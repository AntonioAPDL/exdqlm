imid_v1_schema <- "independent_qdesn_metric_interval_dispersion_v1"
imid_v1_stage <- "qdesn_500obs_metric_interval_dispersion_diagnostic_v1"
imid_v1_production_run_id <- "independent_metric_intervals_v1_production_20260823_225856"
imid_v1_promotion_id <- "qdesn_dqlm_500obs_metric_intervals_v10_20260824"
imid_v1_workers <- 20L
imid_v1_chains <- 3L
imid_v1_draws <- 4000L

imid_v1_selection_path <- function(repo_root = ffv2_repo_root()) {
  file.path(repo_root, "config", "validation",
            "independent_interval_dispersion_diagnostic_v1", "sentinel_sources.csv")
}

imid_v1_promotion_dir <- function(repo_root = ffv2_repo_root()) {
  file.path(repo_root, "validation", "fitforecast_v2", "promotions",
            imid_v1_promotion_id)
}

imid_v1_read_selection <- function(repo_root = ffv2_repo_root()) {
  x <- ffv2_read_csv(imid_v1_selection_path(repo_root))
  required <- c("replay_id", "model_variant", "family", "tau", "sentinel_role",
                "source_candidate_id", "rationale")
  missing <- setdiff(required, names(x))
  if (length(missing)) {
    stop(sprintf("Dispersion sentinel selection is missing: %s",
                 paste(missing, collapse = ", ")), call. = FALSE)
  }
  if (nrow(x) != 7L || anyDuplicated(x$replay_id) ||
      any(!x$model_variant %in% c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"))) {
    stop("Dispersion selection must contain seven unique Q-DESN RHS replay ids.",
         call. = FALSE)
  }
  x
}

imid_v1_recursive_replace <- function(x, replacements) {
  if (is.list(x)) return(lapply(x, imid_v1_recursive_replace, replacements = replacements))
  if (!is.character(x)) return(x)
  out <- x
  for (from in names(replacements)) out <- gsub(from, replacements[[from]], out, fixed = TRUE)
  out
}

imid_v1_interval_width <- function(x) {
  q <- stats::quantile(as.numeric(x), c(0.025, 0.975), names = FALSE, type = 8)
  q[[2L]] - q[[1L]]
}

imid_v1_pool_diagnostics <- function(status_index) {
  blocks <- split(status_index, as.character(status_index$replay_id))
  rows <- lapply(blocks, function(block) {
    pieces <- lapply(seq_len(nrow(block)), function(i) {
      x <- ffv2_read_csv(block$dispersion_draws_path[[i]])
      x$chain_id <- as.integer(block$chain_id[[i]])
      x
    })
    draws <- do.call(rbind, pieces)
    coupling <- do.call(rbind, lapply(seq_len(nrow(block)), function(i) {
      x <- ffv2_read_csv(block$coupling_draws_path[[i]])
      x$chain_id <- as.integer(block$chain_id[[i]])
      x
    }))
    permuted <- coupling[coupling$coupling_mode == "origin_independent_permutation",
                         "forecast_mae", drop = TRUE]
    native_width <- imid_v1_interval_width(draws$forecast_mae_native)
    plugin_width <- imid_v1_interval_width(draws$forecast_mae_plugin)
    permuted_width <- imid_v1_interval_width(permuted)
    parameter_fields <- intersect(
      c("beta_intercept", "beta_norm", "sigma", "gamma", "tau", "c2",
        "lambda_mean", "lambda_min", "lambda_max"), names(draws)
    )
    correlations <- vapply(parameter_fields, function(field) {
      x <- as.numeric(draws[[field]])
      y <- as.numeric(draws$forecast_mae_native)
      ok <- is.finite(x) & is.finite(y)
      if (sum(ok) < 3L || stats::sd(x[ok]) == 0 || stats::sd(y[ok]) == 0) {
        NA_real_
      } else suppressWarnings(stats::cor(x[ok], y[ok], method = "spearman"))
    }, numeric(1L))
    max_idx <- if (length(correlations) && any(is.finite(correlations))) {
      which.max(abs(correlations))
    } else integer(0)
    max_parameter <- if (length(max_idx)) names(correlations)[max_idx] else NA_character_
    max_correlation <- if (length(max_idx)) correlations[max_idx] else NA_real_
    recursion_ratio <- plugin_width / native_width
    coupling_ratio <- permuted_width / native_width
    mechanism <- if (recursion_ratio <= 0.50 && coupling_ratio <= 0.50) {
      "recursive_innovation_and_cross_origin_dependence"
    } else if (recursion_ratio <= 0.70) {
      "recursive_innovation_dominant"
    } else if (coupling_ratio <= 0.70) {
      "cross_origin_dependence_dominant"
    } else if (is.finite(max_correlation) && abs(max_correlation) >= 0.35) {
      "posterior_parameter_scale_dominant"
    } else {
      "mixed_or_structural"
    }
    next_stage <- switch(
      mechanism,
      recursive_innovation_and_cross_origin_dependence =
        "freeze_primary_estimator_and_review_recursion_estimand_before_prior_tuning",
      recursive_innovation_dominant =
        "paired_stochastic_vs_plugin_recursion_protocol_confirmation",
      cross_origin_dependence_dominant =
        "retain_native_estimator_and_report_dependence_sensitivity",
      posterior_parameter_scale_dominant =
        "case_specific_one_factor_prior_or_scale_intervention",
      "case_specific_structural_readout_intervention"
    )
    meta <- block[1L, , drop = FALSE]
    data.frame(
      replay_id = meta$replay_id[[1L]],
      model_variant = meta$model_variant[[1L]],
      family = meta$family[[1L]],
      tau = as.numeric(meta$tau[[1L]]),
      sentinel_role = meta$sentinel_role[[1L]],
      native_mae_mean = mean(draws$forecast_mae_native),
      native_mae_width = native_width,
      plugin_mae_mean = mean(draws$forecast_mae_plugin),
      plugin_mae_width = plugin_width,
      plugin_to_native_width_ratio = recursion_ratio,
      origin_permuted_mae_width = permuted_width,
      origin_permuted_to_native_width_ratio = coupling_ratio,
      max_abs_parameter = max_parameter,
      max_abs_parameter_spearman = max_correlation,
      mean_recursion_delta_rmse = mean(draws$recursion_delta_rmse),
      mechanism = mechanism,
      recommended_next_stage = next_stage,
      tau0_only_screen_authorized = identical(
        mechanism, "posterior_parameter_scale_dominant"
      ) && max_parameter %in% c("tau", "c2", "lambda_mean"),
      n_draws = nrow(draws),
      n_chains = length(unique(draws$chain_id)),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[order(out$family, out$tau, out$model_variant), , drop = FALSE]
}

imid_v1_followup_gate <- function(pooled) {
  data.frame(
    replay_id = pooled$replay_id,
    model_variant = pooled$model_variant,
    family = pooled$family,
    tau = pooled$tau,
    diagnosed_mechanism = pooled$mechanism,
    next_stage = pooled$recommended_next_stage,
    preserve_case_specific_authoritative_design = TRUE,
    preserve_primary_stochastic_recursion = TRUE,
    deterministic_plugin_is_diagnostic_only = TRUE,
    tau0_only_screen_authorized = pooled$tau0_only_screen_authorized,
    article_update_authorized = FALSE,
    automatic_followup_launch_authorized = FALSE,
    stringsAsFactors = FALSE
  )
}

imid_v1_closeout_decision <- function(pooled, checks_pass = TRUE) {
  mechanisms <- as.character(pooled$mechanism)
  if (!isTRUE(checks_pass)) {
    return("DIAGNOSTIC_CLOSEOUT_FAILED")
  }
  if (!length(mechanisms) || any(!nzchar(mechanisms))) {
    stop("Closeout mechanisms must be non-empty.", call. = FALSE)
  }
  if (all(mechanisms == "cross_origin_dependence_dominant")) {
    return("CROSS_ORIGIN_DEPENDENCE_DOMINANT_RETAIN_NATIVE")
  }
  if (all(mechanisms %in% c(
    "recursive_innovation_and_cross_origin_dependence",
    "recursive_innovation_dominant"
  ))) {
    return("RECURSIVE_INNOVATION_DOMINANT_DO_NOT_START_TAU0_SCREEN")
  }
  tau0_authorized <- as.logical(pooled$tau0_only_screen_authorized %||% FALSE)
  if (any(tau0_authorized, na.rm = TRUE)) {
    return("CASE_SPECIFIC_PRIOR_INTERVENTION_ELIGIBLE_FOR_SELECTED_CELLS")
  }
  "MIXED_MECHANISMS_REQUIRE_CASE_SPECIFIC_FOLLOWUP"
}

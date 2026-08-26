imoh_v1_schema <- "independent_qdesn_origin_horizon_attribution_v1"
imoh_v1_stage <- "qdesn_500obs_origin_horizon_attribution_v1"
imoh_v1_source_run_id <-
  "independent_interval_dispersion_diagnostic_v1_20260825_195658"
imoh_v1_workers <- 20L
imoh_v1_draws <- 4000L
imoh_v1_reconstruction_tolerance <- 1e-6

imoh_v1_selection_path <- function(repo_root = ffv2_repo_root()) {
  file.path(repo_root, "config", "validation",
            "independent_origin_horizon_attribution_v1", "sentinel_sources.csv")
}

imoh_v1_read_selection <- function(repo_root = ffv2_repo_root()) {
  x <- ffv2_read_csv(imoh_v1_selection_path(repo_root))
  required <- c("replay_id", "model_variant", "family", "tau", "sentinel_role",
                "source_candidate_id", "pilot_selected", "rationale")
  missing <- setdiff(required, names(x))
  if (length(missing)) {
    stop(sprintf("Origin-horizon selection is missing: %s",
                 paste(missing, collapse = ", ")), call. = FALSE)
  }
  x$pilot_selected <- vapply(x$pilot_selected, ffv2_truthy, logical(1L))
  if (nrow(x) != 7L || sum(x$pilot_selected) != 2L || anyDuplicated(x$replay_id)) {
    stop("Origin-horizon selection requires seven sources and two pilot sources.",
         call. = FALSE)
  }
  x
}

imoh_v1_verify_pilot_reuse <- function(state_root) {
  state_root <- normalizePath(state_root, winslash = "/", mustWork = TRUE)
  required <- c(
    file.path(state_root, "manifests", "materialization_manifest.json"),
    file.path(state_root, "manifests", "job_plan.csv"),
    file.path(state_root, "manifests", "sentinel_sources.csv"),
    file.path(state_root, "closeout", "closeout_checks.csv"),
    file.path(state_root, "closeout", "decision_manifest.json")
  )
  if (any(!file.exists(required))) {
    stop("Pilot reuse requires a complete materialization and closeout.", call. = FALSE)
  }
  materialization <- ffv2_read_json(required[[1L]])
  plan <- ffv2_read_csv(required[[2L]])
  selection <- ffv2_read_csv(required[[3L]])
  checks <- ffv2_read_csv(required[[4L]])
  decision <- ffv2_read_json(required[[5L]])
  checks$pass <- vapply(checks$pass, ffv2_truthy, logical(1L))
  failures <- character(0)
  add_failure <- function(condition, label) {
    if (!isTRUE(condition)) failures <<- c(failures, label)
  }
  add_failure(identical(as.character(materialization$phase), "pilot"),
              "materialization_not_pilot")
  add_failure(identical(as.character(decision$decision),
                        "PILOT_PASS_AUTHORIZE_FULL_SEVEN_CELL_ATTRIBUTION"),
              "pilot_decision_not_authorized")
  add_failure(nrow(plan) == 6L && length(unique(plan$replay_id)) == 2L &&
                all(table(plan$replay_id) == 3L), "pilot_plan_shape")
  add_failure(nrow(selection) == 2L && all(vapply(
    selection$pilot_selected, ffv2_truthy, logical(1L)
  )), "pilot_selection_shape")
  add_failure(nrow(checks) > 0L && all(checks$pass), "pilot_closeout_checks")
  add_failure(as.integer(decision$jobs_completed) == 6L &&
                as.integer(decision$heavy_binary_count) == 0L,
              "pilot_decision_counts")

  status_paths <- file.path(state_root, "status", paste0(plan$job_id, ".json"))
  add_failure(all(file.exists(status_paths)), "pilot_status_files")
  statuses <- if (all(file.exists(status_paths))) {
    lapply(status_paths, ffv2_read_json)
  } else vector("list", nrow(plan))
  artifact_fields <- list(
    attribution_manifest = c("origin_horizon_attribution_manifest_path",
                             "origin_horizon_attribution_manifest_sha256"),
    group_draws = c("attribution_group_draws_path",
                    "attribution_group_draws_sha256"),
    reconstruction = c("attribution_reconstruction_path",
                       "attribution_reconstruction_sha256")
  )
  ledger_rows <- vector("list", nrow(plan))
  if (length(statuses) == nrow(plan)) {
    for (i in seq_len(nrow(plan))) {
      status <- statuses[[i]]
      add_failure(identical(as.character(status$status), "SUCCESS"),
                  paste0(plan$job_id[[i]], ":status"))
      add_failure(identical(as.character(status$config_sha256),
                            as.character(plan$config_sha256[[i]])),
                  paste0(plan$job_id[[i]], ":config_status_hash"))
      add_failure(file.exists(plan$config_path[[i]]) && identical(
        ffv2_file_sha256(plan$config_path[[i]]), as.character(plan$config_sha256[[i]])
      ), paste0(plan$job_id[[i]], ":config_file_hash"))
      artifact_values <- list()
      for (name in names(artifact_fields)) {
        pair <- artifact_fields[[name]]
        path <- as.character(status[[pair[[1L]]]] %||% "")
        sha <- as.character(status[[pair[[2L]]]] %||% "")
        add_failure(nzchar(path) && file.exists(path) && identical(
          ffv2_file_sha256(path), sha
        ), paste0(plan$job_id[[i]], ":", name, "_hash"))
        artifact_values[[paste0(name, "_path")]] <- path
        artifact_values[[paste0(name, "_sha256")]] <- sha
      }
      manifest_path <- artifact_values$attribution_manifest_path
      if (nzchar(manifest_path) && file.exists(manifest_path)) {
        attribution <- ffv2_read_json(manifest_path)
        add_failure(identical(as.character(attribution$status), "PASS"),
                    paste0(plan$job_id[[i]], ":attribution_manifest_status"))
      }
      add_failure(as.integer(status$heavy_binary_count %||% NA_integer_) == 0L,
                  paste0(plan$job_id[[i]], ":heavy_binary_count"))
      ledger_rows[[i]] <- data.frame(
        job_id = plan$job_id[[i]], replay_id = plan$replay_id[[i]],
        chain_id = plan$chain_id[[i]], config_path = plan$config_path[[i]],
        config_sha256 = plan$config_sha256[[i]], job_root = plan$job_root[[i]],
        status_path = status_paths[[i]],
        status_sha256 = if (file.exists(status_paths[[i]]))
          ffv2_file_sha256(status_paths[[i]]) else "",
        attribution_manifest_path = artifact_values$attribution_manifest_path %||% "",
        attribution_manifest_sha256 = artifact_values$attribution_manifest_sha256 %||% "",
        group_draws_path = artifact_values$group_draws_path %||% "",
        group_draws_sha256 = artifact_values$group_draws_sha256 %||% "",
        reconstruction_path = artifact_values$reconstruction_path %||% "",
        reconstruction_sha256 = artifact_values$reconstruction_sha256 %||% "",
        stringsAsFactors = FALSE
      )
    }
  }
  heavy <- unique(unlist(lapply(unique(plan$job_root), function(root) {
    if (!dir.exists(root)) return(character(0))
    list.files(root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
               full.names = TRUE, ignore.case = TRUE)
  }), use.names = FALSE))
  add_failure(length(heavy) == 0L, "pilot_heavy_binaries")
  if (length(failures)) {
    stop(sprintf("Pilot reuse verification failed: %s",
                 paste(unique(failures), collapse = ", ")), call. = FALSE)
  }
  list(
    state_root = state_root,
    plan = plan,
    status_paths = status_paths,
    ledger = do.call(rbind, ledger_rows),
    decision_path = required[[5L]],
    decision_sha256 = ffv2_file_sha256(required[[5L]])
  )
}

imoh_v1_pool_group_draws <- function(status_index) {
  pieces <- lapply(seq_len(nrow(status_index)), function(i) {
    x <- ffv2_read_csv(status_index$attribution_group_draws_path[[i]])
    x$chain_id <- as.integer(status_index$chain_id[[i]])
    x$draw_uid <- paste0("c", x$chain_id, "_d", x$draw_id)
    x$replay_id <- status_index$replay_id[[i]]
    x$model_variant <- status_index$model_variant[[i]]
    x$family <- status_index$family[[i]]
    x$tau_level <- status_index$tau[[i]]
    x$sentinel_role <- status_index$sentinel_role[[i]]
    x
  })
  do.call(rbind, pieces)
}

imoh_v1_pool_group_summary <- function(group_draws) {
  keys <- unique(group_draws[c(
    "replay_id", "model_variant", "family", "tau_level", "sentinel_role",
    "scope", "group_type", "group_value", "n_targets"
  )])
  metrics <- c("forecast_mae", "forecast_check_loss", "oracle_bias", "oracle_rmse")
  rows <- vector("list", nrow(keys) * length(metrics))
  k <- 0L
  for (i in seq_len(nrow(keys))) {
    keep <- Reduce(`&`, Map(function(name) {
      as.character(group_draws[[name]]) == as.character(keys[[name]][[i]])
    }, c("replay_id", "scope", "group_type", "group_value")))
    for (metric in metrics) {
      x <- as.numeric(group_draws[[metric]][keep])
      qs <- stats::quantile(x, c(0.025, 0.5, 0.975), names = FALSE,
                            type = 8, na.rm = TRUE)
      k <- k + 1L
      rows[[k]] <- data.frame(
        keys[i, , drop = FALSE], metric = metric,
        posterior_mean = mean(x), posterior_sd = stats::sd(x),
        cri_lower = qs[[1L]], posterior_median = qs[[2L]],
        cri_upper = qs[[3L]], cri_width = qs[[3L]] - qs[[1L]],
        n_draws = sum(is.finite(x)), n_chains = length(unique(
          group_draws$chain_id[keep]
        )), stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows[seq_len(k)])
}

imoh_v1_pool_variance <- function(group_draws) {
  selected <- group_draws[group_draws$group_type %in% c("origin", "lead"), ]
  keys <- unique(selected[c("replay_id", "model_variant", "family", "tau_level",
                             "sentinel_role", "scope", "group_type")])
  rows <- list()
  k <- 0L
  for (i in seq_len(nrow(keys))) {
    keep <- Reduce(`&`, Map(function(name) {
      as.character(selected[[name]]) == as.character(keys[[name]][[i]])
    }, c("replay_id", "scope", "group_type")))
    block <- selected[keep, , drop = FALSE]
    groups <- unique(block$group_value)
    split <- lapply(groups, function(value) {
      z <- block[block$group_value == value, , drop = FALSE]
      z[order(z$chain_id, z$draw_id), , drop = FALSE]
    })
    counts <- vapply(split, function(z) z$n_targets[[1L]], numeric(1L))
    weights <- counts / sum(counts)
    for (metric in c("forecast_mae", "forecast_check_loss")) {
      matrix <- do.call(rbind, lapply(split, function(z) as.numeric(z[[metric]])))
      aggregate <- as.numeric(crossprod(weights, matrix))
      total <- stats::var(aggregate)
      diagonal <- sum(weights^2 * apply(matrix, 1L, stats::var))
      covariance <- total - diagonal
      k <- k + 1L
      rows[[k]] <- data.frame(
        keys[i, , drop = FALSE], metric = metric,
        n_groups = length(groups), n_targets = sum(counts),
        n_draws = ncol(matrix), total_variance = total,
        diagonal_variance = diagonal, covariance_variance = covariance,
        covariance_fraction = if (is.finite(total) && total > 0) {
          covariance / total
        } else NA_real_, stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

imoh_v1_read_chain_artifact <- function(status_index, field) {
  pieces <- lapply(seq_len(nrow(status_index)), function(i) {
    x <- ffv2_read_csv(status_index[[field]][[i]])
    x$chain_id <- status_index$chain_id[[i]]
    x$replay_id <- status_index$replay_id[[i]]
    x$model_variant <- status_index$model_variant[[i]]
    x$family <- status_index$family[[i]]
    x$tau_level <- status_index$tau[[i]]
    x$sentinel_role <- status_index$sentinel_role[[i]]
    x
  })
  do.call(rbind, pieces)
}

imoh_v1_parameter_signal <- function(parameter_associations) {
  rhs <- parameter_associations[
    parameter_associations$scope == "all_targets" &
      parameter_associations$group_type == "all" &
      parameter_associations$metric == "forecast_mae" &
      parameter_associations$parameter %in% c("tau", "c2", "lambda_mean"), ,
    drop = FALSE
  ]
  if (!nrow(rhs)) return(data.frame(stringsAsFactors = FALSE))
  keys <- unique(rhs[c("replay_id", "parameter")])
  rows <- lapply(seq_len(nrow(keys)), function(i) {
    keep <- rhs$replay_id == keys$replay_id[[i]] &
      rhs$parameter == keys$parameter[[i]]
    x <- rhs$spearman[keep]
    data.frame(
      replay_id = keys$replay_id[[i]], parameter = keys$parameter[[i]],
      median_spearman = stats::median(x, na.rm = TRUE),
      min_abs_spearman = min(abs(x), na.rm = TRUE),
      sign_consistency = abs(mean(sign(x), na.rm = TRUE)),
      n_chains = sum(is.finite(x)), stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

imoh_v1_cell_diagnosis <- function(group_summary, variance, target_summary,
                                   path_structure, parameter_signal) {
  cells <- unique(group_summary[c("replay_id", "model_variant", "family",
                                   "tau_level", "sentinel_role")])
  rows <- lapply(seq_len(nrow(cells)), function(i) {
    id <- cells$replay_id[[i]]
    lead <- group_summary[
      group_summary$replay_id == id & group_summary$scope == "all_targets" &
        group_summary$group_type == "lead" & group_summary$metric == "forecast_mae", ,
      drop = FALSE
    ]
    origin <- group_summary[
      group_summary$replay_id == id & group_summary$scope == "all_targets" &
        group_summary$group_type == "origin" & group_summary$metric == "forecast_mae", ,
      drop = FALSE
    ]
    all_metric <- group_summary[
      group_summary$replay_id == id & group_summary$scope == "all_targets" &
        group_summary$group_type == "all" & group_summary$metric == "forecast_mae", ,
      drop = FALSE
    ]
    origin_var <- variance[
      variance$replay_id == id & variance$scope == "all_targets" &
        variance$group_type == "origin" & variance$metric == "forecast_mae", ,
      drop = FALSE
    ]
    lead_var <- variance[
      variance$replay_id == id & variance$scope == "all_targets" &
        variance$group_type == "lead" & variance$metric == "forecast_mae", ,
      drop = FALSE
    ]
    target <- target_summary[target_summary$replay_id == id, , drop = FALSE]
    structure <- path_structure[
      path_structure$replay_id == id & path_structure$component == "global_shift", ,
      drop = FALSE
    ]
    signal <- parameter_signal[parameter_signal$replay_id == id, , drop = FALSE]
    early <- mean(lead$posterior_mean[as.numeric(lead$group_value) <= 5])
    late <- mean(lead$posterior_mean[as.numeric(lead$group_value) >= 26])
    contribution <- origin$posterior_mean * origin$n_targets
    top_n <- max(1L, ceiling(0.2 * nrow(origin)))
    top_share <- sum(sort(contribution, decreasing = TRUE)[seq_len(top_n)]) /
      sum(contribution)
    best_signal <- if (nrow(signal)) signal[which.max(abs(signal$median_spearman)), ] else NULL
    stable_rhs <- !is.null(best_signal) && best_signal$n_chains == 3L &&
      best_signal$min_abs_spearman >= 0.20 &&
      abs(best_signal$median_spearman) >= 0.35 &&
      best_signal$sign_consistency == 1
    coverage <- mean(target$oracle_covered, na.rm = TRUE)
    covariance_dominant <- origin_var$covariance_fraction[[1L]] >= 0.70
    horizon_dominant <- is.finite(late / early) && late / early >= 1.25
    origin_concentrated <- is.finite(top_share) && top_share >= 0.35
    pattern <- if (covariance_dominant && !horizon_dominant && !origin_concentrated) {
      "global_cross_origin_posterior_dependence"
    } else if (horizon_dominant && !origin_concentrated) {
      "long_horizon_performance_instability"
    } else if (origin_concentrated && !horizon_dominant) {
      "localized_time_block_instability"
    } else {
      "combined_origin_horizon_and_common_mode"
    }
    data.frame(
      cells[i, , drop = FALSE], aggregate_mae_mean = all_metric$posterior_mean[[1L]],
      aggregate_mae_cri_width = all_metric$cri_width[[1L]],
      early_lead_mae = early, late_lead_mae = late,
      late_to_early_mae_ratio = late / early,
      origin_top20pct_loss_share = top_share,
      origin_covariance_fraction = origin_var$covariance_fraction[[1L]],
      lead_covariance_fraction = lead_var$covariance_fraction[[1L]],
      global_shift_energy_fraction = mean(structure$fraction, na.rm = TRUE),
      oracle_path_coverage = coverage,
      strongest_rhs_parameter = if (is.null(best_signal)) NA_character_ else
        best_signal$parameter[[1L]],
      strongest_rhs_median_spearman = if (is.null(best_signal)) NA_real_ else
        best_signal$median_spearman[[1L]],
      strongest_rhs_sign_consistency = if (is.null(best_signal)) NA_real_ else
        best_signal$sign_consistency[[1L]],
      primary_pattern = pattern,
      tau0_causal_pilot_eligible = stable_rhs && coverage >= 0.95,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

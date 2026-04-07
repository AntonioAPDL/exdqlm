`%||%` <- function(a, b) if (is.null(a)) b else a

qdesn_dynamic_maincmp_load_manifest <- function(path = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_main_comparison_analysis_manifest.yaml"),
                                                repo_root = NULL) {
  .qdesn_validation_require_namespace("yaml")
  yaml_path <- .qdesn_validation_resolve_path(path, repo_root = repo_root, must_work = TRUE)
  out <- yaml::read_yaml(yaml_path)
  if (!is.list(out)) {
    stop("Dynamic main comparison analysis manifest YAML must parse to a list.", call. = FALSE)
  }
  out
}

.qdesn_dynamic_maincmp_root_spec_from_row <- function(row) {
  list(
    root_id = as.character(row$root_id[1L]),
    dataset_cell_id = as.character(row$dataset_cell_id[1L]),
    scenario = as.character(row$scenario[1L] %||% NA_character_),
    source_root_kind = as.character(row$root_kind[1L]),
    source_family = as.character(row$family[1L]),
    tau = as.numeric(row$tau[1L]),
    fit_size = as.integer(row$fit_size[1L]),
    beta_prior_type = as.character((row$prior %||% row$beta_prior_type)[1L]),
    source_reference_priors = as.character(row$source_reference_priors[1L] %||% "default"),
    source_current_rhsns_member = isTRUE(as.logical(row$source_current_rhsns_member[1L] %||% FALSE)),
    source_legacy_rhs_member = isTRUE(as.logical(row$source_legacy_rhs_member[1L] %||% FALSE))
  )
}

qdesn_dynamic_maincmp_rebuild_pair_tables <- function(fit_summary,
                                                      root_summary = data.frame(stringsAsFactors = FALSE)) {
  if (!nrow(fit_summary)) {
    return(list(
      pairwise_vb_vs_mcmc = data.frame(stringsAsFactors = FALSE),
      model_pair_signoff = data.frame(stringsAsFactors = FALSE)
    ))
  }

  pair_rows <- list()
  model_rows <- list()
  root_ids <- sort(unique(as.character(fit_summary$root_id)))
  for (root_id in root_ids) {
    fit_sub <- fit_summary[as.character(fit_summary$root_id) == root_id, , drop = FALSE]
    root_sub <- if (nrow(root_summary)) {
      root_summary[as.character(root_summary$root_id) == root_id, , drop = FALSE]
    } else {
      data.frame(stringsAsFactors = FALSE)
    }
    meta <- if (nrow(root_sub)) root_sub[1L, , drop = FALSE] else fit_sub[1L, , drop = FALSE]
    root_spec <- .qdesn_dynamic_maincmp_root_spec_from_row(meta)
    pair_df <- .qdesn_static_crossstudy_algorithm_pair_summary(fit_sub, root_spec)
    model_df <- .qdesn_static_crossstudy_model_pair_summary(fit_sub, root_spec)
    if (nrow(pair_df)) {
      pair_df$scenario <- as.character(meta$scenario[1L] %||% NA_character_)
      pair_rows[[length(pair_rows) + 1L]] <- pair_df
    }
    if (nrow(model_df)) {
      model_df$scenario <- as.character(meta$scenario[1L] %||% NA_character_)
      model_rows[[length(model_rows) + 1L]] <- model_df
    }
  }

  list(
    pairwise_vb_vs_mcmc = .qdesn_validation_bind_rows(pair_rows),
    model_pair_signoff = .qdesn_validation_bind_rows(model_rows)
  )
}

.qdesn_dynamic_maincmp_metric_summary <- function(df,
                                                  group_cols,
                                                  grade_col,
                                                  eligible_col = NULL,
                                                  numeric_cols = character(0)) {
  if (!nrow(df)) return(data.frame(stringsAsFactors = FALSE))
  group_cols <- group_cols[group_cols %in% names(df)]
  if (!length(group_cols)) return(data.frame(stringsAsFactors = FALSE))

  idx_list <- split(seq_len(nrow(df)), interaction(df[, group_cols, drop = FALSE], drop = TRUE, lex.order = TRUE))
  rows <- lapply(idx_list, function(idx) {
    sub <- df[idx, , drop = FALSE]
    row <- sub[1L, group_cols, drop = FALSE]
    row$n_rows <- nrow(sub)
    grades <- as.character(sub[[grade_col]])
    row$n_pass <- sum(grades == "PASS", na.rm = TRUE)
    row$n_warn <- sum(grades == "WARN", na.rm = TRUE)
    row$n_fail <- sum(grades == "FAIL", na.rm = TRUE)
    row$pass_rate <- row$n_pass / row$n_rows
    row$warn_rate <- row$n_warn / row$n_rows
    row$fail_rate <- row$n_fail / row$n_rows
    if (!is.null(eligible_col) && eligible_col %in% names(sub)) {
      row$comparison_eligible_rate <- mean(as.logical(sub[[eligible_col]]), na.rm = TRUE)
    }
    for (nm in numeric_cols[numeric_cols %in% names(sub)]) {
      x <- suppressWarnings(as.numeric(sub[[nm]]))
      finite_x <- x[is.finite(x)]
      row[[paste0(nm, "_mean")]] <- if (length(finite_x)) mean(finite_x) else NA_real_
      row[[paste0(nm, "_median")]] <- if (length(finite_x)) stats::median(finite_x) else NA_real_
      row[[paste0(nm, "_p90")]] <- if (length(finite_x)) as.numeric(stats::quantile(finite_x, probs = 0.9, names = FALSE, type = 7)) else NA_real_
      if (identical(nm, "runtime_sec")) {
        row[[paste0(nm, "_total")]] <- if (length(finite_x)) sum(finite_x) else NA_real_
      }
    }
    row
  })
  .qdesn_validation_bind_rows(rows)
}

qdesn_dynamic_maincmp_root_inventory <- function(root_summary,
                                                 fit_summary) {
  if (!nrow(root_summary)) return(data.frame(stringsAsFactors = FALSE))
  fail_counts <- if (nrow(fit_summary)) {
    fail_fit <- fit_summary[as.character(fit_summary$signoff_grade) == "FAIL", , drop = FALSE]
    if (nrow(fail_fit)) {
      out <- aggregate(
        list(fail_fit_n = rep(1L, nrow(fail_fit))),
        by = list(root_id = as.character(fail_fit$root_id)),
        FUN = sum
      )
      out
    } else {
      data.frame(root_id = character(0), fail_fit_n = integer(0), stringsAsFactors = FALSE)
    }
  } else {
    data.frame(root_id = character(0), fail_fit_n = integer(0), stringsAsFactors = FALSE)
  }

  out <- merge(root_summary, fail_counts, by = "root_id", all.x = TRUE, sort = FALSE)
  out$fail_fit_n[is.na(out$fail_fit_n)] <- 0L
  out$readiness_label <- ifelse(
    as.logical(out$root_comparison_eligible_full),
    "FULL_READY",
    ifelse(as.logical(out$root_comparison_eligible_any), "USABLE_WITH_GAP", "NONCOMPARABLE")
  )
  out[order(out$scenario, out$family, out$tau, out$fit_size, out$prior), , drop = FALSE]
}

qdesn_dynamic_maincmp_root_axis_summary <- function(root_inventory,
                                                    group_cols = c("prior", "fit_size")) {
  if (!nrow(root_inventory)) return(data.frame(stringsAsFactors = FALSE))
  group_cols <- group_cols[group_cols %in% names(root_inventory)]
  if (!length(group_cols)) return(data.frame(stringsAsFactors = FALSE))

  idx_list <- split(
    seq_len(nrow(root_inventory)),
    interaction(root_inventory[, group_cols, drop = FALSE], drop = TRUE, lex.order = TRUE)
  )
  rows <- lapply(idx_list, function(idx) {
    sub <- root_inventory[idx, , drop = FALSE]
    row <- sub[1L, group_cols, drop = FALSE]
    row$n_roots <- nrow(sub)
    row$n_success <- sum(as.character(sub$root_status) == "SUCCESS", na.rm = TRUE)
    row$n_fail <- sum(as.character(sub$root_status) == "FAIL", na.rm = TRUE)
    row$n_full_ready <- sum(as.character(sub$readiness_label) == "FULL_READY", na.rm = TRUE)
    row$n_usable_with_gap <- sum(as.character(sub$readiness_label) == "USABLE_WITH_GAP", na.rm = TRUE)
    row$n_noncomparable <- sum(as.character(sub$readiness_label) == "NONCOMPARABLE", na.rm = TRUE)
    row$root_success_rate <- if (nrow(sub)) row$n_success / nrow(sub) else NA_real_
    row$root_comparison_eligible_any_rate <- mean(as.logical(sub$root_comparison_eligible_any), na.rm = TRUE)
    row$root_comparison_eligible_full_rate <- mean(as.logical(sub$root_comparison_eligible_full), na.rm = TRUE)
    fail_fit_n <- suppressWarnings(as.numeric(sub$fail_fit_n))
    finite_fail_fit_n <- fail_fit_n[is.finite(fail_fit_n)]
    row$fail_fit_n_total <- if (length(finite_fail_fit_n)) sum(finite_fail_fit_n) else NA_real_
    row$fail_fit_n_mean <- if (length(finite_fail_fit_n)) mean(finite_fail_fit_n) else NA_real_
    row
  })
  .qdesn_validation_bind_rows(rows)
}

.qdesn_dynamic_maincmp_canonical_model <- function(x) {
  out <- tolower(trimws(as.character(x)))
  out[out %in% c("dqlm", "al")] <- "al"
  out[out %in% c("exdqlm", "exal")] <- "exal"
  out
}

qdesn_dynamic_maincmp_prior_head_to_head <- function(fit_surface_summary) {
  if (!nrow(fit_surface_summary)) return(data.frame(stringsAsFactors = FALSE))
  required <- c("scenario", "root_kind", "family", "tau", "fit_size", "inference", "model", "prior")
  if (!all(required %in% names(fit_surface_summary))) return(data.frame(stringsAsFactors = FALSE))

  ridge <- fit_surface_summary[as.character(fit_surface_summary$prior) == "ridge", , drop = FALSE]
  rhs <- fit_surface_summary[as.character(fit_surface_summary$prior) == "rhs_ns", , drop = FALSE]
  by_cols <- c("scenario", "root_kind", "family", "tau", "fit_size", "inference", "model")
  merged <- merge(rhs, ridge, by = by_cols, all = FALSE, suffixes = c("_rhs_ns", "_ridge"), sort = TRUE)
  if (!nrow(merged)) return(merged)

  delta_pairs <- list(
    c("fail_rate", "rhs_ns_minus_ridge"),
    c("comparison_eligible_rate", "rhs_ns_minus_ridge"),
    c("runtime_sec_mean", "rhs_ns_minus_ridge"),
    c("holdout_mae_mean", "rhs_ns_minus_ridge"),
    c("holdout_rmse_mean", "rhs_ns_minus_ridge"),
    c("holdout_bias_mean", "rhs_ns_minus_ridge"),
    c("holdout_corr_mean", "rhs_ns_minus_ridge"),
    c("train_mae_mean", "rhs_ns_minus_ridge"),
    c("train_rmse_mean", "rhs_ns_minus_ridge")
  )
  for (pair in delta_pairs) {
    metric <- pair[[1L]]
    out_name <- paste0(metric, "_", pair[[2L]])
    lhs <- paste0(metric, "_rhs_ns")
    rhs_nm <- paste0(metric, "_ridge")
    if (lhs %in% names(merged) && rhs_nm %in% names(merged)) {
      merged[[out_name]] <- as.numeric(merged[[lhs]]) - as.numeric(merged[[rhs_nm]])
    }
  }

  merged$preferred_prior <- apply(merged, 1L, function(row) {
    fail_delta <- suppressWarnings(as.numeric(row[["fail_rate_rhs_ns_minus_ridge"]]))
    elig_delta <- suppressWarnings(as.numeric(row[["comparison_eligible_rate_rhs_ns_minus_ridge"]]))
    rmse_delta <- suppressWarnings(as.numeric(row[["holdout_rmse_mean_rhs_ns_minus_ridge"]]))
    runtime_delta <- suppressWarnings(as.numeric(row[["runtime_sec_mean_rhs_ns_minus_ridge"]]))
    if (is.finite(fail_delta) && fail_delta < 0) return("rhs_ns")
    if (is.finite(fail_delta) && fail_delta > 0) return("ridge")
    if (is.finite(elig_delta) && elig_delta > 0) return("rhs_ns")
    if (is.finite(elig_delta) && elig_delta < 0) return("ridge")
    if (is.finite(rmse_delta) && rmse_delta < 0) return("rhs_ns")
    if (is.finite(rmse_delta) && rmse_delta > 0) return("ridge")
    if (is.finite(runtime_delta) && runtime_delta < 0) return("rhs_ns")
    if (is.finite(runtime_delta) && runtime_delta > 0) return("ridge")
    "tie"
  })

  merged
}

qdesn_dynamic_maincmp_join_reference_metrics <- function(q_summary,
                                                         ref_summary,
                                                         join_cols) {
  if (!nrow(q_summary) || !nrow(ref_summary)) return(data.frame(stringsAsFactors = FALSE))
  join_cols <- join_cols[join_cols %in% names(q_summary) & join_cols %in% names(ref_summary)]
  if (!length(join_cols)) return(data.frame(stringsAsFactors = FALSE))

  merged <- merge(
    q_summary,
    ref_summary,
    by = join_cols,
    all.x = TRUE,
    suffixes = c("_qdesn", "_reference"),
    sort = TRUE
  )

  delta_metrics <- c(
    "pass_rate",
    "warn_rate",
    "fail_rate",
    "comparison_eligible_rate",
    "runtime_sec_mean",
    "runtime_sec_median",
    "runtime_sec_p90"
  )
  for (metric in delta_metrics) {
    q_nm <- paste0(metric, "_qdesn")
    r_nm <- paste0(metric, "_reference")
    if (q_nm %in% names(merged) && r_nm %in% names(merged)) {
      merged[[paste0(metric, "_delta_qdesn_minus_reference")]] <- as.numeric(merged[[q_nm]]) - as.numeric(merged[[r_nm]])
    }
  }
  if (all(c("runtime_sec_mean_qdesn", "runtime_sec_mean_reference") %in% names(merged))) {
    merged$runtime_sec_mean_ratio_qdesn_vs_reference <- ifelse(
      is.finite(as.numeric(merged$runtime_sec_mean_reference)) &
        as.numeric(merged$runtime_sec_mean_reference) > 0,
      as.numeric(merged$runtime_sec_mean_qdesn) / as.numeric(merged$runtime_sec_mean_reference),
      NA_real_
    )
  }

  merged
}

qdesn_dynamic_maincmp_write_analysis <- function(source_state,
                                                 reference_inventory,
                                                 output_root,
                                                 manifest = list(),
                                                 defaults = NULL,
                                                 final_wave_run_tag = NA_character_) {
  .qdesn_validation_dir_create(output_root)
  .qdesn_validation_dir_create(file.path(output_root, "tables"))
  .qdesn_validation_dir_create(file.path(output_root, "summary"))
  .qdesn_validation_dir_create(file.path(output_root, "manifest"))

  pair_tables <- qdesn_dynamic_maincmp_rebuild_pair_tables(
    fit_summary = source_state$fit_summary,
    root_summary = source_state$root_summary
  )
  pairwise_vb_vs_mcmc <- pair_tables$pairwise_vb_vs_mcmc
  model_pair_signoff <- pair_tables$model_pair_signoff
  root_inventory <- qdesn_dynamic_maincmp_root_inventory(source_state$root_summary, source_state$fit_summary)
  fail_inventory <- source_state$fit_summary[as.character(source_state$fit_summary$signoff_grade) == "FAIL", , drop = FALSE]

  fit_surface_summary <- .qdesn_dynamic_maincmp_metric_summary(
    source_state$fit_summary,
    group_cols = c("scenario", "root_kind", "family", "tau", "fit_size", "prior", "inference", "model"),
    grade_col = "signoff_grade",
    eligible_col = "comparison_eligible",
    numeric_cols = c(
      "runtime_sec", "fit_runtime_seconds", "holdout_mae", "holdout_rmse", "holdout_bias", "holdout_corr",
      "train_mae", "train_rmse", "train_bias", "train_corr"
    )
  )
  if (nrow(fit_surface_summary) && "model" %in% names(fit_surface_summary)) {
    fit_surface_summary$canonical_model <- .qdesn_dynamic_maincmp_canonical_model(fit_surface_summary$model)
  }
  fit_axis_summary <- .qdesn_dynamic_maincmp_metric_summary(
    source_state$fit_summary,
    group_cols = c("prior", "inference", "model", "fit_size"),
    grade_col = "signoff_grade",
    eligible_col = "comparison_eligible",
    numeric_cols = c(
      "runtime_sec", "fit_runtime_seconds", "holdout_mae", "holdout_rmse", "holdout_bias", "holdout_corr",
      "train_mae", "train_rmse", "train_bias", "train_corr"
    )
  )
  if (nrow(fit_axis_summary) && "model" %in% names(fit_axis_summary)) {
    fit_axis_summary$canonical_model <- .qdesn_dynamic_maincmp_canonical_model(fit_axis_summary$model)
  }
  fit_prior_summary <- .qdesn_dynamic_maincmp_metric_summary(
    source_state$fit_summary,
    group_cols = c("prior"),
    grade_col = "signoff_grade",
    eligible_col = "comparison_eligible",
    numeric_cols = c("runtime_sec", "holdout_mae", "holdout_rmse", "train_mae", "train_rmse")
  )
  fit_method_model_summary <- .qdesn_dynamic_maincmp_metric_summary(
    source_state$fit_summary,
    group_cols = c("inference", "model"),
    grade_col = "signoff_grade",
    eligible_col = "comparison_eligible",
    numeric_cols = c("runtime_sec", "holdout_mae", "holdout_rmse", "train_mae", "train_rmse")
  )

  pair_surface_summary <- .qdesn_dynamic_maincmp_metric_summary(
    pairwise_vb_vs_mcmc,
    group_cols = c("scenario", "root_kind", "family", "tau", "fit_size", "prior", "model"),
    grade_col = "algorithm_pair_signoff_grade",
    eligible_col = "algorithm_pair_comparison_eligible",
    numeric_cols = c("runtime_ratio_mcmc_vs_vb", "mae_delta_mcmc_minus_vb", "rmse_delta_mcmc_minus_vb", "bias_delta_mcmc_minus_vb", "corr_delta_mcmc_minus_vb")
  )
  pair_axis_summary <- .qdesn_dynamic_maincmp_metric_summary(
    pairwise_vb_vs_mcmc,
    group_cols = c("prior", "model", "fit_size"),
    grade_col = "algorithm_pair_signoff_grade",
    eligible_col = "algorithm_pair_comparison_eligible",
    numeric_cols = c("runtime_ratio_mcmc_vs_vb", "mae_delta_mcmc_minus_vb", "rmse_delta_mcmc_minus_vb", "bias_delta_mcmc_minus_vb", "corr_delta_mcmc_minus_vb")
  )
  model_axis_summary <- .qdesn_dynamic_maincmp_metric_summary(
    model_pair_signoff,
    group_cols = c("prior", "inference", "fit_size"),
    grade_col = "pair_signoff_grade",
    eligible_col = "pair_comparison_eligible",
    numeric_cols = c("train_mae_delta_extended_minus_baseline", "train_rmse_delta_extended_minus_baseline", "train_corr_delta_extended_minus_baseline")
  )

  root_surface_summary <- .qdesn_dynamic_crossstudy_qdesn_root_group_summary(source_state$root_summary)
  root_axis_summary <- qdesn_dynamic_maincmp_root_axis_summary(
    root_inventory,
    group_cols = c("prior", "fit_size")
  )

  ref_fit_group <- .qdesn_dynamic_maincmp_metric_summary(
    reference_inventory$fit_summary,
    group_cols = c("scenario", "root_kind", "family", "tau", "fit_size", "inference", "model"),
    grade_col = "signoff_grade",
    eligible_col = "comparison_eligible",
    numeric_cols = c("runtime_sec")
  )
  if (nrow(ref_fit_group) && "model" %in% names(ref_fit_group)) {
    ref_fit_group$canonical_model <- .qdesn_dynamic_maincmp_canonical_model(ref_fit_group$model)
  }
  ref_fit_axis <- .qdesn_dynamic_maincmp_metric_summary(
    reference_inventory$fit_summary,
    group_cols = c("inference", "model", "fit_size"),
    grade_col = "signoff_grade",
    eligible_col = "comparison_eligible",
    numeric_cols = c("runtime_sec")
  )
  if (nrow(ref_fit_axis) && "model" %in% names(ref_fit_axis)) {
    ref_fit_axis$canonical_model <- .qdesn_dynamic_maincmp_canonical_model(ref_fit_axis$model)
  }

  q_vs_ref_surface <- qdesn_dynamic_maincmp_join_reference_metrics(
    fit_surface_summary,
    ref_fit_group,
    join_cols = c("scenario", "root_kind", "family", "tau", "fit_size", "inference", "canonical_model")
  )
  q_vs_ref_axis <- qdesn_dynamic_maincmp_join_reference_metrics(
    fit_axis_summary,
    ref_fit_axis,
    join_cols = c("inference", "canonical_model", "fit_size")
  )
  prior_head_to_head <- qdesn_dynamic_maincmp_prior_head_to_head(fit_surface_summary)
  prior_head_to_head_counts <- if (nrow(prior_head_to_head)) {
    as.data.frame(table(preferred_prior = as.character(prior_head_to_head$preferred_prior)), stringsAsFactors = FALSE)
  } else {
    data.frame(stringsAsFactors = FALSE)
  }

  compare_obj <- qdesn_dynamic_crossstudy_write_reference_compare(
    reference_inventory = reference_inventory,
    qdesn_tables = list(
      fit_summary = source_state$fit_summary,
      pairwise_vb_vs_mcmc = pairwise_vb_vs_mcmc,
      model_pair_signoff = model_pair_signoff,
      root_summary = source_state$root_summary
    ),
    output_root = file.path(output_root, "comparison_vs_reference")
  )

  .qdesn_validation_write_df(source_state$fit_summary, file.path(output_root, "tables", "authoritative_fit_summary.csv"))
  .qdesn_validation_write_df(source_state$root_summary, file.path(output_root, "tables", "authoritative_root_signoff_summary.csv"))
  .qdesn_validation_write_df(source_state$progress, file.path(output_root, "tables", "authoritative_campaign_progress.csv"))
  .qdesn_validation_write_df(pairwise_vb_vs_mcmc, file.path(output_root, "tables", "authoritative_pairwise_vb_vs_mcmc.csv"))
  .qdesn_validation_write_df(model_pair_signoff, file.path(output_root, "tables", "authoritative_model_pair_signoff.csv"))
  .qdesn_validation_write_df(source_state$local_baseline_map, file.path(output_root, "tables", "authoritative_local_baseline_map.csv"))
  .qdesn_validation_write_df(source_state$root_override_map %||% data.frame(stringsAsFactors = FALSE), file.path(output_root, "tables", "authoritative_root_override_map.csv"))
  .qdesn_validation_write_df(source_state$stage_status, file.path(output_root, "tables", "source_stage_execution_status.csv"))
  .qdesn_validation_write_df(source_state$winner_inventory, file.path(output_root, "tables", "source_winner_inventory.csv"))
  .qdesn_validation_write_df(root_inventory, file.path(output_root, "tables", "authoritative_root_inventory.csv"))
  .qdesn_validation_write_df(fail_inventory, file.path(output_root, "tables", "authoritative_fail_inventory.csv"))
  .qdesn_validation_write_df(fit_surface_summary, file.path(output_root, "tables", "authoritative_fit_surface_summary.csv"))
  .qdesn_validation_write_df(fit_axis_summary, file.path(output_root, "tables", "authoritative_fit_axis_summary.csv"))
  .qdesn_validation_write_df(fit_prior_summary, file.path(output_root, "tables", "authoritative_fit_prior_summary.csv"))
  .qdesn_validation_write_df(fit_method_model_summary, file.path(output_root, "tables", "authoritative_fit_method_model_summary.csv"))
  .qdesn_validation_write_df(pair_surface_summary, file.path(output_root, "tables", "authoritative_pair_surface_summary.csv"))
  .qdesn_validation_write_df(pair_axis_summary, file.path(output_root, "tables", "authoritative_pair_axis_summary.csv"))
  .qdesn_validation_write_df(model_axis_summary, file.path(output_root, "tables", "authoritative_model_axis_summary.csv"))
  .qdesn_validation_write_df(root_surface_summary, file.path(output_root, "tables", "authoritative_root_surface_summary.csv"))
  .qdesn_validation_write_df(root_axis_summary, file.path(output_root, "tables", "authoritative_root_axis_summary.csv"))
  .qdesn_validation_write_df(q_vs_ref_surface, file.path(output_root, "tables", "authoritative_qdesn_vs_reference_fit_surface_delta.csv"))
  .qdesn_validation_write_df(q_vs_ref_axis, file.path(output_root, "tables", "authoritative_qdesn_vs_reference_fit_axis_delta.csv"))
  .qdesn_validation_write_df(prior_head_to_head, file.path(output_root, "tables", "authoritative_prior_head_to_head.csv"))
  .qdesn_validation_write_df(prior_head_to_head_counts, file.path(output_root, "tables", "authoritative_prior_head_to_head_counts.csv"))

  overview <- data.frame(
    metric = c(
      "fit_rows_total", "fit_pass_n", "fit_warn_n", "fit_fail_n",
      "root_total", "root_status_fail_n", "root_compare_any_n", "root_compare_full_n"
    ),
    value = c(
      nrow(source_state$fit_summary),
      sum(as.character(source_state$fit_summary$signoff_grade) == "PASS", na.rm = TRUE),
      sum(as.character(source_state$fit_summary$signoff_grade) == "WARN", na.rm = TRUE),
      sum(as.character(source_state$fit_summary$signoff_grade) == "FAIL", na.rm = TRUE),
      nrow(source_state$root_summary),
      sum(as.character(source_state$root_summary$root_status) == "FAIL", na.rm = TRUE),
      sum(as.logical(source_state$root_summary$root_comparison_eligible_any), na.rm = TRUE),
      sum(as.logical(source_state$root_summary$root_comparison_eligible_full), na.rm = TRUE)
    ),
    stringsAsFactors = FALSE
  )
  .qdesn_validation_write_df(overview, file.path(output_root, "tables", "analysis_overview.csv"))

  summary_lines <- c(
    "# QDESN Dynamic exdqlm Cross-Study Main Comparison Analysis",
    "",
    sprintf("- generated_at: `%s`", as.character(Sys.time())),
    sprintf("- source_run_tag: `%s`", as.character(source_state$source_run_tag)),
    sprintf("- source_mode: `%s`", as.character(source_state$source_mode)),
    sprintf("- source_label: `%s`", as.character(source_state$source_label)),
    sprintf("- final_wave_evidence_run_tag: `%s`", as.character(final_wave_run_tag %||% NA_character_)),
    "",
    "## Authoritative Local Baseline Map",
    .qdesn_validation_df_to_markdown(source_state$local_baseline_map),
    "",
    "## Authoritative Root-Level Overrides",
    .qdesn_validation_df_to_markdown(source_state$root_override_map %||% data.frame(stringsAsFactors = FALSE)),
    "",
    "## Full-Study Overview",
    .qdesn_validation_df_to_markdown(overview),
    "",
    "## Root Readiness",
    sprintf("- comparison_eligible_any_roots: `%d / %d`", sum(as.logical(source_state$root_summary$root_comparison_eligible_any), na.rm = TRUE), nrow(source_state$root_summary)),
    sprintf("- comparison_eligible_full_roots: `%d / %d`", sum(as.logical(source_state$root_summary$root_comparison_eligible_full), na.rm = TRUE), nrow(source_state$root_summary)),
    sprintf("- root_status_fail_n: `%d`", sum(as.character(source_state$root_summary$root_status) == "FAIL", na.rm = TRUE)),
    "",
    "## Fit Signoff By Prior",
    .qdesn_validation_df_to_markdown(fit_prior_summary),
    "",
    "## Fit Signoff / Runtime By Inference + Model",
    .qdesn_validation_df_to_markdown(fit_method_model_summary),
    "",
    "## VB vs MCMC Pair Summary",
    .qdesn_validation_df_to_markdown(pair_axis_summary),
    "",
    "## QDESN vs Reference Runtime / Readiness Delta",
    .qdesn_validation_df_to_markdown(q_vs_ref_axis),
    "",
    "## Prior Head-To-Head Winner Counts",
    .qdesn_validation_df_to_markdown(prior_head_to_head_counts),
    "",
    "## Remaining Documented FAIL Rows",
    .qdesn_validation_df_to_markdown(fail_inventory[, c(
      "root_id", "family", "tau", "fit_size", "prior", "inference", "model", "signoff_reason"
    ), drop = FALSE]),
    "",
    "## Important Interpretation Notes",
    "- Signoff/readiness deltas are directly comparable against the exdqlm reference on the mirrored dynamic surface once the model labels are normalized (`al <-> dqlm`, `exal <-> exdqlm`).",
    "- Runtime is summarized in detail for QDESN. Reference-runtime deltas are only meaningful where the reference inventory has non-missing runtime values; some mirrored reference summaries leave runtime blank.",
    "- Forecast fit-performance metrics (`train_*`, `holdout_*`) are summarized for the QDESN side only.",
    "- The reference-side summary inventory on this surface does not expose matching forecast metric columns, so direct forecast-metric deltas vs exdqlm are not reported here.",
    "",
    sprintf("- comparison_root: `%s`", file.path(output_root, "comparison_vs_reference"))
  )
  .qdesn_validation_write_lines(file.path(output_root, "summary", "qdesn_dynamic_main_comparison_analysis.md"), summary_lines)

  .qdesn_validation_write_json(file.path(output_root, "manifest", "analysis_manifest.json"), list(
    generated_at = as.character(Sys.time()),
    source_run_tag = source_state$source_run_tag,
    source_mode = source_state$source_mode,
    source_label = source_state$source_label,
    final_wave_evidence_run_tag = final_wave_run_tag %||% NA_character_,
    manifest = manifest,
    output_root = normalizePath(output_root, winslash = "/", mustWork = FALSE),
    fit_rows = nrow(source_state$fit_summary),
    root_rows = nrow(source_state$root_summary),
    fit_fail_rows = sum(as.character(source_state$fit_summary$signoff_grade) == "FAIL", na.rm = TRUE),
    root_compare_any_n = sum(as.logical(source_state$root_summary$root_comparison_eligible_any), na.rm = TRUE),
    root_compare_full_n = sum(as.logical(source_state$root_summary$root_comparison_eligible_full), na.rm = TRUE)
  ))

  invisible(list(
    pairwise_vb_vs_mcmc = pairwise_vb_vs_mcmc,
    model_pair_signoff = model_pair_signoff,
    root_inventory = root_inventory,
    fail_inventory = fail_inventory,
    fit_surface_summary = fit_surface_summary,
    fit_axis_summary = fit_axis_summary,
    fit_prior_summary = fit_prior_summary,
    fit_method_model_summary = fit_method_model_summary,
    pair_surface_summary = pair_surface_summary,
    pair_axis_summary = pair_axis_summary,
    model_axis_summary = model_axis_summary,
    root_surface_summary = root_surface_summary,
    root_axis_summary = root_axis_summary,
    q_vs_ref_surface = q_vs_ref_surface,
    q_vs_ref_axis = q_vs_ref_axis,
    prior_head_to_head = prior_head_to_head,
    prior_head_to_head_counts = prior_head_to_head_counts,
    compare = compare_obj
  ))
}

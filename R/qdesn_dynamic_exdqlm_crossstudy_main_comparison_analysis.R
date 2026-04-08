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
    effective_fit_size = as.integer(row$effective_fit_size[1L] %||% row$fit_size[1L]),
    source_total_size = as.integer(row$source_total_size[1L] %||% row$fit_size[1L]),
    source_window_label = as.character(row$source_window_label[1L] %||% NA_character_),
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
    c("runtime_sec_per_1k_eval_mean", "rhs_ns_minus_ridge"),
    c("train_qtrue_mae_mean", "rhs_ns_minus_ridge"),
    c("train_qtrue_rmse_mean", "rhs_ns_minus_ridge"),
    c("train_qtrue_bias_mean", "rhs_ns_minus_ridge"),
    c("train_qtrue_corr_mean", "rhs_ns_minus_ridge"),
    c("train_pinball_tau_mean", "rhs_ns_minus_ridge"),
    c("train_coverage_minus_tau_mean", "rhs_ns_minus_ridge"),
    c("train_coverage_error_mean", "rhs_ns_minus_ridge")
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
    qtrue_rmse_delta <- suppressWarnings(as.numeric(row[["train_qtrue_rmse_mean_rhs_ns_minus_ridge"]]))
    pinball_delta <- suppressWarnings(as.numeric(row[["train_pinball_tau_mean_rhs_ns_minus_ridge"]]))
    coverage_error_delta <- suppressWarnings(as.numeric(row[["train_coverage_error_mean_rhs_ns_minus_ridge"]]))
    runtime_delta <- suppressWarnings(as.numeric(row[["runtime_sec_per_1k_eval_mean_rhs_ns_minus_ridge"]]))
    if (is.finite(fail_delta) && fail_delta < 0) return("rhs_ns")
    if (is.finite(fail_delta) && fail_delta > 0) return("ridge")
    if (is.finite(elig_delta) && elig_delta > 0) return("rhs_ns")
    if (is.finite(elig_delta) && elig_delta < 0) return("ridge")
    if (is.finite(qtrue_rmse_delta) && qtrue_rmse_delta < 0) return("rhs_ns")
    if (is.finite(qtrue_rmse_delta) && qtrue_rmse_delta > 0) return("ridge")
    if (is.finite(pinball_delta) && pinball_delta < 0) return("rhs_ns")
    if (is.finite(pinball_delta) && pinball_delta > 0) return("ridge")
    if (is.finite(coverage_error_delta) && coverage_error_delta < 0) return("rhs_ns")
    if (is.finite(coverage_error_delta) && coverage_error_delta > 0) return("ridge")
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

.qdesn_dynamic_maincmp_lookup_grid_row <- function(root_id, grid) {
  if (is.null(grid) || !nrow(grid)) return(NULL)
  idx <- match(as.character(root_id)[1L], as.character(grid$root_id))
  if (is.na(idx)) return(NULL)
  as.list(grid[idx, , drop = FALSE])
}

.qdesn_dynamic_maincmp_metric_recompute_bundle <- function(fit_file,
                                                           root_id,
                                                           grid,
                                                           defaults,
                                                           fit_row = NULL,
                                                           summary_cache,
                                                           truth_cache) {
  fit_file <- as.character(fit_file %||% "")[1L]
  root_id <- as.character(root_id %||% "")[1L]
  if (!nzchar(fit_file) || !file.exists(fit_file) || !nzchar(root_id)) return(NULL)

  truth_key <- root_id
  if (!exists(truth_key, envir = truth_cache, inherits = FALSE)) {
    grid_row <- .qdesn_dynamic_maincmp_lookup_grid_row(root_id, grid)
    if (is.null(grid_row)) {
      assign(truth_key, NULL, envir = truth_cache)
    } else {
      root_spec <- qdesn_dynamic_crossstudy_enrich_root_spec(grid_row, defaults)
      assign(truth_key, .qdesn_dynamic_crossstudy_source_truth_bundle(root_spec), envir = truth_cache)
    }
  }
  truth_bundle <- get(truth_key, envir = truth_cache, inherits = FALSE)
  if (is.null(truth_bundle)) return(NULL)

  if (!exists(fit_file, envir = summary_cache, inherits = FALSE)) {
    method_dir <- dirname(dirname(fit_file))
    summary_obj <- tryCatch(
      collect_pipeline_run_summary(method_dir),
      error = function(...) NULL
    )
    assign(fit_file, summary_obj, envir = summary_cache)
  }
  summary_obj <- get(fit_file, envir = summary_cache, inherits = FALSE)
  if (is.null(summary_obj)) return(NULL)

  metrics <- .qdesn_static_crossstudy_collect_metrics_from_summary(summary_obj, truth_bundle$q_true)
  runtime_candidates <- suppressWarnings(as.numeric(c(
    summary_obj$summary$fit_runtime_seconds[1L] %||% NA_real_,
    summary_obj$summary$wall_seconds[1L] %||% NA_real_,
    fit_row$runtime_sec[1L] %||% NA_real_,
    fit_row$fit_runtime_seconds[1L] %||% NA_real_
  )))
  runtime_candidates <- runtime_candidates[is.finite(runtime_candidates) & runtime_candidates >= 0]
  runtime_sec <- if (length(runtime_candidates)) runtime_candidates[1L] else NA_real_
  total_n_eval <- as.integer((metrics$train$n_eval %||% 0L) + (metrics$holdout$n_eval %||% 0L))

  list(
    train_n_eval = as.integer(metrics$train$n_eval),
    train_mae = as.numeric(metrics$train$mae),
    train_rmse = as.numeric(metrics$train$rmse),
    train_bias = as.numeric(metrics$train$bias),
    train_corr = as.numeric(metrics$train$corr),
    train_qtrue_mae = as.numeric(metrics$train$mae),
    train_qtrue_rmse = as.numeric(metrics$train$rmse),
    train_qtrue_bias = as.numeric(metrics$train$bias),
    train_qtrue_corr = as.numeric(metrics$train$corr),
    train_qtrue_median_ae = as.numeric(metrics$train$median_ae),
    train_qtrue_p90_ae = as.numeric(metrics$train$p90_ae),
    train_pinball_tau = as.numeric(metrics$train_quantile$pinball_tau),
    train_coverage = as.numeric(metrics$train_quantile$coverage),
    train_coverage_minus_tau = as.numeric(metrics$train_quantile$coverage_minus_tau),
    train_coverage_error = as.numeric(metrics$train_quantile$coverage_error),
    holdout_n_eval = as.integer(metrics$holdout$n_eval),
    holdout_mae = as.numeric(metrics$holdout$mae),
    holdout_rmse = as.numeric(metrics$holdout$rmse),
    holdout_bias = as.numeric(metrics$holdout$bias),
    holdout_corr = as.numeric(metrics$holdout$corr),
    holdout_qtrue_mae = as.numeric(metrics$holdout$mae),
    holdout_qtrue_rmse = as.numeric(metrics$holdout$rmse),
    holdout_qtrue_bias = as.numeric(metrics$holdout$bias),
    holdout_qtrue_corr = as.numeric(metrics$holdout$corr),
    holdout_qtrue_median_ae = as.numeric(metrics$holdout$median_ae),
    holdout_qtrue_p90_ae = as.numeric(metrics$holdout$p90_ae),
    holdout_pinball_tau = as.numeric(metrics$holdout_quantile$pinball_tau),
    holdout_coverage = as.numeric(metrics$holdout_quantile$coverage),
    holdout_coverage_minus_tau = as.numeric(metrics$holdout_quantile$coverage_minus_tau),
    holdout_coverage_error = as.numeric(metrics$holdout_quantile$coverage_error),
    total_n_eval = total_n_eval,
    runtime_sec_per_1k_eval = if (is.finite(runtime_sec) && is.finite(total_n_eval) && total_n_eval > 0L) {
      1000 * runtime_sec / total_n_eval
    } else {
      NA_real_
    },
    runtime_sec_per_1k_train_eval = if (is.finite(runtime_sec) &&
      is.finite(metrics$train$n_eval) &&
      metrics$train$n_eval > 0L) {
      1000 * runtime_sec / metrics$train$n_eval
    } else {
      NA_real_
    }
  )
}

qdesn_dynamic_maincmp_refresh_fit_metrics <- function(fit_summary,
                                                      grid,
                                                      defaults) {
  fit_summary <- as.data.frame(fit_summary, stringsAsFactors = FALSE)
  if (!nrow(fit_summary)) return(fit_summary)

  metric_cols <- c(
    "train_n_eval",
    "train_mae", "train_rmse", "train_bias", "train_corr",
    "train_qtrue_mae", "train_qtrue_rmse", "train_qtrue_bias", "train_qtrue_corr",
    "train_qtrue_median_ae", "train_qtrue_p90_ae",
    "train_pinball_tau", "train_coverage", "train_coverage_minus_tau", "train_coverage_error",
    "holdout_n_eval",
    "holdout_mae", "holdout_rmse", "holdout_bias", "holdout_corr",
    "holdout_qtrue_mae", "holdout_qtrue_rmse", "holdout_qtrue_bias", "holdout_qtrue_corr",
    "holdout_qtrue_median_ae", "holdout_qtrue_p90_ae",
    "holdout_pinball_tau", "holdout_coverage", "holdout_coverage_minus_tau", "holdout_coverage_error",
    "total_n_eval", "runtime_sec_per_1k_eval", "runtime_sec_per_1k_train_eval"
  )
  for (nm in setdiff(metric_cols, names(fit_summary))) fit_summary[[nm]] <- NA_real_

  summary_cache <- new.env(parent = emptyenv())
  truth_cache <- new.env(parent = emptyenv())
  for (i in seq_len(nrow(fit_summary))) {
    bundle <- .qdesn_dynamic_maincmp_metric_recompute_bundle(
      fit_file = fit_summary$fit_file[i] %||% NA_character_,
      root_id = fit_summary$root_id[i] %||% NA_character_,
      grid = grid,
      defaults = defaults,
      fit_row = fit_summary[i, , drop = FALSE],
      summary_cache = summary_cache,
      truth_cache = truth_cache
    )
    if (is.null(bundle)) next
    for (nm in names(bundle)) fit_summary[[nm]][i] <- bundle[[nm]]
  }

  fit_summary
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

  source_state$fit_summary <- qdesn_dynamic_maincmp_refresh_fit_metrics(
    fit_summary = source_state$fit_summary,
    grid = source_state$grid %||% NULL,
    defaults = source_state$defaults %||% defaults
  )

  pair_tables <- qdesn_dynamic_maincmp_rebuild_pair_tables(
    fit_summary = source_state$fit_summary,
    root_summary = source_state$root_summary
  )
  pairwise_vb_vs_mcmc <- pair_tables$pairwise_vb_vs_mcmc
  model_pair_signoff <- pair_tables$model_pair_signoff
  root_inventory <- qdesn_dynamic_maincmp_root_inventory(source_state$root_summary, source_state$fit_summary)
  fail_inventory <- source_state$fit_summary[as.character(source_state$fit_summary$signoff_grade) == "FAIL", , drop = FALSE]
  fit_numeric_cols <- c(
    "runtime_sec", "fit_runtime_seconds",
    "total_n_eval", "runtime_sec_per_1k_eval", "runtime_sec_per_1k_train_eval",
    "holdout_mae", "holdout_rmse", "holdout_bias", "holdout_corr",
    "train_mae", "train_rmse", "train_bias", "train_corr",
    "train_qtrue_mae", "train_qtrue_rmse", "train_qtrue_bias", "train_qtrue_corr",
    "train_qtrue_median_ae", "train_qtrue_p90_ae",
    "train_pinball_tau", "train_coverage", "train_coverage_minus_tau", "train_coverage_error",
    "holdout_qtrue_mae", "holdout_qtrue_rmse", "holdout_qtrue_bias", "holdout_qtrue_corr",
    "holdout_qtrue_median_ae", "holdout_qtrue_p90_ae",
    "holdout_pinball_tau", "holdout_coverage", "holdout_coverage_minus_tau", "holdout_coverage_error"
  )

  fit_surface_summary <- .qdesn_dynamic_maincmp_metric_summary(
    source_state$fit_summary,
    group_cols = c("scenario", "root_kind", "family", "tau", "fit_size", "prior", "inference", "model"),
    grade_col = "signoff_grade",
    eligible_col = "comparison_eligible",
    numeric_cols = fit_numeric_cols
  )
  if (nrow(fit_surface_summary) && "model" %in% names(fit_surface_summary)) {
    fit_surface_summary$canonical_model <- .qdesn_dynamic_maincmp_canonical_model(fit_surface_summary$model)
  }
  fit_axis_summary <- .qdesn_dynamic_maincmp_metric_summary(
    source_state$fit_summary,
    group_cols = c("prior", "inference", "model", "fit_size"),
    grade_col = "signoff_grade",
    eligible_col = "comparison_eligible",
    numeric_cols = fit_numeric_cols
  )
  if (nrow(fit_axis_summary) && "model" %in% names(fit_axis_summary)) {
    fit_axis_summary$canonical_model <- .qdesn_dynamic_maincmp_canonical_model(fit_axis_summary$model)
  }
  fit_inference_summary <- .qdesn_dynamic_maincmp_metric_summary(
    source_state$fit_summary,
    group_cols = c("inference"),
    grade_col = "signoff_grade",
    eligible_col = "comparison_eligible",
    numeric_cols = fit_numeric_cols
  )
  fit_model_summary <- .qdesn_dynamic_maincmp_metric_summary(
    source_state$fit_summary,
    group_cols = c("model"),
    grade_col = "signoff_grade",
    eligible_col = "comparison_eligible",
    numeric_cols = fit_numeric_cols
  )
  fit_fit_size_summary <- .qdesn_dynamic_maincmp_metric_summary(
    source_state$fit_summary,
    group_cols = c("fit_size"),
    grade_col = "signoff_grade",
    eligible_col = "comparison_eligible",
    numeric_cols = fit_numeric_cols
  )
  fit_prior_summary <- .qdesn_dynamic_maincmp_metric_summary(
    source_state$fit_summary,
    group_cols = c("prior"),
    grade_col = "signoff_grade",
    eligible_col = "comparison_eligible",
    numeric_cols = fit_numeric_cols
  )
  fit_family_summary <- .qdesn_dynamic_maincmp_metric_summary(
    source_state$fit_summary,
    group_cols = c("family"),
    grade_col = "signoff_grade",
    eligible_col = "comparison_eligible",
    numeric_cols = fit_numeric_cols
  )
  fit_tau_summary <- .qdesn_dynamic_maincmp_metric_summary(
    source_state$fit_summary,
    group_cols = c("tau"),
    grade_col = "signoff_grade",
    eligible_col = "comparison_eligible",
    numeric_cols = fit_numeric_cols
  )
  fit_method_model_summary <- .qdesn_dynamic_maincmp_metric_summary(
    source_state$fit_summary,
    group_cols = c("inference", "model"),
    grade_col = "signoff_grade",
    eligible_col = "comparison_eligible",
    numeric_cols = fit_numeric_cols
  )

  pair_surface_summary <- .qdesn_dynamic_maincmp_metric_summary(
    pairwise_vb_vs_mcmc,
    group_cols = c("scenario", "root_kind", "family", "tau", "fit_size", "prior", "model"),
    grade_col = "algorithm_pair_signoff_grade",
    eligible_col = "algorithm_pair_comparison_eligible",
    numeric_cols = c(
      "runtime_ratio_mcmc_vs_vb", "mae_delta_mcmc_minus_vb", "rmse_delta_mcmc_minus_vb",
      "bias_delta_mcmc_minus_vb", "corr_delta_mcmc_minus_vb",
      "train_qtrue_mae_delta_mcmc_minus_vb", "train_qtrue_rmse_delta_mcmc_minus_vb",
      "train_qtrue_bias_delta_mcmc_minus_vb", "train_qtrue_corr_delta_mcmc_minus_vb",
      "train_qtrue_median_ae_delta_mcmc_minus_vb", "train_qtrue_p90_ae_delta_mcmc_minus_vb",
      "train_pinball_tau_delta_mcmc_minus_vb", "train_coverage_delta_mcmc_minus_vb",
      "train_coverage_minus_tau_delta_mcmc_minus_vb", "train_coverage_error_delta_mcmc_minus_vb",
      "runtime_sec_per_1k_eval_ratio_mcmc_vs_vb",
      "holdout_qtrue_mae_delta_mcmc_minus_vb", "holdout_qtrue_rmse_delta_mcmc_minus_vb",
      "holdout_pinball_tau_delta_mcmc_minus_vb", "holdout_coverage_delta_mcmc_minus_vb",
      "holdout_coverage_minus_tau_delta_mcmc_minus_vb",
      "holdout_coverage_error_delta_mcmc_minus_vb"
    )
  )
  pair_axis_summary <- .qdesn_dynamic_maincmp_metric_summary(
    pairwise_vb_vs_mcmc,
    group_cols = c("prior", "model", "fit_size"),
    grade_col = "algorithm_pair_signoff_grade",
    eligible_col = "algorithm_pair_comparison_eligible",
    numeric_cols = c(
      "runtime_ratio_mcmc_vs_vb", "mae_delta_mcmc_minus_vb", "rmse_delta_mcmc_minus_vb",
      "bias_delta_mcmc_minus_vb", "corr_delta_mcmc_minus_vb",
      "train_qtrue_mae_delta_mcmc_minus_vb", "train_qtrue_rmse_delta_mcmc_minus_vb",
      "train_qtrue_bias_delta_mcmc_minus_vb", "train_qtrue_corr_delta_mcmc_minus_vb",
      "train_qtrue_median_ae_delta_mcmc_minus_vb", "train_qtrue_p90_ae_delta_mcmc_minus_vb",
      "train_pinball_tau_delta_mcmc_minus_vb", "train_coverage_delta_mcmc_minus_vb",
      "train_coverage_minus_tau_delta_mcmc_minus_vb", "train_coverage_error_delta_mcmc_minus_vb",
      "runtime_sec_per_1k_eval_ratio_mcmc_vs_vb",
      "holdout_qtrue_mae_delta_mcmc_minus_vb", "holdout_qtrue_rmse_delta_mcmc_minus_vb",
      "holdout_pinball_tau_delta_mcmc_minus_vb", "holdout_coverage_delta_mcmc_minus_vb",
      "holdout_coverage_minus_tau_delta_mcmc_minus_vb",
      "holdout_coverage_error_delta_mcmc_minus_vb"
    )
  )
  model_axis_summary <- .qdesn_dynamic_maincmp_metric_summary(
    model_pair_signoff,
    group_cols = c("prior", "inference", "fit_size"),
    grade_col = "pair_signoff_grade",
    eligible_col = "pair_comparison_eligible",
    numeric_cols = c(
      "baseline_runtime_sec", "extended_runtime_sec",
      "runtime_sec_delta_extended_minus_baseline", "runtime_ratio_extended_vs_baseline",
      "train_mae_delta_extended_minus_baseline", "train_rmse_delta_extended_minus_baseline", "train_corr_delta_extended_minus_baseline",
      "train_qtrue_mae_delta_extended_minus_baseline", "train_qtrue_rmse_delta_extended_minus_baseline",
      "train_qtrue_bias_delta_extended_minus_baseline", "train_qtrue_corr_delta_extended_minus_baseline",
      "train_qtrue_median_ae_delta_extended_minus_baseline", "train_qtrue_p90_ae_delta_extended_minus_baseline",
      "train_pinball_tau_delta_extended_minus_baseline",
      "train_coverage_minus_tau_delta_extended_minus_baseline",
      "train_coverage_error_delta_extended_minus_baseline",
      "holdout_qtrue_mae_delta_extended_minus_baseline", "holdout_qtrue_rmse_delta_extended_minus_baseline",
      "holdout_pinball_tau_delta_extended_minus_baseline",
      "holdout_coverage_minus_tau_delta_extended_minus_baseline",
      "holdout_coverage_error_delta_extended_minus_baseline"
    )
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
  .qdesn_validation_write_df(fit_inference_summary, file.path(output_root, "tables", "authoritative_fit_inference_summary.csv"))
  .qdesn_validation_write_df(fit_model_summary, file.path(output_root, "tables", "authoritative_fit_model_summary.csv"))
  .qdesn_validation_write_df(fit_fit_size_summary, file.path(output_root, "tables", "authoritative_fit_fit_size_summary.csv"))
  .qdesn_validation_write_df(fit_prior_summary, file.path(output_root, "tables", "authoritative_fit_prior_summary.csv"))
  .qdesn_validation_write_df(fit_family_summary, file.path(output_root, "tables", "authoritative_fit_family_summary.csv"))
  .qdesn_validation_write_df(fit_tau_summary, file.path(output_root, "tables", "authoritative_fit_tau_summary.csv"))
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

  source_totals <- suppressWarnings(as.numeric(source_state$fit_summary$source_total_size %||% NA_real_))
  fit_sizes <- suppressWarnings(as.numeric(source_state$fit_summary$fit_size %||% NA_real_))
  effective_source_window_contract <- length(source_totals) &&
    length(fit_sizes) &&
    any(is.finite(source_totals) & is.finite(fit_sizes) & source_totals > fit_sizes, na.rm = TRUE)

  case_table_cols <- intersect(c(
    "dataset_cell_id", "root_id", "scenario", "root_kind", "family", "tau", "fit_size",
    "effective_fit_size", "source_total_size", "source_window_label",
    "prior", "inference", "model", "signoff_grade", "comparison_eligible",
    "runtime_sec", "runtime_sec_per_1k_eval", "runtime_sec_per_1k_train_eval",
    "train_n_eval", "train_draw_n",
    "train_qtrue_mae", "train_qtrue_rmse", "train_qtrue_bias", "train_qtrue_corr",
    "train_qtrue_mae_post_sd", "train_qtrue_mae_post_q05", "train_qtrue_mae_post_q50", "train_qtrue_mae_post_q95",
    "train_qtrue_rmse_post_sd", "train_qtrue_rmse_post_q05", "train_qtrue_rmse_post_q50", "train_qtrue_rmse_post_q95",
    "train_qtrue_bias_post_sd", "train_qtrue_bias_post_q05", "train_qtrue_bias_post_q50", "train_qtrue_bias_post_q95",
    "train_qtrue_corr_post_sd", "train_qtrue_corr_post_q05", "train_qtrue_corr_post_q50", "train_qtrue_corr_post_q95",
    "train_point_qtrue_mae", "train_point_qtrue_rmse", "train_point_qtrue_bias", "train_point_qtrue_corr",
    "train_qtrue_median_ae", "train_qtrue_p90_ae",
    "train_pinball_tau", "train_coverage", "train_coverage_minus_tau", "train_coverage_error",
    "train_pinball_tau_post_sd", "train_pinball_tau_post_q05", "train_pinball_tau_post_q50", "train_pinball_tau_post_q95",
    "train_coverage_post_sd", "train_coverage_post_q05", "train_coverage_post_q50", "train_coverage_post_q95",
    "train_coverage_minus_tau_post_sd", "train_coverage_minus_tau_post_q05", "train_coverage_minus_tau_post_q50", "train_coverage_minus_tau_post_q95",
    "train_coverage_error_post_sd", "train_coverage_error_post_q05", "train_coverage_error_post_q50", "train_coverage_error_post_q95",
    "train_point_pinball_tau", "train_point_coverage", "train_point_coverage_minus_tau", "train_point_coverage_error",
    "holdout_n_eval", "holdout_draw_n", "holdout_qtrue_mae", "holdout_qtrue_rmse", "holdout_qtrue_bias",
    "holdout_qtrue_corr", "holdout_pinball_tau", "holdout_coverage",
    "holdout_coverage_minus_tau", "holdout_coverage_error",
    "holdout_qtrue_mae_post_sd", "holdout_qtrue_mae_post_q05", "holdout_qtrue_mae_post_q50", "holdout_qtrue_mae_post_q95",
    "holdout_qtrue_rmse_post_sd", "holdout_qtrue_rmse_post_q05", "holdout_qtrue_rmse_post_q50", "holdout_qtrue_rmse_post_q95",
    "holdout_qtrue_bias_post_sd", "holdout_qtrue_bias_post_q05", "holdout_qtrue_bias_post_q50", "holdout_qtrue_bias_post_q95",
    "holdout_qtrue_corr_post_sd", "holdout_qtrue_corr_post_q05", "holdout_qtrue_corr_post_q50", "holdout_qtrue_corr_post_q95",
    "holdout_point_qtrue_mae", "holdout_point_qtrue_rmse", "holdout_point_qtrue_bias", "holdout_point_qtrue_corr",
    "holdout_pinball_tau_post_sd", "holdout_pinball_tau_post_q05", "holdout_pinball_tau_post_q50", "holdout_pinball_tau_post_q95",
    "holdout_coverage_post_sd", "holdout_coverage_post_q05", "holdout_coverage_post_q50", "holdout_coverage_post_q95",
    "holdout_coverage_minus_tau_post_sd", "holdout_coverage_minus_tau_post_q05", "holdout_coverage_minus_tau_post_q50", "holdout_coverage_minus_tau_post_q95",
    "holdout_coverage_error_post_sd", "holdout_coverage_error_post_q05", "holdout_coverage_error_post_q50", "holdout_coverage_error_post_q95",
    "holdout_point_pinball_tau", "holdout_point_coverage", "holdout_point_coverage_minus_tau", "holdout_point_coverage_error",
    "status", "finite_ok", "domain_ok", "signoff_reason"
  ), names(source_state$fit_summary))
  case_table <- source_state$fit_summary[, case_table_cols, drop = FALSE]
  if (nrow(case_table)) {
    case_table <- case_table[order(
      case_table$scenario,
      case_table$family,
      case_table$tau,
      case_table$fit_size,
      case_table$prior,
      case_table$inference,
      case_table$model
    ), , drop = FALSE]
    rownames(case_table) <- NULL
  }
  case_table_readable <- case_table
  if (nrow(case_table_readable)) {
    numeric_case_cols <- names(case_table_readable)[vapply(case_table_readable, is.numeric, logical(1))]
    for (nm in numeric_case_cols) {
      case_table_readable[[nm]] <- ifelse(
        is.finite(case_table_readable[[nm]]),
        round(case_table_readable[[nm]], digits = 6),
        case_table_readable[[nm]]
      )
    }
  }
  .qdesn_validation_write_df(case_table, file.path(output_root, "tables", "authoritative_fit_case_table.csv"))
  .qdesn_validation_write_df(case_table_readable, file.path(output_root, "tables", "authoritative_fit_case_table_readable.csv"))

  fit_inference_compact <- fit_inference_summary[, intersect(c(
    "inference", "n_rows", "n_pass", "n_warn", "n_fail", "pass_rate",
    "runtime_sec_mean", "runtime_sec_median", "runtime_sec_per_1k_eval_mean",
    "train_qtrue_mae_mean", "train_qtrue_rmse_mean", "train_qtrue_bias_mean", "train_qtrue_corr_mean",
    "train_qtrue_median_ae_mean", "train_qtrue_p90_ae_mean",
    "train_pinball_tau_mean", "train_coverage_mean", "train_coverage_minus_tau_mean", "train_coverage_error_mean"
  ), names(fit_inference_summary)), drop = FALSE]
  fit_model_compact <- fit_model_summary[, intersect(c(
    "model", "n_rows", "n_pass", "n_warn", "n_fail", "pass_rate",
    "runtime_sec_mean", "runtime_sec_median", "runtime_sec_per_1k_eval_mean",
    "train_qtrue_mae_mean", "train_qtrue_rmse_mean", "train_qtrue_bias_mean", "train_qtrue_corr_mean",
    "train_qtrue_median_ae_mean", "train_qtrue_p90_ae_mean",
    "train_pinball_tau_mean", "train_coverage_mean", "train_coverage_minus_tau_mean", "train_coverage_error_mean"
  ), names(fit_model_summary)), drop = FALSE]
  fit_prior_compact <- fit_prior_summary[, intersect(c(
    "prior", "n_rows", "n_pass", "n_warn", "n_fail", "pass_rate",
    "runtime_sec_mean", "runtime_sec_median", "runtime_sec_per_1k_eval_mean",
    "train_qtrue_mae_mean", "train_qtrue_rmse_mean", "train_qtrue_bias_mean", "train_qtrue_corr_mean",
    "train_qtrue_median_ae_mean", "train_qtrue_p90_ae_mean",
    "train_pinball_tau_mean", "train_coverage_mean", "train_coverage_minus_tau_mean", "train_coverage_error_mean"
  ), names(fit_prior_summary)), drop = FALSE]
  fit_family_compact <- fit_family_summary[, intersect(c(
    "family", "n_rows", "n_pass", "n_warn", "n_fail", "pass_rate",
    "runtime_sec_mean", "runtime_sec_median", "runtime_sec_per_1k_eval_mean",
    "train_qtrue_mae_mean", "train_qtrue_rmse_mean", "train_qtrue_bias_mean",
    "train_qtrue_median_ae_mean", "train_qtrue_p90_ae_mean",
    "train_pinball_tau_mean", "train_coverage_mean", "train_coverage_minus_tau_mean", "train_coverage_error_mean"
  ), names(fit_family_summary)), drop = FALSE]
  fit_tau_compact <- fit_tau_summary[, intersect(c(
    "tau", "n_rows", "n_pass", "n_warn", "n_fail", "pass_rate",
    "runtime_sec_mean", "runtime_sec_median", "runtime_sec_per_1k_eval_mean",
    "train_qtrue_mae_mean", "train_qtrue_rmse_mean", "train_qtrue_bias_mean",
    "train_qtrue_median_ae_mean", "train_qtrue_p90_ae_mean",
    "train_pinball_tau_mean", "train_coverage_mean", "train_coverage_minus_tau_mean", "train_coverage_error_mean"
  ), names(fit_tau_summary)), drop = FALSE]
  fit_method_model_compact <- fit_method_model_summary[, intersect(c(
    "inference", "model", "n_rows", "n_pass", "n_warn", "n_fail", "pass_rate",
    "runtime_sec_mean", "runtime_sec_median", "runtime_sec_per_1k_eval_mean",
    "train_qtrue_mae_mean", "train_qtrue_rmse_mean", "train_qtrue_bias_mean", "train_qtrue_corr_mean",
    "train_qtrue_median_ae_mean", "train_qtrue_p90_ae_mean",
    "train_pinball_tau_mean", "train_coverage_mean", "train_coverage_minus_tau_mean", "train_coverage_error_mean"
  ), names(fit_method_model_summary)), drop = FALSE]
  pair_axis_compact <- pair_axis_summary[, intersect(c(
    "prior", "model", "fit_size", "n_rows", "n_pass", "n_warn", "n_fail",
    "runtime_ratio_mcmc_vs_vb_mean", "runtime_ratio_mcmc_vs_vb_median",
    "runtime_sec_per_1k_eval_ratio_mcmc_vs_vb_mean",
    "train_qtrue_mae_delta_mcmc_minus_vb_mean", "train_qtrue_rmse_delta_mcmc_minus_vb_mean",
    "train_qtrue_bias_delta_mcmc_minus_vb_mean", "train_qtrue_corr_delta_mcmc_minus_vb_mean",
    "train_qtrue_median_ae_delta_mcmc_minus_vb_mean", "train_qtrue_p90_ae_delta_mcmc_minus_vb_mean",
    "train_pinball_tau_delta_mcmc_minus_vb_mean",
    "train_coverage_minus_tau_delta_mcmc_minus_vb_mean",
    "train_coverage_error_delta_mcmc_minus_vb_mean"
  ), names(pair_axis_summary)), drop = FALSE]
  model_axis_compact <- model_axis_summary[, intersect(c(
    "prior", "inference", "fit_size", "n_rows", "n_pass", "n_warn", "n_fail",
    "runtime_ratio_extended_vs_baseline_mean",
    "train_qtrue_mae_delta_extended_minus_baseline_mean",
    "train_qtrue_rmse_delta_extended_minus_baseline_mean",
    "train_qtrue_bias_delta_extended_minus_baseline_mean",
    "train_qtrue_corr_delta_extended_minus_baseline_mean",
    "train_qtrue_median_ae_delta_extended_minus_baseline_mean",
    "train_qtrue_p90_ae_delta_extended_minus_baseline_mean",
    "train_pinball_tau_delta_extended_minus_baseline_mean",
    "train_coverage_minus_tau_delta_extended_minus_baseline_mean",
    "train_coverage_error_delta_extended_minus_baseline_mean"
  ), names(model_axis_summary)), drop = FALSE]

  .qdesn_validation_write_df(fit_inference_compact, file.path(output_root, "tables", "authoritative_fit_inference_compact.csv"))
  .qdesn_validation_write_df(fit_model_compact, file.path(output_root, "tables", "authoritative_fit_model_compact.csv"))
  .qdesn_validation_write_df(fit_prior_compact, file.path(output_root, "tables", "authoritative_fit_prior_compact.csv"))
  .qdesn_validation_write_df(fit_family_compact, file.path(output_root, "tables", "authoritative_fit_family_compact.csv"))
  .qdesn_validation_write_df(fit_tau_compact, file.path(output_root, "tables", "authoritative_fit_tau_compact.csv"))
  .qdesn_validation_write_df(fit_method_model_compact, file.path(output_root, "tables", "authoritative_fit_method_model_compact.csv"))
  .qdesn_validation_write_df(pair_axis_compact, file.path(output_root, "tables", "authoritative_pair_axis_compact.csv"))
  .qdesn_validation_write_df(model_axis_compact, file.path(output_root, "tables", "authoritative_model_axis_compact.csv"))
  .qdesn_validation_write_lines(
    file.path(output_root, "summary", "qdesn_dynamic_main_comparison_case_table.md"),
    c(
      "# QDESN Dynamic Main Comparison Case Table",
      "",
      sprintf("- generated_at: `%s`", as.character(Sys.time())),
      sprintf("- source_run_tag: `%s`", as.character(source_state$source_run_tag)),
      sprintf("- case_rows: `%d`", nrow(case_table_readable)),
      "",
      "## 144-Row Case Table",
      .qdesn_validation_df_to_markdown(case_table_readable)
    )
  )

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
    "## Primary Goodness-Of-Fit By Inference (train/fitted path; `qhat` vs `q_true`, plus quantile calibration on `y`)",
    .qdesn_validation_df_to_markdown(fit_inference_compact),
    "",
    "## Primary Goodness-Of-Fit By Model (train/fitted path)",
    .qdesn_validation_df_to_markdown(fit_model_compact),
    "",
    "## Primary Goodness-Of-Fit By Prior (train/fitted path)",
    .qdesn_validation_df_to_markdown(fit_prior_compact),
    "",
    "## Primary Goodness-Of-Fit By Family (train/fitted path)",
    .qdesn_validation_df_to_markdown(fit_family_compact),
    "",
    "## Primary Goodness-Of-Fit By Tau (train/fitted path)",
    .qdesn_validation_df_to_markdown(fit_tau_compact),
    "",
    "## Fit Signoff / Runtime / Quantile Fit By Inference + Model",
    .qdesn_validation_df_to_markdown(fit_method_model_compact),
    "",
    "## VB vs MCMC Pair Summary (delta metrics are `mcmc - vb`; lower is better for MAE/RMSE/pinball/coverage error)",
    .qdesn_validation_df_to_markdown(pair_axis_compact),
    "",
    "## EXAL vs AL Pair Summary (delta metrics are `exal - al`; lower is better for MAE/RMSE/pinball/coverage error)",
    .qdesn_validation_df_to_markdown(model_axis_compact),
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
    if (isTRUE(effective_source_window_contract)) {
      "- This effective-w300 study uses longer source windows than the mirrored reference (`source_total_size > fit_size`), so QDESN-vs-reference deltas here should be read as descriptive context rather than strict like-for-like causal claims unless the reference is rerun under the same contract."
    } else {
      NULL
    },
    "- Runtime is summarized in detail for QDESN. Reference-runtime deltas are only meaningful where the reference inventory has non-missing runtime values; some mirrored reference summaries leave runtime blank.",
    "- The primary validation window in this pack is the fitted/train path, because the dynamic validation defaults currently use `holdout_n = 1`; holdout metrics remain available in the detailed tables but are secondary for interpretation.",
    "- Oracle quantile-recovery metrics are recomputed directly against the known simulated `q_true` path from the source dynamic cell, rather than only carried forward from archived summaries.",
    "- Quantile calibration against the observed path is summarized via `*_pinball_tau`, `*_coverage`, `*_coverage_minus_tau`, and `*_coverage_error`.",
    "- Runtime is reported both in raw seconds and as normalized cost per 1,000 evaluation points via `runtime_sec_per_1k_eval`.",
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
    fit_inference_summary = fit_inference_summary,
    fit_model_summary = fit_model_summary,
    fit_fit_size_summary = fit_fit_size_summary,
    fit_prior_summary = fit_prior_summary,
    fit_family_summary = fit_family_summary,
    fit_tau_summary = fit_tau_summary,
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

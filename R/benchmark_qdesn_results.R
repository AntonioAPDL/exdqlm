# Result writers and report helpers for benchmark Q-DESN experiments.

bench_qdesn_run_dirs <- function(context, cfg) {
  repo_root <- context$paths$repo_root
  git_info <- context$git %||% bench_git_info(repo_root)
  experiment_name <- cfg$evaluation$experiment_name %||% "qdesn_synth"
  result_root <- bench_abs_path(
    cfg$evaluation$result_root %||% "results/benchmarks/qdesn_synth",
    repo_root = repo_root,
    must_work = FALSE
  )
  stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
  run_name <- sprintf(
    "%s__%s__git-%s",
    experiment_name,
    stamp,
    git_info$sha %||% "nogit"
  )
  run_dir <- file.path(result_root, run_name)

  out <- list(
    result_root = result_root,
    run_dir = run_dir,
    tables_dir = file.path(run_dir, "tables"),
    manifests_dir = file.path(run_dir, "manifest"),
    reports_dir = file.path(run_dir, "reports"),
    figures_dir = file.path(run_dir, "figures"),
    artifacts_dir = file.path(run_dir, "artifacts"),
    logs_dir = file.path(run_dir, "logs")
  )

  invisible(lapply(out[-1L], dir.create, recursive = TRUE, showWarnings = FALSE))
  out
}

bench_qdesn_write_run_manifest <- function(context, cfg, run_dirs, selected_datasets) {
  manifest <- list(
    created_at_utc = bench_timestamp_utc(),
    git = context$git,
    benchmark_paths = list(
      processed_root = bench_rel_path(context$paths$processed_root, context$paths$repo_root),
      metadata_dir = bench_rel_path(context$paths$metadata_dir, context$paths$repo_root),
      panel_dir = bench_rel_path(context$paths$panel_dir, context$paths$repo_root),
      splits_dir = bench_rel_path(context$paths$splits_dir, context$paths$repo_root)
    ),
    selected_datasets = selected_datasets,
    config = cfg
  )

  bench_write_yaml(manifest, file.path(run_dirs$manifests_dir, "run_config.yaml"))
  bench_write_json(manifest, file.path(run_dirs$manifests_dir, "run_config.json"))
  invisible(manifest)
}

bench_qdesn_write_experiment_tables <- function(results, run_dirs) {
  table_map <- list(
    series_metrics = results$series_metrics,
    lead_metrics = results$lead_metrics,
    forecast_summary = results$forecast_summary,
    quantile_model_metrics = results$quantile_model_metrics,
    rhs_diagnostics = results$rhs_diagnostics,
    series_status = results$series_status,
    model_selection_summary = results$model_selection_summary,
    model_selection_detail = results$model_selection_detail,
    candidate_registry = results$candidate_registry,
    m4_comparability = results$m4_comparability
  )

  outputs <- lapply(names(table_map), function(name) {
    dt <- table_map[[name]]
    if (is.null(dt)) dt <- data.table::data.table()
    bench_save_table(dt, file.path(run_dirs$tables_dir, name), write_csv = TRUE, write_rds = TRUE, compress = "gzip")
  })
  names(outputs) <- names(table_map)
  outputs
}

bench_qdesn_safe_tag <- function(x) {
  x <- as.character(x %||% "unknown")[1L]
  x <- gsub("[^A-Za-z0-9]+", "_", x)
  x <- gsub("^_+|_+$", "", x)
  if (!nzchar(x)) "unknown" else x
}

bench_qdesn_write_selection_checkpoint <- function(
  run_dirs,
  dataset_name,
  route_key,
  summary_dt,
  detail_dt,
  quantile_rows,
  rhs_rows,
  completed_candidates = NA_integer_,
  total_candidates = NA_integer_,
  last_candidate_id = NA_character_
) {
  dataset_tag <- bench_qdesn_safe_tag(dataset_name)
  route_tag <- bench_qdesn_safe_tag(route_key)
  stem <- sprintf("selection_checkpoint__%s__%s", dataset_tag, route_tag)

  bench_save_table(
    data.table::as.data.table(summary_dt),
    file.path(run_dirs$tables_dir, paste0(stem, "__summary")),
    write_csv = TRUE,
    write_rds = TRUE,
    compress = "gzip"
  )
  bench_save_table(
    data.table::as.data.table(detail_dt),
    file.path(run_dirs$tables_dir, paste0(stem, "__detail")),
    write_csv = TRUE,
    write_rds = TRUE,
    compress = "gzip"
  )
  bench_save_table(
    data.table::as.data.table(quantile_rows),
    file.path(run_dirs$tables_dir, paste0(stem, "__quantile_model_metrics")),
    write_csv = TRUE,
    write_rds = TRUE,
    compress = "gzip"
  )
  bench_save_table(
    data.table::as.data.table(rhs_rows),
    file.path(run_dirs$tables_dir, paste0(stem, "__rhs_diagnostics")),
    write_csv = TRUE,
    write_rds = TRUE,
    compress = "gzip"
  )

  status <- list(
    written_at_utc = bench_timestamp_utc(),
    dataset = as.character(dataset_name)[1L],
    route_key = as.character(route_key)[1L],
    completed_candidates = as.integer(completed_candidates),
    total_candidates = as.integer(total_candidates),
    last_candidate_id = as.character(last_candidate_id)[1L],
    candidate_ids_seen = unique(as.character(data.table::as.data.table(summary_dt)$candidate_id %||% character(0)))
  )
  bench_write_json(status, file.path(run_dirs$logs_dir, paste0(stem, "__status.json")))
  invisible(status)
}

bench_qdesn_write_failure_state <- function(run_dirs, failure, partial_results = NULL, summary_dt = NULL) {
  failure <- bench_deep_merge(
    list(
      failed_at_utc = bench_timestamp_utc(),
      type = "benchmark_failure",
      message = "Benchmark experiment failed."
    ),
    failure %||% list()
  )

  bench_write_json(failure, file.path(run_dirs$logs_dir, "failure_state.json"))
  bench_write_yaml(failure, file.path(run_dirs$logs_dir, "failure_state.yaml"))

  txt <- c(
    sprintf("type: %s", failure$type %||% "benchmark_failure"),
    sprintf("failed_at_utc: %s", failure$failed_at_utc %||% bench_timestamp_utc()),
    sprintf("message: %s", failure$message %||% "Benchmark experiment failed.")
  )
  if (!is.null(failure$dataset)) {
    txt <- c(txt, sprintf("dataset: %s", as.character(failure$dataset)[1L]))
  }
  if (!is.null(failure$route_key)) {
    txt <- c(txt, sprintf("route_key: %s", as.character(failure$route_key)[1L]))
  }
  if (!is.null(failure$selection_metric)) {
    txt <- c(txt, sprintf("selection_metric: %s", as.character(failure$selection_metric)[1L]))
  }
  if (length(failure$veto_counts)) {
    veto_lines <- vapply(
      names(failure$veto_counts),
      function(nm) sprintf("veto_%s: %s", nm, as.character(failure$veto_counts[[nm]])),
      character(1)
    )
    txt <- c(txt, veto_lines)
  }
  writeLines(txt, file.path(run_dirs$logs_dir, "failure_state.txt"))

  if (!is.null(partial_results)) {
    bench_qdesn_write_experiment_tables(partial_results, run_dirs)
  }
  if (!is.null(summary_dt)) {
    bench_save_table(
      summary_dt,
      file.path(run_dirs$tables_dir, "dataset_model_summary"),
      write_csv = TRUE,
      write_rds = TRUE,
      compress = "gzip"
    )
  }

  invisible(failure)
}

bench_qdesn_save_audit_artifact <- function(run_dirs, result_obj) {
  if (is.null(result_obj$artifacts) || !length(result_obj$artifacts)) {
    return(invisible(NULL))
  }

  art <- result_obj$artifacts
  out_dir <- file.path(run_dirs$artifacts_dir, art$dataset, art$series_id, art$model_name)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  saveRDS(art, file.path(out_dir, "forecast_artifact.rds"), compress = "gzip")
  invisible(out_dir)
}

bench_qdesn_dataset_summary_table <- function(series_metrics) {
  dt <- data.table::as.data.table(series_metrics)
  if (!nrow(dt)) {
    return(data.table::data.table())
  }

  dt[, .(
    n_series = .N,
    crps_mean = mean(crps_mean, na.rm = TRUE),
    pinball_mean = mean(pinball_mean, na.rm = TRUE),
    mae_mean = mean(mae_mean, na.rm = TRUE),
    rmse_mean = mean(rmse_mean, na.rm = TRUE),
    mase_mean = mean(mase_mean, na.rm = TRUE),
    smape_mean = mean(smape_mean, na.rm = TRUE),
    msis95_mean = mean(msis95_mean, na.rm = TRUE),
    coverage95_mean = mean(coverage95_mean, na.rm = TRUE),
    acd95_mean = abs(mean(coverage95_mean, na.rm = TRUE) - 0.95),
    interval_width95_mean = mean(interval_width95_mean, na.rm = TRUE)
  ), by = .(dataset, source_family, model_name)]
}

bench_qdesn_m4_comparability_table <- function(series_metrics) {
  dt <- data.table::as.data.table(series_metrics)
  required_cols <- c("source_family", "dataset", "model_name", "smape_mean", "mase_mean", "msis95_mean", "coverage95_mean")
  if (!nrow(dt) || !all(required_cols %in% names(dt))) {
    return(data.table::data.table())
  }
  dt <- dt[source_family == "m4"]
  if (!nrow(dt)) {
    return(data.table::data.table())
  }

  summarize_block <- function(x, group_label, group_type) {
    out <- x[, .(
      n_series = .N,
      smape_mean = mean(smape_mean, na.rm = TRUE),
      mase_mean = mean(mase_mean, na.rm = TRUE),
      msis95_mean = mean(msis95_mean, na.rm = TRUE),
      coverage95_mean = mean(coverage95_mean, na.rm = TRUE),
      acd95_mean = abs(mean(coverage95_mean, na.rm = TRUE) - 0.95)
    ), by = .(model_name)]
    out[, m4_group := group_label]
    out[, group_type := group_type]
    out
  }

  by_dataset <- dt[, summarize_block(.SD, unique(dataset), "dataset"), by = .(dataset)]
  overall <- summarize_block(dt, "m4_overall", "overall")
  overall[, dataset := "m4_overall"]

  out <- data.table::rbindlist(list(by_dataset, overall), fill = TRUE)
  naive2_ref <- out[model_name == "naive2", .(
    dataset,
    m4_group,
    smape_naive2 = smape_mean,
    mase_naive2 = mase_mean,
    msis95_naive2 = msis95_mean
  )]

  out <- naive2_ref[out, on = .(dataset, m4_group)]
  out[, owa := bench_qdesn_owa_value(smape_mean, mase_mean, smape_naive2, mase_naive2), by = .(dataset, m4_group, model_name)]
  out[, msis95_rel_naive2 := ifelse(is.finite(msis95_naive2) & msis95_naive2 > 0, msis95_mean / msis95_naive2, NA_real_)]
  data.table::setcolorder(out, c(
    "dataset", "m4_group", "group_type", "model_name", "n_series",
    "smape_mean", "mase_mean", "owa",
    "msis95_mean", "msis95_rel_naive2",
    "coverage95_mean", "acd95_mean",
    "smape_naive2", "mase_naive2", "msis95_naive2"
  ))
  data.table::setorder(out, dataset, owa, model_name)
  out
}

# Focused single-quantile debug mode for RHS benchmark failures.

bench_qdesn_quantile_debug_trace_plot <- function(trace_dt, value_col, y_label, out_path, log10_y = FALSE) {
  if (!requireNamespace("ggplot2", quietly = TRUE) || !nrow(trace_dt)) {
    return(invisible(NULL))
  }

  plot_dt <- data.table::copy(data.table::as.data.table(trace_dt))
  p <- ggplot2::ggplot(plot_dt, ggplot2::aes(x = iter, y = .data[[value_col]])) +
    ggplot2::geom_line(linewidth = 0.9, color = "#1f4e79") +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold")
    ) +
    ggplot2::labs(
      title = y_label,
      x = "VB Iteration",
      y = y_label
    )

  warmup_iters <- unique(stats::na.omit(plot_dt$tau_warmup_iters %||% NA_integer_))
  if (length(warmup_iters) == 1L && is.finite(warmup_iters[[1L]]) && warmup_iters[[1L]] > 0L) {
    p <- p + ggplot2::geom_vline(
      xintercept = warmup_iters[[1L]],
      linetype = "dashed",
      linewidth = 0.5,
      color = "#8b0000"
    )
  }

  if (isTRUE(log10_y)) {
    p <- p + ggplot2::scale_y_log10()
  }

  ggplot2::ggsave(out_path, plot = p, width = 8, height = 4.5, dpi = 160)
  invisible(out_path)
}

bench_qdesn_quantile_debug_collapse_row <- function(trace_dt, quantile_row, bundle, candidate_cfg, quantile_p, seed_used) {
  trace_dt <- data.table::as.data.table(trace_dt)
  rhs_cfg <- candidate_cfg$vb_args$beta_rhs %||% list()
  rhs_ctl <- candidate_cfg$vb_args$rhs %||% list()

  tau0 <- as.numeric(rhs_cfg$tau0 %||% NA_real_)
  init_tau <- rhs_cfg$init_tau
  if (is.null(init_tau) && !is.null(rhs_cfg$init_log_tau)) {
    init_tau <- exp(as.numeric(rhs_cfg$init_log_tau))
  }
  if (is.null(init_tau)) {
    init_tau <- tau0
  }
  init_tau <- as.numeric(init_tau %||% NA_real_)
  warmup_iters <- as.integer(rhs_ctl$freeze_tau_warmup_iters %||% rhs_ctl$freeze_tau_iters %||% 0L)

  first_tau_move_iter <- if (nrow(trace_dt)) {
    moved <- trace_dt[iter > warmup_iters & is.finite(delta_log_tau) & abs(delta_log_tau) > 1e-12]
    if (nrow(moved)) as.integer(moved$iter[[1L]]) else NA_integer_
  } else {
    NA_integer_
  }

  first_lower_bound_iter <- if (nrow(trace_dt)) {
    hit <- trace_dt[isTRUE(log_tau_clipped) & log_tau_clip_side == "lo"]
    if (nrow(hit)) as.integer(hit$iter[[1L]]) else NA_integer_
  } else {
    NA_integer_
  }

  first_lower_bound_post_warmup_iter <- if (nrow(trace_dt)) {
    hit <- trace_dt[iter > warmup_iters & isTRUE(log_tau_clipped) & log_tau_clip_side == "lo"]
    if (nrow(hit)) as.integer(hit$iter[[1L]]) else NA_integer_
  } else {
    NA_integer_
  }

  last_row <- if (nrow(trace_dt)) trace_dt[.N] else data.table::data.table()

  data.table::data.table(
    dataset = bundle$dataset,
    source_family = bundle$source_family,
    benchmark_pool = bundle$benchmark_pool,
    route_key = bundle$route_key %||% "global",
    series_id = bundle$series_id,
    stage = bundle$stage,
    candidate_id = candidate_cfg$candidate_id,
    quantile_p = as.numeric(quantile_p),
    quantile_label = bench_qdesn_prob_label(quantile_p),
    seed = as.integer(seed_used),
    tau0 = tau0,
    init_tau = init_tau,
    tau_warmup_iters = warmup_iters,
    thaw_iter = if (warmup_iters > 0L) as.integer(warmup_iters + 1L) else 1L,
    first_tau_move_iter_post_warmup = first_tau_move_iter,
    first_lower_bound_iter = first_lower_bound_iter,
    first_lower_bound_iter_post_warmup = first_lower_bound_post_warmup_iter,
    tau_last = as.numeric(last_row$tau[[1L]] %||% quantile_row$rhs_tau_last[[1L]] %||% NA_real_),
    log_tau_last = as.numeric(last_row$log_tau[[1L]] %||% NA_real_),
    beta_l2_last = as.numeric(last_row$beta_l2[[1L]] %||% quantile_row$rhs_beta_l2_last[[1L]] %||% NA_real_),
    collapse_flag = as.logical(quantile_row$rhs_collapse_flag[[1L]] %||% FALSE),
    near_bound_flag = as.logical(quantile_row$rhs_near_bound_flag[[1L]] %||% FALSE),
    y_true = as.numeric(quantile_row$y_true[[1L]] %||% NA_real_),
    qhat = as.numeric(quantile_row$qhat[[1L]] %||% NA_real_),
    draw_mean = as.numeric(quantile_row$draw_mean[[1L]] %||% NA_real_),
    draw_sd = as.numeric(quantile_row$draw_sd[[1L]] %||% NA_real_),
    mu_mean = as.numeric(quantile_row$mu_mean[[1L]] %||% NA_real_),
    mu_sd = as.numeric(quantile_row$mu_sd[[1L]] %||% NA_real_),
    sigma_mean = as.numeric(quantile_row$sigma_mean[[1L]] %||% NA_real_),
    gamma_mean = as.numeric(quantile_row$gamma_mean[[1L]] %||% NA_real_)
  )
}

bench_qdesn_quantile_debug_candidate <- function(bundle, candidate_cfg, quantile_p) {
  candidate_cfg <- bench_qdesn_normalize_model_cfg(candidate_cfg, allow_single_quantile = TRUE)
  candidate_cfg$p_vec <- as.numeric(quantile_p)

  scaler <- bench_qdesn_scale_spec(bundle$fit_y, scale_y = candidate_cfg$preproc$scale_y)
  y_fit_scaled <- scaler$forward(bundle$fit_y)
  fit_args_template <- candidate_cfg$fit
  fit_args_template$seed_set <- NULL
  seed_set <- as.integer(candidate_cfg$fit$seed_set %||% candidate_cfg$fit$seed)
  if (!length(seed_set)) {
    seed_set <- as.integer(candidate_cfg$fit$seed %||% 123L)
  }
  if (length(seed_set) != 1L) {
    stop("Quantile debug currently expects exactly one seed.", call. = FALSE)
  }

  seed_used <- bench_qdesn_string_seed(
    paste(
      bundle$dataset,
      bundle$series_id,
      bundle$stage,
      bench_qdesn_candidate_seed_group(candidate_cfg),
      sprintf("q%.2f", quantile_p),
      sep = "::"
    ),
    base_seed = seed_set[[1L]]
  )

  fit_args <- fit_args_template
  fit_args$seed <- seed_used
  fit_args$y <- y_fit_scaled
  fit_args$p0 <- as.numeric(quantile_p)
  fit_args$vb_args <- candidate_cfg$vb_args

  qfit <- do.call(qdesn_fit_vb, fit_args)
  fore <- forecast_paths.qdesn_fit(
    qfit,
    H = 1L,
    nd = candidate_cfg$sampling$nd_draws,
    y_hist = y_fit_scaled,
    chunk = candidate_cfg$sampling$chunk,
    seed = seed_used + as.integer(round(1000 * quantile_p))
  )

  quantile_row <- bench_qdesn_one_step_quantile_row(
    bundle = bundle,
    candidate_cfg = candidate_cfg,
    quantile_p = quantile_p,
    qfit = qfit,
    fore = fore,
    scaler = scaler,
    seed_used = seed_used
  )

  trace_dt <- bench_qdesn_shoulder_trace_table(
    qfit = qfit,
    bundle = bundle,
    candidate_id = candidate_cfg$candidate_id,
    quantile_p = quantile_p,
    seed = seed_used,
    seed_index = 1L
  )
  if (nrow(trace_dt)) {
    trace_dt[, tau_warmup_iters := as.integer(candidate_cfg$vb_args$rhs$freeze_tau_warmup_iters %||%
      candidate_cfg$vb_args$rhs$freeze_tau_iters %||% 0L)]
  }

  collapse_row <- bench_qdesn_quantile_debug_collapse_row(
    trace_dt = trace_dt,
    quantile_row = quantile_row,
    bundle = bundle,
    candidate_cfg = candidate_cfg,
    quantile_p = quantile_p,
    seed_used = seed_used
  )

  list(
    quantile_row = quantile_row,
    trace_dt = trace_dt,
    collapse_row = collapse_row
  )
}

bench_qdesn_write_quantile_debug_report <- function(run_dir) {
  run_dir <- normalizePath(run_dir, mustWork = TRUE)
  tables_dir <- file.path(run_dir, "tables")
  figures_dir <- file.path(run_dir, "figures")
  reports_dir <- file.path(run_dir, "reports")
  dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(reports_dir, recursive = TRUE, showWarnings = FALSE)

  summary_dt <- data.table::as.data.table(readRDS(file.path(tables_dir, "quantile_debug_summary.rds")))
  trace_dt <- data.table::as.data.table(readRDS(file.path(tables_dir, "quantile_debug_rhs_trace.rds")))
  collapse_dt <- data.table::as.data.table(readRDS(file.path(tables_dir, "quantile_debug_collapse_summary.rds")))

  tau_plot <- file.path(figures_dir, "quantile_debug_tau_trace.png")
  beta_plot <- file.path(figures_dir, "quantile_debug_beta_l2_trace.png")
  bench_qdesn_quantile_debug_trace_plot(trace_dt, "tau", "RHS tau trace", tau_plot, log10_y = TRUE)
  bench_qdesn_quantile_debug_trace_plot(trace_dt, "beta_l2", "Readout beta L2 trace", beta_plot, log10_y = TRUE)

  row <- collapse_dt[1L]
  lines <- c(
    "# Q-DESN Quantile Debug Report",
    "",
    sprintf("- Generated at: `%s`", bench_timestamp_utc()),
    sprintf("- Run dir: `%s`", run_dir),
    "",
    "## Frozen Context",
    "",
    "- This mode exists to isolate one benchmark failure before reopening any broad synthesis benchmark run.",
    "- Current benchmark state is frozen at the tourism medium-route RHS failure, and this debug mode should be used before any wider `check`, `dev`, or monthly rerun.",
    "",
    "## Debug Target",
    "",
    sprintf("- Dataset: `%s`", row$dataset[[1L]]),
    sprintf("- Series: `%s`", row$series_id[[1L]]),
    sprintf("- Stage: `%s`", row$stage[[1L]]),
    sprintf("- Candidate: `%s`", row$candidate_id[[1L]]),
    sprintf("- Quantile: `%s`", row$quantile_label[[1L]]),
    "",
    "## Main Takeaways",
    "",
    sprintf("- `tau0 = %.3g`, warmup iterations = `%d`, initialized tau = `%.3g`.", row$tau0[[1L]], as.integer(row$tau_warmup_iters[[1L]]), row$init_tau[[1L]]),
    sprintf("- Final tau = `%.3e`, final beta L2 = `%.3e`.", row$tau_last[[1L]], row$beta_l2_last[[1L]]),
    sprintf("- Collapse flag = `%s`, near-bound flag = `%s`.", if (isTRUE(row$collapse_flag[[1L]])) "TRUE" else "FALSE", if (isTRUE(row$near_bound_flag[[1L]])) "TRUE" else "FALSE"),
    sprintf("- First post-warmup tau movement iteration = `%s`.", as.character(row$first_tau_move_iter_post_warmup[[1L]] %||% NA_integer_)),
    sprintf("- First lower-bound hit iteration = `%s`; first post-warmup lower-bound hit = `%s`.", as.character(row$first_lower_bound_iter[[1L]] %||% NA_integer_), as.character(row$first_lower_bound_iter_post_warmup[[1L]] %||% NA_integer_)),
    sprintf("- Lead-1 forecast summary: y_true = `%.6g`, qhat = `%.6g`, draw_sd = `%.6g`, mu_mean = `%.6g`, sigma_mean = `%.6g`.", row$y_true[[1L]], row$qhat[[1L]], row$draw_sd[[1L]], row$mu_mean[[1L]], row$sigma_mean[[1L]]),
    "",
    "## Files",
    "",
    sprintf("- Summary table: `%s`", file.path(tables_dir, "quantile_debug_summary.rds")),
    sprintf("- Collapse table: `%s`", file.path(tables_dir, "quantile_debug_collapse_summary.rds")),
    sprintf("- RHS trace table: `%s`", file.path(tables_dir, "quantile_debug_rhs_trace.rds")),
    sprintf("- Tau trace plot: `%s`", tau_plot),
    sprintf("- Beta L2 trace plot: `%s`", beta_plot)
  )

  report_path <- file.path(reports_dir, "quantile_debug_report.md")
  writeLines(lines, report_path)
  report_path
}

bench_qdesn_run_quantile_debug <- function(context) {
  cfg <- bench_qdesn_default_cfg(context$config)
  loaded <- bench_qdesn_load_processed(context)
  datasets <- bench_qdesn_select_datasets(loaded, cfg)
  if (length(datasets) != 1L) {
    stop("Quantile debug expects exactly one dataset in the config.", call. = FALSE)
  }

  dataset_name <- datasets[[1L]]
  stage <- as.character(cfg$evaluation$quantile_debug$stage %||% "validation")[1L]
  quantile_p <- as.numeric(cfg$evaluation$quantile_debug$quantile %||% NA_real_)[1L]
  if (!is.finite(quantile_p) || quantile_p <= 0 || quantile_p >= 1) {
    stop("Quantile debug requires evaluation.quantile_debug.quantile in (0, 1).", call. = FALSE)
  }

  series_id <- cfg$evaluation$series_overrides$selection[[dataset_name]] %||%
    cfg$evaluation$series_overrides$evaluation[[dataset_name]] %||%
    cfg$evaluation$series_overrides$audit[[dataset_name]] %||%
    NULL
  if (is.null(series_id) || !length(series_id)) {
    stop("Quantile debug requires a pinned series via evaluation.series_overrides.", call. = FALSE)
  }
  series_id <- as.character(series_id[[1L]])

  candidate_cfgs <- bench_qdesn_candidate_configs(cfg)
  if (length(candidate_cfgs) != 1L) {
    stop("Quantile debug expects exactly one candidate in the config.", call. = FALSE)
  }

  run_dirs <- bench_qdesn_run_dirs(context, cfg)
  bench_qdesn_write_run_manifest(context, cfg, run_dirs, selected_datasets = datasets)
  bench_write_json(bench_qdesn_candidate_registry_table(candidate_cfgs), file.path(run_dirs$manifests_dir, "candidate_registry.json"))

  bundle <- bench_qdesn_build_series_bundle(loaded, dataset_name, series_id, stage = stage, cfg = cfg)
  candidate_cfg <- candidate_cfgs[[1L]]
  message(sprintf(
    "[benchmark_qdesn_quantile_debug] dataset=%s series=%s candidate=%s quantile=%.2f start",
    dataset_name, series_id, candidate_cfg$candidate_id, quantile_p
  ))

  res <- bench_qdesn_quantile_debug_candidate(bundle, candidate_cfg, quantile_p)
  bench_save_table(res$quantile_row, file.path(run_dirs$tables_dir, "quantile_debug_summary"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")
  bench_save_table(res$collapse_row, file.path(run_dirs$tables_dir, "quantile_debug_collapse_summary"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")
  bench_save_table(res$trace_dt, file.path(run_dirs$tables_dir, "quantile_debug_rhs_trace"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")

  report_path <- bench_qdesn_write_quantile_debug_report(run_dirs$run_dir)
  message(sprintf(
    "[benchmark_qdesn_quantile_debug] dataset=%s series=%s candidate=%s quantile=%.2f done collapse=%s near_bound=%s",
    dataset_name,
    series_id,
    candidate_cfg$candidate_id,
    quantile_p,
    if (isTRUE(res$collapse_row$collapse_flag[[1L]])) "TRUE" else "FALSE",
    if (isTRUE(res$collapse_row$near_bound_flag[[1L]])) "TRUE" else "FALSE"
  ))

  list(run_dirs = run_dirs, report_path = report_path)
}

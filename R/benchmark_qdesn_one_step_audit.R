# Focused lead-1 audit for benchmark-side Q-DESN quantile models.

bench_qdesn_one_step_quantile_row <- function(bundle, candidate_cfg, quantile_p, qfit, fore, scaler, seed_used) {
  yrep <- scaler$inverse_matrix(as.matrix(fore$yrep))
  mu_draws <- scaler$inverse_matrix(as.matrix(fore$mu_draws))

  rhs_row <- bench_qdesn_rhs_diagnostics_row(
    qfit = qfit,
    p0 = quantile_p,
    candidate_cfg = candidate_cfg,
    seed = seed_used
  )

  beta_mean <- as.numeric(qfit$fit$qbeta$m %||% numeric(0))
  qsiggam <- qfit$fit$qsiggam %||% list()
  yrep1 <- as.numeric(yrep[1L, ])
  mu1 <- as.numeric(mu_draws[1L, ])

  data.table::data.table(
    dataset = bundle$dataset,
    source_family = bundle$source_family,
    benchmark_pool = bundle$benchmark_pool,
    series_id = bundle$series_id,
    stage = bundle$stage,
    candidate_id = candidate_cfg$candidate_id,
    quantile_p = as.numeric(quantile_p),
    quantile_label = bench_qdesn_prob_label(quantile_p),
    y_true = as.numeric(bundle$eval_y[[1L]]),
    qhat = as.numeric(stats::quantile(yrep1, probs = quantile_p, names = FALSE, na.rm = TRUE)),
    draw_mean = mean(yrep1, na.rm = TRUE),
    draw_sd = stats::sd(yrep1, na.rm = TRUE),
    mu_mean = mean(mu1, na.rm = TRUE),
    mu_sd = stats::sd(mu1, na.rm = TRUE),
    beta_l2 = sqrt(sum(beta_mean^2)),
    beta_abs_max = max(abs(beta_mean)),
    beta_intercept = if (length(beta_mean)) beta_mean[[1L]] else NA_real_,
    sigma_mean = as.numeric(qsiggam$sigma_mean %||% NA_real_),
    gamma_mean = as.numeric(qsiggam$gamma_mean %||% NA_real_),
    eta_hat = as.numeric(qsiggam$eta_hat %||% NA_real_),
    ell_hat = as.numeric(qsiggam$ell_hat %||% NA_real_),
    seed = as.integer(seed_used),
    rhs_tau_last = as.numeric(rhs_row$tau_last[[1L]] %||% NA_real_),
    rhs_beta_l2_last = as.numeric(rhs_row$beta_l2_last[[1L]] %||% NA_real_),
    rhs_collapse_flag = as.logical(rhs_row$collapse_flag[[1L]] %||% FALSE),
    rhs_near_bound_flag = as.logical(rhs_row$near_bound_flag[[1L]] %||% FALSE)
  )
}

bench_qdesn_one_step_candidate_rows <- function(bundle, candidate_cfg) {
  candidate_cfg <- bench_qdesn_normalize_model_cfg(candidate_cfg)
  scaler <- bench_qdesn_scale_spec(bundle$fit_y, scale_y = candidate_cfg$preproc$scale_y)
  y_fit_scaled <- scaler$forward(bundle$fit_y)
  fit_args_template <- candidate_cfg$fit
  fit_args_template$seed_set <- NULL
  seed_set <- as.integer(candidate_cfg$fit$seed_set %||% candidate_cfg$fit$seed)
  if (!length(seed_set)) {
    seed_set <- as.integer(candidate_cfg$fit$seed %||% 123L)
  }
  if (length(seed_set) != 1L) {
    stop("One-step audit currently expects exactly one seed.", call. = FALSE)
  }

  seed_used <- bench_qdesn_string_seed(
    paste(
      bundle$dataset,
      bundle$series_id,
      bundle$stage,
      bench_qdesn_candidate_seed_group(candidate_cfg),
      "lead1",
      sep = "::"
    ),
    base_seed = seed_set[[1L]]
  )

  rows <- lapply(candidate_cfg$p_vec, function(p0) {
    fit_args <- fit_args_template
    fit_args$seed <- seed_used
    fit_args$y <- y_fit_scaled
    fit_args$p0 <- as.numeric(p0)
    fit_args$vb_args <- candidate_cfg$vb_args

    qfit <- do.call(qdesn_fit_vb, fit_args)
    fore <- forecast_paths.qdesn_fit(
      qfit,
      H = 1L,
      nd = candidate_cfg$sampling$nd_draws,
      y_hist = y_fit_scaled,
      chunk = candidate_cfg$sampling$chunk,
      seed = seed_used + as.integer(round(1000 * p0))
    )

    bench_qdesn_one_step_quantile_row(
      bundle = bundle,
      candidate_cfg = candidate_cfg,
      quantile_p = p0,
      qfit = qfit,
      fore = fore,
      scaler = scaler,
      seed_used = seed_used
    )
  })

  data.table::rbindlist(rows, fill = TRUE)
}

bench_qdesn_one_step_candidate_summary <- function(one_step_dt) {
  one_step_dt <- data.table::as.data.table(one_step_dt)
  if (!nrow(one_step_dt)) {
    return(data.table::data.table())
  }

  one_step_dt[, is_shoulder := quantile_p %in% c(min(quantile_p), max(quantile_p)), by = candidate_id]
  one_step_dt[, is_median := quantile_p == stats::median(quantile_p), by = candidate_id]

  one_step_dt[, .(
    shoulder_abs_qhat_mean = mean(abs(qhat[is_shoulder]), na.rm = TRUE),
    median_abs_qhat = mean(abs(qhat[is_median]), na.rm = TRUE),
    shoulder_abs_mu_mean = mean(abs(mu_mean[is_shoulder]), na.rm = TRUE),
    median_abs_mu_mean = mean(abs(mu_mean[is_median]), na.rm = TRUE),
    shoulder_draw_sd_mean = mean(draw_sd[is_shoulder], na.rm = TRUE),
    median_draw_sd = mean(draw_sd[is_median], na.rm = TRUE),
    shoulder_sigma_mean = mean(sigma_mean[is_shoulder], na.rm = TRUE),
    median_sigma_mean = mean(sigma_mean[is_median], na.rm = TRUE),
    shoulder_gamma_mean = mean(gamma_mean[is_shoulder], na.rm = TRUE),
    median_gamma_mean = mean(gamma_mean[is_median], na.rm = TRUE),
    rhs_collapse_n = sum(rhs_collapse_flag, na.rm = TRUE),
    rhs_near_bound_n = sum(rhs_near_bound_flag, na.rm = TRUE)
  ), by = .(dataset, source_family, benchmark_pool, series_id, stage, candidate_id)][
    , `:=`(
      shoulder_qhat_to_median_ratio = shoulder_abs_qhat_mean / pmax(median_abs_qhat, 1e-8),
      shoulder_mu_to_median_ratio = shoulder_abs_mu_mean / pmax(median_abs_mu_mean, 1e-8),
      shoulder_drawsd_to_median_ratio = shoulder_draw_sd_mean / pmax(median_draw_sd, 1e-8),
      shoulder_sigma_to_median_ratio = shoulder_sigma_mean / pmax(median_sigma_mean, 1e-8)
    )
  ][]
}

bench_qdesn_write_one_step_audit_report <- function(run_dir) {
  run_dir <- normalizePath(run_dir, mustWork = TRUE)
  tables_dir <- file.path(run_dir, "tables")
  reports_dir <- file.path(run_dir, "reports")
  dir.create(reports_dir, recursive = TRUE, showWarnings = FALSE)

  one_step_dt <- data.table::as.data.table(readRDS(file.path(tables_dir, "one_step_quantile_diagnostics.rds")))
  summary_dt <- data.table::as.data.table(readRDS(file.path(tables_dir, "one_step_candidate_summary.rds")))

  lines <- c(
    "# Q-DESN One-Step Audit",
    "",
    sprintf("- Generated at: `%s`", bench_timestamp_utc()),
    sprintf("- Run dir: `%s`", run_dir),
    "",
    "## Main Takeaways",
    ""
  )

  if (nrow(summary_dt)) {
    best <- summary_dt[order(shoulder_qhat_to_median_ratio, shoulder_mu_to_median_ratio)][1L]
    lines <- c(
      lines,
      sprintf(
        "- Best candidate by shoulder/median |qhat| ratio is `%s`, but the ratio is still %.3g.",
        best$candidate_id[[1L]],
        as.numeric(best$shoulder_qhat_to_median_ratio[[1L]])
      ),
      sprintf(
        "- Its shoulder/median posterior-mean ratio is %.3g and shoulder/median predictive-SD ratio is %.3g.",
        as.numeric(best$shoulder_mu_to_median_ratio[[1L]]),
        as.numeric(best$shoulder_drawsd_to_median_ratio[[1L]])
      )
    )
  }

  lines <- c(lines, "", "## Candidate Summary", "")
  for (i in seq_len(nrow(summary_dt))) {
    row <- summary_dt[i]
    lines <- c(
      lines,
      sprintf(
        "- `%s`: shoulder/median |qhat|=%.3g, shoulder/median |mu|=%.3g, shoulder/median draw SD=%.3g, collapse=%d, near-bound=%d",
        row$candidate_id[[1L]],
        as.numeric(row$shoulder_qhat_to_median_ratio[[1L]]),
        as.numeric(row$shoulder_mu_to_median_ratio[[1L]]),
        as.numeric(row$shoulder_drawsd_to_median_ratio[[1L]]),
        as.integer(row$rhs_collapse_n[[1L]]),
        as.integer(row$rhs_near_bound_n[[1L]])
      )
    )
  }

  lines <- c(lines, "", "## Quantile Details", "")
  for (i in seq_len(nrow(one_step_dt))) {
    row <- one_step_dt[i]
    lines <- c(
      lines,
      sprintf(
        "- `%s` / q=%s: qhat=%.3g, draw_mean=%.3g, draw_sd=%.3g, mu_mean=%.3g, mu_sd=%.3g, sigma_mean=%.3g, gamma_mean=%.3g, beta_l2=%.3g, tau_last=%.3e, collapse=%s",
        row$candidate_id[[1L]],
        row$quantile_label[[1L]],
        as.numeric(row$qhat[[1L]]),
        as.numeric(row$draw_mean[[1L]]),
        as.numeric(row$draw_sd[[1L]]),
        as.numeric(row$mu_mean[[1L]]),
        as.numeric(row$mu_sd[[1L]]),
        as.numeric(row$sigma_mean[[1L]]),
        as.numeric(row$gamma_mean[[1L]]),
        as.numeric(row$beta_l2[[1L]]),
        as.numeric(row$rhs_tau_last[[1L]]),
        if (isTRUE(row$rhs_collapse_flag[[1L]])) "TRUE" else "FALSE"
      )
    )
  }

  report_path <- file.path(reports_dir, "one_step_audit.md")
  writeLines(lines, report_path)
  report_path
}

bench_qdesn_run_one_step_audit <- function(context) {
  cfg <- bench_qdesn_default_cfg(context$config)
  loaded <- bench_qdesn_load_processed(context)
  datasets <- bench_qdesn_select_datasets(loaded, cfg)
  if (length(datasets) != 1L) {
    stop("One-step audit expects exactly one dataset in the config.", call. = FALSE)
  }

  dataset_name <- datasets[[1L]]
  stage <- as.character(cfg$evaluation$one_step_audit$stage %||% "validation")[1L]
  series_id <- cfg$evaluation$series_overrides$selection[[dataset_name]] %||%
    cfg$evaluation$series_overrides$evaluation[[dataset_name]] %||%
    cfg$evaluation$series_overrides$audit[[dataset_name]] %||%
    NULL
  if (is.null(series_id) || !length(series_id)) {
    stop("One-step audit requires a pinned series via evaluation.series_overrides.", call. = FALSE)
  }
  series_id <- as.character(series_id[[1L]])

  candidate_cfgs <- bench_qdesn_candidate_configs(cfg)
  run_dirs <- bench_qdesn_run_dirs(context, cfg)
  bench_qdesn_write_run_manifest(context, cfg, run_dirs, selected_datasets = datasets)
  bench_write_json(bench_qdesn_candidate_registry_table(candidate_cfgs), file.path(run_dirs$manifests_dir, "candidate_registry.json"))

  bundle <- bench_qdesn_build_series_bundle(loaded, dataset_name, series_id, stage = stage, cfg = cfg)
  one_step_rows <- lapply(candidate_cfgs, function(candidate_cfg) {
    bench_qdesn_one_step_candidate_rows(bundle, candidate_cfg)
  })

  one_step_dt <- data.table::rbindlist(one_step_rows, fill = TRUE)
  summary_dt <- bench_qdesn_one_step_candidate_summary(one_step_dt)

  bench_save_table(one_step_dt, file.path(run_dirs$tables_dir, "one_step_quantile_diagnostics"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")
  bench_save_table(summary_dt, file.path(run_dirs$tables_dir, "one_step_candidate_summary"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")

  report_path <- bench_qdesn_write_one_step_audit_report(run_dirs$run_dir)
  list(run_dirs = run_dirs, report_path = report_path)
}

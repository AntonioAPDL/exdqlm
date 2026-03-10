# Audit diagnostics and visualization helpers for benchmarked Q-DESN runs.

bench_qdesn_pit_value <- function(y_true, draws_vec) {
  z <- as.numeric(draws_vec)
  z <- z[is.finite(z)]
  if (!length(z) || !is.finite(y_true)) {
    return(NA_real_)
  }

  (sum(z < y_true) + 0.5 * sum(z == y_true)) / length(z)
}

bench_qdesn_audit_artifact_paths <- function(run_dir) {
  list.files(
    file.path(run_dir, "artifacts"),
    pattern = "forecast_artifact\\.rds$",
    full.names = TRUE,
    recursive = TRUE
  )
}

bench_qdesn_audit_long_from_artifact <- function(artifact) {
  draws <- as.matrix(artifact$synth_draws)
  if (!nrow(draws)) {
    return(data.table::data.table())
  }

  q_lookup <- function(prob) {
    apply(draws, 1L, stats::quantile, probs = prob, names = FALSE, na.rm = TRUE)
  }
  y_true <- as.numeric(artifact$eval_y)
  eval_idx <- as.integer(artifact$eval_idx %||% seq_len(length(y_true)))
  timestamp_eval <- artifact$timestamp_eval %||%
    if (!is.null(artifact$timestamp)) artifact$timestamp[eval_idx] else rep(NA, length(eval_idx))
  q025 <- q_lookup(0.025)
  q10 <- q_lookup(0.10)
  q50 <- q_lookup(0.50)
  q90 <- q_lookup(0.90)
  q975 <- q_lookup(0.975)
  coverage95 <- as.numeric(y_true >= q025 & y_true <= q975)
  interval_width95 <- q975 - q025

  data.table::data.table(
    dataset = artifact$dataset,
    dataset_label = artifact$dataset_label %||% artifact$dataset,
    source_family = artifact$source_family,
    series_id = artifact$series_id,
    route_key = artifact$route_key %||% "global",
    stage = artifact$stage,
    model_name = artifact$model_name,
    candidate_id = artifact$candidate_id,
    seasonal_period = as.integer(artifact$seasonal_period %||% NA_integer_),
    forecast_horizon = as.integer(artifact$forecast_horizon %||% nrow(draws)),
    lead = seq_len(length(y_true)),
    eval_t_index = eval_idx,
    timestamp = timestamp_eval,
    y_true = y_true,
    pred_mean = rowMeans(draws),
    pred_median = q50,
    q025 = q025,
    q10 = q10,
    q90 = q90,
    q975 = q975,
    crps = bench_qdesn_crps_vec(y_true, draws),
    pit = vapply(seq_len(nrow(draws)), function(i) bench_qdesn_pit_value(y_true[[i]], draws[i, ]), numeric(1)),
    coverage95 = coverage95,
    interval_width95 = interval_width95
  )
}

bench_qdesn_audit_summary_table <- function(audit_long) {
  dt <- data.table::as.data.table(audit_long)
  if (!nrow(dt)) {
    return(data.table::data.table())
  }

  by_series <- dt[, .(
    n_leads = .N,
    crps_mean = mean(crps, na.rm = TRUE),
    pit_mean = mean(pit, na.rm = TRUE),
    pit_var = stats::var(pit, na.rm = TRUE),
    coverage95_mean = mean(coverage95, na.rm = TRUE),
    acd95_mean = abs(mean(coverage95, na.rm = TRUE) - 0.95),
    interval_width95_mean = mean(interval_width95, na.rm = TRUE)
  ), by = .(dataset, route_key, series_id, model_name, candidate_id)]

  overall <- dt[, .(
    n_leads = .N,
    crps_mean = mean(crps, na.rm = TRUE),
    pit_mean = mean(pit, na.rm = TRUE),
    pit_var = stats::var(pit, na.rm = TRUE),
    coverage95_mean = mean(coverage95, na.rm = TRUE),
    acd95_mean = abs(mean(coverage95, na.rm = TRUE) - 0.95),
    interval_width95_mean = mean(interval_width95, na.rm = TRUE)
  ), by = .(model_name, candidate_id)]
  overall[, dataset := "audit_overall"]
  overall[, route_key := "all_routes"]
  overall[, series_id := "all_audit_series"]

  data.table::rbindlist(list(by_series, overall), fill = TRUE)
}

bench_qdesn_audit_calibration_bins <- function(audit_long, n_bins = 10L) {
  dt <- data.table::as.data.table(audit_long)
  dt <- dt[is.finite(pit)]
  if (!nrow(dt)) {
    return(data.table::data.table())
  }

  breaks <- seq(0, 1, length.out = as.integer(n_bins) + 1L)
  dt[, pit_bin := cut(pit, breaks = breaks, include.lowest = TRUE, right = TRUE)]
  dt[, .(
    n = .N,
    observed_share = .N / nrow(dt),
    expected_share = 1 / as.integer(n_bins)
  ), by = .(model_name, candidate_id, pit_bin)]
}

bench_qdesn_plot_audit_pit <- function(audit_long, out_path) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    return(invisible(NULL))
  }

  dt <- data.table::as.data.table(audit_long)[is.finite(pit)]
  if (!nrow(dt)) {
    return(invisible(NULL))
  }

  p <- ggplot2::ggplot(dt, ggplot2::aes(x = pit)) +
    ggplot2::geom_histogram(
      breaks = seq(0, 1, by = 0.1),
      fill = "#1b6ca8",
      color = "white",
      linewidth = 0.3
    ) +
    ggplot2::geom_hline(yintercept = nrow(dt) / 10, linetype = "dashed", color = "#b03a2e") +
    ggplot2::coord_cartesian(xlim = c(0, 1)) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::labs(
      title = "Audit PIT Histogram",
      subtitle = "Synthesized Q-DESN forecasts on the saved audit subset",
      x = "PIT value",
      y = "Count"
    )

  ggplot2::ggsave(out_path, plot = p, width = 8, height = 4.5, dpi = 160)
  invisible(out_path)
}

bench_qdesn_plot_audit_coverage <- function(audit_long, out_path) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    return(invisible(NULL))
  }

  dt <- data.table::as.data.table(audit_long)
  if (!nrow(dt)) {
    return(invisible(NULL))
  }

  cover_dt <- dt[, .(
    coverage95_mean = mean(coverage95, na.rm = TRUE),
    interval_width95_mean = mean(interval_width95, na.rm = TRUE)
  ), by = .(lead)]

  p <- ggplot2::ggplot(cover_dt, ggplot2::aes(x = lead, y = coverage95_mean)) +
    ggplot2::geom_line(ggplot2::aes(group = 1), color = "#1b6ca8", linewidth = 0.8) +
    ggplot2::geom_point(color = "#1b6ca8", size = 1.8) +
    ggplot2::geom_hline(yintercept = 0.95, linetype = "dashed", color = "#b03a2e") +
    ggplot2::coord_cartesian(ylim = c(0, 1)) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::labs(
      title = "Audit 95% Coverage by Lead",
      subtitle = "Mean empirical coverage across saved audit series",
      x = "Forecast lead",
      y = "Coverage"
    )

  ggplot2::ggsave(out_path, plot = p, width = 8, height = 4.5, dpi = 160)
  invisible(out_path)
}

bench_qdesn_plot_audit_fan <- function(artifact, out_path) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    return(invisible(NULL))
  }

  draws <- as.matrix(artifact$synth_draws)
  if (!nrow(draws)) {
    return(invisible(NULL))
  }

  q_lookup <- function(prob) {
    apply(draws, 1L, stats::quantile, probs = prob, names = FALSE, na.rm = TRUE)
  }
  q025 <- q_lookup(0.025)
  q10 <- q_lookup(0.10)
  q50 <- q_lookup(0.50)
  q90 <- q_lookup(0.90)
  q975 <- q_lookup(0.975)
  h <- nrow(draws)
  fit_tail_n <- min(length(artifact$fit_y), max(48L, 2L * h))
  fit_tail_idx <- tail(seq_along(artifact$fit_y), fit_tail_n)
  eval_idx <- as.integer(artifact$eval_idx %||% seq_len(h))
  ts_full <- artifact$timestamp %||% rep(NA, max(c(artifact$fit_idx, artifact$eval_idx), na.rm = TRUE))

  hist_x <- ts_full[artifact$fit_idx[fit_tail_idx]]
  fc_x <- artifact$timestamp_eval %||% ts_full[eval_idx]
  if (all(is.na(hist_x)) || all(is.na(fc_x))) {
    hist_x <- artifact$fit_idx[fit_tail_idx]
    fc_x <- eval_idx
  }

  hist_df <- data.frame(
    x = hist_x,
    y = tail(artifact$fit_y, fit_tail_n)
  )
  fc_df <- data.frame(
    x = fc_x,
    y_true = artifact$eval_y,
    q025 = q025,
    q10 = q10,
    q50 = q50,
    q90 = q90,
    q975 = q975
  )

  p <- ggplot2::ggplot() +
    ggplot2::geom_line(data = hist_df, ggplot2::aes(x = x, y = y, group = 1), color = "#4d4d4d", linewidth = 0.7) +
    ggplot2::geom_ribbon(data = fc_df, ggplot2::aes(x = x, ymin = q025, ymax = q975, group = 1), fill = "#c6dbef", alpha = 0.8) +
    ggplot2::geom_ribbon(data = fc_df, ggplot2::aes(x = x, ymin = q10, ymax = q90, group = 1), fill = "#6baed6", alpha = 0.8) +
    ggplot2::geom_line(data = fc_df, ggplot2::aes(x = x, y = q50, group = 1), color = "#08519c", linewidth = 0.8) +
    ggplot2::geom_line(data = fc_df, ggplot2::aes(x = x, y = y_true, group = 1), color = "#cb181d", linewidth = 0.8) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::labs(
      title = sprintf("Audit Fan Chart: %s / %s", artifact$dataset, artifact$series_id),
      subtitle = sprintf(
        "Candidate: %s | route=%s | recal=%s",
        artifact$candidate_id,
        artifact$route_key %||% "global",
        artifact$recalibration$mode %||% "none"
      ),
      x = NULL,
      y = "y"
    )

  ggplot2::ggsave(out_path, plot = p, width = 9, height = 4.8, dpi = 160)
  invisible(out_path)
}

bench_qdesn_write_audit_diagnostics <- function(run_dir) {
  run_dir <- normalizePath(run_dir, mustWork = TRUE)
  artifact_paths <- bench_qdesn_audit_artifact_paths(run_dir)
  tables_dir <- file.path(run_dir, "tables")
  figures_dir <- file.path(run_dir, "figures")

  if (!length(artifact_paths)) {
    return(list(
      audit_long = data.table::data.table(),
      audit_summary = data.table::data.table(),
      calibration_bins = data.table::data.table(),
      figure_manifest = data.table::data.table(),
      plot_paths = character(0)
    ))
  }

  artifacts <- lapply(artifact_paths, readRDS)
  audit_long <- data.table::rbindlist(lapply(artifacts, bench_qdesn_audit_long_from_artifact), fill = TRUE)
  audit_summary <- bench_qdesn_audit_summary_table(audit_long)
  calibration_bins <- bench_qdesn_audit_calibration_bins(audit_long, n_bins = 10L)

  bench_save_table(audit_long, file.path(tables_dir, "audit_lead_diagnostics"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")
  bench_save_table(audit_summary, file.path(tables_dir, "audit_diagnostics_summary"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")
  bench_save_table(calibration_bins, file.path(tables_dir, "audit_calibration_bins"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")

  plot_paths <- character(0)
  figure_rows <- list()
  figure_idx <- 1L

  pit_path <- file.path(figures_dir, "audit_pit_histogram.png")
  if (!is.null(bench_qdesn_plot_audit_pit(audit_long, pit_path))) {
    plot_paths <- c(plot_paths, pit_path)
    figure_rows[[figure_idx]] <- data.table::data.table(
      figure_type = "audit_pit_histogram",
      dataset = "audit_overall",
      series_id = NA_character_,
      path = pit_path
    )
    figure_idx <- figure_idx + 1L
  }

  cov_path <- file.path(figures_dir, "audit_coverage95_by_lead.png")
  if (!is.null(bench_qdesn_plot_audit_coverage(audit_long, cov_path))) {
    plot_paths <- c(plot_paths, cov_path)
    figure_rows[[figure_idx]] <- data.table::data.table(
      figure_type = "audit_coverage95_by_lead",
      dataset = "audit_overall",
      series_id = NA_character_,
      path = cov_path
    )
    figure_idx <- figure_idx + 1L
  }

  for (artifact in artifacts) {
    fan_path <- file.path(figures_dir, sprintf("audit_fan__%s__%s.png", artifact$dataset, artifact$series_id))
    if (!is.null(bench_qdesn_plot_audit_fan(artifact, fan_path))) {
      plot_paths <- c(plot_paths, fan_path)
      figure_rows[[figure_idx]] <- data.table::data.table(
        figure_type = "audit_fan",
        dataset = artifact$dataset,
        series_id = artifact$series_id,
        path = fan_path
      )
      figure_idx <- figure_idx + 1L
    }
  }

  figure_manifest <- if (length(figure_rows)) {
    data.table::rbindlist(figure_rows, fill = TRUE)
  } else {
    data.table::data.table()
  }
  bench_save_table(figure_manifest, file.path(tables_dir, "audit_figure_manifest"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")

  list(
    audit_long = audit_long,
    audit_summary = audit_summary,
    calibration_bins = calibration_bins,
    figure_manifest = figure_manifest,
    plot_paths = plot_paths
  )
}

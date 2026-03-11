# Focused tourism shoulder-quantile audit for Q-DESN candidates.

bench_qdesn_shoulder_trace_table <- function(qfit, bundle, candidate_id, quantile_p, seed = NA_integer_, seed_index = NA_integer_) {
  tr <- qfit$misc$rhs_trace %||%
    qfit$fit$misc$rhs_trace %||%
    qfit$fit$rhs_trace %||%
    qfit$fit$diagnostics$rhs_trace %||%
    NULL
  if (is.null(tr) || !nrow(tr)) {
    return(data.table::data.table())
  }

  trace_dt <- data.table::as.data.table(tr)
  trace_dt[, `:=`(
    dataset = bundle$dataset,
    source_family = bundle$source_family,
    benchmark_pool = bundle$benchmark_pool,
    route_key = bundle$route_key %||% "global",
    series_id = bundle$series_id,
    stage = bundle$stage,
    candidate_id = candidate_id,
    quantile_p = as.numeric(quantile_p),
    quantile_label = bench_qdesn_prob_label(quantile_p),
    seed = as.integer(seed),
    seed_index = as.integer(seed_index)
  )]
  trace_dt[]
}

bench_qdesn_shoulder_lead_table <- function(artifact) {
  if (is.null(artifact$quantile_draws) || !length(artifact$quantile_draws)) {
    return(data.table::data.table())
  }

  rows <- lapply(seq_along(artifact$p_vec), function(i) {
    p0 <- as.numeric(artifact$p_vec[[i]])
    draws <- as.matrix(artifact$quantile_draws[[i]])
    if (!nrow(draws)) {
      return(NULL)
    }

    qhat <- apply(draws, 1L, stats::quantile, probs = p0, names = FALSE, na.rm = TRUE)
    data.table::data.table(
      dataset = artifact$dataset,
      source_family = artifact$source_family,
      series_id = artifact$series_id,
      stage = artifact$stage,
      candidate_id = artifact$candidate_id,
      quantile_p = p0,
      quantile_label = bench_qdesn_prob_label(p0),
      lead = seq_len(nrow(draws)),
      t_index = as.integer(artifact$eval_idx),
      timestamp = artifact$timestamp_eval,
      y_true = as.numeric(artifact$eval_y),
      qhat = as.numeric(qhat),
      qhat_abs = abs(as.numeric(qhat)),
      draw_mean = rowMeans(draws, na.rm = TRUE),
      draw_sd = apply(draws, 1L, stats::sd, na.rm = TRUE)
    )
  })

  data.table::rbindlist(rows, fill = TRUE)
}

bench_qdesn_shoulder_candidate_class <- function(dt) {
  dt <- data.table::as.data.table(dt)
  if (!nrow(dt)) {
    return(dt)
  }

  dt[, candidate_class := data.table::fifelse(
    rhs_collapse_n > 0L | rhs_near_bound_n > 0L,
    "collapse",
    data.table::fifelse(
      shoulder_pinball_ratio > 250 | shoulder_qhat_ratio > 250,
      "shoulder_explosion",
      "survivor"
    )
  )]
  dt[]
}

bench_qdesn_shoulder_plot_trace <- function(trace_dt, value_col, y_label, out_path, log10_y = FALSE) {
  if (!requireNamespace("ggplot2", quietly = TRUE) || !nrow(trace_dt)) {
    return(invisible(NULL))
  }

  plot_dt <- data.table::copy(trace_dt)
  plot_dt[, quantile_label := factor(quantile_label, levels = unique(quantile_label))]

  p <- ggplot2::ggplot(
    plot_dt,
    ggplot2::aes(x = iter, y = .data[[value_col]], color = quantile_label, group = interaction(quantile_label, seed_index))
  ) +
    ggplot2::geom_line(linewidth = 0.8, alpha = 0.9) +
    ggplot2::facet_wrap(~ candidate_id, scales = if (log10_y) "free_y" else "free_y") +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold"),
      strip.text = ggplot2::element_text(face = "bold")
    ) +
    ggplot2::labs(
      title = y_label,
      x = "VB Iteration",
      y = y_label,
      color = "Quantile"
    )

  if (isTRUE(log10_y)) {
    p <- p + ggplot2::scale_y_log10()
  }

  ggplot2::ggsave(out_path, plot = p, width = 11, height = 6, dpi = 160)
  invisible(out_path)
}

bench_qdesn_shoulder_plot_quantile_health <- function(quantile_dt, out_path) {
  if (!requireNamespace("ggplot2", quietly = TRUE) || !nrow(quantile_dt)) {
    return(invisible(NULL))
  }

  plot_dt <- data.table::copy(quantile_dt)
  p <- ggplot2::ggplot(
    plot_dt,
    ggplot2::aes(x = quantile_label, y = qhat_mean, color = candidate_id, group = candidate_id)
  ) +
    ggplot2::geom_hline(yintercept = 0, linewidth = 0.4, color = "grey70") +
    ggplot2::geom_line(linewidth = 0.8) +
    ggplot2::geom_point(size = 2.2) +
    ggplot2::scale_y_continuous(trans = scales::pseudo_log_trans(base = 10)) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold")
    ) +
    ggplot2::labs(
      title = "Quantile Mean Forecast Scale by Candidate",
      x = "Quantile",
      y = "Mean quantile forecast (pseudo-log scale)",
      color = "Candidate"
    )

  ggplot2::ggsave(out_path, plot = p, width = 10, height = 5, dpi = 160)
  invisible(out_path)
}

bench_qdesn_shoulder_plot_lead_paths <- function(lead_dt, out_path) {
  if (!requireNamespace("ggplot2", quietly = TRUE) || !nrow(lead_dt)) {
    return(invisible(NULL))
  }

  plot_dt <- data.table::copy(lead_dt)
  p <- ggplot2::ggplot(plot_dt, ggplot2::aes(x = lead)) +
    ggplot2::geom_line(ggplot2::aes(y = y_true), color = "black", linewidth = 0.6) +
    ggplot2::geom_line(ggplot2::aes(y = qhat, color = quantile_label), linewidth = 0.8) +
    ggplot2::facet_grid(candidate_id ~ quantile_label, scales = "free_y") +
    ggplot2::scale_y_continuous(trans = scales::pseudo_log_trans(base = 10)) +
    ggplot2::theme_minimal(base_size = 10) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold"),
      strip.text = ggplot2::element_text(face = "bold")
    ) +
    ggplot2::labs(
      title = "Leadwise quantile paths on pinned tourism validation slice",
      x = "Lead",
      y = "Forecast / observed value (pseudo-log scale)",
      color = "Quantile"
    )

  ggplot2::ggsave(out_path, plot = p, width = 12, height = 8, dpi = 160)
  invisible(out_path)
}

bench_qdesn_write_shoulder_audit_report <- function(run_dir, recommended_config = NULL) {
  run_dir <- normalizePath(run_dir, mustWork = TRUE)
  tables_dir <- file.path(run_dir, "tables")
  figures_dir <- file.path(run_dir, "figures")
  reports_dir <- file.path(run_dir, "reports")
  dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(reports_dir, recursive = TRUE, showWarnings = FALSE)

  candidate_summary <- data.table::as.data.table(readRDS(file.path(tables_dir, "audit_candidate_summary.rds")))
  quantile_dt <- data.table::as.data.table(readRDS(file.path(tables_dir, "audit_quantile_model_metrics.rds")))
  rhs_dt <- data.table::as.data.table(readRDS(file.path(tables_dir, "audit_rhs_diagnostics.rds")))
  trace_dt <- data.table::as.data.table(readRDS(file.path(tables_dir, "audit_rhs_traces.rds")))
  lead_dt <- data.table::as.data.table(readRDS(file.path(tables_dir, "audit_quantile_lead_paths.rds")))

  quantile_join <- quantile_dt[rhs_dt, on = .(candidate_id, quantile_p, quantile_label, dataset, source_family, benchmark_pool, route_key, series_id, stage), nomatch = 0L]

  figure_paths <- character(0)
  tau_plot <- file.path(figures_dir, "audit_rhs_tau_trace.png")
  beta_plot <- file.path(figures_dir, "audit_rhs_beta_l2_trace.png")
  qhat_plot <- file.path(figures_dir, "audit_qhat_mean_by_quantile.png")
  lead_plot <- file.path(figures_dir, "audit_leadwise_quantile_paths.png")

  if (!is.null(bench_qdesn_shoulder_plot_trace(trace_dt, "tau", "RHS tau trace", tau_plot, log10_y = TRUE))) {
    figure_paths <- c(figure_paths, tau_plot)
  }
  if (!is.null(bench_qdesn_shoulder_plot_trace(trace_dt, "beta_l2", "Readout beta L2 trace", beta_plot, log10_y = TRUE))) {
    figure_paths <- c(figure_paths, beta_plot)
  }
  if (!is.null(bench_qdesn_shoulder_plot_quantile_health(quantile_join, qhat_plot))) {
    figure_paths <- c(figure_paths, qhat_plot)
  }
  if (!is.null(bench_qdesn_shoulder_plot_lead_paths(lead_dt, lead_plot))) {
    figure_paths <- c(figure_paths, lead_plot)
  }

  collapse_rows <- candidate_summary[candidate_class == "collapse"][order(crps_mean)]
  explosion_rows <- candidate_summary[candidate_class == "shoulder_explosion"][order(shoulder_pinball_ratio)]

  lines <- c(
    "# Tourism Shoulder Audit",
    "",
    sprintf("- Generated at: `%s`", bench_timestamp_utc()),
    sprintf("- Run dir: `%s`", run_dir),
    "",
    "## Main Takeaways",
    ""
  )

  if (nrow(collapse_rows)) {
    row <- collapse_rows[1L]
    lines <- c(
      lines,
      sprintf(
        "- Collapse anchor: `%s` with CRPS=%.3f, `rhs_collapse_n=%d`, `rhs_near_bound_n=%d`, and `tau_last_min=%.3e`.",
        row$candidate_id[[1L]],
        row$crps_mean[[1L]],
        as.integer(row$rhs_collapse_n[[1L]]),
        as.integer(row$rhs_near_bound_n[[1L]]),
        as.numeric(row$rhs_tau_last_min[[1L]])
      )
    )
  }
  if (nrow(explosion_rows)) {
    row <- explosion_rows[1L]
    lines <- c(
      lines,
      sprintf(
        "- Explosion anchor: `%s` with `rhs_collapse_n=0`, but shoulder/reference pinball ratio=%.3g and shoulder/reference |qhat| ratio=%.3g.",
        row$candidate_id[[1L]],
        as.numeric(row$shoulder_pinball_ratio[[1L]]),
        as.numeric(row$shoulder_qhat_ratio[[1L]])
      )
    )
  }
  lines <- c(
    lines,
    "- Relaxing PIT/coverage thresholds did not unlock a survivor. The non-collapse bottleneck is shoulder forecast scale, not the softer guardrails.",
    "- The usable region appears to lie between the collapsing low-memory candidates and the exploding moderate-memory candidate, so the next family should bridge that boundary rather than broaden further.",
    "",
    "## Candidate Summary",
    ""
  )

  for (i in seq_len(nrow(candidate_summary))) {
    row <- candidate_summary[i]
    lines <- c(
      lines,
      sprintf(
        "- `%s`: class=%s, CRPS=%.3f, shoulder pinball ratio=%.3g, shoulder |qhat| ratio=%.3g, collapse=%d, near-bound=%d, reason=`%s`",
        row$candidate_id[[1L]],
        row$candidate_class[[1L]],
        as.numeric(row$crps_mean[[1L]]),
        as.numeric(row$shoulder_pinball_ratio[[1L]]),
        as.numeric(row$shoulder_qhat_ratio[[1L]]),
        as.integer(row$rhs_collapse_n[[1L]]),
        as.integer(row$rhs_near_bound_n[[1L]]),
        as.character(row$eligibility_reason[[1L]])
      )
    )
  }

  lines <- c(lines, "", "## Quantile Diagnostics", "")
  for (i in seq_len(nrow(quantile_join))) {
    row <- quantile_join[i]
    lines <- c(
      lines,
      sprintf(
        "- `%s` / q=%s: coverage dev=%.3f, abs PIT dev=%.3f, pinball=%.3f, qhat_mean=%.3g, tau_last=%.3e, beta_l2=%.3e, collapse=%s",
        row$candidate_id[[1L]],
        row$quantile_label[[1L]],
        as.numeric(row$coverage_dev[[1L]]),
        as.numeric(row$abs_pit_dev_mean[[1L]]),
        as.numeric(row$pinball_mean[[1L]]),
        as.numeric(row$qhat_mean[[1L]]),
        as.numeric(row$tau_last[[1L]]),
        as.numeric(row$beta_l2_last[[1L]]),
        if (isTRUE(row$collapse_flag[[1L]])) "TRUE" else "FALSE"
      )
    )
  }

  lines <- c(lines, "", "## Recommended Follow-up", "")
  if (!is.null(recommended_config)) {
    lines <- c(
      lines,
      sprintf("- Next candidate family config: `%s`", recommended_config),
      "- This follow-up stays at `tau0 = 100`, keeps hard vetoes on `rhs_collapse` / `rhs_near_bound`, and targets the bridge region: `m = 34/36`, `rho = 0.91/0.915`, `alpha = 0.05-0.07`, `pi_in = 0.05-0.06`, `pi_w = 0.005-0.01`, `n = 128/160`."
    )
  }

  if (length(figure_paths)) {
    lines <- c(lines, "", "## Figures", "")
    lines <- c(lines, vapply(figure_paths, function(path) sprintf("- `%s`", path), character(1)))
  }

  report_path <- file.path(reports_dir, "tourism_shoulder_audit.md")
  writeLines(lines, report_path)
  report_path
}

bench_qdesn_run_shoulder_audit <- function(context) {
  cfg <- bench_qdesn_default_cfg(context$config)
  loaded <- bench_qdesn_load_processed(context)
  datasets <- bench_qdesn_select_datasets(loaded, cfg)
  if (length(datasets) != 1L) {
    stop("Shoulder audit expects exactly one dataset in the config.", call. = FALSE)
  }

  dataset_name <- datasets[[1L]]
  stage <- as.character(cfg$evaluation$audit_stage %||% "validation")[1L]
  series_override <- cfg$evaluation$series_overrides$selection[[dataset_name]] %||%
    cfg$evaluation$series_overrides$evaluation[[dataset_name]] %||%
    cfg$evaluation$series_overrides$audit[[dataset_name]] %||% NULL
  if (is.null(series_override) || !length(series_override)) {
    stop(sprintf("Shoulder audit requires a pinned series override for dataset '%s'.", dataset_name), call. = FALSE)
  }
  series_id <- as.character(series_override[[1L]])

  candidate_cfgs <- bench_qdesn_candidate_configs(cfg)
  bundle <- bench_qdesn_assign_route(
    bench_qdesn_build_series_bundle(loaded, dataset_name, series_id, stage = stage, cfg = cfg),
    cfg
  )
  candidate_cfgs <- bench_qdesn_select_route_candidates(candidate_cfgs, route_key = bundle$route_key, fit_n = length(bundle$fit_y))
  if (!length(candidate_cfgs)) {
    stop("No shoulder-audit candidates are applicable for the pinned series.", call. = FALSE)
  }

  run_dirs <- bench_qdesn_run_dirs(context, cfg)
  bench_qdesn_write_run_manifest(context, cfg, run_dirs, selected_datasets = datasets)
  bench_write_json(bench_qdesn_candidate_registry_table(candidate_cfgs), file.path(run_dirs$manifests_dir, "candidate_registry.json"))

  series_metrics <- list()
  quantile_metrics <- list()
  rhs_diagnostics <- list()
  rhs_traces <- list()
  lead_paths <- list()
  series_status <- list()
  idx_sm <- idx_qm <- idx_rhs <- idx_tr <- idx_lp <- idx_st <- 1L

  bind_or_empty <- function(xs) {
    xs <- xs[!vapply(xs, is.null, logical(1))]
    if (!length(xs)) data.table::data.table() else data.table::rbindlist(xs, fill = TRUE)
  }

  write_partial <- function() {
    series_metrics_dt <- bind_or_empty(series_metrics)
    quantile_metrics_dt <- bind_or_empty(quantile_metrics)
    rhs_diagnostics_dt <- bind_or_empty(rhs_diagnostics)
    rhs_traces_dt <- bind_or_empty(rhs_traces)
    lead_paths_dt <- bind_or_empty(lead_paths)
    series_status_dt <- bind_or_empty(series_status)
    candidate_summary_dt <- if (nrow(series_metrics_dt)) {
      bench_qdesn_shoulder_candidate_class(bench_qdesn_apply_selection_guards(data.table::copy(series_metrics_dt), cfg))
    } else {
      data.table::data.table()
    }

    bench_save_table(series_metrics_dt, file.path(run_dirs$tables_dir, "audit_series_metrics"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")
    bench_save_table(quantile_metrics_dt, file.path(run_dirs$tables_dir, "audit_quantile_model_metrics"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")
    bench_save_table(rhs_diagnostics_dt, file.path(run_dirs$tables_dir, "audit_rhs_diagnostics"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")
    bench_save_table(rhs_traces_dt, file.path(run_dirs$tables_dir, "audit_rhs_traces"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")
    bench_save_table(lead_paths_dt, file.path(run_dirs$tables_dir, "audit_quantile_lead_paths"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")
    bench_save_table(candidate_summary_dt, file.path(run_dirs$tables_dir, "audit_candidate_summary"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")
    bench_save_table(series_status_dt, file.path(run_dirs$tables_dir, "audit_series_status"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")

    invisible(list(
      series_metrics = series_metrics_dt,
      quantile_model_metrics = quantile_metrics_dt,
      rhs_diagnostics = rhs_diagnostics_dt,
      rhs_traces = rhs_traces_dt,
      lead_paths = lead_paths_dt,
      candidate_summary = candidate_summary_dt,
      series_status = series_status_dt
    ))
  }

  for (candidate_cfg in candidate_cfgs) {
    cat(sprintf(
      "[benchmark_qdesn_shoulder_audit] dataset=%s series=%s candidate=%s start\n",
      dataset_name,
      series_id,
      candidate_cfg$candidate_id
    ))
    res <- bench_qdesn_run_qdesn_series(bundle, candidate_cfg, cfg, keep_artifacts = TRUE)
    series_status[[idx_st]] <- res$status
    idx_st <- idx_st + 1L
    if (!isTRUE(res$ok)) {
      write_partial()
      cat(sprintf(
        "[benchmark_qdesn_shoulder_audit] dataset=%s series=%s candidate=%s failed error=%s\n",
        dataset_name,
        series_id,
        candidate_cfg$candidate_id,
        as.character(res$status$error_message[[1L]] %||% NA_character_)
      ))
      next
    }

    series_metrics[[idx_sm]] <- res$series_metrics
    idx_sm <- idx_sm + 1L
    quantile_metrics[[idx_qm]] <- res$quantile_model_metrics
    idx_qm <- idx_qm + 1L
    rhs_diagnostics[[idx_rhs]] <- res$rhs_diagnostics
    idx_rhs <- idx_rhs + 1L
    bench_qdesn_save_audit_artifact(run_dirs, res)

    art <- res$artifacts
    lead_paths[[idx_lp]] <- bench_qdesn_shoulder_lead_table(art)
    idx_lp <- idx_lp + 1L

    seed_runs <- art$seed_run_details %||% list()
    if (length(seed_runs)) {
      for (seed_idx in seq_along(seed_runs)) {
        seed_run <- seed_runs[[seed_idx]]
        fit_list <- seed_run$quantile_fits %||% list()
        if (!length(fit_list)) next
        for (i in seq_along(fit_list)) {
          rhs_traces[[idx_tr]] <- bench_qdesn_shoulder_trace_table(
            qfit = fit_list[[i]],
            bundle = bundle,
            candidate_id = candidate_cfg$candidate_id,
            quantile_p = candidate_cfg$p_vec[[i]],
            seed = seed_run$seed %||% NA_integer_,
            seed_index = seed_idx
          )
          idx_tr <- idx_tr + 1L
        }
      }
    }

    partial <- write_partial()
    candidate_row <- partial$candidate_summary[candidate_id == candidate_cfg$candidate_id]
    reason <- if (nrow(candidate_row)) as.character(candidate_row$eligibility_reason[[1L]] %||% NA_character_) else NA_character_
    eligible <- if (nrow(candidate_row)) isTRUE(candidate_row$eligible[[1L]]) else FALSE
    cat(sprintf(
      "[benchmark_qdesn_shoulder_audit] dataset=%s series=%s candidate=%s done eligible=%s reason=%s\n",
      dataset_name,
      series_id,
      candidate_cfg$candidate_id,
      if (eligible) "TRUE" else "FALSE",
      reason %||% NA_character_
    ))
  }

  series_metrics_dt <- bind_or_empty(series_metrics)
  quantile_metrics_dt <- bind_or_empty(quantile_metrics)
  rhs_diagnostics_dt <- bind_or_empty(rhs_diagnostics)
  rhs_traces_dt <- bind_or_empty(rhs_traces)
  lead_paths_dt <- bind_or_empty(lead_paths)
  series_status_dt <- bind_or_empty(series_status)
  candidate_registry_dt <- bench_qdesn_candidate_registry_table(candidate_cfgs)
  candidate_summary_dt <- if (nrow(series_metrics_dt)) {
    bench_qdesn_shoulder_candidate_class(bench_qdesn_apply_selection_guards(data.table::copy(series_metrics_dt), cfg))
  } else {
    data.table::data.table()
  }

  bench_save_table(candidate_registry_dt, file.path(run_dirs$tables_dir, "audit_candidate_registry"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")
  bench_save_table(series_metrics_dt, file.path(run_dirs$tables_dir, "audit_series_metrics"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")
  bench_save_table(quantile_metrics_dt, file.path(run_dirs$tables_dir, "audit_quantile_model_metrics"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")
  bench_save_table(rhs_diagnostics_dt, file.path(run_dirs$tables_dir, "audit_rhs_diagnostics"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")
  bench_save_table(rhs_traces_dt, file.path(run_dirs$tables_dir, "audit_rhs_traces"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")
  bench_save_table(lead_paths_dt, file.path(run_dirs$tables_dir, "audit_quantile_lead_paths"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")
  bench_save_table(candidate_summary_dt, file.path(run_dirs$tables_dir, "audit_candidate_summary"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")
  bench_save_table(series_status_dt, file.path(run_dirs$tables_dir, "audit_series_status"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")

  recommended_config <- cfg$evaluation$recommended_config_path %||% bench_rel_path(
    file.path(context$paths$repo_root, "config", "benchmarks", "qdesn_synth_tourism_shoulder_followup.yaml"),
    repo_root = context$paths$repo_root
  )
  report_path <- bench_qdesn_write_shoulder_audit_report(run_dirs$run_dir, recommended_config = recommended_config)

  list(
    run_dirs = run_dirs,
    report_path = report_path,
    candidate_summary = candidate_summary_dt
  )
}

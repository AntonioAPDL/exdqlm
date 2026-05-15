# Reporting helpers for benchmark Q-DESN experiments.

bench_qdesn_plot_metric_by_dataset <- function(summary_dt, metric_col, y_label, out_path) {
  if (!requireNamespace("ggplot2", quietly = TRUE) || !nrow(summary_dt)) {
    return(invisible(NULL))
  }

  plot_dt <- data.table::copy(summary_dt)
  data.table::setorderv(plot_dt, c("dataset", metric_col))
  plot_dt[, metric_value := get(metric_col)]
  p <- ggplot2::ggplot(
    plot_dt,
    ggplot2::aes(x = dataset, y = metric_value, color = model_name, group = model_name)
  ) +
    ggplot2::geom_point(size = 2.2) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 30, hjust = 1),
      plot.title = ggplot2::element_text(face = "bold")
    ) +
    ggplot2::labs(
      title = sprintf("%s by dataset", y_label),
      x = "Dataset",
      y = y_label,
      color = "Model"
    )

  if (any(plot_dt[, .N, by = model_name]$N > 1L)) {
    p <- p + ggplot2::geom_line(linewidth = 0.8, alpha = 0.7)
  }

  ggplot2::ggsave(out_path, plot = p, width = 10, height = 5, dpi = 160)
  invisible(out_path)
}

bench_qdesn_write_report <- function(run_dir) {
  run_dir <- normalizePath(run_dir, mustWork = TRUE)
  tables_dir <- file.path(run_dir, "tables")
  reports_dir <- file.path(run_dir, "reports")
  figures_dir <- file.path(run_dir, "figures")
  manifests_dir <- file.path(run_dir, "manifest")

  dir.create(reports_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)

  series_metrics <- data.table::as.data.table(readRDS(file.path(tables_dir, "series_metrics.rds")))
  series_status <- data.table::as.data.table(readRDS(file.path(tables_dir, "series_status.rds")))
  selection_summary <- if (file.exists(file.path(tables_dir, "model_selection_summary.rds"))) {
    data.table::as.data.table(readRDS(file.path(tables_dir, "model_selection_summary.rds")))
  } else {
    data.table::data.table()
  }
  quantile_model_metrics <- if (file.exists(file.path(tables_dir, "quantile_model_metrics.rds"))) {
    data.table::as.data.table(readRDS(file.path(tables_dir, "quantile_model_metrics.rds")))
  } else {
    data.table::data.table()
  }
  rhs_diagnostics <- if (file.exists(file.path(tables_dir, "rhs_diagnostics.rds"))) {
    data.table::as.data.table(readRDS(file.path(tables_dir, "rhs_diagnostics.rds")))
  } else {
    data.table::data.table()
  }
  candidate_registry <- if (file.exists(file.path(tables_dir, "candidate_registry.rds"))) {
    data.table::as.data.table(readRDS(file.path(tables_dir, "candidate_registry.rds")))
  } else {
    data.table::data.table()
  }
  m4_comparability <- if (file.exists(file.path(tables_dir, "m4_comparability.rds"))) {
    data.table::as.data.table(readRDS(file.path(tables_dir, "m4_comparability.rds")))
  } else {
    data.table::data.table()
  }
  if (nrow(selection_summary)) {
    default_cols <- list(
      selected = FALSE,
      eligible = NA,
      eligibility_reason = NA_character_,
      selection_metric = NA_character_,
      selection_metric_value = NA_real_,
      tail_pinball_mean = NA_real_,
      quantile_abs_coverage_dev_mean = NA_real_,
      max_abs_quantile_coverage_dev = NA_real_,
      rhs_collapse_n = NA_real_,
      rhs_near_bound_n = NA_real_
    )
    for (nm in names(default_cols)) {
      if (!nm %in% names(selection_summary)) {
        selection_summary[, (nm) := default_cols[[nm]]]
      }
    }
  }

  dataset_summary <- bench_qdesn_dataset_summary_table(series_metrics)
  bench_save_table(dataset_summary, file.path(tables_dir, "dataset_model_summary"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")
  audit_diag <- bench_qdesn_write_audit_diagnostics(run_dir)

  plot_paths <- character(0)
  figure_rows <- list()
  fig_idx <- 1L
  crps_plot <- file.path(figures_dir, "dataset_model_crps.png")
  mase_plot <- file.path(figures_dir, "dataset_model_mase.png")
  msis_plot <- file.path(figures_dir, "dataset_model_msis95.png")
  if (nrow(dataset_summary)) {
    if (!is.null(bench_qdesn_plot_metric_by_dataset(dataset_summary, "crps_mean", "Mean CRPS", crps_plot))) {
      plot_paths <- c(plot_paths, crps_plot)
      figure_rows[[fig_idx]] <- data.table::data.table(figure_type = "dataset_model_crps", dataset = "all", path = crps_plot)
      fig_idx <- fig_idx + 1L
    }
    if (!is.null(bench_qdesn_plot_metric_by_dataset(dataset_summary, "mase_mean", "Mean MASE", mase_plot))) {
      plot_paths <- c(plot_paths, mase_plot)
      figure_rows[[fig_idx]] <- data.table::data.table(figure_type = "dataset_model_mase", dataset = "all", path = mase_plot)
      fig_idx <- fig_idx + 1L
    }
    if (!is.null(bench_qdesn_plot_metric_by_dataset(dataset_summary, "msis95_mean", "Mean MSIS (95%)", msis_plot))) {
      plot_paths <- c(plot_paths, msis_plot)
      figure_rows[[fig_idx]] <- data.table::data.table(figure_type = "dataset_model_msis95", dataset = "all", path = msis_plot)
      fig_idx <- fig_idx + 1L
    }
  }

  if (nrow(m4_comparability)) {
    m4_ds <- m4_comparability[group_type == "dataset"]
    owa_plot <- file.path(figures_dir, "m4_owa_by_dataset.png")
    msis_rel_plot <- file.path(figures_dir, "m4_msis95_rel_naive2_by_dataset.png")
    if (nrow(m4_ds)) {
      if (!is.null(bench_qdesn_plot_metric_by_dataset(m4_ds, "owa", "OWA vs Naive2", owa_plot))) {
        plot_paths <- c(plot_paths, owa_plot)
        figure_rows[[fig_idx]] <- data.table::data.table(figure_type = "m4_owa", dataset = "m4", path = owa_plot)
        fig_idx <- fig_idx + 1L
      }
      if (!is.null(bench_qdesn_plot_metric_by_dataset(m4_ds, "msis95_rel_naive2", "MSIS Ratio vs Naive2", msis_rel_plot))) {
        plot_paths <- c(plot_paths, msis_rel_plot)
        figure_rows[[fig_idx]] <- data.table::data.table(figure_type = "m4_msis95_rel_naive2", dataset = "m4", path = msis_rel_plot)
        fig_idx <- fig_idx + 1L
      }
    }
  }
  if (length(audit_diag$plot_paths)) {
    plot_paths <- c(plot_paths, audit_diag$plot_paths)
  }
  if (nrow(audit_diag$figure_manifest)) {
    figure_rows[[fig_idx]] <- audit_diag$figure_manifest
  }
  figure_manifest <- if (length(figure_rows)) {
    data.table::rbindlist(figure_rows, fill = TRUE)
  } else {
    data.table::data.table()
  }
  bench_save_table(figure_manifest, file.path(tables_dir, "figure_manifest"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")

  selected_rows <- if (nrow(selection_summary) && "selected" %in% names(selection_summary)) {
    selection_summary[selected == TRUE]
  } else {
    data.table::data.table()
  }
  selected_quantile_health <- if (nrow(selected_rows)) {
    selected_rows[, .(
      dataset,
      route_key,
      candidate_id,
      eligible,
      eligibility_reason,
      tail_pinball_mean,
      quantile_abs_coverage_dev_mean,
      max_abs_quantile_coverage_dev,
      rhs_collapse_n,
      rhs_near_bound_n
    )]
  } else {
    data.table::data.table()
  }
  quantile_test_summary <- if (nrow(quantile_model_metrics)) {
    quantile_model_metrics[stage == "test", .(
      pinball_mean = mean(pinball_mean, na.rm = TRUE),
      abs_coverage_dev = mean(abs_coverage_dev, na.rm = TRUE)
    ), by = .(dataset, quantile_label, is_tail)][order(dataset, quantile_label)]
  } else {
    data.table::data.table()
  }
  rhs_overall <- if (nrow(rhs_diagnostics)) {
    rhs_diagnostics[beta_prior_type %chin% c("rhs", "rhs_ns"), .(
      rhs_rows = .N,
      rhs_collapse_n = sum(collapse_flag, na.rm = TRUE),
      rhs_near_bound_n = sum(near_bound_flag, na.rm = TRUE),
      tau_last_min = if (any(is.finite(tau_last))) min(tau_last, na.rm = TRUE) else NA_real_,
      tau_last_median = if (any(is.finite(tau_last))) stats::median(tau_last, na.rm = TRUE) else NA_real_
    ), by = .(dataset, stage)][order(dataset, stage)]
  } else {
    data.table::data.table()
  }
  selected_dataset_configs <- if (nrow(selected_rows)) {
    selected_rows[, .(
      selected_candidate_id = paste(candidate_id, collapse = "|"),
      selected_route_keys = paste(route_key %||% "global", collapse = "|"),
      qdesn_selection_metric = paste(unique(selection_metric), collapse = "|"),
      qdesn_selection_metric_value = paste(sprintf("%.6f", selection_metric_value), collapse = "|"),
      selection_guard_relaxed = any(eligibility_reason %chin% "guard_relaxed_no_eligible_candidates"),
      qdesn_eligibility_reason = paste(unique(stats::na.omit(eligibility_reason)), collapse = "|")
    ), by = .(dataset)]
  } else {
    data.table::data.table()
  }
  m4_dataset_metrics <- if (nrow(m4_comparability)) {
    m4_comparability[group_type == "dataset", .(
      dataset,
      model_name,
      owa,
      msis95_rel_naive2
    )]
  } else {
    data.table::data.table()
  }
  benchmark_snapshot <- data.table::copy(dataset_summary)
  benchmark_snapshot[, crps_rank_within_dataset := data.table::frank(crps_mean, ties.method = "min"), by = dataset]
  if (nrow(m4_dataset_metrics)) {
    benchmark_snapshot <- m4_dataset_metrics[benchmark_snapshot, on = .(dataset, model_name)]
  } else {
    benchmark_snapshot[, `:=`(owa = NA_real_, msis95_rel_naive2 = NA_real_)]
  }
  if (nrow(selected_dataset_configs)) {
    benchmark_snapshot <- selected_dataset_configs[benchmark_snapshot, on = .(dataset)]
  } else {
    benchmark_snapshot[, `:=`(
      selected_candidate_id = NA_character_,
      selected_route_keys = NA_character_,
      qdesn_selection_metric = NA_character_,
      qdesn_selection_metric_value = NA_character_,
      selection_guard_relaxed = NA,
      qdesn_eligibility_reason = NA_character_
    )]
  }
  bench_save_table(
    benchmark_snapshot,
    file.path(tables_dir, "benchmark_result_snapshot"),
    write_csv = TRUE,
    write_rds = TRUE,
    compress = "gzip"
  )

  status_summary <- if (nrow(series_status)) {
    series_status[, .N, by = .(model_name, status)][order(model_name, status)]
  } else {
    data.table::data.table()
  }

  manifest <- if (file.exists(file.path(manifests_dir, "run_config.yaml"))) {
    bench_read_yaml(file.path(manifests_dir, "run_config.yaml"))
  } else {
    list()
  }

  lines <- c(
    "# Q-DESN Benchmark Report",
    "",
    sprintf("- Generated: %s", bench_timestamp_utc()),
    sprintf("- Run directory: `%s`", run_dir),
    sprintf("- Experiment: `%s`", manifest$config$evaluation$experiment_name %||% basename(run_dir)),
    sprintf("- Datasets evaluated: %d", data.table::uniqueN(series_metrics$dataset)),
    sprintf("- Series-model evaluations: %d", nrow(series_metrics)),
    sprintf("- Candidate specs considered: %d", nrow(candidate_registry)),
    sprintf("- Baselines: `%s`", paste(manifest$config$evaluation$baselines$models %||% character(0), collapse = "`, `")),
    ""
  )

  if (nrow(selected_rows)) {
    lines <- c(lines, "## Selected Q-DESN Configurations", "")
    for (i in seq_len(nrow(selected_rows))) {
      row <- selected_rows[i]
      cand <- if (nrow(candidate_registry)) candidate_registry[candidate_id == row$candidate_id[[1L]]][1L] else data.table::data.table()
      route_label <- if ("route_key" %in% names(row) && !is.na(row$route_key[[1L]]) && row$route_key[[1L]] != "global") {
        sprintf(" [%s]", row$route_key[[1L]])
      } else {
        ""
      }
      cfg_bits <- character(0)
      if (nrow(cand)) {
        cfg_bits <- c(
          sprintf("n=%s", cand$fit_n[[1L]]),
          sprintf("m=%s", cand$fit_m[[1L]]),
          sprintf("rho=%s", cand$fit_rho[[1L]]),
          sprintf("seeds=%s", cand$fit_seed_set[[1L]]),
          sprintf("cal=%s", cand$calibration_mode[[1L]])
        )
      }
      lines <- c(
        lines,
        sprintf(
          "- `%s`%s: `%s` (selection metric `%s` = %.4f%s)",
          row$dataset[[1L]],
          route_label,
          row$candidate_id[[1L]],
          row$selection_metric[[1L]],
          row$selection_metric_value[[1L]],
          if (length(cfg_bits)) paste0("; ", paste(cfg_bits, collapse = ", ")) else ""
        )
      )
    }
    lines <- c(lines, "")
  }

  if (nrow(selected_quantile_health)) {
    lines <- c(lines, "## Selection Quantile Health", "")
    for (i in seq_len(nrow(selected_quantile_health))) {
      row <- selected_quantile_health[i]
      lines <- c(
        lines,
        sprintf(
          "- `%s` [%s]: eligible=%s, tail pinball=%.4f, mean |coverage-p|=%.4f, max |coverage-p|=%.4f, rhs collapse=%d, rhs near-bound=%d%s",
          row$dataset[[1L]],
          row$route_key[[1L]] %||% "global",
          ifelse(isTRUE(row$eligible[[1L]]), "yes", "no"),
          row$tail_pinball_mean[[1L]],
          row$quantile_abs_coverage_dev_mean[[1L]],
          row$max_abs_quantile_coverage_dev[[1L]],
          as.integer(row$rhs_collapse_n[[1L]] %||% 0L),
          as.integer(row$rhs_near_bound_n[[1L]] %||% 0L),
          if (!is.na(row$eligibility_reason[[1L]]) && nzchar(row$eligibility_reason[[1L]])) {
            paste0("; reason=", row$eligibility_reason[[1L]])
          } else {
            ""
          }
        )
      )
    }
    lines <- c(lines, "")
  }

  if (nrow(dataset_summary)) {
    lines <- c(lines, "## Dataset-Level Summary", "")
    for (i in seq_len(nrow(dataset_summary))) {
      row <- dataset_summary[i]
      lines <- c(
        lines,
        sprintf(
          "- `%s` / `%s`: CRPS=%.4f, MASE=%.4f, sMAPE=%.4f, MSIS95=%.4f",
          row$dataset[[1L]],
          row$model_name[[1L]],
          row$crps_mean[[1L]],
          row$mase_mean[[1L]],
          row$smape_mean[[1L]],
          row$msis95_mean[[1L]]
        )
      )
    }
    lines <- c(lines, "")
  }

  if (nrow(m4_comparability)) {
    lines <- c(lines, "## M4 Comparability", "")
    m4_overall <- m4_comparability[group_type == "overall"]
    if (!nrow(m4_overall)) {
      m4_overall <- m4_comparability
    }
    for (i in seq_len(nrow(m4_overall))) {
      row <- m4_overall[i]
      lines <- c(
        lines,
        sprintf(
          "- `%s`: OWA=%.4f, sMAPE=%.4f, MASE=%.4f, MSIS95 ratio=%.4f",
          row$model_name[[1L]],
          row$owa[[1L]],
          row$smape_mean[[1L]],
          row$mase_mean[[1L]],
          row$msis95_rel_naive2[[1L]]
        )
      )
    }
    lines <- c(lines, "")
  }

  if (nrow(audit_diag$audit_summary)) {
    lines <- c(lines, "## Audit Diagnostics", "")
    audit_overall <- audit_diag$audit_summary[dataset == "audit_overall"]
    if (nrow(audit_overall)) {
      row <- audit_overall[1L]
      lines <- c(
        lines,
        sprintf(
          "- `%s`: PIT mean=%.4f, PIT var=%.4f, coverage95=%.4f, ACD95=%.4f",
          row$model_name[[1L]],
          row$pit_mean[[1L]],
          row$pit_var[[1L]],
          row$coverage95_mean[[1L]],
          row$acd95_mean[[1L]]
        ),
        ""
      )
    }
  }

  if (nrow(quantile_test_summary)) {
    lines <- c(lines, "## Test Quantile Diagnostics", "")
    for (i in seq_len(nrow(quantile_test_summary))) {
      row <- quantile_test_summary[i]
      lines <- c(
        lines,
        sprintf(
          "- `%s` / q=%s%s: pinball=%.4f, mean |coverage-p|=%.4f",
          row$dataset[[1L]],
          row$quantile_label[[1L]],
          if (isTRUE(row$is_tail[[1L]])) " (tail)" else "",
          row$pinball_mean[[1L]],
          row$abs_coverage_dev[[1L]]
        )
      )
    }
    lines <- c(lines, "")
  }

  if (nrow(rhs_overall)) {
    lines <- c(lines, "## RHS Diagnostics", "")
    for (i in seq_len(nrow(rhs_overall))) {
      row <- rhs_overall[i]
      lines <- c(
        lines,
        sprintf(
          "- `%s` / `%s`: rows=%d, collapse=%d, near-bound=%d, tau_last_min=%.4e, tau_last_median=%.4e",
          row$dataset[[1L]],
          row$stage[[1L]],
          as.integer(row$rhs_rows[[1L]]),
          as.integer(row$rhs_collapse_n[[1L]]),
          as.integer(row$rhs_near_bound_n[[1L]]),
          row$tau_last_min[[1L]],
          row$tau_last_median[[1L]]
        )
      )
    }
    lines <- c(lines, "")
  }

  if (nrow(status_summary)) {
    lines <- c(lines, "## Execution Status", "")
    lines <- c(lines, apply(status_summary, 1L, function(row) {
      sprintf("- `%s` / `%s`: %s", row[["model_name"]], row[["status"]], row[["N"]])
    }))
    lines <- c(lines, "")
  }

  if (length(plot_paths)) {
    lines <- c(lines, "## Figures", "")
    lines <- c(lines, vapply(plot_paths, function(path) sprintf("- `%s`", path), character(1)))
    lines <- c(lines, "")
  }

  report_path <- file.path(reports_dir, "benchmark_qdesn_summary.md")
  writeLines(lines, report_path)

  list(
    report_path = report_path,
    dataset_summary = dataset_summary,
    status_summary = status_summary,
    selected_rows = selected_rows,
    plot_paths = plot_paths
  )
}

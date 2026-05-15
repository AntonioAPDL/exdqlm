# Focused Stage-A RHS debugging summaries for benchmark Q-DESN runs.

bench_qdesn_rhs_stageA_candidate_summary <- function(
  selection_summary,
  quantile_model_metrics,
  rhs_diagnostics,
  candidate_registry,
  stage = "validation"
) {
  selection_dt <- data.table::as.data.table(selection_summary)
  quant_dt <- data.table::as.data.table(quantile_model_metrics)
  rhs_dt <- data.table::as.data.table(rhs_diagnostics)
  registry_dt <- data.table::as.data.table(candidate_registry)

  if (!nrow(selection_dt)) {
    return(data.table::data.table())
  }

  safe_mean <- function(x) if (all(!is.finite(x))) NA_real_ else mean(x, na.rm = TRUE)
  safe_max <- function(x) if (all(!is.finite(x))) NA_real_ else max(x, na.rm = TRUE)
  safe_min <- function(x) if (all(!is.finite(x))) NA_real_ else min(x, na.rm = TRUE)
  safe_median <- function(x) if (all(!is.finite(x))) NA_real_ else stats::median(x, na.rm = TRUE)

  stage_name <- as.character(stage)[1L]
  quant_stage <- quant_dt[stage %chin% stage_name]
  rhs_stage <- rhs_dt[stage %chin% stage_name]

  quant_summary <- if (nrow(quant_stage)) {
    quant_stage[, .(
      quantile_series_n = uniqueN(series_id),
      quantile_rows_n = .N,
      quantile_levels_n = uniqueN(quantile_label),
      median_pinball_mean = safe_mean(pinball_mean[abs(quantile_p - 0.50) < 1e-8]),
      central_pinball_mean = safe_mean(pinball_mean),
      mean_abs_coverage_dev = safe_mean(abs_coverage_dev),
      max_abs_coverage_dev = safe_max(abs_coverage_dev),
      mean_abs_pit_dev = safe_mean(abs_pit_dev_mean)
    ), by = .(dataset, route_key, candidate_id)]
  } else {
    data.table::data.table()
  }

  rhs_summary <- if (nrow(rhs_stage)) {
    rhs_stage[, .(
      rhs_rows = .N,
      rhs_series_n = uniqueN(series_id),
      collapse_n = sum(collapse_flag, na.rm = TRUE),
      near_bound_n = sum(near_bound_flag, na.rm = TRUE),
      collapse_any = any(collapse_flag, na.rm = TRUE),
      near_bound_any = any(near_bound_flag, na.rm = TRUE),
      tau_last_min = safe_min(tau_last),
      tau_last_median = safe_median(tau_last),
      beta_l2_min = safe_min(beta_l2_last),
      beta_l2_median = safe_median(beta_l2_last),
      e_invv_med_max = safe_max(E_invV_med_last)
    ), by = .(dataset, route_key, candidate_id)]
  } else {
    data.table::data.table()
  }

  out <- unique(selection_dt[, .(
    dataset,
    route_key,
    candidate_id,
    n_series,
    n_applicable,
    n_failed,
    n_inapplicable,
    runtime_sec,
    selected
  )])

  if (nrow(quant_summary)) {
    out <- quant_summary[out, on = .(dataset, route_key, candidate_id)]
  }
  if (nrow(rhs_summary)) {
    out <- rhs_summary[out, on = .(dataset, route_key, candidate_id)]
  }
  if (nrow(registry_dt)) {
    meta_cols <- intersect(
      c(
        "candidate_id", "p_vec", "fit_D", "fit_n", "fit_m", "fit_rho",
        "fit_washout", "vb_rhs_tau0", "vb_rhs_s2", "vb_rhs_init_log_tau",
        "vb_rhs_freeze_tau_iters", "vb_rhs_freeze_tau_warmup_iters",
        "vb_rhs_update_every", "vb_rhs_update_every_warmup",
        "vb_rhs_update_every_warmup_iters", "vb_rhs_min_tau_updates",
        "vb_rhs_force_tau_after_warmup"
      ),
      names(registry_dt)
    )
    out <- registry_dt[, ..meta_cols][out, on = "candidate_id"]
  }

  for (nm in c(
    "n_series", "n_applicable", "n_failed", "n_inapplicable",
    "quantile_series_n", "quantile_rows_n", "quantile_levels_n",
    "rhs_rows", "rhs_series_n", "collapse_n", "near_bound_n"
  )) {
    if (nm %in% names(out)) {
      out[, (nm) := as.integer(get(nm))]
    }
  }
  for (nm in c(
    "median_pinball_mean", "central_pinball_mean", "mean_abs_coverage_dev",
    "max_abs_coverage_dev", "mean_abs_pit_dev", "tau_last_min",
    "tau_last_median", "beta_l2_min", "beta_l2_median", "e_invv_med_max",
    "runtime_sec"
  )) {
    if (nm %in% names(out)) {
      out[, (nm) := as.numeric(get(nm))]
    }
  }
  for (nm in c("collapse_any", "near_bound_any", "selected", "vb_rhs_force_tau_after_warmup")) {
    if (nm %in% names(out)) {
      out[, (nm) := as.logical(get(nm))]
    }
  }

  out[is.na(collapse_any), collapse_any := FALSE]
  out[is.na(near_bound_any), near_bound_any := FALSE]
  out[is.na(n_failed), n_failed := 0L]
  out[is.na(n_applicable), n_applicable := 0L]

  out[, stageA_pass := (
    n_applicable > 0L &
      n_failed == 0L &
      !collapse_any &
      !near_bound_any &
      is.finite(tau_last_min) &
      tau_last_min > 0 &
      is.finite(beta_l2_min) &
      beta_l2_min > 0
  )]
  out[, stageA_fail_reason := data.table::fifelse(
    n_applicable <= 0L, "no_applicable_validation_runs",
    data.table::fifelse(n_failed > 0L, "validation_failure",
      data.table::fifelse(collapse_any, "rhs_collapse",
        data.table::fifelse(near_bound_any, "rhs_near_bound",
          data.table::fifelse(!is.finite(tau_last_min) | tau_last_min <= 0, "invalid_tau_last",
            data.table::fifelse(!is.finite(beta_l2_min) | beta_l2_min <= 0, "zero_beta_norm", "ok")
          )
        )
      )
    )
  )]

  data.table::setorderv(
    out,
    cols = c("dataset", "stageA_pass", "median_pinball_mean", "central_pinball_mean", "runtime_sec", "candidate_id"),
    order = c(1L, -1L, 1L, 1L, 1L, 1L)
  )
  out[, stageA_rank := seq_len(.N), by = dataset]
  out[]
}

bench_qdesn_rhs_stageA_overall_summary <- function(candidate_summary) {
  dt <- data.table::as.data.table(candidate_summary)
  if (!nrow(dt)) {
    return(data.table::data.table())
  }

  safe_mean <- function(x) if (all(!is.finite(x))) NA_real_ else mean(x, na.rm = TRUE)

  out <- dt[, .(
    datasets_n = uniqueN(dataset),
    datasets_pass_n = sum(stageA_pass, na.rm = TRUE),
    all_stageA_pass = all(stageA_pass),
    median_pinball_macro = safe_mean(median_pinball_mean),
    central_pinball_macro = safe_mean(central_pinball_mean),
    mean_abs_coverage_dev_macro = safe_mean(mean_abs_coverage_dev),
    max_abs_coverage_dev_max = if (all(!is.finite(max_abs_coverage_dev))) NA_real_ else max(max_abs_coverage_dev, na.rm = TRUE),
    mean_abs_pit_dev_macro = safe_mean(mean_abs_pit_dev),
    runtime_sec_sum = sum(runtime_sec, na.rm = TRUE),
    collapse_datasets_n = sum(collapse_any, na.rm = TRUE),
    near_bound_datasets_n = sum(near_bound_any, na.rm = TRUE),
    tau_last_min_overall = if (all(!is.finite(tau_last_min))) NA_real_ else min(tau_last_min, na.rm = TRUE),
    beta_l2_min_overall = if (all(!is.finite(beta_l2_min))) NA_real_ else min(beta_l2_min, na.rm = TRUE),
    fail_reasons = paste(unique(stageA_fail_reason), collapse = "|"),
    p_vec = paste(unique(stats::na.omit(p_vec)), collapse = "|"),
    fit_D = paste(unique(stats::na.omit(fit_D)), collapse = "|"),
    fit_n = paste(unique(stats::na.omit(fit_n)), collapse = "|"),
    fit_m = paste(unique(stats::na.omit(fit_m)), collapse = "|"),
    fit_rho = paste(unique(stats::na.omit(fit_rho)), collapse = "|"),
    fit_washout = paste(unique(stats::na.omit(fit_washout)), collapse = "|"),
    vb_rhs_tau0 = paste(unique(stats::na.omit(vb_rhs_tau0)), collapse = "|"),
    vb_rhs_s2 = paste(unique(stats::na.omit(vb_rhs_s2)), collapse = "|"),
    vb_rhs_init_log_tau = paste(unique(stats::na.omit(vb_rhs_init_log_tau)), collapse = "|"),
    vb_rhs_freeze_tau_iters = paste(unique(stats::na.omit(vb_rhs_freeze_tau_iters)), collapse = "|"),
    vb_rhs_freeze_tau_warmup_iters = paste(unique(stats::na.omit(vb_rhs_freeze_tau_warmup_iters)), collapse = "|")
  ), by = .(candidate_id)]

  data.table::setorderv(
    out,
    cols = c("all_stageA_pass", "datasets_pass_n", "median_pinball_macro", "central_pinball_macro", "runtime_sec_sum", "candidate_id"),
    order = c(-1L, -1L, 1L, 1L, 1L, 1L)
  )
  out[, stageA_overall_rank := seq_len(.N)]
  out[]
}

bench_qdesn_rhs_selected_refit_summary <- function(
  selection_summary,
  quantile_model_metrics,
  rhs_diagnostics,
  stage = "test"
) {
  selection_dt <- data.table::as.data.table(selection_summary)
  quant_dt <- data.table::as.data.table(quantile_model_metrics)
  rhs_dt <- data.table::as.data.table(rhs_diagnostics)

  selected_dt <- unique(selection_dt[selected == TRUE, .(dataset, route_key, candidate_id)])
  if (!nrow(selected_dt)) {
    return(data.table::data.table())
  }

  safe_mean <- function(x) if (all(!is.finite(x))) NA_real_ else mean(x, na.rm = TRUE)
  safe_max <- function(x) if (all(!is.finite(x))) NA_real_ else max(x, na.rm = TRUE)
  safe_min <- function(x) if (all(!is.finite(x))) NA_real_ else min(x, na.rm = TRUE)

  stage_name <- as.character(stage)[1L]
  quant_stage <- quant_dt[stage %chin% stage_name]
  rhs_stage <- rhs_dt[stage %chin% stage_name]

  quant_summary <- if (nrow(quant_stage)) {
    quant_stage[selected_dt, on = .(dataset, route_key, candidate_id), nomatch = 0L][, .(
      quantile_rows_n = .N,
      quantile_levels_n = uniqueN(quantile_label),
      median_pinball_mean = safe_mean(pinball_mean[abs(quantile_p - 0.50) < 1e-8]),
      central_pinball_mean = safe_mean(pinball_mean),
      mean_abs_coverage_dev = safe_mean(abs_coverage_dev),
      max_abs_coverage_dev = safe_max(abs_coverage_dev),
      mean_abs_pit_dev = safe_mean(abs_pit_dev_mean)
    ), by = .(dataset, route_key, candidate_id)]
  } else {
    data.table::data.table()
  }

  rhs_summary <- if (nrow(rhs_stage)) {
    rhs_stage[selected_dt, on = .(dataset, route_key, candidate_id), nomatch = 0L][, .(
      rhs_rows = .N,
      collapse_n = sum(collapse_flag, na.rm = TRUE),
      near_bound_n = sum(near_bound_flag, na.rm = TRUE),
      collapse_any = any(collapse_flag, na.rm = TRUE),
      near_bound_any = any(near_bound_flag, na.rm = TRUE),
      tau_last_min = safe_min(tau_last),
      tau_last_median = if (all(!is.finite(tau_last))) NA_real_ else stats::median(tau_last, na.rm = TRUE),
      beta_l2_min = safe_min(beta_l2_last),
      beta_l2_median = if (all(!is.finite(beta_l2_last))) NA_real_ else stats::median(beta_l2_last, na.rm = TRUE),
      e_invv_med_max = safe_max(E_invV_med_last)
    ), by = .(dataset, route_key, candidate_id)]
  } else {
    data.table::data.table()
  }

  out <- copy(selected_dt)
  if (nrow(quant_summary)) {
    out <- quant_summary[out, on = .(dataset, route_key, candidate_id)]
  }
  if (nrow(rhs_summary)) {
    out <- rhs_summary[out, on = .(dataset, route_key, candidate_id)]
  }

  for (nm in c("quantile_rows_n", "quantile_levels_n", "rhs_rows", "collapse_n", "near_bound_n")) {
    if (nm %in% names(out)) {
      out[, (nm) := as.integer(get(nm))]
    }
  }
  for (nm in c(
    "median_pinball_mean", "central_pinball_mean", "mean_abs_coverage_dev",
    "max_abs_coverage_dev", "mean_abs_pit_dev", "tau_last_min",
    "tau_last_median", "beta_l2_min", "beta_l2_median", "e_invv_med_max"
  )) {
    if (nm %in% names(out)) {
      out[, (nm) := as.numeric(get(nm))]
    }
  }
  for (nm in c("collapse_any", "near_bound_any")) {
    if (nm %in% names(out)) {
      out[, (nm) := as.logical(get(nm))]
    }
  }

  out[is.na(collapse_any), collapse_any := FALSE]
  out[is.na(near_bound_any), near_bound_any := FALSE]
  out[, refit_stage := stage_name]
  out[, refit_pass := (
    !collapse_any &
      !near_bound_any &
      is.finite(tau_last_min) &
      tau_last_min > 0 &
      is.finite(beta_l2_min) &
      beta_l2_min > 0
  )]
  out[, refit_fail_reason := data.table::fifelse(
    collapse_any, "rhs_collapse",
    data.table::fifelse(near_bound_any, "rhs_near_bound",
      data.table::fifelse(!is.finite(tau_last_min) | tau_last_min <= 0, "invalid_tau_last",
        data.table::fifelse(!is.finite(beta_l2_min) | beta_l2_min <= 0, "zero_beta_norm", "ok")
      )
    )
  )]
  out[]
}

bench_qdesn_rhs_stageA_write_report <- function(run_dir) {
  run_dir <- normalizePath(run_dir, mustWork = TRUE)
  tables_dir <- file.path(run_dir, "tables")
  reports_dir <- file.path(run_dir, "reports")
  figures_dir <- file.path(run_dir, "figures")
  dir.create(reports_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)

  load_dt <- function(name) {
    path <- file.path(tables_dir, sprintf("%s.rds", name))
    if (!file.exists(path)) return(data.table::data.table())
    data.table::as.data.table(readRDS(path))
  }

  selection_summary <- load_dt("model_selection_summary")
  quantile_model_metrics <- load_dt("quantile_model_metrics")
  rhs_diagnostics <- load_dt("rhs_diagnostics")
  candidate_registry <- load_dt("candidate_registry")

  candidate_summary <- bench_qdesn_rhs_stageA_candidate_summary(
    selection_summary = selection_summary,
    quantile_model_metrics = quantile_model_metrics,
    rhs_diagnostics = rhs_diagnostics,
    candidate_registry = candidate_registry,
    stage = "validation"
  )
  overall_summary <- bench_qdesn_rhs_stageA_overall_summary(candidate_summary)
  selected_refit_summary <- bench_qdesn_rhs_selected_refit_summary(
    selection_summary = selection_summary,
    quantile_model_metrics = quantile_model_metrics,
    rhs_diagnostics = rhs_diagnostics,
    stage = "test"
  )

  bench_save_table(candidate_summary, file.path(tables_dir, "rhs_stageA_candidate_summary"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")
  bench_save_table(overall_summary, file.path(tables_dir, "rhs_stageA_overall_summary"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")
  bench_save_table(selected_refit_summary, file.path(tables_dir, "rhs_selected_refit_summary"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")

  plot_paths <- character(0)
  if (nrow(candidate_summary)) {
    make_plot <- function(metric_col, y_label, filename, log10_y = FALSE) {
      dt <- copy(candidate_summary)
      dt[, candidate_id := stats::reorder(candidate_id, get(metric_col), FUN = function(z) mean(z, na.rm = TRUE))]
      p <- ggplot2::ggplot(dt, ggplot2::aes(x = candidate_id, y = .data[[metric_col]], fill = stageA_pass)) +
        ggplot2::geom_col() +
        ggplot2::facet_wrap(~dataset, scales = "free_x") +
        ggplot2::coord_flip() +
        ggplot2::scale_fill_manual(values = c("TRUE" = "#1b7f5a", "FALSE" = "#b13a3a"), drop = FALSE) +
        ggplot2::labs(x = NULL, y = y_label, fill = "Stage A pass") +
        ggplot2::theme_minimal(base_size = 12)
      if (isTRUE(log10_y)) {
        p <- p + ggplot2::scale_y_log10()
      }
      out_path <- file.path(figures_dir, filename)
      ggplot2::ggsave(out_path, p, width = 9, height = 4.8, dpi = 160)
      out_path
    }

    if (any(is.finite(candidate_summary$tau_last_min) & candidate_summary$tau_last_min > 0, na.rm = TRUE)) {
      plot_paths <- c(plot_paths, make_plot("tau_last_min", "Min tau_last (validation)", "rhs_stageA_tau_last.png", log10_y = TRUE))
    }
    if (any(is.finite(candidate_summary$beta_l2_min) & candidate_summary$beta_l2_min > 0, na.rm = TRUE)) {
      plot_paths <- c(plot_paths, make_plot("beta_l2_min", "Min beta L2 (validation)", "rhs_stageA_beta_l2.png", log10_y = TRUE))
    }
    if (any(is.finite(candidate_summary$median_pinball_mean), na.rm = TRUE)) {
      plot_paths <- c(plot_paths, make_plot("median_pinball_mean", "Median quantile pinball (validation)", "rhs_stageA_median_pinball.png", log10_y = FALSE))
    }
  }

  lines <- c(
    "# Stage A RHS Debug Report",
    "",
    sprintf("- Generated: %s", bench_timestamp_utc()),
    sprintf("- Run directory: `%s`", run_dir),
    sprintf("- Validation candidates summarized: %d", nrow(candidate_summary)),
    sprintf("- Unique candidate specs: %d", if (nrow(candidate_summary)) data.table::uniqueN(candidate_summary$candidate_id) else 0L),
    "- Stage A pass is a validation-stage screen only; selected-candidate refits are checked separately below.",
    ""
  )

  if (nrow(overall_summary)) {
    top <- overall_summary[1L]
    lines <- c(
      lines,
      "## Overall Ranking",
      "",
      sprintf(
        "- Top candidate: `%s` (pass all datasets=%s, datasets passed=%d/%d, median pinball macro=%.4f, tau0=%s, s2=%s, init_log_tau=%s, freeze_tau_iters=%s)",
        top$candidate_id[[1L]],
        ifelse(isTRUE(top$all_stageA_pass[[1L]]), "yes", "no"),
        as.integer(top$datasets_pass_n[[1L]]),
        as.integer(top$datasets_n[[1L]]),
        as.numeric(top$median_pinball_macro[[1L]]),
        top$vb_rhs_tau0[[1L]],
        top$vb_rhs_s2[[1L]],
        top$vb_rhs_init_log_tau[[1L]],
        top$vb_rhs_freeze_tau_iters[[1L]]
      ),
      ""
    )
  }

  if (nrow(candidate_summary)) {
    lines <- c(lines, "## Dataset Candidate Summary", "")
    for (dataset_name in unique(candidate_summary$dataset)) {
      lines <- c(lines, sprintf("### %s", dataset_name), "")
      rows <- candidate_summary[dataset == dataset_name]
      for (i in seq_len(nrow(rows))) {
        row <- rows[i]
        lines <- c(
          lines,
          sprintf(
            "- `%s`: pass=%s, fail_reason=%s, median pinball=%.4f, central pinball=%.4f, tau_last_min=%.3e, beta_l2_min=%.3e, collapse=%s, near_bound=%s, tau0=%s, s2=%s, init_log_tau=%s, freeze_tau_iters=%s",
            row$candidate_id[[1L]],
            ifelse(isTRUE(row$stageA_pass[[1L]]), "yes", "no"),
            row$stageA_fail_reason[[1L]],
            as.numeric(row$median_pinball_mean[[1L]]),
            as.numeric(row$central_pinball_mean[[1L]]),
            as.numeric(row$tau_last_min[[1L]]),
            as.numeric(row$beta_l2_min[[1L]]),
            ifelse(isTRUE(row$collapse_any[[1L]]), "yes", "no"),
            ifelse(isTRUE(row$near_bound_any[[1L]]), "yes", "no"),
            row$vb_rhs_tau0[[1L]],
            row$vb_rhs_s2[[1L]],
            row$vb_rhs_init_log_tau[[1L]],
            row$vb_rhs_freeze_tau_iters[[1L]]
          )
        )
      }
      lines <- c(lines, "")
    }
  }

  if (nrow(selected_refit_summary)) {
    lines <- c(lines, "## Selected Candidate Test Refit Check", "")
    for (dataset_name in unique(selected_refit_summary$dataset)) {
      row <- selected_refit_summary[dataset == dataset_name][1L]
      lines <- c(
        lines,
        sprintf(
          "- `%s`: candidate=`%s`, pass=%s, fail_reason=%s, median pinball=%.4f, central pinball=%.4f, tau_last_min=%.3e, beta_l2_min=%.3e, collapse=%s, near_bound=%s",
          dataset_name,
          row$candidate_id[[1L]],
          ifelse(isTRUE(row$refit_pass[[1L]]), "yes", "no"),
          row$refit_fail_reason[[1L]],
          as.numeric(row$median_pinball_mean[[1L]]),
          as.numeric(row$central_pinball_mean[[1L]]),
          as.numeric(row$tau_last_min[[1L]]),
          as.numeric(row$beta_l2_min[[1L]]),
          ifelse(isTRUE(row$collapse_any[[1L]]), "yes", "no"),
          ifelse(isTRUE(row$near_bound_any[[1L]]), "yes", "no")
        )
      )
    }
    lines <- c(lines, "")
  }

  if (length(plot_paths)) {
    lines <- c(lines, "## Figures", "")
    lines <- c(lines, sprintf("- `%s`", plot_paths))
    lines <- c(lines, "")
  }

  report_path <- file.path(reports_dir, "rhs_stageA_debug.md")
  writeLines(lines, report_path)

  list(
    candidate_summary = candidate_summary,
    overall_summary = overall_summary,
    selected_refit_summary = selected_refit_summary,
    report_path = report_path,
    plot_paths = plot_paths
  )
}

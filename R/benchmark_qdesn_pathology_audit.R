# Quantile-pathology audit for fixed-slice RHS / quantile debugging.

bench_qdesn_pathology_band <- function(p) {
  ifelse(
    p <= 0.15, "lower_tail",
    ifelse(
      p <= 0.40, "lower_shoulder",
      ifelse(
        p <= 0.55, "center",
        ifelse(p <= 0.80, "upper_shoulder", "upper_tail")
      )
    )
  )
}

bench_qdesn_pathology_load_fit_audit <- function(run_dir, repo_root = ".") {
  run_dir <- bench_abs_path(run_dir, repo_root = repo_root, must_work = TRUE)
  audit_path <- file.path(run_dir, "tables", "rhs_collapse_fit_audit.rds")
  if (file.exists(audit_path)) {
    return(data.table::as.data.table(readRDS(audit_path)))
  }

  bench_qdesn_collapse_audit_fit_table(run_dir = run_dir, repo_root = repo_root)
}

bench_qdesn_pathology_candidate_summary <- function(fit_dt, stage = "validation") {
  dt <- data.table::as.data.table(fit_dt)
  stage_name <- as.character(stage)[1L]
  dt <- dt[stage %chin% stage_name]
  if (!nrow(dt)) {
    return(data.table::data.table())
  }

  dt[, quantile_band := bench_qdesn_pathology_band(quantile_p)]
  dt[, qhat_abs_mean := abs(qhat_mean)]

  band_summary <- dt[, .(
    band_pinball_mean = mean(pinball_mean, na.rm = TRUE),
    band_qhat_abs_mean = mean(qhat_abs_mean, na.rm = TRUE),
    band_abs_coverage_dev_mean = mean(abs_coverage_dev, na.rm = TRUE),
    band_abs_pit_dev_mean = mean(abs_pit_dev_mean, na.rm = TRUE)
  ), by = .(candidate_id, dataset, quantile_band)]

  out <- dt[, .(
    n_fits = .N,
    collapse_n = sum(collapse_flag, na.rm = TRUE),
    fragile_n = sum(stability_state == "fragile_noncollapsed", na.rm = TRUE),
    stable_n = sum(stability_state == "stable", na.rm = TRUE),
    tau_last_min = min(tau_last, na.rm = TRUE),
    beta_l2_min = min(beta_l2_last, na.rm = TRUE),
    overall_pinball_mean = mean(pinball_mean, na.rm = TRUE),
    overall_qhat_abs_mean = mean(qhat_abs_mean, na.rm = TRUE),
    overall_abs_coverage_dev_mean = mean(abs_coverage_dev, na.rm = TRUE),
    overall_abs_pit_dev_mean = mean(abs_pit_dev_mean, na.rm = TRUE)
  ), by = .(candidate_id, dataset)]

  band_wide <- data.table::dcast(
    band_summary,
    candidate_id + dataset ~ quantile_band,
    value.var = c(
      "band_pinball_mean",
      "band_qhat_abs_mean",
      "band_abs_coverage_dev_mean",
      "band_abs_pit_dev_mean"
    )
  )
  out <- merge(out, band_wide, by = c("candidate_id", "dataset"), all.x = TRUE)

  rename_if_present <- function(dt_obj, old, new) {
    if (old %in% names(dt_obj)) {
      data.table::setnames(dt_obj, old, new)
    }
    dt_obj
  }

  out <- rename_if_present(out, "band_pinball_mean_lower_tail", "lower_tail_pinball_mean")
  out <- rename_if_present(out, "band_pinball_mean_lower_shoulder", "lower_shoulder_pinball_mean")
  out <- rename_if_present(out, "band_pinball_mean_center", "center_pinball_mean")
  out <- rename_if_present(out, "band_pinball_mean_upper_shoulder", "upper_shoulder_pinball_mean")
  out <- rename_if_present(out, "band_pinball_mean_upper_tail", "upper_tail_pinball_mean")

  out <- rename_if_present(out, "band_qhat_abs_mean_lower_tail", "lower_tail_qhat_abs_mean")
  out <- rename_if_present(out, "band_qhat_abs_mean_lower_shoulder", "lower_shoulder_qhat_abs_mean")
  out <- rename_if_present(out, "band_qhat_abs_mean_center", "center_qhat_abs_mean")
  out <- rename_if_present(out, "band_qhat_abs_mean_upper_shoulder", "upper_shoulder_qhat_abs_mean")
  out <- rename_if_present(out, "band_qhat_abs_mean_upper_tail", "upper_tail_qhat_abs_mean")

  out <- rename_if_present(out, "band_abs_coverage_dev_mean_lower_tail", "lower_tail_abs_coverage_dev_mean")
  out <- rename_if_present(out, "band_abs_coverage_dev_mean_lower_shoulder", "lower_shoulder_abs_coverage_dev_mean")
  out <- rename_if_present(out, "band_abs_coverage_dev_mean_center", "center_abs_coverage_dev_mean")
  out <- rename_if_present(out, "band_abs_coverage_dev_mean_upper_shoulder", "upper_shoulder_abs_coverage_dev_mean")
  out <- rename_if_present(out, "band_abs_coverage_dev_mean_upper_tail", "upper_tail_abs_coverage_dev_mean")

  out <- rename_if_present(out, "band_abs_pit_dev_mean_lower_tail", "lower_tail_abs_pit_dev_mean")
  out <- rename_if_present(out, "band_abs_pit_dev_mean_lower_shoulder", "lower_shoulder_abs_pit_dev_mean")
  out <- rename_if_present(out, "band_abs_pit_dev_mean_center", "center_abs_pit_dev_mean")
  out <- rename_if_present(out, "band_abs_pit_dev_mean_upper_shoulder", "upper_shoulder_abs_pit_dev_mean")
  out <- rename_if_present(out, "band_abs_pit_dev_mean_upper_tail", "upper_tail_abs_pit_dev_mean")

  out[, shoulder_pinball_mean := rowMeans(.SD, na.rm = TRUE), .SDcols = c("lower_shoulder_pinball_mean", "upper_shoulder_pinball_mean")]
  out[, reference_pinball_mean := rowMeans(.SD, na.rm = TRUE), .SDcols = c("lower_tail_pinball_mean", "center_pinball_mean", "upper_tail_pinball_mean")]
  out[, shoulder_qhat_abs_mean := rowMeans(.SD, na.rm = TRUE), .SDcols = c("lower_shoulder_qhat_abs_mean", "upper_shoulder_qhat_abs_mean")]
  out[, reference_qhat_abs_mean := rowMeans(.SD, na.rm = TRUE), .SDcols = c("lower_tail_qhat_abs_mean", "center_qhat_abs_mean", "upper_tail_qhat_abs_mean")]

  out[, shoulder_pinball_ratio := shoulder_pinball_mean / pmax(reference_pinball_mean, 1e-12)]
  out[, shoulder_qhat_ratio := shoulder_qhat_abs_mean / pmax(reference_qhat_abs_mean, 1e-12)]

  data.table::setorderv(
    out,
    cols = c("collapse_n", "fragile_n", "shoulder_pinball_ratio", "shoulder_qhat_ratio", "overall_pinball_mean", "candidate_id", "dataset"),
    order = c(1L, 1L, 1L, 1L, 1L, 1L, 1L)
  )
  out[]
}

bench_qdesn_pathology_overall_summary <- function(candidate_summary) {
  dt <- data.table::as.data.table(candidate_summary)
  if (!nrow(dt)) {
    return(data.table::data.table())
  }

  out <- dt[, .(
    datasets_n = .N,
    collapse_n = sum(collapse_n, na.rm = TRUE),
    fragile_n = sum(fragile_n, na.rm = TRUE),
    shoulder_pinball_mean_macro = mean(shoulder_pinball_mean, na.rm = TRUE),
    reference_pinball_mean_macro = mean(reference_pinball_mean, na.rm = TRUE),
    shoulder_pinball_ratio_macro = mean(shoulder_pinball_ratio, na.rm = TRUE),
    shoulder_qhat_abs_mean_macro = mean(shoulder_qhat_abs_mean, na.rm = TRUE),
    reference_qhat_abs_mean_macro = mean(reference_qhat_abs_mean, na.rm = TRUE),
    shoulder_qhat_ratio_macro = mean(shoulder_qhat_ratio, na.rm = TRUE),
    overall_pinball_mean_macro = mean(overall_pinball_mean, na.rm = TRUE)
  ), by = candidate_id]

  data.table::setorderv(
    out,
    cols = c("collapse_n", "fragile_n", "shoulder_pinball_ratio_macro", "shoulder_qhat_ratio_macro", "overall_pinball_mean_macro", "candidate_id"),
    order = c(1L, 1L, 1L, 1L, 1L, 1L)
  )
  out[]
}

bench_qdesn_pathology_quantile_summary <- function(fit_dt, stage = "validation") {
  dt <- data.table::as.data.table(fit_dt)
  stage_name <- as.character(stage)[1L]
  dt <- dt[stage %chin% stage_name]
  if (!nrow(dt)) {
    return(data.table::data.table())
  }
  dt[, qhat_abs_mean := abs(qhat_mean)]
  dt[, quantile_band := bench_qdesn_pathology_band(quantile_p)]

  out <- dt[, .(
    n = .N,
    collapse_n = sum(collapse_flag, na.rm = TRUE),
    fragile_n = sum(stability_state == "fragile_noncollapsed", na.rm = TRUE),
    stable_n = sum(stability_state == "stable", na.rm = TRUE),
    pinball_mean = mean(pinball_mean, na.rm = TRUE),
    qhat_abs_mean = mean(qhat_abs_mean, na.rm = TRUE),
    qhat_sd_mean = mean(qhat_sd, na.rm = TRUE),
    abs_coverage_dev_mean = mean(abs_coverage_dev, na.rm = TRUE),
    abs_pit_dev_mean = mean(abs_pit_dev_mean, na.rm = TRUE)
  ), by = .(candidate_id, dataset, quantile_p, quantile_band)]

  data.table::setorderv(out, cols = c("candidate_id", "dataset", "quantile_p"), order = c(1L, 1L, 1L))
  out[]
}

bench_qdesn_pathology_figures <- function(candidate_summary, quantile_summary, figures_dir) {
  dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)
  out <- list()
  idx <- 1L

  if (nrow(candidate_summary)) {
    cand_plot <- ggplot2::ggplot(
      candidate_summary,
      ggplot2::aes(x = candidate_id, y = shoulder_pinball_ratio, fill = dataset)
    ) +
      ggplot2::geom_col(position = "dodge") +
      ggplot2::coord_flip() +
      ggplot2::labs(x = NULL, y = "Shoulder / reference pinball ratio", fill = "Dataset") +
      ggplot2::theme_minimal(base_size = 12)
    path <- file.path(figures_dir, "rhs_tau_sweep_shoulder_pinball_ratio.png")
    ggplot2::ggsave(path, cand_plot, width = 9, height = 4.8, dpi = 160)
    out[[idx]] <- data.table::data.table(
      file_path = path,
      description = "Shoulder-quantile pinball ratio by candidate and dataset."
    )
    idx <- idx + 1L

    qhat_plot <- ggplot2::ggplot(
      candidate_summary,
      ggplot2::aes(x = candidate_id, y = shoulder_qhat_ratio, fill = dataset)
    ) +
      ggplot2::geom_col(position = "dodge") +
      ggplot2::coord_flip() +
      ggplot2::labs(x = NULL, y = "Shoulder / reference |qhat| ratio", fill = "Dataset") +
      ggplot2::theme_minimal(base_size = 12)
    path <- file.path(figures_dir, "rhs_tau_sweep_shoulder_qhat_ratio.png")
    ggplot2::ggsave(path, qhat_plot, width = 9, height = 4.8, dpi = 160)
    out[[idx]] <- data.table::data.table(
      file_path = path,
      description = "Shoulder-quantile absolute forecast scale ratio by candidate and dataset."
    )
    idx <- idx + 1L
  }

  if (nrow(quantile_summary)) {
    pinball_plot <- ggplot2::ggplot(
      quantile_summary,
      ggplot2::aes(x = quantile_p, y = pinball_mean, color = candidate_id)
    ) +
      ggplot2::geom_line(linewidth = 0.8) +
      ggplot2::geom_point(size = 1.4) +
      ggplot2::facet_wrap(~dataset, scales = "free_y") +
      ggplot2::scale_y_log10() +
      ggplot2::labs(x = "Quantile", y = "Validation pinball (log10)", color = "Candidate") +
      ggplot2::theme_minimal(base_size = 12)
    path <- file.path(figures_dir, "rhs_tau_sweep_quantile_pinball.png")
    ggplot2::ggsave(path, pinball_plot, width = 10, height = 5.2, dpi = 160)
    out[[idx]] <- data.table::data.table(
      file_path = path,
      description = "Validation quantile pinball by candidate across the full quantile ladder."
    )
    idx <- idx + 1L

    qhat_abs_plot <- ggplot2::ggplot(
      quantile_summary,
      ggplot2::aes(x = quantile_p, y = qhat_abs_mean, color = candidate_id)
    ) +
      ggplot2::geom_line(linewidth = 0.8) +
      ggplot2::geom_point(size = 1.4) +
      ggplot2::facet_wrap(~dataset, scales = "free_y") +
      ggplot2::scale_y_log10() +
      ggplot2::labs(x = "Quantile", y = "Mean |qhat| (log10)", color = "Candidate") +
      ggplot2::theme_minimal(base_size = 12)
    path <- file.path(figures_dir, "rhs_tau_sweep_quantile_qhat_abs.png")
    ggplot2::ggsave(path, qhat_abs_plot, width = 10, height = 5.2, dpi = 160)
    out[[idx]] <- data.table::data.table(
      file_path = path,
      description = "Validation quantile forecast scale by candidate across the full quantile ladder."
    )
    idx <- idx + 1L
  }

  if (!length(out)) {
    return(data.table::data.table())
  }

  data.table::rbindlist(out, fill = TRUE)
}

bench_qdesn_pathology_write_report <- function(run_dir, repo_root = ".") {
  run_dir <- bench_abs_path(run_dir, repo_root = repo_root, must_work = TRUE)
  tables_dir <- file.path(run_dir, "tables")
  reports_dir <- file.path(run_dir, "reports")
  figures_dir <- file.path(run_dir, "figures")
  dir.create(reports_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)

  fit_dt <- bench_qdesn_pathology_load_fit_audit(run_dir = run_dir, repo_root = repo_root)
  candidate_summary <- bench_qdesn_pathology_candidate_summary(fit_dt, stage = "validation")
  overall_summary <- bench_qdesn_pathology_overall_summary(candidate_summary)
  quantile_summary <- bench_qdesn_pathology_quantile_summary(fit_dt, stage = "validation")
  figure_manifest <- bench_qdesn_pathology_figures(candidate_summary, quantile_summary, figures_dir = figures_dir)

  bench_save_table(candidate_summary, file.path(tables_dir, "rhs_pathology_candidate_summary"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")
  bench_save_table(overall_summary, file.path(tables_dir, "rhs_pathology_overall_summary"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")
  bench_save_table(quantile_summary, file.path(tables_dir, "rhs_pathology_quantile_summary"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")
  bench_save_table(figure_manifest, file.path(tables_dir, "rhs_pathology_figure_manifest"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")

  top <- overall_summary[1L]
  lines <- c(
    "# RHS Tau Sweep Pathology Audit",
    "",
    sprintf("- Generated: %s", bench_timestamp_utc()),
    sprintf("- Run directory: `%s`", run_dir),
    sprintf("- Validation candidates summarized: %d", nrow(candidate_summary)),
    ""
  )

  if (nrow(overall_summary)) {
    lines <- c(
      lines,
      "## Overall Ranking",
      "",
      sprintf(
        "- Best pathology profile on validation: `%s` (collapse=%d, fragile=%d, shoulder/reference pinball ratio=%.3f, shoulder/reference |qhat| ratio=%.3f).",
        top$candidate_id[[1L]],
        as.integer(top$collapse_n[[1L]]),
        as.integer(top$fragile_n[[1L]]),
        as.numeric(top$shoulder_pinball_ratio_macro[[1L]]),
        as.numeric(top$shoulder_qhat_ratio_macro[[1L]])
      ),
      ""
    )
  }

  if (nrow(candidate_summary)) {
    lines <- c(lines, "## Dataset Candidate Summary", "")
    for (dataset_name in unique(candidate_summary$dataset)) {
      rows <- candidate_summary[dataset == dataset_name]
      lines <- c(lines, sprintf("### %s", dataset_name), "")
      for (i in seq_len(nrow(rows))) {
        row <- rows[i]
        lines <- c(
          lines,
          sprintf(
            "- `%s`: collapse=%d, fragile=%d, shoulder pinball=%.3f, reference pinball=%.3f, shoulder/reference pinball ratio=%.3f, shoulder/reference |qhat| ratio=%.3f, tau_last_min=%.3e, beta_l2_min=%.3e",
            row$candidate_id[[1L]],
            as.integer(row$collapse_n[[1L]]),
            as.integer(row$fragile_n[[1L]]),
            as.numeric(row$shoulder_pinball_mean[[1L]]),
            as.numeric(row$reference_pinball_mean[[1L]]),
            as.numeric(row$shoulder_pinball_ratio[[1L]]),
            as.numeric(row$shoulder_qhat_ratio[[1L]]),
            as.numeric(row$tau_last_min[[1L]]),
            as.numeric(row$beta_l2_min[[1L]])
          )
        )
      }
      lines <- c(lines, "")
    }
  }

  shoulder_rows <- quantile_summary[quantile_band %chin% c("lower_shoulder", "upper_shoulder")]
  if (nrow(shoulder_rows)) {
    lines <- c(lines, "## Shoulder Quantile Pattern", "")
    worst_rows <- shoulder_rows[order(-pinball_mean)][1:min(10L, .N)]
    for (i in seq_len(nrow(worst_rows))) {
      row <- worst_rows[i]
      lines <- c(
        lines,
        sprintf(
          "- `%s` / `%s` / q=%.2f: pinball=%.3f, |qhat|=%.3f, abs_coverage_dev=%.3f, abs_pit_dev=%.3f",
          row$candidate_id[[1L]],
          row$dataset[[1L]],
          as.numeric(row$quantile_p[[1L]]),
          as.numeric(row$pinball_mean[[1L]]),
          as.numeric(row$qhat_abs_mean[[1L]]),
          as.numeric(row$abs_coverage_dev_mean[[1L]]),
          as.numeric(row$abs_pit_dev_mean[[1L]])
        )
      )
    }
    lines <- c(lines, "")
  }

  if (nrow(figure_manifest)) {
    lines <- c(lines, "## Figures", "")
    lines <- c(lines, sprintf("- `%s`: %s", figure_manifest$file_path, figure_manifest$description))
    lines <- c(lines, "")
  }

  report_path <- file.path(reports_dir, "rhs_tau_sweep_pathology.md")
  writeLines(lines, report_path)

  list(
    fit_table = fit_dt,
    candidate_summary = candidate_summary,
    overall_summary = overall_summary,
    quantile_summary = quantile_summary,
    figure_manifest = figure_manifest,
    report_path = report_path
  )
}

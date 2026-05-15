# Exploratory analysis, visualization, and reporting helpers for benchmarks.

bench_load_processed_benchmarks <- function(config_path = NULL) {
  bench_assert_packages(bench_required_packages("analysis"))
  bench_attach_packages(c("data.table", "ggplot2", "scales"))

  context <- bench_read_pipeline_config(config_path = config_path)
  paths <- context$paths

  list(
    context = context,
    metadata = readRDS(file.path(paths$metadata_dir, "series_metadata.rds")),
    summary = readRDS(file.path(paths$metadata_dir, "dataset_summary.rds")),
    panel_manifest = readRDS(file.path(paths$metadata_dir, "panel_manifest.rds")),
    splits = readRDS(file.path(paths$splits_dir, "split_definitions.rds")),
    quality_issues = readRDS(file.path(paths$quality_dir, "quality_issues.rds")),
    exclusion_log = readRDS(file.path(paths$quality_dir, "exclusion_log.rds"))
  )
}

bench_plot_theme <- function() {
  ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold"),
      panel.grid.minor = ggplot2::element_blank(),
      axis.title.x = ggplot2::element_text(margin = ggplot2::margin(t = 8)),
      axis.title.y = ggplot2::element_text(margin = ggplot2::margin(r = 8)),
      strip.text = ggplot2::element_text(face = "bold")
    )
}

bench_save_plot <- function(plot_obj, path, width = 11, height = 7, dpi = 180) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  ggplot2::ggsave(path, plot = plot_obj, width = width, height = height, dpi = dpi)
  invisible(path)
}

bench_parse_plot_x <- function(timestamp, frequency_label) {
  freq <- bench_normalize_frequency_label(frequency_label)
  if (all(is.na(timestamp))) {
    return(NULL)
  }

  if (freq %in% c("hourly", "half_hourly", "10_minutes")) {
    return(as.POSIXct(timestamp, tz = "UTC"))
  }

  as.Date(timestamp)
}

bench_load_panel_dataset <- function(dataset_name, loaded) {
  idx <- match(dataset_name, loaded$panel_manifest$dataset)
  if (is.na(idx)) {
    stop(sprintf("Panel partition not found for dataset %s.", dataset_name), call. = FALSE)
  }

  panel_path <- bench_abs_path(loaded$panel_manifest$panel_path[[idx]], repo_root = loaded$context$paths$repo_root, must_work = TRUE)
  readRDS(panel_path)
}

bench_safe_cor <- function(x, y) {
  if (length(x) <= 2L || sum(is.finite(x) & is.finite(y)) <= 2L) {
    return(NA_real_)
  }
  suppressWarnings(stats::cor(x, y, use = "pairwise.complete.obs"))
}

bench_safe_seasonal_acf <- function(y, seasonal_period) {
  if (is.na(seasonal_period) || seasonal_period <= 1L) {
    return(NA_real_)
  }

  y <- y[is.finite(y)]
  if (length(y) < (2L * seasonal_period + 1L)) {
    return(NA_real_)
  }

  acf_obj <- stats::acf(y, lag.max = seasonal_period, plot = FALSE, na.action = stats::na.pass)
  as.numeric(acf_obj$acf[seasonal_period + 1L])
}

bench_series_selection_metrics <- function(panel_dt, metadata_row) {
  seasonal_period <- as.integer(metadata_row$seasonal_period[[1L]])

  metrics <- panel_dt[, {
    finite_y <- y[is.finite(y)]
    finite_idx <- t_index[is.finite(y)]
    variance <- if (length(finite_y) > 1L) stats::var(finite_y) else NA_real_
    volatility <- if (length(finite_y) > 2L) stats::sd(diff(finite_y)) else NA_real_

    .(
      n_obs = .N,
      missing_rate = mean(is.na(y)),
      variance = variance,
      trend_strength = abs(bench_safe_cor(finite_idx, finite_y)),
      seasonal_strength = abs(bench_safe_seasonal_acf(finite_y, seasonal_period)),
      volatility = volatility
    )
  }, by = .(series_id)]

  safe_scale <- function(x) {
    x <- as.numeric(x)
    if (all(is.na(x))) return(rep(0, length(x)))
    s <- stats::sd(x, na.rm = TRUE)
    if (!is.finite(s) || s == 0) return(rep(0, length(x)))
    (x - stats::median(x, na.rm = TRUE)) / s
  }

  metrics[, representative_score :=
            abs(safe_scale(log1p(n_obs))) +
            abs(safe_scale(log1p(pmax(variance, 0)))) +
            abs(safe_scale(missing_rate))]

  metrics[]
}

bench_select_series_roles <- function(metrics_dt, max_roles = 7L) {
  if (!nrow(metrics_dt)) {
    return(data.table::data.table())
  }

  selected_ids <- character()
  pick_role <- function(order_dt, role, metric_name) {
    candidates <- order_dt[!series_id %in% selected_ids]
    if (!nrow(candidates)) return(NULL)
    best <- candidates[1L]
    selected_ids <<- c(selected_ids, best$series_id)
    data.table::data.table(
      series_id = best$series_id,
      selection_role = role,
      metric_name = metric_name,
      metric_value = best[[metric_name]]
    )
  }

  candidates <- list(
    pick_role(metrics_dt[order(representative_score, series_id)], "representative", "representative_score"),
    pick_role(metrics_dt[!is.na(seasonal_strength)][order(-seasonal_strength, series_id)], "seasonal", "seasonal_strength"),
    pick_role(metrics_dt[!is.na(trend_strength)][order(-trend_strength, series_id)], "trend", "trend_strength"),
    pick_role(metrics_dt[!is.na(volatility)][order(-volatility, series_id)], "volatile", "volatility"),
    pick_role(metrics_dt[order(n_obs, series_id)], "short", "n_obs"),
    pick_role(metrics_dt[order(-n_obs, series_id)], "long", "n_obs"),
    if (any(metrics_dt$missing_rate > 0, na.rm = TRUE)) {
      pick_role(metrics_dt[missing_rate > 0][order(-missing_rate, series_id)], "missing", "missing_rate")
    } else {
      NULL
    }
  )

  selected <- data.table::rbindlist(candidates, fill = TRUE)
  if (nrow(selected) > max_roles) {
    role_priority <- c("representative", "seasonal", "trend", "volatile", "missing", "short", "long")
    selected[, role_rank := match(selection_role, role_priority)]
    selected <- selected[order(role_rank, series_id)][seq_len(max_roles)]
    selected[, role_rank := NULL]
  }

  selected[]
}

bench_dataset_selection_manifest <- function(dataset, loaded) {
  panel_dt <- data.table::as.data.table(bench_load_panel_dataset(dataset, loaded))
  meta_idx <- match(dataset, loaded$metadata$dataset)
  metadata_row <- data.table::as.data.table(loaded$metadata[meta_idx, , drop = FALSE])
  metrics_dt <- bench_series_selection_metrics(panel_dt, metadata_row)
  selected <- bench_select_series_roles(metrics_dt, max_roles = loaded$context$config$analysis$top_n_roles_per_dataset %||% 7L)
  selected[, dataset := dataset]
  selected[]
}

bench_summary_figures <- function(loaded) {
  summary_dt <- data.table::as.data.table(loaded$summary)
  metadata_dt <- data.table::as.data.table(loaded$metadata)
  splits_dt <- data.table::as.data.table(loaded$splits)
  fig_dir <- loaded$context$paths$figures_dir

  split_summary <- splits_dt[, .(
    median_train_length = as.numeric(stats::median(train_end - train_start + 1L, na.rm = TRUE)),
    median_val_length = as.numeric(stats::median(ifelse(is.na(val_start), 0L, val_end - val_start + 1L), na.rm = TRUE)),
    median_test_length = as.numeric(stats::median(test_end - test_start + 1L, na.rm = TRUE))
  ), by = .(dataset, source_family)]

  plots <- list(
    list(
      key = "counts_by_dataset",
      description = "Series counts by processed dataset.",
      plot = ggplot2::ggplot(summary_dt, ggplot2::aes(x = reorder(dataset_label, n_series), y = n_series, fill = source_family)) +
        ggplot2::geom_col(width = 0.75) +
        ggplot2::coord_flip() +
        ggplot2::scale_y_continuous(labels = scales::label_comma()) +
        ggplot2::labs(title = "Series Counts by Dataset", x = NULL, y = "Series") +
        bench_plot_theme(),
      width = 10,
      height = 7
    ),
    list(
      key = "counts_by_frequency",
      description = "Series counts aggregated by frequency label.",
      plot = ggplot2::ggplot(summary_dt[, .(n_series = sum(n_series)), by = .(frequency_label)], ggplot2::aes(x = reorder(frequency_label, n_series), y = n_series)) +
        ggplot2::geom_col(fill = "#2A6F97", width = 0.7) +
        ggplot2::coord_flip() +
        ggplot2::scale_y_continuous(labels = scales::label_comma()) +
        ggplot2::labs(title = "Series Counts by Frequency", x = NULL, y = "Series") +
        bench_plot_theme(),
      width = 8,
      height = 6
    ),
    list(
      key = "length_distribution",
      description = "Series length distribution by dataset.",
      plot = ggplot2::ggplot(metadata_dt, ggplot2::aes(x = reorder(dataset_label, n_obs, FUN = median), y = n_obs, fill = source_family)) +
        ggplot2::geom_boxplot(outlier.alpha = 0.15) +
        ggplot2::coord_flip() +
        ggplot2::scale_y_continuous(trans = "log10", labels = scales::label_number()) +
        ggplot2::labs(title = "Series Length Distribution", x = NULL, y = "Observations (log scale)") +
        bench_plot_theme(),
      width = 10,
      height = 7
    ),
    list(
      key = "horizon_distribution",
      description = "Forecast horizon by dataset.",
      plot = ggplot2::ggplot(summary_dt, ggplot2::aes(x = reorder(dataset_label, mean_horizon), y = mean_horizon, fill = source_family)) +
        ggplot2::geom_col(width = 0.75) +
        ggplot2::coord_flip() +
        ggplot2::labs(title = "Forecast Horizon by Dataset", x = NULL, y = "Forecast horizon") +
        bench_plot_theme(),
      width = 10,
      height = 7
    ),
    list(
      key = "missingness_by_dataset",
      description = "Mean missingness rate by dataset.",
      plot = ggplot2::ggplot(summary_dt, ggplot2::aes(x = reorder(dataset_label, missing_rate), y = missing_rate, fill = source_family)) +
        ggplot2::geom_col(width = 0.75) +
        ggplot2::coord_flip() +
        ggplot2::scale_y_continuous(labels = scales::label_percent(accuracy = 0.1)) +
        ggplot2::labs(title = "Missingness by Dataset", x = NULL, y = "Mean missing rate") +
        bench_plot_theme(),
      width = 10,
      height = 7
    ),
    list(
      key = "split_lengths_by_dataset",
      description = "Median train/validation/test lengths by dataset.",
      plot = {
        split_long <- data.table::melt(
          split_summary,
          id.vars = c("dataset", "source_family"),
          variable.name = "segment",
          value.name = "length"
        )
        ggplot2::ggplot(split_long, ggplot2::aes(x = reorder(dataset, length), y = length, fill = segment)) +
          ggplot2::geom_col(position = "stack", width = 0.75) +
          ggplot2::coord_flip() +
          ggplot2::labs(title = "Median Split Lengths by Dataset", x = NULL, y = "Median segment length") +
          bench_plot_theme()
      },
      width = 10,
      height = 7
    )
  )

  manifest_rows <- vector("list", length(plots))
  for (idx in seq_along(plots)) {
    spec <- plots[[idx]]
    out_path <- file.path(fig_dir, sprintf("summary_%s.png", spec$key))
    bench_save_plot(spec$plot, out_path, width = spec$width, height = spec$height)
    manifest_rows[[idx]] <- data.table::data.table(
      figure_type = "summary",
      dataset = NA_character_,
      figure_key = spec$key,
      description = spec$description,
      figure_path = bench_rel_path(out_path, repo_root = loaded$context$paths$repo_root)
    )
  }

  data.table::rbindlist(manifest_rows, fill = TRUE)
}

bench_dataset_panel_figure <- function(dataset, loaded, selection_manifest) {
  panel_dt <- data.table::as.data.table(bench_load_panel_dataset(dataset, loaded))
  if (!nrow(selection_manifest)) {
    return(NULL)
  }

  plot_dt <- selection_manifest[panel_dt, on = "series_id", nomatch = 0L]
  if (!nrow(plot_dt)) {
    return(NULL)
  }

  meta_idx <- match(dataset, loaded$metadata$dataset)
  meta_row <- loaded$metadata[meta_idx, , drop = FALSE]
  x_parsed <- bench_parse_plot_x(plot_dt$timestamp, meta_row$frequency_label[[1L]])
  if (is.null(x_parsed)) {
    plot_dt[, x_value := t_index]
    x_mapping <- ggplot2::aes(x = x_value, y = y)
    x_label <- "Index"
    scale_layer <- NULL
  } else {
    plot_dt[, x_value := x_parsed]
    x_mapping <- ggplot2::aes(x = x_value, y = y)
    x_label <- "Timestamp"
    scale_layer <- if (inherits(x_parsed, "POSIXct")) ggplot2::scale_x_datetime(date_labels = "%Y-%m") else ggplot2::scale_x_date(date_labels = "%Y-%m")
  }

  p <- ggplot2::ggplot(plot_dt, x_mapping) +
    ggplot2::geom_line(color = "#004E64", linewidth = 0.45) +
    ggplot2::facet_wrap(~ selection_role + series_id, scales = "free_y", ncol = loaded$context$config$analysis$facet_ncol %||% 2L) +
    ggplot2::labs(
      title = sprintf("%s: Selected Representative and Extreme Series", meta_row$dataset_label[[1L]]),
      subtitle = "Selection roles are deterministic and metric-driven.",
      x = x_label,
      y = "y"
    ) +
    bench_plot_theme()

  if (!is.null(scale_layer)) {
    p <- p + scale_layer
  }

  out_path <- file.path(loaded$context$paths$figures_dir, sprintf("series_panel_%s.png", dataset))
  bench_save_plot(p, out_path, width = 12, height = 9)

  data.table::data.table(
    figure_type = "series_panel",
    dataset = dataset,
    figure_key = sprintf("series_panel_%s", dataset),
    description = sprintf("Selected representative and diagnostic series for %s.", meta_row$dataset_label[[1L]]),
    figure_path = bench_rel_path(out_path, repo_root = loaded$context$paths$repo_root)
  )
}

bench_write_analysis_report <- function(loaded, selections_dt, figure_manifest) {
  context <- loaded$context
  paths <- context$paths
  summary_dt <- data.table::as.data.table(loaded$summary)
  exclusion_dt <- data.table::as.data.table(loaded$exclusion_log)

  split_policy_lines <- c(
    sprintf("- Monash default split protocol: `%s`", context$config$split$monash_protocol %||% "train_val_test_tail"),
    sprintf("- M4 default split protocol: `%s`", context$config$split$m4_protocol %||% "official_only"),
    "- Official M4 test sets are preserved exactly. Validation, when requested, is carved only from the official training segment.",
    "- Monash M4 duplicates are explicitly excluded from the Monash main pool by registry rules."
  )

  key_findings <- c(
    sprintf("- Final processed datasets: %d", nrow(summary_dt)),
    sprintf("- Final processed series: %s", scales::comma(sum(summary_dt$n_series))),
    sprintf("- Generated figures: %d", nrow(figure_manifest)),
    sprintf("- Logged exclusions: %d", nrow(exclusion_dt))
  )

  exclusion_lines <- if (nrow(exclusion_dt)) {
    exclusion_dt[, .N, by = .(dataset, issue_type)][order(dataset, issue_type)][
      , sprintf("- `%s`: %d series excluded for `%s`", dataset, N, issue_type)
    ]
  } else {
    "- No series were excluded by the final processing rules."
  }

  report_lines <- c(
    "# Benchmark Data Summary",
    "",
    "## What Was Downloaded",
    "",
    "- Monash curated validation batch: Tourism Monthly, CIF 2016 Monthly, and Pedestrian Counts Hourly.",
    "- Official M4 source family: Yearly, Quarterly, Monthly, Weekly, Daily, and Hourly train/test splits plus `M4-info.csv`.",
    "",
    "## Split Policy",
    "",
    split_policy_lines,
    "",
    "## Final Counts",
    "",
    key_findings,
    "",
    "## Exclusions",
    "",
    exclusion_lines,
    "",
    "## Processed Output Locations",
    "",
    sprintf("- Metadata tables: `%s`", bench_rel_path(paths$metadata_dir, repo_root = paths$repo_root)),
    sprintf("- Panel partitions: `%s`", bench_rel_path(paths$panel_dir, repo_root = paths$repo_root)),
    sprintf("- Split definitions: `%s`", bench_rel_path(paths$splits_dir, repo_root = paths$repo_root)),
    sprintf("- Quality logs: `%s`", bench_rel_path(paths$quality_dir, repo_root = paths$repo_root)),
    sprintf("- Figures: `%s`", bench_rel_path(paths$figures_dir, repo_root = paths$repo_root)),
    "",
    "## Figure Index",
    ""
  )

  if (nrow(figure_manifest)) {
    report_lines <- c(
      report_lines,
      apply(figure_manifest, 1L, function(row) sprintf("- `%s`: %s", row[["figure_path"]], row[["description"]]))
    )
  } else {
    report_lines <- c(report_lines, "- No figures were generated.")
  }

  report_path <- file.path(paths$reports_dir, "benchmark_summary.md")
  dir.create(dirname(report_path), recursive = TRUE, showWarnings = FALSE)
  writeLines(report_lines, report_path)
  report_path
}

bench_analyze_benchmarks <- function(config_path = NULL) {
  loaded <- bench_load_processed_benchmarks(config_path = config_path)
  datasets <- loaded$summary$dataset

  selection_rows <- vector("list", length(datasets))
  panel_figure_rows <- vector("list", length(datasets))

  for (idx in seq_along(datasets)) {
    dataset <- datasets[[idx]]
    message("[bench-analyze] dataset:", dataset)
    selection_rows[[idx]] <- bench_dataset_selection_manifest(dataset, loaded)
    panel_figure_rows[[idx]] <- bench_dataset_panel_figure(dataset, loaded, selection_rows[[idx]])
  }

  selections_dt <- data.table::rbindlist(selection_rows, fill = TRUE)
  figure_manifest <- data.table::rbindlist(
    c(list(bench_summary_figures(loaded)), panel_figure_rows),
    fill = TRUE
  )

  bench_save_table(selections_dt, file.path(loaded$context$paths$metadata_dir, "selected_series_manifest"), write_csv = TRUE, write_rds = TRUE, compress = loaded$context$config$processing$compress %||% "gzip")
  bench_save_table(figure_manifest, file.path(loaded$context$paths$reports_dir, "figure_index"), write_csv = TRUE, write_rds = TRUE, compress = loaded$context$config$processing$compress %||% "gzip")
  report_path <- bench_write_analysis_report(loaded, selections_dt, figure_manifest)

  bench_write_json(
    list(
      generated_at_utc = bench_timestamp_utc(),
      figure_count = nrow(figure_manifest),
      selected_series = nrow(selections_dt),
      report_path = bench_rel_path(report_path, repo_root = loaded$context$paths$repo_root)
    ),
    file.path(loaded$context$paths$reports_dir, "analysis_summary.json")
  )

  invisible(list(
    loaded = loaded,
    selections = selections_dt,
    figure_manifest = figure_manifest,
    report_path = report_path
  ))
}

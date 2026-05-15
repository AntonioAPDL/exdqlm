# Canonical processing, split construction, and quality checks for benchmarks.

bench_label_split <- function(t_index, train_end, val_start, val_end, test_start, test_end) {
  if (!is.na(test_start) && t_index >= test_start && t_index <= test_end) {
    return("test")
  }

  if (!is.na(val_start) && t_index >= val_start && t_index <= val_end) {
    return("validation")
  }

  if (!is.na(train_end) && t_index >= 1L && t_index <= train_end) {
    return("train")
  }

  NA_character_
}

bench_append_length_metrics <- function(metadata_dt, panel_dt) {
  counts <- panel_dt[, .(
    n_obs = .N,
    n_missing = sum(is.na(y)),
    n_finite = sum(is.finite(y)),
    y_mean = if (sum(is.finite(y)) > 0L) mean(y, na.rm = TRUE) else NA_real_,
    y_var = if (sum(is.finite(y)) > 1L) var(y, na.rm = TRUE) else NA_real_,
    y_sd = if (sum(is.finite(y)) > 1L) stats::sd(y, na.rm = TRUE) else NA_real_
  ), by = .(dataset, source_family, series_id)]

  counts[metadata_dt, on = .(dataset, source_family, series_id)]
}

bench_build_monash_dataset <- function(dataset_spec, context) {
  bench_assert_packages("data.table")

  cfg <- context$config
  paths <- context$paths
  tsf_path <- file.path(paths$raw_monash, dataset_spec$dataset, dataset_spec$archive_member)
  if (!file.exists(tsf_path)) {
    stop(sprintf("Monash raw file not found: %s", tsf_path), call. = FALSE)
  }

  parsed <- bench_parse_tsf_file(tsf_path)
  meta_raw <- data.table::copy(parsed$series_attributes)
  panel_raw <- data.table::copy(parsed$panel)
  data.table::setDT(meta_raw)
  data.table::setDT(panel_raw)

  frequency_label <- bench_normalize_frequency_label(parsed$header$frequency %||% dataset_spec$frequency_label)
  equal_length <- isTRUE(parsed$header$equallength)
  source_file <- bench_rel_path(tsf_path, repo_root = paths$repo_root)

  if (!("series_name" %in% names(meta_raw))) {
    stop(sprintf("TSF file %s is missing a series_name attribute.", tsf_path), call. = FALSE)
  }

  default_horizon <- as.integer(dataset_spec$forecast_horizon %||% NA_integer_)
  meta_raw[, series_id := as.character(series_name)]
  if ("horizon" %in% names(meta_raw)) {
    meta_raw[, forecast_horizon := as.integer(horizon)]
  } else {
    meta_raw[, forecast_horizon := default_horizon]
  }
  if (is.finite(parsed$header$horizon)) {
    meta_raw[is.na(forecast_horizon), forecast_horizon := as.integer(parsed$header$horizon)]
  }
  meta_raw[is.na(forecast_horizon), forecast_horizon := default_horizon]

  start_col <- if ("start_timestamp" %in% names(meta_raw)) {
    "start_timestamp"
  } else if ("start_date" %in% names(meta_raw)) {
    "start_date"
  } else {
    NULL
  }
  if (!is.null(start_col)) {
    meta_raw[, start_timestamp_raw := as.character(get(start_col))]
  } else {
    meta_raw[, start_timestamp_raw := rep(NA_character_, .N)]
  }

  meta_dt <- meta_raw[, .(
    dataset = dataset_spec$dataset,
    dataset_label = dataset_spec$dataset_label %||% dataset_spec$dataset,
    source_family = "monash",
    benchmark_pool = dataset_spec$benchmark_pool %||% "monash_main",
    series_id = series_id,
    category = NA_character_,
    domain = dataset_spec$domain %||% NA_character_,
    frequency_label = frequency_label,
    seasonal_period = as.integer(dataset_spec$seasonal_period %||% NA_integer_),
    forecast_horizon = as.integer(forecast_horizon),
    start_timestamp = vapply(start_timestamp_raw, function(x) {
      parsed_ts <- bench_parse_timestamp_value(x)
      if (is.na(parsed_ts)) NA_character_ else bench_format_timestamp_vector(parsed_ts)
    }, character(1)),
    has_missing = NA,
    equal_length = equal_length,
    source_file = source_file,
    notes = dataset_spec$notes %||% NA_character_,
    n_train = NA_integer_,
    n_test = NA_integer_
  )]

  data.table::setkey(meta_dt, series_id)
  data.table::setkey(meta_raw, series_id)
  panel_dt <- meta_raw[panel_raw, on = "tsf_row_id"]
  panel_dt[, dataset := dataset_spec$dataset]
  panel_dt[, source_family := "monash"]
  panel_dt[, timestamp := {
    seq_values <- bench_make_timestamp_sequence(start_timestamp_raw[[1L]], .N, frequency_label)
    if (length(seq_values) == .N) seq_values else rep(NA_character_, .N)
  }, by = .(tsf_row_id)]

  panel_dt <- panel_dt[, .(
    dataset,
    source_family,
    series_id,
    t_index = as.integer(t_index),
    timestamp,
    y = as.numeric(y)
  )]

  meta_dt <- bench_append_length_metrics(meta_dt, panel_dt)
  meta_dt[, has_missing := n_missing > 0L]

  split_dt <- bench_build_monash_splits(meta_dt, cfg)
  quality <- bench_collect_quality_issues(meta_dt, split_dt)

  keep_ids <- setdiff(meta_dt$series_id, quality$excluded_series$series_id)
  meta_keep <- meta_dt[series_id %in% keep_ids]
  split_keep <- split_dt[series_id %in% keep_ids]
  panel_keep <- panel_dt[series_id %in% keep_ids]
  panel_keep <- bench_assign_split_labels(panel_keep, split_keep)

  list(
    metadata = meta_keep,
    panel = panel_keep,
    splits = split_keep,
    quality_issues = quality$issues,
    exclusion_log = quality$excluded_series
  )
}

bench_melt_m4_block <- function(dt, value_name) {
  measure_cols <- setdiff(names(dt), "series_id")
  long_dt <- data.table::melt(
    dt,
    id.vars = "series_id",
    measure.vars = measure_cols,
    variable.name = "wide_col",
    value.name = value_name,
    variable.factor = FALSE,
    na.rm = FALSE
  )
  long_dt[, t_index := as.integer(sub("^V", "", wide_col))]
  long_dt[, wide_col := NULL]
  long_dt
}

bench_build_m4_frequency <- function(freq_name, freq_spec, info_dt, context) {
  bench_assert_packages("data.table")

  cfg <- context$config
  paths <- context$paths

  train_path <- file.path(paths$raw_m4, freq_name, basename(freq_spec$train_url))
  test_path <- file.path(paths$raw_m4, freq_name, basename(freq_spec$test_url))
  if (!file.exists(train_path) || !file.exists(test_path)) {
    stop(sprintf("Missing raw M4 files for %s. Run the benchmark download step first.", freq_name), call. = FALSE)
  }

  train_dt <- data.table::fread(train_path, na.strings = c("", "NA"), fill = TRUE, showProgress = FALSE)
  test_dt <- data.table::fread(test_path, na.strings = c("", "NA"), fill = TRUE, showProgress = FALSE)
  data.table::setDT(train_dt)
  data.table::setDT(test_dt)
  data.table::setnames(train_dt, 1L, "series_id")
  data.table::setnames(test_dt, 1L, "series_id")

  if (!identical(train_dt$series_id, test_dt$series_id)) {
    stop(sprintf("M4 train/test ID mismatch detected for %s.", freq_name), call. = FALSE)
  }

  info_sub <- data.table::copy(info_dt[series_id %in% train_dt$series_id])
  data.table::setDT(info_sub)
  data.table::setkey(info_sub, series_id)
  if (nrow(info_sub) != nrow(train_dt)) {
    stop(sprintf("M4 info metadata mismatch for %s.", freq_name), call. = FALSE)
  }

  train_value_cols <- setdiff(names(train_dt), "series_id")
  test_value_cols <- setdiff(names(test_dt), "series_id")
  n_series <- nrow(train_dt)
  panel_rows <- vector("list", n_series)
  metadata_rows <- vector("list", n_series)
  source_file <- bench_rel_path(train_path, repo_root = paths$repo_root)

  for (idx in seq_len(n_series)) {
    if (idx %% 10000L == 0L) {
      message("[bench-build] m4:", freq_name, " row ", idx, "/", n_series)
    }

    train_id <- train_dt$series_id[[idx]]
    test_id <- test_dt$series_id[[idx]]
    if (!identical(train_id, test_id)) {
      stop(sprintf("M4 train/test ID mismatch detected for %s at row %d.", freq_name, idx), call. = FALSE)
    }

    info_row <- info_sub[train_id]
    if (nrow(info_row) != 1L) {
      stop(sprintf("Missing or duplicated M4 metadata for series %s.", train_id), call. = FALSE)
    }

    train_vals <- unlist(train_dt[idx, ..train_value_cols], use.names = FALSE)
    test_vals <- unlist(test_dt[idx, ..test_value_cols], use.names = FALSE)
    train_vals <- as.numeric(train_vals[!is.na(train_vals)])
    test_vals <- as.numeric(test_vals[!is.na(test_vals)])
    total_n <- length(train_vals) + length(test_vals)
    timestamp_vec <- bench_make_timestamp_sequence(info_row$starting_date[[1L]], total_n, freq_spec$frequency_label)
    if (length(timestamp_vec) != total_n) {
      timestamp_vec <- rep(NA_character_, total_n)
    }

    panel_rows[[idx]] <- data.table::data.table(
      dataset = freq_spec$dataset,
      source_family = "m4",
      series_id = train_id,
      t_index = seq_len(total_n),
      timestamp = timestamp_vec,
      y = c(train_vals, test_vals)
    )

    metadata_rows[[idx]] <- list(
      dataset = freq_spec$dataset,
      dataset_label = freq_spec$dataset_label,
      source_family = "m4",
      benchmark_pool = freq_spec$benchmark_pool %||% "m4_official",
      series_id = train_id,
      category = info_row$category[[1L]],
      domain = info_row$category[[1L]],
      frequency_label = bench_normalize_frequency_label(freq_spec$frequency_label),
      seasonal_period = as.integer(freq_spec$seasonal_period %||% NA_integer_),
      forecast_horizon = as.integer(info_row$forecast_horizon[[1L]]),
      start_timestamp = {
        parsed_ts <- bench_parse_timestamp_value(info_row$starting_date[[1L]])
        if (is.na(parsed_ts)) NA_character_ else bench_format_timestamp_vector(parsed_ts)
      },
      has_missing = FALSE,
      equal_length = FALSE,
      source_file = source_file,
      notes = "Official M4 train/test split preserved from the competition repository.",
      n_train = length(train_vals),
      n_test = length(test_vals)
    )
  }

  meta_dt <- data.table::rbindlist(metadata_rows, fill = TRUE)
  panel_dt <- data.table::rbindlist(panel_rows, use.names = TRUE, fill = TRUE)

  meta_dt <- bench_append_length_metrics(meta_dt, panel_dt)
  split_dt <- bench_build_m4_splits(meta_dt, cfg)
  quality <- bench_collect_quality_issues(meta_dt, split_dt)

  keep_ids <- setdiff(meta_dt$series_id, quality$excluded_series$series_id)
  meta_keep <- meta_dt[series_id %in% keep_ids]
  split_keep <- split_dt[series_id %in% keep_ids]
  panel_keep <- panel_dt[series_id %in% keep_ids]
  panel_keep <- bench_assign_split_labels(panel_keep, split_keep)

  list(
    metadata = meta_keep,
    panel = panel_keep,
    splits = split_keep,
    quality_issues = quality$issues,
    exclusion_log = quality$excluded_series
  )
}

bench_build_monash_splits <- function(metadata_dt, cfg) {
  protocol <- cfg$split$monash_protocol %||% "train_val_test_tail"
  min_train_points <- as.integer(cfg$split$validation$min_train_points %||% 24L)

  splits <- metadata_dt[, {
    h <- as.integer(forecast_horizon)
    n <- as.integer(n_obs)
    test_start <- if (is.finite(h) && is.finite(n)) n - h + 1L else NA_integer_
    test_end <- if (is.finite(n)) n else NA_integer_
    official_train_end <- if (is.finite(test_start)) test_start - 1L else NA_integer_

    val_start <- NA_integer_
    val_end <- NA_integer_
    train_end <- official_train_end
    split_notes <- NA_character_

    if (identical(protocol, "train_val_test_tail") && is.finite(official_train_end) && is.finite(h)) {
      candidate_train_end <- official_train_end - h
      if (candidate_train_end >= min_train_points) {
        val_start <- candidate_train_end + 1L
        val_end <- official_train_end
        train_end <- candidate_train_end
      } else {
        split_notes <- "validation_block_skipped_short_series"
      }
    }

    .(
      train_start = 1L,
      train_end = train_end,
      val_start = val_start,
      val_end = val_end,
      test_start = test_start,
      test_end = test_end,
      official_train_end = official_train_end,
      official_test_start = test_start,
      official_test_end = test_end,
      forecast_horizon = h,
      split_protocol = protocol,
      split_notes = split_notes
    )
  }, by = .(dataset, source_family, series_id)]

  splits[]
}

bench_build_m4_splits <- function(metadata_dt, cfg) {
  protocol <- cfg$split$m4_protocol %||% "official_only"
  min_train_points <- as.integer(cfg$split$validation$min_train_points %||% 24L)

  splits <- metadata_dt[, {
    n_train_obs <- as.integer(n_train)
    n_test_obs <- as.integer(n_test)
    h <- as.integer(forecast_horizon)

    val_start <- NA_integer_
    val_end <- NA_integer_
    train_end <- n_train_obs
    split_notes <- if (!is.na(n_test_obs) && !is.na(h) && n_test_obs != h) "official_test_length_differs_from_horizon" else NA_character_

    if (identical(protocol, "train_val_test_tail") && is.finite(n_train_obs) && is.finite(h)) {
      candidate_train_end <- n_train_obs - h
      if (candidate_train_end >= min_train_points) {
        val_start <- candidate_train_end + 1L
        val_end <- n_train_obs
        train_end <- candidate_train_end
      } else {
        split_notes <- paste(na.omit(c(split_notes, "validation_block_skipped_short_series")), collapse = "; ")
      }
    }

    .(
      train_start = 1L,
      train_end = train_end,
      val_start = val_start,
      val_end = val_end,
      test_start = n_train_obs + 1L,
      test_end = n_train_obs + n_test_obs,
      official_train_end = n_train_obs,
      official_test_start = n_train_obs + 1L,
      official_test_end = n_train_obs + n_test_obs,
      forecast_horizon = h,
      split_protocol = protocol,
      split_notes = split_notes
    )
  }, by = .(dataset, source_family, series_id)]

  splits[]
}

bench_collect_quality_issues <- function(metadata_dt, split_dt) {
  data.table::setkey(split_dt, dataset, source_family, series_id)
  dt <- split_dt[metadata_dt, on = .(dataset, source_family, series_id)]

  duplicate_ids <- dt[, .N, by = .(dataset, source_family, series_id)][N > 1L, .(dataset, source_family, series_id)]
  duplicate_keys <- if (nrow(duplicate_ids)) paste(duplicate_ids$dataset, duplicate_ids$series_id, sep = "::") else character()

  issues <- list()

  add_issue <- function(rows, issue_type, severity, action, details_fun = NULL) {
    if (!nrow(rows)) return(invisible(NULL))
    issue_dt <- rows[, .(dataset, source_family, series_id)]
    issue_dt[, issue_type := issue_type]
    issue_dt[, severity := severity]
    issue_dt[, action := action]
    issue_dt[, details := issue_type]
    issues[[length(issues) + 1L]] <<- issue_dt
    invisible(NULL)
  }

  add_issue(dt[paste(dataset, series_id, sep = "::") %in% duplicate_keys], "duplicate_series_id", "error", "excluded")
  add_issue(dt[n_finite <= 0L], "all_missing_or_nonfinite", "error", "excluded")
  add_issue(dt[is.na(forecast_horizon) | forecast_horizon <= 0L], "invalid_forecast_horizon", "error", "excluded")
  add_issue(dt[!is.na(forecast_horizon) & n_obs <= forecast_horizon], "too_short_for_test_horizon", "error", "excluded")
  add_issue(dt[n_missing > 0L], "missing_values_present", "warning", "kept")
  add_issue(dt[!is.na(y_var) & y_var == 0], "zero_variance", "warning", "kept")
  add_issue(dt[!is.na(y_sd) & !is.na(y_mean) & y_sd <= 1e-08 * pmax(1, abs(y_mean))], "near_constant", "warning", "kept")
  add_issue(dt[!is.na(forecast_horizon) & n_obs < (2L * forecast_horizon)], "short_relative_to_horizon", "warning", "kept")
  add_issue(dt[source_family == "m4" & !is.na(n_test) & !is.na(forecast_horizon) & n_test != forecast_horizon], "m4_test_length_mismatch", "error", "excluded")

  issues_dt <- if (length(issues)) data.table::rbindlist(issues, fill = TRUE) else data.table::data.table(
    dataset = character(),
    source_family = character(),
    series_id = character(),
    issue_type = character(),
    severity = character(),
    action = character(),
    details = character()
  )

  excluded <- unique(issues_dt[action == "excluded", .(dataset, source_family, series_id, issue_type, details)])
  list(issues = issues_dt, excluded_series = excluded)
}

bench_assign_split_labels <- function(panel_dt, split_dt) {
  data.table::setkey(split_dt, dataset, source_family, series_id)
  labeled <- split_dt[panel_dt, on = .(dataset, source_family, series_id)]
  labeled[, split := vapply(
    seq_len(.N),
    function(i) {
      bench_label_split(
        t_index = t_index[[i]],
        train_end = train_end[[i]],
        val_start = val_start[[i]],
        val_end = val_end[[i]],
        test_start = test_start[[i]],
        test_end = test_end[[i]]
      )
    },
    character(1)
  )]

  labeled[, c("train_start", "train_end", "val_start", "val_end", "test_start", "test_end",
              "official_train_end", "official_test_start", "official_test_end",
              "forecast_horizon", "split_protocol", "split_notes") := NULL]
  labeled[]
}

bench_dataset_summary <- function(metadata_dt, issues_dt) {
  exclusion_counts <- issues_dt[action == "excluded", .N, by = .(dataset, source_family)]

  summary_dt <- metadata_dt[, .(
    n_series = as.integer(.N),
    frequency_label = unique(frequency_label)[1L],
    mean_length = as.numeric(mean(n_obs)),
    median_length = as.numeric(stats::median(n_obs)),
    min_length = as.integer(min(n_obs)),
    max_length = as.integer(max(n_obs)),
    q10_length = as.numeric(stats::quantile(n_obs, probs = 0.10, names = FALSE)),
    q90_length = as.numeric(stats::quantile(n_obs, probs = 0.90, names = FALSE)),
    mean_horizon = as.numeric(mean(forecast_horizon, na.rm = TRUE)),
    median_horizon = as.numeric(stats::median(forecast_horizon, na.rm = TRUE)),
    missing_rate = as.numeric(mean(n_missing / pmax(n_obs, 1L), na.rm = TRUE)),
    has_missing_series = as.integer(sum(n_missing > 0L))
  ), by = .(dataset, source_family, dataset_label)]

  summary_dt[exclusion_counts, excluded_series := i.N, on = .(dataset, source_family)]
  summary_dt[is.na(excluded_series), excluded_series := 0L]
  summary_dt[]
}

bench_write_panel_partition <- function(panel_dt, dataset, context) {
  cfg <- context$config
  paths <- context$paths

  out <- bench_save_table(
    x = panel_dt,
    path_stub = file.path(paths$panel_dir, dataset),
    write_csv = FALSE,
    write_rds = TRUE,
    compress = cfg$processing$compress %||% "gzip"
  )

  data.table::data.table(
    dataset = dataset,
    panel_path = bench_rel_path(out$rds, repo_root = paths$repo_root),
    n_rows = nrow(panel_dt),
    n_series = data.table::uniqueN(panel_dt$series_id)
  )
}

bench_write_processed_outputs <- function(results, context) {
  cfg <- context$config
  paths <- context$paths

  result_dataset <- function(res) {
    candidates <- list(res$metadata, res$panel, res$splits, res$exclusion_log, res$quality_issues)
    for (candidate in candidates) {
      if (is.data.frame(candidate) && nrow(candidate) && "dataset" %in% names(candidate)) {
        return(unique(candidate$dataset)[[1L]])
      }
    }
    stop("Could not resolve a dataset name for a benchmark result.", call. = FALSE)
  }

  metadata_dt <- data.table::rbindlist(lapply(results, `[[`, "metadata"), fill = TRUE)
  split_dt <- data.table::rbindlist(lapply(results, `[[`, "splits"), fill = TRUE)
  issues_dt <- data.table::rbindlist(lapply(results, `[[`, "quality_issues"), fill = TRUE)
  exclusion_dt <- data.table::rbindlist(lapply(results, `[[`, "exclusion_log"), fill = TRUE)
  panel_manifest <- data.table::rbindlist(
    lapply(results, function(res) bench_write_panel_partition(res$panel, result_dataset(res), context)),
    fill = TRUE
  )
  summary_dt <- bench_dataset_summary(metadata_dt, issues_dt)

  bench_save_table(metadata_dt, file.path(paths$metadata_dir, "series_metadata"), write_csv = TRUE, write_rds = TRUE, compress = cfg$processing$compress %||% "gzip")
  bench_save_table(summary_dt, file.path(paths$metadata_dir, "dataset_summary"), write_csv = TRUE, write_rds = TRUE, compress = cfg$processing$compress %||% "gzip")
  bench_save_table(panel_manifest, file.path(paths$metadata_dir, "panel_manifest"), write_csv = TRUE, write_rds = TRUE, compress = cfg$processing$compress %||% "gzip")
  bench_save_table(split_dt, file.path(paths$splits_dir, "split_definitions"), write_csv = TRUE, write_rds = TRUE, compress = cfg$processing$compress %||% "gzip")
  bench_save_table(issues_dt, file.path(paths$quality_dir, "quality_issues"), write_csv = TRUE, write_rds = TRUE, compress = cfg$processing$compress %||% "gzip")
  bench_save_table(exclusion_dt, file.path(paths$quality_dir, "exclusion_log"), write_csv = TRUE, write_rds = TRUE, compress = cfg$processing$compress %||% "gzip")

  bench_write_json(
    list(
      generated_at_utc = bench_timestamp_utc(),
      git = context$git,
      datasets = summary_dt$dataset,
      counts = list(
        datasets = nrow(summary_dt),
        series = nrow(metadata_dt),
        panel_partitions = nrow(panel_manifest),
        exclusions = nrow(exclusion_dt)
      ),
      processed_roots = list(
        metadata = bench_rel_path(paths$metadata_dir, repo_root = paths$repo_root),
        panel = bench_rel_path(paths$panel_dir, repo_root = paths$repo_root),
        splits = bench_rel_path(paths$splits_dir, repo_root = paths$repo_root),
        quality = bench_rel_path(paths$quality_dir, repo_root = paths$repo_root)
      )
    ),
    file.path(paths$metadata_dir, "benchmark_summary.json")
  )

  invisible(list(
    metadata = metadata_dt,
    splits = split_dt,
    issues = issues_dt,
    exclusion_log = exclusion_dt,
    panel_manifest = panel_manifest,
    summary = summary_dt
  ))
}

bench_build_benchmarks <- function(config_path = NULL) {
  bench_assert_packages(bench_required_packages("build"))
  bench_attach_packages("data.table")

  context <- bench_read_pipeline_config(config_path = config_path)
  bench_ensure_directories(context$paths)

  info_path <- file.path(context$paths$raw_m4, "metadata", context$registry$m4$info$file_name)
  if (!file.exists(info_path)) {
    stop("M4 info file is missing. Run the benchmark download step first.", call. = FALSE)
  }
  info_dt <- bench_parse_m4_info(info_path)

  results <- list()

  for (dataset_id in context$registry$monash$default_selection) {
    message("[bench-build] monash:", dataset_id)
    results[[dataset_id]] <- bench_build_monash_dataset(context$registry$monash$datasets[[dataset_id]], context)
  }

  for (freq_name in context$registry$m4$default_selection) {
    message("[bench-build] m4:", freq_name)
    results[[freq_name]] <- bench_build_m4_frequency(freq_name, context$registry$m4$frequencies[[freq_name]], info_dt, context)
  }

  message("[bench-build] writing processed outputs")
  outputs <- bench_write_processed_outputs(results, context)
  invisible(c(context, outputs))
}

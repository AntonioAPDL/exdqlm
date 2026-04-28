rf288_run_tag_20260427 <- "20260422_p90_full288_baseline_v1"
rf288_analysis_stamp_20260427 <- "20260427"

rf288_status_path_20260427 <- file.path(
  "tools",
  "merge_reports",
  paste0("LOCAL_refreshed288_full_manifest_status_", rf288_run_tag_20260427, ".csv")
)

rf288_manifest_path_20260427 <- file.path(
  "tools",
  "merge_reports",
  paste0("LOCAL_refreshed288_full_manifest_", rf288_run_tag_20260427, ".csv")
)

rf288_output_path_20260427 <- function(stem) {
  file.path(
    "tools",
    "merge_reports",
    paste0(
      "LOCAL_refreshed288_",
      stem,
      "_",
      rf288_analysis_stamp_20260427,
      "_",
      rf288_run_tag_20260427,
      ".csv"
    )
  )
}

rf288_read_csv_20260427 <- function(path) {
  if (!file.exists(path)) {
    stop(sprintf("Missing required input: %s", path), call. = FALSE)
  }

  read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}

rf288_write_csv_20260427 <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  write.csv(x, path, row.names = FALSE, na = "")
}

rf288_na_chr_20260427 <- function(x) {
  out <- as.character(x)
  out[is.na(out) | out == "" | out == "NA"] <- NA_character_
  out
}

rf288_numeric_or_na_20260427 <- function(x) {
  suppressWarnings(as.numeric(x))
}

rf288_truthy_20260427 <- function(x) {
  if (is.logical(x)) {
    out <- x
    out[is.na(out)] <- FALSE
    return(out)
  }

  lx <- tolower(trimws(as.character(x)))
  lx %in% c("true", "t", "1", "yes", "y")
}

rf288_pct_20260427 <- function(num, den) {
  ifelse(is.na(den) | den == 0, NA_real_, round(100 * num / den, 1))
}

rf288_safe_mean_20260427 <- function(x) {
  x <- rf288_numeric_or_na_20260427(x)
  if (all(is.na(x))) {
    return(NA_real_)
  }
  mean(x, na.rm = TRUE)
}

rf288_safe_median_20260427 <- function(x) {
  x <- rf288_numeric_or_na_20260427(x)
  if (all(is.na(x))) {
    return(NA_real_)
  }
  stats::median(x, na.rm = TRUE)
}

rf288_gate_rank_20260427 <- function(x) {
  ux <- toupper(trimws(as.character(x)))
  out <- rep(0L, length(ux))
  out[ux == "FAIL"] <- 1L
  out[ux == "WARN"] <- 2L
  out[ux == "PASS"] <- 3L
  out
}

rf288_gate_comparison_20260427 <- function(candidate_rank, reference_rank, candidate_label, reference_label) {
  candidate_rank <- rf288_numeric_or_na_20260427(candidate_rank)
  reference_rank <- rf288_numeric_or_na_20260427(reference_rank)

  ifelse(
    is.na(candidate_rank) | is.na(reference_rank),
    "missing",
    ifelse(
      candidate_rank > reference_rank,
      paste0(candidate_label, "_better"),
      ifelse(candidate_rank < reference_rank, paste0(reference_label, "_better"), "tie")
    )
  )
}

rf288_runtime_ratio_20260427 <- function(num, den) {
  num <- rf288_numeric_or_na_20260427(num)
  den <- rf288_numeric_or_na_20260427(den)
  ifelse(is.na(num) | is.na(den) | den == 0, NA_real_, round(num / den, 6))
}

rf288_faster_method_20260427 <- function(candidate_runtime, reference_runtime, candidate_label, reference_label) {
  candidate_runtime <- rf288_numeric_or_na_20260427(candidate_runtime)
  reference_runtime <- rf288_numeric_or_na_20260427(reference_runtime)

  ifelse(
    is.na(candidate_runtime) | is.na(reference_runtime),
    NA_character_,
    ifelse(
      candidate_runtime < reference_runtime,
      candidate_label,
      ifelse(candidate_runtime > reference_runtime, reference_label, "tie")
    )
  )
}

rf288_ensure_columns_20260427 <- function(df, cols) {
  missing_cols <- setdiff(cols, names(df))
  for (col in missing_cols) {
    df[[col]] <- NA
  }
  df[, cols, drop = FALSE]
}

rf288_metric_cols_20260427 <- function() {
  c(
    "crps",
    "primary_accuracy",
    "q_rmse",
    "coverage95",
    "coverage95_gap",
    "mean_ci_width",
    "cie",
    "beta_rmse_mean",
    "beta_coverage_gap"
  )
}

rf288_make_scenario_key_20260427 <- function(df) {
  paste(
    df$block,
    df$root_kind,
    df$family,
    df$tau_label,
    df$fit_size,
    df$prior_semantics,
    sep = "::"
  )
}

rf288_read_inputs_20260427 <- function(
  status_path = rf288_status_path_20260427,
  manifest_path = rf288_manifest_path_20260427
) {
  status <- rf288_read_csv_20260427(status_path)
  manifest <- rf288_read_csv_20260427(manifest_path)

  status$.rf288_order <- seq_len(nrow(status))

  path_cols <- intersect(
    c(
      "row_id",
      "pair_id",
      "source_dataset_id",
      "config_path",
      "run_root",
      "candidate_fit_path",
      "vb_init_fit_path",
      "row_status_path",
      "health_path",
      "metrics_path",
      "draws_path",
      "stored_posterior_draws"
    ),
    names(manifest)
  )

  merged <- merge(
    status,
    manifest[, path_cols, drop = FALSE],
    by = "row_id",
    all.x = TRUE,
    sort = FALSE
  )
  merged <- merged[order(merged$.rf288_order), , drop = FALSE]
  merged$.rf288_order <- NULL
  row.names(merged) <- NULL

  merged
}

rf288_build_comparison_long_20260427 <- function(df) {
  df$case_key <- df$original_case_key
  df$scenario_key <- rf288_make_scenario_key_20260427(df)
  df$scope_label <- df$root_kind
  df$workstream <- df$block
  df$method_id <- paste(df$inference, df$model, sep = "__")
  df$gate_overall <- toupper(ifelse(is.na(df$gate_current) | df$gate_current == "", "MISSING", df$gate_current))
  df$gate_rank_num <- rf288_gate_rank_20260427(df$gate_overall)
  df$healthy <- rf288_truthy_20260427(df$healthy_current)
  df$status <- df$status_current
  df$state <- df$gate_overall
  df$runtime_sec <- rf288_numeric_or_na_20260427(df$runtime_sec_current)
  df$completed <- df$status_current == "done"

  df$crps <- rf288_numeric_or_na_20260427(df$crps_metric)
  df$primary_accuracy <- rf288_numeric_or_na_20260427(df$primary_accuracy_metric)
  df$q_rmse <- rf288_numeric_or_na_20260427(df$q_rmse_metric)
  df$coverage95 <- rf288_numeric_or_na_20260427(df$coverage95_metric)
  df$coverage95_gap <- rf288_numeric_or_na_20260427(df$coverage95_gap_metric)
  df$mean_ci_width <- rf288_numeric_or_na_20260427(df$mean_ci_width_metric)
  df$cie <- rf288_numeric_or_na_20260427(df$cie_metric)
  df$beta_rmse_mean <- rf288_numeric_or_na_20260427(df$beta_rmse_mean_metric)
  df$beta_coverage_gap <- rf288_numeric_or_na_20260427(df$beta_coverage_gap_metric)

  df$hard_error_present <- !is.na(df$error_current) & nzchar(df$error_current)
  df$metric_error_present <- !is.na(df$metric_error) & nzchar(df$metric_error)

  ordered_cols <- c(
    "row_id",
    "base_row_id",
    "case_key",
    "original_case_key",
    "scenario_key",
    "workstream",
    "scope_label",
    "phase",
    "phase_order",
    "block",
    "root_kind",
    "family",
    "tau",
    "tau_label",
    "fit_size",
    "prior_semantics",
    "model",
    "inference",
    "method_id",
    "method_profile_id",
    "source_dataset_id",
    "seed",
    "status",
    "status_current",
    "completed",
    "gate_overall",
    "gate_current",
    "gate_rank_num",
    "healthy",
    "healthy_current",
    "state",
    "runtime_sec",
    "runtime_sec_current",
    "crps",
    "primary_accuracy",
    "q_rmse",
    "coverage95",
    "coverage95_gap",
    "mean_ci_width",
    "cie",
    "beta_rmse_mean",
    "beta_coverage_gap",
    "metric_source",
    "metric_error",
    "metric_error_present",
    "error_current",
    "hard_error_present",
    "config_path",
    "run_root",
    "candidate_fit_path",
    "vb_init_fit_path",
    "row_status_path",
    "health_path",
    "metrics_path",
    "draws_path",
    "stored_posterior_draws"
  )

  out <- rf288_ensure_columns_20260427(df, ordered_cols)
  out[order(out$block, out$root_kind, out$family, out$tau_label, out$fit_size, out$prior_semantics, out$inference, out$model, out$row_id), ]
}

rf288_group_gate_summary_20260427 <- function(df, by) {
  if (!nrow(df)) {
    return(data.frame())
  }

  parts <- split(df, interaction(df[by], drop = TRUE, lex.order = TRUE))
  out <- lapply(parts, function(chunk) {
    base <- chunk[1, by, drop = FALSE]
    total <- nrow(chunk)
    completed <- sum(chunk$completed, na.rm = TRUE)
    pass <- sum(chunk$gate_overall == "PASS", na.rm = TRUE)
    warn <- sum(chunk$gate_overall == "WARN", na.rm = TRUE)
    fail <- sum(chunk$gate_overall == "FAIL", na.rm = TRUE)
    healthy_true <- sum(rf288_truthy_20260427(chunk$healthy), na.rm = TRUE)

    data.frame(
      base,
      total = total,
      completed = completed,
      pass = pass,
      warn = warn,
      fail = fail,
      healthy_true = healthy_true,
      healthy_false = total - healthy_true,
      pct_completed = rf288_pct_20260427(completed, total),
      pct_pass = rf288_pct_20260427(pass, total),
      pct_warn = rf288_pct_20260427(warn, total),
      pct_fail = rf288_pct_20260427(fail, total),
      pct_healthy = rf288_pct_20260427(healthy_true, total),
      runtime_sec_total = round(sum(chunk$runtime_sec, na.rm = TRUE), 3),
      runtime_sec_mean = round(rf288_safe_mean_20260427(chunk$runtime_sec), 3),
      runtime_sec_median = round(rf288_safe_median_20260427(chunk$runtime_sec), 3),
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, out)
}

rf288_group_numeric_summary_20260427 <- function(df, by, metrics) {
  if (!nrow(df)) {
    return(data.frame())
  }

  parts <- split(df, interaction(df[by], drop = TRUE, lex.order = TRUE))
  out <- lapply(parts, function(chunk) {
    base <- chunk[1, by, drop = FALSE]
    row <- base
    row$n <- nrow(chunk)
    for (metric in metrics) {
      vals <- rf288_numeric_or_na_20260427(chunk[[metric]])
      row[[paste0(metric, "_median")]] <- round(rf288_safe_median_20260427(vals), 6)
      row[[paste0(metric, "_mean")]] <- round(rf288_safe_mean_20260427(vals), 6)
      row[[paste0(metric, "_nonmissing")]] <- sum(!is.na(vals))
    }
    row
  })

  do.call(rbind, out)
}

rf288_pair_summary_20260427 <- function(df, by, comparison_values, faster_values, ratio_col) {
  make_row <- function(chunk, labels) {
    row <- as.data.frame(labels, stringsAsFactors = FALSE)
    row$total_pairs <- nrow(chunk)
    for (val in comparison_values) {
      row[[val]] <- sum(chunk$gate_comparison == val, na.rm = TRUE)
    }
    for (val in faster_values) {
      row[[paste0(val, "_faster")]] <- sum(chunk$faster_method == val, na.rm = TRUE)
    }
    row[[paste0("median_", ratio_col)]] <- round(rf288_safe_median_20260427(chunk[[ratio_col]]), 6)
    row
  }

  overall_labels <- as.list(rep("all", length(by)))
  names(overall_labels) <- by
  if ("block" %in% by) {
    overall_labels$block <- "overall"
  }
  if ("inference" %in% by) {
    overall_labels$inference <- "all"
  }
  if ("model" %in% by) {
    overall_labels$model <- "all"
  }

  out <- list(make_row(df, overall_labels))
  if (nrow(df)) {
    parts <- split(df, interaction(df[by], drop = TRUE, lex.order = TRUE))
    out <- c(out, lapply(parts, function(chunk) {
      labels <- as.list(chunk[1, by, drop = FALSE])
      make_row(chunk, labels)
    }))
  }

  do.call(rbind, out)
}

rf288_inventory_columns_20260427 <- function() {
  c(
    "row_id",
    "case_key",
    "scenario_key",
    "block",
    "root_kind",
    "family",
    "tau_label",
    "fit_size",
    "prior_semantics",
    "inference",
    "model",
    "method_id",
    "gate_overall",
    "healthy",
    "runtime_sec",
    "crps",
    "q_rmse",
    "coverage95_gap",
    "mean_ci_width",
    "cie",
    "beta_rmse_mean",
    "beta_coverage_gap",
    "metric_source",
    "metric_error",
    "error_current",
    "health_path",
    "metrics_path",
    "candidate_fit_path"
  )
}

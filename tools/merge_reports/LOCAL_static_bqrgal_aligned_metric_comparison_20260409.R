#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

parse_args_metric_compare <- function(args) {
  out <- list()
  for (x in args) {
    if (grepl("^--[^=]+=.*$", x)) {
      key <- sub("^--([^=]+)=.*$", "\\1", x)
      val <- sub("^--[^=]+=(.*)$", "\\1", x)
      out[[key]] <- val
    }
  }
  out
}

args <- parse_args_metric_compare(commandArgs(trailingOnly = TRUE))
repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)

source("tools/merge_reports/LOCAL_static_bqrgal_aligned_helpers_20260408.R")

paths <- static_bqrgal_aligned_paths_20260408()
out_dir <- file.path(paths$out_dir, "static_bqrgal_aligned_metric_comparison_20260409")
ensure_dir_static_bqrgal(out_dir)

target_coverage <- safe_num_static_bqrgal(args$target_coverage, 0.95)

metric_paths <- Sys.glob(file.path(paths$metrics_dir, "metrics_*.csv"))
if (!length(metric_paths)) {
  stop(sprintf("no metric files found in %s", paths$metrics_dir))
}

metrics_list <- lapply(metric_paths, function(path) {
  df <- tryCatch(utils::read.csv(path, stringsAsFactors = FALSE), error = function(e) NULL)
  if (is.null(df) || !nrow(df)) return(NULL)
  df$file_path <- path
  df
})
metrics_list <- Filter(Negate(is.null), metrics_list)
metrics <- do.call(rbind, metrics_list)

key_cols <- c("lane_label", "family", "tau_label", "n_train", "rep_id")
metrics$key <- do.call(paste, c(metrics[key_cols], sep = "::"))

al <- metrics[metrics$model == "al", , drop = FALSE]
exal <- metrics[metrics$model == "exal", , drop = FALSE]
matched_keys <- intersect(al$key, exal$key)
if (!length(matched_keys)) {
  stop("no matched al/exal metric pairs found")
}

al <- al[match(matched_keys, al$key), , drop = FALSE]
exal <- exal[match(matched_keys, exal$key), , drop = FALSE]
stopifnot(all(al$key == exal$key))

paired <- data.frame(
  lane_label = al$lane_label,
  phase = al$phase,
  family = al$family,
  tau = al$tau,
  tau_label = al$tau_label,
  n_train = al$n_train,
  rep_id = al$rep_id,
  cie_al = al$cie,
  cie_exal = exal$cie,
  cie_delta_exal_minus_al = exal$cie - al$cie,
  rmse_al = al$beta_rmse_mean,
  rmse_exal = exal$beta_rmse_mean,
  rmse_delta_exal_minus_al = exal$beta_rmse_mean - al$beta_rmse_mean,
  coverage_al = al$beta_coverage_mean,
  coverage_exal = exal$beta_coverage_mean,
  coverage_gap_al = abs(al$beta_coverage_mean - target_coverage),
  coverage_gap_exal = abs(exal$beta_coverage_mean - target_coverage),
  coverage_gap_delta_exal_minus_al = abs(exal$beta_coverage_mean - target_coverage) - abs(al$beta_coverage_mean - target_coverage),
  interval_score_al = al$pred_interval_score_mean,
  interval_score_exal = exal$pred_interval_score_mean,
  interval_score_delta_exal_minus_al = exal$pred_interval_score_mean - al$pred_interval_score_mean,
  runtime_sec_al = al$runtime_sec,
  runtime_sec_exal = exal$runtime_sec,
  runtime_ratio_exal_over_al = exal$runtime_sec / al$runtime_sec,
  stringsAsFactors = FALSE
)

paired$exal_better_cie <- paired$cie_delta_exal_minus_al > 0
paired$exal_better_rmse <- paired$rmse_delta_exal_minus_al < 0
paired$exal_better_coverage <- paired$coverage_gap_delta_exal_minus_al < 0
paired$exal_better_interval_score <- paired$interval_score_delta_exal_minus_al < 0

pair_out <- paired[order(
  paired$lane_label,
  paired$n_train,
  paired$family,
  paired$tau,
  paired$rep_id
), , drop = FALSE]

split_key <- paste(pair_out$lane_label, pair_out$family, pair_out$tau_label, pair_out$n_train, sep = "\r")
scenario_summary <- do.call(rbind, lapply(split(pair_out, split_key), function(df) {
  data.frame(
    lane_label = df$lane_label[1],
    phase = df$phase[1],
    family = df$family[1],
    tau = df$tau[1],
    tau_label = df$tau_label[1],
    n_train = df$n_train[1],
    paired_reps = nrow(df),
    cie_median_al = stats::median(df$cie_al, na.rm = TRUE),
    cie_median_exal = stats::median(df$cie_exal, na.rm = TRUE),
    cie_delta_median = stats::median(df$cie_delta_exal_minus_al, na.rm = TRUE),
    rmse_median_al = stats::median(df$rmse_al, na.rm = TRUE),
    rmse_median_exal = stats::median(df$rmse_exal, na.rm = TRUE),
    rmse_delta_median = stats::median(df$rmse_delta_exal_minus_al, na.rm = TRUE),
    coverage_mean_al = mean(df$coverage_al, na.rm = TRUE),
    coverage_mean_exal = mean(df$coverage_exal, na.rm = TRUE),
    coverage_gap_mean_al = mean(df$coverage_gap_al, na.rm = TRUE),
    coverage_gap_mean_exal = mean(df$coverage_gap_exal, na.rm = TRUE),
    coverage_gap_delta_mean = mean(df$coverage_gap_delta_exal_minus_al, na.rm = TRUE),
    interval_score_median_al = stats::median(df$interval_score_al, na.rm = TRUE),
    interval_score_median_exal = stats::median(df$interval_score_exal, na.rm = TRUE),
    interval_score_delta_median = stats::median(df$interval_score_delta_exal_minus_al, na.rm = TRUE),
    runtime_ratio_median = stats::median(df$runtime_ratio_exal_over_al, na.rm = TRUE),
    exal_better_cie = sum(df$exal_better_cie, na.rm = TRUE),
    exal_better_rmse = sum(df$exal_better_rmse, na.rm = TRUE),
    exal_better_coverage = sum(df$exal_better_coverage, na.rm = TRUE),
    exal_better_interval_score = sum(df$exal_better_interval_score, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}))

scenario_summary <- scenario_summary[order(
  scenario_summary$lane_label,
  scenario_summary$n_train,
  scenario_summary$family,
  scenario_summary$tau
), , drop = FALSE]
rownames(scenario_summary) <- NULL

lane_summary <- do.call(rbind, lapply(split(pair_out, pair_out$lane_label), function(df) {
  data.frame(
    lane_label = df$lane_label[1],
    paired_reps = nrow(df),
    cie_median_al = stats::median(df$cie_al, na.rm = TRUE),
    cie_median_exal = stats::median(df$cie_exal, na.rm = TRUE),
    cie_delta_median = stats::median(df$cie_delta_exal_minus_al, na.rm = TRUE),
    rmse_median_al = stats::median(df$rmse_al, na.rm = TRUE),
    rmse_median_exal = stats::median(df$rmse_exal, na.rm = TRUE),
    rmse_delta_median = stats::median(df$rmse_delta_exal_minus_al, na.rm = TRUE),
    coverage_mean_al = mean(df$coverage_al, na.rm = TRUE),
    coverage_mean_exal = mean(df$coverage_exal, na.rm = TRUE),
    coverage_gap_mean_al = mean(df$coverage_gap_al, na.rm = TRUE),
    coverage_gap_mean_exal = mean(df$coverage_gap_exal, na.rm = TRUE),
    coverage_gap_delta_mean = mean(df$coverage_gap_delta_exal_minus_al, na.rm = TRUE),
    interval_score_median_al = stats::median(df$interval_score_al, na.rm = TRUE),
    interval_score_median_exal = stats::median(df$interval_score_exal, na.rm = TRUE),
    interval_score_delta_median = stats::median(df$interval_score_delta_exal_minus_al, na.rm = TRUE),
    runtime_ratio_median = stats::median(df$runtime_ratio_exal_over_al, na.rm = TRUE),
    exal_better_cie = sum(df$exal_better_cie, na.rm = TRUE),
    exal_better_rmse = sum(df$exal_better_rmse, na.rm = TRUE),
    exal_better_coverage = sum(df$exal_better_coverage, na.rm = TRUE),
    exal_better_interval_score = sum(df$exal_better_interval_score, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}))

row_issues <- data.frame(
  total_metric_files = nrow(metrics),
  matched_pairs = nrow(pair_out),
  target_coverage = target_coverage,
  stringsAsFactors = FALSE
)

utils::write.csv(pair_out, file.path(out_dir, "static_bqrgal_aligned_metric_pair_detail_20260409.csv"), row.names = FALSE)
utils::write.csv(scenario_summary, file.path(out_dir, "static_bqrgal_aligned_metric_scenario_summary_20260409.csv"), row.names = FALSE)
utils::write.csv(lane_summary, file.path(out_dir, "static_bqrgal_aligned_metric_lane_summary_20260409.csv"), row.names = FALSE)
utils::write.csv(row_issues, file.path(out_dir, "static_bqrgal_aligned_metric_meta_20260409.csv"), row.names = FALSE)

cat(sprintf("wrote %s\n", out_dir))

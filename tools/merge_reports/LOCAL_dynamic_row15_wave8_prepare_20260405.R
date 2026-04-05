#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
out_dir <- file.path(repo_root, "tools", "merge_reports")

matrix_path <- file.path(out_dir, "LOCAL_dynamic_row15_wave8_matrix_20260405.csv")
stage_counts_path <- file.path(out_dir, "LOCAL_dynamic_row15_wave8_stage_counts_20260405.csv")

matrix <- data.frame(
  phase = c("row15_replay2", "row15_replay2"),
  track = c("dynamic_row15", "dynamic_row15"),
  queue_id = c(15L, 15L),
  config_id = c("slice_exact", "slice_long"),
  model = c("exdqlm", "exdqlm"),
  family = c("gausmix", "gausmix"),
  tt = c(5000L, 5000L),
  tau = c("0p25", "0p25"),
  seed = c(2026032111L, 2026041502L),
  mh_proposal = c("slice", "slice"),
  mh_adapt = c("false", "false"),
  laplace_refresh_interval = c(50L, 50L),
  laplace_refresh_start = c(200L, 250L),
  laplace_refresh_weight = c(0.60, 0.60),
  slice_width = c(0.12, 0.12),
  slice_max_steps = c(80L, 80L),
  n_burn = c(1200L, 1500L),
  n_mcmc = c(4000L, 5000L),
  trace_every = c(50L, 50L),
  progress_every = c(50L, 50L),
  watchdog_mode = c("log_only", "log_only"),
  variant_tag = c("row15_slice_exact_20260405", "row15_slice_long_20260405"),
  rationale = c(
    "exact replay of the historical TT5000 gausmix slice rescue that already gated to WARN/healthy=TRUE",
    "same slice kernel with a mild longer tail to test whether the rescue remains stable under slightly more Monte Carlo effort"
  ),
  stringsAsFactors = FALSE
)

stage_counts <- data.frame(
  phase = "row15_replay2",
  n_rows = nrow(matrix),
  stringsAsFactors = FALSE
)

utils::write.csv(matrix, matrix_path, row.names = FALSE)
utils::write.csv(stage_counts, stage_counts_path, row.names = FALSE)

cat(sprintf("Wrote dynamic matrix: %s\n", matrix_path))
cat("STAGE_COUNTS\n")
print(stage_counts, row.names = FALSE)

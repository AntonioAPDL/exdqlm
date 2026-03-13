#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3L) {
  stop("Usage: 20260312_materialize_static_family_qspec_subsample.R <source_root> <target_root> <target_n>")
}
source_root <- args[[1]]
target_root <- args[[2]]
target_n <- as.integer(args[[3]])

source("tools/merge_reports/20260308_quantile_specific_sim_helpers.R")

sim_path <- file.path(source_root, "sim_output.rds")
if (!file.exists(sim_path)) stop("Missing source sim_output.rds: ", sim_path)
series_wide_path <- file.path(source_root, "series_wide.csv")
series_long_path <- file.path(source_root, "series_long.csv")
if (!file.exists(series_wide_path) || !file.exists(series_long_path)) {
  stop("Missing source series files under: ", source_root)
}

sim_output <- readRDS(sim_path)
series_wide <- utils::read.csv(series_wide_path, stringsAsFactors = FALSE)
series_long <- utils::read.csv(series_long_path, stringsAsFactors = FALSE)
order_key <- if ("x01" %in% names(series_wide)) series_wide$x01 else if ("x_main" %in% names(series_wide)) series_wide$x_main else seq_len(nrow(series_wide))

tmp_root <- dirname(target_root)
dir.create(tmp_root, recursive = TRUE, showWarnings = FALSE)
sub_root <- write_quantile_specific_subsample(
  sim_output = sim_output,
  out_root = source_root,
  target_n = target_n,
  order_key = order_key,
  sub_label = "x01_sorted",
  series_wide = series_wide,
  series_long = series_long,
  extra_files = c("coef_truth.csv", "true_quantile_grid.csv")
)

if (normalizePath(sub_root, winslash = "/", mustWork = TRUE) != normalizePath(target_root, winslash = "/", mustWork = FALSE)) {
  dir.create(dirname(target_root), recursive = TRUE, showWarnings = FALSE)
  if (dir.exists(target_root)) unlink(target_root, recursive = TRUE, force = TRUE)
  ok <- file.rename(sub_root, target_root)
  if (!ok) stop("Failed to rename subsample root from ", sub_root, " to ", target_root)
}

cat(sprintf("Materialized static family-qspec subsample under: %s\n", target_root))

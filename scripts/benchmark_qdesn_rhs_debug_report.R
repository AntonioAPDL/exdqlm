#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  source("scripts/benchmark_common.R")
})

repo_root <- bootstrap_benchmark_packages("all")
args <- commandArgs(trailingOnly = TRUE)

get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) && idx < length(args)) args[idx + 1L] else default
}

run_dir <- get_arg("--run_dir")
if (is.null(run_dir) || !nzchar(run_dir)) {
  stop("Usage: Rscript --vanilla scripts/benchmark_qdesn_rhs_debug_report.R --run_dir <results_dir>", call. = FALSE)
}

report <- bench_qdesn_rhs_stageA_write_report(
  bench_abs_path(run_dir, repo_root = repo_root, must_work = TRUE)
)
cat("RHS debug report:", report$report_path, "\n")

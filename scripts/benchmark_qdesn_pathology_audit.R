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
  stop("Usage: Rscript --vanilla scripts/benchmark_qdesn_pathology_audit.R --run_dir <results_dir>", call. = FALSE)
}

res <- bench_qdesn_pathology_write_report(run_dir = run_dir, repo_root = repo_root)
cat("Pathology audit report:", res$report_path, "\n")

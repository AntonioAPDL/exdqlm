#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  source("scripts/benchmark_common.R")
})

Sys.setenv(
  OPENBLAS_NUM_THREADS = "1",
  OMP_NUM_THREADS = "1",
  MKL_NUM_THREADS = "1",
  VECLIB_MAXIMUM_THREADS = "1",
  NUMEXPR_NUM_THREADS = "1"
)

repo_root <- bootstrap_benchmark_packages("all")
args <- benchmark_cli_args()

context <- bench_read_pipeline_config(config_path = args$config, repo_root = repo_root)
res <- bench_qdesn_run_shoulder_audit(context)

cat("Run dir:", res$run_dirs$run_dir, "\n")
cat("Report:", res$report_path, "\n")

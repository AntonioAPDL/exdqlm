#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  source("scripts/benchmark_common.R")
})

repo_root <- bootstrap_benchmark_packages("all")
args <- benchmark_cli_args()

context <- bench_read_pipeline_config(config_path = args$config, repo_root = repo_root)
res <- bench_qdesn_run_experiment(context)
report <- bench_qdesn_write_report(res$run_dirs$run_dir)

cat("Run dir:", res$run_dirs$run_dir, "\n")
cat("Report:", report$report_path, "\n")

#!/usr/bin/env Rscript

args_all <- commandArgs(trailingOnly = FALSE)
script_arg <- sub("^--file=", "", args_all[grep("^--file=", args_all)])
repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), mustWork = TRUE),
  error = function(...) normalizePath(file.path(dirname(script_arg[[1L]]), ".."), mustWork = TRUE)
)
setwd(repo_root)

source(file.path(repo_root, "scripts", "benchmark_common.R"))

args <- benchmark_cli_args()
bootstrap_benchmark_packages("all")

bench_download_benchmarks(config_path = args$config, overwrite = isTRUE(args$overwrite))
bench_build_benchmarks(config_path = args$config)
res <- bench_analyze_benchmarks(config_path = args$config)

cat("Benchmark pipeline complete.\n")
cat("Processed metadata:", file.path(res$loaded$context$paths$metadata_dir, "series_metadata.csv.gz"), "\n")
cat("Report:", res$report_path, "\n")

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
bootstrap_benchmark_packages("download")

res <- bench_download_benchmarks(
  config_path = args$config,
  overwrite = isTRUE(args$overwrite)
)

cat("Benchmark downloads complete.\n")
cat("Raw root:", res$paths$raw_root, "\n")
cat("Manifest:", file.path(res$paths$manifests_dir, "download_manifest.csv.gz"), "\n")

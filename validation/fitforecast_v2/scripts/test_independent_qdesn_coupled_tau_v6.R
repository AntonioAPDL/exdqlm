#!/usr/bin/env Rscript
args <- commandArgs(TRUE)
repo_root <- normalizePath(args[1]); out <- args[2]
setwd(repo_root)
Sys.setenv(OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1", MKL_NUM_THREADS = "1")
harness_root <- file.path(repo_root, "validation/fitforecast_v2")
suppressPackageStartupMessages(pkgload::load_all(repo_root, quiet = TRUE, compile = FALSE))
files <- c("test-independent-qdesn-coupled-tau-v6.R", "test-independent-qdesn-beta-solver-v5.R",
  "test-independent-qdesn-corrected-broad-v4.R", "test-independent-qdesn-corrected-forecast-v3.R")
results <- lapply(files, function(file) as.data.frame(testthat::test_file(
  file.path(harness_root, "tests/testthat", file), reporter = "summary", stop_on_failure = TRUE)))
results <- do.call(rbind, results); results$result <- NULL
dir.create(out, recursive = TRUE, showWarnings = FALSE)
write.csv(results, file.path(out, "test_results.csv"), row.names = FALSE)
writeLines(capture.output(sessionInfo()), file.path(out, "session_info.txt"))
cat("Passed:", sum(results$passed), "failed:", sum(results$failed), "warnings:", sum(results$warning), "\n")

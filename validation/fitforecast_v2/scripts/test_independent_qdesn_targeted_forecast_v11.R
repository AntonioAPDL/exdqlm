#!/usr/bin/env Rscript
args <- commandArgs(TRUE)
repo_root <- normalizePath(args[1]); test_output <- normalizePath(args[2], mustWork = FALSE)
if (dir.exists(test_output)) stop("Use a fresh test output directory.")
dir.create(test_output, recursive = TRUE)
setwd(repo_root)
harness_root <- file.path(repo_root, "validation/fitforecast_v2")
Sys.setenv(OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1", MKL_NUM_THREADS = "1")
suppressPackageStartupMessages(pkgload::load_all(repo_root, quiet = TRUE, compile = FALSE))
source(file.path(harness_root, "R/independent_qdesn_targeted_forecast_v11.R"))
iqtf_v11_source(repo_root)
files <- c("tests/testthat/test-qdesn-frozen-input-overrides.R",
  "validation/fitforecast_v2/tests/testthat/test-independent-qdesn-targeted-forecast-v11.R",
  "validation/fitforecast_v2/tests/testthat/test-independent-qdesn-targeted-forecast-v11-launcher.R")
results <- do.call(rbind, lapply(files, function(f) as.data.frame(testthat::test_file(
  f, reporter = "summary", stop_on_failure = FALSE, env = .GlobalEnv))))
results$result <- NULL
write.csv(results, file.path(test_output, "test_results.csv"), row.names = FALSE)
writeLines(capture.output(sessionInfo()), file.path(test_output, "session_info.txt"))
stopifnot(all(results$failed == 0), !any(results$error), all(results$warning == 0),
  all(results$skipped == 0))
cat("Passed:", sum(results$passed), "failed:", sum(results$failed),
  "warnings:", sum(results$warning), "\n")

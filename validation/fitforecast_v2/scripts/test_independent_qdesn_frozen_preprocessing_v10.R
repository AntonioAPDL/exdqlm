#!/usr/bin/env Rscript
args <- commandArgs(TRUE)
repo_root <- normalizePath(args[1]);out <- args[2]
setwd(repo_root)
Sys.setenv(OMP_NUM_THREADS="1",OPENBLAS_NUM_THREADS="1",MKL_NUM_THREADS="1")
harness_root <- file.path(repo_root,"validation/fitforecast_v2")
suppressPackageStartupMessages(pkgload::load_all(repo_root,quiet=TRUE,compile=FALSE))
files <- c("tests/testthat/test-qdesn-frozen-input-overrides.R",
  "tests/testthat/test-qdesn-normal.R",
  "tests/testthat/test-qdesn-forecast-recursion-diagnostic.R",
  "tests/testthat/test-qdesn-mean-readout-state-forecast.R",
  "validation/fitforecast_v2/tests/testthat/test-independent-qdesn-frozen-preprocessing-v10.R",
  "validation/fitforecast_v2/tests/testthat/test-independent-qdesn-frozen-preprocessing-v10-launcher.R",
  "validation/fitforecast_v2/tests/testthat/test-independent-qdesn-corrected-forecast-v3.R",
  "validation/fitforecast_v2/tests/testthat/test-independent-qdesn-beta-solver-v5.R")
results <- do.call(rbind,lapply(files,function(f)as.data.frame(testthat::test_file(f,
  reporter="summary",stop_on_failure=FALSE))))
results$result <- NULL
dir.create(out,recursive=TRUE,showWarnings=FALSE)
write.csv(results,file.path(out,"test_results.csv"),row.names=FALSE)
writeLines(capture.output(sessionInfo()),file.path(out,"session_info.txt"))
stopifnot(all(results$failed==0),!any(results$error),all(results$warning==0))
cat("Passed:",sum(results$passed),"failed:",sum(results$failed),"warnings:",sum(results$warning),"\n")

#!/usr/bin/env Rscript
options(stringsAsFactors = FALSE)
Sys.setenv(OMP_NUM_THREADS = 1, OPENBLAS_NUM_THREADS = 1, MKL_NUM_THREADS = 1)
file <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L]))
repo <- normalizePath(file.path(dirname(file), "../../.."))
for (name in c("forecast_prefix_metric_intervals_v1", "forecast_prefix_reconstruction_v1", "forecast_prefix_recovery_v2"))
  source(file.path(repo, "validation/fitforecast_v2/R", paste0(name, ".R")))
tests <- c("test-forecast-prefix-metric-intervals-v1.R", "test-forecast-prefix-reconstruction-v1.R",
  "test-forecast-prefix-recovery-v2.R")
results <- lapply(tests, function(name) {
  x <- testthat::test_file(file.path(repo, "validation/fitforecast_v2/tests/testthat", name),
    reporter = "summary", stop_on_failure = TRUE, load_helpers = FALSE)
  y <- as.data.frame(x)
  fpf_assert(!any(y$failed > 0 | y$error), "Focused test failed.")
  data.frame(file = name, tests = nrow(y), expectations = sum(y$nb), failed = sum(y$failed),
    errors = sum(y$error), warnings = sum(y$warning), skipped = sum(y$skipped))
})
results <- do.call(rbind, results)
output <- file.path(repo, "validation/fitforecast_v2/local_trackers/prefix_recovery_v2_verification_20261014")
fpf_write(results, file.path(output, "focused_tests.csv"))
fpf_write(fpr_hashes(c(file, file.path(repo, "validation/fitforecast_v2/tests/testthat", tests))),
  file.path(output, "test_source_manifest.csv"))
print(results)

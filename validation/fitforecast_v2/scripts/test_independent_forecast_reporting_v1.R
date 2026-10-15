#!/usr/bin/env Rscript
options(stringsAsFactors = FALSE)
Sys.setenv(OMP_NUM_THREADS = 1, OPENBLAS_NUM_THREADS = 1, MKL_NUM_THREADS = 1)
file <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L]))
ifr_repo <- normalizePath(file.path(dirname(file), "../../.."))
for (name in c("forecast_prefix_metric_intervals_v1", "forecast_prefix_reconstruction_v1", "forecast_prefix_recovery_v2",
  "independent_dgp_oracle_reference_v1", "independent_forecast_reporting_v1"))
  source(file.path(ifr_repo, "validation/fitforecast_v2/R", paste0(name, ".R")))
files <- c("test-forecast-prefix-metric-intervals-v1.R", "test-forecast-prefix-reconstruction-v1.R",
  "test-forecast-prefix-recovery-v2.R", "test-independent-forecast-reporting-v1.R")
results <- lapply(files, function(name) {
  x <- as.data.frame(testthat::test_file(file.path(ifr_repo, "validation/fitforecast_v2/tests/testthat", name),
    reporter = "summary", stop_on_failure = TRUE, load_helpers = FALSE))
  fpf_assert(!any(x$failed > 0 | x$error | x$warning > 0), "Focused reporting test failed.")
  data.frame(file = name, tests = nrow(x), expectations = sum(x$nb), failed = sum(x$failed),
    errors = sum(x$error), warnings = sum(x$warning), skipped = sum(x$skipped))
})
out <- file.path(ifr_repo, "validation/fitforecast_v2/local_trackers/independent_reporting_300_500_v1/tests")
fpf_write(do.call(rbind, results), file.path(out, "focused_tests.csv"))
print(do.call(rbind, results))

#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
index <- match("--run-root", args)
if (is.na(index) || index == length(args)) stop("--run-root is required.",
                                                call. = FALSE)
run_root <- normalizePath(args[[index + 1L]], winslash = "/", mustWork = TRUE)
repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                           winslash = "/", mustWork = TRUE)
for (path in c(
  "independent_qdesn_full_redesign_v2.R",
  "independent_qdesn_full_redesign_v2_runtime.R",
  "independent_qdesn_corrected_forecast_v3.R",
  "independent_qdesn_corrected_forecast_v3_campaign.R",
  "independent_qdesn_corrected_broad_v4.R"
)) source(file.path(repo_root, "validation", "fitforecast_v2", "R", path))
health <- iqcb_v4_health(run_root)
print(health, row.names = FALSE)
if (nrow(health)) {
  cat("Total planned:", sum(health$planned), "\n")
  cat("Total successful:", sum(health$success), "\n")
  cat("Total remaining:", sum(health$planned - health$success - health$failed),
      "\n")
}

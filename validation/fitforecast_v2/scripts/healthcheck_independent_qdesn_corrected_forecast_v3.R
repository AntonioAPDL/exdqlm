#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
index <- match("--run-root", args)
if (is.na(index) || index == length(args)) {
  stop("--run-root is required.", call. = FALSE)
}
run_root <- normalizePath(args[[index + 1L]], winslash = "/", mustWork = TRUE)
repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/", mustWork = TRUE
)
for (path in c(
  "independent_qdesn_full_redesign_v2.R",
  "independent_qdesn_full_redesign_v2_runtime.R",
  "independent_qdesn_cellwise_refinement_v2_superseded_closeout.R",
  "independent_qdesn_corrected_forecast_v3.R",
  "independent_qdesn_corrected_forecast_v3_campaign.R"
)) source(file.path(repo_root, "validation", "fitforecast_v2", "R", path))
print(iqcf_v3_health(run_root), row.names = FALSE)

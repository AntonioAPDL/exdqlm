#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
value <- function(flag, default = NULL) {
  index <- match(flag, args)
  if (is.na(index) || index == length(args)) return(default)
  args[[index + 1L]]
}

repo_root <- normalizePath(
  value("--repo-root", system("git rev-parse --show-toplevel", intern = TRUE)),
  winslash = "/", mustWork = TRUE
)
run_root <- value("--run-root")
output_dir <- value("--output-dir", file.path(
  repo_root, "validation", "fitforecast_v2", "promotions",
  "independent_qdesn_cellwise_refinement_v2_superseded_closeout_20260930"
))
if (is.null(run_root)) stop("--run-root is required.", call. = FALSE)

source(file.path(
  repo_root, "validation", "fitforecast_v2", "R",
  "independent_qdesn_full_redesign_v2.R"
))
source(file.path(
  repo_root, "validation", "fitforecast_v2", "R",
  "independent_qdesn_full_redesign_v2_runtime.R"
))
source(file.path(
  repo_root, "validation", "fitforecast_v2", "R",
  "independent_qdesn_corrected_forecast_v3.R"
))
source(file.path(
  repo_root, "validation", "fitforecast_v2", "R",
  "independent_qdesn_cellwise_refinement_v2_superseded_closeout.R"
))

result <- iqcr_v2_superseded_closeout(
  repo_root = repo_root, run_root = run_root, output_dir = output_dir
)
print(result$stage_summary, row.names = FALSE)
cat("Closeout:", normalizePath(output_dir, winslash = "/", mustWork = TRUE),
    "\n")

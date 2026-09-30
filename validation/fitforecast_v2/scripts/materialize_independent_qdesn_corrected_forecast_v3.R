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
predecessor_run_root <- value("--predecessor-run-root")
allow_dirty <- "--allow-dirty" %in% args
if (is.null(run_root) || is.null(predecessor_run_root)) {
  stop("--run-root and --predecessor-run-root are required.", call. = FALSE)
}

for (path in c(
  "independent_qdesn_full_redesign_v2.R",
  "independent_qdesn_full_redesign_v2_runtime.R",
  "independent_qdesn_representation_screen_v1.R",
  "independent_qdesn_representation_screen_v1_runtime.R",
  "independent_qdesn_posterior_forecast_rescue_v1.R",
  "independent_qdesn_cellwise_refinement_v2.R",
  "independent_qdesn_cellwise_refinement_v2_superseded_closeout.R",
  "independent_qdesn_corrected_forecast_v3.R",
  "independent_qdesn_corrected_forecast_v3_campaign.R"
)) source(file.path(repo_root, "validation", "fitforecast_v2", "R", path))

out <- iqcf_v3_materialize(
  repo_root, run_root, predecessor_run_root, allow_dirty = allow_dirty
)
cat("Operator smoke jobs:", nrow(out$smoke_plan), "\n")
cat("Gated forecast-canary jobs:", nrow(out$canary_plan), "\n")
cat("Run root:", normalizePath(run_root, winslash = "/", mustWork = TRUE),
    "\n")

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
v3_run_root <- value("--v3-run-root")
predecessor_run_root <- value("--predecessor-run-root")
allow_dirty <- "--allow-dirty" %in% args
if (any(vapply(list(run_root, v3_run_root, predecessor_run_root), is.null,
               logical(1L)))) {
  stop("--run-root, --v3-run-root, and --predecessor-run-root are required.",
       call. = FALSE)
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
  "independent_qdesn_corrected_forecast_v3_campaign.R",
  "independent_qdesn_corrected_broad_v4.R"
)) source(file.path(repo_root, "validation", "fitforecast_v2", "R", path))
source(file.path(repo_root, "validation", "fitforecast_v2", "R", "utils.R"))
source(file.path(
  repo_root, "validation", "fitforecast_v2", "R",
  "independent_qdesn_fixed_comparator_stride1_v1.R"
))

out <- iqcb_v4_materialize(
  repo_root, run_root, v3_run_root, predecessor_run_root,
  allow_dirty = allow_dirty
)
cat("Operator-smoke jobs:", nrow(out$smoke_plan), "\n")
cat("Matched-comparator jobs:", nrow(out$comparator_plan), "\n")
cat("Gated broad-screen jobs:", nrow(out$broad_plan), "\n")
cat("Cells:", length(unique(out$candidates$cell_id)), "\n")
cat("Run root:", normalizePath(run_root, winslash = "/", mustWork = TRUE), "\n")

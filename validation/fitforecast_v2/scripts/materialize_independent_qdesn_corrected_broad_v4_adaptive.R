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
if (is.null(run_root)) stop("--run-root is required.", call. = FALSE)
for (path in c(
  "independent_qdesn_full_redesign_v2.R",
  "independent_qdesn_full_redesign_v2_runtime.R",
  "independent_qdesn_corrected_forecast_v3.R",
  "independent_qdesn_corrected_forecast_v3_campaign.R",
  "independent_qdesn_corrected_broad_v4.R"
)) source(file.path(repo_root, "validation", "fitforecast_v2", "R", path))
out <- iqcb_v4_materialize_adaptive(repo_root, run_root)
cat("Adaptive jobs:", nrow(out$plan), "\n")
cat("Automatic launch: disabled\n")

#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
value <- function(flag, default = NULL) {
  index <- match(flag, args)
  if (is.na(index) || index == length(args)) return(default)
  args[[index + 1L]]
}
run_root <- value("--run-root")
stage <- value("--stage")
repo_root <- normalizePath(
  value("--repo-root", system("git rev-parse --show-toplevel", intern = TRUE)),
  winslash = "/", mustWork = TRUE
)
if (is.null(run_root) || is.null(stage)) {
  stop("--run-root and --stage are required.", call. = FALSE)
}
for (path in c(
  "independent_qdesn_full_redesign_v2.R",
  "independent_qdesn_full_redesign_v2_runtime.R",
  "independent_qdesn_corrected_forecast_v3.R",
  "independent_qdesn_corrected_forecast_v3_campaign.R",
  "independent_qdesn_corrected_broad_v4.R"
)) source(file.path(repo_root, "validation", "fitforecast_v2", "R", path))

decision <- switch(
  stage,
  operator_smoke = iqcb_v4_audit_operator_smoke(run_root),
  development_comparator = iqcb_v4_audit_comparators(run_root),
  broad_screen = iqcb_v4_audit_broad(run_root),
  stop("Unsupported audit stage: ", stage, call. = FALSE)
)
cat("Decision:", decision$decision, "\n")

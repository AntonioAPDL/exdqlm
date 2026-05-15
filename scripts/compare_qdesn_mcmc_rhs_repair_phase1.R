#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("pkgload")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) && idx < length(args)) args[idx + 1L] else default
}
has_flag <- function(flag) any(args == flag)

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

baseline_report <- get_arg("--baseline-report", file.path(
  "reports", "qdesn_mcmc_validation", "phase1_compare_tuned", "20260314-183449__git-1ec79ff"
))
candidate_report <- get_arg("--candidate-report")
output_root <- get_arg("--output-root")

if (is.null(candidate_report) || is.null(output_root)) {
  stop("--candidate-report and --output-root are required.", call. = FALSE)
}

res <- exdqlm:::qdesn_validation_compare_campaign_reports(
  baseline_report_root = baseline_report,
  tuned_report_root = candidate_report,
  output_root = output_root,
  create_plots = !has_flag("--no-plots")
)

cat(sprintf("Comparison root: %s\n", res$output_root))

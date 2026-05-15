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

baseline_report <- get_arg("--baseline-report")
tuned_report <- get_arg("--tuned-report")
output_root <- get_arg("--output-root")

if (is.null(baseline_report) || is.null(tuned_report) || is.null(output_root)) {
  stop("--baseline-report, --tuned-report, and --output-root are required.", call. = FALSE)
}

res <- exdqlm:::qdesn_validation_compare_campaign_reports(
  baseline_report_root = baseline_report,
  tuned_report_root = tuned_report,
  output_root = output_root,
  create_plots = !has_flag("--no-plots")
)

cat(sprintf("Comparison root: %s\n", res$output_root))

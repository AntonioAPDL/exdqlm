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

results_root <- get_arg("--results-root")
reports_root <- get_arg("--reports-root")
if (is.null(results_root) || is.null(reports_root)) {
  stop("--results-root and --reports-root are required.", call. = FALSE)
}

res <- exdqlm:::qdesn_validation_collect_campaign(
  results_root = normalizePath(results_root, winslash = "/", mustWork = TRUE),
  report_root = normalizePath(reports_root, winslash = "/", mustWork = FALSE),
  create_plots = !has_flag("--no-plots")
)

cat(sprintf("Collected %d roots into %s\n", nrow(res$root_summary), res$report_root))

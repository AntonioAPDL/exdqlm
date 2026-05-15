#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("pkgload")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
has_flag <- function(flag) any(args == flag)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) && idx < length(args)) args[idx + 1L] else default
}

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)
`%||%` <- function(a, b) if (is.null(a)) b else a

defaults_path <- get_arg("--defaults", file.path("config", "validation", "qdesn_mcmc_compare_rhs_repair_defaults.yaml"))
grid_path <- get_arg("--grid", file.path("config", "validation", "qdesn_mcmc_compare_grid.csv"))
results_root <- get_arg("--results-root", NULL)
reports_root <- get_arg("--reports-root", NULL)
baseline_report <- get_arg("--baseline-report", file.path(
  "reports", "qdesn_mcmc_validation", "phase1_compare_tuned", "20260314-183449__git-1ec79ff"
))
compare_root <- get_arg("--compare-root", NULL)
root_filter <- get_arg("--root-id", "")
root_filter <- if (nzchar(root_filter)) trimws(strsplit(root_filter, ",", fixed = TRUE)[[1L]]) else NULL

run_res <- exdqlm:::qdesn_validation_run_campaign(
  grid_path = grid_path,
  defaults_path = defaults_path,
  results_root = results_root,
  report_root = reports_root,
  create_plots = !has_flag("--no-plots"),
  root_filter = root_filter,
  verbose = !has_flag("--quiet")
)

compare_root <- compare_root %||% file.path(
  "reports",
  "qdesn_mcmc_validation",
  "phase1_compare_rhs_repair_compare",
  paste0(basename(run_res$report_root), "__vs-phase1-tuned")
)

cmp_res <- exdqlm:::qdesn_validation_compare_campaign_reports(
  baseline_report_root = baseline_report,
  tuned_report_root = run_res$report_root,
  output_root = compare_root,
  create_plots = !has_flag("--no-plots")
)

cat(sprintf("Results root: %s\n", run_res$results_root))
cat(sprintf("Report root: %s\n", run_res$report_root))
cat(sprintf("Comparison root: %s\n", cmp_res$output_root))

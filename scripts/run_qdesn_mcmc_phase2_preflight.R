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

defaults_path <- get_arg("--defaults", file.path("config", "validation", "qdesn_mcmc_compare_phase2_defaults.yaml"))
grid_path <- get_arg("--grid", file.path("config", "validation", "qdesn_mcmc_compare_phase2_preflight_grid.csv"))
results_root <- get_arg("--results-root", NULL)
reports_root <- get_arg("--reports-root", NULL)

res <- exdqlm:::qdesn_validation_run_campaign(
  grid_path = grid_path,
  defaults_path = defaults_path,
  results_root = results_root,
  report_root = reports_root,
  create_plots = !has_flag("--no-plots"),
  verbose = !has_flag("--quiet")
)

cat(sprintf("Results root: %s\n", res$results_root))
cat(sprintf("Report root: %s\n", res$report_root))

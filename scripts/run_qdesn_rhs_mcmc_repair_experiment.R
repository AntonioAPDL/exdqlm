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

experiment_id <- get_arg("--experiment-id", NULL)
run_order <- get_arg("--run-order", NULL)
matrix_path <- get_arg("--matrix", file.path("config", "validation", "qdesn_rhs_mcmc_repair_matrix.csv"))
profiles_path <- get_arg("--profiles", file.path("config", "validation", "qdesn_rhs_mcmc_repair_profiles.yaml"))
results_root <- get_arg("--results-root", NULL)
reports_root <- get_arg("--reports-root", NULL)
vb_profile_override <- get_arg("--vb-profile-override", NULL)
freeze_tau_override <- get_arg("--freeze-tau-override", NULL)

res <- exdqlm:::qdesn_rhs_mcmc_repair_run_experiment(
  experiment_id = experiment_id,
  run_order = if (is.null(run_order)) NULL else as.integer(run_order)[1L],
  matrix_path = matrix_path,
  profiles_path = profiles_path,
  results_root = results_root,
  report_root = reports_root,
  vb_warm_start_profile_override = vb_profile_override,
  freeze_tau_burnin_iters_override = if (is.null(freeze_tau_override)) NULL else as.integer(freeze_tau_override)[1L],
  create_plots = !has_flag("--no-plots"),
  verbose = !has_flag("--quiet"),
  repo_root = repo_root
)

cat(sprintf("Experiment: %s\n", res$experiment_id))
cat(sprintf("Results root: %s\n", res$results_root))
cat(sprintf("Report root: %s\n", res$report_root))

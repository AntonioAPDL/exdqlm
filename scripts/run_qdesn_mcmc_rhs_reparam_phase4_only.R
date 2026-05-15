#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("pkgload", "yaml")
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
stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
git_sha <- exdqlm:::.qdesn_validation_git_sha()
run_stub <- paste0(stamp, "__git-", git_sha)

defaults_path <- get_arg(
  "--defaults",
  file.path("config", "validation", "qdesn_mcmc_compare_rhs_structural_reparam_candidate_best.yaml")
)
rep_grid <- get_arg(
  "--rep-grid",
  file.path("config", "validation", "qdesn_mcmc_multichain_representative_rhs_grid.csv")
)
freeze_tau <- as.integer(get_arg("--freeze-tau", 25L))[1L]
results_root <- get_arg(
  "--results-root",
  file.path("results", "qdesn_mcmc_validation", "rhs_reparam_phase4_rerun", run_stub)
)
reports_root <- get_arg(
  "--reports-root",
  file.path("reports", "qdesn_mcmc_validation", "rhs_reparam_phase4_rerun", run_stub)
)
create_plots <- !has_flag("--no-plots")
verbose <- !has_flag("--quiet")

defaults <- exdqlm:::qdesn_validation_load_defaults(defaults_path)
defaults$pipeline$inference$mcmc$prior_overrides$rhs$rhs$freeze_tau_burnin_iters <- freeze_tau
defaults$pipeline$inference$mcmc$prior_overrides$rhs$rhs$freeze_tau_only_during_burn <- TRUE

cat(sprintf("Phase 4 rerun: freeze_tau_burnin_iters=%d\n", freeze_tau))
cat(sprintf("Results root: %s\n", results_root))
cat(sprintf("Reports root: %s\n", reports_root))

tmp_defaults <- tempfile(pattern = "reparam-phase4-", fileext = ".yaml")
yaml::write_yaml(defaults, tmp_defaults)

exdqlm:::qdesn_validation_run_multichain_campaign(
  grid_path = rep_grid,
  defaults = defaults,
  defaults_path = tmp_defaults,
  results_root = results_root,
  report_root = reports_root,
  create_plots = create_plots,
  verbose = verbose
)

file.copy(tmp_defaults, file.path(reports_root, "manifest", "materialized_defaults.yaml"), overwrite = TRUE)
cat("Phase 4 rerun completed.\n")

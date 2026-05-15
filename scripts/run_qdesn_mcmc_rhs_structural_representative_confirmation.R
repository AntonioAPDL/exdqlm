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

defaults_path <- get_arg("--defaults", file.path("config", "validation", "qdesn_mcmc_compare_rhs_structural_defaults.yaml"))
grid_path <- get_arg("--grid", file.path("config", "validation", "qdesn_mcmc_multichain_representative_rhs_grid.csv"))
results_root <- get_arg("--results-root", file.path("results", "qdesn_mcmc_validation", "multichain_confirmation_rhs_structural"))
reports_root <- get_arg("--reports-root", file.path("reports", "qdesn_mcmc_validation", "multichain_confirmation_rhs_structural"))
decision_root <- get_arg("--decision-root", file.path(reports_root, "decision"))
n_chains <- as.integer(get_arg("--n-chains", "4"))[1L]
chain_seed_base <- as.integer(get_arg("--chain-seed-base", "500000"))[1L]
create_plots <- !has_flag("--no-plots")
verbose <- !has_flag("--quiet")

res <- exdqlm:::qdesn_validation_run_multichain_campaign(
  grid_path = grid_path,
  defaults_path = defaults_path,
  results_root = results_root,
  report_root = reports_root,
  n_chains = n_chains,
  chain_seed_base = chain_seed_base,
  create_plots = create_plots,
  verbose = verbose
)

decision <- exdqlm:::qdesn_validation_assess_multichain_followup(
  multichain_report_root = reports_root,
  output_root = decision_root
)

manifest_root <- file.path(reports_root, "confirmation_followup")
exdqlm:::.qdesn_validation_dir_create(manifest_root)
exdqlm:::.qdesn_validation_write_json(file.path(manifest_root, "manifest.json"), list(
  defaults_path = normalizePath(defaults_path, winslash = "/", mustWork = TRUE),
  grid_path = normalizePath(grid_path, winslash = "/", mustWork = TRUE),
  results_root = normalizePath(results_root, winslash = "/", mustWork = FALSE),
  report_root = normalizePath(reports_root, winslash = "/", mustWork = FALSE),
  decision_root = normalizePath(decision_root, winslash = "/", mustWork = FALSE),
  decision_mode = decision$decision_mode,
  n_chains = n_chains,
  chain_seed_base = chain_seed_base,
  generated_at = as.character(Sys.time()),
  git_sha = exdqlm:::.qdesn_validation_git_sha()
))

cat(sprintf("Results root: %s\n", normalizePath(results_root, winslash = "/", mustWork = FALSE)))
cat(sprintf("Report root: %s\n", normalizePath(reports_root, winslash = "/", mustWork = FALSE)))
cat(sprintf("Decision root: %s\n", normalizePath(decision_root, winslash = "/", mustWork = FALSE)))
cat(sprintf("Decision mode: %s\n", decision$decision_mode))

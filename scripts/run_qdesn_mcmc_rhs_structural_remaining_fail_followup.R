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
grid_path <- get_arg("--grid", file.path("config", "validation", "qdesn_mcmc_multichain_remaining_rhs_fail_grid.csv"))
results_root <- get_arg("--results-root", file.path("results", "qdesn_mcmc_validation", "multichain_confirmation_rhs_structural_remaining_fail"))
reports_root <- get_arg("--reports-root", file.path("reports", "qdesn_mcmc_validation", "multichain_confirmation_rhs_structural_remaining_fail"))
decision_root <- get_arg("--decision-root", file.path(reports_root, "decision"))
n_chains <- as.integer(get_arg("--n-chains", "4"))[1L]
chain_seed_base <- as.integer(get_arg("--chain-seed-base", "500000"))[1L]
create_plots <- !has_flag("--no-plots")
verbose <- !has_flag("--quiet")

defaults <- exdqlm:::qdesn_validation_load_defaults(defaults_path)
defaults$campaign <- defaults$campaign %||% list()
defaults$campaign$name <- "qdesn_mcmc_rhs_structural_remaining_fail_followup"
defaults$campaign$results_root <- results_root
defaults$campaign$reports_root <- reports_root

defaults$pipeline <- defaults$pipeline %||% list()
defaults$pipeline$inference <- defaults$pipeline$inference %||% list()
defaults$pipeline$inference$mcmc <- defaults$pipeline$inference$mcmc %||% list()
defaults$pipeline$inference$mcmc$prior_overrides <- defaults$pipeline$inference$mcmc$prior_overrides %||% list()
defaults$pipeline$inference$mcmc$prior_overrides$rhs <- modifyList(
  defaults$pipeline$inference$mcmc$prior_overrides$rhs %||% list(),
  list(
    n_burn = 1000L,
    n_mcmc = 2000L,
    progress_every = 250L,
    slice = list(
      width_rhs_c2 = 0.18,
      width_rhs_tau_c2_block = 0.70
    )
  )
)

res <- exdqlm:::qdesn_validation_run_multichain_campaign(
  grid_path = grid_path,
  defaults = defaults,
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

override_root <- file.path(reports_root, "override_manifest")
exdqlm:::.qdesn_validation_dir_create(override_root)
exdqlm:::.qdesn_validation_write_json(file.path(override_root, "manifest.json"), list(
  base_defaults_path = normalizePath(defaults_path, winslash = "/", mustWork = TRUE),
  grid_path = normalizePath(grid_path, winslash = "/", mustWork = TRUE),
  overrides = list(
    rhs = list(
      n_burn = 1000L,
      n_mcmc = 2000L,
      progress_every = 250L,
      width_rhs_c2 = 0.18,
      width_rhs_tau_c2_block = 0.70
    )
  ),
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

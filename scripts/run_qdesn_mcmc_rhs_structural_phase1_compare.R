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
grid_path <- get_arg("--grid", file.path("config", "validation", "qdesn_mcmc_compare_grid.csv"))
baseline_report <- get_arg("--baseline-report", file.path(
  "reports", "qdesn_mcmc_validation", "phase1_compare_rhs_repair", "20260315-001336__git-a343eb6"
))
representative_grid <- get_arg("--representative-grid", file.path("config", "validation", "qdesn_mcmc_multichain_representative_rhs_grid.csv"))
results_root <- get_arg("--results-root", NULL)
reports_root <- get_arg("--reports-root", NULL)
compare_root <- get_arg("--compare-root", NULL)
decision_root <- get_arg("--decision-root", NULL)
multichain_results_root <- get_arg("--multichain-results-root", NULL)
multichain_reports_root <- get_arg("--multichain-reports-root", NULL)
root_filter <- get_arg("--root-id", "")
root_filter <- if (nzchar(root_filter)) trimws(strsplit(root_filter, ",", fixed = TRUE)[[1L]]) else NULL
n_chains <- as.integer(get_arg("--n-chains", "4"))[1L]
chain_seed_base <- as.integer(get_arg("--chain-seed-base", "500000"))[1L]
create_plots <- !has_flag("--no-plots")
verbose <- !has_flag("--quiet")

run_res <- exdqlm:::qdesn_validation_run_campaign(
  grid_path = grid_path,
  defaults_path = defaults_path,
  results_root = results_root,
  report_root = reports_root,
  create_plots = create_plots,
  root_filter = root_filter,
  verbose = verbose
)

compare_root <- compare_root %||% file.path(
  "reports",
  "qdesn_mcmc_validation",
  "phase1_compare_rhs_structural_compare",
  paste0(basename(run_res$report_root), "__vs-phase1-rhs-repair")
)

cmp_res <- exdqlm:::qdesn_validation_compare_campaign_reports(
  baseline_report_root = baseline_report,
  tuned_report_root = run_res$report_root,
  output_root = compare_root,
  create_plots = create_plots
)

decision_root <- decision_root %||% file.path(compare_root, "decision")
decision <- exdqlm:::qdesn_validation_assess_rhs_repair_candidate(
  candidate_report_root = run_res$report_root,
  baseline_report_root = baseline_report,
  output_root = decision_root
)

multichain_report_root <- NA_character_
multichain_results_root <- NA_character_
if (identical(decision$decision_mode, "representative")) {
  multichain_results_root <- multichain_results_root %||% file.path(
    "results", "qdesn_mcmc_validation", "multichain_confirmation_rhs_structural"
  )
  multichain_reports_root <- multichain_reports_root %||% file.path(
    "reports", "qdesn_mcmc_validation", "multichain_confirmation_rhs_structural"
  )
  exdqlm:::qdesn_validation_run_multichain_campaign(
    grid_path = representative_grid,
    defaults_path = defaults_path,
    results_root = multichain_results_root,
    report_root = multichain_reports_root,
    n_chains = n_chains,
    chain_seed_base = chain_seed_base,
    create_plots = create_plots,
    verbose = verbose
  )
  multichain_results_root <- normalizePath(multichain_results_root, winslash = "/", mustWork = FALSE)
  multichain_report_root <- normalizePath(multichain_reports_root, winslash = "/", mustWork = FALSE)
} else {
  multichain_reports_root <- NA_character_
}

summary_root <- file.path(compare_root, "structural_followup")
exdqlm:::.qdesn_validation_dir_create(summary_root)
exdqlm:::.qdesn_validation_write_json(file.path(summary_root, "manifest.json"), list(
  defaults_path = normalizePath(defaults_path, winslash = "/", mustWork = TRUE),
  grid_path = normalizePath(grid_path, winslash = "/", mustWork = TRUE),
  baseline_report_root = normalizePath(baseline_report, winslash = "/", mustWork = TRUE),
  candidate_report_root = normalizePath(run_res$report_root, winslash = "/", mustWork = TRUE),
  comparison_root = normalizePath(cmp_res$output_root, winslash = "/", mustWork = TRUE),
  decision_root = normalizePath(decision_root, winslash = "/", mustWork = TRUE),
  decision_mode = decision$decision_mode,
  representative_grid = if (identical(decision$decision_mode, "representative")) normalizePath(representative_grid, winslash = "/", mustWork = TRUE) else NA_character_,
  multichain_results_root = multichain_results_root,
  multichain_report_root = multichain_report_root,
  generated_at = as.character(Sys.time()),
  git_sha = exdqlm:::.qdesn_validation_git_sha()
))

cat(sprintf("Results root: %s\n", run_res$results_root))
cat(sprintf("Report root: %s\n", run_res$report_root))
cat(sprintf("Comparison root: %s\n", cmp_res$output_root))
cat(sprintf("Decision mode: %s\n", decision$decision_mode))
if (!is.na(multichain_report_root)) cat(sprintf("Representative multichain report root: %s\n", multichain_report_root))

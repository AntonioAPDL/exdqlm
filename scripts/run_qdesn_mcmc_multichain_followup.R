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

mode <- get_arg("--mode", "auto")
defaults_path <- get_arg("--defaults", file.path("config", "validation", "qdesn_mcmc_compare_rhs_repair_defaults.yaml"))
baseline_report <- get_arg("--baseline-report", file.path("reports", "qdesn_mcmc_validation", "phase1_compare_tuned", "20260314-183449__git-1ec79ff"))
candidate_report <- get_arg("--candidate-report", file.path("reports", "qdesn_mcmc_validation", "phase1_compare_rhs_repair", "20260315-001336__git-a343eb6"))
representative_grid <- get_arg("--representative-grid", file.path("config", "validation", "qdesn_mcmc_multichain_representative_grid.csv"))
failure_grid_fallback <- get_arg("--failure-grid-fallback", file.path("config", "validation", "qdesn_mcmc_rhs_failure_grid.csv"))
n_chains <- as.integer(get_arg("--n-chains", "4"))[1L]
chain_seed_base <- as.integer(get_arg("--chain-seed-base", "500000"))[1L]
analysis_root <- get_arg("--analysis-root", NULL)
results_root <- get_arg("--results-root", NULL)
reports_root <- get_arg("--reports-root", NULL)
create_plots <- !has_flag("--no-plots")
verbose <- !has_flag("--quiet")

candidate_report <- normalizePath(candidate_report, winslash = "/", mustWork = TRUE)
baseline_report <- normalizePath(baseline_report, winslash = "/", mustWork = TRUE)

run_stub <- paste0(format(Sys.time(), "%Y%m%d-%H%M%S"), "__git-", exdqlm:::.qdesn_validation_git_sha())
analysis_root <- analysis_root %||% file.path("reports", "qdesn_mcmc_validation", "multichain_followup_decision", run_stub)
analysis_root <- normalizePath(analysis_root, winslash = "/", mustWork = FALSE)
exdqlm:::.qdesn_validation_dir_create(analysis_root)

decision <- if (identical(mode, "auto")) {
  exdqlm:::qdesn_validation_assess_rhs_repair_candidate(
    candidate_report_root = candidate_report,
    baseline_report_root = baseline_report,
    output_root = analysis_root
  )
} else {
  list(
    decision_mode = mode,
    decision_reason = sprintf("explicit mode '%s' requested", mode),
    output_root = analysis_root
  )
}

selected_mode <- as.character(decision$decision_mode)[1L]
if (!selected_mode %in% c("representative", "candidate_failures")) {
  stop(sprintf("Unsupported multichain follow-up mode: %s", selected_mode), call. = FALSE)
}

grid_path <- if (identical(selected_mode, "representative")) {
  normalizePath(representative_grid, winslash = "/", mustWork = TRUE)
} else {
  out_grid <- file.path(analysis_root, "candidate_failed_rhs_grid.csv")
  exdqlm:::qdesn_validation_extract_failed_rhs_grid(
    candidate_report_root = candidate_report,
    output_path = out_grid,
    fallback_grid_path = failure_grid_fallback
  )
}

results_root <- results_root %||% file.path("results", "qdesn_mcmc_validation", if (identical(selected_mode, "representative")) "multichain_confirmation" else "multichain_failure_triage")
reports_root <- reports_root %||% file.path("reports", "qdesn_mcmc_validation", if (identical(selected_mode, "representative")) "multichain_confirmation" else "multichain_failure_triage")
results_run_root <- file.path(results_root, run_stub)
reports_run_root <- file.path(reports_root, run_stub)

res <- exdqlm:::qdesn_validation_run_multichain_campaign(
  grid_path = grid_path,
  defaults_path = defaults_path,
  results_root = results_run_root,
  report_root = reports_run_root,
  n_chains = n_chains,
  chain_seed_base = chain_seed_base,
  create_plots = create_plots,
  verbose = verbose
)

exdqlm:::.qdesn_validation_write_json(file.path(analysis_root, "followup_manifest.json"), list(
  decision_mode = selected_mode,
  decision_reason = decision$decision_reason %||% "",
  candidate_report_root = candidate_report,
  baseline_report_root = baseline_report,
  defaults_path = normalizePath(defaults_path, winslash = "/", mustWork = TRUE),
  grid_path = normalizePath(grid_path, winslash = "/", mustWork = TRUE),
  results_root = normalizePath(results_run_root, winslash = "/", mustWork = FALSE),
  report_root = normalizePath(reports_run_root, winslash = "/", mustWork = FALSE),
  n_chains = n_chains,
  chain_seed_base = chain_seed_base,
  generated_at = as.character(Sys.time())
))

cat(sprintf("Decision mode: %s\n", selected_mode))
cat(sprintf("Decision root: %s\n", analysis_root))
cat(sprintf("Grid path: %s\n", normalizePath(grid_path, winslash = "/", mustWork = TRUE)))
cat(sprintf("Results root: %s\n", normalizePath(results_run_root, winslash = "/", mustWork = FALSE)))
cat(sprintf("Report root: %s\n", normalizePath(reports_run_root, winslash = "/", mustWork = FALSE)))

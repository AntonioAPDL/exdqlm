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
fail_grid <- get_arg(
  "--fail-grid",
  file.path("config", "validation", "qdesn_mcmc_multichain_rhs_fail_reparam_grid.csv")
)
rep_grid <- get_arg(
  "--rep-grid",
  file.path("config", "validation", "qdesn_mcmc_multichain_representative_rhs_grid.csv")
)
analysis_root <- get_arg(
  "--analysis-root",
  file.path("reports", "qdesn_mcmc_validation", "rhs_reparam_phase3_phase4", run_stub)
)
analysis_root <- normalizePath(analysis_root, winslash = "/", mustWork = FALSE)
create_plots <- !has_flag("--no-plots")
verbose <- !has_flag("--quiet")

dir_create <- exdqlm:::.qdesn_validation_dir_create
write_json <- exdqlm:::.qdesn_validation_write_json
write_df <- exdqlm:::.qdesn_validation_write_df

dir_create(analysis_root)
dir_create(file.path(analysis_root, "manifest"))
dir_create(file.path(analysis_root, "tables"))

base_defaults <- exdqlm:::qdesn_validation_load_defaults(defaults_path)

run_multichain <- function(defaults, grid_path, results_root, report_root, create_plots = TRUE, verbose = TRUE) {
  tmp_defaults <- tempfile(pattern = "reparam-defaults-", fileext = ".yaml")
  yaml::write_yaml(defaults, tmp_defaults)
  res <- exdqlm:::qdesn_validation_run_multichain_campaign(
    grid_path = grid_path,
    defaults = defaults,
    defaults_path = tmp_defaults,
    results_root = results_root,
    report_root = report_root,
    create_plots = create_plots,
    verbose = verbose
  )
  file.copy(tmp_defaults, file.path(report_root, "manifest", "materialized_defaults.yaml"), overwrite = TRUE)
  res
}

summarize_report <- function(report_root) {
  confirm <- exdqlm:::.qdesn_validation_read_report_csv(report_root, "campaign_root_confirmation.csv")
  if (!nrow(confirm)) {
    return(data.frame(
      report_root = report_root,
      n_roots = 0,
      n_fail = NA_integer_,
      n_warn = NA_integer_,
      n_pass = NA_integer_,
      max_split_rhat = NA_real_,
      stringsAsFactors = FALSE
    ))
  }
  data.frame(
    report_root = report_root,
    n_roots = nrow(confirm),
    n_fail = sum(confirm$confirmation_grade == "FAIL", na.rm = TRUE),
    n_warn = sum(confirm$confirmation_grade == "WARN", na.rm = TRUE),
    n_pass = sum(confirm$confirmation_grade == "PASS", na.rm = TRUE),
    max_split_rhat = max(confirm$max_split_rhat, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}

pick_best <- function(summary_df) {
  if (!nrow(summary_df)) return(NULL)
  ord <- do.call(order, list(
    summary_df$n_fail,
    summary_df$n_warn,
    summary_df$max_split_rhat,
    summary_df$report_root
  ))
  summary_df[ord, , drop = FALSE][1L, , drop = FALSE]
}

cat(sprintf("Analysis root: %s\n", analysis_root))
cat(sprintf("Defaults: %s\n", defaults_path))
cat(sprintf("Fail-grid: %s\n", fail_grid))
cat(sprintf("Representative grid: %s\n", rep_grid))

# ---- Phase 3: tau warm-freeze sweep ----
cat("Phase 3: tau warm-freeze sweep...\n")
phase3_freeze <- c(25L, 50L)
phase3_summaries <- list()
phase3_reports <- character(length(phase3_freeze))

for (ii in seq_along(phase3_freeze)) {
  freeze_iters <- phase3_freeze[[ii]]
  cand_id <- sprintf("p3_taufreeze_%02d", freeze_iters)
  cand_defaults <- base_defaults
  cand_defaults$pipeline$inference$mcmc$prior_overrides$rhs$rhs$freeze_tau_burnin_iters <- as.integer(freeze_iters)
  cand_defaults$pipeline$inference$mcmc$prior_overrides$rhs$rhs$freeze_tau_only_during_burn <- TRUE

  cand_results <- file.path("results", "qdesn_mcmc_validation", "rhs_reparam_phase3", run_stub, cand_id)
  cand_report <- file.path("reports", "qdesn_mcmc_validation", "rhs_reparam_phase3", run_stub, cand_id)
  dir_create(cand_results)
  dir_create(cand_report)

  cat(sprintf("Phase 3 candidate %s: freeze_tau_burnin_iters=%d\n", cand_id, freeze_iters))
  run_multichain(
    defaults = cand_defaults,
    grid_path = fail_grid,
    results_root = cand_results,
    report_root = cand_report,
    create_plots = create_plots,
    verbose = verbose
  )
  phase3_reports[[ii]] <- cand_report
  summary_i <- summarize_report(cand_report)
  summary_i$candidate_id <- cand_id
  summary_i$freeze_tau_burnin_iters <- freeze_iters
  phase3_summaries[[ii]] <- summary_i
}
phase3_summary <- do.call(rbind, phase3_summaries)
write_df(phase3_summary, file.path(analysis_root, "tables", "phase3_summary.csv"))
best_phase3 <- pick_best(phase3_summary)
write_json(file.path(analysis_root, "manifest", "phase3_best.json"), best_phase3[1L, , drop = FALSE])

# ---- Phase 4: representative confirmation ----
cat("Phase 4: representative confirmation...\n")
final_defaults <- base_defaults
if (!is.null(best_phase3) && nrow(best_phase3)) {
  final_defaults$pipeline$inference$mcmc$prior_overrides$rhs$rhs$freeze_tau_burnin_iters <- as.integer(best_phase3$freeze_tau_burnin_iters %||% 0L)
  final_defaults$pipeline$inference$mcmc$prior_overrides$rhs$rhs$freeze_tau_only_during_burn <- TRUE
}

phase4_results <- file.path("results", "qdesn_mcmc_validation", "rhs_reparam_phase4", run_stub)
phase4_report <- file.path("reports", "qdesn_mcmc_validation", "rhs_reparam_phase4", run_stub)
dir_create(phase4_results)
dir_create(phase4_report)
run_multichain(
  defaults = final_defaults,
  grid_path = rep_grid,
  results_root = phase4_results,
  report_root = phase4_report,
  create_plots = create_plots,
  verbose = verbose
)
phase4_summary <- summarize_report(phase4_report)
write_df(phase4_summary, file.path(analysis_root, "tables", "phase4_summary.csv"))

write_json(file.path(analysis_root, "manifest", "phase3_phase4_manifest.json"), list(
  generated_at = as.character(Sys.time()),
  defaults_path = normalizePath(defaults_path, winslash = "/", mustWork = TRUE),
  fail_grid = normalizePath(fail_grid, winslash = "/", mustWork = TRUE),
  rep_grid = normalizePath(rep_grid, winslash = "/", mustWork = TRUE),
  phase3_reports = normalizePath(phase3_reports, winslash = "/", mustWork = TRUE),
  phase4_report = normalizePath(phase4_report, winslash = "/", mustWork = TRUE)
))

cat("Phase 3+4 completed.\n")
cat(sprintf("Phase 4 report: %s\n", phase4_report))

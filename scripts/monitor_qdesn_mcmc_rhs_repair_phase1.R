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

candidate_report <- get_arg("--candidate-report", file.path("reports", "qdesn_mcmc_validation", "phase1_compare_rhs_repair", "20260315-001336__git-a343eb6"))
baseline_report <- get_arg("--baseline-report", file.path("reports", "qdesn_mcmc_validation", "phase1_compare_tuned", "20260314-183449__git-1ec79ff"))
poll_seconds <- max(10L, as.integer(get_arg("--poll-seconds", "600"))[1L])
monitor_root <- get_arg("--monitor-root", NULL)
auto_followup <- !has_flag("--no-followup")
followup_n_chains <- as.integer(get_arg("--followup-n-chains", "4"))[1L]
followup_chain_seed_base <- as.integer(get_arg("--followup-chain-seed-base", "500000"))[1L]
create_plots <- !has_flag("--no-plots")

candidate_report <- normalizePath(candidate_report, winslash = "/", mustWork = TRUE)
baseline_report <- normalizePath(baseline_report, winslash = "/", mustWork = TRUE)
monitor_root <- monitor_root %||% file.path("reports", "qdesn_mcmc_validation", "phase1_compare_rhs_repair_monitor", basename(candidate_report))
monitor_root <- normalizePath(monitor_root, winslash = "/", mustWork = FALSE)
for (d in c(monitor_root, file.path(monitor_root, "tables"), file.path(monitor_root, "manifest"))) {
  exdqlm:::.qdesn_validation_dir_create(d)
}

progress_path <- file.path(candidate_report, "tables", "campaign_progress.csv")
completed_path <- file.path(candidate_report, "manifest", "campaign_completed.json")
status_rows <- list()

repeat {
  progress_df <- if (file.exists(progress_path)) utils::read.csv(progress_path, stringsAsFactors = FALSE) else data.frame(stringsAsFactors = FALSE)
  row <- data.frame(
    checked_at = as.character(Sys.time()),
    completed_roots = nrow(progress_df),
    pair_eligible_roots = if (nrow(progress_df) && "pair_comparison_eligible" %in% names(progress_df)) sum(as.logical(progress_df$pair_comparison_eligible), na.rm = TRUE) else 0L,
    rhs_mcmc_fail_roots = if (nrow(progress_df)) sum(progress_df$beta_prior_type == "rhs" & progress_df$mcmc_signoff_grade == "FAIL", na.rm = TRUE) else 0L,
    ridge_mcmc_fail_roots = if (nrow(progress_df)) sum(progress_df$beta_prior_type == "ridge" & progress_df$mcmc_signoff_grade == "FAIL", na.rm = TRUE) else 0L,
    campaign_completed = file.exists(completed_path),
    stringsAsFactors = FALSE
  )
  status_rows[[length(status_rows) + 1L]] <- row
  exdqlm:::.qdesn_validation_write_df(exdqlm:::.qdesn_validation_bind_rows(status_rows), file.path(monitor_root, "tables", "monitor_status.csv"))
  if (file.exists(completed_path)) break
  Sys.sleep(poll_seconds)
}

compare_root <- file.path("reports", "qdesn_mcmc_validation", "phase1_compare_rhs_repair_compare", paste0(basename(candidate_report), "__auto-vs-phase1-tuned"))
cmp_res <- exdqlm:::qdesn_validation_compare_campaign_reports(
  baseline_report_root = baseline_report,
  tuned_report_root = candidate_report,
  output_root = compare_root,
  create_plots = create_plots
)

decision <- exdqlm:::qdesn_validation_assess_rhs_repair_candidate(
  candidate_report_root = candidate_report,
  baseline_report_root = baseline_report,
  output_root = file.path(monitor_root, "decision")
)

exdqlm:::.qdesn_validation_write_json(file.path(monitor_root, "manifest", "monitor_manifest.json"), list(
  candidate_report_root = candidate_report,
  baseline_report_root = baseline_report,
  compare_root = cmp_res$output_root,
  decision_mode = decision$decision_mode,
  decision_reason = decision$decision_reason,
  auto_followup = auto_followup,
  finished_at = as.character(Sys.time())
))

if (isTRUE(auto_followup)) {
  followup_analysis_root <- file.path(monitor_root, "followup")
  exdqlm:::.qdesn_validation_dir_create(followup_analysis_root)
  followup_stub <- paste0(format(Sys.time(), "%Y%m%d-%H%M%S"), "__git-", exdqlm:::.qdesn_validation_git_sha())
  exdqlm:::qdesn_validation_run_multichain_campaign(
    grid_path = if (identical(decision$decision_mode, "representative")) {
      file.path("config", "validation", "qdesn_mcmc_multichain_representative_grid.csv")
    } else {
      exdqlm:::qdesn_validation_extract_failed_rhs_grid(
        candidate_report_root = candidate_report,
        output_path = file.path(followup_analysis_root, "candidate_failed_rhs_grid.csv"),
        fallback_grid_path = file.path("config", "validation", "qdesn_mcmc_rhs_failure_grid.csv")
      )
    },
    defaults_path = file.path("config", "validation", "qdesn_mcmc_compare_rhs_repair_defaults.yaml"),
    results_root = file.path("results", "qdesn_mcmc_validation", if (identical(decision$decision_mode, "representative")) "multichain_confirmation" else "multichain_failure_triage", followup_stub),
    report_root = file.path("reports", "qdesn_mcmc_validation", if (identical(decision$decision_mode, "representative")) "multichain_confirmation" else "multichain_failure_triage", followup_stub),
    n_chains = followup_n_chains,
    chain_seed_base = followup_chain_seed_base,
    create_plots = create_plots,
    verbose = FALSE
  )
}

cat(sprintf("Monitor root: %s\n", monitor_root))
cat(sprintf("Compare root: %s\n", cmp_res$output_root))
cat(sprintf("Decision mode: %s\n", decision$decision_mode))

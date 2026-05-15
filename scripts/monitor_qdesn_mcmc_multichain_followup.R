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

report_root <- get_arg("--report-root", NULL)
results_root <- get_arg("--results-root", NULL)
defaults_path <- get_arg("--defaults", file.path("config", "validation", "qdesn_mcmc_compare_rhs_repair_defaults.yaml"))
representative_grid <- get_arg("--representative-grid", file.path("config", "validation", "qdesn_mcmc_multichain_representative_grid.csv"))
poll_seconds <- max(10L, as.integer(get_arg("--poll-seconds", "600"))[1L])
monitor_root <- get_arg("--monitor-root", NULL)
create_plots <- !has_flag("--no-plots")
auto_followup <- !has_flag("--no-followup")
n_chains <- as.integer(get_arg("--n-chains", "4"))[1L]
chain_seed_base <- as.integer(get_arg("--chain-seed-base", "500000"))[1L]

if (is.null(report_root) || is.null(results_root)) {
  stop("--report-root and --results-root are required.", call. = FALSE)
}

report_root <- normalizePath(report_root, winslash = "/", mustWork = TRUE)
results_root <- normalizePath(results_root, winslash = "/", mustWork = TRUE)
monitor_root <- monitor_root %||% file.path("reports", "qdesn_mcmc_validation", "multichain_followup_monitor", basename(report_root))
monitor_root <- normalizePath(monitor_root, winslash = "/", mustWork = FALSE)
for (d in c(monitor_root, file.path(monitor_root, "tables"), file.path(monitor_root, "manifest"))) {
  exdqlm:::.qdesn_validation_dir_create(d)
}

progress_path <- file.path(report_root, "tables", "campaign_progress.csv")
confirm_path <- file.path(report_root, "tables", "campaign_root_confirmation.csv")
rhat_path <- file.path(report_root, "tables", "campaign_multichain_rhat.csv")
completed_path <- file.path(report_root, "manifest", "campaign_completed.json")
status_rows <- list()

repeat {
  progress_df <- if (file.exists(progress_path)) utils::read.csv(progress_path, stringsAsFactors = FALSE) else data.frame(stringsAsFactors = FALSE)
  confirm_df <- if (file.exists(confirm_path)) utils::read.csv(confirm_path, stringsAsFactors = FALSE) else data.frame(stringsAsFactors = FALSE)
  rhat_df <- if (file.exists(rhat_path)) utils::read.csv(rhat_path, stringsAsFactors = FALSE) else data.frame(stringsAsFactors = FALSE)

  row <- data.frame(
    checked_at = as.character(Sys.time()),
    completed_roots = if (nrow(confirm_df)) nrow(confirm_df) else nrow(progress_df),
    n_confirmation_pass = if (nrow(confirm_df)) sum(confirm_df$confirmation_grade == "PASS", na.rm = TRUE) else 0L,
    n_confirmation_warn = if (nrow(confirm_df)) sum(confirm_df$confirmation_grade == "WARN", na.rm = TRUE) else 0L,
    n_confirmation_fail = if (nrow(confirm_df)) sum(confirm_df$confirmation_grade == "FAIL", na.rm = TRUE) else 0L,
    rhs_tau025_fail_roots = if (nrow(confirm_df)) sum(confirm_df$beta_prior_type == "rhs" & abs(confirm_df$tau - 0.25) < 1e-12 & confirm_df$confirmation_grade == "FAIL", na.rm = TRUE) else 0L,
    max_split_rhat = if (nrow(rhat_df)) suppressWarnings(max(rhat_df$rhat, na.rm = TRUE)) else NA_real_,
    campaign_completed = file.exists(completed_path),
    stringsAsFactors = FALSE
  )
  if (!is.finite(row$max_split_rhat[1L])) row$max_split_rhat[1L] <- NA_real_
  status_rows[[length(status_rows) + 1L]] <- row
  exdqlm:::.qdesn_validation_write_df(exdqlm:::.qdesn_validation_bind_rows(status_rows), file.path(monitor_root, "tables", "monitor_status.csv"))
  if (file.exists(completed_path)) break
  Sys.sleep(poll_seconds)
}

decision <- exdqlm:::qdesn_validation_assess_multichain_followup(
  multichain_report_root = report_root,
  output_root = file.path(monitor_root, "decision")
)

next_action <- decision$decision_mode
next_root <- NA_character_
if (isTRUE(auto_followup) && identical(next_action, "representative_confirmation")) {
  run_stub <- paste0(format(Sys.time(), "%Y%m%d-%H%M%S"), "__git-", exdqlm:::.qdesn_validation_git_sha())
  next_results <- file.path("results", "qdesn_mcmc_validation", "multichain_confirmation_representative", run_stub)
  next_report <- file.path("reports", "qdesn_mcmc_validation", "multichain_confirmation_representative", run_stub)
  exdqlm:::qdesn_validation_run_multichain_campaign(
    grid_path = representative_grid,
    defaults_path = defaults_path,
    results_root = next_results,
    report_root = next_report,
    n_chains = n_chains,
    chain_seed_base = chain_seed_base,
    create_plots = create_plots,
    verbose = FALSE
  )
  next_root <- normalizePath(next_report, winslash = "/", mustWork = FALSE)
} else if (identical(next_action, "structural_rhs_repair")) {
  still_failed_grid <- file.path(monitor_root, "still_failed_rhs_grid.csv")
  exdqlm:::qdesn_validation_extract_multichain_failed_rhs_grid(
    multichain_report_root = report_root,
    output_path = still_failed_grid
  )
  next_root <- normalizePath(still_failed_grid, winslash = "/", mustWork = FALSE)
}

exdqlm:::.qdesn_validation_write_json(file.path(monitor_root, "manifest", "monitor_manifest.json"), list(
  report_root = report_root,
  results_root = results_root,
  decision_mode = decision$decision_mode,
  decision_reason = decision$decision_reason,
  auto_followup = auto_followup,
  next_artifact = next_root,
  finished_at = as.character(Sys.time())
))

cat(sprintf("Monitor root: %s\n", monitor_root))
cat(sprintf("Decision mode: %s\n", decision$decision_mode))
cat(sprintf("Next artifact: %s\n", next_root %||% ""))

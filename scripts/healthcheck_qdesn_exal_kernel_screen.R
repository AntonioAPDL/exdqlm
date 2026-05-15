#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) && idx < length(args)) args[idx + 1L] else default
}
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

read_csv_safe <- function(path) {
  if (is.null(path) || !file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  utils::read.csv(path, stringsAsFactors = FALSE)
}

run_tag <- as.character(get_arg("--run-tag", ""))[1L]
report_root <- resolve_path(get_arg("--report-root", NULL), must_work = FALSE)
if (!nzchar(trimws(run_tag)) && is.null(report_root)) {
  stop("Pass --run-tag or --report-root.", call. = FALSE)
}
if (is.null(report_root)) {
  report_root <- resolve_path(file.path("reports", "qdesn_mcmc_validation", "exal_kernel_screen", run_tag), must_work = TRUE)
}
if (!dir.exists(report_root)) stop(sprintf("Report root not found: %s", report_root), call. = FALSE)
if (!nzchar(trimws(run_tag))) run_tag <- basename(report_root)

state_path <- file.path(report_root, "status", "runner_state.json")
manifest_path <- file.path(report_root, "manifest", "screen_manifest.json")
summary_path <- file.path(report_root, "summary", "screen_results.md")
exec_path <- file.path(report_root, "tables", "profile_execution_status.csv")
rank_path <- file.path(report_root, "tables", "profile_rank_summary.csv")

state <- if (file.exists(state_path)) jsonlite::fromJSON(state_path, simplifyVector = TRUE) else list()
manifest <- if (file.exists(manifest_path)) jsonlite::fromJSON(manifest_path, simplifyVector = TRUE) else list()
execution <- read_csv_safe(exec_path)
rank_df <- read_csv_safe(rank_path)

proc_cmd <- sprintf("pgrep -af 'run_qdesn_exal_kernel_screen.R.*%s|run_qdesn_mcmc_validation_campaign.R.*%s' || true", run_tag, run_tag)
proc_lines <- tryCatch(system(proc_cmd, intern = TRUE), error = function(...) character(0))
proc_lines <- proc_lines[nzchar(trimws(proc_lines))]
proc_lines <- proc_lines[!grepl("pgrep -af", proc_lines, fixed = TRUE)]

status_tab <- if (nrow(execution)) sort(table(as.character(execution$execution_status)), decreasing = TRUE) else integer(0)
status_str <- if (length(status_tab)) paste(names(status_tab), as.integer(status_tab), collapse = ", ") else "none"

best_profile <- if (nrow(rank_df)) as.character(rank_df$profile_id[1L]) else "na"
best_fails <- if (nrow(rank_df) && "total_fail_n" %in% names(rank_df)) as.character(rank_df$total_fail_n[1L]) else "na"
current_profile <- as.character(state$current_profile_id %||% "na")[1L]
current_batch <- as.character(state$current_batch_id %||% "na")[1L]
stop_reason <- as.character(state$stop_reason %||% "na")[1L]
total_profiles <- as.integer(state$total_profiles %||% if (nrow(execution)) nrow(execution) else NA_integer_)[1L]
completed_profiles <- as.integer(state$completed_profiles %||% 0L)[1L]

cat(sprintf("run_tag: %s\n", run_tag))
cat("| Checkpoint | Status | Detail |\n")
cat("|---|---|---|\n")
cat(sprintf("| Active process | %s | matching_processes=%d |\n", if (length(proc_lines)) "yes" else "no", length(proc_lines)))
cat(sprintf("| Runner state | %s | current_batch=%s, current_profile=%s, stop_reason=%s |\n",
            if (file.exists(state_path)) "present" else "missing", current_batch, current_profile, stop_reason))
cat(sprintf("| Execution table | %s | completed=%d/%s, status_mix=%s |\n",
            if (nrow(execution)) "present" else "missing",
            completed_profiles,
            ifelse(is.na(total_profiles), "na", as.character(total_profiles)),
            status_str))
cat(sprintf("| Ranking table | %s | best_profile=%s, best_total_fail_n=%s |\n",
            if (nrow(rank_df)) "present" else "missing", best_profile, best_fails))
cat(sprintf("| Result summary | %s | path=%s |\n",
            if (file.exists(summary_path)) "present" else "missing", summary_path))
cat(sprintf("| Manifest | %s | path=%s |\n",
            if (file.exists(manifest_path)) "present" else "missing", manifest_path))

if (length(proc_lines)) {
  cat("\nactive_processes:\n")
  cat(paste(proc_lines, collapse = "\n"))
  cat("\n")
}

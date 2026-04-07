#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("yaml", "jsonlite")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) && idx < length(args)) args[idx + 1L] else default
}
`%||%` <- function(a, b) if (is.null(a)) b else a

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
  if (!file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  utils::read.csv(path, stringsAsFactors = FALSE)
}

read_json_safe <- function(path) {
  if (!file.exists(path)) return(list())
  jsonlite::fromJSON(path)
}

run_tag <- as.character(get_arg("--run-tag", ""))[1L]
if (!nzchar(trimws(run_tag))) stop("--run-tag is required.", call. = FALSE)

manifest_path <- resolve_path(
  get_arg("--manifest", file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave_manifest.yaml")),
  must_work = TRUE
)
manifest <- yaml::read_yaml(manifest_path)
campaign_cfg <- manifest$campaign %||% list()

base_results_root <- resolve_path(
  get_arg("--results-root", campaign_cfg$results_root %||% file.path("results", "qdesn_mcmc_validation", "dynamic_exdqlm_crossstudy_fit_fail_closure_wave")),
  must_work = TRUE
)
base_report_root <- resolve_path(
  get_arg("--report-root", campaign_cfg$reports_root %||% file.path("reports", "qdesn_mcmc_validation", "dynamic_exdqlm_crossstudy_fit_fail_closure_wave")),
  must_work = TRUE
)

outer_results_root <- file.path(base_results_root, run_tag)
outer_report_root <- file.path(base_report_root, run_tag)
launch_root <- file.path(outer_report_root, "launch")
status_root <- file.path(outer_report_root, "status")
tables_root <- file.path(outer_report_root, "tables")

preflight_manifest <- read_json_safe(file.path(launch_root, "qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_preflight_manifest.json"))
launch_manifest <- read_json_safe(file.path(launch_root, "qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_launch_manifest.json"))
launcher_meta <- read_json_safe(file.path(launch_root, "launcher_session.json"))
runner_state <- read_json_safe(file.path(status_root, "runner_state.json"))
stage_status <- read_csv_safe(file.path(tables_root, "stage_execution_status.csv"))
local_baseline_map <- read_csv_safe(file.path(tables_root, "local_baseline_map.csv"))

pct <- function(num, den) {
  if (!is.finite(den) || den <= 0) return("NA")
  sprintf("%.1f%%", 100 * (as.numeric(num) / as.numeric(den)))
}

total_stages <- as.integer(preflight_manifest$stage_plan$stage_id %||% character(0))
total_stage_n <- length(total_stages)
planned_profiles <- if (is.data.frame(preflight_manifest$stage_plan) && nrow(preflight_manifest$stage_plan)) {
  sum(as.integer(preflight_manifest$stage_plan$stage_profile_n), na.rm = TRUE)
} else {
  NA_integer_
}
completed_stages <- if (nrow(stage_status)) sum(as.character(stage_status$execution_status) == "COMPLETED", na.rm = TRUE) else 0L
completed_profiles <- if (nrow(stage_status)) sum(as.integer(stage_status$profile_n_completed), na.rm = TRUE) else 0L

launcher_mode <- as.character(launcher_meta$launcher_mode %||% NA_character_)
launcher_session <- as.character(launcher_meta$session_name %||% NA_character_)
launcher_log <- as.character(launcher_meta$launcher_log %||% NA_character_)
launcher_session_live <- if (!is.na(launcher_session) && nzchar(launcher_session) && identical(launcher_mode, "tmux")) {
  identical(suppressWarnings(system2("tmux", c("has-session", "-t", launcher_session))), 0L)
} else {
  NA
}
launcher_log_mtime <- if (!is.na(launcher_log) && nzchar(launcher_log) && file.exists(launcher_log)) {
  as.character(file.info(launcher_log)$mtime[1L])
} else {
  NA_character_
}

cat(sprintf("Snapshot: %s\n", as.character(Sys.time())))
cat(sprintf("Run tag: %s\n", run_tag))
cat(sprintf("Manifest: %s\n", manifest_path))
cat(sprintf("Outer report root: %s\n", outer_report_root))
cat(sprintf("Outer results root: %s\n", outer_results_root))
cat(sprintf("Source run tag: %s\n", as.character(preflight_manifest$source_run_tag %||% NA_character_)))
cat(sprintf("Total stages: %s\n", as.character(total_stage_n)))
cat(sprintf("Completed stages: %d (%s)\n", completed_stages, pct(completed_stages, total_stage_n)))
cat(sprintf("Planned profiles: %s\n", as.character(planned_profiles)))
cat(sprintf("Completed profiles: %s (%s)\n", as.character(completed_profiles), pct(completed_profiles, planned_profiles)))
cat(sprintf("Runner stop reason: %s\n", as.character(runner_state$stop_reason %||% NA_character_)))
cat(sprintf("Current stage: %s\n", as.character(runner_state$current_stage_id %||% NA_character_)))
cat(sprintf("Current profile: %s\n", as.character(runner_state$current_profile_id %||% NA_character_)))
cat(sprintf("Launcher mode: %s\n", launcher_mode))
cat(sprintf("Launcher session: %s\n", launcher_session))
cat(sprintf("Launcher session live: %s\n", as.character(launcher_session_live)))
cat(sprintf("Launcher log: %s\n", launcher_log))
cat(sprintf("Launcher log mtime: %s\n", launcher_log_mtime))
cat(sprintf("Launch manifest present: %s\n", if (length(launch_manifest)) "TRUE" else "FALSE"))
cat(sprintf("Stage status rows: %d\n", nrow(stage_status)))
cat(sprintf("Local baseline rows: %d\n", nrow(local_baseline_map)))

if (nrow(stage_status)) {
  cat("\nstage_status_distribution:\n")
  mix <- as.data.frame(table(stage_status$execution_status), stringsAsFactors = FALSE)
  for (i in seq_len(nrow(mix))) {
    cat(sprintf("- %s: %d\n", as.character(mix$Var1[i]), as.integer(mix$Freq[i])))
  }
}

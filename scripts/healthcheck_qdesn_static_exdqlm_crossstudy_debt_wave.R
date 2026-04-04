#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("pkgload", "yaml", "jsonlite")
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
pkgload::load_all(repo_root, quiet = TRUE)

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

manifest_path <- resolve_path(get_arg("--manifest", file.path("config", "validation", "qdesn_static_exdqlm_crossstudy_debt_wave_manifest.yaml")), must_work = TRUE)
manifest <- exdqlm:::qdesn_static_crossstudy_debt_load_manifest(manifest_path)
run_tag <- as.character(get_arg("--run-tag", ""))[1L]
if (!nzchar(run_tag)) stop("--run-tag is required", call. = FALSE)

campaign_cfg <- manifest$campaign %||% list()
base_results_root <- resolve_path(campaign_cfg$results_root %||% file.path("results", "qdesn_mcmc_validation", "static_exdqlm_crossstudy_debt_wave"), must_work = FALSE)
base_report_root <- resolve_path(campaign_cfg$reports_root %||% file.path("reports", "qdesn_mcmc_validation", "static_exdqlm_crossstudy_debt_wave"), must_work = FALSE)
outer_results_root <- file.path(base_results_root, run_tag)
outer_report_root <- file.path(base_report_root, run_tag)

runner_state <- if (file.exists(file.path(outer_report_root, "status", "runner_state.json"))) {
  jsonlite::fromJSON(file.path(outer_report_root, "status", "runner_state.json"))
} else {
  list()
}
stage_status <- read_csv_safe(file.path(outer_report_root, "tables", "stage_execution_status.csv"))
completed_manifest <- if (file.exists(file.path(outer_report_root, "manifest", "debt_wave_completed.json"))) {
  jsonlite::fromJSON(file.path(outer_report_root, "manifest", "debt_wave_completed.json"))
} else {
  list()
}

cat(sprintf("Snapshot: %s\n", as.character(Sys.time())))
cat(sprintf("Run tag: %s\n", run_tag))
cat(sprintf("Outer report root: %s\n", outer_report_root))
cat(sprintf("Outer results root: %s\n", outer_results_root))
cat(sprintf("Current stage: %s\n", as.character(runner_state$current_stage_id %||% NA_character_)))
cat(sprintf("Current profile: %s\n", as.character(runner_state$current_profile_id %||% NA_character_)))
cat(sprintf("Completed stages: %s\n", as.character(runner_state$completed_stages %||% 0L)))
cat(sprintf("Total stages: %s\n", as.character(runner_state$total_stages %||% 0L)))
cat(sprintf("Completed profiles: %s\n", as.character(runner_state$completed_profiles %||% 0L)))
cat(sprintf("Total profiles: %s\n", as.character(runner_state$total_profiles %||% 0L)))
cat(sprintf("Stop reason: %s\n", as.character(runner_state$stop_reason %||% "IN_PROGRESS")))
cat(sprintf("Recommendation: %s\n", as.character(completed_manifest$recommendation %||% "IN_PROGRESS")))
cat("\nStage status:\n")
if (nrow(stage_status)) {
  utils::write.table(stage_status, row.names = FALSE, quote = FALSE)
} else {
  cat("(no stage status rows yet)\n")
}

#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Package 'jsonlite' is required.", call. = FALSE)
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx) || idx[[1L]] >= length(args)) return(default)
  args[[idx[[1L]] + 1L]]
}
`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
state_parent <- file.path(repo_root, "reports", "shared_fitforecast_v2_orchestration")
run_id <- as.character(get_arg("--run-id", ""))[1L]
if (!nzchar(run_id)) {
  candidates <- list.dirs(state_parent, recursive = FALSE, full.names = FALSE)
  candidates <- candidates[startsWith(candidates, "qdesn_alpha_rho_seedrepair_v1_")]
  if (!length(candidates)) stop("No seed-repair orchestration state was found.", call. = FALSE)
  run_id <- sort(candidates, decreasing = TRUE)[[1L]]
}
state_root <- file.path(state_parent, run_id)
status_path <- file.path(state_root, "stage_status.csv")
status <- if (file.exists(status_path)) {
  utils::read.csv(status_path, check.names = FALSE, stringsAsFactors = FALSE)
} else data.frame(stringsAsFactors = FALSE)
env_path <- file.path(state_root, "run_tags.env")
env <- if (file.exists(env_path)) readLines(env_path, warn = FALSE) else character()
env_value <- function(name) {
  line <- env[startsWith(env, paste0(name, "="))]
  if (length(line)) sub(paste0("^", name, "="), "", line[[1L]]) else NA_character_
}
full_tag <- env_value("FULL_TAG")
stage <- "qdesn_dynamic_fitforecast_v2_500obs_alpha_rho_seedrepair_v1"
run_root <- file.path(repo_root, "results", "qdesn_mcmc_validation", stage, full_tag)
fit_summaries <- if (is.character(full_tag) && !is.na(full_tag) && dir.exists(run_root)) {
  list.files(run_root, pattern = "^fit_summary_row[.]csv$", recursive = TRUE, full.names = TRUE)
} else character()
root_status <- if (is.character(full_tag) && !is.na(full_tag) && dir.exists(run_root)) {
  list.files(run_root, pattern = "^root_status[.]csv$", recursive = TRUE, full.names = TRUE)
} else character()
gate_path <- file.path(state_root, "audit", "seedrepair_gate.json")
gate <- if (file.exists(gate_path)) jsonlite::read_json(gate_path, simplifyVector = TRUE) else list()
latest <- if (nrow(status)) status[nrow(status), , drop = FALSE] else data.frame(
  timestamp = NA_character_, stage = "not_started", status = "NOT_STARTED", detail = "", stringsAsFactors = FALSE
)
active_processes <- system(
  sprintf(
    paste(
      "pgrep -af '%s|%s'",
      "| grep -v -E 'pgrep|healthcheck_qdesn_alpha_rho_seedrepair_v1[.]R'",
      "|| true"
    ),
    run_id,
    full_tag %||% "__none__"
  ),
  intern = TRUE
)
binary_count <- if (dir.exists(run_root)) length(list.files(
  run_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE
)) else 0L
done <- length(unique(fit_summaries))
expected <- 48L
health <- data.frame(
  run_id = run_id,
  current_stage = as.character(latest$stage[[1L]]),
  stage_status = as.character(latest$status[[1L]]),
  roots_done = done,
  roots_expected = expected,
  roots_left = max(0L, expected - done),
  percent_done = round(100 * done / expected, 1),
  root_status_files = length(root_status),
  active_process_count = length(active_processes),
  audit_decision = as.character(gate$decision %||% NA_character_),
  seed_contract_passes = as.integer(gate$seed_contract_passes %||% NA_integer_),
  full_budget_handoff_count = as.integer(gate$full_budget_handoff_count %||% NA_integer_),
  unexpected_binary_payloads = binary_count,
  last_update = as.character(latest$timestamp[[1L]]),
  stringsAsFactors = FALSE
)
utils::write.table(health, row.names = FALSE, sep = ",", quote = TRUE)
if (length(active_processes)) {
  cat("\nACTIVE_PROCESSES\n", paste(active_processes, collapse = "\n"), "\n", sep = "")
}

#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx) || idx[[1L]] >= length(args)) return(default)
  args[[idx[[1L]] + 1L]]
}

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/",
  mustWork = TRUE
)
setwd(repo_root)

state_parent <- file.path(repo_root, "reports", "shared_fitforecast_v2_orchestration")
run_id <- as.character(get_arg("--run-id", ""))[[1L]]
if (!nzchar(run_id)) {
  candidates <- list.dirs(state_parent, recursive = FALSE, full.names = TRUE)
  candidates <- candidates[grepl("/qdesn_alpha_rho_topology_v1_[0-9]{8}_[0-9]{6}$", candidates)]
  if (!length(candidates)) stop("No alpha/rho topology v1 orchestration directory found.", call. = FALSE)
  run_id <- basename(candidates[[which.max(file.info(candidates)$mtime)]])
}
state_root <- file.path(state_parent, run_id)
if (!dir.exists(state_root)) stop(sprintf("Missing state root: %s", state_root), call. = FALSE)

read_csv_safe <- function(path) {
  if (!file.exists(path) || file.info(path)$size <= 0) return(data.frame(stringsAsFactors = FALSE))
  tryCatch(utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE), error = function(e) data.frame(stringsAsFactors = FALSE))
}
read_env <- function(path) {
  if (!file.exists(path)) return(character())
  lines <- readLines(path, warn = FALSE)
  lines <- lines[grepl("^[A-Z0-9_]+=", lines)]
  out <- sub("^[^=]+=", "", lines)
  names(out) <- sub("=.*$", "", lines)
  out
}
count_status <- function(root) {
  if (!dir.exists(root)) return(integer())
  paths <- list.files(root, pattern = "^root_status[.]txt$", recursive = TRUE, full.names = TRUE)
  values <- vapply(paths, function(path) trimws(readLines(path, warn = FALSE, n = 1L)), character(1L))
  if (length(values)) sort(table(values), decreasing = TRUE) else integer()
}
resolve_campaign_root <- function(outer_root) {
  if (!dir.exists(outer_root)) return(outer_root)
  if (dir.exists(file.path(outer_root, "roots"))) return(outer_root)
  children <- list.dirs(outer_root, recursive = FALSE, full.names = TRUE)
  hits <- children[dir.exists(file.path(children, "roots"))]
  if (length(hits)) hits[[which.max(file.info(hits)$mtime)]] else outer_root
}
status_count <- function(tab, value) if (value %in% names(tab)) as.integer(tab[[value]]) else 0L

env <- read_env(file.path(state_root, "run_tags.env"))
stages <- read_csv_safe(file.path(state_root, "stage_status.csv"))
latest_stage <- if (nrow(stages)) as.character(tail(stages$stage, 1L)) else "initializing"
latest_status <- if (nrow(stages)) as.character(tail(stages$status, 1L)) else "UNKNOWN"
phase <- if (grepl("^broad|pipeline_complete", latest_stage)) "broad" else "mechanism"
run_tag_key <- if (phase == "broad") "BROAD_RUN_TAG" else "MECHANISM_RUN_TAG"
run_tag <- unname(env[[run_tag_key]])
expected <- if (phase == "broad") 960L else 120L

stage_stub <- "qdesn_dynamic_fitforecast_v2_500obs_alpha_rho_topology_v1"
outer_results <- file.path(
  repo_root, "results", "qdesn_mcmc_validation",
  paste(stage_stub, phase, sep = "_"), run_tag
)
campaign_root <- resolve_campaign_root(outer_results)
root_status <- count_status(file.path(campaign_root, "roots"))
fit_paths <- if (dir.exists(campaign_root)) {
  list.files(campaign_root, pattern = "^fit_summary_row[.]csv$", recursive = TRUE, full.names = TRUE)
} else character()
horizon_paths <- if (dir.exists(campaign_root)) {
  list.files(campaign_root, pattern = "^forecast_horizon_summary[.]csv$", recursive = TRUE, full.names = TRUE)
} else character()
heavy_paths <- if (dir.exists(campaign_root)) {
  list.files(campaign_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
} else character()
progress_paths <- if (dir.exists(campaign_root)) {
  list.files(campaign_root, pattern = "progress_trace.*[.]csv$|fit_status[.]txt$|root_status[.]txt$", recursive = TRUE, full.names = TRUE)
} else character()
latest_progress <- if (length(progress_paths)) max(file.info(progress_paths)$mtime, na.rm = TRUE) else as.POSIXct(NA)
age_minutes <- if (!is.na(latest_progress)) as.numeric(difftime(Sys.time(), latest_progress, units = "mins")) else NA_real_

stamp <- sub("^qdesn_alpha_rho_topology_v1_", "", run_id)
session <- paste0("ffv2_qdesn_arv1_", stamp)
tmux_live <- identical(
  suppressWarnings(system2("tmux", c("has-session", "-t", session), stdout = FALSE, stderr = FALSE)),
  0L
)
success <- status_count(root_status, "SUCCESS")
failed <- status_count(root_status, "FAIL") + status_count(root_status, "FAILED")
running <- status_count(root_status, "RUNNING")
finished <- success + failed
remaining <- max(0L, expected - finished)
pct <- if (expected > 0L) 100 * finished / expected else NA_real_
health <- if (tmux_live && is.finite(age_minutes) && age_minutes <= 30) {
  "ACTIVE"
} else if (tmux_live) {
  "LIVE_CHECK_PROGRESS"
} else if (latest_stage %in% c("pipeline_complete", "pipeline_stopped_by_gate")) {
  "COMPLETE"
} else {
  "NOT_LIVE_REVIEW_LOG"
}

cat(sprintf("Snapshot: %s\n", format(Sys.time(), tz = "UTC", usetz = TRUE)))
cat(sprintf("Run ID: %s\n", run_id))
cat(sprintf("State root: %s\n\n", normalizePath(state_root, winslash = "/", mustWork = TRUE)))
cat("| Phase | Health | Finished | Remaining | Success | Failed | Running | Fit summaries | H1000 files | Heavy payloads | Latest progress age |\n")
cat("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n")
cat(sprintf(
  "| %s | %s | %d/%d (%.1f%%) | %d | %d | %d | %d | %d | %d | %d | %s |\n",
  phase, health, finished, expected, pct, remaining, success, failed, running,
  length(fit_paths), length(horizon_paths), length(heavy_paths),
  if (is.finite(age_minutes)) sprintf("%.1f min", age_minutes) else "NA"
))
cat(sprintf("\nLatest stage/status: `%s` / `%s`\n", latest_stage, latest_status))
cat(sprintf("tmux session: `%s` (live=%s)\n", session, tmux_live))
cat(sprintf("run tag: `%s`\n", run_tag))
cat(sprintf("campaign root: `%s`\n", campaign_root))

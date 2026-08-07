#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx) || idx[[1L]] >= length(args)) return(default)
  args[[idx[[1L]] + 1L]]
}
repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
setwd(repo_root)
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
resolve_campaign_root <- function(outer_root) {
  if (!dir.exists(outer_root)) return(outer_root)
  if (dir.exists(file.path(outer_root, "roots"))) return(outer_root)
  children <- list.dirs(outer_root, recursive = FALSE, full.names = TRUE)
  hits <- children[dir.exists(file.path(children, "roots"))]
  if (length(hits)) hits[[which.max(file.info(hits)$mtime)]] else outer_root
}
read_statuses <- function(root) {
  if (!dir.exists(root)) return(character())
  paths <- list.files(root, pattern = "^root_status[.]txt$", recursive = TRUE, full.names = TRUE)
  if (!length(paths)) return(character())
  vapply(paths, function(path) trimws(readLines(path, warn = FALSE, n = 1L)), character(1L))
}
status_count <- function(values, pattern) sum(grepl(pattern, values, ignore.case = TRUE))
latest_iteration <- function(path) {
  if (!file.exists(path)) return(NA_integer_)
  lines <- tail(readLines(path, warn = FALSE), 250L)
  hits <- regmatches(lines, regexec("MCMC iteration[[:space:]]+([0-9]+)", lines))
  values <- suppressWarnings(as.integer(vapply(hits, function(x) if (length(x) >= 2L) x[[2L]] else NA_character_, character(1L))))
  values <- values[is.finite(values)]
  if (length(values)) tail(values, 1L) else NA_integer_
}

state_parent <- file.path(repo_root, "reports", "shared_fitforecast_v2_orchestration")
run_id <- as.character(get_arg("--run-id", ""))[[1L]]
if (!nzchar(run_id)) {
  candidates <- list.dirs(state_parent, recursive = FALSE, full.names = TRUE)
  candidates <- candidates[grepl("/qdesn_mcmc_highalpha_cellwise_v1_[0-9]{8}_[0-9]{6}$", candidates)]
  if (!length(candidates)) stop("No high-alpha cellwise v1 orchestration directory found.", call. = FALSE)
  run_id <- basename(candidates[[which.max(file.info(candidates)$mtime)]])
}
state_root <- file.path(state_parent, run_id)
if (!dir.exists(state_root)) stop(sprintf("Missing state root: %s", state_root), call. = FALSE)
env <- read_env(file.path(state_root, "run_tags.env"))
stages <- read_csv_safe(file.path(state_root, "stage_status.csv"))
latest_stage <- if (nrow(stages)) as.character(tail(stages$stage, 1L)) else trimws(readLines(file.path(state_root, "current_stage.txt"), warn = FALSE, n = 1L))
latest_status <- if (nrow(stages)) as.character(tail(stages$status, 1L)) else "UNKNOWN"
run_tag <- unname(env[["WAVE1_RUN_TAG"]])
expected <- 372L
outer_root <- file.path(
  repo_root, "results", "qdesn_mcmc_validation",
  "qdesn_dynamic_fitforecast_v2_500obs_mcmc_highalpha_cellwise_v1_wave1",
  run_tag
)
campaign_root <- resolve_campaign_root(outer_root)
statuses <- read_statuses(file.path(campaign_root, "roots"))
success <- status_count(statuses, "^SUCCESS$")
failed <- status_count(statuses, "FAIL|ERROR|TIMEOUT|INTERRUPT")
running <- status_count(statuses, "RUNNING|STARTED")
finished <- success + failed
remaining <- max(0L, expected - finished)
fit_paths <- if (dir.exists(campaign_root)) list.files(campaign_root, pattern = "^fit_summary_row[.]csv$", recursive = TRUE, full.names = TRUE) else character()
horizon_paths <- if (dir.exists(campaign_root)) list.files(campaign_root, pattern = "^forecast_horizon_summary[.]csv$", recursive = TRUE, full.names = TRUE) else character()
heavy_paths <- if (dir.exists(campaign_root)) list.files(campaign_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE) else character()
live_logs <- if (dir.exists(campaign_root)) list.files(campaign_root, pattern = "^pipeline_child_live[.]log$", recursive = TRUE, full.names = TRUE) else character()
progress_paths <- c(live_logs, if (dir.exists(campaign_root)) list.files(campaign_root, pattern = "root_status[.]txt$|fit_status[.]txt$", recursive = TRUE, full.names = TRUE) else character())
latest_progress <- if (length(progress_paths)) max(file.info(progress_paths)$mtime, na.rm = TRUE) else as.POSIXct(NA)
progress_age <- if (!is.na(latest_progress)) as.numeric(difftime(Sys.time(), latest_progress, units = "mins")) else NA_real_
stage_age <- as.numeric(difftime(Sys.time(), file.info(file.path(state_root, "current_stage.txt"))$mtime, units = "mins"))
session_file <- file.path(state_root, "tmux_session.txt")
session <- if (file.exists(session_file)) trimws(readLines(session_file, warn = FALSE, n = 1L)) else ""
tmux_live <- nzchar(session) && identical(suppressWarnings(system2("tmux", c("has-session", "-t", session), stdout = FALSE, stderr = FALSE)), 0L)
process_lines <- suppressWarnings(system("ps -eo args=", intern = TRUE, ignore.stderr = TRUE))
fit_process_token <- paste0("--file=", file.path(repo_root, "scripts", "pipeline_real_main.R"))
worker_processes <- sum(grepl(fit_process_token, process_lines, fixed = TRUE))
terminal_stage <- latest_stage == "pipeline_complete"
health <- if (tmux_live && grepl("resource_gate", latest_stage)) {
  "WAITING_FOR_RESOURCES"
} else if (tmux_live && is.finite(progress_age) && progress_age <= 30) {
  "ACTIVE"
} else if (tmux_live && !is.finite(progress_age) && is.finite(stage_age) && stage_age <= 30) {
  "STARTING"
} else if (tmux_live) {
  "LIVE_BUT_STALE_REVIEW"
} else if (terminal_stage) {
  "COMPLETE"
} else {
  "NOT_LIVE_REVIEW_LOG"
}

active_rows <- list()
if (length(live_logs)) {
  for (path in live_logs) {
    fit_dir <- dirname(dirname(path))
    status_path <- file.path(fit_dir, "manifest", "fit_status.txt")
    fit_status <- if (file.exists(status_path)) trimws(readLines(status_path, warn = FALSE, n = 1L)) else "UNKNOWN"
    age <- as.numeric(difftime(Sys.time(), file.info(path)$mtime, units = "mins"))
    iter <- latest_iteration(path)
    if (grepl("RUNNING|STARTED", fit_status, ignore.case = TRUE) || (is.finite(age) && age <= 30 && !grepl("SUCCESS|FAIL", fit_status, ignore.case = TRUE))) {
      root_name <- basename(dirname(dirname(dirname(fit_dir))))
      active_rows[[length(active_rows) + 1L]] <- data.frame(
        root = root_name,
        status = fit_status,
        iteration = iter,
        total_iterations = 4000L,
        iteration_pct = if (is.finite(iter)) 100 * iter / 4000 else NA_real_,
        log_age_minutes = age,
        stringsAsFactors = FALSE
      )
    }
  }
}
active <- if (length(active_rows)) do.call(rbind, active_rows) else data.frame(
  root = character(), status = character(), iteration = integer(),
  total_iterations = integer(), iteration_pct = numeric(), log_age_minutes = numeric()
)
if (nrow(active)) active <- active[order(-active$iteration, active$root), , drop = FALSE]

summary <- data.frame(
  snapshot_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
  run_id = run_id,
  health = health,
  stage = latest_stage,
  stage_status = latest_status,
  finished = finished,
  expected = expected,
  completion_pct = 100 * finished / expected,
  remaining = remaining,
  success = success,
  failed = failed,
  running_markers = running,
  worker_processes = worker_processes,
  fit_summaries = length(fit_paths),
  horizon_files = length(horizon_paths),
  heavy_payloads = length(heavy_paths),
  progress_age_minutes = progress_age,
  tmux_live = tmux_live,
  stringsAsFactors = FALSE
)
utils::write.csv(summary, file.path(state_root, "health_snapshot_latest.csv"), row.names = FALSE, na = "")
utils::write.csv(active, file.path(state_root, "active_iteration_snapshot_latest.csv"), row.names = FALSE, na = "")

cat(sprintf("Snapshot: %s\n", summary$snapshot_utc))
cat(sprintf("Run ID: %s\n", run_id))
cat(sprintf("State root: %s\n\n", normalizePath(state_root, winslash = "/", mustWork = TRUE)))
cat("| Health | Stage | Finished | Remaining | Success | Failed | Running | Workers | Fit rows | H1000 | Heavy | Progress age |\n")
cat("|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n")
cat(sprintf(
  "| %s | %s | %d/%d (%.1f%%) | %d | %d | %d | %d | %d | %d | %d | %d | %s |\n",
  health, latest_stage, finished, expected, 100 * finished / expected, remaining,
  success, failed, running, worker_processes, length(fit_paths), length(horizon_paths),
  length(heavy_paths), if (is.finite(progress_age)) sprintf("%.1f min", progress_age) else "NA"
))
visible_iterations <- active$iteration[is.finite(active$iteration)]
if (length(visible_iterations)) {
  cat(sprintf("\nActive MCMC iteration range: %d-%d / 4000 across %d visible fits.\n",
    min(visible_iterations), max(visible_iterations), length(visible_iterations)))
} else if (nrow(active)) {
  cat(sprintf("\n%d active fits are visible but have not emitted a numeric iteration yet.\n", nrow(active)))
}
cat(sprintf("tmux: `%s` (live=%s)\n", session, tmux_live))
cat(sprintf("run tag: `%s`\n", run_tag))
cat(sprintf("campaign root: `%s`\n", campaign_root))
cat("Wave 2 and full-budget confirmation are not launched automatically.\n")

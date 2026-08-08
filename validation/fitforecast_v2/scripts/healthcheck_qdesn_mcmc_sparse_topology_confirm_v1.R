#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x
get_arg <- function(flag, default = NULL) {
  index <- which(args == flag)
  if (!length(index) || index[[1L]] >= length(args)) return(default)
  args[[index[[1L]] + 1L]]
}
repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/", mustWork = TRUE
)
setwd(repo_root)
read_csv_safe <- function(path) {
  if (!file.exists(path) || file.info(path)$size <= 0) return(data.frame())
  tryCatch(
    utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE),
    error = function(e) data.frame()
  )
}
read_json_safe <- function(path) {
  if (!file.exists(path) || file.info(path)$size <= 0) return(list())
  tryCatch(
    jsonlite::read_json(path, simplifyVector = TRUE),
    error = function(e) list()
  )
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
  if (!dir.exists(outer_root) || dir.exists(file.path(outer_root, "roots"))) return(outer_root)
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
latest_iteration <- function(path) {
  if (!file.exists(path)) return(NA_integer_)
  lines <- tail(readLines(path, warn = FALSE), 300L)
  progress <- lines[grepl(
    "burn-in iteration|MCMC iteration|sampling iteration|posterior iteration",
    lines
  )]
  if (!length(progress)) return(NA_integer_)
  latest <- tail(progress, 1L)
  if (grepl("burn-in iteration[[:space:]]+[0-9]+", latest)) {
    return(suppressWarnings(as.integer(sub(
      ".*burn-in iteration[[:space:]]+([0-9]+).*", "\\1", latest
    ))))
  }
  if (grepl("(MCMC|sampling|posterior) iteration[[:space:]]+[0-9]+", latest)) {
    iteration <- suppressWarnings(as.integer(sub(
      ".*(MCMC|sampling|posterior) iteration[[:space:]]+([0-9]+).*",
      "\\2", latest
    )))
    # Q-DESN reports post-burn progress on the global burn-plus-sampling scale.
    return(iteration)
  }
  NA_integer_
}
artifact_root_status <- function(path, campaign_root) {
  roots_root <- file.path(campaign_root, "roots")
  relative <- substring(path, nchar(roots_root) + 2L)
  root_name <- strsplit(relative, "/", fixed = TRUE)[[1L]][[1L]]
  status_path <- file.path(roots_root, root_name, "manifest", "root_status.txt")
  if (!file.exists(status_path)) return("UNKNOWN")
  trimws(readLines(status_path, warn = FALSE, n = 1L))
}

state_parent <- file.path(repo_root, "reports", "shared_fitforecast_v2_orchestration")
run_id <- as.character(get_arg("--run-id", ""))[1L]
if (!nzchar(run_id)) {
  candidates <- list.dirs(state_parent, recursive = FALSE, full.names = TRUE)
  candidates <- candidates[grepl(
    "/qdesn_mcmc_sparse_topology_confirm_v1_[0-9]{8}_[0-9]{6}$", candidates
  )]
  if (!length(candidates)) stop("No sparse-topology confirmation v1 run found.", call. = FALSE)
  run_id <- basename(candidates[[which.max(file.info(candidates)$mtime)]])
}
state_root <- file.path(state_parent, run_id)
if (!dir.exists(state_root)) stop(sprintf("Missing state root: %s", state_root), call. = FALSE)
env <- read_env(file.path(state_root, "run_tags.env"))
stages <- read_csv_safe(file.path(state_root, "stage_status.csv"))
current_stage_path <- file.path(state_root, "current_stage.txt")
latest_stage <- if (nrow(stages)) {
  as.character(tail(stages$stage, 1L))
} else if (file.exists(current_stage_path)) {
  trimws(readLines(current_stage_path, warn = FALSE, n = 1L))
} else "UNKNOWN"
latest_status <- if (nrow(stages)) as.character(tail(stages$status, 1L)) else "UNKNOWN"
run_tag <- unname(env[["CONFIRMATION_RUN_TAG"]])
if (!length(run_tag) || is.na(run_tag)) run_tag <- ""
expected <- 21L
campaign_parent <- file.path(
  repo_root, "results", "qdesn_mcmc_validation",
  "qdesn_dynamic_fitforecast_v2_500obs_mcmc_sparse_topology_confirm_v1"
)
outer_root <- if (nzchar(run_tag)) file.path(campaign_parent, run_tag) else campaign_parent
campaign_root <- resolve_campaign_root(outer_root)
statuses <- read_statuses(file.path(campaign_root, "roots"))
success <- sum(grepl("^SUCCESS$", statuses, ignore.case = TRUE))
failed <- sum(grepl("FAIL|ERROR|TIMEOUT|INTERRUPT", statuses, ignore.case = TRUE))
running <- sum(grepl("RUNNING|STARTED", statuses, ignore.case = TRUE))
finished <- success + failed
remaining <- max(0L, expected - finished)
fit_paths <- if (dir.exists(campaign_root)) {
  list.files(campaign_root, pattern = "^fit_summary_row[.]csv$", recursive = TRUE, full.names = TRUE)
} else character()
horizon_paths <- if (dir.exists(campaign_root)) {
  list.files(campaign_root, pattern = "^forecast_horizon_summary[.]csv$", recursive = TRUE, full.names = TRUE)
} else character()
heavy_paths <- if (dir.exists(campaign_root)) {
  list.files(campaign_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
             full.names = TRUE, ignore.case = TRUE)
} else character()
heavy_status <- if (length(heavy_paths)) {
  vapply(heavy_paths, artifact_root_status, character(1L), campaign_root = campaign_root)
} else character()
transient_heavy <- heavy_paths[grepl("RUNNING|STARTED", heavy_status, ignore.case = TRUE)]
retained_heavy <- setdiff(heavy_paths, transient_heavy)
live_logs <- if (dir.exists(campaign_root)) {
  list.files(campaign_root, pattern = "^pipeline_child_live[.]log$", recursive = TRUE,
             full.names = TRUE)
} else character()
progress_paths <- c(live_logs, if (dir.exists(campaign_root)) {
  list.files(campaign_root, pattern = "root_status[.]txt$|fit_status[.]txt$",
             recursive = TRUE, full.names = TRUE)
} else character())
latest_progress <- if (length(progress_paths)) {
  max(file.info(progress_paths)$mtime, na.rm = TRUE)
} else as.POSIXct(NA)
progress_age <- if (!is.na(latest_progress)) {
  as.numeric(difftime(Sys.time(), latest_progress, units = "mins"))
} else NA_real_
session_file <- file.path(state_root, "tmux_session.txt")
session <- if (file.exists(session_file)) {
  trimws(readLines(session_file, warn = FALSE, n = 1L))
} else ""
tmux_live <- nzchar(session) && identical(suppressWarnings(system2(
  "tmux", c("has-session", "-t", session), stdout = FALSE, stderr = FALSE
)), 0L)
process_lines <- suppressWarnings(system("ps -eo args=", intern = TRUE, ignore.stderr = TRUE))
fit_token <- paste0("--file=", file.path(repo_root, "scripts", "pipeline_real_main.R"))
worker_processes <- sum(grepl(fit_token, process_lines, fixed = TRUE))
terminal <- identical(latest_stage, "pipeline_complete")
closeout_gate_path <- file.path(state_root, "closeout", "confirmation_gate.json")
closeout_gate <- read_json_safe(closeout_gate_path)
closeout_decision <- as.character(closeout_gate$decision %||% "")
closeout_complete <-
  grepl("^CONFIRMATION_COMPLETE_", closeout_decision) &&
  identical(as.integer(closeout_gate$expected_specs %||% NA_integer_), expected) &&
  identical(as.integer(closeout_gate$observed_specs %||% NA_integer_), expected) &&
  identical(as.integer(closeout_gate$complete_metric_specs %||% NA_integer_), expected) &&
  identical(as.integer(closeout_gate$execution_contract_passes %||% NA_integer_), expected) &&
  identical(as.integer(closeout_gate$complete_candidate_parent_pairs %||% NA_integer_), 9L) &&
  identical(as.integer(closeout_gate$unexpected_binary_payloads %||% NA_integer_), 0L)
health <- if (length(retained_heavy)) {
  "STORAGE_REVIEW"
} else if (closeout_complete) {
  "COMPLETE_CLOSED_OUT"
} else if (terminal && latest_status == "COMPLETED") {
  "COMPLETE"
} else if (terminal) {
  "COMPLETE_WITH_REVIEW"
} else if (tmux_live && grepl("resource_gate", latest_stage)) {
  "WAITING_FOR_RESOURCES"
} else if (tmux_live && is.finite(progress_age) && progress_age <= 30) {
  "ACTIVE"
} else if (tmux_live && !is.finite(progress_age)) {
  "STARTING"
} else if (tmux_live) {
  "LIVE_STALE_REVIEW"
} else {
  "NOT_LIVE_REVIEW_LOG"
}

active_rows <- list()
for (path in live_logs) {
  fit_dir <- dirname(dirname(path))
  status_path <- file.path(fit_dir, "manifest", "fit_status.txt")
  fit_status <- if (file.exists(status_path)) {
    trimws(readLines(status_path, warn = FALSE, n = 1L))
  } else "UNKNOWN"
  age <- as.numeric(difftime(Sys.time(), file.info(path)$mtime, units = "mins"))
  iteration <- latest_iteration(path)
  if (grepl("RUNNING|STARTED", fit_status, ignore.case = TRUE) ||
      (is.finite(age) && age <= 30 && !grepl("SUCCESS|FAIL", fit_status, ignore.case = TRUE))) {
    active_rows[[length(active_rows) + 1L]] <- data.frame(
      fit = basename(dirname(fit_dir)),
      status = fit_status,
      iteration = iteration,
      total_iterations = 25000L,
      iteration_pct = if (is.finite(iteration)) 100 * iteration / 25000 else NA_real_,
      log_age_minutes = age,
      stringsAsFactors = FALSE
    )
  }
}
active <- if (length(active_rows)) do.call(rbind, active_rows) else data.frame(
  fit = character(), status = character(), iteration = integer(),
  total_iterations = integer(), iteration_pct = numeric(), log_age_minutes = numeric()
)
if (nrow(active)) active <- active[order(-active$iteration, active$fit), , drop = FALSE]

summary <- data.frame(
  snapshot_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
  run_id = run_id,
  health = health,
  stage = latest_stage,
  stage_status = latest_status,
  closeout_decision = if (nzchar(closeout_decision)) closeout_decision else NA_character_,
  closeout_complete = closeout_complete,
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
  retained_heavy_payloads = length(retained_heavy),
  transient_heavy_payloads = length(transient_heavy),
  progress_age_minutes = progress_age,
  tmux_live = tmux_live,
  stringsAsFactors = FALSE
)
utils::write.csv(summary, file.path(state_root, "health_snapshot_latest.csv"),
                 row.names = FALSE, na = "")
utils::write.csv(active, file.path(state_root, "active_iteration_snapshot_latest.csv"),
                 row.names = FALSE, na = "")

cat(sprintf("Snapshot: %s\n", summary$snapshot_utc))
cat(sprintf("Run ID: %s\n", run_id))
if (nzchar(closeout_decision)) cat(sprintf("Closeout: %s\n", closeout_decision))
cat("| Health | Stage | Finished | Left | Success | Failed | Running | Workers | Fit rows | H1000 | Heavy | Progress age |\n")
cat("|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n")
cat(sprintf(
  "| %s | %s | %d/%d (%.1f%%) | %d | %d | %d | %d | %d | %d | %d | %d | %s |\n",
  health, latest_stage, finished, expected, 100 * finished / expected,
  remaining, success, failed, running, worker_processes, length(fit_paths),
  length(horizon_paths), length(retained_heavy),
  if (is.finite(progress_age)) sprintf("%.1f min", progress_age) else "NA"
))
visible <- active$iteration[is.finite(active$iteration)]
if (length(visible)) {
  cat(sprintf("Active MCMC range: %d-%d / 25000 across %d visible fits.\n",
              min(visible), max(visible), length(visible)))
}
cat(sprintf("tmux: `%s` (live=%s)\n", session, tmux_live))
cat(sprintf("run tag: `%s`\n", run_tag))
cat(sprintf("campaign root: `%s`\n", campaign_root))

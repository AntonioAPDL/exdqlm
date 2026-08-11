#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Missing package: jsonlite", call. = FALSE)
  }
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (!length(i) || i[[1L]] >= length(args)) return(default)
  args[[i[[1L]] + 1L]]
}
repo_root <- normalizePath(get_arg(
  "--repo-root", system("git rev-parse --show-toplevel", intern = TRUE)
), winslash = "/", mustWork = TRUE)
setwd(repo_root)
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "independent_exal_m0_structural_screen_v2.R"))

run_tag <- as.character(get_arg("--run-tag", ""))[1L]
mode <- as.character(get_arg("--mode", "calibration"))[1L]
if (!nzchar(run_tag) || !mode %in% c("smoke", "calibration")) {
  stop("--run-tag and --mode smoke|calibration are required.", call. = FALSE)
}
materialization_root <- normalizePath(get_arg(
  "--materialization-root",
  file.path(repo_root, "reports", "shared_fitforecast_v2_orchestration",
            "independent_exal_m0_paired_rolling_repair_v1_materialization")
), winslash = "/", mustWork = TRUE)
plan <- qdesn_ssv2_read_csv(file.path(materialization_root, paste0(mode, "_plan.csv")))
state_root <- file.path(repo_root, "reports", "shared_fitforecast_v2_orchestration", run_tag)
output_path <- get_arg("--output", file.path(state_root, "healthcheck.csv"))
stale_seconds <- as.numeric(get_arg("--stale-seconds", "1800"))

process_alive <- function(pid) {
  if (!is.finite(pid) || pid <= 0) return(FALSE)
  status <- suppressWarnings(system2("kill", c("-0", as.integer(pid)),
                                     stdout = FALSE, stderr = FALSE))
  identical(status, 0L)
}
mtime_age <- function(path) {
  if (!file.exists(path)) return(Inf)
  as.numeric(difftime(Sys.time(), file.info(path)$mtime, units = "secs"))
}

rows <- lapply(seq_len(nrow(plan)), function(i) {
  row <- plan[i, , drop = FALSE]
  job_root <- qdesn_ssv2_job_root(repo_root, run_tag, row$job_id[[1L]])
  started_path <- file.path(job_root, "job_started.json")
  status_path <- file.path(job_root, "job_status.json")
  log_path <- file.path(state_root, "logs", paste0(row$job_id[[1L]], ".log"))
  started <- if (file.exists(started_path)) {
    tryCatch(qdesn_ssv2_read_json(started_path), error = function(e) NULL)
  } else NULL
  status <- if (file.exists(status_path)) {
    tryCatch(qdesn_ssv2_read_json(status_path), error = function(e) NULL)
  } else NULL
  pid <- if (is.null(started)) NA_integer_ else as.integer(started$pid)
  alive <- process_alive(pid)
  log_lines <- if (file.exists(log_path)) {
    tryCatch(readLines(log_path, warn = FALSE), error = function(e) character())
  } else character()
  progress <- qdesn_ssv2_parse_progress_lines(
    log_lines, as.integer(row$n_burn[[1L]]), as.integer(row$n_mcmc[[1L]])
  )
  completed_iterations <- if (!is.finite(progress$iteration)) {
    NA_integer_
  } else if (identical(progress$phase, "sampling")) {
    as.integer(row$n_burn[[1L]]) + progress$iteration
  } else progress$iteration
  state <- if (!is.null(status)) {
    as.character(status$status)
  } else if (alive) {
    "RUNNING"
  } else if (!is.null(started)) {
    "INTERRUPTED"
  } else {
    "PENDING"
  }
  age <- min(c(mtime_age(log_path), mtime_age(started_path), mtime_age(status_path)))
  data.frame(
    job_id = row$job_id[[1L]],
    target_cell_id = row$target_cell_id[[1L]],
    candidate_role = row$candidate_role[[1L]],
    source_id = row$source_id[[1L]],
    reservoir_seed_id = row$reservoir_seed_id[[1L]],
    state = state,
    pid = pid,
    process_alive = alive,
    phase = progress$phase,
    iterations_completed = completed_iterations,
    iterations_total = progress$total,
    completion_pct = if (is.finite(completed_iterations) && progress$total > 0) {
      100 * completed_iterations / progress$total
    } else if (state == "SUCCESS") 100 else 0,
    seconds_since_activity = age,
    stale = state == "RUNNING" && age > stale_seconds,
    objective_value = if (is.null(status)) NA_real_ else as.numeric(status$objective_value),
    error_message = if (is.null(status) || is.null(status$error_message)) {
      NA_character_
    } else as.character(status$error_message),
    log_path = normalizePath(log_path, winslash = "/", mustWork = FALSE),
    stringsAsFactors = FALSE
  )
})
health <- do.call(rbind, rows)
qdesn_ssv2_write_csv(health, output_path)
counts <- as.list(table(factor(
  health$state, levels = c("PENDING", "RUNNING", "SUCCESS", "FAIL", "INTERRUPTED")
)))
names(counts) <- c("pending", "running", "success", "failed", "interrupted")
summary_path <- sub("[.]csv$", "_summary.json", output_path)
qdesn_ssv2_write_json(list(
  generated_at = as.character(Sys.time()),
  run_tag = run_tag,
  mode = mode,
  jobs = nrow(health),
  counts = counts,
  completed_pct = 100 * sum(health$state == "SUCCESS") / nrow(health),
  stale_running = sum(health$stale),
  failed_or_interrupted = sum(health$state %in% c("FAIL", "INTERRUPTED")),
  health_table = normalizePath(output_path, winslash = "/", mustWork = TRUE),
  calibration_complete = all(health$state == "SUCCESS")
), summary_path)
cat(sprintf(
  "run_tag=%s jobs=%d success=%d running=%d pending=%d failed=%d interrupted=%d stale=%d complete_pct=%.1f\n",
  run_tag, nrow(health), counts$success, counts$running, counts$pending,
  counts$failed, counts$interrupted, sum(health$stale),
  100 * counts$success / nrow(health)
))

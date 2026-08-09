#!/usr/bin/env Rscript

suppressPackageStartupMessages(requireNamespace("jsonlite", quietly = TRUE))

args <- commandArgs(trailingOnly = TRUE)
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
source(file.path(
  repo_root, "validation", "fitforecast_v2", "R",
  "independent_exal_m0_relaunch_v1.R"
))

run_tag <- as.character(get_arg("--run-tag", ""))[1L]
budget <- tolower(as.character(get_arg("--budget", "full"))[1L])
if (!nzchar(run_tag) || !budget %in% c("smoke", "canary", "full")) {
  stop("--run-tag and --budget smoke|canary|full are required.", call. = FALSE)
}
output_dir_arg <- get_arg(
  "--output-dir",
  file.path("reports", "shared_fitforecast_v2_orchestration", run_tag, "health")
)
output_dir <- if (grepl("^/", output_dir_arg)) output_dir_arg else file.path(repo_root, output_dir_arg)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

stub <- qdesn_m0v1_config_stub(repo_root)
plan <- qdesn_m0v1_read_csv(paste0(stub, "_", budget, "_chain_plan.csv"))
health <- qdesn_m0v1_scan_jobs(repo_root, run_tag, plan)
now <- Sys.time()
total_iter <- setNames(plan$n_burn + plan$n_mcmc, plan$job_id)
health$pid <- rep(NA_integer_, nrow(health))
health$process_alive <- rep(FALSE, nrow(health))
health$health_state <- rep("unknown", nrow(health))
health$last_iteration <- rep(0L, nrow(health))
health$total_iterations <- rep(NA_integer_, nrow(health))
health$iteration_percent <- rep(0, nrow(health))
health$evidence_age_seconds <- rep(NA_real_, nrow(health))
health$stale <- rep(FALSE, nrow(health))

for (i in seq_len(nrow(health))) {
  job_root <- qdesn_m0v1_job_root(repo_root, run_tag, health$job_id[[i]])
  started_path <- file.path(job_root, "job_started.json")
  live_path <- file.path(job_root, "logs", "pipeline_child_live.log")
  started <- if (file.exists(started_path)) {
    tryCatch(qdesn_m0v1_read_json(started_path), error = function(e) NULL)
  } else NULL
  pid <- as.integer(started$pid %||% NA_integer_)
  health$pid[[i]] <- pid
  health$process_alive[[i]] <- if (is.finite(pid)) {
    identical(system2("kill", c("-0", as.character(pid)), stdout = FALSE,
                      stderr = FALSE), 0L)
  } else FALSE
  lines <- if (file.exists(live_path)) readLines(live_path, warn = FALSE) else character()
  hits <- regmatches(lines, regexec("(?:burn-in|MCMC) iteration ([0-9]+)", lines))
  iterations <- suppressWarnings(as.integer(vapply(
    hits, function(x) if (length(x) >= 2L) x[[2L]] else NA_character_, character(1L)
  )))
  iterations <- iterations[is.finite(iterations)]
  health$total_iterations[[i]] <- total_iter[[health$job_id[[i]]]]
  health$last_iteration[[i]] <- if (identical(health$status[[i]], "SUCCESS")) {
    health$total_iterations[[i]]
  } else if (length(iterations)) {
    max(iterations)
  } else {
    0L
  }
  health$iteration_percent[[i]] <- 100 * health$last_iteration[[i]] /
    health$total_iterations[[i]]
  evidence_paths <- c(live_path, started_path, file.path(job_root, "job_status.json"))
  evidence_paths <- evidence_paths[file.exists(evidence_paths)]
  age <- if (length(evidence_paths)) {
    as.numeric(difftime(now, max(file.info(evidence_paths)$mtime), units = "secs"))
  } else NA_real_
  health$evidence_age_seconds[[i]] <- age
  health$health_state[[i]] <- qdesn_m0v1_classify_health(
    status = health$status[[i]],
    process_alive = health$process_alive[[i]],
    evidence_age_seconds = age,
    stale_threshold_seconds = 1800
  )
  health$stale[[i]] <- health$health_state[[i]] %in% c("stalled", "interrupted")
}

health <- health[, c(
  "job_id", "budget", "anchor_id", "chain_id", "status", "pid",
  "process_alive", "health_state", "last_iteration", "total_iterations", "iteration_percent",
  "progress_rows", "evidence_age_seconds", "stale", "elapsed_seconds",
  "fit_summary_exists", "forecast_summary_exists", "error_message"
), drop = FALSE]
qdesn_m0v1_write_csv(health, file.path(output_dir, "job_health.csv"))

summary <- list(
  generated_at = as.character(now),
  run_tag = run_tag,
  budget = budget,
  expected_jobs = nrow(plan),
  completed_jobs = sum(health$status == "SUCCESS"),
  failed_jobs = sum(health$status == "FAIL"),
  running_jobs = sum(health$status == "RUNNING"),
  planned_jobs = sum(health$status == "PLANNED"),
  jobs_left = sum(health$status != "SUCCESS"),
  completion_percent = 100 * sum(health$status == "SUCCESS") / nrow(plan),
  active_processes = sum(health$process_alive %in% TRUE),
  progressing_jobs = sum(health$health_state == "progressing"),
  stalled_jobs = sum(health$health_state == "stalled"),
  interrupted_jobs = sum(health$health_state == "interrupted"),
  stale_jobs = sum(health$stale %in% TRUE),
  all_done = all(health$status == "SUCCESS")
)
qdesn_m0v1_write_json(summary, file.path(output_dir, "health_summary.json"))
cat(sprintf(
  "%s %s: %d/%d complete (%.1f%%); %d running; %d failed; %d left; %d stale\n",
  run_tag, budget, summary$completed_jobs, summary$expected_jobs,
  summary$completion_percent, summary$running_jobs, summary$failed_jobs,
  summary$jobs_left, summary$stale_jobs
))

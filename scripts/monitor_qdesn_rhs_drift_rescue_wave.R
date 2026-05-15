#!/usr/bin/env Rscript

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
if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("Package 'jsonlite' is required for this script.", call. = FALSE)
}

`%||%` <- function(a, b) if (is.null(a) || (length(a) == 1L && is.na(a))) b else a

guess_latest_analysis_root <- function() {
  base <- file.path("reports", "qdesn_mcmc_validation", "rhs_drift_rescue_wave")
  if (!dir.exists(base)) return(NULL)
  kids <- list.dirs(base, recursive = FALSE, full.names = TRUE)
  if (!length(kids)) return(NULL)
  sort(kids, decreasing = TRUE)[1L]
}

resolve_run_dir <- function(stage_report_root) {
  if (!dir.exists(stage_report_root)) return(NULL)
  lvl1 <- list.dirs(stage_report_root, recursive = FALSE, full.names = TRUE)
  if (!length(lvl1)) return(NULL)
  # Stage D/E use direct run directories. Stage A/B/C use profile/run nesting.
  direct <- lvl1[grepl("^[0-9]{8}-[0-9]{6}__git-", basename(lvl1))]
  if (length(direct)) return(sort(direct, decreasing = TRUE)[1L])
  nested <- unlist(lapply(lvl1, function(d) {
    list.dirs(d, recursive = FALSE, full.names = TRUE)
  }), use.names = FALSE)
  nested <- nested[grepl("^[0-9]{8}-[0-9]{6}__git-", basename(nested))]
  if (!length(nested)) return(NULL)
  sort(nested, decreasing = TRUE)[1L]
}

read_csv_safe <- function(path) {
  if (!file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  tryCatch(utils::read.csv(path, stringsAsFactors = FALSE), error = function(...) data.frame(stringsAsFactors = FALSE))
}

status_counts <- function(results_run_root) {
  out <- list(total = 0L, pending = 0L, running = 0L, success = 0L, failed = 0L)
  roots_dir <- file.path(results_run_root, "roots")
  if (!dir.exists(roots_dir)) return(out)
  roots <- list.dirs(roots_dir, recursive = FALSE, full.names = TRUE)
  if (!length(roots)) return(out)
  out$total <- length(roots)
  vals <- vapply(roots, function(r) {
    f <- file.path(r, "manifest", "root_status.txt")
    if (!file.exists(f)) return("PENDING")
    x <- trimws(readLines(f, warn = FALSE, n = 1L))
    if (!nzchar(x)) "PENDING" else toupper(x)
  }, character(1L))
  out$pending <- sum(vals == "PENDING")
  out$running <- sum(vals == "RUNNING")
  out$success <- sum(vals == "SUCCESS")
  out$failed <- sum(vals %in% c("FAILED", "FAIL", "ERROR"))
  out
}

compute_snapshot <- function(analysis_root) {
  run_tag <- basename(analysis_root)
  results_root <- file.path(repo_root, "results", "qdesn_mcmc_validation", "rhs_drift_rescue_wave", run_tag)

  stage_d_report_run <- resolve_run_dir(file.path(analysis_root, "stageD_replicates"))
  stage_e_report_run <- resolve_run_dir(file.path(analysis_root, "stageE_broader"))
  stage_d_results_run <- if (is.null(stage_d_report_run)) NULL else file.path(results_root, "stageD_replicates", basename(stage_d_report_run))
  stage_e_results_run <- if (is.null(stage_e_report_run)) NULL else file.path(results_root, "stageE_broader", basename(stage_e_report_run))

  d_counts <- if (is.null(stage_d_results_run)) status_counts("") else status_counts(stage_d_results_run)
  e_counts <- if (is.null(stage_e_results_run)) status_counts("") else status_counts(stage_e_results_run)

  stage_d_summary <- read_csv_safe(file.path(analysis_root, "tables", "stageD_replicate_summary.csv"))
  stage_e_summary <- read_csv_safe(file.path(analysis_root, "tables", "stageE_broader_summary.csv"))
  stage_d_gate_pass <- if (nrow(stage_d_summary)) {
    as.integer(stage_d_summary$n_pair_fail[1] == 0 && stage_d_summary$n_pair_eligible[1] == stage_d_summary$n_pairs[1])
  } else NA_integer_
  stage_e_gate_pass <- if (nrow(stage_e_summary)) {
    trace_unavail <- as.numeric(stage_e_summary$n_trace_unavailable_mcmc_signoff[1] %||% 0) +
      as.numeric(stage_e_summary$n_trace_unavailable_mcmc_unhealthy[1] %||% 0)
    as.integer(stage_e_summary$n_pair_fail[1] == 0 &&
      stage_e_summary$n_pair_eligible[1] == stage_e_summary$n_pairs[1] &&
      trace_unavail == 0)
  } else NA_integer_

  final_decision_path <- file.path(analysis_root, "manifest", "final_decision.json")
  final_status <- "PENDING"
  promote <- NA
  if (file.exists(final_decision_path)) {
    j <- tryCatch(jsonlite::fromJSON(final_decision_path), error = function(...) NULL)
    if (!is.null(j)) {
      final_status <- "READY"
      promote <- isTRUE(j$promote)
    }
  }

  ps_lines <- tryCatch(
    system2("ps", c("-eo", "pid=,cmd="), stdout = TRUE, stderr = FALSE),
    error = function(...) character(0)
  )
  n_running_proc <- sum(grepl("run_qdesn_rhs_drift_rescue_wave.R|pipeline_sim_main.R", ps_lines))

  data.frame(
    checked_at = as.character(Sys.time()),
    run_tag = run_tag,
    n_running_processes = n_running_proc,
    stageD_started = !is.null(stage_d_report_run),
    stageD_roots_total = d_counts$total,
    stageD_success = d_counts$success,
    stageD_running = d_counts$running,
    stageD_pending = d_counts$pending,
    stageD_failed = d_counts$failed,
    stageD_gate_pass = stage_d_gate_pass,
    stageE_started = !is.null(stage_e_report_run),
    stageE_roots_total = e_counts$total,
    stageE_success = e_counts$success,
    stageE_running = e_counts$running,
    stageE_pending = e_counts$pending,
    stageE_failed = e_counts$failed,
    stageE_gate_pass = stage_e_gate_pass,
    final_decision_status = final_status,
    promote = promote,
    stringsAsFactors = FALSE
  )
}

analysis_root <- normalizePath(get_arg("--analysis-root", guess_latest_analysis_root()), winslash = "/", mustWork = TRUE)
poll_seconds <- max(10L, as.integer(get_arg("--poll-seconds", "600"))[1L])
max_checks <- as.integer(get_arg("--max-checks", "-1"))[1L]
once <- has_flag("--once")

monitor_root <- normalizePath(get_arg("--monitor-root", file.path(analysis_root, "monitor")), winslash = "/", mustWork = FALSE)
tables_root <- file.path(monitor_root, "tables")
dir.create(monitor_root, recursive = TRUE, showWarnings = FALSE)
dir.create(tables_root, recursive = TRUE, showWarnings = FALSE)
out_path <- file.path(tables_root, "drift_rescue_live_status.csv")

rows <- list()
i <- 0L
repeat {
  i <- i + 1L
  snap <- compute_snapshot(analysis_root)
  rows[[length(rows) + 1L]] <- snap
  out <- do.call(rbind, rows)
  utils::write.csv(out, out_path, row.names = FALSE)
  print(snap, row.names = FALSE)

  done <- identical(snap$final_decision_status[1L], "READY")
  if (once || done) break
  if (max_checks > 0L && i >= max_checks) break
  Sys.sleep(poll_seconds)
}

cat(sprintf("analysis_root: %s\n", analysis_root))
cat(sprintf("monitor_csv: %s\n", out_path))

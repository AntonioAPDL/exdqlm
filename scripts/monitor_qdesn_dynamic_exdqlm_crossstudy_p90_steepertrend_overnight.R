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
  if (!length(idx)) return(default)
  idx <- idx[1L]
  if (is.na(idx) || idx >= length(args)) return(default)
  args[idx + 1L]
}

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)

resolve_path <- function(path, must_work = FALSE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

`%||%` <- function(a, b) if (is.null(a)) b else a

smoke_run_tag <- as.character(get_arg("--smoke-run-tag", ""))[1L]
if (!nzchar(trimws(smoke_run_tag))) {
  stop("--smoke-run-tag is required.", call. = FALSE)
}

ridge_phase <- as.character(get_arg("--ridge-phase", "ridge_full"))[1L]
sleep_sec <- as.integer(get_arg("--sleep-sec", "600"))[1L]
if (!is.finite(sleep_sec) || sleep_sec < 30L) sleep_sec <- 600L
ridge_session <- as.character(get_arg("--ridge-session", "qdesn_p90_ridge"))[1L]

default_monitor_root <- file.path(
  "reports",
  "qdesn_mcmc_validation",
  "dynamic_exdqlm_crossstudy_p90_steepertrend_validation",
  "overnight_supervisor",
  sprintf(
    "qdesn-p90-overnight-supervisor-%s__git-%s",
    format(Sys.time(), "%Y%m%d-%H%M%S"),
    trimws(system("git rev-parse --short HEAD", intern = TRUE))
  )
)
monitor_root <- resolve_path(get_arg("--monitor-root", default_monitor_root), must_work = FALSE)
health_root <- file.path(monitor_root, "healthchecks")
dir.create(health_root, recursive = TRUE, showWarnings = FALSE)

log_path <- file.path(monitor_root, "supervisor.log")
state_path <- file.path(monitor_root, "supervisor_state.json")
ridge_tag_path <- file.path(monitor_root, "ridge_run_tag.txt")

append_log <- function(...) {
  line <- paste0("[", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), "] ", paste(..., collapse = ""))
  write(line, file = log_path, append = TRUE)
}

write_state <- function(extra = list()) {
  ridge_tag <- if (file.exists(ridge_tag_path)) {
    raw <- trimws(readLines(ridge_tag_path, warn = FALSE, n = 1L))
    if (length(raw) && nzchar(raw[1L]) && !is.na(raw[1L])) raw[1L] else NA_character_
  } else {
    NA_character_
  }
  payload <- utils::modifyList(list(
    generated_at = as.character(Sys.time()),
    smoke_run_tag = smoke_run_tag,
    ridge_phase = ridge_phase,
    ridge_session = ridge_session,
    ridge_run_tag = ridge_tag,
    sleep_sec = sleep_sec,
    monitor_root = monitor_root
  ), extra)
  jsonlite::write_json(payload, state_path, auto_unbox = TRUE, pretty = TRUE, null = "null")
}

run_healthcheck <- function(run_tag) {
  tryCatch(
    system2(
      "Rscript",
      c(
        file.path("scripts", "healthcheck_qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_validation.R"),
        "--run-tag", run_tag
      ),
      stdout = TRUE,
      stderr = TRUE
    ),
    error = function(e) sprintf("ERROR: %s", conditionMessage(e))
  )
}

launch_ridge <- function() {
  tryCatch(
    system2(
      "Rscript",
      c(
        file.path("scripts", "launch_qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_validation.R"),
        "--phase", ridge_phase,
        "--tmux-session", ridge_session
      ),
      stdout = TRUE,
      stderr = TRUE
    ),
    error = function(e) sprintf("ERROR: %s", conditionMessage(e))
  )
}

parse_run_tag <- function(lines) {
  hit <- grep("^Run tag: ", lines, value = TRUE)
  if (!length(hit)) return(NA_character_)
  trimws(sub("^Run tag: ", "", hit[length(hit)]))
}

write_health_snapshot <- function(prefix, lines) {
  ts <- format(Sys.time(), "%Y%m%d-%H%M%S")
  out_path <- file.path(health_root, sprintf("%s_%s.txt", prefix, ts))
  writeLines(lines, out_path)
  out_path
}

smoke_clean_success <- function(lines) {
  any(grepl("Campaign completed manifest present: TRUE", lines, fixed = TRUE)) &&
    any(grepl("SUCCESS roots: 1 (100.0%)", lines, fixed = TRUE)) &&
    any(grepl("FAIL roots: 0 (0.0%)", lines, fixed = TRUE))
}

campaign_finished <- function(lines) {
  any(grepl("Campaign completed manifest present: TRUE", lines, fixed = TRUE))
}

append_log("overnight supervisor started")
write_state(list(status = "started"))

repeat {
  smoke_lines <- run_healthcheck(smoke_run_tag)
  smoke_path <- write_health_snapshot("smoke", smoke_lines)
  append_log("smoke snapshot written: ", smoke_path)

  ridge_tag <- if (file.exists(ridge_tag_path)) {
    raw <- trimws(readLines(ridge_tag_path, warn = FALSE, n = 1L))
    if (length(raw) && nzchar(raw[1L]) && !is.na(raw[1L])) raw[1L] else ""
  } else {
    ""
  }

  if (!nzchar(ridge_tag)) {
    if (smoke_clean_success(smoke_lines)) {
      append_log("smoke completed cleanly; launching ridge phase ", ridge_phase)
      launch_lines <- launch_ridge()
      launch_path <- write_health_snapshot("ridge_launch", launch_lines)
      new_ridge_tag <- parse_run_tag(launch_lines)
      if (!nzchar(new_ridge_tag %||% "")) {
        append_log("ridge launch failed to return a run tag; stopping supervisor")
        write_state(list(status = "ridge_launch_failed", ridge_launch_log = launch_path))
        break
      }
      writeLines(new_ridge_tag, ridge_tag_path)
      append_log("ridge launched: ", new_ridge_tag)
      write_state(list(status = "ridge_launched", ridge_launch_log = launch_path))
    } else if (campaign_finished(smoke_lines)) {
      append_log("smoke finished without clean success; ridge will not be launched")
      write_state(list(status = "smoke_finished_unhealthy"))
      break
    } else {
      write_state(list(status = "smoke_running"))
    }
  } else {
    ridge_lines <- run_healthcheck(ridge_tag)
    ridge_path <- write_health_snapshot("ridge", ridge_lines)
    append_log("ridge snapshot written: ", ridge_path)
    if (campaign_finished(ridge_lines)) {
      append_log("ridge completed; supervisor exiting")
      write_state(list(status = "ridge_completed"))
      break
    }
    write_state(list(status = "ridge_running"))
  }

  Sys.sleep(sleep_sec)
}

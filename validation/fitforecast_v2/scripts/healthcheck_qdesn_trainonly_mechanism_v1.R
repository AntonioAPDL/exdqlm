#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx) || idx[[1L]] >= length(args)) return(default)
  args[[idx[[1L]] + 1L]]
}
`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
setwd(repo_root)
state_parent <- file.path(repo_root, "reports", "shared_fitforecast_v2_orchestration")
run_id <- as.character(get_arg("--run-id", ""))[1L]
if (!nzchar(run_id)) {
  candidates <- list.dirs(state_parent, recursive = FALSE, full.names = TRUE)
  candidates <- candidates[grepl("/qdesn_trainonly_mechanism_v1_[0-9]{8}_[0-9]{6}$", candidates)]
  if (!length(candidates)) stop("No train-only mechanism v1 orchestration directory found.", call. = FALSE)
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
status_count <- function(tab, value) if (value %in% names(tab)) as.integer(tab[[value]]) else 0L

env <- read_env(file.path(state_root, "run_tags.env"))
stages <- read_csv_safe(file.path(state_root, "stage_status.csv"))
bundle_index <- read_csv_safe(file.path(repo_root, "config", "validation", "qdesn_dynamic_fitforecast_v2_500obs_trainonly_mechanism_v1_bundle_index.csv"))
rows <- lapply(seq_len(nrow(bundle_index)), function(i) {
  b <- bundle_index[i, , drop = FALSE]
  id <- as.character(b$bundle_id[[1L]])
  tag <- unname(env[[paste0(toupper(id), "_RUN_TAG")]] %||% "")
  defaults <- yaml::read_yaml(as.character(b$defaults_path[[1L]]))
  outer <- file.path(repo_root, defaults$campaign$results_root, tag)
  fit_paths <- if (dir.exists(outer)) list.files(outer, pattern = "^fit_summary_row[.]csv$", recursive = TRUE, full.names = TRUE) else character()
  h_paths <- if (dir.exists(outer)) list.files(outer, pattern = "^forecast_horizon_summary[.]csv$", recursive = TRUE, full.names = TRUE) else character()
  heavy <- if (dir.exists(outer)) list.files(outer, pattern = "[.](rds|rda|RData)$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE) else character()
  status <- count_status(outer)
  progress <- if (dir.exists(outer)) list.files(outer, pattern = "progress_trace.*[.]csv$|fit_status[.]txt$|root_status[.]txt$", recursive = TRUE, full.names = TRUE) else character()
  latest <- if (length(progress)) max(file.info(progress)$mtime, na.rm = TRUE) else as.POSIXct(NA)
  age <- if (!is.na(latest)) as.numeric(difftime(Sys.time(), latest, units = "mins")) else NA_real_
  success <- status_count(status, "SUCCESS")
  failed <- status_count(status, "FAIL") + status_count(status, "FAILED")
  expected <- as.integer(b$expected_specs[[1L]])
  finished <- length(unique(vapply(fit_paths, function(path) {
    x <- tryCatch(utils::read.csv(path, nrows = 1L, stringsAsFactors = FALSE), error = function(e) NULL)
    if (is.null(x) || !nrow(x) || !"spec_id" %in% names(x)) path else as.character(x$spec_id[[1L]])
  }, character(1L))))
  data.frame(
    bundle = id,
    expected = expected,
    finished = finished,
    remaining = max(0L, expected - finished),
    percent = 100 * finished / expected,
    success = success,
    failed = failed,
    fit_summaries = length(fit_paths),
    horizon_files = length(h_paths),
    heavy_payloads = length(heavy),
    latest_progress_minutes = age,
    run_tag = tag,
    stringsAsFactors = FALSE
  )
})
rows <- do.call(rbind, rows)

stamp <- sub("^qdesn_trainonly_mechanism_v1_", "", run_id)
session <- paste0("ffv2_qdesn_tmv1_", stamp)
tmux_live <- identical(suppressWarnings(system2("tmux", c("has-session", "-t", session), stdout = FALSE, stderr = FALSE)), 0L)
latest_stage <- if (nrow(stages)) as.character(tail(stages$stage, 1L)) else "initializing"
latest_status <- if (nrow(stages)) as.character(tail(stages$status, 1L)) else "UNKNOWN"
total_expected <- sum(rows$expected)
total_finished <- sum(rows$finished)

cat(sprintf("Snapshot: %s\n", format(Sys.time(), tz = "UTC", usetz = TRUE)))
cat(sprintf("Run ID: %s\n", run_id))
cat(sprintf("tmux: %s (live=%s)\n", session, tmux_live))
cat(sprintf("Latest stage/status: %s / %s\n\n", latest_stage, latest_status))
cat("| Bundle | Finished | Remaining | Success | Failed | Fit summaries | H1000 files | Heavy | Latest progress |\n")
cat("|---|---:|---:|---:|---:|---:|---:|---:|---:|\n")
for (i in seq_len(nrow(rows))) {
  x <- rows[i, , drop = FALSE]
  age <- if (is.finite(x$latest_progress_minutes)) sprintf("%.1f min", x$latest_progress_minutes) else "NA"
  cat(sprintf("| %s | %d/%d (%.1f%%) | %d | %d | %d | %d | %d | %d | %s |\n",
    x$bundle, x$finished, x$expected, x$percent, x$remaining, x$success, x$failed,
    x$fit_summaries, x$horizon_files, x$heavy_payloads, age))
}
cat(sprintf("| **Total** | **%d/%d (%.1f%%)** | **%d** | **%d** | **%d** | **%d** | **%d** | **%d** |  |\n",
  total_finished, total_expected, 100 * total_finished / total_expected,
  total_expected - total_finished, sum(rows$success), sum(rows$failed),
  sum(rows$fit_summaries), sum(rows$horizon_files), sum(rows$heavy_payloads)))
cat(sprintf("\nState root: `%s`\n", normalizePath(state_root, winslash = "/", mustWork = TRUE)))

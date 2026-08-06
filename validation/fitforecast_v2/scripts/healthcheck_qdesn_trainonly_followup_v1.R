#!/usr/bin/env Rscript

suppressPackageStartupMessages(requireNamespace("yaml", quietly = TRUE))
args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) { i <- which(args == flag); if (!length(i) || i[[1L]] >= length(args)) default else args[[i[[1L]] + 1L]] }
`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x
repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
state_parent <- file.path(repo_root, "reports", "shared_fitforecast_v2_orchestration")
run_id <- as.character(get_arg("--run-id", ""))[1L]
if (!nzchar(run_id)) {
  x <- list.dirs(state_parent, recursive = FALSE, full.names = TRUE); x <- x[grepl("/qdesn_trainonly_followup_v1_[0-9]{8}_[0-9]{6}$", x)]
  if (!length(x)) stop("No follow-up v1 run found.", call. = FALSE)
  run_id <- basename(x[[which.max(file.info(x)$mtime)]])
}
state_root <- file.path(state_parent, run_id)
read_csv <- function(path) if (file.exists(path) && file.info(path)$size > 0) tryCatch(utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE), error = function(e) data.frame()) else data.frame()
read_env <- function(path) { if (!file.exists(path)) return(character()); x <- readLines(path, warn = FALSE); x <- x[grepl("^[A-Z0-9_]+=", x)]; y <- sub("^[^=]+=", "", x); names(y) <- sub("=.*$", "", x); y }
status_counts <- function(root) {
  p <- if (dir.exists(root)) list.files(root, "^root_status[.]txt$", recursive = TRUE, full.names = TRUE) else character()
  v <- unlist(lapply(p, function(z) readLines(z, warn = FALSE, n = 1L))); if (length(v)) table(v) else integer()
}
env <- read_env(file.path(state_root, "run_tags.env")); stages <- read_csv(file.path(state_root, "stage_status.csv"))
index <- read_csv(file.path(repo_root, "config", "validation", "qdesn_dynamic_fitforecast_v2_500obs_trainonly_followup_v1_bundle_index.csv"))
rows <- lapply(seq_len(nrow(index)), function(i) {
  b <- index[i, , drop = FALSE]; id <- b$bundle_id[[1L]]; d <- yaml::read_yaml(b$defaults_path[[1L]])
  tag <- unname(env[[paste0(toupper(id), "_RUN_TAG")]] %||% ""); root <- file.path(repo_root, d$campaign$results_root, tag)
  fits <- if (dir.exists(root)) list.files(root, "^fit_summary_row[.]csv$", recursive = TRUE, full.names = TRUE) else character()
  horizons <- if (dir.exists(root)) list.files(root, "^forecast_horizon_summary[.]csv$", recursive = TRUE, full.names = TRUE) else character()
  heavy <- if (dir.exists(root)) list.files(root, "[.](rds|rda|RData)$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE) else character()
  progress <- if (dir.exists(root)) list.files(root, "progress_trace.*[.]csv$|root_status[.]txt$", recursive = TRUE, full.names = TRUE) else character()
  age <- if (length(progress)) as.numeric(difftime(Sys.time(), max(file.info(progress)$mtime), units = "mins")) else NA_real_
  st <- status_counts(root); n <- as.integer(b$expected_specs[[1L]]); done <- length(fits)
  data.frame(bundle = id, expected = n, done = done, remaining = max(0L, n - done), percent = 100 * done/n,
             success = if ("SUCCESS" %in% names(st)) as.integer(st[["SUCCESS"]]) else 0L,
             failed = sum(st[names(st) %in% c("FAIL", "FAILED")]), horizons = length(horizons), heavy = length(heavy),
             progress_age_min = age, run_tag = tag, stringsAsFactors = FALSE)
})
rows <- do.call(rbind, rows)
comp_index <- read_csv(file.path(state_root, "comparator_index.csv"))
if (nrow(comp_index)) for (i in seq_len(nrow(comp_index))) {
  root <- comp_index$run_root[[i]]; metrics <- if (dir.exists(file.path(root, "metrics"))) list.files(file.path(root, "metrics"), "[.]csv$", full.names = TRUE) else character()
  heavy <- if (dir.exists(root)) list.files(root, "[.](rds|rda|RData)$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE) else character()
  statuses <- if (dir.exists(file.path(root, "rows"))) list.files(file.path(root, "rows"), "status[.]csv$", full.names = TRUE) else character()
  failed <- sum(vapply(statuses, function(p) { x <- read_csv(p); nrow(x) && any(tolower(as.character(x$status)) %in% c("failed", "error")) }, logical(1L)))
  rows <- rbind(rows, data.frame(bundle = paste0("comparator_", comp_index$source_role[[i]]), expected = 2L,
    done = length(metrics), remaining = max(0L, 2L-length(metrics)), percent = 50*length(metrics), success = max(0L, length(metrics)-failed),
    failed = failed, horizons = length(metrics), heavy = length(heavy), progress_age_min = NA_real_, run_tag = comp_index$run_tag[[i]]))
}
stamp <- sub("^qdesn_trainonly_followup_v1_", "", run_id); session <- paste0("ffv2_qdesn_tfv1_", stamp)
live <- system2("tmux", c("has-session", "-t", session), stdout = FALSE, stderr = FALSE) == 0L
stage <- if (nrow(stages)) tail(stages$stage, 1L) else "initializing"; status <- if (nrow(stages)) tail(stages$status, 1L) else "UNKNOWN"
cat(sprintf("Snapshot: %s\nRun ID: %s\ntmux: %s (live=%s)\nLatest stage/status: %s / %s\n\n", format(Sys.time(), tz="UTC", usetz=TRUE), run_id, session, live, stage, status))
cat("| Bundle | Done | Left | Success | Failed | H/metrics | Heavy | Latest progress |\n|---|---:|---:|---:|---:|---:|---:|---:|\n")
for (i in seq_len(nrow(rows))) { x <- rows[i,]; age <- if (is.finite(x$progress_age_min)) sprintf("%.1f min", x$progress_age_min) else "NA"; cat(sprintf("| %s | %d/%d (%.1f%%) | %d | %d | %d | %d | %d | %s |\n", x$bundle, x$done, x$expected, x$percent, x$remaining, x$success, x$failed, x$horizons, x$heavy, age)) }
cat(sprintf("| **Total** | **%d/%d (%.1f%%)** | **%d** | **%d** | **%d** | **%d** | **%d** |  |\n", sum(rows$done), sum(rows$expected), 100*sum(rows$done)/sum(rows$expected), sum(rows$remaining), sum(rows$success), sum(rows$failed), sum(rows$horizons), sum(rows$heavy)))
cat(sprintf("\nState root: `%s`\n", state_root))

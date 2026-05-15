#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
has_flag <- function(flag) any(args == flag)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) && idx < length(args)) args[idx + 1L] else default
}
`%||%` <- function(a, b) if (is.null(a)) b else a

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)

resolve_path <- function(path, must_work = TRUE) {
  if (is.null(path)) return(NULL)
  raw <- as.character(path)[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

read_json_safe <- function(path) {
  if (!file.exists(path)) return(NULL)
  jsonlite::fromJSON(path, simplifyVector = TRUE)
}

read_csv_safe <- function(path) {
  if (!file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  utils::read.csv(path, stringsAsFactors = FALSE)
}

report_root <- resolve_path(get_arg("--report-root", NULL), must_work = TRUE)
if (is.null(report_root)) {
  stop("--report-root is required.", call. = FALSE)
}

campaign_manifest_path <- file.path(report_root, "manifest", "campaign_manifest.json")
campaign_manifest <- read_json_safe(campaign_manifest_path)
results_root <- resolve_path(get_arg("--results-root", campaign_manifest$results_root %||% NULL), must_work = TRUE)
if (is.null(results_root)) {
  stop("Could not resolve results_root. Pass --results-root explicitly or ensure campaign_manifest has results_root.", call. = FALSE)
}

progress_path <- file.path(report_root, "tables", "campaign_progress.csv")
progress <- read_csv_safe(progress_path)
progress_ids <- unique(as.character(progress$root_id %||% character(0)))

roots_dir <- file.path(results_root, "roots")
root_dirs <- if (dir.exists(roots_dir)) {
  list.dirs(roots_dir, recursive = FALSE, full.names = TRUE)
} else {
  character(0)
}
root_ids <- basename(root_dirs)

rows <- lapply(root_dirs, function(root_dir) {
  root_id <- basename(root_dir)
  root_status_path <- file.path(root_dir, "manifest", "root_status.txt")
  method_status_path <- file.path(root_dir, "manifest", "method_status.csv")

  root_status <- if (file.exists(root_status_path)) trimws(paste(readLines(root_status_path, warn = FALSE), collapse = " ")) else NA_character_
  method_status <- read_csv_safe(method_status_path)
  vb_status <- NA_character_
  mcmc_status <- NA_character_
  if (nrow(method_status)) {
    vb_idx <- which(as.character(method_status$method) == "vb")
    mcmc_idx <- which(as.character(method_status$method) == "mcmc")
    if (length(vb_idx)) vb_status <- as.character(method_status$status[vb_idx[1L]])
    if (length(mcmc_idx)) mcmc_status <- as.character(method_status$status[mcmc_idx[1L]])
  }

  data.frame(
    root_id = root_id,
    in_campaign_progress = root_id %in% progress_ids,
    root_status = root_status,
    vb_status = vb_status,
    mcmc_status = mcmc_status,
    stringsAsFactors = FALSE
  )
})

detail_df <- if (length(rows)) do.call(rbind, rows) else data.frame(
  root_id = character(0),
  in_campaign_progress = logical(0),
  root_status = character(0),
  vb_status = character(0),
  mcmc_status = character(0),
  stringsAsFactors = FALSE
)

pending_root_ids <- setdiff(root_ids, progress_ids)
running_like <- detail_df$root_status %in% c("RUNNING", "", NA_character_)
all_root_rows_closed <- nrow(detail_df) == 0L || !any(running_like, na.rm = TRUE)
can_mark_completed <- length(pending_root_ids) == 0L && all_root_rows_closed && nrow(progress) > 0L

campaign_completed_path <- file.path(report_root, "manifest", "campaign_completed.json")
campaign_completed_exists <- file.exists(campaign_completed_path)

summary_df <- data.frame(
  report_root = report_root,
  results_root = results_root,
  n_roots_results = length(root_ids),
  n_roots_progress = length(progress_ids),
  n_pending_roots = length(pending_root_ids),
  all_root_rows_closed = all_root_rows_closed,
  campaign_completed_exists = campaign_completed_exists,
  can_mark_completed = can_mark_completed,
  stringsAsFactors = FALSE
)

tables_dir <- file.path(report_root, "tables")
if (!dir.exists(tables_dir)) dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(detail_df, file.path(tables_dir, "campaign_metadata_reconcile.csv"), row.names = FALSE)
utils::write.csv(summary_df, file.path(tables_dir, "campaign_metadata_reconcile_summary.csv"), row.names = FALSE)

summary_lines <- c(
  "# QDESN Campaign Metadata Reconciliation",
  "",
  sprintf("- report_root: `%s`", report_root),
  sprintf("- results_root: `%s`", results_root),
  sprintf("- n_roots_results: `%d`", length(root_ids)),
  sprintf("- n_roots_progress: `%d`", length(progress_ids)),
  sprintf("- n_pending_roots: `%d`", length(pending_root_ids)),
  sprintf("- all_root_rows_closed: `%s`", if (all_root_rows_closed) "true" else "false"),
  sprintf("- campaign_completed_exists: `%s`", if (campaign_completed_exists) "true" else "false"),
  sprintf("- can_mark_completed: `%s`", if (can_mark_completed) "true" else "false")
)

if (length(pending_root_ids)) {
  summary_lines <- c(summary_lines, "", "## Pending Roots", "")
  summary_lines <- c(summary_lines, paste0("- `", pending_root_ids, "`"))
}

writeLines(summary_lines, file.path(report_root, "campaign_metadata_reconcile.md"))

if (has_flag("--apply") && can_mark_completed && !campaign_completed_exists) {
  payload <- list(
    finished_at = as.character(Sys.time()),
    results_root = results_root,
    report_root = report_root,
    n_roots = as.integer(length(progress_ids)),
    n_methods = if ("n_methods" %in% names(progress)) as.integer(sum(as.integer(progress$n_methods), na.rm = TRUE)) else NA_integer_,
    reconciled_by = "scripts/reconcile_qdesn_validation_campaign_status.R"
  )
  jsonlite::write_json(payload, campaign_completed_path, auto_unbox = TRUE, pretty = TRUE, null = "null")
  cat(sprintf("Wrote campaign_completed.json via reconciliation: %s\n", campaign_completed_path))
} else if (has_flag("--apply") && campaign_completed_exists) {
  cat(sprintf("campaign_completed.json already present: %s\n", campaign_completed_path))
} else if (has_flag("--apply") && !can_mark_completed) {
  cat("Reconciliation indicates campaign is not complete; did not write campaign_completed.json.\n")
}

cat(sprintf("Reconciliation summary written under: %s\n", report_root))

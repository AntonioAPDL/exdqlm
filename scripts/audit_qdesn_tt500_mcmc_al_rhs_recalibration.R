#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite", "pkgload")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx)) return(default)
  idx <- idx[[1L]]
  if (idx >= length(args)) return(default)
  args[[idx + 1L]]
}
has_flag <- function(flag) any(args == flag)
`%||%` <- function(a, b) if (is.null(a)) b else a

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}
int_arg <- function(flag, default) {
  val <- suppressWarnings(as.integer(get_arg(flag, as.character(default)))[1L])
  if (is.finite(val)) val else as.integer(default)
}

report_root <- resolve_path(get_arg("--report-root", ""), must_work = FALSE)
results_root <- resolve_path(get_arg("--results-root", ""), must_work = FALSE)
out_dir <- resolve_path(get_arg("--out-dir", ""), must_work = FALSE)
strict <- has_flag("--strict")
require_rankings <- has_flag("--require-rankings")

audit <- exdqlm:::qdesn_dynamic_fitforecast_write_campaign_audit(
  results_root = results_root,
  report_root = report_root,
  out_dir = out_dir,
  expected_roots = int_arg("--expected-roots", 9L),
  expected_lead_rows = int_arg("--expected-lead-rows", 30L),
  expected_rolling_rows = int_arg("--expected-rolling-rows", 1000L),
  expected_final_origin = int_arg("--expected-final-origin", 9990L),
  expected_final_origin_rows = int_arg("--expected-final-origin-rows", 10L),
  require_rankings = require_rankings,
  method_dir_name = "mcmc_al",
  strict = strict
)

summary <- audit$summary
cat(sprintf("summary_csv: %s\n", audit$output_paths$summary))
cat(sprintf("root_audit_csv: %s\n", audit$output_paths$root_audit))
cat(sprintf("report_md: %s\n", audit$output_paths$report))
cat(sprintf("manifest: %s\n", audit$output_paths$manifest))
cat(sprintf(
  "observed=%d success=%d running=%d fail=%d strict_ready=%s\n",
  as.integer(summary$observed_roots[[1L]]),
  as.integer(summary$n_success[[1L]]),
  as.integer(summary$n_running[[1L]]),
  as.integer(summary$n_fail[[1L]]),
  as.character(summary$strict_ready[[1L]])
))
if (isTRUE(strict) && !isTRUE(summary$strict_ready[[1L]])) {
  quit(status = 1L, save = "no")
}
quit(status = 0L, save = "no")

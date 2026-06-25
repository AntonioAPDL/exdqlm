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

report_root <- resolve_path(get_arg("--report-root", ""), must_work = FALSE)
fit_summary_path <- get_arg("--fit-summary", NULL)
if (is.null(fit_summary_path) || !nzchar(trimws(fit_summary_path))) {
  if (is.null(report_root) || !nzchar(report_root)) {
    stop("Supply either --report-root or --fit-summary.", call. = FALSE)
  }
  fit_summary_path <- file.path(report_root, "tables", "campaign_fit_summary.csv")
}
fit_summary_path <- resolve_path(fit_summary_path, must_work = TRUE)
if (is.null(report_root) || !nzchar(report_root)) {
  report_root <- dirname(dirname(fit_summary_path))
}
out_dir <- resolve_path(get_arg("--out-dir", report_root), must_work = FALSE)
top_n <- suppressWarnings(as.integer(get_arg("--top-n", "15"))[1L])
if (!is.finite(top_n) || top_n < 1L) top_n <- 15L

rank_obj <- exdqlm:::qdesn_dynamic_fitforecast_write_screen_ranking(
  fit_summary_path = fit_summary_path,
  report_root = report_root,
  out_dir = out_dir,
  top_n = top_n
)

cat(sprintf("fit_forecast_summary: %s\n", rank_obj$output_paths$fit_forecast_summary))
cat(sprintf("profile_cell_summary: %s\n", rank_obj$output_paths$profile_cell_summary))
cat(sprintf("profile_ranking: %s\n", rank_obj$output_paths$profile_ranking))
cat(sprintf("summary: %s\n", rank_obj$output_paths$summary))
cat(sprintf("manifest: %s\n", rank_obj$output_paths$manifest))
if (has_flag("--print-top")) {
  print(utils::head(rank_obj$profile_ranking, top_n))
}

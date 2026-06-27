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
fit_forecast_summary <- get_arg("--fit-forecast-summary", NULL)
if (is.null(fit_forecast_summary) || !nzchar(trimws(fit_forecast_summary))) {
  if (is.null(report_root) || !nzchar(report_root)) {
    stop("Supply either --report-root or --fit-forecast-summary.", call. = FALSE)
  }
  fit_forecast_summary <- file.path(report_root, "tables", "qdesn_tt500_vb_screen_fit_forecast_summary.csv")
}
fit_forecast_summary <- resolve_path(fit_forecast_summary, must_work = TRUE)
if (is.null(report_root) || !nzchar(report_root)) {
  report_root <- dirname(dirname(fit_forecast_summary))
}

baseline_path <- get_arg(
  "--baseline",
  "/data/jaguir26/local/src/Article-Q-DESN/tables/qdesn_validation_tt500_final_summary.csv"
)
baseline_path <- resolve_path(baseline_path, must_work = TRUE)
out_dir <- resolve_path(get_arg("--out-dir", report_root), must_work = FALSE)
top_n <- suppressWarnings(as.integer(get_arg("--top-n", "20"))[1L])
if (!is.finite(top_n) || top_n < 1L) top_n <- 20L

rank_obj <- exdqlm:::qdesn_dynamic_fitforecast_rank_screen_against_vb_baseline(
  fit_forecast_summary_path = fit_forecast_summary,
  baseline_path = baseline_path,
  out_dir = out_dir,
  fit_size = 500L,
  top_n = top_n
)

cat(sprintf("baseline_targets: %s\n", rank_obj$output_paths$baseline))
cat(sprintf("cell_summary: %s\n", rank_obj$output_paths$cell_summary))
cat(sprintf("profile_ranking: %s\n", rank_obj$output_paths$profile_ranking))
cat(sprintf("summary: %s\n", rank_obj$output_paths$summary))
cat(sprintf("manifest: %s\n", rank_obj$output_paths$manifest))

#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("pkgload", "jsonlite")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) && idx < length(args)) args[idx + 1L] else default
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

defaults_path <- resolve_path(
  get_arg("--defaults", file.path("config", "validation", "qdesn_mcmc_compare_rhsns_stageP_defaults.yaml")),
  must_work = TRUE
)
full_grid_path <- resolve_path(
  get_arg("--full-grid", file.path("config", "validation", "qdesn_rhsns_stageP_expansion_grid.csv")),
  must_work = TRUE
)
ridge_grid_path <- resolve_path(
  get_arg("--ridge-grid", file.path("config", "validation", "qdesn_ridge_stageP_anchor_grid.csv")),
  must_work = TRUE
)

workers_full <- as.integer(get_arg("--workers-full", "12"))[1L]
workers_ridge <- as.integer(get_arg("--workers-ridge", "8"))[1L]
if (!is.finite(workers_full) || workers_full < 1L) workers_full <- 1L
if (!is.finite(workers_ridge) || workers_ridge < 1L) workers_ridge <- 1L

create_plots <- !has_flag("--no-plots")
verbose <- !has_flag("--quiet")
run_ridge <- !has_flag("--skip-ridge")

defaults <- exdqlm:::qdesn_validation_load_defaults(defaults_path)
campaign_cfg <- defaults$campaign %||% list()
base_results_root <- resolve_path(
  campaign_cfg$results_root %||% file.path("results", "qdesn_mcmc_validation", "rhsns_stageP_wave"),
  must_work = FALSE
)
base_report_root <- resolve_path(
  campaign_cfg$reports_root %||% file.path("reports", "qdesn_mcmc_validation", "rhsns_stageP_wave"),
  must_work = FALSE
)

git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
run_tag <- get_arg("--run-tag", sprintf("stageP-%s__git-%s", format(Sys.time(), "%Y%m%d-%H%M%S"), git_sha))
wave_results_root <- file.path(base_results_root, run_tag)
wave_report_root <- file.path(base_report_root, run_tag)
dir.create(wave_results_root, recursive = TRUE, showWarnings = FALSE)
dir.create(wave_report_root, recursive = TRUE, showWarnings = FALSE)

if (isTRUE(verbose)) {
  cat(sprintf("[stageP] defaults: %s\n", defaults_path))
  cat(sprintf("[stageP] full grid: %s\n", full_grid_path))
  cat(sprintf("[stageP] ridge grid: %s\n", ridge_grid_path))
  cat(sprintf("[stageP] run tag: %s\n", run_tag))
  cat(sprintf("[stageP] workers full=%d | ridge=%d\n", workers_full, workers_ridge))
}

run_arm <- function(label, grid_path, workers) {
  if (isTRUE(verbose)) cat(sprintf("[stageP] launch %s\n", label))
  out <- exdqlm:::qdesn_validation_run_campaign(
    grid_path = grid_path,
    defaults_path = defaults_path,
    results_root = file.path(wave_results_root, label),
    report_root = file.path(wave_report_root, label),
    create_plots = create_plots,
    verbose = verbose,
    workers = workers
  )
  out
}

rhsns_full <- run_arm("rhsns_full", full_grid_path, workers_full)
ridge_anchor <- NULL
if (isTRUE(run_ridge)) {
  ridge_anchor <- run_arm("ridge_anchor", ridge_grid_path, workers_ridge)
}

read_csv_safe <- function(path) {
  if (!file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  utils::read.csv(path, stringsAsFactors = FALSE)
}

summarize_campaign <- function(label, run_obj) {
  report_root <- run_obj$report_root
  status_path <- file.path(report_root, "tables", "campaign_status.csv")
  method_path <- file.path(report_root, "tables", "campaign_method_summary.csv")
  status_df <- read_csv_safe(status_path)
  method_df <- read_csv_safe(method_path)
  if (!nrow(status_df)) status_df <- data.frame(n_roots = NA_integer_, n_root_success = NA_integer_, n_root_fail = NA_integer_, n_method_rows = nrow(method_df), stringsAsFactors = FALSE)
  signoff_tab <- if ("signoff_grade" %in% names(method_df)) table(method_df$signoff_grade) else integer(0)
  eligible_true <- if ("comparison_eligible" %in% names(method_df)) sum(method_df$comparison_eligible %in% TRUE, na.rm = TRUE) else NA_integer_
  collapse_true <- if ("rhs_collapse_flag" %in% names(method_df)) sum(method_df$rhs_collapse_flag %in% TRUE, na.rm = TRUE) else NA_integer_
  unhealthy_true <- if ("unhealthy" %in% names(method_df)) sum(method_df$unhealthy %in% TRUE, na.rm = TRUE) else NA_integer_
  data.frame(
    arm = label,
    report_root = report_root,
    results_root = run_obj$results_root,
    n_roots = as.integer(status_df$n_roots[1]),
    n_root_success = as.integer(status_df$n_root_success[1]),
    n_root_fail = as.integer(status_df$n_root_fail[1]),
    n_method_rows = as.integer(status_df$n_method_rows[1]),
    signoff_pass = if ("PASS" %in% names(signoff_tab)) as.integer(signoff_tab[["PASS"]]) else 0L,
    signoff_warn = if ("WARN" %in% names(signoff_tab)) as.integer(signoff_tab[["WARN"]]) else 0L,
    signoff_fail = if ("FAIL" %in% names(signoff_tab)) as.integer(signoff_tab[["FAIL"]]) else 0L,
    eligible_true = as.integer(eligible_true),
    collapse_true = as.integer(collapse_true),
    unhealthy_true = as.integer(unhealthy_true),
    stringsAsFactors = FALSE
  )
}

rows <- list(summarize_campaign("rhsns_full", rhsns_full))
if (!is.null(ridge_anchor)) rows[[length(rows) + 1L]] <- summarize_campaign("ridge_anchor", ridge_anchor)
summary_df <- do.call(rbind, rows)

summary_dir <- file.path(wave_report_root, "summary")
dir.create(summary_dir, recursive = TRUE, showWarnings = FALSE)
summary_csv <- file.path(summary_dir, "stageP_wave_summary.csv")
utils::write.csv(summary_df, summary_csv, row.names = FALSE)

summary_md <- file.path(summary_dir, "stageP_wave_summary.md")
md_lines <- c(
  "# Stage-P Wave Summary",
  "",
  sprintf("- run_tag: `%s`", run_tag),
  sprintf("- defaults: `%s`", defaults_path),
  sprintf("- rhsns_full_grid: `%s`", full_grid_path),
  sprintf("- ridge_anchor_grid: `%s`", ridge_grid_path),
  sprintf("- workers_full: `%d`", workers_full),
  sprintf("- workers_ridge: `%d`", workers_ridge),
  "",
  exdqlm:::.qdesn_validation_df_to_markdown(summary_df)
)
writeLines(md_lines, summary_md)

manifest <- list(
  generated_at = as.character(Sys.time()),
  run_tag = run_tag,
  defaults_path = defaults_path,
  full_grid_path = full_grid_path,
  ridge_grid_path = ridge_grid_path,
  workers_full = workers_full,
  workers_ridge = workers_ridge,
  rhsns_full = list(results_root = rhsns_full$results_root, report_root = rhsns_full$report_root),
  ridge_anchor = if (!is.null(ridge_anchor)) list(results_root = ridge_anchor$results_root, report_root = ridge_anchor$report_root) else NULL,
  summary_csv = summary_csv,
  summary_md = summary_md
)
jsonlite::write_json(manifest, file.path(summary_dir, "stageP_wave_manifest.json"), pretty = TRUE, auto_unbox = TRUE, null = "null")

cat(sprintf("Stage-P summary CSV: %s\n", summary_csv))
cat(sprintf("Stage-P summary MD: %s\n", summary_md))

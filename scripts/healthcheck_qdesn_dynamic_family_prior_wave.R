#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("yaml")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
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
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}
read_csv_safe <- function(path) {
  if (!file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  utils::read.csv(path, stringsAsFactors = FALSE)
}
read_first_line <- function(path, default = "MISSING") {
  if (!file.exists(path)) return(default)
  trimws(readLines(path, warn = FALSE, n = 1L))
}

run_tag <- as.character(get_arg("--run-tag", ""))[1L]
if (!nzchar(trimws(run_tag))) stop("--run-tag is required.", call. = FALSE)

defaults_path <- resolve_path(
  get_arg("--defaults", file.path("config", "validation", "qdesn_dynamic_family_prior_defaults.yaml")),
  must_work = TRUE
)
grid_path <- resolve_path(
  get_arg("--grid", file.path("config", "validation", "qdesn_dynamic_family_prior_grid.csv")),
  must_work = TRUE
)
defaults <- yaml::read_yaml(defaults_path)
campaign_cfg <- defaults$campaign %||% list()

base_results_root <- resolve_path(
  get_arg("--results-root", campaign_cfg$results_root %||% file.path("results", "qdesn_mcmc_validation", "dynamic_family_prior_rerun")),
  must_work = TRUE
)
base_report_root <- resolve_path(
  get_arg("--report-root", campaign_cfg$reports_root %||% file.path("reports", "qdesn_mcmc_validation", "dynamic_family_prior_rerun")),
  must_work = TRUE
)

run_results_root <- file.path(base_results_root, run_tag)
run_report_root <- file.path(base_report_root, run_tag)

resolve_campaign_root <- function(run_root, child) {
  if (!dir.exists(run_root)) return(run_root)
  direct <- file.path(run_root, child)
  if (dir.exists(direct)) return(run_root)
  kids <- sort(list.dirs(run_root, recursive = FALSE, full.names = TRUE), decreasing = TRUE)
  for (k in kids) {
    if (dir.exists(file.path(k, child))) return(k)
  }
  run_root
}

results_root <- resolve_campaign_root(run_results_root, "roots")
report_root <- resolve_campaign_root(run_report_root, "tables")

grid_df <- read_csv_safe(grid_path)
if (nrow(grid_df) && "enabled" %in% names(grid_df)) {
  enabled <- tolower(as.character(grid_df$enabled)) %in% c("true", "1", "t", "yes", "y")
  grid_df <- grid_df[enabled, , drop = FALSE]
}
expected_roots <- nrow(grid_df)

roots_dir <- file.path(results_root, "roots")
root_dirs <- if (dir.exists(roots_dir)) sort(list.dirs(roots_dir, recursive = FALSE, full.names = TRUE)) else character(0)
status_vals <- vapply(file.path(root_dirs, "manifest", "root_status.txt"), read_first_line, character(1))
status_tab <- if (length(status_vals)) sort(table(status_vals), decreasing = TRUE) else integer(0)

n_materialized <- length(root_dirs)
n_success <- if ("SUCCESS" %in% names(status_tab)) as.integer(status_tab[["SUCCESS"]]) else 0L
n_running <- if ("RUNNING" %in% names(status_tab)) as.integer(status_tab[["RUNNING"]]) else 0L
n_other <- n_materialized - n_success - n_running

vb_health_n <- sum(file.exists(file.path(root_dirs, "fits", "vb", "health_summary.csv")))
mcmc_health_n <- sum(file.exists(file.path(root_dirs, "fits", "mcmc", "health_summary.csv")))

method_summary <- read_csv_safe(file.path(report_root, "tables", "campaign_method_summary.csv"))
pair_summary <- read_csv_safe(file.path(report_root, "tables", "campaign_pair_summary.csv"))
method_group <- read_csv_safe(file.path(report_root, "tables", "campaign_method_group_summary.csv"))
pair_group <- read_csv_safe(file.path(report_root, "tables", "campaign_pair_group_summary.csv"))

signoff_mix <- if (nrow(method_summary) && all(c("method", "signoff_grade") %in% names(method_summary))) {
  as.data.frame(table(method = as.character(method_summary$method), signoff_grade = as.character(method_summary$signoff_grade)), stringsAsFactors = FALSE)
} else {
  data.frame(stringsAsFactors = FALSE)
}

pct <- function(num, den) {
  if (!is.finite(den) || den <= 0) return("NA")
  sprintf("%.1f%%", 100 * (as.numeric(num) / as.numeric(den)))
}

cat(sprintf("run_tag: %s\n", run_tag))
cat("| Checkpoint | Value | Detail |\n")
cat("|---|---:|---|\n")
cat(sprintf("| Expected roots | %d | grid=%s |\n", expected_roots, grid_path))
cat(sprintf("| Materialized roots | %d (%s) | results_root=%s |\n", n_materialized, pct(n_materialized, expected_roots), results_root))
cat(sprintf("| SUCCESS roots | %d (%s) | RUNNING=%d, other=%d |\n", n_success, pct(n_success, expected_roots), n_running, n_other))
cat(sprintf("| VB health files | %d (%s) | fits/vb/health_summary.csv |\n", vb_health_n, pct(vb_health_n, expected_roots)))
cat(sprintf("| MCMC health files | %d (%s) | fits/mcmc/health_summary.csv |\n", mcmc_health_n, pct(mcmc_health_n, expected_roots)))
cat(sprintf("| Method summary table | %s | %s |\n", if (nrow(method_summary)) "present" else "missing", file.path(report_root, "tables", "campaign_method_summary.csv")))
cat(sprintf("| Pair summary table | %s | %s |\n", if (nrow(pair_summary)) "present" else "missing", file.path(report_root, "tables", "campaign_pair_summary.csv")))
cat(sprintf("| Method group table | %s | %s |\n", if (nrow(method_group)) "present" else "missing", file.path(report_root, "tables", "campaign_method_group_summary.csv")))
cat(sprintf("| Pair group table | %s | %s |\n", if (nrow(pair_group)) "present" else "missing", file.path(report_root, "tables", "campaign_pair_group_summary.csv")))

if (nrow(signoff_mix)) {
  cat("\nmethod_signoff_mix:\n")
  for (i in seq_len(nrow(signoff_mix))) {
    cat(sprintf("- %s | %s: %d\n",
      as.character(signoff_mix$method[i]),
      as.character(signoff_mix$signoff_grade[i]),
      as.integer(signoff_mix$Freq[i])
    ))
  }
}

if (length(status_tab)) {
  cat("\nroot_status_distribution:\n")
  cat(paste(sprintf("- %s: %d", names(status_tab), as.integer(status_tab)), collapse = "\n"))
  cat("\n")
}

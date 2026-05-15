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

run_tag <- as.character(get_arg("--run-tag", ""))[1L]
if (!nzchar(trimws(run_tag))) stop("--run-tag is required.", call. = FALSE)
arm <- as.character(get_arg("--arm", "rhsns_full"))[1L]

defaults_path <- resolve_path(
  get_arg("--defaults", file.path("config", "validation", "qdesn_mcmc_compare_rhsns_stageQ_defaults.yaml")),
  must_work = TRUE
)
grid_path <- resolve_path(
  get_arg("--grid", file.path("config", "validation", "qdesn_rhsns_stageQ_grid.csv")),
  must_work = TRUE
)
defaults <- yaml::read_yaml(defaults_path)
campaign_cfg <- defaults$campaign %||% list()

base_results_root <- resolve_path(
  get_arg("--results-root", campaign_cfg$results_root %||% file.path("results", "qdesn_mcmc_validation", "rhsns_stageQ_wave")),
  must_work = TRUE
)
base_report_root <- resolve_path(
  get_arg("--report-root", campaign_cfg$reports_root %||% file.path("reports", "qdesn_mcmc_validation", "rhsns_stageQ_wave")),
  must_work = TRUE
)

arm_results_root <- file.path(base_results_root, run_tag, arm)
arm_report_root <- file.path(base_report_root, run_tag, arm)

resolve_campaign_root <- function(arm_root, required_child) {
  direct <- file.path(arm_root, required_child)
  if (dir.exists(direct)) return(arm_root)
  if (!dir.exists(arm_root)) return(arm_root)
  kids <- sort(list.dirs(arm_root, recursive = FALSE, full.names = TRUE), decreasing = TRUE)
  for (k in kids) {
    if (dir.exists(file.path(k, required_child))) return(k)
  }
  arm_root
}

results_root <- resolve_campaign_root(arm_results_root, "roots")
report_root <- resolve_campaign_root(arm_report_root, "tables")
roots_dir <- file.path(results_root, "roots")

grid_df <- read_csv_safe(grid_path)
if (nrow(grid_df) && "enabled" %in% names(grid_df)) {
  enabled <- tolower(as.character(grid_df$enabled)) %in% c("true", "1", "t", "yes", "y")
  grid_df <- grid_df[enabled, , drop = FALSE]
}
expected_roots <- nrow(grid_df)

root_dirs <- if (dir.exists(roots_dir)) sort(list.dirs(roots_dir, recursive = FALSE, full.names = TRUE)) else character(0)
status_files <- file.path(root_dirs, "manifest", "root_status.txt")
status_vals <- vapply(status_files, function(f) {
  if (!file.exists(f)) return("MISSING")
  trimws(readLines(f, warn = FALSE, n = 1L))
}, character(1))
status_tab <- if (length(status_vals)) sort(table(status_vals), decreasing = TRUE) else integer(0)

vb_health_files <- file.path(root_dirs, "fits", "vb", "health_summary.csv")
mcmc_health_files <- file.path(root_dirs, "fits", "mcmc", "health_summary.csv")
vb_health_n <- sum(file.exists(vb_health_files))
mcmc_health_n <- sum(file.exists(mcmc_health_files))

campaign_status <- read_csv_safe(file.path(report_root, "tables", "campaign_status.csv"))
method_summary <- read_csv_safe(file.path(report_root, "tables", "campaign_method_summary.csv"))
tau_pair_summary <- read_csv_safe(file.path(report_root, "tables", "campaign_tau_set_pair_summary.csv"))

n_materialized <- length(root_dirs)
n_success <- if ("SUCCESS" %in% names(status_tab)) as.integer(status_tab[["SUCCESS"]]) else 0L
n_running <- if ("RUNNING" %in% names(status_tab)) as.integer(status_tab[["RUNNING"]]) else 0L
n_failish <- n_materialized - n_success - n_running

pct <- function(num, den) {
  if (!is.finite(den) || den <= 0) return("NA")
  sprintf("%.1f%%", 100 * (as.numeric(num) / as.numeric(den)))
}

pair_synth_tab <- if ("pair_synthesis_status" %in% names(tau_pair_summary)) {
  sort(table(as.character(tau_pair_summary$pair_synthesis_status)), decreasing = TRUE)
} else {
  integer(0)
}

pair_synth_str <- if (length(pair_synth_tab)) {
  paste(names(pair_synth_tab), as.integer(pair_synth_tab), collapse = ", ")
} else {
  "NA"
}

method_signoff <- if (nrow(method_summary) && all(c("method", "signoff_grade") %in% names(method_summary))) {
  split(method_summary, method_summary$method)
} else {
  list()
}
signoff_str <- if (length(method_signoff)) {
  paste(vapply(names(method_signoff), function(m) {
    tab <- table(as.character(method_signoff[[m]]$signoff_grade))
    paste0(m, "{", paste(names(tab), as.integer(tab), collapse = ","), "}")
  }, character(1)), collapse = " | ")
} else {
  "NA"
}

cat(sprintf("run_tag: %s\n", run_tag))
cat(sprintf("arm: %s\n", arm))
cat("| Checkpoint | Value | Detail |\n")
cat("|---|---:|---|\n")
cat(sprintf("| Expected roots | %d | grid=%s |\n", expected_roots, grid_path))
cat(sprintf("| Materialized roots | %d (%s) | campaign_results_root=%s |\n", n_materialized, pct(n_materialized, expected_roots), results_root))
cat(sprintf("| SUCCESS roots | %d (%s) | RUNNING=%d, other=%d |\n", n_success, pct(n_success, expected_roots), n_running, n_failish))
cat(sprintf("| VB health files | %d (%s) | fits/vb/health_summary.csv present |\n", vb_health_n, pct(vb_health_n, expected_roots)))
cat(sprintf("| MCMC health files | %d (%s) | fits/mcmc/health_summary.csv present |\n", mcmc_health_n, pct(mcmc_health_n, expected_roots)))
cat(sprintf("| Campaign status table | %s | %s |\n", if (nrow(campaign_status)) "present" else "missing", file.path(report_root, "tables", "campaign_status.csv")))
cat(sprintf("| Method signoff mix | %s | %s |\n", if (nrow(method_summary)) "present" else "missing", signoff_str))
cat(sprintf("| Tau-set pair status | %s | %s |\n", if (nrow(tau_pair_summary)) "present" else "missing", pair_synth_str))

if (length(status_tab)) {
  cat("\nroot_status_distribution:\n")
  cat(paste(sprintf("- %s: %d", names(status_tab), as.integer(status_tab)), collapse = "\n"))
  cat("\n")
}

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
read_csv_safe <- function(path) {
  if (!file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  utils::read.csv(path, stringsAsFactors = FALSE)
}

defaults_path <- resolve_path(
  get_arg("--defaults", file.path("config", "validation", "qdesn_dynamic_family_prior_defaults.yaml")),
  must_work = TRUE
)
grid_path <- resolve_path(
  get_arg("--grid", file.path("config", "validation", "qdesn_dynamic_family_prior_grid.csv")),
  must_work = TRUE
)
workers <- as.integer(get_arg("--workers", NA_character_))[1L]
verbose <- !has_flag("--quiet")
create_plots <- !has_flag("--no-plots")

defaults <- exdqlm:::qdesn_validation_load_defaults(defaults_path)
campaign_cfg <- defaults$campaign %||% list()
runtime_cfg <- defaults$runtime %||% list()
workers_eff <- if (is.finite(workers) && workers >= 1L) workers else {
  as.integer(runtime_cfg$campaign_workers %||% runtime_cfg$workers %||% 1L)[1L]
}

git_sha <- exdqlm:::.qdesn_validation_git_sha() %||% "unknown"
run_tag <- as.character(get_arg(
  "--run-tag",
  sprintf("dynamic-family-prior-%s__git-%s", format(Sys.time(), "%Y%m%d-%H%M%S"), git_sha)
))[1L]

base_results_root <- resolve_path(
  get_arg("--results-root", campaign_cfg$results_root %||% file.path("results", "qdesn_mcmc_validation", "dynamic_family_prior_rerun")),
  must_work = FALSE
)
base_report_root <- resolve_path(
  get_arg("--report-root", campaign_cfg$reports_root %||% file.path("reports", "qdesn_mcmc_validation", "dynamic_family_prior_rerun")),
  must_work = FALSE
)

results_root <- file.path(base_results_root, run_tag)
report_root <- file.path(base_report_root, run_tag)
summary_dir <- file.path(report_root, "summary")
dir.create(summary_dir, recursive = TRUE, showWarnings = FALSE)

grid_df <- read_csv_safe(grid_path)
if (nrow(grid_df) && "enabled" %in% names(grid_df)) {
  enabled <- tolower(as.character(grid_df$enabled)) %in% c("true", "1", "t", "yes", "y")
  grid_df <- grid_df[enabled, , drop = FALSE]
}

preflight <- list(
  generated_at = as.character(Sys.time()),
  git_sha = git_sha,
  defaults_path = defaults_path,
  grid_path = grid_path,
  run_tag = run_tag,
  workers = workers_eff,
  expected_roots = nrow(grid_df),
  matrix = list(
    scenarios = sort(unique(as.character(grid_df$scenario %||% character(0)))),
    taus = sort(unique(as.numeric(grid_df$tau %||% numeric(0)))),
    likelihood_families = sort(unique(as.character(grid_df$likelihood_family %||% character(0)))),
    beta_priors = sort(unique(as.character(grid_df$beta_prior_type %||% character(0))))
  ),
  synthesis_policy = "disabled_by_single_tau_roots",
  contract = {
    pipeline_cfg <- defaults$pipeline %||% list()
    readout_cfg <- pipeline_cfg$readout %||% list()
    decomposition_cfg <- pipeline_cfg$decomposition %||% list()
    list(
      readout_input_mode = as.character((readout_cfg$input_mode %||% "raw_y_lags")[1L]),
      decomposition_enabled = isTRUE(decomposition_cfg$enabled %||% FALSE)
    )
  }
)
jsonlite::write_json(preflight, file.path(summary_dir, "dynamic_wave_preflight.json"), pretty = TRUE, auto_unbox = TRUE, null = "null")

if (isTRUE(verbose)) {
  cat(sprintf("[dynamic-wave] defaults: %s\n", defaults_path))
  cat(sprintf("[dynamic-wave] grid: %s\n", grid_path))
  cat(sprintf("[dynamic-wave] run tag: %s\n", run_tag))
  cat(sprintf("[dynamic-wave] workers: %d\n", workers_eff))
}

run <- exdqlm:::qdesn_validation_run_campaign(
  grid_path = grid_path,
  defaults_path = defaults_path,
  results_root = results_root,
  report_root = report_root,
  create_plots = create_plots,
  verbose = verbose,
  workers = workers_eff
)

report_run_root <- normalizePath(run$report_root, winslash = "/", mustWork = TRUE)
results_run_root <- normalizePath(run$results_root, winslash = "/", mustWork = TRUE)
tables_dir <- file.path(report_run_root, "tables")

status_df <- read_csv_safe(file.path(tables_dir, "campaign_status.csv"))
method_df <- read_csv_safe(file.path(tables_dir, "campaign_method_summary.csv"))
pair_df <- read_csv_safe(file.path(tables_dir, "campaign_pair_summary.csv"))
method_group_df <- read_csv_safe(file.path(tables_dir, "campaign_method_group_summary.csv"))
pair_group_df <- read_csv_safe(file.path(tables_dir, "campaign_pair_group_summary.csv"))

status_mix <- if (nrow(status_df) && "root_status" %in% names(status_df)) {
  as.data.frame(table(root_status = as.character(status_df$root_status)), stringsAsFactors = FALSE)
} else {
  data.frame(stringsAsFactors = FALSE)
}
signoff_mix <- if (nrow(method_df) && all(c("method", "signoff_grade") %in% names(method_df))) {
  as.data.frame(table(method = as.character(method_df$method), signoff_grade = as.character(method_df$signoff_grade)), stringsAsFactors = FALSE)
} else {
  data.frame(stringsAsFactors = FALSE)
}

utils::write.csv(status_mix, file.path(summary_dir, "dynamic_wave_root_status_mix.csv"), row.names = FALSE)
utils::write.csv(signoff_mix, file.path(summary_dir, "dynamic_wave_method_signoff_mix.csv"), row.names = FALSE)

summary_lines <- c(
  "# QDESN Dynamic Family/Prior Validation Wave",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- git_sha: `%s`", git_sha),
  sprintf("- run_tag: `%s`", run_tag),
  sprintf("- defaults_path: `%s`", defaults_path),
  sprintf("- grid_path: `%s`", grid_path),
  sprintf("- expected_roots: `%d`", nrow(grid_df)),
  sprintf("- workers: `%d`", workers_eff),
  sprintf("- report_run_root: `%s`", report_run_root),
  sprintf("- results_run_root: `%s`", results_run_root),
  "",
  "## Root Status Mix",
  exdqlm:::.qdesn_validation_df_to_markdown(status_mix),
  "",
  "## Method Signoff Mix",
  exdqlm:::.qdesn_validation_df_to_markdown(signoff_mix),
  "",
  "## Method Group Summary",
  exdqlm:::.qdesn_validation_df_to_markdown(method_group_df),
  "",
  "## Pair Group Summary",
  exdqlm:::.qdesn_validation_df_to_markdown(pair_group_df)
)
writeLines(summary_lines, file.path(summary_dir, "dynamic_wave_summary.md"))

manifest <- list(
  generated_at = as.character(Sys.time()),
  run_tag = run_tag,
  git_sha = git_sha,
  defaults_path = defaults_path,
  grid_path = grid_path,
  workers = workers_eff,
  expected_roots = nrow(grid_df),
  report_run_root = report_run_root,
  results_run_root = results_run_root,
  summary_dir = summary_dir,
  tables = list(
    campaign_status = file.path(tables_dir, "campaign_status.csv"),
    campaign_method_summary = file.path(tables_dir, "campaign_method_summary.csv"),
    campaign_pair_summary = file.path(tables_dir, "campaign_pair_summary.csv"),
    campaign_method_group_summary = file.path(tables_dir, "campaign_method_group_summary.csv"),
    campaign_pair_group_summary = file.path(tables_dir, "campaign_pair_group_summary.csv"),
    status_mix = file.path(summary_dir, "dynamic_wave_root_status_mix.csv"),
    signoff_mix = file.path(summary_dir, "dynamic_wave_method_signoff_mix.csv"),
    markdown_summary = file.path(summary_dir, "dynamic_wave_summary.md")
  )
)
jsonlite::write_json(manifest, file.path(summary_dir, "dynamic_wave_manifest.json"), pretty = TRUE, auto_unbox = TRUE, null = "null")

cat(sprintf("Dynamic wave report root: %s\n", report_run_root))
cat(sprintf("Dynamic wave results root: %s\n", results_run_root))
cat(sprintf("Dynamic wave summary: %s\n", file.path(summary_dir, "dynamic_wave_summary.md")))

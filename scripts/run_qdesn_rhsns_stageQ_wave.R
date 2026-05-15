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
  get_arg("--defaults", file.path("config", "validation", "qdesn_mcmc_compare_rhsns_stageQ_defaults.yaml")),
  must_work = TRUE
)
grid_path <- resolve_path(
  get_arg("--grid", file.path("config", "validation", "qdesn_rhsns_stageQ_grid.csv")),
  must_work = TRUE
)
workers <- as.integer(get_arg("--workers", "12"))[1L]
if (!is.finite(workers) || workers < 1L) workers <- 1L

create_plots <- !has_flag("--no-plots")
verbose <- !has_flag("--quiet")

defaults <- exdqlm:::qdesn_validation_load_defaults(defaults_path)
campaign_cfg <- defaults$campaign %||% list()
base_results_root <- resolve_path(
  campaign_cfg$results_root %||% file.path("results", "qdesn_mcmc_validation", "rhsns_stageQ_wave"),
  must_work = FALSE
)
base_report_root <- resolve_path(
  campaign_cfg$reports_root %||% file.path("reports", "qdesn_mcmc_validation", "rhsns_stageQ_wave"),
  must_work = FALSE
)

git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
run_tag <- get_arg("--run-tag", sprintf("stageQ-%s__git-%s", format(Sys.time(), "%Y%m%d-%H%M%S"), git_sha))
wave_results_root <- file.path(base_results_root, run_tag)
wave_report_root <- file.path(base_report_root, run_tag)
arm_results_root <- file.path(wave_results_root, "rhsns_full")
arm_report_root <- file.path(wave_report_root, "rhsns_full")
summary_dir <- file.path(wave_report_root, "summary")
dir.create(wave_results_root, recursive = TRUE, showWarnings = FALSE)
dir.create(wave_report_root, recursive = TRUE, showWarnings = FALSE)
dir.create(summary_dir, recursive = TRUE, showWarnings = FALSE)

read_csv_safe <- function(path) {
  if (!file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  utils::read.csv(path, stringsAsFactors = FALSE)
}

pipeline_cfg <- defaults$pipeline %||% list()
readout_cfg <- pipeline_cfg$readout %||% list()
decomposition_cfg <- pipeline_cfg$decomposition %||% list()
inference_cfg <- pipeline_cfg$inference %||% list()
vb_cfg <- inference_cfg$vb %||% list()
mcmc_cfg <- inference_cfg$mcmc %||% list()
vb_priors <- vb_cfg$priors %||% list()
vb_beta_priors <- vb_priors$beta %||% list()
vb_rhs_ns <- vb_beta_priors$rhs_ns %||% list()

preflight <- list(
  generated_at = as.character(Sys.time()),
  run_tag = run_tag,
  git_sha = git_sha,
  defaults_path = defaults_path,
  grid_path = grid_path,
  workers = workers,
  contract = list(
    readout_input_mode = as.character(readout_cfg$input_mode %||% "missing"),
    decomposition_enabled = isTRUE(decomposition_cfg$enabled %||% FALSE),
    validation_p_vec = as.numeric(unlist(pipeline_cfg$validation_p_vec %||% numeric(0), use.names = FALSE))
  ),
  rhs_ns_guardrails = list(
    vb_rhs_trace = isTRUE((vb_cfg$diagnostics %||% list())$rhs_trace %||% FALSE),
    vb_rhs_ns_init_log_tau_raw = vb_rhs_ns$init_log_tau %||% NULL,
    mcmc_init_from_vb = isTRUE(mcmc_cfg$init_from_vb %||% FALSE)
  ),
  baseline_refs = c(
    file.path("reports", "qdesn_mcmc_validation", "rhsns_stageP_wave", "stageP-20260327-181230__git-2641e6b", "rhsns_full", "20260327-181231__git-2641e6b"),
    file.path("results", "qdesn_mcmc_validation", "rhsns_stageP_wave", "stageP-20260327-181230__git-2641e6b", "rhsns_full", "20260327-181231__git-2641e6b")
  )
)
jsonlite::write_json(preflight, file.path(summary_dir, "stageQ_preflight.json"), pretty = TRUE, auto_unbox = TRUE, null = "null")

if (isTRUE(verbose)) {
  cat(sprintf("[stageQ] defaults: %s\n", defaults_path))
  cat(sprintf("[stageQ] grid: %s\n", grid_path))
  cat(sprintf("[stageQ] run tag: %s\n", run_tag))
  cat(sprintf("[stageQ] workers: %d\n", workers))
  cat(sprintf("[stageQ] validation_p_vec: %s\n", paste(preflight$contract$validation_p_vec, collapse = ", ")))
}

rhsns_full <- exdqlm:::qdesn_validation_run_campaign(
  grid_path = grid_path,
  defaults_path = defaults_path,
  results_root = arm_results_root,
  report_root = arm_report_root,
  create_plots = create_plots,
  verbose = verbose,
  workers = workers
)

status_df <- read_csv_safe(file.path(rhsns_full$report_root, "tables", "campaign_status.csv"))
method_df <- read_csv_safe(file.path(rhsns_full$report_root, "tables", "campaign_method_summary.csv"))
pair_df <- read_csv_safe(file.path(rhsns_full$report_root, "tables", "campaign_pair_summary.csv"))
tau_method_df <- read_csv_safe(file.path(rhsns_full$report_root, "tables", "campaign_tau_set_method_summary.csv"))
tau_pair_df <- read_csv_safe(file.path(rhsns_full$report_root, "tables", "campaign_tau_set_pair_summary.csv"))
if (!nrow(status_df)) {
  status_df <- data.frame(
    n_roots = NA_integer_,
    n_root_success = NA_integer_,
    n_root_fail = NA_integer_,
    n_method_rows = nrow(method_df),
    stringsAsFactors = FALSE
  )
}

signoff_tab <- if ("signoff_grade" %in% names(method_df)) table(method_df$signoff_grade) else integer(0)
eligible_true <- if ("comparison_eligible" %in% names(method_df)) sum(method_df$comparison_eligible %in% TRUE, na.rm = TRUE) else NA_integer_
collapse_true <- if ("rhs_collapse_flag" %in% names(method_df)) sum(method_df$rhs_collapse_flag %in% TRUE, na.rm = TRUE) else NA_integer_
unhealthy_true <- if ("unhealthy" %in% names(method_df)) sum(method_df$unhealthy %in% TRUE, na.rm = TRUE) else NA_integer_
pair_tab <- if ("pair_signoff_grade" %in% names(pair_df)) table(pair_df$pair_signoff_grade) else integer(0)
tau_pair_tab <- if ("pair_synthesis_status" %in% names(tau_pair_df)) table(tau_pair_df$pair_synthesis_status) else integer(0)

summary_df <- data.frame(
  arm = "rhsns_full",
  report_root = rhsns_full$report_root,
  results_root = rhsns_full$results_root,
  n_roots = as.integer(status_df$n_roots[1L]),
  n_root_success = as.integer(status_df$n_root_success[1L]),
  n_root_fail = as.integer(status_df$n_root_fail[1L]),
  n_method_rows = as.integer(status_df$n_method_rows[1L]),
  signoff_pass = if ("PASS" %in% names(signoff_tab)) as.integer(signoff_tab[["PASS"]]) else 0L,
  signoff_warn = if ("WARN" %in% names(signoff_tab)) as.integer(signoff_tab[["WARN"]]) else 0L,
  signoff_fail = if ("FAIL" %in% names(signoff_tab)) as.integer(signoff_tab[["FAIL"]]) else 0L,
  eligible_true = as.integer(eligible_true),
  collapse_true = as.integer(collapse_true),
  unhealthy_true = as.integer(unhealthy_true),
  pair_signoff_pass = if ("PASS" %in% names(pair_tab)) as.integer(pair_tab[["PASS"]]) else 0L,
  pair_signoff_warn = if ("WARN" %in% names(pair_tab)) as.integer(pair_tab[["WARN"]]) else 0L,
  pair_signoff_fail = if ("FAIL" %in% names(pair_tab)) as.integer(pair_tab[["FAIL"]]) else 0L,
  tau_set_complete_healthy = if ("COMPLETE_HEALTHY" %in% names(tau_pair_tab)) as.integer(tau_pair_tab[["COMPLETE_HEALTHY"]]) else 0L,
  tau_set_complete_unhealthy = if ("COMPLETE_UNHEALTHY" %in% names(tau_pair_tab)) as.integer(tau_pair_tab[["COMPLETE_UNHEALTHY"]]) else 0L,
  tau_set_incomplete = if ("INCOMPLETE" %in% names(tau_pair_tab)) as.integer(tau_pair_tab[["INCOMPLETE"]]) else 0L,
  stringsAsFactors = FALSE
)

summary_csv <- file.path(summary_dir, "stageQ_wave_summary.csv")
utils::write.csv(summary_df, summary_csv, row.names = FALSE)

summary_md <- file.path(summary_dir, "stageQ_wave_summary.md")
md_lines <- c(
  "# Stage-Q Wave Summary",
  "",
  sprintf("- run_tag: `%s`", run_tag),
  sprintf("- defaults: `%s`", defaults_path),
  sprintf("- grid: `%s`", grid_path),
  sprintf("- workers: `%d`", workers),
  sprintf("- rhsns_full results_root: `%s`", rhsns_full$results_root),
  sprintf("- rhsns_full report_root: `%s`", rhsns_full$report_root),
  sprintf("- validation_p_vec: `%s`", paste(preflight$contract$validation_p_vec, collapse = ", ")),
  "",
  "## Campaign Summary",
  "",
  exdqlm:::.qdesn_validation_df_to_markdown(summary_df),
  "",
  "## Tau-Set Method Summary (first 24 rows)",
  "",
  exdqlm:::.qdesn_validation_df_to_markdown(utils::head(tau_method_df, 24L)),
  "",
  "## Tau-Set Pair Summary (first 24 rows)",
  "",
  exdqlm:::.qdesn_validation_df_to_markdown(utils::head(tau_pair_df, 24L))
)
writeLines(md_lines, summary_md)

manifest <- list(
  generated_at = as.character(Sys.time()),
  run_tag = run_tag,
  git_sha = git_sha,
  defaults_path = defaults_path,
  grid_path = grid_path,
  workers = workers,
  preflight = file.path(summary_dir, "stageQ_preflight.json"),
  rhsns_full = list(results_root = rhsns_full$results_root, report_root = rhsns_full$report_root),
  summary_csv = summary_csv,
  summary_md = summary_md
)
jsonlite::write_json(manifest, file.path(summary_dir, "stageQ_wave_manifest.json"), pretty = TRUE, auto_unbox = TRUE, null = "null")

cat(sprintf("Stage-Q summary CSV: %s\n", summary_csv))
cat(sprintf("Stage-Q summary MD: %s\n", summary_md))

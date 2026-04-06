#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("yaml", "jsonlite")
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

read_json_safe <- function(path) {
  if (!file.exists(path)) return(list())
  jsonlite::fromJSON(path)
}

run_tag <- as.character(get_arg("--run-tag", ""))[1L]
if (!nzchar(trimws(run_tag))) stop("--run-tag is required.", call. = FALSE)

defaults_path <- resolve_path(
  get_arg("--defaults", file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_defaults.yaml")),
  must_work = TRUE
)
defaults <- yaml::read_yaml(defaults_path)
campaign_cfg <- defaults$campaign %||% list()

base_results_root <- resolve_path(
  get_arg("--results-root", campaign_cfg$results_root %||% file.path("results", "qdesn_mcmc_validation", "dynamic_exdqlm_crossstudy_validation")),
  must_work = TRUE
)
base_report_root <- resolve_path(
  get_arg("--report-root", campaign_cfg$reports_root %||% file.path("reports", "qdesn_mcmc_validation", "dynamic_exdqlm_crossstudy_validation")),
  must_work = TRUE
)

outer_results_root <- file.path(base_results_root, run_tag)
outer_report_root <- file.path(base_report_root, run_tag)
launch_root <- file.path(outer_report_root, "launch")
preflight_manifest <- read_json_safe(file.path(launch_root, "qdesn_dynamic_exdqlm_crossstudy_preflight_manifest.json"))
launch_manifest <- read_json_safe(file.path(launch_root, "qdesn_dynamic_exdqlm_crossstudy_launch_manifest.json"))
launcher_meta <- read_json_safe(file.path(launch_root, "launcher_session.json"))

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

results_root <- resolve_campaign_root(outer_results_root, "roots")
report_root <- resolve_campaign_root(outer_report_root, "tables")

root_dirs <- if (dir.exists(file.path(results_root, "roots"))) {
  sort(list.dirs(file.path(results_root, "roots"), recursive = FALSE, full.names = TRUE))
} else {
  character(0)
}
root_status_vals <- vapply(file.path(root_dirs, "manifest", "root_status.txt"), function(path) {
  if (!file.exists(path)) return("MISSING")
  trimws(readLines(path, warn = FALSE, n = 1L))
}, character(1))
root_status_tab <- if (length(root_status_vals)) sort(table(root_status_vals), decreasing = TRUE) else integer(0)

fit_summary <- read_csv_safe(file.path(report_root, "tables", "campaign_fit_summary.csv"))
pair_summary <- read_csv_safe(file.path(report_root, "tables", "campaign_pairwise_vb_vs_mcmc.csv"))
root_summary <- read_csv_safe(file.path(report_root, "tables", "campaign_root_signoff_summary.csv"))
fit_group <- read_csv_safe(file.path(report_root, "tables", "campaign_fit_group_summary.csv"))
compare_delta <- read_csv_safe(file.path(report_root, "comparison_vs_reference", "tables", "qdesn_vs_reference_surface_delta.csv"))
completed_manifest <- read_json_safe(file.path(report_root, "manifest", "campaign_completed.json"))

selected_roots <- as.integer(preflight_manifest$selected_grid_summary$selected_roots %||% NA_integer_)[1L]
batch <- as.character(preflight_manifest$batch %||% get_arg("--batch", "unknown"))[1L]

launcher_mode <- as.character(launcher_meta$launcher_mode %||% NA_character_)
launcher_session <- as.character(launcher_meta$session_name %||% NA_character_)
launcher_pid <- suppressWarnings(as.integer(launcher_meta$launcher_pid %||% NA_integer_)[1L])
launcher_log <- as.character(launcher_meta$launcher_log %||% NA_character_)
launcher_session_live <- if (!is.na(launcher_session) && nzchar(launcher_session) && identical(launcher_mode, "tmux")) {
  identical(suppressWarnings(system2("tmux", c("has-session", "-t", launcher_session))), 0L)
} else {
  NA
}
launcher_pid_live <- if (is.finite(launcher_pid) && launcher_pid > 0L) {
  identical(suppressWarnings(system2("ps", c("-p", as.character(launcher_pid)))), 0L)
} else {
  NA
}
launcher_log_mtime <- if (!is.na(launcher_log) && nzchar(launcher_log) && file.exists(launcher_log)) {
  as.character(file.info(launcher_log)$mtime[1L])
} else {
  NA_character_
}

pct <- function(num, den) {
  if (!is.finite(den) || den <= 0) return("NA")
  sprintf("%.1f%%", 100 * (as.numeric(num) / as.numeric(den)))
}

n_materialized <- length(root_dirs)
n_success <- if ("SUCCESS" %in% names(root_status_tab)) as.integer(root_status_tab[["SUCCESS"]]) else 0L
n_running <- if ("RUNNING" %in% names(root_status_tab)) as.integer(root_status_tab[["RUNNING"]]) else 0L
n_fail <- if ("FAIL" %in% names(root_status_tab)) as.integer(root_status_tab[["FAIL"]]) else 0L

cat(sprintf("Snapshot: %s\n", as.character(Sys.time())))
cat(sprintf("Run tag: %s\n", run_tag))
cat(sprintf("Batch: %s\n", batch))
cat(sprintf("Outer report root: %s\n", outer_report_root))
cat(sprintf("Outer results root: %s\n", outer_results_root))
cat(sprintf("Campaign report root: %s\n", report_root))
cat(sprintf("Campaign results root: %s\n", results_root))
cat(sprintf("Selected roots: %s\n", as.character(selected_roots)))
cat(sprintf("Materialized roots: %d (%s)\n", n_materialized, pct(n_materialized, selected_roots)))
cat(sprintf("SUCCESS roots: %d (%s)\n", n_success, pct(n_success, selected_roots)))
cat(sprintf("RUNNING roots: %d (%s)\n", n_running, pct(n_running, selected_roots)))
cat(sprintf("FAIL roots: %d (%s)\n", n_fail, pct(n_fail, selected_roots)))
cat(sprintf("Fit summary rows: %d\n", nrow(fit_summary)))
cat(sprintf("Pair summary rows: %d\n", nrow(pair_summary)))
cat(sprintf("Root summary rows: %d\n", nrow(root_summary)))
cat(sprintf("Fit group rows: %d\n", nrow(fit_group)))
cat(sprintf("Surface delta rows: %d\n", nrow(compare_delta)))
cat(sprintf("Campaign completed manifest present: %s\n", if (length(completed_manifest)) "TRUE" else "FALSE"))
cat(sprintf("Launcher mode: %s\n", launcher_mode))
cat(sprintf("Launcher session: %s\n", launcher_session))
cat(sprintf("Launcher session live: %s\n", as.character(launcher_session_live)))
cat(sprintf("Launcher pid: %s\n", as.character(launcher_pid)))
cat(sprintf("Launcher pid live: %s\n", as.character(launcher_pid_live)))
cat(sprintf("Launcher log: %s\n", launcher_log))
cat(sprintf("Launcher log mtime: %s\n", launcher_log_mtime))

if (nrow(fit_summary) && "signoff_grade" %in% names(fit_summary)) {
  cat("\nfit_signoff_mix:\n")
  mix <- as.data.frame(table(fit_summary$signoff_grade), stringsAsFactors = FALSE)
  for (i in seq_len(nrow(mix))) {
    cat(sprintf("- %s: %d\n", as.character(mix$Var1[i]), as.integer(mix$Freq[i])))
  }
}

if (length(root_status_tab)) {
  cat("\nroot_status_distribution:\n")
  cat(paste(sprintf("- %s: %d", names(root_status_tab), as.integer(root_status_tab)), collapse = "\n"))
  cat("\n")
}

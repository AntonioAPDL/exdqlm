#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

get_arg <- function(flag, default = NULL) {
  idx <- match(flag, args)
  if (is.na(idx) || idx >= length(args)) default else args[[idx + 1L]]
}

repo_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)

outer_results_root <- get_arg(
  "--outer-results-root",
  file.path(
    "results", "qdesn_mcmc_validation",
    "dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation",
    "qdesn-dynamic-p90-steepertrend-n300m50-full-20260424-172949__git-366ca13"
  )
)
run_stub <- get_arg("--run-stub", "20260424-172958__git-366ca13")
outer_report_root <- get_arg(
  "--outer-report-root",
  file.path(
    "reports", "qdesn_mcmc_validation",
    "dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation",
    "qdesn-dynamic-p90-steepertrend-n300m50-full-20260424-172949__git-366ca13"
  )
)
defaults_path <- get_arg(
  "--defaults",
  file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_defaults.yaml")
)
closeout_manifest <- get_arg(
  "--closeout-manifest",
  file.path("config", "validation", "qdesn_dynamic_p90_steepertrend_n300m50_closeout_analysis_manifest.yaml")
)
expected_roots <- as.integer(get_arg("--expected-roots", "36"))
expected_fits <- as.integer(get_arg("--expected-fits", "144"))

resolve <- function(path, must_work = FALSE) {
  if (!grepl("^/", path)) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = must_work)
}

outer_results_root <- resolve(outer_results_root, must_work = TRUE)
results_run_root <- file.path(outer_results_root, run_stub)
outer_report_root <- resolve(outer_report_root, must_work = FALSE)
report_run_root <- file.path(outer_report_root, run_stub)
defaults_path <- resolve(defaults_path, must_work = TRUE)
closeout_manifest <- resolve(closeout_manifest, must_work = TRUE)

if (!requireNamespace("pkgload", quietly = TRUE)) {
  stop("pkgload is required for final QDESN closeout.", call. = FALSE)
}
pkgload::load_all(repo_root, quiet = TRUE)

roots_dir <- file.path(results_run_root, "roots")
root_dirs <- if (dir.exists(roots_dir)) {
  sort(list.dirs(roots_dir, recursive = FALSE, full.names = TRUE))
} else {
  character(0)
}
if (length(root_dirs) != expected_roots) {
  stop(sprintf("Final closeout requires %d roots; found %d.", expected_roots, length(root_dirs)), call. = FALSE)
}

status_rows <- lapply(root_dirs, function(root_dir) {
  status_file <- file.path(root_dir, "manifest", "root_status.txt")
  status <- if (file.exists(status_file)) trimws(readLines(status_file, warn = FALSE)[1L]) else NA_character_
  data.frame(
    root_id = basename(root_dir),
    status = status,
    stringsAsFactors = FALSE
  )
})
status_df <- .qdesn_validation_bind_rows(status_rows)
not_success <- status_df[as.character(status_df$status) != "SUCCESS" | is.na(status_df$status), , drop = FALSE]
if (nrow(not_success)) {
  print(not_success, row.names = FALSE)
  stop("Final closeout is intentionally blocked until all roots are SUCCESS.", call. = FALSE)
}

repair_root <- file.path(outer_report_root, paste0("signoff_repair_final_", format(Sys.time(), "%Y%m%d_%H%M%S")))
repair_script <- file.path(repo_root, "scripts", "repair_qdesn_dynamic_crossstudy_signoff_from_saved_outputs.R")
repair_status <- system2(
  "Rscript",
  c(
    repair_script,
    "--results-root", outer_results_root,
    "--report-root", repair_root
  )
)
if (!identical(as.integer(repair_status), 0L)) {
  stop(sprintf("Final signoff repair failed with status %s.", repair_status), call. = FALSE)
}

defaults <- qdesn_dynamic_crossstudy_load_defaults(defaults_path)
campaign <- qdesn_dynamic_crossstudy_collect_campaign(
  results_root = results_run_root,
  report_root = report_run_root,
  defaults = defaults,
  reference_inventory = NULL,
  create_plots = FALSE
)
if (nrow(campaign$root_summary) != expected_roots) {
  stop(sprintf("Collected %d root rows; expected %d.", nrow(campaign$root_summary), expected_roots), call. = FALSE)
}
if (nrow(campaign$fit_summary) != expected_fits) {
  stop(sprintf("Collected %d fit rows; expected %d.", nrow(campaign$fit_summary), expected_fits), call. = FALSE)
}

closeout <- qdesn_dynamic_p90_steepertrend_closeout_analysis(
  manifest_path = closeout_manifest,
  repo_root = repo_root
)

final_manifest <- list(
  generated_at = as.character(Sys.time()),
  repo_root = repo_root,
  outer_results_root = outer_results_root,
  results_run_root = results_run_root,
  outer_report_root = outer_report_root,
  report_run_root = report_run_root,
  defaults_path = defaults_path,
  repair_root = repair_root,
  closeout_manifest = closeout_manifest,
  closeout_output_root = closeout$output_root,
  n_roots = nrow(campaign$root_summary),
  n_fits = nrow(campaign$fit_summary),
  recommendation = campaign$recommendation
)
.qdesn_validation_dir_create(file.path(outer_report_root, "final_closeout"))
.qdesn_validation_write_json(
  file.path(outer_report_root, "final_closeout", paste0("final_closeout_manifest_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".json")),
  final_manifest
)

cat(sprintf("Final repair root: %s\n", repair_root))
cat(sprintf("Campaign report root: %s\n", report_run_root))
cat(sprintf("Closeout output root: %s\n", closeout$output_root))
cat(sprintf("Collected roots/fits: %d / %d\n", nrow(campaign$root_summary), nrow(campaign$fit_summary)))

#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("pkgload", "jsonlite", "yaml")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
has_flag <- function(flag) any(args == flag)
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
pkgload::load_all(repo_root, quiet = TRUE)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

write_json <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, null = "null")
  invisible(path)
}

manifest_rel <- get_arg("--manifest", file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_fit_plot_pack_manifest.yaml"))
prepare_only <- has_flag("--prepare-only")
assemble_only <- has_flag("--assemble-only")
workers_override <- suppressWarnings(as.integer(get_arg("--max-workers", NA)))

manifest_path <- resolve_path(manifest_rel, must_work = TRUE)
manifest <- exdqlm:::qdesn_dynamic_fitplotpack_load_manifest(manifest_path)
source_state <- exdqlm:::.qdesn_dynamic_fitplotpack_resolve_source_state(manifest, repo_root = repo_root)
case_table <- exdqlm:::.qdesn_dynamic_fitplotpack_case_table(manifest, source_state)
source_fit_table <- exdqlm:::.qdesn_dynamic_fitplotpack_source_fit_table(case_table, source_state)

analysis_cfg <- manifest$analysis %||% list()
report_root <- resolve_path(
  analysis_cfg$report_root %||% file.path("reports", "qdesn_mcmc_validation", "dynamic_exdqlm_crossstudy_fit_plot_pack"),
  must_work = FALSE
)
git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
run_tag_prefix <- as.character(manifest$meta$run_tag_prefix %||% "qdesn-dynamic-exdqlm-crossstudy-fitplotpack")[1L]
run_tag <- as.character(get_arg(
  "--run-tag",
  sprintf("%s-%s__git-%s", run_tag_prefix, format(Sys.time(), "%Y%m%d-%H%M%S"), git_sha)
))[1L]

output_root <- file.path(report_root, run_tag)
launch_root <- file.path(output_root, "launch")
dir.create(launch_root, recursive = TRUE, showWarnings = FALSE)

job_list <- exdqlm:::.qdesn_dynamic_fitplotpack_build_jobs(
  case_table = case_table,
  source_fit_table = source_fit_table,
  source_state = source_state,
  manifest = manifest,
  output_root = output_root
)

execution_cfg <- manifest$execution %||% list()
max_workers <- if (is.finite(workers_override)) workers_override else as.integer(execution_cfg$max_workers %||% 2L)[1L]
max_workers <- max(1L, min(max_workers, length(job_list)))

preflight_lines <- c(
  "# QDESN Fit Plot Pack Preflight",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- run_tag: `%s`", run_tag),
  sprintf("- prepare_only: `%s`", if (prepare_only) "TRUE" else "FALSE"),
  sprintf("- assemble_only: `%s`", if (assemble_only) "TRUE" else "FALSE"),
  sprintf("- manifest: `%s`", manifest_path),
  sprintf("- source_run_root: `%s`", source_state$source_run_root),
  sprintf("- comparison_root: `%s`", source_state$comparison_root),
  sprintf("- max_workers: `%d`", max_workers),
  "",
  "## Selected Cases",
  exdqlm:::.qdesn_validation_df_to_markdown(case_table),
  "",
  "## Source Fit Scorecard",
  exdqlm:::.qdesn_validation_df_to_markdown(source_fit_table[, c(
    "case_id", "panel_label", "signoff_grade", "holdout_qtrue_mae", "holdout_pinball_tau", "runtime_sec"
  ), drop = FALSE]),
  "",
  "## Output",
  sprintf("- output_root: `%s`", output_root)
)
writeLines(preflight_lines, file.path(launch_root, "qdesn_dynamic_fit_plot_pack_preflight.md"))
write_json(list(
  generated_at = as.character(Sys.time()),
  run_tag = run_tag,
  prepare_only = prepare_only,
  assemble_only = assemble_only,
  manifest_path = manifest_path,
  source_run_root = source_state$source_run_root,
  comparison_root = source_state$comparison_root,
  output_root = normalizePath(output_root, winslash = "/", mustWork = FALSE),
  max_workers = max_workers
), file.path(launch_root, "run_metadata.json"))

if (prepare_only) {
  cat(sprintf("Prepare-only OK: %s\n", output_root))
  quit(save = "no", status = 0L)
}

rerun_status <- if (assemble_only) {
  exdqlm:::qdesn_dynamic_fitplotpack_collect_jobs(job_list)
} else {
  exdqlm:::qdesn_dynamic_fitplotpack_run_jobs(
    jobs = job_list,
    max_workers = max_workers
  )
}
analysis_obj <- exdqlm:::qdesn_dynamic_fitplotpack_write_analysis(
  source_state = source_state,
  case_table = case_table,
  source_fit_table = source_fit_table,
  rerun_status = rerun_status,
  output_root = output_root,
  manifest = manifest
)

write_json(list(
  completed_at = as.character(Sys.time()),
  assemble_only = assemble_only,
  rerun_success_n = sum(as.integer(rerun_status$pipeline_status) == 0L & rerun_status$train_plot_exists, na.rm = TRUE),
  rerun_total_n = nrow(rerun_status),
  figure_paths = analysis_obj$figure_index$rel_plot_path
), file.path(launch_root, "completion_metadata.json"))

cat(sprintf("Fit plot pack complete: %s\n", output_root))

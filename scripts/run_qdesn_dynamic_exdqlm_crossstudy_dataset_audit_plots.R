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

manifest_rel <- get_arg("--manifest", file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_dataset_audit_manifest.yaml"))
prepare_only <- has_flag("--prepare-only")
workers_override <- suppressWarnings(as.integer(get_arg("--max-workers", NA)))

manifest_path <- resolve_path(manifest_rel, must_work = TRUE)
manifest <- exdqlm:::qdesn_dynamic_datasetaudit_load_manifest(manifest_path)
state <- exdqlm:::.qdesn_dynamic_datasetaudit_resolve_state(manifest, repo_root = repo_root)
inventory <- exdqlm:::qdesn_dynamic_datasetaudit_build_inventory(manifest, state = state, repo_root = repo_root)

execution_cfg <- manifest$execution %||% list()
max_workers <- if (is.finite(workers_override)) workers_override else as.integer(execution_cfg$max_workers %||% 1L)[1L]
max_workers <- max(1L, min(max_workers, nrow(inventory)))

git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
run_tag_prefix <- as.character((manifest$meta %||% list())$run_tag_prefix %||% "qdesn-dynamic-exdqlm-crossstudy-datasetaudit")[1L]
output_parent <- as.character((manifest$analysis %||% list())$output_parent %||% tempdir())[1L]
if (!grepl("^(/|~)", output_parent)) output_parent <- file.path(repo_root, output_parent)
output_parent <- normalizePath(output_parent, winslash = "/", mustWork = FALSE)
output_root <- resolve_path(
  get_arg("--output-root", file.path(output_parent, sprintf("%s-%s__git-%s", run_tag_prefix, format(Sys.time(), "%Y%m%d-%H%M%S"), git_sha))),
  must_work = FALSE
)

exdqlm:::.qdesn_validation_dir_create(output_root)
exdqlm:::.qdesn_validation_write_json(file.path(output_root, "000__run_metadata.json"), list(
  generated_at = as.character(Sys.time()),
  run_tag_prefix = run_tag_prefix,
  prepare_only = prepare_only,
  manifest_path = manifest_path,
  source_run_root = state$source_run_root,
  comparison_root = state$comparison_root,
  output_root = output_root,
  max_workers = max_workers
))

preflight_lines <- c(
  "# Tau050 Dataset Audit Preflight",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- prepare_only: `%s`", if (prepare_only) "TRUE" else "FALSE"),
  sprintf("- manifest: `%s`", manifest_path),
  sprintf("- source_run_root: `%s`", state$source_run_root),
  sprintf("- comparison_root: `%s`", state$comparison_root %||% NA_character_),
  sprintf("- output_root: `%s`", output_root),
  sprintf("- max_workers: `%d`", max_workers),
  sprintf("- n_datasets: `%d`", nrow(inventory)),
  "",
  "## Inventory",
  exdqlm:::.qdesn_validation_df_to_markdown(inventory[, c(
    "plot_index", "png_file", "family", "tau", "fit_size", "prior", "n_obs", "readiness_label", "fail_fit_n"
  ), drop = FALSE])
)
exdqlm:::.qdesn_validation_write_lines(file.path(output_root, "000__preflight.md"), preflight_lines)

if (prepare_only) {
  exdqlm:::qdesn_dynamic_datasetaudit_write_outputs(
    inventory = inventory,
    render_status = data.frame(stringsAsFactors = FALSE),
    output_root = output_root,
    manifest = manifest,
    state = state
  )
  cat(sprintf("Prepare-only OK: %s\n", output_root))
  quit(save = "no", status = 0L)
}

render_status <- exdqlm:::qdesn_dynamic_datasetaudit_render_plots(
  inventory = inventory,
  output_root = output_root,
  manifest = manifest,
  max_workers = max_workers
)
inventory_out <- exdqlm:::qdesn_dynamic_datasetaudit_write_outputs(
  inventory = inventory,
  render_status = render_status,
  output_root = output_root,
  manifest = manifest,
  state = state
)

render_error <- if ("render_error" %in% names(inventory_out)) inventory_out$render_error else rep("", nrow(inventory_out))
render_error <- trimws(as.character(render_error))
render_error[is.na(render_error)] <- ""
png_ok <- !is.na(inventory_out$png_path) & file.exists(inventory_out$png_path)

exdqlm:::.qdesn_validation_write_json(file.path(output_root, "000__completion_metadata.json"), list(
  completed_at = as.character(Sys.time()),
  output_root = output_root,
  n_datasets = nrow(inventory_out),
  n_rendered = sum(png_ok),
  n_render_errors = sum(nzchar(render_error)),
  max_workers = max_workers
))

if (any(!png_ok) || any(nzchar(render_error))) {
  bad_n <- sum(!png_ok | nzchar(render_error))
  stop(sprintf("Dataset audit completed with %d plot rendering problems. See %s", bad_n, file.path(output_root, "000__dataset_index.csv")), call. = FALSE)
}

cat(sprintf("Dataset audit plot pack complete: %s\n", output_root))

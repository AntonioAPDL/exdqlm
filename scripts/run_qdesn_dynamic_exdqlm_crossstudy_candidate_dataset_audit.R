#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("pkgload", "yaml", "jsonlite")
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

manifest_rel <- get_arg("--manifest", file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_candidate_dataset_audit_manifest.yaml"))
prepare_only <- has_flag("--prepare-only")
workers_override <- suppressWarnings(as.integer(get_arg("--max-workers", NA)))

manifest <- exdqlm:::qdesn_dynamic_candidate_audit_load_manifest(manifest_rel, repo_root = repo_root)
state <- exdqlm:::.qdesn_dynamic_candidate_audit_resolve_state(manifest, repo_root = repo_root)
inventory <- exdqlm:::qdesn_dynamic_candidate_audit_build_inventory(manifest, state = state, repo_root = repo_root)

execution_cfg <- manifest$execution %||% list()
max_workers <- if (is.finite(workers_override)) workers_override else as.integer(execution_cfg$max_workers %||% 1L)[1L]
max_workers <- max(1L, min(max_workers, nrow(inventory)))

git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
run_tag_prefix <- as.character((manifest$meta %||% list())$run_tag_prefix %||% "qdesn-dynamic-candidate-datasetaudit")[1L]
output_parent <- as.character((manifest$analysis %||% list())$output_parent %||% tempdir())[1L]
if (!grepl("^(/|~)", output_parent)) output_parent <- file.path(repo_root, output_parent)
output_parent <- normalizePath(output_parent, winslash = "/", mustWork = FALSE)
output_root <- normalizePath(
  get_arg("--output-root", file.path(output_parent, sprintf("%s-%s__git-%s", run_tag_prefix, format(Sys.time(), "%Y%m%d-%H%M%S"), git_sha))),
  winslash = "/",
  mustWork = FALSE
)

exdqlm:::.qdesn_validation_dir_create(output_root)
exdqlm:::.qdesn_validation_write_json(file.path(output_root, "000__run_metadata.json"), list(
  generated_at = as.character(Sys.time()),
  prepare_only = prepare_only,
  manifest = normalizePath(file.path(repo_root, manifest_rel), winslash = "/", mustWork = FALSE),
  source_root = state$source_root,
  qdesn_materialized_root = state$qdesn_materialized_root,
  output_root = output_root,
  max_workers = max_workers,
  n_rows = nrow(inventory)
))

if (prepare_only) {
  exdqlm:::qdesn_dynamic_candidate_audit_write_outputs(
    inventory = inventory,
    render_status = data.frame(stringsAsFactors = FALSE),
    output_root = output_root,
    manifest = manifest,
    state = state
  )
  cat(sprintf("Prepare-only OK: %s\n", output_root))
  quit(save = "no", status = 0L)
}

render_status <- exdqlm:::qdesn_dynamic_candidate_audit_render_plots(
  inventory = inventory,
  output_root = output_root,
  manifest = manifest,
  max_workers = max_workers
)
inventory_out <- exdqlm:::qdesn_dynamic_candidate_audit_write_outputs(
  inventory = inventory,
  render_status = render_status,
  output_root = output_root,
  manifest = manifest,
  state = state
)
render_error <- if ("error" %in% names(inventory_out)) inventory_out$error else rep("", nrow(inventory_out))
render_error <- trimws(as.character(render_error))
render_error[is.na(render_error)] <- ""
png_ok <- !is.na(inventory_out$png_path) & file.exists(inventory_out$png_path)
if (any(!png_ok) || any(nzchar(render_error))) {
  stop(sprintf("Candidate dataset audit completed with rendering problems. See %s", file.path(output_root, "000__dataset_index.csv")), call. = FALSE)
}
cat(sprintf("Candidate dataset audit pack complete: %s\n", output_root))

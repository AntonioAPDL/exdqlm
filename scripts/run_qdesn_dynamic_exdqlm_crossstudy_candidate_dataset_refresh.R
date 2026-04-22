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

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

manifest_rel <- get_arg("--manifest", file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_candidate_dataset_manifest.yaml"))
material_defaults_rel <- get_arg("--materialization-defaults", file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_candidate_materialization_defaults.yaml"))
prepare_only <- has_flag("--prepare-only")
refresh <- !has_flag("--no-refresh")

manifest <- exdqlm:::qdesn_dynamic_candidate_load_manifest(manifest_rel, repo_root = repo_root)
state <- exdqlm:::.qdesn_dynamic_candidate_resolve_state(manifest, repo_root = repo_root)

exdqlm:::.qdesn_validation_dir_create(state$source_root)
exdqlm:::.qdesn_validation_write_json(file.path(state$source_root, "000__preflight.json"), list(
  generated_at = as.character(Sys.time()),
  prepare_only = prepare_only,
  refresh = refresh,
  source_root = state$source_root,
  qdesn_staged_root = state$qdesn_staged_root,
  manifest = normalizePath(file.path(repo_root, manifest_rel), winslash = "/", mustWork = FALSE),
  materialization_defaults = normalizePath(file.path(repo_root, material_defaults_rel), winslash = "/", mustWork = FALSE)
))

if (prepare_only) {
  cat(sprintf("Prepare-only OK: %s\n", state$source_root))
  quit(save = "no", status = 0L)
}

bundle <- exdqlm:::qdesn_dynamic_candidate_generate_bundle(
  manifest = manifest,
  repo_root = repo_root,
  refresh = refresh,
  verbose = TRUE
)
materialized <- exdqlm:::qdesn_dynamic_candidate_materialize_qdesn_windows(
  defaults_path = material_defaults_rel,
  repo_root = repo_root,
  refresh = refresh,
  verbose = TRUE
)

exdqlm:::.qdesn_validation_write_json(file.path(state$source_root, "000__completion.json"), list(
  completed_at = as.character(Sys.time()),
  source_root = state$source_root,
  qdesn_staged_root = state$qdesn_staged_root,
  n_full_roots = nrow(bundle$root_inventory),
  n_canonical_slices = nrow(bundle$slice_inventory),
  n_qdesn_windows = nrow(materialized)
))

cat(sprintf("Candidate dynamic datasets ready: %s\n", state$source_root))
cat(sprintf("Candidate qdesn windows ready: %s\n", state$qdesn_staged_root))

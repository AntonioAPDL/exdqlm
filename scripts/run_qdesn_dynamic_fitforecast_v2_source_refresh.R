#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag, default = NULL) {
  idx <- match(flag, args)
  if (is.na(idx) || idx >= length(args)) return(default)
  args[[idx + 1L]]
}
arg_flag <- function(flag) flag %in% args

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)

manifest_path <- arg_value(
  "--manifest",
  file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_candidate_dataset_manifest.yaml")
)
defaults_path <- arg_value(
  "--defaults",
  file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_storage_light_defaults.yaml")
)
grid_out <- arg_value(
  "--grid-out",
  file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_full_grid.csv")
)
execute <- arg_flag("--execute")
refresh <- arg_flag("--refresh")
skip_generate <- arg_flag("--skip-generate")

suppressPackageStartupMessages(pkgload::load_all(repo_root, quiet = TRUE))
runtime <- exdqlm:::qdesn_validation_assert_runtime(repo_root = repo_root)

cat("Q-DESN dynamic fit+forecast v2 source refresh\n")
cat(sprintf("repo_root: %s\n", repo_root))
cat(sprintf("Rscript: %s\n", runtime$rscript))
cat(sprintf("R version: %s\n", runtime$r_version))
cat(sprintf("manifest: %s\n", manifest_path))
cat(sprintf("defaults: %s\n", defaults_path))
cat(sprintf("grid_out: %s\n", grid_out))
cat(sprintf("execute: %s\n", execute))
cat(sprintf("refresh: %s\n", refresh))

if (!execute) {
  cat("DRY RUN ONLY. Re-run with --execute to generate/materialize source files.\n")
  quit(status = 0L, save = "no")
}

manifest <- exdqlm:::qdesn_dynamic_candidate_load_manifest(manifest_path, repo_root = repo_root)
if (!skip_generate) {
  candidate_bundle <- exdqlm:::qdesn_dynamic_candidate_generate_bundle(
    manifest = manifest,
    repo_root = repo_root,
    refresh = refresh,
    verbose = TRUE
  )
  cat(sprintf("candidate_full_roots: %d\n", nrow(candidate_bundle$root_inventory)))
  cat(sprintf("candidate_tail_slices: %d\n", nrow(candidate_bundle$slice_inventory)))
}

defaults <- exdqlm:::qdesn_validation_load_defaults(defaults_path, repo_root = repo_root)
inventory <- exdqlm:::qdesn_dynamic_crossstudy_materialize_source_inputs(
  defaults = defaults,
  refresh = refresh,
  verbose = TRUE
)
verification <- exdqlm:::qdesn_dynamic_fitforecast_verify_source_windows(
  inventory,
  expected_train_end = 9000L,
  expected_forecast_end = 10000L,
  stop_on_fail = TRUE
)

verify_out <- file.path(dirname(grid_out), "qdesn_dynamic_fitforecast_v2_source_window_verification.csv")
exdqlm:::.qdesn_validation_write_df(verification, verify_out)

grid <- exdqlm:::qdesn_dynamic_crossstudy_build_grid_from_materialized_sources(
  defaults = defaults,
  materialized_inventory = inventory
)
exdqlm:::.qdesn_validation_write_df(grid, grid_out)

cat(sprintf("materialized_rows: %d\n", nrow(inventory)))
cat(sprintf("verification: %s\n", verify_out))
cat(sprintf("grid_rows: %d\n", nrow(grid)))
cat(sprintf("grid: %s\n", grid_out))

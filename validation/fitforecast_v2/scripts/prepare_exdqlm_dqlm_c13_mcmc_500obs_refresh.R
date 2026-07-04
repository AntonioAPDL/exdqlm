#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) {
  sub("^--file=", "", file_arg[[1L]])
} else {
  "validation/fitforecast_v2/scripts/prepare_exdqlm_dqlm_c13_mcmc_500obs_refresh.R"
}
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
defaults_path <- args$defaults %||% ffv2_default_defaults_path()
candidates_path <- args$candidates %||% ffv2_default_vb_calibration_candidates_path()
full_only <- ffv2_truthy(args$`full-only` %||% args$`no-gates` %||% FALSE)
run_tag <- args$`run-tag` %||% if (full_only) {
  ffv2_c13_mcmc_default_full_run_tag()
} else {
  ffv2_c13_mcmc_default_gate_run_tag()
}
run_root <- args$`run-root` %||% NULL
workers <- as.integer(args$workers %||% 12L)
dry_run <- ffv2_truthy(args$`dry-run` %||% FALSE)
overwrite <- ffv2_truthy(args$overwrite %||% FALSE)
allow_missing_source <- ffv2_truthy(args$`allow-missing-source` %||% FALSE)

defaults <- ffv2_load_defaults(defaults_path)
candidates <- ffv2_read_vb_calibration_candidates(candidates_path)
candidate <- ffv2_c13_mcmc_candidate(candidates)
defaults <- ffv2_c13_mcmc_defaults(
  defaults = defaults,
  run_tag = run_tag,
  candidate = candidate,
  workers = workers,
  gate_rows = !full_only
)

ffv2_assert_runtime(defaults$runtime$r_min_version %||% "4.6.0")
registry <- ffv2_collect_source_registry(defaults, require_sources = !allow_missing_source)
verification <- ffv2_verify_source_windows(registry, stop_on_fail = !allow_missing_source)
manifest <- ffv2_prepare_c13_mcmc_refresh_manifest(
  defaults = defaults,
  registry = registry,
  candidate = candidate,
  run_root = run_root,
  dry_run = dry_run,
  overwrite = overwrite,
  workers = workers,
  gate_rows = !full_only
)

smoke_rows <- ffv2_stage_rows(manifest, "smoke", include_completed = TRUE)
pilot_rows <- ffv2_stage_rows(manifest, "pilot", include_completed = TRUE)

cat("exDQLM/DQLM c13 MCMC 500-observation refresh prepare\n")
cat(sprintf("repo_root: %s\n", ffv2_repo_root()))
cat(sprintf("defaults: %s\n", normalizePath(defaults_path, winslash = "/", mustWork = TRUE)))
cat(sprintf("candidates: %s\n", normalizePath(candidates_path, winslash = "/", mustWork = TRUE)))
cat(sprintf("run_tag: %s\n", defaults$study$run_tag))
cat(sprintf("dry_run: %s\n", dry_run))
cat(sprintf("overwrite: %s\n", overwrite))
cat(sprintf("full_only: %s\n", full_only))
cat(sprintf("workers_mcmc_tt500: %d\n", workers))
cat(sprintf("source_rows: %d\n", nrow(registry)))
cat(sprintf("manifest_rows: %d\n", nrow(manifest)))
cat(sprintf("smoke_rows: %d\n", nrow(smoke_rows)))
cat(sprintf("pilot_rows: %d\n", nrow(pilot_rows)))
cat(sprintf("candidate_id: %s\n", candidate$candidate_id[[1L]]))
cat(sprintf("calibration_id: %s\n", candidate$calibration_id[[1L]]))
cat(sprintf("trend_C0_scale: %s\n", candidate$trend_C0_scale[[1L]]))
cat(sprintf("seasonal_C0_scale: %s\n", candidate$seasonal_C0_scale[[1L]]))
cat(sprintf("df_value: %s\n", candidate$df_value[[1L]]))
cat(sprintf("dim_df: %s\n", candidate$dim_df[[1L]]))
cat("source_window_status:\n")
print(table(verification$status, useNA = "ifany"))
cat("phase_counts:\n")
print(table(manifest$phase, useNA = "ifany"))
cat("cell_preview:\n")
print(manifest[, intersect(
  c("row_id", "row_key", "family", "tau", "model_variant", "inference",
    "phase", "smoke", "pilot", "spec_id"),
  names(manifest)
), drop = FALSE])
if (!dry_run) {
  run_root_out <- unique(manifest$run_root)[[1L]]
  cat(sprintf("run_root: %s\n", run_root_out))
  cat(sprintf("row_manifest: %s\n", file.path(run_root_out, "manifests", "row_manifest.csv")))
  cat(sprintf("smoke_row_ids: %s\n", file.path(run_root_out, "manifests", "smoke_row_ids.txt")))
  cat(sprintf("pilot_row_ids: %s\n", file.path(run_root_out, "manifests", "pilot_row_ids.txt")))
}

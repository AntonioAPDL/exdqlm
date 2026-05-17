#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else "validation/fitforecast_v2/scripts/prepare_exdqlm_dynamic_fitforecast_v2_validation.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
defaults_path <- args$defaults %||% ffv2_default_defaults_path()
dry_run <- ffv2_truthy(args$`dry-run` %||% FALSE)
overwrite <- ffv2_truthy(args$overwrite %||% FALSE)
allow_missing_source <- ffv2_truthy(args$`allow-missing-source` %||% dry_run)

defaults <- ffv2_load_defaults(defaults_path)
if (!is.null(args$`run-tag`)) defaults$study$run_tag <- as.character(args$`run-tag`)
if (!is.null(args$`run-overrides`)) {
  defaults$run_overrides <- defaults$run_overrides %||% list()
  defaults$run_overrides$path <- as.character(args$`run-overrides`)
}
run_root <- args$`run-root` %||% NULL

ffv2_assert_runtime(defaults$runtime$r_min_version %||% "4.6.0")
registry <- ffv2_collect_source_registry(defaults, require_sources = !allow_missing_source)
if (!allow_missing_source) {
  verification <- ffv2_verify_source_windows(registry, stop_on_fail = TRUE)
} else {
  verification <- ffv2_verify_source_windows(registry, stop_on_fail = FALSE)
}
manifest <- ffv2_prepare_manifest(
  defaults = defaults,
  registry = registry,
  run_root = run_root,
  dry_run = dry_run,
  overwrite = overwrite
)

cat("exDQLM/DQLM dynamic fit+forecast v2 prepare\n")
cat(sprintf("repo_root: %s\n", ffv2_repo_root()))
cat(sprintf("defaults: %s\n", normalizePath(defaults_path, winslash = "/", mustWork = TRUE)))
cat(sprintf("run_tag: %s\n", defaults$study$run_tag))
cat(sprintf("dry_run: %s\n", dry_run))
cat(sprintf("source_rows: %d\n", nrow(registry)))
cat(sprintf("manifest_rows: %d\n", nrow(manifest)))
cat("source_window_status:\n")
print(table(verification$status, useNA = "ifany"))
cat("phase_counts:\n")
print(table(manifest$phase, useNA = "ifany"))
cat("smoke_rows:\n")
print(manifest[manifest$smoke %in% c(TRUE, "TRUE", "true", "1"),
               intersect(c("row_id", "spec_id", "family", "tau", "fit_size", "model_variant", "inference"), names(manifest))])
if (!dry_run) {
  cat(sprintf("run_root: %s\n", unique(manifest$run_root)[[1L]]))
  cat(sprintf("row_manifest: %s\n", file.path(unique(manifest$run_root)[[1L]], "manifests", "row_manifest.csv")))
}

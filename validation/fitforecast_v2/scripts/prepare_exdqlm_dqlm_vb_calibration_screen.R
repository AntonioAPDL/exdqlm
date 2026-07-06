#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) {
  sub("^--file=", "", file_arg[[1L]])
} else {
  "validation/fitforecast_v2/scripts/prepare_exdqlm_dqlm_vb_calibration_screen.R"
}
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
defaults_path <- args$defaults %||% ffv2_default_defaults_path()
candidates_path <- args$candidates %||% ffv2_default_vb_calibration_candidates_path()
dry_run <- ffv2_truthy(args$`dry-run` %||% FALSE)
overwrite <- ffv2_truthy(args$overwrite %||% FALSE)
allow_missing_source <- ffv2_truthy(args$`allow-missing-source` %||% FALSE)
run_tag <- args$`run-tag` %||% "20260702_exdqlm_dqlm_vb_c0_discount_screen"
run_root <- args$`run-root` %||% NULL

split_arg <- function(value) {
  value <- as.character(value %||% "")[1L]
  value <- trimws(value)
  if (!nzchar(value)) return(character(0))
  out <- trimws(strsplit(value, ",", fixed = TRUE)[[1L]])
  out[nzchar(out)]
}

defaults <- ffv2_load_defaults(defaults_path)
defaults <- ffv2_vb_screen_defaults(defaults, run_tag = run_tag)

ffv2_assert_runtime(defaults$runtime$r_min_version %||% "4.6.0")
registry <- ffv2_collect_source_registry(defaults, require_sources = !allow_missing_source)
families <- split_arg(args$families %||% args$family %||% "")
taus_raw <- split_arg(args$taus %||% args$tau %||% "")
taus <- suppressWarnings(as.numeric(taus_raw))
if (length(taus_raw) && (length(taus) != length(taus_raw) || any(!is.finite(taus)))) {
  stop("--taus must be a comma-separated list of finite numeric tau values.", call. = FALSE)
}
if (length(families)) {
  registry <- registry[as.character(registry$family) %in% families, , drop = FALSE]
}
if (length(taus)) {
  registry <- registry[round(as.numeric(registry$tau), 8L) %in% round(taus, 8L), , drop = FALSE]
}
if (!nrow(registry)) {
  stop("Filtered source registry is empty. Check --families/--taus.", call. = FALSE)
}
verification <- ffv2_verify_source_windows(registry, stop_on_fail = !allow_missing_source)
candidates <- ffv2_read_vb_calibration_candidates(candidates_path)
manifest <- ffv2_prepare_vb_calibration_screen_manifest(
  defaults = defaults,
  registry = registry,
  candidates = candidates,
  run_root = run_root,
  dry_run = dry_run,
  overwrite = overwrite
)

sentinels <- manifest[as.logical(manifest$screen_sentinel), , drop = FALSE]
candidate_counts <- as.data.frame(table(manifest$candidate_id), stringsAsFactors = FALSE)
names(candidate_counts) <- c("candidate_id", "rows")
sentinel_counts <- as.data.frame(table(sentinels$candidate_id), stringsAsFactors = FALSE)
names(sentinel_counts) <- c("candidate_id", "sentinel_rows")

cat("exDQLM/DQLM VB calibration screen prepare\n")
cat(sprintf("repo_root: %s\n", ffv2_repo_root()))
cat(sprintf("defaults: %s\n", normalizePath(defaults_path, winslash = "/", mustWork = TRUE)))
cat(sprintf("candidates: %s\n", normalizePath(candidates_path, winslash = "/", mustWork = TRUE)))
cat(sprintf("run_tag: %s\n", defaults$study$run_tag))
cat(sprintf("dry_run: %s\n", dry_run))
cat(sprintf("family_filter: %s\n", if (length(families)) paste(families, collapse = ",") else "<all>"))
cat(sprintf("tau_filter: %s\n", if (length(taus)) paste(taus, collapse = ",") else "<all>"))
cat(sprintf("source_rows: %d\n", nrow(registry)))
cat(sprintf("candidate_rows: %d\n", nrow(candidates)))
cat(sprintf("manifest_rows: %d\n", nrow(manifest)))
cat(sprintf("sentinel_rows: %d\n", nrow(sentinels)))
cat(sprintf("unique_spec_ids: %d of %d\n", length(unique(manifest$spec_id)), nrow(manifest)))
cat("source_window_status:\n")
print(table(verification$status, useNA = "ifany"))
cat("phase_counts:\n")
print(table(manifest$phase, useNA = "ifany"))
cat("candidate_counts:\n")
print(candidate_counts)
cat("sentinel_counts:\n")
print(sentinel_counts)
cat("sentinel_preview:\n")
preview_cols <- intersect(
  c("row_id", "candidate_id", "family", "tau", "model_variant", "spec_id"),
  names(sentinels)
)
print(utils::head(sentinels[, preview_cols, drop = FALSE], 24L))
if (!dry_run) {
  run_root_out <- unique(manifest$run_root)[[1L]]
  cat(sprintf("run_root: %s\n", run_root_out))
  cat(sprintf("row_manifest: %s\n", file.path(run_root_out, "manifests", "row_manifest.csv")))
  cat(sprintf("sentinel_rows: %s\n", file.path(run_root_out, "manifests", "sentinel_rows.csv")))
  cat(sprintf("sentinel_row_ids: %s\n", file.path(run_root_out, "manifests", "sentinel_row_ids.txt")))
}

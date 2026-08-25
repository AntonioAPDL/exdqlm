#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/verify_independent_metric_interval_evidence_bundle_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/", mustWork = TRUE)
bundle_root <- normalizePath(args$`bundle-root` %||% "", winslash = "/", mustWork = TRUE)
audit_dir <- normalizePath(args$`audit-dir` %||% imic_v1_audit_dir(repo_root),
                           winslash = "/", mustWork = FALSE)
promotion_dir <- imic_v1_promotion_dir(repo_root)
ledger <- ffv2_read_csv(file.path(bundle_root, "bundle_file_manifest.csv"))

observed <- lapply(seq_len(nrow(ledger)), function(i) {
  path <- file.path(bundle_root, ledger$relative_path[[i]])
  data.frame(
    relative_path = ledger$relative_path[[i]],
    exists = file.exists(path),
    bytes_match = file.exists(path) && as.numeric(file.info(path)$size) == ledger$bytes[[i]],
    hash_match = file.exists(path) && identical(ffv2_file_sha256(path), ledger$sha256[[i]]),
    stringsAsFactors = FALSE
  )
})
observed <- do.call(rbind, observed)
if (!all(observed$exists & observed$bytes_match & observed$hash_match)) {
  stop("Portable bundle member verification failed.", call. = FALSE)
}

job_audit <- ffv2_read_csv(file.path(promotion_dir, "job_artifact_audit.csv"))
draw_rows <- ledger[ledger$artifact_role == "metric_draws", , drop = FALSE]
if (nrow(draw_rows) != 198L || anyDuplicated(draw_rows$job_id)) {
  stop("Portable bundle does not contain exactly 198 unique metric-draw files.", call. = FALSE)
}
draw_index <- merge(
  job_audit[c("job_id", "replay_id", "engine", "inference", "model_variant",
              "family", "tau", "chain_id", "metric_draws_sha256")],
  draw_rows[c("job_id", "relative_path", "sha256")], by = "job_id", all = TRUE
)
draw_index$draw_path <- file.path(bundle_root, draw_index$relative_path)
draw_index$promoted_hash_match <- draw_index$metric_draws_sha256 == draw_index$sha256
if (nrow(draw_index) != 198L || any(!draw_index$promoted_hash_match)) {
  stop("Portable draw files do not match the promoted per-job hashes.", call. = FALSE)
}

recomputed <- imic_v1_recompute_source_summaries(draw_index, promotion_dir)
comparison <- imic_v1_compare_replay_to_promotion(recomputed, promotion_dir)
checks <- data.frame(
  check = c("bundle_members_verified", "metric_draw_files_198", "promoted_hashes_match",
            "source_identities_90", "source_metric_rows_270", "all_summaries_match",
            "no_fitted_model_binaries"),
  pass = c(
    all(observed$exists & observed$bytes_match & observed$hash_match),
    nrow(draw_rows) == 198L,
    all(draw_index$promoted_hash_match),
    length(unique(recomputed$replay_id)) == 90L,
    nrow(recomputed) == 270L,
    all(comparison$all_match),
    !any(grepl("[.](rds|rda|RData)$", ledger$relative_path, ignore.case = TRUE))
  ),
  stringsAsFactors = FALSE
)

ffv2_ensure_dir(audit_dir)
ffv2_write_csv(observed, file.path(audit_dir, "portable_bundle_member_verification.csv"))
ffv2_write_csv(draw_index, file.path(audit_dir, "portable_bundle_draw_index.csv"))
ffv2_write_csv(recomputed, file.path(audit_dir, "recomputed_source_interval_summary.csv"))
ffv2_write_csv(comparison, file.path(audit_dir, "recomputed_vs_promoted_comparison.csv"))
ffv2_write_csv(checks, file.path(audit_dir, "raw_evidence_replay_checks.csv"))
manifest <- list(
  schema_version = imic_v1_schema,
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  status = if (all(checks$pass)) "PASS" else "FAIL",
  bundle_root = bundle_root,
  bundle_file_manifest_sha256 = ffv2_file_sha256(
    file.path(bundle_root, "bundle_file_manifest.csv")
  ),
  metric_draw_files = nrow(draw_rows),
  source_identities = length(unique(recomputed$replay_id)),
  source_metric_rows = nrow(recomputed),
  mismatches = sum(!comparison$all_match),
  checks_sha256 = ffv2_file_sha256(file.path(audit_dir, "raw_evidence_replay_checks.csv")),
  comparison_sha256 = ffv2_file_sha256(
    file.path(audit_dir, "recomputed_vs_promoted_comparison.csv")
  )
)
ffv2_write_json(manifest, file.path(audit_dir, "raw_evidence_replay_manifest.json"))
cat(sprintf("status=%s files=%d sources=%d summaries=%d mismatches=%d\n",
            manifest$status, manifest$metric_draw_files, manifest$source_identities,
            manifest$source_metric_rows, manifest$mismatches))
if (!all(checks$pass)) quit(save = "no", status = 1L)

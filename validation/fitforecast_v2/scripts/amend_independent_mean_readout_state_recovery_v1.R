#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/amend_independent_mean_readout_state_recovery_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/",
                           mustWork = TRUE)
state_root <- normalizePath(args$`state-root` %||% "", winslash = "/",
                            mustWork = TRUE)
setwd(repo_root)

manifest_path <- file.path(state_root, "manifests", "materialization_manifest.json")
artifact_path <- file.path(state_root, "manifests", "materialized_artifacts.csv")
manifest <- imrs_v1_read_json(manifest_path)
artifacts <- ffv2_read_csv(artifact_path)
current_commit <- system("git rev-parse HEAD", intern = TRUE)
recovery_id <- "endpoint_review_source_pool_v1"
recovery_root <- file.path(state_root, "manifests", "recovery", recovery_id)
record_path <- file.path(recovery_root, "recovery_amendment.json")

if (!is.null(manifest$recovery_amendment)) {
  amendment <- manifest$recovery_amendment
  checks <- c(
    recovery_id = identical(as.character(amendment$recovery_id), recovery_id),
    recovery_commit = identical(
      as.character(amendment$recovery_git_commit), current_commit
    ),
    artifact_hash = identical(
      ffv2_file_sha256(artifact_path), as.character(manifest$artifact_manifest_sha256)
    ),
    record_hash = file.exists(amendment$record_path) && identical(
      ffv2_file_sha256(amendment$record_path), as.character(amendment$record_sha256)
    )
  )
  if (!all(checks)) {
    stop("Existing recovery amendment is inconsistent: ",
         paste(names(checks)[!checks], collapse = ", "), call. = FALSE)
  }
  cat("RECOVERY_AMENDMENT_ALREADY_VERIFIED commit=", current_commit, "\n",
      sep = "")
  quit(save = "no", status = 0L)
}

if (!identical(
  ffv2_file_sha256(artifact_path), as.character(manifest$artifact_manifest_sha256)
)) stop("Frozen artifact-manifest file changed before recovery.", call. = FALSE)

dir.create(recovery_root, recursive = TRUE, showWarnings = FALSE)
original_manifest_sha256 <- ffv2_file_sha256(manifest_path)
original_artifact_sha256 <- ffv2_file_sha256(artifact_path)
original_manifest_copy <- file.path(recovery_root, "materialization_manifest.original.json")
original_artifact_copy <- file.path(recovery_root, "materialized_artifacts.original.csv")
if (!file.copy(manifest_path, original_manifest_copy, overwrite = FALSE) ||
    !file.copy(artifact_path, original_artifact_copy, overwrite = FALSE)) {
  stop("Could not archive the frozen pre-recovery manifests.", call. = FALSE)
}

relative_runtime_files <- c(
  "validation/fitforecast_v2/R/independent_mean_readout_state_forecast_v1.R",
  "validation/fitforecast_v2/scripts/run_independent_mean_readout_state_fit_job.R",
  "validation/fitforecast_v2/scripts/run_independent_mean_readout_state_forecast_job.R",
  "validation/fitforecast_v2/scripts/orchestrate_independent_mean_readout_state_forecast_v1.R",
  "validation/fitforecast_v2/scripts/closeout_independent_mean_readout_state_forecast_v1.R",
  "validation/fitforecast_v2/scripts/verify_independent_mean_readout_state_forecast_v1.R"
)
runtime_files <- normalizePath(
  file.path(repo_root, relative_runtime_files), winslash = "/", mustWork = TRUE
)
indices <- match(runtime_files, artifacts$path)
if (anyNA(indices)) {
  stop("Recovery file is absent from the frozen artifact manifest: ",
       paste(relative_runtime_files[is.na(indices)], collapse = ", "), call. = FALSE)
}
change_ledger <- data.frame(
  path = runtime_files,
  original_sha256 = artifacts$sha256[indices],
  recovery_sha256 = vapply(runtime_files, ffv2_file_sha256, character(1L)),
  original_bytes = artifacts$bytes[indices],
  recovery_bytes = as.numeric(file.info(runtime_files)$size),
  stringsAsFactors = FALSE
)
if (!all(change_ledger$original_sha256 != change_ledger$recovery_sha256)) {
  stop("Every declared recovery runtime file must have a changed hash.", call. = FALSE)
}
artifacts$sha256[indices] <- change_ledger$recovery_sha256
artifacts$bytes[indices] <- change_ledger$recovery_bytes

recovery_scripts <- normalizePath(file.path(
  harness_root, "scripts", c(
    "amend_independent_mean_readout_state_recovery_v1.R",
    "backfill_independent_mean_readout_state_source_pool_v1.R"
  )
), winslash = "/", mustWork = TRUE)
for (recovery_script in recovery_scripts) {
  if (!recovery_script %in% artifacts$path) {
    artifacts <- rbind(artifacts, data.frame(
      path = recovery_script,
      bytes = as.numeric(file.info(recovery_script)$size),
      sha256 = ffv2_file_sha256(recovery_script),
      stringsAsFactors = FALSE
    ))
  }
}
imrs_v1_atomic_write_csv(artifacts, artifact_path)

record <- list(
  schema_version = "independent_mean_readout_state_recovery_amendment_v1",
  recovery_id = recovery_id,
  reason = paste(
    "An isolated MCMC chain passed mean, empirical-distribution, and interval",
    "overlap checks but missed the per-chain endpoint-width check. The frozen",
    "threshold remains unchanged; endpoint-only chain review is now resolved by",
    "a strict balanced source-pool compatibility gate before forecasting."
  ),
  original_materialization_git_commit = as.character(manifest$git_commit),
  recovery_git_commit = current_commit,
  original_materialization_manifest_sha256 = original_manifest_sha256,
  original_artifact_manifest_sha256 = original_artifact_sha256,
  updated_artifact_manifest_sha256 = ffv2_file_sha256(artifact_path),
  original_manifest_copy = normalizePath(
    original_manifest_copy, winslash = "/", mustWork = TRUE
  ),
  original_artifact_copy = normalizePath(
    original_artifact_copy, winslash = "/", mustWork = TRUE
  ),
  changed_runtime_files = lapply(seq_len(nrow(change_ledger)), function(i) {
    as.list(change_ledger[i, , drop = FALSE])
  }),
  amended_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
)
imrs_v1_atomic_write_json(record, record_path)
manifest$artifact_manifest_sha256 <- ffv2_file_sha256(artifact_path)
manifest$recovery_amendment <- list(
  recovery_id = recovery_id,
  recovery_git_commit = current_commit,
  record_path = normalizePath(record_path, winslash = "/", mustWork = TRUE),
  record_sha256 = ffv2_file_sha256(record_path),
  original_materialization_manifest_sha256 = original_manifest_sha256,
  original_artifact_manifest_sha256 = original_artifact_sha256
)
imrs_v1_atomic_write_json(manifest, manifest_path)
cat("RECOVERY_AMENDMENT_APPLIED commit=", current_commit,
    " changed_runtime_files=", nrow(change_ledger), "\n", sep = "")

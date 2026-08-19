#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Missing package: jsonlite", call. = FALSE)
  }
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (!length(i) || i[[1L]] >= length(args)) return(default)
  args[[i[[1L]] + 1L]]
}

repo_root <- normalizePath(get_arg(
  "--repo-root", system("git rev-parse --show-toplevel", intern = TRUE)
), winslash = "/", mustWork = TRUE)
setwd(repo_root)
source(file.path(
  repo_root, "validation", "fitforecast_v2", "R",
  "qdesn_postm0_legacy_recheck_v1.R"
))

state_root <- normalizePath(get_arg("--state-root"), winslash = "/",
                            mustWork = TRUE)
run_tag <- get_arg("--run-tag")
if (is.null(run_tag) || !nzchar(run_tag)) {
  stop("--run-tag is required.", call. = FALSE)
}

expected_branch <- qdesn_plrv1_branch
expected_original_commit <-
  "9db909c9ef6dfd95c9f40267bc19012401520aea"
expected_execution_recovery_commit <-
  "c5317e7fbf39e37e7f5425a9046109bc24443a4f"
branch <- system("git branch --show-current", intern = TRUE)
head_commit <- system("git rev-parse HEAD", intern = TRUE)
if (!identical(branch, expected_branch)) {
  stop(sprintf("Recovery refused outside %s.", expected_branch), call. = FALSE)
}
if (system2(
  "git", c("merge-base", "--is-ancestor", expected_execution_recovery_commit,
           head_commit), stdout = FALSE, stderr = FALSE
) != 0L) {
  stop("The replication execution recovery commit is not an ancestor of HEAD.",
       call. = FALSE)
}

materialization_root <- file.path(state_root, "materialization")
adaptive_root <- file.path(state_root, "adaptive")
manifest_path <- file.path(materialization_root, "materialization_manifest.json")
plan_path <- file.path(adaptive_root, "tier_a_replication_plan.csv")
if (any(!file.exists(c(manifest_path, plan_path)))) {
  stop("Materialization manifest or replication plan is missing.", call. = FALSE)
}

recovery_root <- file.path(
  state_root, "recovery", "tier_a_replication_closeout_20260815"
)
dir.create(recovery_root, recursive = TRUE, showWarnings = FALSE)
original_manifest_path <- file.path(
  recovery_root, "original_materialization_manifest.json"
)
original_tracked_path <- file.path(
  recovery_root, "original_tracked_manifest.csv"
)

manifest <- qdesn_ssv2_read_json(manifest_path)
tracked_manifest_path <- normalizePath(
  as.character(manifest$tracked_manifest_path), winslash = "/", mustWork = TRUE
)
if (!file.exists(original_manifest_path)) {
  if (!identical(as.character(manifest$git_commit), expected_original_commit)) {
    stop("The unsnapshotted materialization manifest is not the frozen original.",
         call. = FALSE)
  }
  if (!identical(
    qdesn_ssv2_sha256(tracked_manifest_path),
    as.character(manifest$tracked_manifest_sha256)
  )) {
    stop("The original tracked manifest hash does not match.", call. = FALSE)
  }
  if (!file.copy(manifest_path, original_manifest_path, overwrite = FALSE) ||
      !file.copy(tracked_manifest_path, original_tracked_path, overwrite = FALSE)) {
    stop("Failed to freeze the original materialization evidence.", call. = FALSE)
  }
}
if (any(!file.exists(c(original_manifest_path, original_tracked_path)))) {
  stop("Original recovery snapshots are incomplete.", call. = FALSE)
}
original_manifest <- qdesn_ssv2_read_json(original_manifest_path)
if (!identical(as.character(original_manifest$git_commit),
               expected_original_commit) ||
    !identical(qdesn_ssv2_sha256(original_tracked_path),
               as.character(original_manifest$tracked_manifest_sha256))) {
  stop("Original recovery snapshots failed their frozen hashes.", call. = FALSE)
}

plan <- qdesn_ssv2_read_csv(plan_path)
if (nrow(plan) != 20L || anyDuplicated(plan$job_id) ||
    anyDuplicated(plan$config_path)) {
  stop("Replication recovery requires exactly 20 unique jobs.", call. = FALSE)
}

metric_names <- c(
  "fit_qtrue_rmse", "forecast_qtrue_mae_H1000",
  "forecast_check_loss_H1000"
)
job_rows <- vector("list", nrow(plan))
file_rows <- list()
file_index <- 0L
for (i in seq_len(nrow(plan))) {
  job_id <- as.character(plan$job_id[[i]])
  config_path <- normalizePath(as.character(plan$config_path[[i]]),
                               winslash = "/", mustWork = TRUE)
  job_root <- qdesn_plrv1_job_root(repo_root, run_tag, job_id)
  status_path <- file.path(job_root, "job_status.json")
  if (!file.exists(status_path)) {
    stop(sprintf("Missing replication status: %s", job_id), call. = FALSE)
  }
  status <- qdesn_ssv2_read_json(status_path)
  config_hash <- qdesn_ssv2_sha256(config_path)
  if (!identical(as.character(status$status), "SUCCESS") ||
      !identical(config_hash, as.character(plan$config_sha256[[i]])) ||
      !identical(as.character(status$config_sha256), config_hash)) {
    stop(sprintf("Replication job failed its frozen config/status gate: %s",
                 job_id), call. = FALSE)
  }
  retained <- sort(list.files(
    job_root, recursive = TRUE, full.names = TRUE, all.files = TRUE,
    no.. = TRUE
  ))
  retained <- retained[file.info(retained)$isdir %in% FALSE]
  binary <- retained[grepl("[.](rds|rda|RData)$", retained,
                           ignore.case = TRUE)]
  if (length(binary)) {
    stop(sprintf("Replication job retains a forbidden binary: %s", job_id),
         call. = FALSE)
  }
  signoff_path <- file.path(job_root, "signoff_summary.csv")
  signoff <- if (file.exists(signoff_path)) {
    qdesn_ssv2_read_csv(signoff_path)
  } else {
    data.frame(signoff_grade = "MISSING", signoff_reason = "missing")
  }
  values <- vapply(metric_names, function(metric) {
    as.numeric(status$metric_values[[metric]] %||% NA_real_)
  }, numeric(1L))
  job_rows[[i]] <- data.frame(
    job_id = job_id,
    target_cell_id = as.character(plan$target_cell_id[[i]]),
    candidate_id = as.character(plan$candidate_id[[i]]),
    source_id = as.character(plan$source_id[[i]]),
    status = as.character(status$status),
    config_path = qdesn_ssv2_rel(config_path, repo_root),
    config_sha256 = config_hash,
    status_path = qdesn_ssv2_rel(status_path, repo_root),
    status_sha256 = qdesn_ssv2_sha256(status_path),
    fit_qtrue_rmse = values[["fit_qtrue_rmse"]],
    forecast_qtrue_mae_H1000 = values[["forecast_qtrue_mae_H1000"]],
    forecast_check_loss_H1000 =
      values[["forecast_check_loss_H1000"]],
    signoff_grade = as.character(signoff$signoff_grade[[1L]]),
    signoff_reason = as.character(signoff$signoff_reason[[1L]]),
    retained_file_count = length(retained),
    retained_bytes = sum(file.info(retained)$size),
    binary_payload_count = 0L,
    stringsAsFactors = FALSE
  )
  for (path in retained) {
    file_index <- file_index + 1L
    file_rows[[file_index]] <- data.frame(
      job_id = job_id,
      relative_path = qdesn_ssv2_rel(path, repo_root),
      bytes = as.numeric(file.info(path)$size),
      sha256 = qdesn_ssv2_sha256(path),
      stringsAsFactors = FALSE
    )
  }
}
jobs <- do.call(rbind, job_rows)
files <- do.call(rbind, file_rows)
if (nrow(jobs) != 20L || any(jobs$status != "SUCCESS") ||
    any(!is.finite(as.matrix(jobs[, metric_names, drop = FALSE]))) ||
    any(jobs$binary_payload_count != 0L) || anyDuplicated(files$relative_path)) {
  stop("Replication evidence failed the recovery freeze gate.", call. = FALSE)
}

job_manifest_path <- qdesn_ssv2_write_csv(
  jobs, file.path(recovery_root, "tier_a_replication_job_manifest.csv")
)
file_manifest_path <- qdesn_ssv2_write_csv(
  files, file.path(recovery_root, "tier_a_replication_retained_file_manifest.csv")
)

tracked <- qdesn_plrv1_tracked_manifest(repo_root)
qdesn_ssv2_write_csv(tracked, tracked_manifest_path)
tracked_hash <- qdesn_ssv2_sha256(tracked_manifest_path)
dirty_before <- system(
  "git status --porcelain --untracked-files=no", intern = TRUE
)
recovery_status <- if (length(dirty_before)) "PRECOMMIT" else "COMPLETE"

recovery_record <- list(
  schema_version = "qdesn_postm0_legacy_recheck_v1_replication_recovery_v1",
  generated_at = as.character(Sys.time()),
  status = recovery_status,
  run_tag = run_tag,
  original_git_commit = expected_original_commit,
  execution_recovery_commit = expected_execution_recovery_commit,
  closeout_recovery_commit = if (recovery_status == "COMPLETE") {
    head_commit
  } else {
    "PENDING_COMMIT"
  },
  branch = branch,
  original_materialization_manifest_path = original_manifest_path,
  original_materialization_manifest_sha256 =
    qdesn_ssv2_sha256(original_manifest_path),
  original_tracked_manifest_path = original_tracked_path,
  original_tracked_manifest_sha256 = qdesn_ssv2_sha256(original_tracked_path),
  current_tracked_manifest_path = tracked_manifest_path,
  current_tracked_manifest_sha256 = tracked_hash,
  tracked_file_count = nrow(tracked),
  replication_plan_path = plan_path,
  replication_plan_sha256 = qdesn_ssv2_sha256(plan_path),
  replication_job_manifest_path = job_manifest_path,
  replication_job_manifest_sha256 = qdesn_ssv2_sha256(job_manifest_path),
  replication_retained_file_manifest_path = file_manifest_path,
  replication_retained_file_manifest_sha256 =
    qdesn_ssv2_sha256(file_manifest_path),
  replication_jobs = nrow(jobs),
  replication_successes = sum(jobs$status == "SUCCESS"),
  replication_retained_files = nrow(files),
  replication_retained_bytes = sum(files$bytes),
  replication_binary_payloads = sum(jobs$binary_payload_count),
  model_outputs_recomputed = FALSE,
  article_state = "v6_frozen_unchanged",
  tracked_worktree_changes_before_recovery = as.list(dirty_before)
)
recovery_manifest_path <- qdesn_ssv2_write_json(
  recovery_record, file.path(recovery_root, "recovery_manifest.json")
)

manifest$tracked_manifest_sha256 <- tracked_hash
manifest$recovery <- list(
  status = recovery_status,
  recovery_manifest_path = recovery_manifest_path,
  recovery_manifest_sha256 = qdesn_ssv2_sha256(recovery_manifest_path),
  original_git_commit = expected_original_commit,
  execution_recovery_commit = expected_execution_recovery_commit,
  closeout_recovery_commit = recovery_record$closeout_recovery_commit,
  model_outputs_recomputed = FALSE
)
qdesn_ssv2_write_json(manifest, manifest_path)

writeLines(c(
  sprintf("RUN_TAG=%s", run_tag),
  sprintf("RECOVERY_STATUS=%s", recovery_status),
  sprintf("ORIGINAL_GIT_COMMIT=%s", expected_original_commit),
  sprintf("EXECUTION_RECOVERY_COMMIT=%s", expected_execution_recovery_commit),
  sprintf("CLOSEOUT_RECOVERY_COMMIT=%s",
          recovery_record$closeout_recovery_commit),
  sprintf("RECOVERY_MANIFEST=%s", recovery_manifest_path),
  "MODEL_OUTPUTS_RECOMPUTED=FALSE",
  "ARTICLE_STATE=v6_frozen_unchanged"
), file.path(recovery_root, "recovery_run_tags.env"))

cat(sprintf(
  paste0(
    "recovery_status=%s jobs=%d files=%d bytes=%d tracked=%d ",
    "model_outputs_recomputed=false\n"
  ),
  recovery_status, nrow(jobs), nrow(files), sum(files$bytes), nrow(tracked)
))

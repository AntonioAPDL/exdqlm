#!/usr/bin/env Rscript

suppressPackageStartupMessages(requireNamespace("jsonlite", quietly = TRUE))

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/", mustWork = TRUE
)
setwd(repo_root)
source(file.path(
  repo_root, "validation", "fitforecast_v2", "R",
  "qdesn_lower_tail_cellwise_mcmc_v1.R"
))

run_id <- "qdesn_lower_tail_cellwise_mcmc_v1_tiera_20260811_215538"
run_tag <- "qdesn-lower-tail-cellwise-mcmc-v1-tiera-20260811_215538__git-c050ccf"
result_root <- file.path(
  repo_root, "results", "qdesn_mcmc_validation", qdesn_ltcv1_stage
)
jobs_root <- file.path(result_root, run_tag, "jobs")
state_root <- file.path(
  repo_root, "reports", "shared_fitforecast_v2_orchestration", run_id
)
evidence_dir <- file.path(
  repo_root, "validation", "fitforecast_v2", "docs",
  "qdesn_lower_tail_cellwise_mcmc_v1_cleanup_20260813"
)
dir.create(evidence_dir, recursive = TRUE, showWarnings = FALSE)

read_csv <- function(path) utils::read.csv(
  path, stringsAsFactors = FALSE, check.names = FALSE
)
read_json <- function(path) jsonlite::read_json(path, simplifyVector = TRUE)
write_csv <- function(x, path) utils::write.csv(x, path, row.names = FALSE, na = "")
write_json <- function(x, path) jsonlite::write_json(
  x, path, pretty = TRUE, auto_unbox = TRUE, digits = NA, null = "null"
)

job_roots <- sort(list.dirs(jobs_root, recursive = FALSE, full.names = TRUE))
confirmation <- startsWith(basename(job_roots), "tier_a_confirmation__")
status <- vapply(file.path(job_roots, "job_status.json"), function(path) {
  if (!file.exists(path)) return("MISSING")
  as.character(read_json(path)$status)
}, character(1L))

required_relpaths <- c(
  "job_status.json", "fit_summary_row.csv", "signoff_summary.csv",
  file.path("manifest", "output_retention.json"),
  file.path("tables", "forecast_lead_metrics.csv"),
  file.path("tables", "forecast_horizon_summary.csv"),
  file.path("logs", "pipeline_stdout.log"),
  file.path("logs", "pipeline_child_live.log")
)
required_paths <- unlist(lapply(job_roots, function(root) {
  file.path(root, required_relpaths)
}), use.names = FALSE)

dense_relpaths <- c(
  "latent_v_trace.csv", "theta_trace.csv", "sigmagam_trace.csv",
  file.path("tables", "fit_quantile_path_train.csv"),
  file.path("tables", "fit_quantile_path_holdout.csv"),
  file.path("tables", "forecast_rolling_origin_paths.csv")
)
dense_paths <- function(roots) unlist(lapply(roots, function(root) {
  file.path(root, dense_relpaths)
}), use.names = FALSE)

progress <- do.call(rbind, lapply(job_roots, function(root) {
  path <- file.path(root, "progress_trace.csv")
  x <- if (file.exists(path)) read_csv(path) else data.frame(step = numeric())
  data.frame(
    job_id = basename(root), rows = nrow(x),
    first_step = if (nrow(x)) as.integer(x$step[[1L]]) else NA_integer_,
    final_step = if (nrow(x)) as.integer(x$step[[nrow(x)]]) else NA_integer_,
    stringsAsFactors = FALSE
  )
}))
progress$expected_final_step <- ifelse(
  startsWith(progress$job_id, "smoke__"), 4L,
  ifelse(startsWith(progress$job_id, "calibration__"), 500L,
         ifelse(startsWith(progress$job_id, "tier_a_confirmation__"),
                20000L, 3000L))
)

collected_paths <- file.path(
  state_root, "adaptive", c(
    "tier_a_discovery_collected_results.csv",
    "tier_a_replication_collected_results.csv",
    "tier_a_sealed_collected_results.csv"
  )
)
collected <- do.call(rbind, lapply(collected_paths, read_csv))
compact <- t(vapply(collected$job_id, function(job_id) {
  qdesn_ltcv1_metric_values(file.path(jobs_root, job_id))
}, numeric(length(qdesn_ltcv1_target_metrics))))
colnames(compact) <- qdesn_ltcv1_target_metrics
reference <- as.matrix(collected[, qdesn_ltcv1_target_metrics, drop = FALSE])
equivalence <- data.frame(
  job_id = collected$job_id,
  stage = collected$stage,
  target_cell_id = collected$target_cell_id,
  compact_fit_qtrue_rmse = compact[, "fit_qtrue_rmse"],
  stored_fit_qtrue_rmse = reference[, "fit_qtrue_rmse"],
  compact_forecast_qtrue_mae_H1000 = compact[, "forecast_qtrue_mae_H1000"],
  stored_forecast_qtrue_mae_H1000 = reference[, "forecast_qtrue_mae_H1000"],
  compact_forecast_check_loss_H1000 = compact[, "forecast_check_loss_H1000"],
  stored_forecast_check_loss_H1000 = reference[, "forecast_check_loss_H1000"],
  stringsAsFactors = FALSE
)
equivalence$max_absolute_difference <- apply(abs(compact - reference), 1L, max)
equivalence_path <- file.path(evidence_dir, "compact_metric_equivalence_audit.csv")
write_csv(equivalence, equivalence_path)

post_verification_paths <- file.path(state_root, c(
  "post_cleanup_smoke_verification.json",
  "post_cleanup_calibration_verification.json",
  "post_cleanup_tier_a_discovery_verification.json",
  "post_cleanup_tier_a_replication_verification.json",
  "post_cleanup_tier_a_sealed_verification.json",
  "post_cleanup_confirmation_verification.json"
))
post_decisions <- vapply(post_verification_paths, function(path) {
  if (!file.exists(path)) return("MISSING")
  as.character(read_json(path)$decision)
}, character(1L))

source_binaries <- list.files(
  file.path(result_root, "source_replicates"),
  pattern = "[.](rds|rda|RData)$", recursive = TRUE, full.names = TRUE,
  ignore.case = TRUE
)
job_binaries <- list.files(
  jobs_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
  full.names = TRUE, ignore.case = TRUE
)
removed <- read_csv(file.path(evidence_dir, "cleanup_removed_files.csv"))
compaction <- read_csv(file.path(evidence_dir, "progress_trace_compaction_audit.csv"))

checks <- c(
  branch = identical(system("git branch --show-current", intern = TRUE),
                     qdesn_ltcv1_branch),
  roots = length(job_roots) == 218L && sum(confirmation) == 6L,
  statuses = all(status == "SUCCESS"),
  compact_evidence = all(file.exists(required_paths)),
  nonconfirmation_dense_pruned = !any(file.exists(dense_paths(job_roots[!confirmation]))),
  confirmation_dense_preserved = all(file.exists(dense_paths(job_roots[confirmation]))),
  progress_compacted = nrow(progress) == 218L &&
    all(progress$first_step == 1L) &&
    all(progress$final_step == progress$expected_final_step),
  metric_equivalence = nrow(equivalence) == 204L &&
    all(is.finite(compact)) &&
    max(equivalence$max_absolute_difference) < 1e-12,
  post_stage_verification = all(post_decisions == "PASS"),
  no_fitted_model_binaries = !length(job_binaries),
  source_archives_preserved = length(source_binaries) == 126L &&
    sum(as.numeric(file.info(source_binaries)$size)) == 29039986,
  removal_ledger = nrow(removed) == 1272L &&
    sum(removed$size_bytes) == 592234853,
  compaction_ledger = nrow(compaction) == 218L &&
    sum(compaction$bytes_before - compaction$bytes_after) == 108495775
)
checks[is.na(checks)] <- FALSE
result <- list(
  schema_version = "qdesn_lower_tail_cellwise_mcmc_v1_cleanup_verification_v1",
  generated_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
  decision = if (all(checks)) "PASS" else "FAIL",
  checks = as.list(checks),
  campaign_roots = length(job_roots),
  canonical_confirmation_roots = sum(confirmation),
  compact_metric_rows = nrow(equivalence),
  compact_metric_max_absolute_difference = max(equivalence$max_absolute_difference),
  removed_files = nrow(removed),
  removed_bytes = sum(removed$size_bytes),
  compacted_progress_files = nrow(compaction),
  progress_bytes_recovered = sum(compaction$bytes_before - compaction$bytes_after),
  total_bytes_recovered = sum(removed$size_bytes) +
    sum(compaction$bytes_before - compaction$bytes_after),
  retained_source_archives = length(source_binaries),
  retained_source_archive_bytes = sum(as.numeric(file.info(source_binaries)$size)),
  compact_metric_equivalence_path = normalizePath(
    equivalence_path, winslash = "/", mustWork = TRUE
  )
)
output <- file.path(evidence_dir, "post_cleanup_verification.json")
write_json(result, output)
cat(sprintf(
  "decision=%s checks=%d roots=%d metric_rows=%d max_diff=%.17g recovered_bytes=%d output=%s\n",
  result$decision, length(checks), result$campaign_roots,
  result$compact_metric_rows, result$compact_metric_max_absolute_difference,
  result$total_bytes_recovered, output
))
if (!all(checks)) {
  stop(sprintf("Cleanup verification failed: %s",
               paste(names(checks)[!checks], collapse = ", ")), call. = FALSE)
}

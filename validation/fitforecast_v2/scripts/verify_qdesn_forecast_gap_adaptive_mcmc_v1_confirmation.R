#!/usr/bin/env Rscript

suppressPackageStartupMessages(requireNamespace("jsonlite", quietly = TRUE))
args <- commandArgs(trailingOnly = TRUE)
arg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (!length(i) || i[[1L]] >= length(args)) default else args[[i[[1L]] + 1L]]
}
repo_root <- normalizePath(
  arg("--repo-root", system("git rev-parse --show-toplevel", intern = TRUE)),
  winslash = "/", mustWork = TRUE
)
state_root <- normalizePath(arg("--state-root"), winslash = "/", mustWork = TRUE)
run_tag <- arg("--run-tag", "")
runtime <- identical(arg("--runtime", "false"), "true")
output <- normalizePath(
  arg("--output", file.path(state_root, "confirmation_verification.json")),
  winslash = "/", mustWork = FALSE
)
setwd(repo_root)
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "qdesn_forecast_gap_adaptive_mcmc_v1.R"))
root <- file.path(state_root, "confirmation")
plan <- qdesn_ssv2_read_csv(file.path(root, "confirmation_plan.csv"))
metric_map <- qdesn_ssv2_read_csv(file.path(root, "confirmation_metric_map.csv"))
manifest <- qdesn_ssv2_read_json(file.path(
  root, "confirmation_materialization_manifest.json"
))
jobs <- if (nrow(plan)) lapply(plan$config_path, qdesn_ssv2_read_json) else list()
job_ok <- if (length(jobs)) vapply(seq_along(jobs), function(i) {
  x <- jobs[[i]]
  likelihood <- as.character(x$likelihood_target)
  method_ok <- likelihood != "exal" || identical(
    as.character(x$config$inference$mcmc$slice$core_update_mode),
    qdesn_ssv2_method_id
  )
  identical(x$stage, "confirmation") && x$source_id == "canonical_article" &&
    x$source_role == "canonical_confirmation" &&
    x$reservoir_seed_id == "canonical_r01" && method_ok &&
    identical(as.integer(x$config$inference$mcmc$n_burn), 5000L) &&
    identical(as.integer(x$config$inference$mcmc$n_mcmc), 20000L) &&
    identical(as.integer(x$config$cpp$postpred_threads), 1L) &&
    isTRUE(x$study_contract$explicit_campaign_approval) &&
    isTRUE(x$study_contract$canonical_source_materialized) &&
    identical(x$source_registry_hash_value, qdesn_ssv2_registry_hash) &&
    identical(qdesn_ssv2_sha256(plan$config_path[[i]]), plan$config_sha256[[i]]) &&
    identical(qdesn_ssv2_sha256(x$observed_path), x$observed_sha256) &&
    !isTRUE(x$config$outputs$keep_draws) &&
    !isTRUE(x$config$outputs$keep_mcmc_vb_init) &&
    !isTRUE(x$config$outputs$save_forecast_objects) &&
    !isTRUE(x$config$outputs$retain_full_rds_on_failure)
}, logical(1L)) else logical()

groups <- if (nrow(plan)) table(paste(plan$target_cell_id, plan$candidate_id)) else integer()
checks <- c(
  branch = identical(system("git branch --show-current", intern = TRUE),
                     qdesn_fgav1_branch),
  plan = nrow(plan) <= 42L && (!nrow(plan) || (
    all(groups == 3L) && identical(sort(unique(plan$chain_id)), 1:3)
  )),
  metric_map = nrow(metric_map) <= 14L && !anyDuplicated(paste(
    metric_map$target_cell_id, metric_map$metric, sep = "\r"
  )),
  manifest = manifest$confirmation_jobs == nrow(plan) &&
    manifest$metric_roles == nrow(metric_map) &&
    isTRUE(manifest$explicit_campaign_approval),
  jobs = !length(job_ok) || all(job_ok),
  materialization_storage = !length(list.files(
    root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
    ignore.case = TRUE
  ))
)

runtime_rows <- data.frame()
if (runtime && nrow(plan)) {
  runtime_rows <- do.call(rbind, lapply(seq_len(nrow(plan)), function(i) {
    job_root <- qdesn_fgav1_job_root(repo_root, run_tag, plan$job_id[[i]])
    status_path <- file.path(job_root, "job_status.json")
    status <- if (file.exists(status_path)) qdesn_ssv2_read_json(status_path) else
      list(status = "MISSING")
    metrics <- qdesn_fgav1_metric_values(job_root)
    required <- strsplit(plan$target_metrics[[i]], ";", fixed = TRUE)[[1L]]
    data.frame(
      job_id = plan$job_id[[i]], status = status$status %||% "MISSING",
      metrics_finite = all(is.finite(metrics[required])),
      binary_count = as.integer(status$binary_payloads_remaining %||% NA_integer_),
      config_hash_match = identical(status$config_sha256, plan$config_sha256[[i]]),
      elapsed_seconds = as.numeric(status$elapsed_seconds %||% NA_real_),
      stringsAsFactors = FALSE
    )
  }))
  qdesn_ssv2_write_csv(runtime_rows, sub("[.]json$", "_runtime.csv", output))
  checks <- c(
    checks, runtime_complete = nrow(runtime_rows) == nrow(plan),
    runtime_success = all(runtime_rows$status == "SUCCESS"),
    runtime_metrics = all(runtime_rows$metrics_finite),
    runtime_storage = all(runtime_rows$binary_count == 0L),
    runtime_config = all(runtime_rows$config_hash_match)
  )
} else if (runtime) {
  checks <- c(checks, zero_job_closeout = nrow(metric_map) == 0L)
}

result <- list(
  schema_version = "qdesn_forecast_gap_adaptive_mcmc_v1_confirmation_verification_v1",
  generated_at = as.character(Sys.time()), runtime = runtime,
  decision = if (all(checks)) "PASS" else "FAIL", checks = as.list(checks),
  runtime_rows = nrow(runtime_rows)
)
qdesn_ssv2_write_json(result, output)
cat(sprintf("confirmation_verification decision=%s checks=%d\n",
            result$decision, length(checks)))
if (!all(checks)) {
  stop(sprintf("Confirmation verification failed: %s",
               paste(names(checks)[!checks], collapse = ", ")))
}

#!/usr/bin/env Rscript

suppressPackageStartupMessages(requireNamespace("jsonlite", quietly = TRUE))
args <- commandArgs(trailingOnly = TRUE)
arg <- function(flag, default = NULL) { i <- which(args == flag); if (!length(i) || i[[1L]] >= length(args)) default else args[[i[[1L]] + 1L]] }
repo_root <- normalizePath(arg("--repo-root", system("git rev-parse --show-toplevel", intern = TRUE)), winslash = "/", mustWork = TRUE)
state_root <- normalizePath(arg("--state-root"), winslash = "/", mustWork = TRUE)
run_tag <- arg("--run-tag", "")
runtime <- identical(arg("--runtime", "false"), "true")
output <- normalizePath(arg("--output", file.path(state_root, "confirmation_verification.json")), winslash = "/", mustWork = FALSE)
setwd(repo_root)
source(file.path(repo_root, "validation", "fitforecast_v2", "R", "qdesn_tierb_cellwise_mcmc_v1.R"))
root <- file.path(state_root, "confirmation")
plan <- qdesn_ssv2_read_csv(file.path(root, "confirmation_plan.csv"))
manifest <- qdesn_ssv2_read_json(file.path(root, "confirmation_materialization_manifest.json"))
jobs <- lapply(plan$config_path, qdesn_ssv2_read_json)
job_ok <- vapply(seq_along(jobs), function(i) {
  x <- jobs[[i]]
  identical(x$stage, "tier_b_confirmation") && x$source_id == "canonical_article" &&
    x$source_role == "canonical_confirmation" && x$reservoir_seed_id == "canonical_r01" &&
    identical(x$likelihood_target, "al") &&
    !identical(x$config$inference$mcmc$slice$core_update_mode,
               qdesn_ssv2_method_id) &&
    identical(as.integer(x$config$inference$mcmc$n_burn), 5000L) &&
    identical(as.integer(x$config$inference$mcmc$n_mcmc), 20000L) &&
    identical(as.integer(x$config$cpp$postpred_threads), 1L) &&
    isTRUE(x$study_contract$explicit_human_approval) &&
    isTRUE(x$study_contract$canonical_source_materialized) &&
    identical(x$source_registry_hash_value, qdesn_ssv2_registry_hash) &&
    identical(qdesn_ssv2_sha256(plan$config_path[[i]]), plan$config_sha256[[i]]) &&
    identical(qdesn_ssv2_sha256(x$observed_path), x$observed_sha256) &&
    !isTRUE(x$config$outputs$keep_draws) && !isTRUE(x$config$outputs$keep_mcmc_vb_init) &&
    !isTRUE(x$config$outputs$save_forecast_objects) &&
    !isTRUE(x$config$outputs$retain_full_rds_on_failure)
}, logical(1L))
checks <- c(
  branch = identical(system("git branch --show-current", intern = TRUE), qdesn_tbcv1_branch),
  plan = nrow(plan) >= 3L && nrow(plan) <= 12L && nrow(plan) %% 3L == 0L &&
    all(table(plan$target_cell_id) == 3L) &&
    identical(sort(unique(plan$chain_id)), 1:3),
  manifest = manifest$confirmation_jobs == nrow(plan) &&
    isTRUE(manifest$explicit_human_approval) &&
    identical(manifest$source_registry_hash_value, qdesn_ssv2_registry_hash),
  jobs = all(job_ok),
  materialization_storage = !length(list.files(root, pattern = "[.](rds|rda|RData)$", recursive = TRUE, ignore.case = TRUE))
)
runtime_rows <- data.frame()
if (runtime) {
  runtime_rows <- do.call(rbind, lapply(seq_len(nrow(plan)), function(i) {
    job_root <- qdesn_tbcv1_job_root(repo_root, run_tag, plan$job_id[[i]])
    status_path <- file.path(job_root, "job_status.json")
    status <- if (file.exists(status_path)) qdesn_ssv2_read_json(status_path) else list(status = "MISSING")
    metrics <- qdesn_tbcv1_metric_values(job_root)
    data.frame(job_id = plan$job_id[[i]], status = status$status %||% "MISSING",
      metric_finite = is.finite(metrics[[plan$metric[[i]]]]),
      binary_count = as.integer(status$binary_payloads_remaining %||% NA_integer_),
      config_hash_match = identical(status$config_sha256, plan$config_sha256[[i]]),
      elapsed_seconds = as.numeric(status$elapsed_seconds %||% NA_real_))
  }))
  qdesn_ssv2_write_csv(runtime_rows, sub("[.]json$", "_runtime.csv", output))
  checks <- c(checks, runtime_complete = nrow(runtime_rows) == nrow(plan),
              runtime_success = all(runtime_rows$status == "SUCCESS"),
              runtime_metrics = all(runtime_rows$metric_finite),
              runtime_storage = all(runtime_rows$binary_count == 0L),
              runtime_config = all(runtime_rows$config_hash_match))
}
result <- list(schema_version = "qdesn_tierb_cellwise_mcmc_v1_confirmation_verification_v1",
               generated_at = as.character(Sys.time()), runtime = runtime,
               decision = if (all(checks)) "PASS" else "FAIL", checks = as.list(checks),
               runtime_rows = nrow(runtime_rows))
qdesn_ssv2_write_json(result, output)
cat(sprintf("confirmation_verification decision=%s checks=%d\n", result$decision, length(checks)))
if (!all(checks)) stop(sprintf("Confirmation verification failed: %s", paste(names(checks)[!checks], collapse = ", ")))

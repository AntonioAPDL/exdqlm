#!/usr/bin/env Rscript

suppressPackageStartupMessages(if (!requireNamespace("jsonlite", quietly = TRUE))
  stop("jsonlite is required."))
args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (!length(i) || i[[1L]] >= length(args)) return(default)
  args[[i[[1L]] + 1L]]
}
repo_root <- normalizePath(get_arg("--repo-root", system(
  "git rev-parse --show-toplevel", intern = TRUE
)), winslash = "/", mustWork = TRUE)
setwd(repo_root)
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "independent_exal_m0_structural_screen_v2.R"))
materialization_root <- normalizePath(get_arg("--materialization-root"),
                                      winslash = "/", mustWork = TRUE)
run_tag <- as.character(get_arg("--run-tag", ""))
output <- normalizePath(get_arg("--output"), winslash = "/", mustWork = FALSE)
plan_path <- file.path(materialization_root, "targeted_confirmation_plan.csv")
plan <- qdesn_ssv2_read_csv(plan_path)
registry <- qdesn_ssv2_read_csv(file.path(materialization_root,
                                          "canonical_source_registry.csv"))
manifest <- qdesn_ssv2_read_json(file.path(materialization_root,
                                           "targeted_confirmation_manifest.json"))
expected_source_sha256 <- c(
  laplace_t0p05 = "5ca362d76dda664c1433efc005bf8e3c559026d45c701cb45852620ebd11ab9d",
  normal_t0p25 = "50091eee6f9df1720e72dd720329269452acb75fb33fa2de8ecae995c1e57fac"
)

config_checks <- lapply(seq_len(nrow(plan)), function(i) {
  job <- qdesn_ssv2_read_json(plan$config_path[[i]])
  staged_series <- tryCatch(
    qdesn_ssv2_read_csv(job$root_spec$source_series_wide_path),
    error = function(e) data.frame()
  )
  staged_selection <- tryCatch(
    qdesn_ssv2_read_csv(job$root_spec$source_selection_indices_path),
    error = function(e) data.frame()
  )
  c(
    config_hash = identical(qdesn_ssv2_sha256(plan$config_path[[i]]),
                            plan$config_sha256[[i]]),
    stage = identical(job$stage, "confirmation"),
    budget = identical(as.integer(job$config$inference$mcmc$n_burn), 5000L) &&
      identical(as.integer(job$config$inference$mcmc$n_mcmc), 20000L) &&
      identical(as.integer(job$config$inference$mcmc$thin), 1L),
    method = identical(job$config$inference$mcmc$slice$core_update_mode,
                       qdesn_ssv2_method_id),
    source = identical(job$source_id, "canonical_article") &&
      identical(job$source_role, "canonical_confirmation"),
    registry = identical(job$source_registry_hash_value, qdesn_ssv2_registry_hash) &&
      identical(qdesn_ssv2_sha256(job$source_registry_path), job$source_registry_sha256),
    observed = file.exists(job$observed_path) &&
      identical(qdesn_ssv2_sha256(job$observed_path), job$observed_sha256),
    windows = identical(as.integer(job$root_spec$train_start_source_index), 8501L) &&
      identical(as.integer(job$root_spec$train_end_source_index), 9000L) &&
      identical(as.integer(job$root_spec$forecast_start_source_index), 9001L) &&
      identical(as.integer(job$root_spec$forecast_end_source_index), 10000L),
    rolling = identical(as.integer(job$config$metrics$rolling_origin$max_lead_configured), 30L) &&
      identical(as.integer(job$config$metrics$rolling_origin$origin_stride), 30L) &&
      !isTRUE(job$config$metrics$rolling_origin$refit_per_origin) &&
      isTRUE(job$config$metrics$rolling_origin$require_lead_export),
    source_mapping = nrow(staged_series) == nrow(staged_selection) &&
      all(c("t", "source_index") %in% names(staged_series)) &&
      all(c("t", "source_index") %in% names(staged_selection)) &&
      identical(as.integer(staged_series$t), as.integer(staged_selection$t)) &&
      identical(as.integer(staged_series$source_index),
                as.integer(staged_selection$source_index)) &&
      min(as.integer(staged_series$source_index)) ==
        as.integer(job$root_spec$raw_start_source_index) &&
      max(as.integer(staged_series$source_index)) == 10000L,
    storage = !isTRUE(job$config$outputs$keep_draws) &&
      !isTRUE(job$config$outputs$keep_mcmc_vb_init) &&
      !isTRUE(job$config$outputs$save_forecast_objects) &&
      !isTRUE(job$config$outputs$retain_full_rds_on_failure),
    no_home = !grepl("/home/jaguir26/local/src", paste(unlist(job), collapse = " "),
                     fixed = TRUE)
  )
})
config_matrix <- do.call(rbind, config_checks)
checks <- c(
  package_version = identical(as.character(read.dcf(file.path(repo_root, "DESCRIPTION"))[
    1L, "Version"]), "1.0.0"),
  plan_count = nrow(plan) == 6L,
  two_cells = identical(sort(unique(plan$target_cell_id)),
                        sort(c("laplace_t0p05", "normal_t0p25"))),
  three_chains = all(table(plan$target_cell_id) == 3L) &&
    all(sort(unique(plan$chain_id)) == 1:3),
  expected_budgets = all(plan$expected_n_burn == 5000L) &&
    all(plan$expected_n_mcmc == 20000L),
  unique_jobs = !anyDuplicated(plan$job_id),
  unique_seeds = length(unique(vapply(plan$config_path, function(path) {
    qdesn_ssv2_read_json(path)$config$inference$mcmc$control$seed
  }, integer(1L)))) == 6L,
  source_rows = nrow(registry) == 2L && all(registry$source_id == "canonical_article") &&
    all(registry$series_wide_sha256 ==
      unname(expected_source_sha256[match(registry$family,
        c(laplace_t0p05 = "laplace", normal_t0p25 = "normal"))])),
  materialization_storage = !length(list.files(
    materialization_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
    full.names = TRUE, ignore.case = TRUE
  )),
  manifest = identical(as.integer(manifest$jobs), 6L) &&
    identical(manifest$source_registry_hash_value, qdesn_ssv2_registry_hash),
  config_contracts = all(config_matrix)
)

runtime <- NULL
if (nzchar(run_tag)) {
  runtime <- do.call(rbind, lapply(seq_len(nrow(plan)), function(i) {
    root <- qdesn_ssv2_job_root(repo_root, run_tag, plan$job_id[[i]])
    status_path <- file.path(root, "job_status.json")
    status <- if (file.exists(status_path)) qdesn_ssv2_read_json(status_path) else
      list(status = "MISSING")
    rolling_audit <- qdesn_ssv2_rolling_artifact_audit(root)
    requires_rolling <- grepl("^forecast_", as.character(plan$objective_metric[[i]]))
    data.frame(
      job_id = plan$job_id[[i]], status = as.character(status$status %||% "MISSING"),
      objective_value = qdesn_ssv2_metric_value(
        root, plan$objective_metric[[i]], require_rolling = requires_rolling
      ),
      objective_source = as.character(status$objective_source %||% NA_character_),
      rolling_artifact_status = rolling_audit$decision,
      rolling_artifact_failed_checks = paste(
        names(rolling_audit$checks)[!rolling_audit$checks], collapse = ";"
      ),
      rolling_path_sha256 = if (file.exists(rolling_audit$rolling_path)) {
        qdesn_ssv2_sha256(rolling_audit$rolling_path)
      } else NA_character_,
      lead_metrics_sha256 = if (file.exists(rolling_audit$lead_path)) {
        qdesn_ssv2_sha256(rolling_audit$lead_path)
      } else NA_character_,
      binary_count = length(list.files(root, pattern = "[.](rds|rda|RData)$",
        recursive = TRUE, ignore.case = TRUE)),
      elapsed_seconds = as.numeric(status$elapsed_seconds %||% NA_real_),
      stringsAsFactors = FALSE
    )
  }))
  qdesn_ssv2_write_csv(runtime, sub("[.]json$", "_runtime.csv", output))
  checks <- c(checks, runtime_success = all(runtime$status == "SUCCESS"),
              runtime_finite = all(is.finite(runtime$objective_value)),
              runtime_rolling_artifacts = all(runtime$rolling_artifact_status == "PASS"),
              runtime_storage = all(runtime$binary_count == 0L))
}
decision <- if (all(checks)) "PASS" else "FAIL"
qdesn_ssv2_write_json(list(
  generated_at = as.character(Sys.time()), run_tag = if (nzchar(run_tag)) run_tag else NULL,
  checks = as.list(checks), runtime_summary = if (is.null(runtime)) NULL else list(
    expected = nrow(runtime), success = sum(runtime$status == "SUCCESS"),
    finite = sum(is.finite(runtime$objective_value)), binaries = sum(runtime$binary_count),
    rolling_artifact_pass = sum(runtime$rolling_artifact_status == "PASS"),
    median_elapsed_seconds = stats::median(runtime$elapsed_seconds, na.rm = TRUE),
    maximum_elapsed_seconds = max(runtime$elapsed_seconds, na.rm = TRUE)
  ), decision = decision
), output)
cat(sprintf("targeted_confirmation decision=%s\n", decision))
if (decision != "PASS") stop("Targeted confirmation verification failed.", call. = FALSE)

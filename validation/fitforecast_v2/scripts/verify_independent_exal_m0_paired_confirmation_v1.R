#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("jsonlite is required.", call. = FALSE)
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
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "independent_exal_m0_structural_screen_v2.R"))

materialization_root <- normalizePath(get_arg("--materialization-root"),
                                      winslash = "/", mustWork = TRUE)
plan_name <- as.character(get_arg("--plan", "confirmation_plan.csv"))[1L]
run_tag <- as.character(get_arg("--run-tag", ""))[1L]
output <- normalizePath(get_arg("--output"), winslash = "/", mustWork = FALSE)
plan_path <- normalizePath(file.path(materialization_root, plan_name),
                           winslash = "/", mustWork = TRUE)
plan <- qdesn_ssv2_read_csv(plan_path)
manifest <- qdesn_ssv2_read_json(file.path(materialization_root,
                                           "materialization_manifest.json"))
registry <- qdesn_ssv2_read_csv(file.path(materialization_root,
                                          "canonical_source_registry.csv"))
contract <- qdesn_ssv2_read_json(manifest$contract$path)
stage <- unique(plan$stage)
if (length(stage) != 1L || !stage %in% c("smoke", "confirmation")) {
  stop("The plan must contain exactly one supported stage.", call. = FALSE)
}
stage_contract <- contract[[stage]]
expected_jobs <- as.integer(stage_contract$expected_jobs)
expected_chains <- as.integer(stage_contract$chains_per_candidate)
expected_burn <- as.integer(stage_contract$n_burn)
expected_mcmc <- as.integer(stage_contract$n_mcmc)
target_ids <- sort(as.character(contract$canonical_source$targets$target_cell_id))

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
  exact_dimension <- qdesn_ssv2_effective_readout_dimension(
    job$config$desn$n, job$config$desn$n_tilde,
    job$config$readout$reservoir_lags, job$config$lags$m_y
  )
  c(
    config_hash = identical(qdesn_ssv2_sha256(plan$config_path[[i]]),
                            plan$config_sha256[[i]]),
    stage = identical(as.character(job$stage), stage),
    budget = identical(as.integer(job$config$inference$mcmc$n_burn), expected_burn) &&
      identical(as.integer(job$config$inference$mcmc$n_mcmc), expected_mcmc) &&
      identical(as.integer(job$config$inference$mcmc$thin), 1L),
    method = identical(as.character(job$config$inference$mcmc$slice$core_update_mode),
                       qdesn_ssv2_method_id),
    source = identical(as.character(job$source_id), "canonical_article") &&
      identical(as.character(job$source_role), "canonical_confirmation"),
    registry = identical(as.character(job$source_registry_hash_value),
                         qdesn_ssv2_registry_hash) &&
      identical(qdesn_ssv2_sha256(job$source_registry_path),
                as.character(job$source_registry_sha256)),
    observed = file.exists(job$observed_path) &&
      identical(qdesn_ssv2_sha256(job$observed_path),
                as.character(job$observed_sha256)),
    windows = identical(as.integer(job$root_spec$train_start_source_index), 8501L) &&
      identical(as.integer(job$root_spec$train_end_source_index), 9000L) &&
      identical(as.integer(job$root_spec$forecast_start_source_index), 9001L) &&
      identical(as.integer(job$root_spec$forecast_end_source_index), 10000L),
    rolling = identical(
      as.integer(job$config$metrics$rolling_origin$max_lead_configured), 30L
    ) && identical(
      as.integer(job$config$metrics$rolling_origin$origin_stride), 30L
    ) && !isTRUE(job$config$metrics$rolling_origin$refit_per_origin) &&
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
    readout_dimension = identical(
      as.integer(job$root_spec$effective_readout_dimension), exact_dimension
    ) && exact_dimension <= qdesn_ssv2_max_effective_readout_dimension,
    seed_contract = identical(
      as.integer(job$config$inference$mcmc$control$seed),
      as.integer(plan$mcmc_seed[[i]])
    ) && identical(
      as.integer(job$config$inference$mcmc$control$rng_seed),
      as.integer(plan$mcmc_rng_seed[[i]])
    ) && identical(
      as.integer(job$config$inference$mcmc$vb_warm_start_seed),
      as.integer(plan$vb_warm_start_seed[[i]])
    ),
    storage = !isTRUE(job$config$outputs$keep_draws) &&
      !isTRUE(job$config$outputs$keep_mcmc_vb_init) &&
      !isTRUE(job$config$outputs$save_forecast_objects) &&
      !isTRUE(job$config$outputs$retain_full_rds_on_failure),
    handoff = identical(
      qdesn_ssv2_sha256(job$study_contract$sealed_handoff_manifest_path),
      as.character(job$study_contract$sealed_handoff_manifest_sha256)
    ) && identical(
      qdesn_ssv2_sha256(job$study_contract$selection_evidence_path),
      as.character(job$study_contract$selection_evidence_sha256)
    ) && identical(
      qdesn_ssv2_sha256(job$study_contract$article_metric_baseline_path),
      as.character(job$study_contract$article_metric_baseline_sha256)
    ),
    no_home = !grepl("/home/jaguir26/local/src", paste(unlist(job), collapse = " "),
                     fixed = TRUE),
    manual_article_gate = !isTRUE(job$study_contract$article_promotion_automatic)
  )
})
config_matrix <- do.call(rbind, config_checks)

source_target <- contract$canonical_source$targets
source_hash_ok <- vapply(seq_len(nrow(registry)), function(i) {
  expected <- source_target[
    source_target$target_cell_id == registry$target_cell_id[[i]], , drop = FALSE
  ]
  nrow(expected) == 1L &&
    identical(registry$series_wide_sha256[[i]],
              as.character(expected$series_wide_sha256[[1L]])) &&
    identical(registry$sim_output_sha256[[i]],
              as.character(expected$sim_output_sha256[[1L]])) &&
    identical(qdesn_ssv2_sha256(registry$series_wide_path[[i]]),
              registry$series_wide_sha256[[i]]) &&
    identical(qdesn_ssv2_sha256(registry$sim_output_path[[i]]),
              registry$sim_output_sha256[[i]])
}, logical(1L))

same_reservoir_by_candidate <- vapply(
  split(plan$reservoir_seed, plan$candidate_id),
  function(x) length(unique(x)) == 1L,
  logical(1L)
)
checks <- c(
  package_version = identical(as.character(read.dcf(file.path(repo_root, "DESCRIPTION"))[
    1L, "Version"]), "1.0.0"),
  branch = identical(system("git branch --show-current", intern = TRUE),
                     as.character(contract$validation_branch)),
  plan_count = nrow(plan) == expected_jobs,
  target_cells = identical(sort(unique(plan$target_cell_id)), target_ids),
  chains_per_candidate = all(table(plan$target_cell_id) == expected_chains),
  unique_jobs = !anyDuplicated(plan$job_id),
  unique_mcmc_seeds = length(unique(plan$mcmc_seed)) == nrow(plan),
  unique_rng_seeds = length(unique(plan$mcmc_rng_seed)) == nrow(plan),
  unique_vb_seeds = length(unique(plan$vb_warm_start_seed)) == nrow(plan),
  fixed_reservoir_per_candidate = all(same_reservoir_by_candidate),
  expected_budgets = all(plan$n_burn == expected_burn) &&
    all(plan$n_mcmc == expected_mcmc) && all(plan$thin == 1L),
  source_rows = nrow(registry) == 2L &&
    identical(sort(registry$target_cell_id), target_ids) && all(source_hash_ok),
  materialization_manifest = identical(manifest$method_id,
                                        "M0_v_collapsed_support_logit") &&
    identical(manifest$source_registry_hash_value, qdesn_ssv2_registry_hash) &&
    identical(qdesn_ssv2_sha256(plan_path),
              as.character(manifest[[stage]]$plan_sha256)),
  materialization_storage = !length(list.files(
    materialization_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
    full.names = TRUE, ignore.case = TRUE
  )),
  config_contracts = all(config_matrix)
)

runtime <- NULL
if (nzchar(run_tag)) {
  metrics <- as.character(contract$promotion_contract$metrics)
  runtime_rows <- list()
  k <- 0L
  for (i in seq_len(nrow(plan))) {
    root <- qdesn_ssv2_job_root(repo_root, run_tag, plan$job_id[[i]])
    status_path <- file.path(root, "job_status.json")
    status <- if (file.exists(status_path)) qdesn_ssv2_read_json(status_path) else
      list(status = "MISSING")
    rolling_audit <- qdesn_ssv2_rolling_artifact_audit(root)
    for (metric in metrics) {
      k <- k + 1L
      runtime_rows[[k]] <- data.frame(
        job_id = plan$job_id[[i]], target_cell_id = plan$target_cell_id[[i]],
        candidate_id = plan$candidate_id[[i]], chain_id = plan$chain_id[[i]],
        metric = metric,
        metric_value = qdesn_ssv2_metric_value(
          root, metric, require_rolling = grepl("^forecast_", metric)
        ),
        status = as.character(status$status %||% "MISSING"),
        rolling_artifact_status = rolling_audit$decision,
        binary_count = length(list.files(
          root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
          full.names = TRUE, ignore.case = TRUE
        )),
        elapsed_seconds = as.numeric(status$elapsed_seconds %||% NA_real_),
        stringsAsFactors = FALSE
      )
    }
  }
  runtime <- do.call(rbind, runtime_rows)
  runtime_path <- sub("[.]json$", "_runtime.csv", output)
  qdesn_ssv2_write_csv(runtime, runtime_path)
  job_runtime <- runtime[!duplicated(runtime$job_id), , drop = FALSE]
  checks <- c(
    checks,
    runtime_success = all(job_runtime$status == "SUCCESS"),
    runtime_all_metrics_finite = all(is.finite(runtime$metric_value)),
    runtime_rolling_artifacts = all(job_runtime$rolling_artifact_status == "PASS"),
    runtime_storage = all(job_runtime$binary_count == 0L)
  )
}

decision <- if (all(checks)) "PASS" else "FAIL"
qdesn_ssv2_write_json(list(
  generated_at = as.character(Sys.time()), stage = stage,
  run_tag = if (nzchar(run_tag)) run_tag else NULL,
  plan = list(path = plan_path, sha256 = qdesn_ssv2_sha256(plan_path)),
  checks = as.list(checks),
  failed_checks = as.list(names(checks)[!checks]),
  runtime_summary = if (is.null(runtime)) NULL else list(
    expected_jobs = nrow(plan), success_jobs = length(unique(
      runtime$job_id[runtime$status == "SUCCESS"]
    )), metric_rows = nrow(runtime), finite_metric_rows = sum(is.finite(runtime$metric_value)),
    binary_payloads = sum(runtime$binary_count[!duplicated(runtime$job_id)]),
    median_elapsed_seconds = stats::median(
      runtime$elapsed_seconds[!duplicated(runtime$job_id)], na.rm = TRUE
    )
  ),
  decision = decision
), output)
cat(sprintf("paired_confirmation stage=%s decision=%s jobs=%d\n",
            stage, decision, nrow(plan)))
if (decision != "PASS") {
  stop(sprintf("Paired confirmation verification failed: %s",
               paste(names(checks)[!checks], collapse = ", ")), call. = FALSE)
}

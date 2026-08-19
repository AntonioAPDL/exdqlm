#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  for (pkg in c("jsonlite", "yaml")) {
    if (!requireNamespace(pkg, quietly = TRUE)) stop(sprintf("Missing package: %s", pkg))
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
                 "qdesn_forecast_gap_adaptive_mcmc_v1.R"))
materialization_root <- normalizePath(get_arg("--materialization-root"),
                                      winslash = "/", mustWork = TRUE)
stage <- get_arg("--stage", "static")
plan_arg <- get_arg("--plan")
run_tag <- get_arg("--run-tag")
output <- normalizePath(get_arg(
  "--output", file.path(materialization_root, paste0(stage, "_verification.json"))
), winslash = "/", mustWork = FALSE)

stub <- file.path(repo_root, "config", "validation", qdesn_fgav1_stage)
targets <- qdesn_ssv2_read_csv(paste0(stub, "_target_cells.csv"))
metric_roles <- qdesn_ssv2_read_csv(paste0(stub, "_metric_role_ledger.csv"))
parents <- qdesn_ssv2_ensure_effective_dimension(
  qdesn_ssv2_read_csv(paste0(stub, "_parent_controls.csv"))
)
profiles <- qdesn_ssv2_ensure_effective_dimension(
  qdesn_ssv2_read_csv(paste0(stub, "_candidate_profiles.csv"))
)
history <- qdesn_ssv2_read_csv(paste0(stub, "_history_signature_ledger.csv"))
evidence_sources <- qdesn_ssv2_read_csv(paste0(stub, "_evidence_source_manifest.csv"))
source_cfg <- yaml::read_yaml(paste0(stub, "_sources.yaml"))
manifest <- qdesn_ssv2_read_json(file.path(
  materialization_root, "materialization_manifest.json"
))

plan_paths <- c(
  smoke = file.path(materialization_root, "smoke_plan.csv"),
  calibration = file.path(materialization_root, "calibration_plan.csv"),
  discovery = file.path(materialization_root, "discovery_plan.csv")
)
plans <- lapply(plan_paths, qdesn_ssv2_read_csv)
all_configs <- unlist(lapply(plans, `[[`, "config_path"), use.names = FALSE)
jobs <- lapply(all_configs, qdesn_ssv2_read_json)
job_checks <- lapply(jobs, function(job) {
  likelihood <- as.character(job$likelihood_target)
  data.frame(
    schema = identical(as.character(job$schema_version),
                       "qdesn_forecast_gap_adaptive_mcmc_v1_job_v1"),
    registry = identical(as.character(job$source_registry_hash_value),
                         qdesn_ssv2_registry_hash),
    version = identical(as.character(job$study_contract$package_version), "1.0.0"),
    window = identical(as.integer(job$study_contract$train_window), c(8501L, 9000L)) &&
      identical(as.integer(job$study_contract$forecast_window), c(9001L, 10000L)),
    rolling = identical(as.integer(job$study_contract$max_lead), 30L) &&
      identical(as.integer(job$study_contract$origin_stride), 30L) &&
      !isTRUE(job$config$metrics$rolling_origin$refit_per_origin),
    likelihood = likelihood %in% c("al", "exal") &&
      identical(as.character(job$config$inference$likelihood_family), likelihood),
    method = likelihood != "exal" || identical(
      as.character(job$config$inference$mcmc$slice$core_update_mode),
      qdesn_ssv2_method_id
    ),
    capacity = as.integer(job$root_spec$effective_readout_dimension) <= 900L,
    one_thread = identical(as.integer(job$config$cpp$postpred_threads), 1L),
    storage = !isTRUE(job$config$outputs$keep_draws) &&
      !isTRUE(job$config$outputs$keep_mcmc_vb_init) &&
      !isTRUE(job$config$outputs$save_forecast_objects) &&
      !isTRUE(job$config$outputs$retain_full_rds_on_failure),
    no_prior_recycling = !isTRUE(job$study_contract$posterior_recycled_as_prior),
    canonical_path = !grepl("/home/jaguir26/local/src", paste(
      job$observed_path, job$source_registry_path, collapse = " "
    ), fixed = TRUE),
    stringsAsFactors = FALSE
  )
})
job_checks <- do.call(rbind, job_checks)
roles <- vapply(source_cfg$replicates, function(x) as.character(x$role), character(1L))
static_checks <- c(
  target_count = nrow(targets) == 8L && sum(targets$tier == "A") == 5L &&
    sum(targets$tier == "B") == 3L,
  metric_role_count = nrow(metric_roles) == 14L &&
    !anyDuplicated(paste(metric_roles$target_cell_id, metric_roles$metric)),
  metric_role_finite = all(is.finite(metric_roles$current_value)) &&
    all(is.finite(metric_roles$best_dqlm_exdqlm_value)) &&
    all(metric_roles$relative_gap_pct > 0),
  profile_count = nrow(profiles) == 84L && nrow(parents) == 8L,
  per_cell_profiles = identical(
    as.integer(table(factor(profiles$target_cell_id, levels = targets$target_cell_id))),
    as.integer(targets$candidates_per_cell)
  ),
  profile_unique = !anyDuplicated(paste(
    profiles$target_cell_id, profiles$profile_signature, sep = "\r"
  )),
  history_excluded = !any(profiles$profile_signature %in% history$profile_signature),
  evidence_sources = nrow(evidence_sources) > 0L &&
    all(evidence_sources$source_exists) && all(nzchar(evidence_sources$source_sha256)),
  capacity = all(profiles$effective_readout_dimension <= 900L) &&
    all(parents$effective_readout_dimension <= 900L),
  parent_frozen = all(file.exists(file.path(repo_root, targets$parent_request_path))) &&
    all(vapply(file.path(repo_root, targets$parent_request_path),
               qdesn_ssv2_sha256, character(1L)) == targets$parent_request_sha256),
  sources = length(roles) == 8L && sum(roles == "discovery") == 2L &&
    sum(roles == "replication") == 2L && sum(roles == "sealed_holdout") == 4L,
  plans = nrow(plans$smoke) == 2L && nrow(plans$calibration) == 8L &&
    nrow(plans$discovery) == 184L,
  config_unique = !anyDuplicated(all_configs) && all(file.exists(all_configs)),
  job_contracts = all(as.matrix(job_checks)),
  manifest_registry = identical(
    as.character(manifest$canonical_source_registry_hash_value),
    qdesn_ssv2_registry_hash
  ),
  branch = identical(system("git branch --show-current", intern = TRUE),
                     qdesn_fgav1_branch)
)

runtime <- NULL
if (stage != "static") {
  if (is.null(plan_arg) || is.null(run_tag)) {
    stop("--plan and --run-tag are required for runtime verification.")
  }
  plan <- qdesn_ssv2_read_csv(normalizePath(plan_arg, winslash = "/", mustWork = TRUE))
  runtime <- do.call(rbind, lapply(seq_len(nrow(plan)), function(i) {
    root <- qdesn_fgav1_job_root(repo_root, run_tag, plan$job_id[[i]])
    status_path <- file.path(root, "job_status.json")
    status <- if (file.exists(status_path)) qdesn_ssv2_read_json(status_path) else
      list(status = "MISSING", binary_payloads_remaining = NA_integer_)
    metrics <- qdesn_fgav1_metric_values(root)
    required <- strsplit(plan$target_metrics[[i]], ";", fixed = TRUE)[[1L]]
    data.frame(
      job_id = plan$job_id[[i]], status = as.character(status$status),
      required_metrics_finite = all(is.finite(metrics[required])),
      binary_count = as.integer(status$binary_payloads_remaining %||% NA_integer_),
      elapsed_seconds = as.numeric(status$elapsed_seconds %||% NA_real_),
      config_hash_match = identical(
        as.character(status$config_sha256), as.character(plan$config_sha256[[i]])
      ),
      stringsAsFactors = FALSE
    )
  }))
  runtime_path <- sub("[.]json$", "_runtime.csv", output)
  qdesn_ssv2_write_csv(runtime, runtime_path)
  static_checks <- c(
    static_checks,
    runtime_complete = nrow(runtime) == nrow(plan),
    runtime_success = all(runtime$status == "SUCCESS"),
    runtime_metrics = all(runtime$required_metrics_finite),
    runtime_storage = all(runtime$binary_count == 0L),
    runtime_config = all(runtime$config_hash_match)
  )
}

binary_materialization <- list.files(
  materialization_root, pattern = "[.](rds|rda|RData)$",
  recursive = TRUE, full.names = TRUE, ignore.case = TRUE
)
static_checks <- c(static_checks, materialization_storage = !length(binary_materialization))
result <- list(
  schema_version = "qdesn_forecast_gap_adaptive_mcmc_v1_verification_v1",
  generated_at = as.character(Sys.time()), stage = stage,
  decision = if (all(static_checks)) "PASS" else "FAIL",
  checks = as.list(static_checks), job_contract_rows = nrow(job_checks),
  runtime_rows = if (is.null(runtime)) 0L else nrow(runtime),
  forbidden_materialization_payloads = as.list(binary_materialization)
)
qdesn_ssv2_write_json(result, output)
cat(sprintf("stage=%s decision=%s checks=%d output=%s\n",
            stage, result$decision, length(static_checks), output))
if (!all(static_checks)) {
  stop(sprintf("Verification failed: %s",
               paste(names(static_checks)[!static_checks], collapse = ", ")),
       call. = FALSE)
}

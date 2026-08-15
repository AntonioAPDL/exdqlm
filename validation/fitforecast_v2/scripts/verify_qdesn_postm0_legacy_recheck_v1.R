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
                 "qdesn_postm0_legacy_recheck_v1.R"))
materialization_root <- normalizePath(get_arg("--materialization-root"),
                                      winslash = "/", mustWork = TRUE)
stage <- get_arg("--stage", "static")
plan_arg <- get_arg("--plan")
run_tag <- get_arg("--run-tag")
output <- normalizePath(get_arg(
  "--output", file.path(materialization_root, paste0(stage, "_verification.json"))
), winslash = "/", mustWork = FALSE)

stub <- file.path(repo_root, "config", "validation", qdesn_ltcv1_stage)
targets <- qdesn_ssv2_read_csv(paste0(stub, "_target_cells.csv"))
parents <- qdesn_ssv2_ensure_effective_dimension(
  qdesn_ssv2_read_csv(paste0(stub, "_parent_controls.csv"))
)
profiles <- qdesn_ssv2_ensure_effective_dimension(
  qdesn_ssv2_read_csv(paste0(stub, "_candidate_profiles.csv"))
)
history <- qdesn_ssv2_read_csv(paste0(stub, "_historical_evidence_rows.csv"))
history_signatures <- qdesn_ssv2_read_csv(
  paste0(stub, "_historical_signature_evidence.csv")
)
postm0 <- qdesn_ssv2_read_csv(paste0(stub, "_postm0_signature_coverage.csv"))
selection <- qdesn_ssv2_read_csv(paste0(stub, "_candidate_selection_audit.csv"))
source_cfg <- yaml::read_yaml(paste0(stub, "_sources.yaml"))
manifest <- qdesn_ssv2_read_json(file.path(
  materialization_root, "materialization_manifest.json"
))
tracked_manifest_path <- normalizePath(
  as.character(manifest$tracked_manifest_path), winslash = "/", mustWork = TRUE
)
tracked <- qdesn_ssv2_read_csv(tracked_manifest_path)
tracked_abs <- file.path(repo_root, tracked$relative_path)
tracked_exists <- file.exists(tracked_abs)
tracked_actual_hash <- vapply(
  tracked_abs, qdesn_ssv2_sha256, character(1L)
)
tracked_audit <- data.frame(
  relative_path = tracked$relative_path,
  expected_sha256 = tracked$sha256,
  actual_sha256 = tracked_actual_hash,
  exists = tracked_exists,
  hash_match = tracked_exists & tracked_actual_hash == tracked$sha256,
  stringsAsFactors = FALSE
)
tracked_audit_path <- sub(
  "[.]json$", "_tracked_file_hash_audit.csv", output
)
qdesn_ssv2_write_csv(tracked_audit, tracked_audit_path)
tracked_hash_ok <- all(tracked_audit$hash_match)
required_tracked <- vapply(
  qdesn_plrv1_tracked_paths(repo_root), qdesn_ssv2_rel, character(1L),
  repo_root = repo_root
)
tracked_dependency_coverage <- setequal(
  tracked$relative_path, required_tracked
)

head_commit <- system("git rev-parse HEAD", intern = TRUE)
recovery_required <- !identical(
  as.character(manifest$git_commit), head_commit
)
recovery_provenance <- !recovery_required
replication_evidence_frozen <- !recovery_required
if (recovery_required && !is.null(manifest$recovery)) {
  recovery_path <- tryCatch(
    normalizePath(
      as.character(manifest$recovery$recovery_manifest_path),
      winslash = "/", mustWork = TRUE
    ), error = function(e) NA_character_
  )
  recovery_hash_ok <- !is.na(recovery_path) && identical(
    qdesn_ssv2_sha256(recovery_path),
    as.character(manifest$recovery$recovery_manifest_sha256)
  )
  recovery <- if (recovery_hash_ok) {
    qdesn_ssv2_read_json(recovery_path)
  } else {
    NULL
  }
  is_ancestor <- function(commit) {
    commit <- as.character(commit %||% "")
    nzchar(commit) && system2(
      "git", c("merge-base", "--is-ancestor", commit, head_commit),
      stdout = FALSE, stderr = FALSE
    ) == 0L
  }
  recovery_provenance <- !is.null(recovery) &&
    identical(as.character(recovery$status), "COMPLETE") &&
    identical(as.character(recovery$original_git_commit),
              as.character(manifest$git_commit)) &&
    identical(as.character(recovery$current_tracked_manifest_sha256),
              qdesn_ssv2_sha256(tracked_manifest_path)) &&
    identical(as.character(manifest$recovery$status), "COMPLETE") &&
    !isTRUE(recovery$model_outputs_recomputed) &&
    !isTRUE(manifest$recovery$model_outputs_recomputed) &&
    is_ancestor(recovery$execution_recovery_commit) &&
    is_ancestor(recovery$closeout_recovery_commit)
  replication_evidence_frozen <- !is.null(recovery) && all(c(
    as.integer(recovery$replication_jobs) == 20L,
    as.integer(recovery$replication_successes) == 20L,
    as.integer(recovery$replication_binary_payloads) == 0L,
    identical(
      qdesn_ssv2_sha256(recovery$replication_plan_path),
      as.character(recovery$replication_plan_sha256)
    ),
    identical(
      qdesn_ssv2_sha256(recovery$replication_job_manifest_path),
      as.character(recovery$replication_job_manifest_sha256)
    ),
    identical(
      qdesn_ssv2_sha256(recovery$replication_retained_file_manifest_path),
      as.character(recovery$replication_retained_file_manifest_sha256)
    )
  ))
}
other_seed_files <- list.files(
  file.path(repo_root, "config", "validation"),
  pattern = "_source_seed_contract[.]csv$", full.names = TRUE
)
other_seed_files <- setdiff(
  normalizePath(other_seed_files, winslash = "/", mustWork = TRUE),
  normalizePath(paste0(stub, "_source_seed_contract.csv"),
                winslash = "/", mustWork = TRUE)
)
prior_seeds <- unique(unlist(lapply(other_seed_files, function(path) {
  x <- tryCatch(qdesn_ssv2_read_csv(path), error = function(e) NULL)
  if (is.null(x)) return(numeric())
  fields <- intersect(c("latent_seed", "noise_seed"), names(x))
  suppressWarnings(as.numeric(unlist(x[, fields, drop = FALSE],
                                     use.names = FALSE)))
}), use.names = FALSE))
current_seed_contract <- qdesn_ssv2_read_csv(
  paste0(stub, "_source_seed_contract.csv")
)
current_seeds <- c(current_seed_contract$latent_seed,
                   current_seed_contract$noise_seed)

plan_paths <- c(
  smoke = file.path(materialization_root, "smoke_plan.csv"),
  calibration = file.path(materialization_root, "calibration_plan.csv"),
  tier_a_discovery = file.path(materialization_root, "tier_a_discovery_plan.csv")
)
plans <- lapply(plan_paths, qdesn_ssv2_read_csv)
all_configs <- unlist(lapply(plans, `[[`, "config_path"), use.names = FALSE)
jobs <- lapply(all_configs, qdesn_ssv2_read_json)
job_checks <- lapply(jobs, function(job) {
  likelihood <- as.character(job$likelihood_target)
  data.frame(
    schema = identical(as.character(job$schema_version),
                       "qdesn_postm0_legacy_recheck_v1_job_v1"),
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
    pre_m0_not_a_veto = !isTRUE(job$study_contract$pre_m0_negative_evidence_veto),
    exact_m0_required = isTRUE(job$study_contract$exact_M0_required),
    canonical_path = !grepl("/home/jaguir26/local/src", paste(
      job$observed_path, job$source_registry_path, collapse = " "
    ), fixed = TRUE),
    stringsAsFactors = FALSE
  )
})
job_checks <- do.call(rbind, job_checks)
roles <- vapply(source_cfg$replicates, function(x) as.character(x$role), character(1L))
static_checks <- c(
  target_count = nrow(targets) == 5L && all(targets$tier == "A") &&
    all(targets$likelihood_target == "exal"),
  profile_count = nrow(profiles) == 40L && nrow(parents) == 5L,
  per_cell_profiles = all(table(profiles$target_cell_id) == 8L),
  profile_unique = !anyDuplicated(paste(
    profiles$target_cell_id, profiles$profile_signature, sep = "\r"
  )),
  history_reused = all(profiles$profile_signature %in% history$profile_signature),
  postm0_excluded = !any(profiles$profile_signature %in% postm0$profile_signature),
  history_contract = nrow(history) == 9268L && nrow(history_signatures) == 2398L,
  evidence_typed = all(profiles$historical_evidence_class %in% c(
    "pre_m0_vb_all_primary_win",
    "pre_m0_mcmc_sampler_confounded_ranked"
  )),
  per_cell_selection = nrow(selection) == 5L &&
    all(selection$candidates_selected == 8L),
  capacity = all(profiles$effective_readout_dimension <= 900L) &&
    all(parents$effective_readout_dimension <= 900L),
  parent_frozen = all(file.exists(file.path(repo_root, targets$parent_request_path))) &&
    all(vapply(file.path(repo_root, targets$parent_request_path),
               qdesn_ssv2_sha256, character(1L)) == targets$parent_request_sha256),
  parent_metrics_frozen = all(file.exists(file.path(
    repo_root, targets$parent_metric_path
  ))) && all(vapply(file.path(repo_root, targets$parent_metric_path),
                    qdesn_ssv2_sha256, character(1L)) ==
             targets$parent_metric_sha256),
  sources = length(roles) == 7L && sum(roles == "discovery") == 2L &&
    sum(roles == "replication") == 1L && sum(roles == "sealed_holdout") == 4L,
  plans = nrow(plans$smoke) == 2L && nrow(plans$calibration) == 5L &&
    nrow(plans$tier_a_discovery) == 90L,
  config_unique = !anyDuplicated(all_configs) && all(file.exists(all_configs)),
  job_contracts = all(as.matrix(job_checks)),
  manifest_registry = identical(
    as.character(manifest$canonical_source_registry_hash_value),
    qdesn_ssv2_registry_hash
  ),
  tracked_manifest_hash = identical(
    qdesn_ssv2_sha256(tracked_manifest_path),
    as.character(manifest$tracked_manifest_sha256)
  ),
  tracked_file_hashes = tracked_hash_ok,
  tracked_dependency_coverage = tracked_dependency_coverage,
  recovery_provenance = recovery_provenance,
  replication_evidence_frozen = replication_evidence_frozen,
  source_seed_nonoverlap = !length(intersect(current_seeds, prior_seeds)),
  branch = identical(system("git branch --show-current", intern = TRUE),
                     qdesn_plrv1_branch)
)

runtime <- NULL
if (stage != "static") {
  if (is.null(plan_arg) || is.null(run_tag)) {
    stop("--plan and --run-tag are required for runtime verification.")
  }
  plan <- qdesn_ssv2_read_csv(normalizePath(plan_arg, winslash = "/", mustWork = TRUE))
  runtime <- do.call(rbind, lapply(seq_len(nrow(plan)), function(i) {
    root <- qdesn_plrv1_job_root(repo_root, run_tag, plan$job_id[[i]])
    status_path <- file.path(root, "job_status.json")
    status <- if (file.exists(status_path)) qdesn_ssv2_read_json(status_path) else
      list(status = "MISSING", binary_payloads_remaining = NA_integer_)
    metrics <- qdesn_ltcv1_metric_values(root)
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
  schema_version = "qdesn_postm0_legacy_recheck_v1_verification_v1",
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

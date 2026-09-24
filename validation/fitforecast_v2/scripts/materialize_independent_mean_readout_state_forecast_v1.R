#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/materialize_independent_mean_readout_state_forecast_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/",
                           mustWork = TRUE)
setwd(repo_root)
run_id <- as.character(args$`run-id` %||% paste0(
  "independent_mean_readout_state_forecast_v1_",
  format(Sys.time(), "%Y%m%d_%H%M%S")
))[[1L]]
state_root <- normalizePath(
  args$`state-root` %||% file.path(
    repo_root, "reports", "shared_fitforecast_v2_orchestration", run_id
  ),
  winslash = "/", mustWork = FALSE
)
if (dir.exists(state_root) && length(list.files(state_root, all.files = TRUE,
                                                no.. = TRUE))) {
  stop("Refusing to overwrite a nonempty campaign root: ", state_root, call. = FALSE)
}

old_state <- normalizePath(args$`old-state-root` %||%
  "/data/jaguir26/local/src/exdqlm__wt__independent_metric_intervals_v1_1p0p0/reports/shared_fitforecast_v2_orchestration/independent_metric_intervals_v1_production_20260823_225856",
  winslash = "/", mustWork = TRUE)
idolp_worktree <- normalizePath(args$`idolp-worktree` %||%
  "/data/jaguir26/local/src/exdqlm__wt__independent_dynamic_location_capacity_tau0_v1_1p0p0",
  winslash = "/", mustWork = TRUE)
defaults_path <- file.path(
  repo_root, "config", "validation", "independent_mean_readout_state_forecast_v1",
  "campaign_defaults.yaml"
)
defaults <- yaml::read_yaml(defaults_path)
if (as.integer(defaults$campaign_workers) != imrs_v1_workers ||
    as.integer(defaults$threads_per_worker) != imrs_v1_threads_per_worker) {
  stop("Tracked worker defaults do not match the campaign contract.", call. = FALSE)
}
compatibility_defaults <- defaults$historical_authority_compatibility
compatibility_policy <- imrs_v1_historical_compatibility_policy(
  compatibility_defaults
)
imi_authority_commit <- as.character(
  compatibility_defaults$imi_source_git_commit
)[[1L]]
idolp_authority_commit <- as.character(
  compatibility_defaults$idolp_source_git_commit
)[[1L]]
if (any(!grepl("^[0-9a-f]{40}$", c(
  imi_authority_commit, idolp_authority_commit
)))) {
  stop("Historical-authority source commits must be full Git hashes.",
       call. = FALSE)
}

git_description_version <- function(commit) {
  lines <- system2(
    "git", c("show", paste0(commit, ":DESCRIPTION")),
    stdout = TRUE, stderr = TRUE
  )
  if (!is.null(attr(lines, "status")) && attr(lines, "status") != 0L) {
    stop("Could not read DESCRIPTION at authority commit: ", commit,
         call. = FALSE)
  }
  version <- sub("^Version:[[:space:]]*", "", grep(
    "^Version:", lines, value = TRUE
  ))
  if (length(version) != 1L) {
    stop("Authority commit does not expose one package version: ", commit,
         call. = FALSE)
  }
  version[[1L]]
}
authority_versions <- vapply(
  c(imi = imi_authority_commit, idolp = idolp_authority_commit),
  git_description_version, character(1L)
)
if (any(authority_versions != compatibility_policy$source_package_version)) {
  stop("Historical-authority commits do not match the declared package version.",
       call. = FALSE)
}
execution_package_version <- as.character(
  read.dcf(file.path(repo_root, "DESCRIPTION"), fields = "Version")[[1L]]
)

dirs <- file.path(state_root, c(
  "configs/fit", "configs/forecast", "sources", "source_requests", "runtime/fit_jobs",
  "runtime/forecast_jobs", "capsules/basis", "capsules/posterior", "status/fit",
  "status/forecast", "logs/fit", "logs/forecast", "manifests", "health", "closeout",
  "native_authority"
))
invisible(lapply(dirs, dir.create, recursive = TRUE, showWarnings = FALSE))

copy_verified <- function(source, destination, expected = NULL) {
  source <- normalizePath(source, winslash = "/", mustWork = TRUE)
  observed <- ffv2_file_sha256(source)
  if (!is.null(expected) && nzchar(as.character(expected)) &&
      !identical(observed, as.character(expected))) {
    stop("Frozen input hash mismatch: ", source, call. = FALSE)
  }
  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  if (!file.exists(destination) && !file.copy(source, destination, copy.mode = TRUE)) {
    stop("Could not stage frozen input: ", source, call. = FALSE)
  }
  if (!identical(ffv2_file_sha256(destination), observed)) {
    stop("Staged input hash mismatch: ", destination, call. = FALSE)
  }
  normalizePath(destination, winslash = "/", mustWork = TRUE)
}

stage_source_pair <- local({
  cache <- new.env(parent = emptyenv())
  function(series_path, series_sha, observed_path, observed_sha) {
    key <- paste(series_sha, observed_sha, sep = "__")
    if (exists(key, envir = cache, inherits = FALSE)) {
      return(get(key, envir = cache, inherits = FALSE))
    }
    root <- file.path(state_root, "sources", substr(series_sha, 1L, 16L))
    series <- copy_verified(series_path, file.path(root, "series_wide.csv"), series_sha)
    observed <- copy_verified(observed_path, file.path(root, "observed.csv"), observed_sha)
    series_data <- readr::read_csv(series, show_col_types = FALSE)
    observed_data <- readr::read_csv(observed, show_col_types = FALSE)
    source_index_name <- intersect(c("source_index", "t"), names(series_data))
    if (!length(source_index_name) || !"y" %in% names(series_data) ||
        !"y" %in% names(observed_data) || nrow(series_data) != nrow(observed_data) ||
        !isTRUE(all.equal(as.numeric(series_data$y), as.numeric(observed_data$y),
                          tolerance = 1e-12, check.attributes = FALSE))) {
      stop("Staged source and observed data do not define one aligned coordinate map.",
           call. = FALSE)
    }
    source_index <- as.integer(series_data[[source_index_name[[1L]]]])
    if (anyNA(source_index) || anyDuplicated(source_index) ||
        any(diff(source_index) <= 0)) {
      stop("Staged source coordinates must be finite, unique, and increasing.",
           call. = FALSE)
    }
    out <- list(
      series_path = series, series_sha256 = ffv2_file_sha256(series),
      observed_path = observed, observed_sha256 = ffv2_file_sha256(observed),
      source_index = source_index
    )
    assign(key, out, envir = cache)
    out
  }
})

stage_request <- function(path, expected = NULL) {
  hash <- ffv2_file_sha256(path)
  if (!is.null(expected) && nzchar(as.character(expected)) &&
      !identical(hash, as.character(expected))) {
    stop("Frozen request hash mismatch: ", path, call. = FALSE)
  }
  copy_verified(
    path, file.path(state_root, "source_requests", paste0(hash, ".json")), hash
  )
}

stage_native_authority <- function(path, expected, authority_id,
                                   source_git_commit) {
  destination <- file.path(
    state_root, "native_authority", paste0(authority_id, "_metric_draws.csv.gz")
  )
  staged <- copy_verified(path, destination, expected)
  list(
    path = staged, sha256 = ffv2_file_sha256(staged),
    source_git_commit = as.character(source_git_commit),
    source_package_version = compatibility_policy$source_package_version
  )
}

configure_job <- function(job, source_id, chain_id, staged, request_path,
                          request_sha, family, tau, inference, likelihood,
                          source_kind, native_authority) {
  job_id <- sprintf("fit__%s__c%02d", source_id, as.integer(chain_id))
  job$schema_version <- imrs_v1_schema
  job$run_id <- run_id
  job$job_id <- job_id
  job$source_id <- source_id
  job$replay_id <- source_id
  job$chain_id <- as.integer(chain_id)
  job$family <- as.character(family)
  job$tau <- as.numeric(tau)
  job$inference <- as.character(inference)
  job$likelihood_family <- as.character(likelihood)
  job$source_kind <- source_kind
  job$execution_package_version <- execution_package_version
  job$source_request_path <- request_path
  job$source_request_sha256 <- request_sha
  job$observed_path <- staged$observed_path
  job$observed_sha256 <- staged$observed_sha256
  job$source_series_path <- staged$series_path
  job$source_series_sha256 <- staged$series_sha256
  job$native_authority <- list(
    metric_draws_path = native_authority$path,
    metric_draws_sha256 = native_authority$sha256,
    source_git_commit = native_authority$source_git_commit,
    source_package_version = native_authority$source_package_version,
    exact_summary_tolerance = compatibility_policy$exact_summary_tolerance,
    compatibility_policy = compatibility_policy
  )
  job$job_root <- file.path(state_root, "runtime", "fit_jobs", job_id)
  job$root_spec$root_id <- job_id
  job$root_spec$source_family <- as.character(family)
  job$root_spec$tau <- as.numeric(tau)
  job$root_spec$likelihood_family <- as.character(likelihood)
  job$root_spec$source_series_wide_path <- staged$series_path
  job$root_spec$source_series_wide_sha256 <- staged$series_sha256
  job$config$inference$method <- as.character(inference)
  job$config$inference$likelihood_family <- as.character(likelihood)
  job$config$outputs$save <- TRUE
  job$config$outputs$keep_draws <- FALSE
  job$config$outputs$save_forecast_objects <- FALSE
  job$config$outputs$save_mean_readout_state_capsule <- TRUE
  job$config$outputs$mean_readout_state_source_index <- staged$source_index
  job$config$outputs$save_compact_fit_paths <- TRUE
  job$config$outputs$retain_full_rds_on_failure <- FALSE
  job$config$outputs$retention_profile <-
    "storage_light_independent_mean_readout_state_forecast_v1"
  interval <- job$config$metrics$posterior_metric_intervals %||% list()
  interval$enabled <- TRUE
  interval$required <- TRUE
  interval$chain_id <- as.integer(chain_id)
  for (field in c(
    "coupling_sensitivity", "dispersion_diagnostic",
    "origin_horizon_attribution", "common_shift_intervention"
  )) {
    interval[[field]] <- interval[[field]] %||% list()
    interval[[field]]$enabled <- FALSE
    interval[[field]]$required <- FALSE
  }
  job$config$metrics$posterior_metric_intervals <- interval
  job$config$diagnostics$plots <- FALSE
  job$config$diagnostics$fan_charts <- FALSE
  job$config$diagnostics$lead_eval <- FALSE
  # The experiment consumes the rolling-origin lattice and compact artifacts.
  # `origin` mode would additionally run a separate 1,000-origin lead-one pass
  # after that identical lattice, adding hours without entering any campaign
  # score. Mixture mode retains the required lattice and skips that dead work.
  job$config$forecast$mode <- "mixture"
  job$config$cpp$postpred_threads <- 1L
  job$config$cpp$use_postpred <- FALSE
  job$config$cpp$postpred_omp <- FALSE
  job$config$cpp$postpred_precompute <- FALSE
  job$forecast_seed <- as.integer(job$config$synthesis$seed) +
    as.integer(round(1000 * as.numeric(tau)))
  job$study_contract$forecast_estimator_experiment <- imrs_v1_estimator
  job$study_contract$winner_specification_frozen <- TRUE
  job$study_contract$posterior_refit_only_for_capsule_reconstruction <- TRUE
  job$study_contract$native_authority_reuse <- list(
    enabled = TRUE,
    source = "same_fit_reconstruction_metric_and_path_artifacts",
    duplicate_native_recursion = FALSE,
    reconstruction_forecast_mode = "mixture",
    excluded_unused_forecast = "separate_1000_origin_lead_one_pass",
    artifact_consistency_tolerance = imrs_v1_tolerance,
    historical_gate = compatibility_policy$schema_version,
    historical_gate_scope = "stochastic_distribution_compatibility",
    same_run_candidate_gate_scope = "exact_paired_native_artifact"
  )
  job
}

old_plan_path <- file.path(old_state, "manifests", "job_plan.csv")
old_manifest_path <- file.path(old_state, "manifests", "materialization_manifest.json")
if (!identical(ffv2_file_sha256(old_plan_path), defaults$old_imi_job_plan_sha256) ||
    !identical(ffv2_file_sha256(old_manifest_path),
               defaults$old_imi_materialization_sha256)) {
  stop("The frozen IMI authority no longer matches the tracked hashes.", call. = FALSE)
}
old_materialization <- ffv2_read_json(old_manifest_path)
if (!identical(as.character(old_materialization$git_commit),
               imi_authority_commit)) {
  stop("The frozen IMI authority commit differs from the tracked policy.",
       call. = FALSE)
}
old_plan <- ffv2_read_csv(old_plan_path)
required_imi <- c(imrs_v1_vb_sources, imrs_v1_mcmc_sources)
selected <- old_plan[
  old_plan$engine == "qdesn" & old_plan$replay_id %in% required_imi,
  , drop = FALSE
]
if (nrow(selected) != 93L || length(unique(selected$replay_id)) != 43L) {
  stop("Frozen IMI selection is not 93 jobs across 43 sources.", call. = FALSE)
}

fit_jobs <- list()
fit_i <- 0L
for (i in seq_len(nrow(selected))) {
  row <- selected[i, , drop = FALSE]
  if (!identical(ffv2_file_sha256(row$config_path), row$config_sha256)) {
    stop("Historical job config hash mismatch: ", row$config_path, call. = FALSE)
  }
  old_job <- ffv2_read_json(row$config_path)
  staged <- stage_source_pair(
    old_job$source_series_path, old_job$source_series_sha256,
    old_job$observed_path, old_job$observed_sha256
  )
  request_path <- stage_request(
    old_job$source_request_path, old_job$source_request_sha256
  )
  old_status_path <- file.path(old_state, "status", paste0(row$job_id, ".json"))
  old_status <- ffv2_read_json(old_status_path)
  if (!identical(as.character(old_status$status), "SUCCESS")) {
    stop("Historical native authority is not successful: ", row$job_id,
         call. = FALSE)
  }
  native_authority <- stage_native_authority(
    old_status$metric_draws_path, old_status$metric_draws_sha256,
    paste0(row$replay_id, "__c", sprintf("%02d", as.integer(row$chain_id))),
    imi_authority_commit
  )
  job <- configure_job(
    old_job, row$replay_id, row$chain_id, staged, request_path,
    old_job$source_request_sha256, row$family, row$tau, row$inference,
    if (grepl("_exal_", row$model_variant, fixed = TRUE)) "exal" else "al",
    "frozen_imi_v1", native_authority
  )
  config_path <- file.path(state_root, "configs", "fit", paste0(job$job_id, ".json"))
  imrs_v1_atomic_write_json(job, config_path)
  fit_i <- fit_i + 1L
  fit_jobs[[fit_i]] <- data.frame(
    job_id = job$job_id, source_id = job$source_id,
    source_kind = job$source_kind, inference = job$inference,
    likelihood_family = job$likelihood_family, family = job$family,
    tau = job$tau, chain_id = job$chain_id,
    forecast_seed = job$forecast_seed,
    expected_draws = as.integer(job$config$sampling$nd_draws),
    native_authority_sha256 = job$native_authority$metric_draws_sha256,
    native_authority_git_commit = job$native_authority$source_git_commit,
    native_authority_package_version =
      job$native_authority$source_package_version,
    native_authority_policy = compatibility_policy$schema_version,
    execution_package_version = job$execution_package_version,
    config_path = normalizePath(config_path, winslash = "/", mustWork = TRUE),
    config_sha256 = ffv2_file_sha256(config_path),
    job_root = job$job_root, status = "PLANNED", stringsAsFactors = FALSE
  )
}

idolp_request_dir <- file.path(
  repo_root, "validation", "fitforecast_v2", "audits",
  "independent_location_orthogonalized_tau0_v2_20260827", "requests"
)
idolp_files <- file.path(
  idolp_request_dir, sprintf("interval_replay_chain_%02d.json", 1:3)
)
idolp_audit_root <- dirname(idolp_request_dir)
idolp_manifest <- ffv2_read_csv(file.path(idolp_audit_root, "artifact_manifest.csv"))
idolp_audit <- ffv2_read_json(file.path(idolp_audit_root, "audit_manifest.json"))
if (!grepl(
  substr(idolp_authority_commit, 1L, 7L),
  as.character(idolp_audit$interval_replay_run_tag), fixed = TRUE
)) {
  stop("The orthogonalized authority commit differs from the tracked policy.",
       call. = FALSE)
}
for (i in seq_along(idolp_files)) {
  request <- ffv2_read_json(idolp_files[[i]])
  request_sha <- ffv2_file_sha256(idolp_files[[i]])
  series_path <- file.path(idolp_worktree, request$root_spec$source_series_wide_path)
  observed_path <- file.path(idolp_worktree, request$observed_path)
  staged <- stage_source_pair(
    series_path, request$root_spec$source_series_wide_sha256,
    observed_path, request$observed_sha256
  )
  staged_request <- stage_request(idolp_files[[i]], request_sha)
  authority_relative <- sprintf(
    "metric_draws/interval_replay_chain_%02d_metric_draws.csv.gz", i
  )
  authority_row <- idolp_manifest[
    idolp_manifest$relative_path == authority_relative, , drop = FALSE
  ]
  if (nrow(authority_row) != 1L) {
    stop("Missing tracked orthogonalized native authority: ", authority_relative,
         call. = FALSE)
  }
  native_authority <- stage_native_authority(
    file.path(idolp_audit_root, authority_relative), authority_row$sha256[[1L]],
    paste0(imrs_v1_idolp_source, "__c", sprintf("%02d", i)),
    idolp_authority_commit
  )
  request$source_identity <- paste(
    "mcmc", "qdesn_al_rhs_ns", "normal", "0.05", imrs_v1_idolp_source,
    sep = "|"
  )
  request$model_variant <- "qdesn_al_rhs_ns"
  request$source_candidate_id <- request$candidate_id
  request$source_run_tag <- "independent_location_orthogonalized_tau0_v2_interval_replay"
  job <- configure_job(
    request, imrs_v1_idolp_source, request$chain_id, staged,
    staged_request, request_sha, "normal", 0.05, "mcmc", "al",
    "frozen_idolp_v2_basis_specific", native_authority
  )
  config_path <- file.path(state_root, "configs", "fit", paste0(job$job_id, ".json"))
  imrs_v1_atomic_write_json(job, config_path)
  fit_i <- fit_i + 1L
  fit_jobs[[fit_i]] <- data.frame(
    job_id = job$job_id, source_id = job$source_id,
    source_kind = job$source_kind, inference = job$inference,
    likelihood_family = job$likelihood_family, family = job$family,
    tau = job$tau, chain_id = job$chain_id,
    forecast_seed = job$forecast_seed,
    expected_draws = as.integer(job$config$sampling$nd_draws),
    native_authority_sha256 = job$native_authority$metric_draws_sha256,
    native_authority_git_commit = job$native_authority$source_git_commit,
    native_authority_package_version =
      job$native_authority$source_package_version,
    native_authority_policy = compatibility_policy$schema_version,
    execution_package_version = job$execution_package_version,
    config_path = normalizePath(config_path, winslash = "/", mustWork = TRUE),
    config_sha256 = ffv2_file_sha256(config_path),
    job_root = job$job_root, status = "PLANNED", stringsAsFactors = FALSE
  )
}
fit_plan <- do.call(rbind, fit_jobs)
fit_plan <- fit_plan[order(fit_plan$inference != "mcmc", fit_plan$source_id,
                           fit_plan$chain_id), , drop = FALSE]
rownames(fit_plan) <- NULL
if (nrow(fit_plan) != 96L || anyDuplicated(fit_plan$job_id)) {
  stop("Materialized fit plan is not the required 96 unique jobs.", call. = FALSE)
}
canary_sources <- as.character(unlist(defaults$canary_source_ids, use.names = FALSE))
if (!setequal(canary_sources, c(
  "imi_v1_source_007", "imi_v1_source_010", "imi_v1_source_044",
  "imi_v1_source_084", imrs_v1_idolp_source
))) {
  stop("Tracked canary source set changed unexpectedly.", call. = FALSE)
}
fit_plan$is_canary <- fit_plan$source_id %in% canary_sources

forecast_rows <- list()
forecast_i <- 0L
for (source_id in c(imrs_v1_vb_sources, imrs_v1_mcmc_sources)) {
  block <- fit_plan[fit_plan$source_id == source_id, , drop = FALSE]
  forecast_i <- forecast_i + 1L
  forecast_rows[[forecast_i]] <- data.frame(
    forecast_id = paste0("forecast__", source_id), source_id = source_id,
    inference = block$inference[[1L]],
    likelihood_family = block$likelihood_family[[1L]],
    family = block$family[[1L]], tau = block$tau[[1L]],
    pooling_policy = if (nrow(block) == 1L) "single_basis" else
      "compatible_basis_chain_pool",
    fit_job_ids = paste(block$job_id, collapse = ";"),
    expected_chains = nrow(block), status = "PLANNED", stringsAsFactors = FALSE
  )
}
idolp_block <- fit_plan[fit_plan$source_id == imrs_v1_idolp_source, , drop = FALSE]
for (i in seq_len(nrow(idolp_block))) {
  forecast_i <- forecast_i + 1L
  forecast_rows[[forecast_i]] <- data.frame(
    forecast_id = sprintf("forecast__%s__basis_c%02d", imrs_v1_idolp_source,
                          idolp_block$chain_id[[i]]),
    source_id = imrs_v1_idolp_source, inference = "mcmc",
    likelihood_family = "al", family = "normal", tau = 0.05,
    pooling_policy = "basis_specific_then_score_pool",
    fit_job_ids = idolp_block$job_id[[i]], expected_chains = 1L,
    status = "PLANNED", stringsAsFactors = FALSE
  )
}
forecast_plan <- do.call(rbind, forecast_rows)
if (nrow(forecast_plan) != 46L || anyDuplicated(forecast_plan$forecast_id)) {
  stop("Materialized forecast plan is not the required 46 unique jobs.", call. = FALSE)
}
forecast_plan$is_canary <- forecast_plan$source_id %in% canary_sources
forecast_plan$stability_check <- forecast_plan$is_canary
forecast_plan$config_path <- NA_character_
forecast_plan$config_sha256 <- NA_character_
forecast_plan$job_root <- NA_character_
for (i in seq_len(nrow(forecast_plan))) {
  row <- forecast_plan[i, , drop = FALSE]
  request <- list(
    schema_version = imrs_v1_schema,
    run_id = run_id,
    forecast_id = row$forecast_id[[1L]],
    source_id = row$source_id[[1L]],
    inference = row$inference[[1L]],
    likelihood_family = row$likelihood_family[[1L]],
    family = row$family[[1L]],
    tau = as.numeric(row$tau[[1L]]),
    pooling_policy = row$pooling_policy[[1L]],
    fit_job_ids = imrs_v1_split_ids(row$fit_job_ids[[1L]]),
    expected_chains = as.integer(row$expected_chains[[1L]]),
    native_recursion_mode = imrs_v1_native_mode,
    candidate_recursion_mode = imrs_v1_recursion_mode,
    metric_estimator = imrs_v1_estimator,
    native_artifact_consistency_tolerance = imrs_v1_tolerance,
    candidate_chunk_size = as.integer(defaults$candidate_chunk_size),
    is_canary = isTRUE(row$is_canary[[1L]]),
    stability_check = isTRUE(row$stability_check[[1L]]),
    stability_contract = defaults$stability_checks,
    score_contract = list(
      targets = 1000L, horizon = 30L, origin_stride = 30L,
      point_path = "posterior_median_targetwise",
      interval = "equal_tailed_95pct_draw_metric"
    )
  )
  path <- file.path(
    state_root, "configs", "forecast", paste0(row$forecast_id[[1L]], ".json")
  )
  imrs_v1_atomic_write_json(request, path)
  forecast_plan$config_path[[i]] <- normalizePath(path, winslash = "/", mustWork = TRUE)
  forecast_plan$config_sha256[[i]] <- ffv2_file_sha256(path)
  forecast_plan$job_root[[i]] <- file.path(
    state_root, "runtime", "forecast_jobs", row$forecast_id[[1L]]
  )
}

role_map <- imrs_v1_role_map()
imrs_v1_validate_role_map(role_map)
if (!setequal(unique(role_map$source_id), unique(fit_plan$source_id))) {
  stop("Role map and fit-plan source identities differ.", call. = FALSE)
}

fit_plan_path <- imrs_v1_atomic_write_csv(
  fit_plan, file.path(state_root, "manifests", "fit_plan.csv")
)
forecast_plan_path <- imrs_v1_atomic_write_csv(
  forecast_plan, file.path(state_root, "manifests", "forecast_plan.csv")
)
role_map_path <- imrs_v1_atomic_write_csv(
  role_map, file.path(state_root, "manifests", "role_map.csv")
)

config_files <- c(fit_plan$config_path, forecast_plan$config_path, defaults_path)
implementation_files <- c(
  file.path(repo_root, "R", "qdesn_mean_readout_state_forecast.R"),
  file.path(repo_root, "R", "qdesn_vb.R"),
  file.path(repo_root, "scripts", "pipeline_real_main.R"),
  file.path(harness_root, "R", "independent_mean_readout_state_forecast_v1.R"),
  file.path(harness_root, "scripts", c(
    "materialize_independent_mean_readout_state_forecast_v1.R",
    "run_independent_mean_readout_state_fit_job.R",
    "run_independent_mean_readout_state_forecast_job.R",
    "orchestrate_independent_mean_readout_state_forecast_v1.R",
    "healthcheck_independent_mean_readout_state_forecast_v1.R",
    "closeout_independent_mean_readout_state_forecast_v1.R",
    "verify_independent_mean_readout_state_forecast_v1.R",
    "launch_independent_mean_readout_state_forecast_v1.sh"
  ))
)
if (any(!file.exists(implementation_files))) {
  stop("One or more campaign implementation files are missing.", call. = FALSE)
}
source_files <- unique(c(config_files, implementation_files, list.files(
  file.path(state_root, "sources"), recursive = TRUE, full.names = TRUE
), list.files(file.path(state_root, "source_requests"), full.names = TRUE),
list.files(file.path(state_root, "native_authority"), full.names = TRUE)))
artifact_manifest <- data.frame(
  path = normalizePath(source_files, winslash = "/", mustWork = TRUE),
  bytes = as.numeric(file.info(source_files)$size),
  sha256 = vapply(source_files, ffv2_file_sha256, character(1L)),
  stringsAsFactors = FALSE
)
artifact_manifest_path <- imrs_v1_atomic_write_csv(
  artifact_manifest, file.path(state_root, "manifests", "materialized_artifacts.csv")
)

manifest <- list(
  schema_version = imrs_v1_schema,
  run_id = run_id,
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  repo_root = repo_root,
  branch = system("git branch --show-current", intern = TRUE),
  git_commit = system("git rev-parse HEAD", intern = TRUE),
  workers = imrs_v1_workers,
  threads_per_worker = imrs_v1_threads_per_worker,
  fit_jobs = nrow(fit_plan), forecast_jobs = nrow(forecast_plan),
  source_identities = length(unique(role_map$source_id)),
  native_authority_files = nrow(fit_plan),
  native_authority_source_package_version =
    compatibility_policy$source_package_version,
  execution_package_version = execution_package_version,
  native_authority_source_commits = list(
    imi = imi_authority_commit, idolp = idolp_authority_commit
  ),
  historical_authority_compatibility = compatibility_policy,
  role_rows = nrow(role_map),
  canary_fit_jobs = sum(fit_plan$is_canary),
  canary_forecast_jobs = sum(forecast_plan$is_canary),
  canary_source_ids = canary_sources,
  old_state_root = old_state,
  old_job_plan_path = old_plan_path,
  old_job_plan_sha256 = ffv2_file_sha256(old_plan_path),
  old_materialization_sha256 = ffv2_file_sha256(old_manifest_path),
  idolp_worktree = idolp_worktree,
  fit_plan_path = fit_plan_path,
  fit_plan_sha256 = ffv2_file_sha256(fit_plan_path),
  forecast_plan_path = forecast_plan_path,
  forecast_plan_sha256 = ffv2_file_sha256(forecast_plan_path),
  role_map_path = role_map_path,
  role_map_sha256 = ffv2_file_sha256(role_map_path),
  artifact_manifest_path = artifact_manifest_path,
  artifact_manifest_sha256 = ffv2_file_sha256(artifact_manifest_path),
  estimator_id = imrs_v1_estimator,
  native_artifact_consistency_tolerance = imrs_v1_tolerance
)
imrs_v1_atomic_write_json(
  manifest, file.path(state_root, "manifests", "materialization_manifest.json")
)
cat(sprintf(
  "MATERIALIZED run_id=%s fit_jobs=%d forecast_jobs=%d sources=%d state_root=%s\n",
  run_id, nrow(fit_plan), nrow(forecast_plan),
  length(unique(role_map$source_id)), state_root
))

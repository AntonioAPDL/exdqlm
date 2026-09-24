#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/run_independent_mean_readout_state_fit_job.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/",
                           mustWork = TRUE)
state_root <- normalizePath(args$`state-root` %||% "", winslash = "/", mustWork = TRUE)
job_id <- as.character(args$`job-id` %||% "")[[1L]]
config_path <- normalizePath(args$config %||% "", winslash = "/", mustWork = TRUE)
if (!nzchar(job_id)) stop("--job-id is required.", call. = FALSE)
setwd(repo_root)
imrs_v1_set_one_thread()

config_sha <- ffv2_file_sha256(config_path)
job <- ffv2_read_json(config_path)
if (!identical(as.character(job$schema_version), imrs_v1_schema) ||
    !identical(as.character(job$job_id), job_id)) {
  stop("Fit job schema or identity mismatch.", call. = FALSE)
}
if (imrs_v1_status_success(state_root, "fit", job_id, config_sha)) {
  cat("skip verified fit job ", job_id, "\n", sep = "")
  quit(save = "no", status = 0L)
}

started <- Sys.time()
imrs_v1_write_status(state_root, "fit", job_id, list(
  status = "RUNNING", request_sha256 = config_sha, pid = Sys.getpid(),
  host = Sys.info()[["nodename"]],
  started_at = format(started, "%Y-%m-%d %H:%M:%S %Z"),
  git_commit = system("git rev-parse HEAD", intern = TRUE)
))

status <- "FAILED"
error_message <- NULL
result_payload <- list()
tryCatch({
  checks <- c(
    config_hash = identical(ffv2_file_sha256(config_path), config_sha),
    request_hash = identical(ffv2_file_sha256(job$source_request_path),
                             as.character(job$source_request_sha256)),
    observed_hash = identical(ffv2_file_sha256(job$observed_path),
                              as.character(job$observed_sha256)),
    source_hash = identical(ffv2_file_sha256(job$source_series_path),
                            as.character(job$source_series_sha256)),
    fit_window = identical(as.integer(job$root_spec$train_start_source_index), 8501L) &&
      identical(as.integer(job$root_spec$train_end_source_index), 9000L),
    forecast_window = identical(as.integer(job$root_spec$forecast_start_source_index), 9001L) &&
      identical(as.integer(job$root_spec$forecast_end_source_index), 10000L),
    horizon = identical(as.integer(job$config$forecast$horizon), 30L),
    stride = identical(as.integer(job$config$forecast$origin_stride), 30L),
    one_thread = identical(as.integer(job$config$cpp$postpred_threads), 1L),
    capsule_requested = isTRUE(job$config$outputs$save_mean_readout_state_capsule),
    source_coordinates = identical(
      as.integer(job$config$outputs$mean_readout_state_source_index),
      seq.int(as.integer(job$root_spec$raw_start_source_index),
              as.integer(job$root_spec$raw_end_source_index))
    ),
    native_authority = file.exists(job$native_authority$metric_draws_path) &&
      identical(
        ffv2_file_sha256(job$native_authority$metric_draws_path),
        as.character(job$native_authority$metric_draws_sha256)
      )
  )
  if (!all(checks)) {
    stop("Fit job contract failed: ", paste(names(checks)[!checks], collapse = ", "),
         call. = FALSE)
  }
  if (!requireNamespace("pkgload", quietly = TRUE)) stop("pkgload is required.")
  pkgload::load_all(repo_root, quiet = TRUE)
  defaults <- list(
    pipeline = list(outputs = job$config$outputs),
    metrics = job$config$metrics,
    source = job$root_spec$source_contract %||% list()
  )
  fit_request_extra <- list(
    schema_version = imrs_v1_schema, run_id = job$run_id, job_id = job_id,
    source_id = job$source_id, source_identity = job$source_identity,
    source_candidate_id = job$source_candidate_id,
    source_run_tag = job$source_run_tag, chain_id = job$chain_id,
    source_request_path = job$source_request_path,
    source_request_sha256 = job$source_request_sha256,
    forecast_estimator_experiment = imrs_v1_estimator,
    execution = list(
      config_path = config_path, config_sha256 = config_sha,
      launch_commit = system("git rev-parse HEAD", intern = TRUE)
    ),
    study_contract = job$study_contract
  )
  run <- .qdesn_validation_run_one_method(
    method = job$inference, root_spec = job$root_spec, defaults = defaults,
    file_long = job$observed_path, method_dir = job$job_root, verbose = TRUE,
    cfg_override = job$config, fit_request_extra = fit_request_extra
  )
  if (!identical(as.character(run$status), "SUCCESS")) {
    stop(as.character(run$error_message %||% "Q-DESN reconstruction failed."),
         call. = FALSE)
  }
  capsule <- imrs_v1_extract_pipeline_capsule(run, job)
  basis_path <- file.path(state_root, "capsules", "basis", paste0(job_id, ".rds"))
  posterior_path <- file.path(
    state_root, "capsules", "posterior", paste0(job_id, ".rds")
  )
  imrs_v1_atomic_save_rds(capsule$basis, basis_path)
  imrs_v1_atomic_save_rds(capsule$posterior, posterior_path)
  basis_sha <- imrs_v1_sha256(basis_path)
  posterior_sha <- imrs_v1_sha256(posterior_path)
  basis_check <- readRDS(basis_path)
  posterior_check <- readRDS(posterior_path)
  if (!identical(basis_check$feature_basis_hash,
                 posterior_check$feature_basis_hash) ||
      !identical(basis_check$feature_basis_hash,
                 capsule$basis$feature_basis_hash)) {
    stop("Published capsules failed their feature-basis contract.", call. = FALSE)
  }

  native_draws_path <- file.path(job$job_root, "tables", "metric_draws.csv.gz")
  native_summary_path <- file.path(
    job$job_root, "tables", "metric_interval_summary.csv"
  )
  native_path_path <- file.path(
    job$job_root, "tables", "forecast_rolling_origin_paths.csv"
  )
  native_lead_path <- file.path(
    job$job_root, "tables", "forecast_lead_metrics.csv"
  )
  required <- c(
    native_draws_path, native_summary_path, native_path_path, native_lead_path
  )
  if (any(!file.exists(required))) {
    stop("Native reconstruction evidence is incomplete.", call. = FALSE)
  }
  native_authority_draws <- ffv2_read_csv(
    job$native_authority$metric_draws_path
  )
  reconstructed_native_draws <- ffv2_read_csv(native_draws_path)
  authority_parity <- imrs_v1_native_authority_parity(
    reconstructed_native_draws, native_authority_draws,
    as.numeric(job$native_authority$tolerance %||% imrs_v1_tolerance)
  )
  authority_parity_path <- file.path(
    job$job_root, "manifest", "historical_native_authority_parity.csv"
  )
  imrs_v1_atomic_write_csv(authority_parity, authority_parity_path)
  if (!all(authority_parity$pass)) {
    stop("Reconstructed native forecast does not reproduce its frozen authority.",
         call. = FALSE)
  }

  heavy <- list.files(
    job$job_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
    full.names = TRUE, ignore.case = TRUE
  )
  prune_manifest <- if (length(heavy)) data.frame(
    path = normalizePath(heavy, winslash = "/", mustWork = TRUE),
    bytes = as.numeric(file.info(heavy)$size),
    sha256 = vapply(heavy, ffv2_file_sha256, character(1L)),
    action = "deleted_after_verified_capsule_export",
    stringsAsFactors = FALSE
  ) else data.frame(
    path = character(), bytes = numeric(), sha256 = character(),
    action = character(), stringsAsFactors = FALSE
  )
  prune_path <- file.path(job$job_root, "manifest", "binary_prune_manifest.csv")
  imrs_v1_atomic_write_csv(prune_manifest, prune_path)
  if (length(heavy)) unlink(heavy, force = TRUE)
  remaining <- list.files(
    job$job_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
    full.names = TRUE, ignore.case = TRUE
  )
  if (length(remaining)) stop("Fit job retained unexpected fitted-model binaries.")

  environment_path <- file.path(
    job$job_root, "manifest", "mean_readout_state_environment.json"
  )
  imrs_v1_atomic_write_json(list(
    schema_version = imrs_v1_schema,
    job_id = job_id, source_id = job$source_id, chain_id = job$chain_id,
    package_version = as.character(utils::packageVersion("exdqlm")),
    git_commit = system("git rev-parse HEAD", intern = TRUE),
    r_version = R.version.string,
    session_info = capture.output(utils::sessionInfo()),
    thread_environment = as.list(Sys.getenv(c(
      "OMP_NUM_THREADS", "OMP_THREAD_LIMIT", "OPENBLAS_NUM_THREADS",
      "MKL_NUM_THREADS", "BLIS_NUM_THREADS", "VECLIB_MAXIMUM_THREADS",
      "NUMEXPR_NUM_THREADS",
      "RCPP_PARALLEL_NUM_THREADS"
    ))),
    feature_basis_hash = capsule$basis$feature_basis_hash,
    basis_capsule_sha256 = basis_sha,
    posterior_capsule_sha256 = posterior_sha
  ), environment_path)
  result_payload <- list(
    source_id = job$source_id, chain_id = as.integer(job$chain_id),
    inference = job$inference, likelihood_family = job$likelihood_family,
    family = job$family, tau = as.numeric(job$tau),
    feature_basis_hash = capsule$basis$feature_basis_hash,
    posterior_draws = nrow(capsule$posterior$beta),
    basis_capsule_path = normalizePath(basis_path, winslash = "/", mustWork = TRUE),
    basis_capsule_sha256 = basis_sha,
    posterior_capsule_path = normalizePath(
      posterior_path, winslash = "/", mustWork = TRUE
    ),
    posterior_capsule_sha256 = posterior_sha,
    native_metric_draws_path = normalizePath(
      native_draws_path, winslash = "/", mustWork = TRUE
    ),
    native_metric_draws_sha256 = ffv2_file_sha256(native_draws_path),
    native_metric_summary_path = normalizePath(
      native_summary_path, winslash = "/", mustWork = TRUE
    ),
    native_metric_summary_sha256 = ffv2_file_sha256(native_summary_path),
    native_forecast_path = normalizePath(
      native_path_path, winslash = "/", mustWork = TRUE
    ),
    native_forecast_path_sha256 = ffv2_file_sha256(native_path_path),
    native_lead_metrics_path = normalizePath(
      native_lead_path, winslash = "/", mustWork = TRUE
    ),
    native_lead_metrics_sha256 = ffv2_file_sha256(native_lead_path),
    native_authority_parity_path = normalizePath(
      authority_parity_path, winslash = "/", mustWork = TRUE
    ),
    native_authority_parity_sha256 = ffv2_file_sha256(authority_parity_path),
    native_authority_max_abs_difference =
      max(authority_parity$max_abs_difference),
    environment_path = normalizePath(environment_path, winslash = "/", mustWork = TRUE),
    environment_sha256 = ffv2_file_sha256(environment_path),
    heavy_binary_count = 0L
  )
  status <- "SUCCESS"
}, error = function(e) {
  error_message <<- conditionMessage(e)
})

ended <- Sys.time()
imrs_v1_write_status(state_root, "fit", job_id, c(list(
  status = status, request_sha256 = config_sha,
  error_message = error_message, pid = Sys.getpid(),
  host = Sys.info()[["nodename"]],
  started_at = format(started, "%Y-%m-%d %H:%M:%S %Z"),
  ended_at = format(ended, "%Y-%m-%d %H:%M:%S %Z"),
  elapsed_seconds = as.numeric(difftime(ended, started, units = "secs")),
  git_commit = system("git rev-parse HEAD", intern = TRUE)
), result_payload))
cat(sprintf("fit job=%s status=%s elapsed=%.1f error=%s\n", job_id, status,
            as.numeric(difftime(ended, started, units = "secs")),
            error_message %||% ""))
quit(save = "no", status = if (identical(status, "SUCCESS")) 0L else 1L)

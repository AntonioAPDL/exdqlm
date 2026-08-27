#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  for (pkg in c("jsonlite", "pkgload")) {
    if (!requireNamespace(pkg, quietly = TRUE)) stop("Missing package: ", pkg)
  }
})

args <- commandArgs(trailingOnly = TRUE)
arg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (!length(i) || i[[1L]] >= length(args)) default else args[[i[[1L]] + 1L]]
}
repo <- normalizePath(
  arg("--repo-root", system("git rev-parse --show-toplevel", intern = TRUE)),
  winslash = "/", mustWork = TRUE
)
setwd(repo)
source(file.path(
  repo, "validation", "fitforecast_v2", "R",
  "independent_location_orthogonalized_tau0_v2.R"
))
source(file.path(repo, "R", "readout_transform.R"))
config_arg <- arg("--config")
run_tag <- as.character(arg("--run-tag", ""))[1L]
if (is.null(config_arg) || !nzchar(config_arg) || !nzchar(run_tag)) {
  stop("--config and --run-tag are required.", call. = FALSE)
}
config_path <- if (grepl("^/", config_arg)) config_arg else file.path(repo, config_arg)
config_path <- normalizePath(config_path, winslash = "/", mustWork = TRUE)
job <- qdesn_ssv2_read_json(config_path)
job_id <- as.character(job$job_id)
job_root <- idol_v2_job_root(repo, run_tag, job_id)
dir.create(job_root, recursive = TRUE, showWarnings = FALSE)
status_path <- file.path(job_root, "job_status.json")
config_sha256 <- qdesn_ssv2_sha256(config_path)

if (file.exists(status_path)) {
  previous <- tryCatch(qdesn_ssv2_read_json(status_path), error = function(e) NULL)
  if (!is.null(previous) && identical(as.character(previous$status), "SUCCESS") &&
      identical(as.character(previous$config_sha256), config_sha256)) {
    cat(sprintf("skip completed job: %s\n", job_id))
    quit(save = "no", status = 0L)
  }
}

observed_path <- normalizePath(as.character(job$observed_path),
                               winslash = "/", mustWork = TRUE)
registry_path <- normalizePath(as.character(job$source_registry_path),
                               winslash = "/", mustWork = TRUE)
likelihood <- as.character(job$likelihood_target)
expected_method <- if (likelihood == "exal") qdesn_ssv2_method_id else
  "sigma_then_gamma"
exact_dimension <- qdesn_ssv2_effective_readout_dimension(
  job$config$desn$n, job$config$desn$n_tilde,
  job$config$readout$reservoir_lags, job$config$lags$m_y
)
interval_cfg <- job$config$metrics$posterior_metric_intervals
transform_cfg <- .qdesn_readout_transform_spec(job$config$readout$linear_transform)
contracts <- c(
  schema = identical(as.character(job$schema_version), idol_v2_schema),
  observed_hash = identical(qdesn_ssv2_sha256(observed_path),
                            as.character(job$observed_sha256)),
  registry_hash = identical(qdesn_ssv2_sha256(registry_path),
                            as.character(job$source_registry_sha256)),
  canonical_registry = identical(as.character(job$source_registry_hash_value),
                                 qdesn_ssv2_registry_hash),
  likelihood = likelihood %in% c("al", "exal") &&
    identical(as.character(job$config$inference$likelihood_family), likelihood),
  method = identical(
    as.character(job$config$inference$mcmc$slice$core_update_mode), expected_method
  ),
  train_window = identical(as.integer(job$root_spec$train_start_source_index), 8501L) &&
    identical(as.integer(job$root_spec$train_end_source_index), 9000L),
  forecast_window =
    identical(as.integer(job$root_spec$forecast_start_source_index), 9001L) &&
    identical(as.integer(job$root_spec$forecast_end_source_index), 10000L),
  no_refit = !isTRUE(job$config$metrics$rolling_origin$refit_per_origin),
  lead = identical(as.integer(job$config$metrics$rolling_origin$max_lead_configured),
                   30L),
  stride = identical(as.integer(job$config$metrics$rolling_origin$origin_stride), 30L),
  dimension = identical(as.integer(job$root_spec$effective_readout_dimension),
                        exact_dimension),
  capacity = exact_dimension <= idol_v2_max_effective_dimension,
  tau0 = is.finite(as.numeric(job$profile$rhs_tau0)) &&
    as.numeric(job$profile$rhs_tau0) > 0,
  transform_mode = identical(
    transform_cfg$mode, as.character(job$profile$transform_mode)
  ),
  transform_training_only = isTRUE(
    job$study_contract$readout_transform_training_only
  ),
  transform_forecast_consistent = isTRUE(
    job$study_contract$readout_transform_forecast_consistent
  ),
  intervals = isTRUE(interval_cfg$enabled) && isTRUE(interval_cfg$required),
  attribution = isTRUE(interval_cfg$origin_horizon_attribution$enabled) &&
    isTRUE(interval_cfg$origin_horizon_attribution$required),
  common_shift = isTRUE(interval_cfg$common_shift_intervention$enabled) &&
    isTRUE(interval_cfg$common_shift_intervention$required),
  one_thread = identical(as.integer(job$config$cpp$postpred_threads), 1L),
  no_prior_recycling = !isTRUE(job$study_contract$posterior_recycled_as_prior)
)
if (!all(contracts)) {
  stop(sprintf("Job contract failed for %s: %s", job_id,
               paste(names(contracts)[!contracts], collapse = ", ")), call. = FALSE)
}

started_at <- as.character(Sys.time())
qdesn_ssv2_write_json(list(
  job_id = job_id, stage = job$stage, target_cell_id = job$target_cell_id,
  candidate_id = job$candidate_id, source_id = job$source_id,
  reservoir_seed_id = job$reservoir_seed_id, chain_id = job$chain_id,
  likelihood_target = likelihood, inference_method_id = job$inference_method_id,
  pid = Sys.getpid(), host = Sys.info()[["nodename"]],
  cpu_affinity = tryCatch(system2(
    "taskset", c("-pc", as.character(Sys.getpid())), stdout = TRUE
  ),
                          error = function(e) NA_character_),
  started_at = started_at, config_path = config_path,
  config_sha256 = config_sha256,
  git_commit = system("git rev-parse HEAD", intern = TRUE)
), file.path(job_root, "job_started.json"))

Sys.setenv(
  OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1", MKL_NUM_THREADS = "1",
  VECLIB_MAXIMUM_THREADS = "1", NUMEXPR_NUM_THREADS = "1",
  RCPP_PARALLEL_NUM_THREADS = "1"
)
pkgload::load_all(repo, quiet = TRUE)
defaults <- list(
  pipeline = list(outputs = job$config$outputs), metrics = job$config$metrics,
  source = job$root_spec$source_contract %||% list()
)
fit_request_extra <- list(
  schema_version = idol_v2_schema,
  spec_id = job$spec_id, job_id = job_id, stage = job$stage,
  target_cell_id = job$target_cell_id, target_metrics = job$target_metrics,
  candidate_id = job$candidate_id, source_id = job$source_id,
  source_role = job$source_role, reservoir_seed_id = job$reservoir_seed_id,
  chain_id = job$chain_id, profile = job$profile,
  execution = list(
    method = "mcmc", likelihood_family = likelihood,
    inference_method_id = job$inference_method_id,
    config_path = config_path, config_sha256 = config_sha256,
    launch_commit = system("git rev-parse HEAD", intern = TRUE)
  ),
  study_contract = job$study_contract
)

result <- NULL
error_message <- NA_character_
t0 <- Sys.time()
design_error <- tryCatch({
  idol_v2_write_design_diagnostics(job, observed_path, job_root)
  NA_character_
}, error = function(e) conditionMessage(e))
if (!is.na(design_error)) error_message <- paste0("design diagnostic: ", design_error)

if (is.na(design_error)) {
  result <- tryCatch(
    .qdesn_validation_run_one_method(
      method = "mcmc", root_spec = job$root_spec, defaults = defaults,
      file_long = observed_path, method_dir = job_root, verbose = TRUE,
      cfg_override = job$config, fit_request_extra = fit_request_extra
    ),
    error = function(e) {
      error_message <<- conditionMessage(e)
      NULL
    }
  )
}

if (!is.null(result) && identical(as.character(result$status), "SUCCESS")) {
  postprocess_error <- tryCatch({
    source_df <- .qdesn_validation_read_source_series(job$root_spec)
    q_true_full <- if ("q_target" %in% names(source_df)) {
      as.numeric(source_df$q_target)
    } else if ("q_true" %in% names(source_df)) {
      as.numeric(source_df$q_true)
    } else as.numeric(source_df$mu)
    metrics <- .qdesn_static_crossstudy_collect_metrics_from_summary(
      result$summary, q_true_full
    )
    signoff_cfg <- .qdesn_validation_signoff_cfg(defaults)
    meta_names <- c("root_id", "scenario", "tau", "likelihood_family",
                    "beta_prior_type", "seed", "reservoir_profile")
    meta_row <- result$health[, meta_names, drop = FALSE]
    signoff <- .qdesn_validation_mcmc_signoff_from_rows(
      meta_row, result$health, result$progress_trace, signoff_cfg$mcmc
    )
    fit <- .qdesn_static_crossstudy_fit_summary_row(
      root_spec = job$root_spec, likelihood_family = likelihood, method = "mcmc",
      health_row = result$health, metrics = metrics, signoff_row = signoff,
      method_dir = job_root
    )
    fit$spec_id <- job$spec_id
    fit$target_cell_id <- job$target_cell_id
    fit$candidate_id <- job$candidate_id
    fit$source_id <- job$source_id
    fit$reservoir_seed_id <- job$reservoir_seed_id
    fit$chain_id <- job$chain_id
    fit$inference_method_id <- job$inference_method_id
    fit$config_sha256 <- config_sha256
    fit$source_registry_hash_value <- qdesn_ssv2_registry_hash
    qdesn_ssv2_write_csv(signoff, file.path(job_root, "signoff_summary.csv"))
    qdesn_ssv2_write_csv(fit, file.path(job_root, "fit_summary_row.csv"))
    required_diagnostics <- c(
      idol_v2_required_diagnostic_paths(job_root),
      file.path(job_root, "tables", "design_conditioning_diagnostics.csv")
    )
    if (any(!file.exists(required_diagnostics))) {
      stop(sprintf("Required compact diagnostics are missing: %s",
                   paste(basename(required_diagnostics[!file.exists(required_diagnostics)]),
                         collapse = ", ")), call. = FALSE)
    }
    reconstruction <- qdesn_ssv2_read_csv(file.path(
      job_root, "tables", "origin_horizon_reconstruction_audit.csv"
    ))
    if (!nrow(reconstruction) || any(!reconstruction$pass) ||
        max(reconstruction$forecast_mae_max_abs_error,
            reconstruction$forecast_check_max_abs_error, na.rm = TRUE) >
          idol_v2_reconstruction_tolerance) {
      stop("Origin-horizon metric reconstruction exceeded 1e-6.", call. = FALSE)
    }
    NA_character_
  }, error = function(e) conditionMessage(e))
  if (!is.na(postprocess_error)) {
    error_message <- postprocess_error
    result$status <- "FAIL"
  }
}

binary_paths <- list.files(
  job_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
  full.names = TRUE, ignore.case = TRUE
)
if (length(binary_paths)) {
  prune <- data.frame(
    path = vapply(binary_paths, qdesn_ssv2_rel, character(1L), repo_root = repo),
    bytes = as.numeric(file.info(binary_paths)$size),
    sha256 = vapply(binary_paths, qdesn_ssv2_sha256, character(1L)),
    action = "deleted_after_required_compact_diagnostic_export",
    stringsAsFactors = FALSE
  )
  qdesn_ssv2_write_csv(
    prune, file.path(job_root, "manifest", "binary_prune_manifest.csv")
  )
  unlink(binary_paths, force = TRUE)
}
binary_remaining <- list.files(
  job_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
  full.names = TRUE, ignore.case = TRUE
)
status <- if (!is.null(result) && identical(as.character(result$status), "SUCCESS") &&
              !length(binary_remaining)) "SUCCESS" else "FAIL"
metric_values <- idol_v2_metric_values(job_root)
required_metrics <- as.character(unlist(job$target_metrics, use.names = FALSE))
if (identical(status, "SUCCESS") &&
    any(!is.finite(metric_values[required_metrics]))) {
  status <- "FAIL"
  error_message <- paste(
    na.omit(c(error_message, "At least one declared target metric is not finite.")),
    collapse = "; "
  )
}
diagnostic_paths <- idol_v2_required_diagnostic_paths(job_root)
diagnostic_hashes <- as.list(setNames(
  vapply(diagnostic_paths[file.exists(diagnostic_paths)], qdesn_ssv2_sha256,
         character(1L)),
  basename(diagnostic_paths[file.exists(diagnostic_paths)])
))
elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
qdesn_ssv2_write_json(list(
  job_id = job_id, stage = job$stage, target_cell_id = job$target_cell_id,
  candidate_id = job$candidate_id, source_id = job$source_id,
  reservoir_seed_id = job$reservoir_seed_id, chain_id = job$chain_id,
  likelihood_target = likelihood, status = status,
  started_at = started_at, finished_at = as.character(Sys.time()),
  elapsed_seconds = elapsed, target_metrics = job$target_metrics,
  metric_values = as.list(metric_values),
  current_metric_values = job$current_metric_values,
  comparator_metric_values = job$comparator_metric_values,
  config_path = config_path, config_sha256 = config_sha256,
  observed_sha256 = qdesn_ssv2_sha256(observed_path),
  source_registry_sha256 = qdesn_ssv2_sha256(registry_path),
  source_registry_hash_value = qdesn_ssv2_registry_hash,
  inference_method_id = job$inference_method_id,
  diagnostic_artifact_hashes = diagnostic_hashes,
  error_message = if (is.na(error_message) || !nzchar(error_message)) NULL else
    error_message,
  binary_payloads_remaining = length(binary_remaining)
), status_path)

cat(sprintf(
  "job=%s status=%s fit=%.8g mae=%.8g check=%.8g elapsed_seconds=%.1f\n",
  job_id, status, metric_values[[1L]], metric_values[[2L]],
  metric_values[[3L]], elapsed
))
quit(save = "no", status = if (status == "SUCCESS") 0L else 1L)

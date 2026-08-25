#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/run_independent_metric_intervals_v1_job.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/", mustWork = TRUE)
setwd(repo_root)
engine <- as.character(args$engine %||% "")[1L]
job_id <- as.character(args$`job-id` %||% "")[1L]
config_path <- normalizePath(args$config %||% "", winslash = "/", mustWork = TRUE)
state_root <- normalizePath(args$`state-root` %||% "", winslash = "/", mustWork = TRUE)
if (!engine %in% c("qdesn", "dqlm") || !nzchar(job_id)) {
  stop("--engine, --job-id, --config, and --state-root are required.", call. = FALSE)
}
config_header <- tryCatch(ffv2_read_json(config_path), error = function(...) list())
job_schema <- as.character(config_header$schema_version %||% imi_v1_schema)[1L]
supported_schemas <- c(imi_v1_schema, imid_v1_schema)
if (!job_schema %in% supported_schemas) {
  stop(sprintf("Unsupported independent interval job schema: %s", job_schema),
       call. = FALSE)
}
status_path <- file.path(state_root, "status", paste0(job_id, ".json"))
ffv2_ensure_dir(dirname(status_path))
config_sha256 <- ffv2_file_sha256(config_path)
if (file.exists(status_path)) {
  previous <- tryCatch(ffv2_read_json(status_path), error = function(...) NULL)
  if (!is.null(previous) && identical(as.character(previous$status), "SUCCESS") &&
      identical(as.character(previous$config_sha256), config_sha256)) {
    cat(sprintf("skip completed job %s\n", job_id))
    quit(save = "no", status = 0L)
  }
}

Sys.setenv(
  OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1", MKL_NUM_THREADS = "1",
  VECLIB_MAXIMUM_THREADS = "1", NUMEXPR_NUM_THREADS = "1",
  RCPP_PARALLEL_NUM_THREADS = "1"
)
started <- Sys.time()
ffv2_write_json(list(
  schema_version = job_schema, job_id = job_id, engine = engine, status = "RUNNING",
  config_path = config_path, config_sha256 = config_sha256,
  pid = Sys.getpid(), host = Sys.info()[["nodename"]],
  started_at = format(started, "%Y-%m-%d %H:%M:%S %Z"),
  git_commit = system("git rev-parse HEAD", intern = TRUE)
), status_path)

result_payload <- NULL
error_message <- NA_character_
status <- "FAIL"
tryCatch({
  if (engine == "qdesn") {
    if (!requireNamespace("pkgload", quietly = TRUE)) stop("pkgload is required.")
    pkgload::load_all(repo_root, quiet = TRUE)
    job <- ffv2_read_json(config_path)
    contracts <- c(
      schema = identical(as.character(job$schema_version), job_schema),
      job_id = identical(as.character(job$job_id), job_id),
      observed_hash = identical(ffv2_file_sha256(job$observed_path),
                                as.character(job$observed_sha256)),
      source_hash = identical(ffv2_file_sha256(job$source_series_path),
                              as.character(job$source_series_sha256)),
      request_hash = identical(ffv2_file_sha256(job$source_request_path),
                               as.character(job$source_request_sha256)),
      fit_window = identical(as.integer(job$root_spec$train_start_source_index), 8501L) &&
        identical(as.integer(job$root_spec$train_end_source_index), 9000L),
      forecast_window = identical(as.integer(job$root_spec$forecast_start_source_index), 9001L) &&
        identical(as.integer(job$root_spec$forecast_end_source_index), 10000L),
      reservoir_seed = identical(as.integer(job$config$desn$seed),
                                 as.integer(job$root_spec$desn_seed)),
      interval_enabled = isTRUE(job$config$metrics$posterior_metric_intervals$enabled) &&
        isTRUE(job$config$metrics$posterior_metric_intervals$required),
      exal_m0 = job$likelihood_family != "exal" ||
        identical(as.character(job$config$inference$mcmc$slice$core_update_mode),
                  "m0_v_collapsed_support_logit") || job$inference == "vb"
    )
    if (!all(contracts)) {
      stop(sprintf("Q-DESN job contract failed: %s",
                   paste(names(contracts)[!contracts], collapse = ", ")), call. = FALSE)
    }
    defaults <- list(
      pipeline = list(outputs = job$config$outputs),
      metrics = job$config$metrics,
      source = job$root_spec$source_contract %||% list()
    )
    fit_request_extra <- list(
      schema_version = job_schema, run_id = job$run_id, job_id = job_id,
      replay_id = job$replay_id, source_identity = job$source_identity,
      source_candidate_id = job$source_candidate_id,
      source_run_tag = job$source_run_tag, chain_id = job$chain_id,
      source_request_path = job$source_request_path,
      source_request_sha256 = job$source_request_sha256,
      study_contract = job$study_contract,
      execution = list(config_path = config_path, config_sha256 = config_sha256,
                       launch_commit = system("git rev-parse HEAD", intern = TRUE))
    )
    run <- .qdesn_validation_run_one_method(
      method = job$inference, root_spec = job$root_spec, defaults = defaults,
      file_long = job$observed_path, method_dir = job$job_root, verbose = TRUE,
      cfg_override = job$config, fit_request_extra = fit_request_extra
    )
    if (!identical(as.character(run$status), "SUCCESS")) {
      stop(as.character(run$error_message %||% "Q-DESN fit did not complete successfully."),
           call. = FALSE)
    }
    draws_path <- file.path(job$job_root, "tables", "metric_draws.csv.gz")
    summary_path <- file.path(job$job_root, "tables", "metric_interval_summary.csv")
    interval_manifest_path <- file.path(job$job_root, "manifest", "metric_interval_manifest.json")
    coupling_enabled <- isTRUE(
      job$config$metrics$posterior_metric_intervals$coupling_sensitivity$enabled
    )
    coupling_draws_path <- file.path(job$job_root, "tables", "metric_coupling_draws.csv.gz")
    coupling_summary_path <- file.path(job$job_root, "tables", "metric_coupling_summary.csv")
    dispersion_enabled <- isTRUE(
      job$config$metrics$posterior_metric_intervals$dispersion_diagnostic$enabled
    )
    dispersion_manifest_path <- file.path(
      job$job_root, "manifest", "metric_dispersion_manifest.json"
    )
    dispersion_mechanism_path <- file.path(
      job$job_root, "tables", "metric_dispersion_mechanism_summary.csv"
    )
    dispersion_draws_path <- file.path(
      job$job_root, "tables", "metric_dispersion_draw_diagnostics.csv.gz"
    )
    binary_paths <- list.files(job$job_root, pattern = "[.](rds|rda|RData)$",
                               recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
    if (length(binary_paths)) {
      prune <- data.frame(
        path = normalizePath(binary_paths, winslash = "/", mustWork = TRUE),
        bytes = as.numeric(file.info(binary_paths)$size),
        sha256 = vapply(binary_paths, ffv2_file_sha256, character(1L)),
        action = "removed_after_required_interval_export",
        stringsAsFactors = FALSE
      )
      ffv2_write_csv(prune, file.path(job$job_root, "manifest", "binary_prune_manifest.csv"))
      unlink(binary_paths, force = TRUE)
    }
    remaining <- list.files(job$job_root, pattern = "[.](rds|rda|RData)$",
                            recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
    required <- c(draws_path, summary_path, interval_manifest_path)
    if (coupling_enabled) {
      required <- c(required, coupling_draws_path, coupling_summary_path)
    }
    if (dispersion_enabled) {
      required <- c(required, dispersion_manifest_path, dispersion_mechanism_path,
                    dispersion_draws_path)
    }
    if (any(!file.exists(required)) || length(remaining)) {
      stop("Q-DESN interval artifacts are incomplete or heavy binaries remain.", call. = FALSE)
    }
    draws <- ffv2_read_csv(draws_path)
    result_payload <- list(
      replay_id = job$replay_id, chain_id = job$chain_id,
      metric_draws_path = draws_path, metric_draws_sha256 = ffv2_file_sha256(draws_path),
      metric_interval_summary_path = summary_path,
      metric_interval_summary_sha256 = ffv2_file_sha256(summary_path),
      metric_interval_manifest_path = interval_manifest_path,
      metric_interval_manifest_sha256 = ffv2_file_sha256(interval_manifest_path),
      metric_draws = nrow(draws),
      metric_coupling_draws_path = if (coupling_enabled) coupling_draws_path else NULL,
      metric_coupling_draws_sha256 = if (coupling_enabled) {
        ffv2_file_sha256(coupling_draws_path)
      } else NULL,
      metric_coupling_summary_path = if (coupling_enabled) coupling_summary_path else NULL,
      metric_coupling_summary_sha256 = if (coupling_enabled) {
        ffv2_file_sha256(coupling_summary_path)
      } else NULL,
      metric_dispersion_manifest_path = if (dispersion_enabled) {
        dispersion_manifest_path
      } else NULL,
      metric_dispersion_manifest_sha256 = if (dispersion_enabled) {
        ffv2_file_sha256(dispersion_manifest_path)
      } else NULL,
      metric_dispersion_mechanism_path = if (dispersion_enabled) {
        dispersion_mechanism_path
      } else NULL,
      metric_dispersion_mechanism_sha256 = if (dispersion_enabled) {
        ffv2_file_sha256(dispersion_mechanism_path)
      } else NULL,
      metric_dispersion_draws_path = if (dispersion_enabled) {
        dispersion_draws_path
      } else NULL,
      metric_dispersion_draws_sha256 = if (dispersion_enabled) {
        ffv2_file_sha256(dispersion_draws_path)
      } else NULL,
      heavy_binary_count = 0L
    )
  } else {
    config <- ffv2_read_json(config_path)
    replay_from_job <- sub("__c[0-9]+$", "", sub("^dqlm__", "", job_id))
    if (!identical(as.character(config$source_replay_id),
                   replay_from_job)) {
      stop("DQLM job/replay identity mismatch.", call. = FALSE)
    }
    ffv2_run_row(config_path, force = FALSE, validation_stage = "all")
    required <- c(config$metric_draws_path, config$metric_interval_summary_path,
                  config$metric_interval_manifest_path)
    coupling_enabled <- isTRUE(
      (config$metric_intervals %||% list())$coupling_sensitivity$enabled
    )
    if (coupling_enabled) {
      required <- c(required, config$metric_coupling_draws_path,
                    config$metric_coupling_summary_path,
                    config$metric_coupling_manifest_path)
    }
    if (any(!file.exists(required))) stop("DQLM interval artifacts are incomplete.", call. = FALSE)
    draws <- ffv2_read_csv(config$metric_draws_path)
    binary_candidates <- c(config$fit_handoff_path, config$vb_init_handoff_path)
    binary_candidates <- binary_candidates[nzchar(as.character(binary_candidates)) &
                                             file.exists(binary_candidates)]
    if (length(binary_candidates)) {
      stop("DQLM successful row retained a forbidden fit handoff.", call. = FALSE)
    }
    result_payload <- list(
      replay_id = config$source_replay_id, chain_id = config$chain_id,
      metric_draws_path = config$metric_draws_path,
      metric_draws_sha256 = ffv2_file_sha256(config$metric_draws_path),
      metric_interval_summary_path = config$metric_interval_summary_path,
      metric_interval_summary_sha256 = ffv2_file_sha256(config$metric_interval_summary_path),
      metric_interval_manifest_path = config$metric_interval_manifest_path,
      metric_interval_manifest_sha256 = ffv2_file_sha256(config$metric_interval_manifest_path),
      metric_draws = nrow(draws),
      metric_coupling_draws_path = if (coupling_enabled) {
        config$metric_coupling_draws_path
      } else NULL,
      metric_coupling_draws_sha256 = if (coupling_enabled) {
        ffv2_file_sha256(config$metric_coupling_draws_path)
      } else NULL,
      metric_coupling_summary_path = if (coupling_enabled) {
        config$metric_coupling_summary_path
      } else NULL,
      metric_coupling_summary_sha256 = if (coupling_enabled) {
        ffv2_file_sha256(config$metric_coupling_summary_path)
      } else NULL,
      heavy_binary_count = 0L
    )
  }
  status <- "SUCCESS"
}, error = function(e) {
  error_message <<- conditionMessage(e)
})

ended <- Sys.time()
payload <- c(list(
  schema_version = job_schema, job_id = job_id, engine = engine,
  status = status, error_message = if (is.na(error_message)) NULL else error_message,
  config_path = config_path, config_sha256 = config_sha256,
  pid = Sys.getpid(), host = Sys.info()[["nodename"]],
  started_at = format(started, "%Y-%m-%d %H:%M:%S %Z"),
  ended_at = format(ended, "%Y-%m-%d %H:%M:%S %Z"),
  elapsed_seconds = as.numeric(difftime(ended, started, units = "secs")),
  git_commit = system("git rev-parse HEAD", intern = TRUE)
), result_payload %||% list())
ffv2_write_json(payload, status_path)
cat(sprintf("job=%s engine=%s status=%s elapsed=%.1f error=%s\n", job_id, engine,
            status, payload$elapsed_seconds, ifelse(is.na(error_message), "", error_message)))
quit(save = "no", status = if (status == "SUCCESS") 0L else 1L)

#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  for (pkg in c("jsonlite", "pkgload")) {
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
                 "independent_exal_m0_structural_screen_v2.R"))

config_arg <- get_arg("--config")
run_tag <- as.character(get_arg("--run-tag", ""))[1L]
if (is.null(config_arg) || !nzchar(config_arg) || !nzchar(run_tag)) {
  stop("--config and --run-tag are required.", call. = FALSE)
}
config_path <- if (grepl("^/", config_arg)) config_arg else file.path(repo_root, config_arg)
config_path <- normalizePath(config_path, winslash = "/", mustWork = TRUE)
job <- qdesn_ssv2_read_json(config_path)
job_id <- as.character(job$job_id)
job_root <- qdesn_ssv2_job_root(repo_root, run_tag, job_id)
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

observed_path <- as.character(job$observed_path)
if (!grepl("^/", observed_path)) observed_path <- file.path(repo_root, observed_path)
observed_path <- normalizePath(observed_path, winslash = "/", mustWork = TRUE)
registry_path <- normalizePath(as.character(job$source_registry_path),
                               winslash = "/", mustWork = TRUE)
contracts <- c(
  observed_hash = identical(qdesn_ssv2_sha256(observed_path), as.character(job$observed_sha256)),
  registry_hash = identical(qdesn_ssv2_sha256(registry_path), as.character(job$source_registry_sha256)),
  canonical_registry = identical(as.character(job$source_registry_hash_value), qdesn_ssv2_registry_hash),
  method = identical(as.character(job$config$inference$mcmc$slice$core_update_mode),
                     qdesn_ssv2_method_id),
  train_start = identical(as.integer(job$root_spec$train_start_source_index), 8501L),
  train_end = identical(as.integer(job$root_spec$train_end_source_index), 9000L),
  forecast_start = identical(as.integer(job$root_spec$forecast_start_source_index), 9001L),
  forecast_end = identical(as.integer(job$root_spec$forecast_end_source_index), 10000L),
  no_refit = !isTRUE(job$config$metrics$rolling_origin$refit_per_origin),
  lead = identical(as.integer(job$config$metrics$rolling_origin$max_lead_configured), 30L),
  stride = identical(as.integer(job$config$metrics$rolling_origin$origin_stride), 30L)
)
exact_dimension <- qdesn_ssv2_effective_readout_dimension(
  job$config$desn$n, job$config$desn$n_tilde,
  job$config$readout$reservoir_lags, job$config$lags$m_y
)
contracts <- c(
  contracts,
  readout_dimension = identical(as.integer(job$root_spec$effective_readout_dimension),
                                exact_dimension),
  readout_capacity = exact_dimension <= qdesn_ssv2_max_effective_readout_dimension,
  stage_timeout = identical(as.integer(job$config$validation$timeout_seconds),
                            qdesn_ssv2_timeout_seconds(as.character(job$stage)))
)
if (!all(contracts)) {
  stop(sprintf("Job contract failed for %s: %s", job_id,
               paste(names(contracts)[!contracts], collapse = ", ")), call. = FALSE)
}

started_at <- as.character(Sys.time())
qdesn_ssv2_write_json(list(
  job_id = job_id, stage = job$stage, target_cell_id = job$target_cell_id,
  candidate_id = job$candidate_id, source_id = job$source_id,
  chain_id = job$chain_id, pid = Sys.getpid(), host = Sys.info()[["nodename"]],
  started_at = started_at, config_path = config_path, config_sha256 = config_sha256,
  git_commit = system("git rev-parse HEAD", intern = TRUE)
), file.path(job_root, "job_started.json"))

Sys.setenv(
  OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1", MKL_NUM_THREADS = "1",
  VECLIB_MAXIMUM_THREADS = "1", NUMEXPR_NUM_THREADS = "1",
  RCPP_PARALLEL_NUM_THREADS = "1"
)

pkgload::load_all(repo_root, quiet = TRUE)
defaults <- list(
  pipeline = list(outputs = job$config$outputs), metrics = job$config$metrics,
  source = job$root_spec$source_contract %||% list()
)
fit_request_extra <- list(
  spec_id = job$spec_id, job_id = job_id, stage = job$stage,
  target_cell_id = job$target_cell_id, candidate_id = job$candidate_id,
  source_id = job$source_id, source_role = job$source_role,
  chain_id = job$chain_id, profile = job$profile,
  execution = list(
    method = "mcmc", likelihood_family = "exal",
    inference_method_id = "M0_v_collapsed_support_logit",
    config_path = config_path, config_sha256 = config_sha256,
    launch_commit = system("git rev-parse HEAD", intern = TRUE)
  ),
  study_contract = job$study_contract
)

result <- NULL
error_message <- NA_character_
t0 <- Sys.time()
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

if (!is.null(result) && identical(as.character(result$status), "SUCCESS")) {
  postprocess_error <- tryCatch({
    source_df <- .qdesn_validation_read_source_series(job$root_spec)
    q_true_full <- if ("q_target" %in% names(source_df)) {
      as.numeric(source_df$q_target)
    } else if ("q_true" %in% names(source_df)) {
      as.numeric(source_df$q_true)
    } else as.numeric(source_df$mu)
    metrics <- .qdesn_static_crossstudy_collect_metrics_from_summary(result$summary, q_true_full)
    signoff_cfg <- .qdesn_validation_signoff_cfg(defaults)
    meta_names <- c("root_id", "scenario", "tau", "likelihood_family",
                    "beta_prior_type", "seed", "reservoir_profile")
    meta_row <- result$health[, meta_names, drop = FALSE]
    signoff <- .qdesn_validation_mcmc_signoff_from_rows(
      meta_row, result$health, result$progress_trace, signoff_cfg$mcmc
    )
    fit <- .qdesn_static_crossstudy_fit_summary_row(
      root_spec = job$root_spec, likelihood_family = "exal", method = "mcmc",
      health_row = result$health, metrics = metrics, signoff_row = signoff,
      method_dir = job_root
    )
    fit$spec_id <- job$spec_id
    fit$target_cell_id <- job$target_cell_id
    fit$candidate_id <- job$candidate_id
    fit$source_id <- job$source_id
    fit$chain_id <- job$chain_id
    fit$inference_method_id <- "M0_v_collapsed_support_logit"
    fit$config_sha256 <- config_sha256
    fit$source_registry_hash_value <- qdesn_ssv2_registry_hash
    qdesn_ssv2_write_csv(signoff, file.path(job_root, "signoff_summary.csv"))
    qdesn_ssv2_write_csv(fit, file.path(job_root, "fit_summary_row.csv"))
    NA_character_
  }, error = function(e) conditionMessage(e))
  if (!is.na(postprocess_error)) {
    error_message <- postprocess_error
    result$status <- "FAIL"
  }
}

binary_paths <- list.files(job_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
                           full.names = TRUE, ignore.case = TRUE)
if (length(binary_paths)) {
  prune <- data.frame(
    path = vapply(binary_paths, qdesn_ssv2_rel, character(1L), repo_root = repo_root),
    bytes = as.numeric(file.info(binary_paths)$size),
    sha256 = vapply(binary_paths, qdesn_ssv2_sha256, character(1L)),
    action = "deleted_by_predeclared_storage_light_policy",
    stringsAsFactors = FALSE
  )
  qdesn_ssv2_write_csv(prune, file.path(job_root, "manifest", "binary_prune_manifest.csv"))
  unlink(binary_paths, force = TRUE)
}
binary_remaining <- list.files(job_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
                               full.names = TRUE, ignore.case = TRUE)
status <- if (!is.null(result) && identical(as.character(result$status), "SUCCESS") &&
              !length(binary_remaining)) "SUCCESS" else "FAIL"
if (is.na(error_message) && !is.null(result)) {
  error_message <- as.character(result$error_message %||% NA_character_)[1L]
}
if (length(binary_remaining)) {
  error_message <- paste(na.omit(c(error_message, "Forbidden binary payload remains.")),
                         collapse = "; ")
}
elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
requires_rolling_objective <- grepl("^forecast_", as.character(job$objective_metric)) &&
  isTRUE(job$config$metrics$rolling_origin$require_lead_export)
objective_value <- qdesn_ssv2_metric_value(
  job_root, job$objective_metric, require_rolling = requires_rolling_objective
)
objective_source <- if (grepl("^forecast_", as.character(job$objective_metric))) {
  if (isTRUE(requires_rolling_objective)) "forecast_rolling_origin_paths.csv" else
    "forecast_horizon_summary.csv"
} else {
  "fit_summary_row.csv"
}
if (identical(status, "SUCCESS") && !is.finite(objective_value)) {
  status <- "FAIL"
  error_message <- paste(
    na.omit(c(error_message, sprintf(
      "Required objective %s is not finite from %s.",
      as.character(job$objective_metric), objective_source
    ))),
    collapse = "; "
  )
}
qdesn_ssv2_write_json(list(
  job_id = job_id, stage = job$stage, target_cell_id = job$target_cell_id,
  candidate_id = job$candidate_id, source_id = job$source_id,
  chain_id = job$chain_id, status = status, started_at = started_at,
  finished_at = as.character(Sys.time()), elapsed_seconds = elapsed,
  objective_metric = job$objective_metric, objective_value = objective_value,
  objective_source = objective_source,
  current_value = job$current_value, comparator_value = job$comparator_value,
  config_path = config_path, config_sha256 = config_sha256,
  observed_sha256 = qdesn_ssv2_sha256(observed_path),
  source_registry_sha256 = qdesn_ssv2_sha256(registry_path),
  source_registry_hash_value = qdesn_ssv2_registry_hash,
  inference_method_id = "M0_v_collapsed_support_logit",
  error_message = if (is.na(error_message) || !nzchar(error_message)) NULL else error_message,
  binary_payloads_remaining = length(binary_remaining)
), status_path)

cat(sprintf("job=%s status=%s objective=%s elapsed_seconds=%.1f\n", job_id, status,
            format(objective_value, digits = 8), elapsed))
quit(save = "no", status = if (status == "SUCCESS") 0L else 1L)

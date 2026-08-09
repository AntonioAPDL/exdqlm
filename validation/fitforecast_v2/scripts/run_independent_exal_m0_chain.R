#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  required <- c("jsonlite", "pkgload")
  missing <- required[!vapply(required, requireNamespace, logical(1L), quietly = TRUE)]
  if (length(missing)) stop(sprintf("Missing packages: %s", paste(missing, collapse = ", ")))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  index <- which(args == flag)
  if (!length(index) || index[[1L]] >= length(args)) return(default)
  args[[index[[1L]] + 1L]]
}

repo_root <- normalizePath(
  get_arg("--repo-root", system("git rev-parse --show-toplevel", intern = TRUE)),
  winslash = "/", mustWork = TRUE
)
setwd(repo_root)
source(file.path(
  repo_root, "validation", "fitforecast_v2", "R",
  "independent_exal_m0_relaunch_v1.R"
))

config_arg <- get_arg("--config")
run_tag <- as.character(get_arg("--run-tag", ""))[1L]
if (is.null(config_arg) || !nzchar(config_arg) || !nzchar(run_tag)) {
  stop("--config and --run-tag are required.", call. = FALSE)
}
config_path <- if (grepl("^/", config_arg)) config_arg else file.path(repo_root, config_arg)
config_path <- normalizePath(config_path, winslash = "/", mustWork = TRUE)
job <- qdesn_m0v1_read_json(config_path)
job_id <- as.character(job$job_id)
job_root <- qdesn_m0v1_job_root(repo_root, run_tag, job_id)
dir.create(job_root, recursive = TRUE, showWarnings = FALSE)
status_path <- file.path(job_root, "job_status.json")
config_sha256 <- qdesn_m0v1_sha256(config_path)

if (file.exists(status_path)) {
  previous <- tryCatch(qdesn_m0v1_read_json(status_path), error = function(e) NULL)
  if (!is.null(previous) && identical(as.character(previous$status), "SUCCESS") &&
      identical(as.character(previous$config_sha256), config_sha256)) {
    cat(sprintf("skip completed job: %s\n", job_id))
    quit(save = "no", status = 0L)
  }
}

observed_path <- as.character(job$observed_path)
if (!grepl("^/", observed_path)) observed_path <- file.path(repo_root, observed_path)
observed_path <- normalizePath(observed_path, winslash = "/", mustWork = TRUE)
if (!identical(qdesn_m0v1_sha256(observed_path), as.character(job$observed_sha256))) {
  stop(sprintf("Frozen observed input hash mismatch for %s.", job_id), call. = FALSE)
}
if (!identical(as.character(job$source_registry_hash_value), qdesn_m0v1_registry_hash) ||
    !identical(as.character(job$config$inference$mcmc$slice$core_update_mode),
               qdesn_m0v1_method_id)) {
  stop(sprintf("M0 or source-registry contract mismatch for %s.", job_id),
       call. = FALSE)
}

started_at <- as.character(Sys.time())
qdesn_m0v1_write_json(list(
  job_id = job_id,
  budget = as.character(job$budget),
  anchor_id = as.character(job$anchor_id),
  chain_id = as.integer(job$chain_id),
  pid = Sys.getpid(),
  host = Sys.info()[["nodename"]],
  started_at = started_at,
  config_path = qdesn_m0v1_rel(config_path, repo_root),
  config_sha256 = config_sha256,
  git_commit = system("git rev-parse HEAD", intern = TRUE)
), file.path(job_root, "job_started.json"))

Sys.setenv(
  OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1", MKL_NUM_THREADS = "1",
  VECLIB_MAXIMUM_THREADS = "1", NUMEXPR_NUM_THREADS = "1",
  RCPP_PARALLEL_NUM_THREADS = "1"
)

pkgload::load_all(repo_root, quiet = TRUE)
# Retention reads pipeline$outputs, while compact rolling-origin export reads
# metrics directly. Keep both views explicit so the storage-light writer can
# emit all article-facing paths before pruning transient objects.
defaults <- list(
  pipeline = list(outputs = job$config$outputs),
  metrics = job$config$metrics,
  source = job$root_spec$source_contract %||% list()
)
fit_request_extra <- list(
  spec_id = as.character(job$spec_id),
  job_id = job_id,
  budget = as.character(job$budget),
  anchor_id = as.character(job$anchor_id),
  chain_id = as.integer(job$chain_id),
  candidate_id = as.character(job$candidate_id),
  execution = list(
    method = "mcmc", likelihood_family = "exal",
    inference_method_id = "M0_v_collapsed_support_logit",
    config_path = qdesn_m0v1_rel(config_path, repo_root),
    config_sha256 = config_sha256,
    launch_commit = system("git rev-parse HEAD", intern = TRUE)
  ),
  study_contract = job$study_contract
)

result <- NULL
error_message <- NA_character_
t0 <- Sys.time()
result <- tryCatch(
  .qdesn_validation_run_one_method(
    method = "mcmc",
    root_spec = job$root_spec,
    defaults = defaults,
    file_long = observed_path,
    method_dir = job_root,
    verbose = TRUE,
    cfg_override = job$config,
    fit_request_extra = fit_request_extra
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
    } else if ("mu" %in% names(source_df)) {
      as.numeric(source_df$mu)
    } else {
      stop("The frozen source contract has no true-quantile column.", call. = FALSE)
    }
    metrics <- .qdesn_static_crossstudy_collect_metrics_from_summary(
      result$summary, q_true_full
    )
    signoff_cfg <- .qdesn_validation_signoff_cfg(defaults)
    meta_names <- c(
      "root_id", "scenario", "tau", "likelihood_family",
      "beta_prior_type", "seed", "reservoir_profile"
    )
    meta_row <- result$health[, meta_names, drop = FALSE]
    signoff <- .qdesn_validation_mcmc_signoff_from_rows(
      meta_row, result$health, result$progress_trace, signoff_cfg$mcmc
    )
    fit_summary <- .qdesn_static_crossstudy_fit_summary_row(
      root_spec = job$root_spec,
      likelihood_family = "exal",
      method = "mcmc",
      health_row = result$health,
      metrics = metrics,
      signoff_row = signoff,
      method_dir = job_root
    )
    fit_summary$spec_id <- as.character(job$spec_id)
    fit_summary$anchor_id <- as.character(job$anchor_id)
    fit_summary$chain_id <- as.integer(job$chain_id)
    fit_summary$candidate_id <- as.character(job$candidate_id)
    fit_summary$inference_method_id <- "M0_v_collapsed_support_logit"
    fit_summary$config_sha256 <- config_sha256
    fit_summary$source_registry_hash_value <- qdesn_m0v1_registry_hash
    qdesn_m0v1_write_csv(signoff, file.path(job_root, "signoff_summary.csv"))
    qdesn_m0v1_write_csv(fit_summary, file.path(job_root, "fit_summary_row.csv"))
    NA_character_
  }, error = function(e) conditionMessage(e))
  if (!is.na(postprocess_error)) {
    error_message <- postprocess_error
    result$status <- "FAIL"
  }
}

finished_at <- as.character(Sys.time())
elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
status <- if (!is.null(result) && identical(as.character(result$status), "SUCCESS")) {
  "SUCCESS"
} else {
  "FAIL"
}
if (is.na(error_message) && !is.null(result)) {
  error_message <- as.character(result$error_message %||% NA_character_)[1L]
}

binary_paths <- list.files(
  job_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
  full.names = TRUE, ignore.case = TRUE
)
if (length(binary_paths)) {
  binary_manifest <- data.frame(
    path = vapply(binary_paths, qdesn_m0v1_rel, character(1L), repo_root = repo_root),
    bytes = as.numeric(file.info(binary_paths)$size),
    sha256 = vapply(binary_paths, qdesn_m0v1_sha256, character(1L)),
    action = "deleted_by_predeclared_storage_light_policy",
    stringsAsFactors = FALSE
  )
  qdesn_m0v1_write_csv(
    binary_manifest, file.path(job_root, "manifest", "binary_prune_manifest.csv")
  )
  unlink(binary_paths, force = TRUE)
}
binary_remaining <- list.files(
  job_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
  full.names = TRUE, ignore.case = TRUE
)
if (length(binary_remaining)) {
  status <- "FAIL"
  error_message <- paste(
    na.omit(c(error_message, "Forbidden binary payload remains after retention.")),
    collapse = "; "
  )
}

qdesn_m0v1_write_json(list(
  job_id = job_id,
  budget = as.character(job$budget),
  anchor_id = as.character(job$anchor_id),
  chain_id = as.integer(job$chain_id),
  candidate_id = as.character(job$candidate_id),
  status = status,
  started_at = started_at,
  finished_at = finished_at,
  elapsed_seconds = elapsed,
  config_path = qdesn_m0v1_rel(config_path, repo_root),
  config_sha256 = config_sha256,
  observed_sha256 = qdesn_m0v1_sha256(observed_path),
  source_registry_hash_value = qdesn_m0v1_registry_hash,
  inference_method_id = "M0_v_collapsed_support_logit",
  error_message = if (is.na(error_message) || !nzchar(error_message)) NULL else error_message,
  binary_payloads_remaining = length(binary_remaining)
), status_path)

cat(sprintf("job=%s status=%s elapsed_seconds=%.1f\n", job_id, status, elapsed))
quit(save = "no", status = if (identical(status, "SUCCESS")) 0L else 1L)

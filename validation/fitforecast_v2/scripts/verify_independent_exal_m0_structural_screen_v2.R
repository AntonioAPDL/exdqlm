#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("jsonlite is required.")
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
stage <- get_arg("--stage", "static")
run_tag <- get_arg("--run-tag", "")
plan_arg <- get_arg("--plan", if (stage %in% c("smoke", "calibration", "wave1")) {
  file.path(materialization_root, paste0(stage, "_plan.csv"))
} else NULL)
output <- normalizePath(get_arg("--output", file.path(materialization_root,
                                                       paste0(stage, "_verification.json"))),
                        winslash = "/", mustWork = FALSE)

manifest_path <- file.path(materialization_root, "materialization_manifest.json")
manifest <- qdesn_ssv2_read_json(manifest_path)
stub <- file.path(repo_root, "config", "validation", qdesn_ssv2_stage)
targets <- qdesn_ssv2_read_csv(paste0(stub, "_target_cells.csv"))
profiles <- qdesn_ssv2_read_csv(paste0(stub, "_wave1_profiles.csv"))
parents <- qdesn_ssv2_read_csv(paste0(stub, "_parent_controls.csv"))
universe <- qdesn_ssv2_read_csv(file.path(materialization_root, "virtual_candidate_universe.csv"))
sources <- qdesn_ssv2_read_csv(file.path(materialization_root, "source_root_registry.csv"))

checks <- c(
  package_version = as.character(read.dcf(file.path(repo_root, "DESCRIPTION"))[1L, "Version"]) == "1.0.0",
  canonical_registry = identical(as.character(manifest$canonical_registry_hash), qdesn_ssv2_registry_hash),
  virtual_size = nrow(universe) == 50000L,
  virtual_unique = !anyDuplicated(universe$profile_signature),
  target_cells = nrow(targets) == 7L,
  wave1_profiles = nrow(profiles) == 96L,
  parent_controls = nrow(parents) == 7L,
  source_roots = nrow(sources) == 45L,
  discovery_sources = length(unique(sources$source_id[sources$source_role == "discovery"])) == 3L,
  sealed_holdout = length(unique(sources$source_id[sources$source_role == "sealed_holdout"])) == 1L,
  reserve_sealed = length(unique(sources$source_id[sources$source_role == "sealed_reserve"])) == 1L,
  no_home_paths = !grepl("/home/jaguir26/local/src", paste(readLines(manifest_path, warn = FALSE), collapse = "\n"), fixed = TRUE)
)

plan_checks <- logical()
runtime <- NULL
if (!is.null(plan_arg)) {
  plan_path <- normalizePath(plan_arg, winslash = "/", mustWork = TRUE)
  plan <- qdesn_ssv2_read_csv(plan_path)
  expected <- switch(stage, smoke = 2L, calibration = 12L, wave1 = 103L,
                     wave2 = 165L, wave3 = 72L, sealed = 76L, NA_integer_)
  config_checks <- lapply(seq_len(nrow(plan)), function(i) {
    job <- qdesn_ssv2_read_json(plan$config_path[[i]])
    D <- as.integer(job$config$desn$D)
    n <- as.integer(job$config$desn$n)
    nt <- as.integer(job$config$desn$n_tilde)
    alpha <- as.numeric(job$config$desn$alpha)
    rho <- as.numeric(job$config$desn$rho)
    pi_w <- as.numeric(job$config$desn$pi_w)
    pi_in <- as.numeric(job$config$desn$pi_in)
    c(
      config_hash = identical(qdesn_ssv2_sha256(plan$config_path[[i]]), plan$config_sha256[[i]]),
      vector_lengths = length(n) == D && length(alpha) == D && length(rho) == D &&
        length(pi_w) == D && length(pi_in) == D && length(nt) == max(0L, D - 1L),
      vector_bounds = all(n >= 4L) && all(alpha > 0 & alpha < 1) &&
        all(rho > 0 & rho < 1) && all(pi_w > 0 & pi_w <= 1) && all(pi_in > 0 & pi_in <= 1),
      m0 = identical(job$config$inference$mcmc$slice$core_update_mode, qdesn_ssv2_method_id),
      one_gamma = identical(as.numeric(job$config$inference$mcmc$slice$width_gamma), 4) &&
        identical(as.integer(job$config$inference$mcmc$slice$core_extra_passes), 0L),
      train_window = identical(as.integer(job$root_spec$train_start_source_index), 8501L) &&
        identical(as.integer(job$root_spec$train_end_source_index), 9000L),
      forecast_window = identical(as.integer(job$root_spec$forecast_start_source_index), 9001L) &&
        identical(as.integer(job$root_spec$forecast_end_source_index), 10000L),
      effective_window = identical(as.integer(job$root_spec$raw_start_source_index) +
        as.integer(job$config$desn$m) + as.integer(job$config$desn$washout), 8501L),
      rolling = identical(as.integer(job$config$metrics$rolling_origin$max_lead_configured), 30L) &&
        identical(as.integer(job$config$metrics$rolling_origin$origin_stride), 30L) &&
        !isTRUE(job$config$metrics$rolling_origin$refit_per_origin),
      observed = file.exists(job$observed_path) &&
        identical(qdesn_ssv2_sha256(job$observed_path), job$observed_sha256),
      storage = !isTRUE(job$config$outputs$keep_draws) &&
        !isTRUE(job$config$outputs$keep_mcmc_vb_init) &&
        !isTRUE(job$config$outputs$save_forecast_objects) &&
        !isTRUE(job$config$outputs$retain_full_rds_on_failure)
    )
  })
  config_matrix <- do.call(rbind, config_checks)
  plan_checks <- c(
    plan_count = nrow(plan) == expected,
    unique_jobs = !anyDuplicated(plan$job_id),
    config_contracts = all(config_matrix)
  )
  if (nzchar(run_tag)) {
    rows <- lapply(seq_len(nrow(plan)), function(i) {
      root <- qdesn_ssv2_job_root(repo_root, run_tag, plan$job_id[[i]])
      status_path <- file.path(root, "job_status.json")
      status <- if (file.exists(status_path)) qdesn_ssv2_read_json(status_path) else list(status = "MISSING")
      binaries <- list.files(root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
                             full.names = TRUE, ignore.case = TRUE)
      data.frame(
        job_id = plan$job_id[[i]], status = as.character(status$status %||% "MISSING"),
        objective_value = qdesn_ssv2_metric_value(root, plan$objective_metric[[i]]),
        fit_exists = file.exists(file.path(root, "fit_summary_row.csv")),
        forecast_exists = file.exists(file.path(root, "tables", "forecast_horizon_summary.csv")),
        binary_count = length(binaries),
        elapsed_seconds = as.numeric(status$elapsed_seconds %||% NA_real_),
        stringsAsFactors = FALSE
      )
    })
    runtime <- do.call(rbind, rows)
    runtime_path <- sub("[.]json$", "_runtime.csv", output)
    qdesn_ssv2_write_csv(runtime, runtime_path)
    plan_checks <- c(plan_checks,
      runtime_success = all(runtime$status == "SUCCESS"),
      runtime_finite = all(is.finite(runtime$objective_value)),
      runtime_artifacts = all(runtime$fit_exists & runtime$forecast_exists),
      runtime_storage = all(runtime$binary_count == 0L)
    )
  }
}

decision <- if (all(checks) && all(plan_checks)) "PASS" else "FAIL"
qdesn_ssv2_write_json(list(
  generated_at = as.character(Sys.time()), stage = stage, run_tag = if (nzchar(run_tag)) run_tag else NULL,
  static_checks = as.list(checks), plan_checks = as.list(plan_checks),
  runtime_summary = if (is.null(runtime)) NULL else list(
    expected = nrow(runtime), success = sum(runtime$status == "SUCCESS"),
    finite = sum(is.finite(runtime$objective_value)), binaries = sum(runtime$binary_count),
    median_elapsed_seconds = stats::median(runtime$elapsed_seconds, na.rm = TRUE),
    maximum_elapsed_seconds = max(runtime$elapsed_seconds, na.rm = TRUE)
  ),
  decision = decision
), output)
cat(sprintf("stage=%s decision=%s\n", stage, decision))
if (decision != "PASS") stop("Structural-screen verification failed.", call. = FALSE)

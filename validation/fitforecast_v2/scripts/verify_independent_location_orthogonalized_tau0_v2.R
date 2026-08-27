#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Missing jsonlite")
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
mat <- normalizePath(arg("--materialization-root"), winslash = "/", mustWork = TRUE)
stage <- arg("--stage", "static")
output <- normalizePath(
  arg("--output", file.path(mat, paste0(stage, "_verification.json"))),
  winslash = "/", mustWork = FALSE
)
targets <- idol_v2_read_targets(repo)
arms <- idol_v2_read_arms(repo)
ladder <- idol_v2_read_ladder(repo)
candidates <- qdesn_ssv2_read_csv(file.path(mat, "candidate_profiles.csv"))
nonrepeat <- qdesn_ssv2_read_csv(file.path(mat, "candidate_nonrepeat_audit.csv"))
registry <- qdesn_ssv2_read_csv(file.path(mat, "canonical_source_registry.csv"))
overlap <- qdesn_ssv2_read_csv(file.path(mat, "full_source_overlap_audit.csv"))
manifest <- qdesn_ssv2_read_json(file.path(mat, "materialization_manifest.json"))
base_plan_names <- c("smoke", "initial_replication", "screen")
base_plans <- lapply(base_plan_names, function(name) {
  qdesn_ssv2_read_csv(file.path(mat, paste0(name, "_plan.csv")))
})
names(base_plans) <- base_plan_names
base_config_paths <- unlist(lapply(base_plans, `[[`, "config_path"), use.names = FALSE)
jobs <- lapply(base_config_paths, qdesn_ssv2_read_json)
job_checks <- lapply(jobs, function(job) {
  likelihood <- as.character(job$likelihood_target)
  method <- if (likelihood == "exal") qdesn_ssv2_method_id else "sigma_then_gamma"
  transform <- .qdesn_readout_transform_spec(job$config$readout$linear_transform)
  interval <- job$config$metrics$posterior_metric_intervals
  c(
    schema = identical(as.character(job$schema_version), idol_v2_schema),
    fit_window = identical(as.integer(job$study_contract$train_window),
                           c(8501L, 9000L)),
    forecast_window = identical(as.integer(job$study_contract$forecast_window),
                                c(9001L, 10000L)),
    lead = identical(as.integer(job$study_contract$max_lead), 30L),
    stride = identical(as.integer(job$study_contract$origin_stride), 30L),
    method = identical(
      as.character(job$config$inference$mcmc$slice$core_update_mode), method
    ),
    tau0 = is.finite(as.numeric(job$profile$rhs_tau0)) &&
      as.numeric(job$profile$rhs_tau0) > 0,
    transform = identical(transform$mode,
                          as.character(job$profile$transform_mode)),
    train_only = isTRUE(job$study_contract$readout_transform_training_only),
    recursive_contract =
      isTRUE(job$study_contract$readout_transform_forecast_consistent),
    intervals = isTRUE(interval$enabled) && isTRUE(interval$required),
    attribution = isTRUE(interval$origin_horizon_attribution$enabled) &&
      isTRUE(interval$origin_horizon_attribution$required),
    no_refit = !isTRUE(job$config$metrics$rolling_origin$refit_per_origin),
    one_thread = identical(as.integer(job$config$cpp$postpred_threads), 1L),
    r_recursion = !isTRUE(job$config$cpp$use_postpred),
    storage = !isTRUE(job$config$outputs$keep_draws) &&
      !isTRUE(job$config$outputs$keep_mcmc_vb_init) &&
      !isTRUE(job$config$outputs$retain_full_rds_on_failure),
    no_prior_recycling = !isTRUE(job$study_contract$posterior_recycled_as_prior)
  )
})
job_check_matrix <- do.call(rbind, job_checks)
checks <- c(
  authorities = nrow(idlc_v1_assert_authorities(repo)) == 4L,
  targets = nrow(targets) == 3L,
  arms = nrow(arms) == 3L,
  ladders = nrow(ladder) == 15L && all(table(ladder$target_cell_id) == 5L),
  candidates = nrow(candidates) == 33L &&
    all(table(candidates$target_cell_id) == 11L),
  candidate_identity = !anyDuplicated(candidates$candidate_id) &&
    !anyDuplicated(candidates$exact_signature),
  arm_crossing = sum(candidates$selection_arm == "C0_parent") == 3L &&
    sum(candidates$selection_arm == "O1_orthogonalized") == 15L &&
    sum(candidates$selection_arm == "O2_orthogonalized_svd") == 15L,
  nonrepeat = nrow(nonrepeat) == 33L && all(nonrepeat$decision == "PASS"),
  source_contract = nrow(registry) == 3L,
  source_overlap = nrow(overlap) == 3L &&
    all(overlap$overlap_status == "PASS") && all(overlap$master_rows == 10000L),
  plans = nrow(base_plans$smoke) == 2L &&
    nrow(base_plans$initial_replication) == 4L &&
    nrow(base_plans$screen) == 33L,
  config_identity = length(base_config_paths) == 39L &&
    !anyDuplicated(base_config_paths) && all(file.exists(base_config_paths)),
  job_contracts = all(job_check_matrix),
  manifest = manifest$target_cells == 3L &&
    manifest$candidate_profiles == 33L && manifest$screen_jobs == 33L,
  branch = identical(system("git branch --show-current", intern = TRUE),
                     idol_v2_branch)
)

runtime <- NULL
if (stage != "static") {
  plan <- qdesn_ssv2_read_csv(normalizePath(
    arg("--plan"), winslash = "/", mustWork = TRUE
  ))
  run_tag <- arg("--run-tag")
  if (nrow(plan)) {
    runtime <- do.call(rbind, lapply(seq_len(nrow(plan)), function(i) {
      row <- plan[i, , drop = FALSE]
      result <- idol_v2_collect_result(repo, run_tag, row)
      root <- idol_v2_job_root(repo, run_tag, row$job_id[[1L]])
      diagnostics <- idol_v2_required_diagnostic_paths(root)
      reconstruction <- file.path(
        root, "tables", "origin_horizon_reconstruction_audit.csv"
      )
      reconstruction_ok <- FALSE
      if (file.exists(reconstruction)) {
        x <- tryCatch(qdesn_ssv2_read_csv(reconstruction), error = function(e) NULL)
        reconstruction_ok <- !is.null(x) && nrow(x) > 0L && all(x$pass) &&
          max(x$forecast_mae_max_abs_error,
              x$forecast_check_max_abs_error, na.rm = TRUE) <=
            idol_v2_reconstruction_tolerance
      }
      result$finite_target_metrics <- all(is.finite(as.numeric(
        result[1L, strsplit(row$target_metrics[[1L]], ";", fixed = TRUE)[[1L]]]
      )))
      result$diagnostics_complete <- all(file.exists(diagnostics))
      result$reconstruction_pass <- reconstruction_ok
      result
    }))
    checks <- c(
      checks, runtime_rows = nrow(runtime) == nrow(plan),
      runtime_success = all(runtime$status == "SUCCESS"),
      runtime_metrics = all(runtime$finite_target_metrics),
      runtime_diagnostics = all(runtime$diagnostics_complete),
      runtime_reconstruction = all(runtime$reconstruction_pass),
      runtime_storage = all(runtime$binary_payloads_remaining == 0L)
    )
    qdesn_ssv2_write_csv(runtime, sub("[.]json$", "_runtime.csv", output))
  } else {
    checks <- c(checks, empty_adaptive_stage = TRUE)
  }
}
materialization_binaries <- list.files(
  mat, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
  full.names = TRUE, ignore.case = TRUE
)
checks <- c(checks, materialization_storage = !length(materialization_binaries))
result <- list(
  schema_version = "independent_location_orthogonalized_tau0_v2_verification_v1",
  generated_at = as.character(Sys.time()), stage = stage,
  decision = if (all(checks)) "PASS" else "FAIL",
  checks = as.list(checks), runtime_rows = if (is.null(runtime)) 0L else nrow(runtime),
  forbidden_payloads = as.list(materialization_binaries)
)
qdesn_ssv2_write_json(result, output)
cat(sprintf("VERIFY_%s checks=%d stage=%s output=%s\n",
            result$decision, length(checks), stage, output))
if (!all(checks)) {
  stop("Failed: ", paste(names(checks)[!checks], collapse = ", "), call. = FALSE)
}

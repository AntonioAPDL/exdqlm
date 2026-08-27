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
source(file.path(
  repo, "validation", "fitforecast_v2", "R",
  "independent_dynamic_location_capacity_tau0_v1.R"
))
mat <- normalizePath(arg("--materialization-root"), winslash = "/", mustWork = TRUE)
stage <- arg("--stage", "static")
output <- normalizePath(
  arg("--output", file.path(mat, paste0(stage, "_verification.json"))),
  winslash = "/", mustWork = FALSE
)
targets <- idlc_v1_read_targets(repo)
ladder <- idlc_v1_read_tau0_ladder(repo)
candidates <- qdesn_ssv2_read_csv(file.path(mat, "candidate_profiles.csv"))
nonrepeat <- qdesn_ssv2_read_csv(file.path(mat, "candidate_nonrepeat_audit.csv"))
registry <- qdesn_ssv2_read_csv(file.path(mat, "canonical_source_registry.csv"))
overlap <- qdesn_ssv2_read_csv(file.path(mat, "full_source_overlap_audit.csv"))
manifest <- qdesn_ssv2_read_json(file.path(mat, "materialization_manifest.json"))
smoke_plan <- qdesn_ssv2_read_csv(file.path(mat, "smoke_plan.csv"))
screen_plan <- qdesn_ssv2_read_csv(file.path(mat, "screen_plan.csv"))
plans <- list(smoke = smoke_plan, screen = screen_plan)
config_paths <- c(smoke_plan$config_path, screen_plan$config_path)
jobs <- lapply(config_paths, qdesn_ssv2_read_json)
job_checks <- lapply(jobs, function(job) {
  likelihood <- as.character(job$likelihood_target)
  method <- if (likelihood == "exal") qdesn_ssv2_method_id else "sigma_then_gamma"
  dimension <- qdesn_ssv2_effective_readout_dimension(
    job$config$desn$n, job$config$desn$n_tilde,
    job$config$readout$reservoir_lags, job$config$lags$m_y
  )
  interval <- job$config$metrics$posterior_metric_intervals
  c(
    schema = identical(as.character(job$schema_version), idlc_v1_schema),
    fit_window = identical(as.integer(job$study_contract$train_window),
                           c(8501L, 9000L)),
    forecast_window = identical(as.integer(job$study_contract$forecast_window),
                                c(9001L, 10000L)),
    lead = identical(as.integer(job$study_contract$max_lead), 30L),
    stride = identical(as.integer(job$study_contract$origin_stride), 30L),
    method = identical(
      as.character(job$config$inference$mcmc$slice$core_update_mode), method
    ),
    capacity = dimension <= idlc_v1_max_effective_dimension &&
      identical(as.integer(job$root_spec$effective_readout_dimension), dimension),
    tau0 = is.finite(as.numeric(job$profile$rhs_tau0)) &&
      as.numeric(job$profile$rhs_tau0) >= 1e-9,
    topology = all(qdesn_ssv2_vec(job$profile$pi_w, "numeric") > 0) &&
      all(qdesn_ssv2_vec(job$profile$pi_in, "numeric") > 0),
    intervals = isTRUE(interval$enabled) && isTRUE(interval$required),
    attribution = isTRUE(interval$origin_horizon_attribution$enabled) &&
      isTRUE(interval$origin_horizon_attribution$required),
    common_shift = isTRUE(interval$common_shift_intervention$enabled) &&
      isTRUE(interval$common_shift_intervention$required),
    no_refit = !isTRUE(job$config$metrics$rolling_origin$refit_per_origin),
    threads = identical(as.integer(job$config$cpp$postpred_threads), 1L),
    storage = !isTRUE(job$config$outputs$keep_draws) &&
      !isTRUE(job$config$outputs$keep_mcmc_vb_init) &&
      !isTRUE(job$config$outputs$retain_full_rds_on_failure),
    no_prior_recycling = !isTRUE(job$study_contract$posterior_recycled_as_prior)
  )
})
job_check_matrix <- do.call(rbind, job_checks)
source_checks <- vapply(seq_len(nrow(registry)), function(i) {
  file.exists(registry$series_wide_path[[i]]) &&
    identical(qdesn_ssv2_sha256(registry$series_wide_path[[i]]),
              registry$series_wide_sha256[[i]]) &&
    file.exists(registry$parent_request_path[[i]]) &&
    identical(qdesn_ssv2_sha256(registry$parent_request_path[[i]]),
              registry$parent_request_sha256[[i]])
}, logical(1L))
checks <- c(
  authorities = nrow(idlc_v1_assert_authorities(repo)) == 4L,
  targets = nrow(targets) == 4L,
  ladders = nrow(ladder) == 16L && all(table(ladder$target_cell_id) == 4L),
  candidates = nrow(candidates) == 64L &&
    all(table(candidates$target_cell_id) == 16L),
  architecture_crossing = all(table(
    paste(candidates$target_cell_id, candidates$selection_arm)
  ) == 4L),
  candidate_identity = !anyDuplicated(candidates$candidate_id) &&
    !anyDuplicated(candidates$exact_signature),
  nonrepeat = nrow(nonrepeat) == 64L && all(nonrepeat$decision == "PASS"),
  capacity = max(candidates$effective_readout_dimension) <=
    idlc_v1_max_effective_dimension,
  high_persistence = all(vapply(
    split(candidates, candidates$target_cell_id),
    function(x) any(x$max_alpha >= .70 & x$max_rho >= .90), logical(1L)
  )),
  compact_control = all(vapply(
    split(candidates, candidates$target_cell_id),
    function(x) any(x$selection_arm == "P1_compact_persistent"), logical(1L)
  )),
  source_contract = nrow(registry) == 4L && all(source_checks),
  source_overlap = nrow(overlap) == 4L && all(overlap$master_rows == 10000L) &&
    all(overlap$overlap_rows == 1890L) && all(overlap$overlap_status == "PASS"),
  plans = nrow(smoke_plan) == 2L && nrow(screen_plan) == 64L,
  config_identity = length(config_paths) == 66L && !anyDuplicated(config_paths) &&
    all(file.exists(config_paths)),
  job_contracts = all(job_check_matrix),
  manifest = manifest$target_cells == 4L && manifest$candidate_profiles == 64L &&
    manifest$screen_jobs == 64L,
  branch = identical(system("git branch --show-current", intern = TRUE),
                     idlc_v1_branch)
)

runtime <- NULL
if (stage != "static") {
  plan_path <- normalizePath(arg("--plan"), winslash = "/", mustWork = TRUE)
  plan <- qdesn_ssv2_read_csv(plan_path)
  run_tag <- arg("--run-tag")
  runtime <- do.call(rbind, lapply(seq_len(nrow(plan)), function(i) {
    row <- plan[i, , drop = FALSE]
    result <- idlc_v1_collect_result(repo, run_tag, row)
    root <- idlc_v1_job_root(repo, run_tag, row$job_id[[1L]])
    diagnostics <- c(
      idlc_v1_required_diagnostic_paths(root),
      file.path(root, "tables", "design_conditioning_diagnostics.csv")
    )
    reconstruction <- file.path(
      root, "tables", "origin_horizon_reconstruction_audit.csv"
    )
    reconstruction_ok <- FALSE
    if (file.exists(reconstruction)) {
      x <- tryCatch(qdesn_ssv2_read_csv(reconstruction), error = function(e) NULL)
      reconstruction_ok <- !is.null(x) && nrow(x) > 0L && all(x$pass) &&
        max(x$forecast_mae_max_abs_error,
            x$forecast_check_max_abs_error, na.rm = TRUE) <=
          idlc_v1_reconstruction_tolerance
    }
    result$finite_target_metrics <- all(is.finite(as.numeric(
      result[1L, strsplit(row$target_metrics[[1L]], ";", fixed = TRUE)[[1L]]]
    )))
    result$diagnostics_complete <- all(file.exists(diagnostics))
    result$reconstruction_pass <- reconstruction_ok
    result
  }))
  checks <- c(
    checks,
    runtime_rows = nrow(runtime) == nrow(plan),
    runtime_success = all(runtime$status == "SUCCESS"),
    runtime_metrics = all(runtime$finite_target_metrics),
    runtime_diagnostics = all(runtime$diagnostics_complete),
    runtime_reconstruction = all(runtime$reconstruction_pass),
    runtime_storage = all(runtime$binary_payloads_remaining == 0L)
  )
  qdesn_ssv2_write_csv(runtime, sub("[.]json$", "_runtime.csv", output))
}
materialization_binaries <- list.files(
  mat, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
  full.names = TRUE, ignore.case = TRUE
)
checks <- c(checks, materialization_storage = !length(materialization_binaries))
result <- list(
  schema_version = "independent_dynamic_location_capacity_tau0_v1_verification_v1",
  generated_at = as.character(Sys.time()), stage = stage,
  decision = if (all(checks)) "PASS" else "FAIL",
  checks = as.list(checks), runtime_rows = if (is.null(runtime)) 0L else nrow(runtime),
  forbidden_payloads = as.list(materialization_binaries)
)
qdesn_ssv2_write_json(result, output)
cat(sprintf("VERIFY_%s checks=%d output=%s\n",
            result$decision, length(checks), output))
if (!all(checks)) {
  stop("Failed: ", paste(names(checks)[!checks], collapse = ", "), call. = FALSE)
}

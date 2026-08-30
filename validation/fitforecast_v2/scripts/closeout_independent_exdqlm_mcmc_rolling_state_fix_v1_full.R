#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/closeout_independent_exdqlm_mcmc_rolling_state_fix_v1_full.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/",
                           mustWork = TRUE)
manifest_path <- normalizePath(args$manifest %||% "", winslash = "/", mustWork = TRUE)
run_root <- dirname(dirname(manifest_path))
closeout_root <- ffv2_resolve_path(
  args$`output-root` %||% file.path(run_root, "closeout"),
  repo_root = repo_root, must_work = FALSE
)
ffv2_ensure_dir(closeout_root)

manifest <- ffv2_read_csv(manifest_path)
materialization_path <- file.path(run_root, "manifests", "materialization_manifest.json")
materialization <- ffv2_read_json(materialization_path)
branch <- system2("git", c("-C", repo_root, "branch", "--show-current"), stdout = TRUE)
head <- system2("git", c("-C", repo_root, "rev-parse", "HEAD"), stdout = TRUE)
if (!identical(as.character(materialization$schema_version), iems_v1_schema) ||
    !identical(as.character(materialization$mode), "full") ||
    !identical(as.integer(materialization$jobs), iems_v1_expected_full_jobs)) {
  stop("Full closeout requires the frozen 27-job materialization.", call. = FALSE)
}
materialization_contract <- c(
  branch = identical(branch, iems_v1_expected_branch) &&
    identical(as.character(materialization$branch), branch),
  head = identical(as.character(materialization$head), head),
  package_version = identical(
    as.character(materialization$package_version), iems_v1_cran_version
  ),
  package_repository = identical(as.character(materialization$package_repository), "CRAN"),
  cran_tarball = identical(
    as.character(materialization$cran_tarball_sha256), iems_v1_cran_tarball_sha256
  ),
  state_method = identical(
    as.character(materialization$state_update_method),
    ffv2_exdqlm_mcmc_predictive_state_update_method()
  ),
  threads = identical(as.integer(materialization$numerical_threads_per_job), 1L),
  article_write_false = isFALSE(materialization$article_write_performed),
  shared_write_false = isFALSE(materialization$shared_validation_write_performed)
)
if (!all(materialization_contract)) {
  stop(sprintf(
    "Frozen materialization contract failed: %s",
    paste(names(materialization_contract)[!materialization_contract], collapse = ", ")
  ), call. = FALSE)
}
if (!identical(ffv2_file_sha256(manifest_path),
               as.character(materialization$manifest_sha256))) {
  stop("The full job manifest changed after materialization.", call. = FALSE)
}
materialization_hashes <- c(
  preflight_report = file.exists(materialization$preflight_report_path) &&
    identical(
      ffv2_file_sha256(materialization$preflight_report_path),
      as.character(materialization$preflight_report_sha256)
    ),
  source_job_audit = file.exists(materialization$source_job_audit_path) &&
    identical(
      ffv2_file_sha256(materialization$source_job_audit_path),
      as.character(materialization$source_job_audit_sha256)
    )
)
if (!all(materialization_hashes)) {
  stop(sprintf(
    "Frozen materialization evidence failed: %s",
    paste(names(materialization_hashes)[!materialization_hashes], collapse = ", ")
  ), call. = FALSE)
}

sentinel_root <- iems_v1_results_root(repo_root, iems_v1_sentinel_run_id)
sentinel_closeout_path <- file.path(sentinel_root, "closeout", "closeout.json")
sentinel <- ffv2_read_json(sentinel_closeout_path)
sentinel_comparison <- as.character(sentinel$comparison_path)
sentinel_checks <- as.character(sentinel$checks_path)
sentinel_ok <- identical(
  as.character(sentinel$decision),
  "SENTINEL_PASS_PROCEED_TO_FULL_27_JOB_CONFIRMATION"
) && identical(ffv2_file_sha256(sentinel_comparison),
               as.character(sentinel$comparison_sha256)) &&
  identical(ffv2_file_sha256(sentinel_checks), as.character(sentinel$checks_sha256))
if (!sentinel_ok) {
  stop("The immutable sentinel gate is absent or no longer verifies.", call. = FALSE)
}

numeric_or_na <- function(x) {
  value <- suppressWarnings(as.numeric(x %||% NA_real_)[1L])
  if (is.finite(value)) value else NA_real_
}

chain_rows <- vector("list", nrow(manifest))
diagnostic_rows <- vector("list", nrow(manifest))
all_draws <- vector("list", nrow(manifest))
all_leads <- vector("list", nrow(manifest))
all_forecasts <- vector("list", nrow(manifest))
for (i in seq_len(nrow(manifest))) {
  config <- ffv2_read_json(manifest$row_config_path[[i]])
  if (!identical(ffv2_file_sha256(manifest$row_config_path[[i]]),
                 as.character(manifest$row_config_sha256[[i]]))) {
    stop(sprintf("Generated config hash changed: %s", manifest$row_key[[i]]),
         call. = FALSE)
  }
  if (!identical(ffv2_file_sha256(config$source_config_path),
                 as.character(config$source_config_sha256))) {
    stop(sprintf("Frozen source config hash changed: %s", manifest$row_key[[i]]),
         call. = FALSE)
  }
  if (!file.exists(config$row_status_path)) {
    stop(sprintf("Incomplete full-confirmation row: %s", manifest$source_job_id[[i]]),
         call. = FALSE)
  }
  status <- ffv2_read_csv(config$row_status_path)
  status <- status[nrow(status), , drop = FALSE]
  if (!identical(as.character(status$status[[1L]]), "done")) {
    stop(sprintf("Incomplete full-confirmation row: %s", manifest$source_job_id[[i]]),
         call. = FALSE)
  }
  artifact_audit <- iems_v1_verify_row_artifacts(config, manifest$row_key[[i]])

  current <- ffv2_read_csv(config$row_metrics_path)
  historical_config <- ffv2_read_json(config$source_config_path)
  historical <- ffv2_read_csv(historical_config$row_metrics_path)
  current_path <- ffv2_read_csv(config$forecast_path_summary_path)
  historical_path <- ffv2_read_csv(historical_config$forecast_path_summary_path)
  current_first <- current_path[current_path$origin_sequence_id == 1L, , drop = FALSE]
  historical_first <- historical_path[
    historical_path$origin_sequence_id == 1L, , drop = FALSE
  ]
  inference_diagnostics <- ffv2_read_json(config$inference_diagnostics_path)
  health <- ffv2_read_csv(config$row_health_path)
  state_methods <- unique(as.character(current_path$state_update_method))
  if (length(state_methods) != 1L) {
    stop(sprintf("Ambiguous state-update method: %s", manifest$row_key[[i]]),
         call. = FALSE)
  }
  row_draws <- ffv2_read_csv(config$metric_draws_path)
  row_draws$chain_id <- as.integer(config$chain_id)
  all_draws[[i]] <- transform(
    row_draws, family = as.character(config$family), tau = as.numeric(config$tau)
  )
  all_leads[[i]] <- transform(
    ffv2_read_csv(config$forecast_lead_metrics_path),
    family = as.character(config$family), tau = as.numeric(config$tau),
    chain_id = as.integer(config$chain_id)
  )
  all_forecasts[[i]] <- transform(
    current_path, family = as.character(config$family), tau = as.numeric(config$tau),
    chain_id = as.integer(config$chain_id)
  )

  chain_rows[[i]] <- data.frame(
    source_job_id = as.character(manifest$source_job_id[[i]]),
    row_id = as.integer(config$row_id), row_key = as.character(config$row_key),
    family = as.character(config$family), tau = as.numeric(config$tau),
    chain_id = as.integer(config$chain_id), seed = as.integer(config$seed),
    status = as.character(status$status[[1L]]),
    health_gate = as.character(health$gate[[1L]]),
    historical_fit_rmse = as.numeric(historical$fit_q_rmse[[1L]]),
    corrected_fit_rmse = as.numeric(current$fit_q_rmse[[1L]]),
    fit_rmse_change = as.numeric(current$fit_q_rmse[[1L]] - historical$fit_q_rmse[[1L]]),
    historical_forecast_mae = as.numeric(historical$forecast_h1000_q_mae[[1L]]),
    corrected_forecast_mae = as.numeric(current$forecast_h1000_q_mae[[1L]]),
    forecast_mae_change = as.numeric(
      current$forecast_h1000_q_mae[[1L]] - historical$forecast_h1000_q_mae[[1L]]
    ),
    forecast_mae_ratio = as.numeric(
      current$forecast_h1000_q_mae[[1L]] / historical$forecast_h1000_q_mae[[1L]]
    ),
    historical_forecast_check = as.numeric(
      historical$forecast_h1000_pinball_mean[[1L]]
    ),
    corrected_forecast_check = as.numeric(current$forecast_h1000_pinball_mean[[1L]]),
    forecast_check_change = as.numeric(
      current$forecast_h1000_pinball_mean[[1L]] -
        historical$forecast_h1000_pinball_mean[[1L]]
    ),
    historical_first_origin_mae = mean(historical_first$abs_q_error),
    corrected_first_origin_mae = mean(current_first$abs_q_error),
    first_origin_mae_change = mean(current_first$abs_q_error) -
      mean(historical_first$abs_q_error),
    state_update_method = state_methods[[1L]],
    package_version = as.character(config$package_contract$version),
    package_repository = as.character(config$package_contract$authority),
    requested_mh_proposal = as.character(
      inference_diagnostics$requested_mh_proposal %||% NA_character_
    ),
    observed_mh_proposal = as.character(
      inference_diagnostics$observed_mh_proposal %||% NA_character_
    ),
    gamma_mean = numeric_or_na(inference_diagnostics$gamma$mean),
    gamma_sd = numeric_or_na(inference_diagnostics$gamma$sd),
    gamma_ess = numeric_or_na(inference_diagnostics$gamma$ess),
    gamma_acf1 = numeric_or_na(inference_diagnostics$gamma$acf1),
    sigma_mean = numeric_or_na(inference_diagnostics$sigma$mean),
    sigma_sd = numeric_or_na(inference_diagnostics$sigma$sd),
    sigma_ess = numeric_or_na(inference_diagnostics$sigma$ess),
    sigma_acf1 = numeric_or_na(inference_diagnostics$sigma$acf1),
    fit_rows = nrow(ffv2_read_csv(config$fit_path_summary_path)),
    forecast_rows = nrow(current_path),
    forecast_origins = length(unique(current_path$forecast_origin_source_index)),
    forecast_max_lead = max(current_path$forecast_lead),
    metric_draws = nrow(row_draws), runtime_sec = as.numeric(status$runtime_sec[[1L]]),
    row_config_path = normalizePath(
      manifest$row_config_path[[i]], winslash = "/", mustWork = TRUE
    ),
    row_config_sha256 = ffv2_file_sha256(manifest$row_config_path[[i]]),
    row_metrics_path = normalizePath(config$row_metrics_path, winslash = "/",
                                     mustWork = TRUE),
    row_metrics_sha256 = ffv2_file_sha256(config$row_metrics_path),
    metric_draws_path = normalizePath(config$metric_draws_path, winslash = "/",
                                      mustWork = TRUE),
    metric_draws_sha256 = ffv2_file_sha256(config$metric_draws_path),
    inference_diagnostics_path = artifact_audit$inference_diagnostics_path,
    inference_diagnostics_sha256 = artifact_audit$inference_diagnostics_sha256,
    artifact_manifest_path = artifact_audit$artifact_manifest_path,
    artifact_manifest_sha256 = artifact_audit$artifact_manifest_sha256,
    stringsAsFactors = FALSE
  )
  diagnostic_rows[[i]] <- chain_rows[[i]][c(
    "source_job_id", "family", "tau", "chain_id", "health_gate",
    "requested_mh_proposal", "observed_mh_proposal", "gamma_mean", "gamma_sd",
    "gamma_ess", "gamma_acf1", "sigma_mean", "sigma_sd", "sigma_ess",
    "sigma_acf1"
  )]
}

chain_summary <- ffv2_bind_rows(chain_rows)
chain_summary <- chain_summary[order(
  chain_summary$family, chain_summary$tau, chain_summary$chain_id
), , drop = FALSE]
cell_summary <- iems_v1_full_cell_summary(chain_summary)
draws <- ffv2_bind_rows(all_draws)
leads <- ffv2_bind_rows(all_leads)
forecasts <- ffv2_bind_rows(all_forecasts)

cell_keys <- unique(paste(draws$family, sprintf("%.2f", draws$tau), sep = "|"))
interval_rows <- vector("list", length(cell_keys))
metric_diagnostic_rows <- vector("list", length(cell_keys))
for (i in seq_along(cell_keys)) {
  key <- cell_keys[[i]]
  index <- paste(draws$family, sprintf("%.2f", draws$tau), sep = "|") == key
  x <- draws[index, , drop = FALSE]
  interval_rows[[i]] <- cbind(data.frame(
    family = as.character(x$family[[1L]]), tau = as.numeric(x$tau[[1L]]),
    stringsAsFactors = FALSE
  ), ffv2_metric_interval_summary(x, inference = "mcmc"))
  d <- tryCatch(ffv2_metric_chain_diagnostics(x), error = function(e) {
    data.frame(
      metric = names(iems_v1_point_metric_columns), chains = 3L,
      draws_per_chain = NA_integer_, split_rhat = NA_real_, bulk_ess = NA_real_,
      tail_ess = NA_real_, mcse_mean = NA_real_,
      mcse_fraction_interval_width = NA_real_,
      endpoint_max_range_pooled_sd = NA_real_, interval_overlap_min = NA_real_,
      diagnostic_error = conditionMessage(e), stringsAsFactors = FALSE
    )
  })
  if (!"diagnostic_error" %in% names(d)) d$diagnostic_error <- ""
  diagnostic_pass <-
    is.finite(d$split_rhat) & d$split_rhat <= 1.05 &
      is.finite(d$bulk_ess) & d$bulk_ess >= 400 &
      is.finite(d$tail_ess) & d$tail_ess >= 200 &
      is.finite(d$mcse_fraction_interval_width) &
      d$mcse_fraction_interval_width <= 0.05 &
      is.finite(d$endpoint_max_range_pooled_sd) &
      d$endpoint_max_range_pooled_sd <= 0.50
  d$diagnostic_grade <- ifelse(!is.na(diagnostic_pass) & diagnostic_pass,
                               "PASS", "WARN")
  metric_diagnostic_rows[[i]] <- cbind(data.frame(
    family = as.character(x$family[[1L]]), tau = as.numeric(x$tau[[1L]]),
    stringsAsFactors = FALSE
  ), d)
}
pooled_intervals <- ffv2_bind_rows(interval_rows)
pooled_intervals <- pooled_intervals[order(
  pooled_intervals$family, pooled_intervals$tau, pooled_intervals$metric
), , drop = FALSE]
metric_diagnostics <- ffv2_bind_rows(metric_diagnostic_rows)

profile_summary <- function(data, group_fields, metric_fields) {
  key <- do.call(paste, c(data[group_fields], sep = "\r"))
  groups <- split(seq_len(nrow(data)), key)
  ffv2_bind_rows(lapply(groups, function(index) {
    x <- data[index, , drop = FALSE]
    out <- x[1L, group_fields, drop = FALSE]
    for (field in metric_fields) {
      value <- as.numeric(x[[field]])
      out[[paste0(field, "_mean")]] <- mean(value)
      out[[paste0(field, "_sd")]] <- if (length(value) > 1L) stats::sd(value) else 0
    }
    out$n_chains <- length(unique(x$chain_id))
    out
  }))
}

lead_profiles <- profile_summary(
  leads,
  c("family", "tau", "forecast_lead"),
  c("forecast_qtrue_mae", "forecast_pinball_mean")
)
origin_chain <- stats::aggregate(
  forecasts[c("abs_q_error", "pinball_tau")],
  by = forecasts[c("family", "tau", "chain_id", "forecast_origin_source_index")],
  FUN = mean
)
origin_profiles <- profile_summary(
  origin_chain,
  c("family", "tau", "forecast_origin_source_index"),
  c("abs_q_error", "pinball_tau")
)
origin_lead_profiles <- profile_summary(
  forecasts,
  c("family", "tau", "forecast_origin_source_index", "forecast_lead"),
  c("abs_q_error", "pinball_tau")
)

metric_role <- c(
  fit_rmse = "fit", forecast_mae = "forecast_mae",
  forecast_check_loss = "forecast_check"
)
interval_candidate <- pooled_intervals
interval_candidate$metric_role <- unname(metric_role[interval_candidate$metric])
point_lookup <- setNames(seq_len(nrow(cell_summary)), paste(
  cell_summary$family, sprintf("%.2f", cell_summary$tau), sep = "|"
))
interval_index <- unname(point_lookup[paste(
  interval_candidate$family, sprintf("%.2f", interval_candidate$tau), sep = "|"
)])
point_column <- c(
  fit_rmse = "corrected_fit_rmse", forecast_mae = "corrected_forecast_mae",
  forecast_check_loss = "corrected_forecast_check"
)
interval_candidate$authoritative_value <- vapply(seq_len(nrow(interval_candidate)),
  function(i) cell_summary[[point_column[[interval_candidate$metric[[i]]]]]][
    interval_index[[i]]
  ], numeric(1L))
interval_candidate$model_variant <- "exdqlm"
interval_candidate$model_label <- "exDQLM"
interval_candidate$inference <- "mcmc"
interval_candidate$package_version <- iems_v1_cran_version
interval_candidate$state_update_method <-
  ffv2_exdqlm_mcmc_predictive_state_update_method()

point_candidate <- cell_summary
point_candidate$inference <- "mcmc"
point_candidate$model_variant <- "exdqlm"
point_candidate$model_label <- "exDQLM"
point_candidate$fit_qtrue_rmse <- point_candidate$corrected_fit_rmse
point_candidate$forecast_qtrue_mae_H1000 <- point_candidate$corrected_forecast_mae
point_candidate$forecast_check_loss_H1000 <- point_candidate$corrected_forecast_check
point_candidate$metric_estimator_contract <- "fixed_path_point_metric_three_chain_mean_v1"
point_candidate$confirmation_chain_count <- iems_v1_expected_chains
point_candidate$package_version <- iems_v1_cran_version
point_candidate$state_update_method <- ffv2_exdqlm_mcmc_predictive_state_update_method()
point_candidate$source_run_id <- as.character(materialization$run_id)
point_candidate$article_consumption_allowed <- TRUE

checks <- iems_v1_full_confirmation_checks(
  chain_summary, cell_summary, pooled_intervals, run_root, manifest
)
checks <- c(
  checks,
  sentinel_8_of_8_verified = sentinel_ok &&
    identical(as.integer(sentinel$checks_pass), 8L) &&
    identical(as.integer(sentinel$checks_total), 8L),
  metric_diagnostics_27 = nrow(metric_diagnostics) == 27L,
  lead_profiles_270 = nrow(lead_profiles) == 270L,
  origin_profiles_306 = nrow(origin_profiles) == 306L,
  origin_lead_profiles_9000 = nrow(origin_lead_profiles) == 9000L,
  article_write_performed_false = isFALSE(materialization$article_write_performed),
  shared_validation_write_performed_false =
    isFALSE(materialization$shared_validation_write_performed)
)

chain_path <- ffv2_write_csv(
  chain_summary, file.path(closeout_root, "chain_metric_comparison.csv")
)
cell_path <- ffv2_write_csv(
  cell_summary, file.path(closeout_root, "cell_metric_comparison.csv")
)
interval_path <- ffv2_write_csv(
  pooled_intervals, file.path(closeout_root, "pooled_metric_intervals.csv")
)
metric_diagnostics_path <- ffv2_write_csv(
  metric_diagnostics, file.path(closeout_root, "mcmc_metric_diagnostics.csv")
)
inference_diagnostics_path <- ffv2_write_csv(
  ffv2_bind_rows(diagnostic_rows),
  file.path(closeout_root, "exdqlm_inference_diagnostics.csv")
)
lead_path <- ffv2_write_csv(
  lead_profiles, file.path(closeout_root, "forecast_lead_profiles.csv")
)
origin_path <- ffv2_write_csv(
  origin_profiles, file.path(closeout_root, "forecast_origin_profiles.csv")
)
origin_lead_path <- ffv2_write_csv(
  origin_lead_profiles, file.path(closeout_root, "forecast_origin_lead_profiles.csv")
)
point_candidate_path <- ffv2_write_csv(
  point_candidate, file.path(closeout_root, "candidate_point_exdqlm_mcmc_rows.csv")
)
interval_candidate_path <- ffv2_write_csv(
  interval_candidate,
  file.path(closeout_root, "candidate_interval_exdqlm_mcmc_roles.csv")
)
checks_path <- ffv2_write_csv(
  data.frame(check = names(checks), pass = unname(checks), stringsAsFactors = FALSE),
  file.path(closeout_root, "full_confirmation_checks.csv")
)

scientific_summary <- data.frame(
  indicator = c(
    "jobs_completed", "cells_completed", "forecast_mae_cells_improved",
    "forecast_check_cells_improved", "lower_tail_mae_cells_improved",
    "median_mae_cells_improved", "metric_diagnostic_warnings",
    "health_pass_chains", "health_warn_chains", "health_fail_chains",
    "maximum_abs_fit_change", "maximum_abs_first_origin_change"
  ),
  value = c(
    nrow(chain_summary), nrow(cell_summary), sum(cell_summary$forecast_mae_change < 0),
    sum(cell_summary$forecast_check_change < 0),
    sum(cell_summary$forecast_mae_change[cell_summary$tau < 0.5] < 0),
    sum(cell_summary$forecast_mae_change[cell_summary$tau == 0.5] < 0),
    sum(metric_diagnostics$diagnostic_grade == "WARN", na.rm = TRUE),
    sum(chain_summary$health_gate == "PASS"), sum(chain_summary$health_gate == "WARN"),
    sum(chain_summary$health_gate == "FAIL"), max(abs(chain_summary$fit_rmse_change)),
    max(abs(chain_summary$first_origin_mae_change))
  ),
  stringsAsFactors = FALSE
)
scientific_summary_path <- ffv2_write_csv(
  scientific_summary, file.path(closeout_root, "scientific_change_summary.csv")
)

decision <- if (all(checks)) {
  "READY_FOR_INTEGRATION_REPLACE_COMPLETE_EXDQLM_MCMC_BLOCK"
} else {
  "BLOCKED_FULL_CONFIRMATION_REVIEW_REQUIRED"
}
writeLines(c(
  "# Independent exDQLM MCMC rolling-state repair v1 closeout",
  "",
  sprintf("- Decision: `%s`", decision),
  sprintf("- Completed jobs: %d/%d", nrow(chain_summary), iems_v1_expected_full_jobs),
  sprintf("- Completed cells: %d/%d", nrow(cell_summary), iems_v1_expected_cells),
  sprintf("- Checks: %d/%d", sum(checks), length(checks)),
  sprintf("- Forecast-MAE improvements: %d/%d cells",
          sum(cell_summary$forecast_mae_change < 0), nrow(cell_summary)),
  sprintf("- Forecast-check improvements: %d/%d cells",
          sum(cell_summary$forecast_check_change < 0), nrow(cell_summary)),
  sprintf("- Diagnostic warnings: %d/%d metric roles",
          sum(metric_diagnostics$diagnostic_grade == "WARN", na.rm = TRUE),
          nrow(metric_diagnostics)),
  "- Diagnostic grades are disclosed but are not metric-exclusion rules.",
  "- The corrected nine-cell exDQLM MCMC block is indivisible for integration.",
  "- Article, shared-validation, and Overleaf writes: none."
), file.path(closeout_root, "CLOSEOUT.md"), useBytes = TRUE)

closeout_files <- list.files(closeout_root, full.names = TRUE)
closeout_files <- closeout_files[basename(closeout_files) != "output_file_manifest.csv"]
output_manifest <- data.frame(
  file = basename(closeout_files),
  path = normalizePath(closeout_files, winslash = "/", mustWork = TRUE),
  sha256 = vapply(closeout_files, ffv2_file_sha256, character(1L)),
  bytes = as.numeric(file.info(closeout_files)$size),
  stringsAsFactors = FALSE
)
output_manifest_path <- ffv2_write_csv(
  output_manifest, file.path(closeout_root, "output_file_manifest.csv")
)

upstream <- system2(
  "git", c("-C", repo_root, "rev-parse", "--abbrev-ref", "@{upstream}"),
  stdout = TRUE
)
handoff <- list(
  schema_version = iems_v1_schema,
  status = if (all(checks)) "READY_FOR_INTEGRATION" else "BLOCKED",
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  lane = "IND_QDESN_VAL",
  run_id = as.character(materialization$run_id),
  worktree = repo_root, branch = branch, upstream = upstream, head = head,
  package_version = iems_v1_cran_version,
  package_repository = "CRAN",
  package_tarball_sha256 = iems_v1_cran_tarball_sha256,
  jobs = nrow(chain_summary), cells = nrow(cell_summary), chains_per_cell = 3L,
  state_update_method = ffv2_exdqlm_mcmc_predictive_state_update_method(),
  scientific_decision = decision,
  replacement_policy = paste(
    "Replace the complete nine-cell exDQLM MCMC block; do not cherry-pick only",
    "favorable cells and do not mix corrected and historical rolling-state rows."
  ),
  point_candidate_path = point_candidate_path,
  point_candidate_sha256 = ffv2_file_sha256(point_candidate_path),
  interval_candidate_path = interval_candidate_path,
  interval_candidate_sha256 = ffv2_file_sha256(interval_candidate_path),
  chain_comparison_path = chain_path,
  chain_comparison_sha256 = ffv2_file_sha256(chain_path),
  cell_comparison_path = cell_path,
  cell_comparison_sha256 = ffv2_file_sha256(cell_path),
  metric_diagnostics_path = metric_diagnostics_path,
  metric_diagnostics_sha256 = ffv2_file_sha256(metric_diagnostics_path),
  inference_diagnostics_path = inference_diagnostics_path,
  inference_diagnostics_sha256 = ffv2_file_sha256(inference_diagnostics_path),
  checks_path = checks_path, checks_sha256 = ffv2_file_sha256(checks_path),
  scientific_summary_path = scientific_summary_path,
  scientific_summary_sha256 = ffv2_file_sha256(scientific_summary_path),
  output_manifest_path = output_manifest_path,
  output_manifest_sha256 = ffv2_file_sha256(output_manifest_path),
  sentinel_run_id = iems_v1_sentinel_run_id,
  sentinel_closeout_sha256 = ffv2_file_sha256(sentinel_closeout_path),
  fitted_model_binaries = 0L,
  article_write_performed = FALSE,
  shared_validation_write_performed = FALSE,
  overleaf_write_performed = FALSE,
  integration_owner = "ARTICLE_QDESN_INTEGRATION"
)
handoff_path <- ffv2_write_json(
  handoff, file.path(closeout_root, "integration_handoff.json")
)

cat(sprintf("FULL_DECISION=%s checks=%d/%d\n", decision, sum(checks), length(checks)))
cat(sprintf("HANDOFF=%s\n", handoff_path))
if (!all(checks)) quit(status = 2L)

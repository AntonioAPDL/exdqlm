#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/closeout_independent_exdqlm_1p1p1_scoped_continuation_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/",
                           mustWork = TRUE)
state_root <- normalizePath(args$`state-root` %||% "", winslash = "/", mustWork = TRUE)
manifest <- ffv2_read_json(file.path(state_root, "manifests", "materialization_manifest.json"))
if (!identical(as.character(manifest$schema_version), i111s_schema) ||
    !identical(as.character(manifest$scope_id), i111s_scope_id)) {
  stop("Closeout requires an exDQLM-only scoped continuation.", call. = FALSE)
}
plan <- ffv2_read_csv(file.path(state_root, "manifests", "job_plan.csv"))
plan_checks <- i111s_plan_checks(plan)
if (!all(plan_checks)) stop("The scoped plan contract changed before closeout.", call. = FALSE)
closeout_root <- file.path(state_root, "closeout")
ffv2_ensure_dir(closeout_root)

artifact_ok <- function(path, expected_sha) {
  path <- as.character(path %||% "")[1L]
  expected_sha <- as.character(expected_sha %||% "")[1L]
  nzchar(path) && nzchar(expected_sha) && file.exists(path) &&
    identical(ffv2_file_sha256(path), expected_sha)
}

job_rows <- lapply(seq_len(nrow(plan)), function(i) {
  row <- plan[i, , drop = FALSE]
  status_path <- file.path(state_root, "status", paste0(row$job_id[[1L]], ".json"))
  if (!file.exists(status_path)) {
    stop(sprintf("Missing terminal status for %s.", row$job_id[[1L]]), call. = FALSE)
  }
  x <- ffv2_read_json(status_path)
  config <- ffv2_read_json(row$config_path[[1L]])
  point_path <- as.character(config$row_metrics_path %||% "")[1L]
  checks <- c(
    success = identical(as.character(x$status), "SUCCESS"),
    config_hash = identical(as.character(x$config_sha256),
                            as.character(row$config_sha256[[1L]])),
    metric_draws = artifact_ok(x$metric_draws_path, x$metric_draws_sha256),
    interval_summary = artifact_ok(x$metric_interval_summary_path,
                                   x$metric_interval_summary_sha256),
    interval_manifest = artifact_ok(x$metric_interval_manifest_path,
                                    x$metric_interval_manifest_sha256),
    inference_diagnostics = artifact_ok(x$inference_diagnostics_path,
                                        x$inference_diagnostics_sha256),
    point_metrics = nzchar(point_path) && file.exists(point_path),
    draw_count = identical(as.integer(x$metric_draws),
                           as.integer(row$expected_draws[[1L]])),
    no_heavy_binary = identical(as.integer(x$heavy_binary_count), 0L)
  )
  data.frame(
    job_id = row$job_id[[1L]], replay_id = row$replay_id[[1L]],
    source_identity = row$source_identity[[1L]], inference = row$inference[[1L]],
    model_variant = row$model_variant[[1L]], family = row$family[[1L]],
    tau = row$tau[[1L]], chain_id = row$chain_id[[1L]],
    config_path = row$config_path[[1L]], config_sha256 = row$config_sha256[[1L]],
    status_path = status_path, status_sha256 = ffv2_file_sha256(status_path),
    metric_draws_path = as.character(x$metric_draws_path),
    metric_draws_sha256 = as.character(x$metric_draws_sha256),
    metric_draws = as.integer(x$metric_draws),
    point_metrics_path = point_path,
    point_metrics_sha256 = if (file.exists(point_path)) ffv2_file_sha256(point_path) else "",
    inference_diagnostics_path = as.character(x$inference_diagnostics_path),
    inference_diagnostics_sha256 = as.character(x$inference_diagnostics_sha256),
    elapsed_seconds = as.numeric(x$elapsed_seconds %||% NA_real_),
    checks_pass = all(checks), failed_checks = paste(names(checks)[!checks], collapse = ";"),
    stringsAsFactors = FALSE
  )
})
job_audit <- ffv2_bind_rows(job_rows)
job_audit_path <- ffv2_write_csv(job_audit,
                                  file.path(closeout_root, "job_artifact_audit.csv"))
if (!all(job_audit$checks_pass)) {
  stop(sprintf("Job artifact audit failed: %s",
               paste(job_audit$job_id[!job_audit$checks_pass], collapse = ", ")),
       call. = FALSE)
}

numeric_or_na <- function(x) {
  value <- suppressWarnings(as.numeric(x %||% NA_real_)[1L])
  if (is.finite(value)) value else NA_real_
}
diagnostic_rows <- lapply(seq_len(nrow(job_audit)), function(i) {
  row <- job_audit[i, , drop = FALSE]
  x <- ffv2_read_json(row$inference_diagnostics_path[[1L]])
  data.frame(
    job_id = row$job_id[[1L]], replay_id = row$replay_id[[1L]],
    inference = row$inference[[1L]], family = row$family[[1L]],
    tau = row$tau[[1L]], chain_id = row$chain_id[[1L]],
    gamma_fixed = isTRUE(x$gamma_fixed),
    requested_mh_proposal = as.character(x$requested_mh_proposal %||% NA_character_)[1L],
    observed_mh_proposal = as.character(x$observed_mh_proposal %||% NA_character_)[1L],
    vb_sigmagam_factorization = as.character(
      x$vb_sigmagam_factorization %||% NA_character_
    )[1L],
    gamma_n = as.integer(x$gamma$n %||% 0L),
    gamma_mean = numeric_or_na(x$gamma$mean), gamma_sd = numeric_or_na(x$gamma$sd),
    gamma_ess = numeric_or_na(x$gamma$ess), gamma_acf1 = numeric_or_na(x$gamma$acf1),
    sigma_n = as.integer(x$sigma$n %||% 0L),
    sigma_mean = numeric_or_na(x$sigma$mean), sigma_sd = numeric_or_na(x$sigma$sd),
    sigma_ess = numeric_or_na(x$sigma$ess), sigma_acf1 = numeric_or_na(x$sigma$acf1),
    stringsAsFactors = FALSE
  )
})
inference_diagnostics <- ffv2_bind_rows(diagnostic_rows)
diagnostics_path <- ffv2_write_csv(
  inference_diagnostics, file.path(closeout_root, "exdqlm_inference_diagnostics.csv")
)

source_summaries <- list()
point_summaries <- list()
chain_diagnostics <- list()
source_i <- point_i <- diag_i <- 0L
point_columns <- c(
  fit_rmse = "fit_q_rmse",
  forecast_mae = "forecast_h1000_q_mae",
  forecast_check_loss = "forecast_h1000_pinball_mean"
)
for (replay_id in unique(job_audit$replay_id)) {
  jobs <- job_audit[job_audit$replay_id == replay_id, , drop = FALSE]
  inference <- jobs$inference[[1L]]
  expected_chains <- if (inference == "mcmc") 3L else 1L
  draws <- ffv2_bind_rows(lapply(seq_len(nrow(jobs)), function(i) {
    x <- ffv2_read_csv(jobs$metric_draws_path[[i]])
    x$chain_id <- as.integer(jobs$chain_id[[i]])
    x
  }))
  if (length(unique(draws$chain_id)) != expected_chains ||
      any(table(draws$chain_id) != jobs$metric_draws[match(
        as.integer(names(table(draws$chain_id))), jobs$chain_id
      )])) {
    stop(sprintf("Metric-draw chain balance failed for %s.", replay_id), call. = FALSE)
  }
  interval_summary <- ffv2_metric_interval_summary(draws, inference = inference)
  source_i <- source_i + 1L
  source_summaries[[source_i]] <- cbind(data.frame(
    replay_id = replay_id, inference = inference, model_variant = "exdqlm",
    family = jobs$family[[1L]], tau = jobs$tau[[1L]], stringsAsFactors = FALSE
  ), interval_summary)

  raw_point <- ffv2_bind_rows(lapply(seq_len(nrow(jobs)), function(i) {
    x <- ffv2_read_csv(jobs$point_metrics_path[[i]])
    data.frame(
      chain_id = jobs$chain_id[[i]],
      fit_rmse = as.numeric(x[[point_columns[["fit_rmse"]]]][[1L]]),
      forecast_mae = as.numeric(x[[point_columns[["forecast_mae"]]]][[1L]]),
      forecast_check_loss = as.numeric(
        x[[point_columns[["forecast_check_loss"]]]][[1L]]
      ), stringsAsFactors = FALSE
    )
  }))
  for (metric in names(point_columns)) {
    values <- raw_point[[metric]]
    point_i <- point_i + 1L
    point_summaries[[point_i]] <- data.frame(
      replay_id = replay_id, inference = inference, model_variant = "exdqlm",
      family = jobs$family[[1L]], tau = jobs$tau[[1L]], metric = metric,
      point_mean = mean(values), point_sd_across_chains = if (length(values) > 1L) {
        stats::sd(values)
      } else 0,
      point_min = min(values), point_max = max(values), n_chains = length(values),
      stringsAsFactors = FALSE
    )
  }
  if (inference == "mcmc") {
    d <- tryCatch(ffv2_metric_chain_diagnostics(draws), error = function(e) {
      data.frame(
        metric = names(point_columns), chains = expected_chains,
        draws_per_chain = NA_integer_, split_rhat = NA_real_, bulk_ess = NA_real_,
        tail_ess = NA_real_, mcse_mean = NA_real_,
        mcse_fraction_interval_width = NA_real_,
        endpoint_max_range_pooled_sd = NA_real_, interval_overlap_min = NA_real_,
        diagnostic_error = conditionMessage(e), stringsAsFactors = FALSE
      )
    })
    if (!"diagnostic_error" %in% names(d)) d$diagnostic_error <- ""
    d$diagnostic_grade <- ifelse(
      is.finite(d$split_rhat) & d$split_rhat <= 1.05 &
        is.finite(d$bulk_ess) & d$bulk_ess >= 400 &
        is.finite(d$tail_ess) & d$tail_ess >= 200 &
        is.finite(d$mcse_fraction_interval_width) &
        d$mcse_fraction_interval_width <= 0.05 &
        is.finite(d$endpoint_max_range_pooled_sd) &
        d$endpoint_max_range_pooled_sd <= 0.50,
      "PASS", "WARN"
    )
    diag_i <- diag_i + 1L
    chain_diagnostics[[diag_i]] <- cbind(data.frame(
      replay_id = replay_id, family = jobs$family[[1L]], tau = jobs$tau[[1L]],
      stringsAsFactors = FALSE
    ), d)
  }
}
source_summary <- ffv2_bind_rows(source_summaries)
point_summary <- ffv2_bind_rows(point_summaries)
metric_diagnostics <- ffv2_bind_rows(chain_diagnostics)
source_summary_path <- ffv2_write_csv(
  source_summary, file.path(closeout_root, "source_interval_summary.csv")
)
point_summary_path <- ffv2_write_csv(
  point_summary, file.path(closeout_root, "source_point_metric_summary.csv")
)
metric_diagnostics_path <- ffv2_write_csv(
  metric_diagnostics, file.path(closeout_root, "mcmc_metric_diagnostics.csv")
)

registry <- ffv2_read_csv(file.path(state_root, "materialization", "source_replay_registry.csv"))
roles <- ffv2_read_csv(file.path(state_root, "materialization", "metric_role_ledger.csv"))
registry_index <- match(roles$source_identity, registry$source_identity)
if (anyNA(registry_index)) stop("Metric-role/source join failed.", call. = FALSE)
roles$replay_id <- registry$replay_id[registry_index]
role_metric <- c(fit = "fit_rmse", forecast_mae = "forecast_mae",
                 forecast_check = "forecast_check_loss")
roles$metric <- unname(role_metric[roles$metric_role])
source_key <- paste(source_summary$replay_id, source_summary$metric, sep = "\r")
role_key <- paste(roles$replay_id, roles$metric, sep = "\r")
source_index <- match(role_key, source_key)
point_key <- paste(point_summary$replay_id, point_summary$metric, sep = "\r")
point_index <- match(role_key, point_key)
if (anyNA(source_index) || anyNA(point_index)) {
  stop("Not all scoped metric roles have interval and point summaries.", call. = FALSE)
}
for (field in c("posterior_mean", "posterior_sd", "cri_lower", "posterior_median",
                "cri_upper", "posterior_mean_inside_cri", "n_draws", "n_chains",
                "interval_label", "estimator_id")) {
  roles[[field]] <- source_summary[[field]][source_index]
}
for (field in c("point_mean", "point_sd_across_chains", "point_min", "point_max")) {
  roles[[field]] <- point_summary[[field]][point_index]
}
roles$posterior_delta_from_authority <- roles$posterior_mean - roles$authoritative_value
roles$posterior_ratio_to_authority <- roles$posterior_mean / roles$authoritative_value
roles$point_delta_from_authority <- roles$point_mean - roles$authoritative_value
roles$point_ratio_to_authority <- roles$point_mean / roles$authoritative_value
roles$strict_posterior_improvement <- roles$posterior_delta_from_authority < -1e-12
roles$strict_point_improvement <- roles$point_delta_from_authority < -1e-12
roles$material_point_change_1e6 <- abs(roles$point_delta_from_authority) > 1e-6
if (nrow(metric_diagnostics)) {
  diagnostic_key <- paste(metric_diagnostics$replay_id, metric_diagnostics$metric, sep = "\r")
  diagnostic_index <- match(role_key, diagnostic_key)
  roles$diagnostic_grade <- ifelse(
    roles$inference == "vb", "APPROX", metric_diagnostics$diagnostic_grade[diagnostic_index]
  )
} else roles$diagnostic_grade <- ifelse(roles$inference == "vb", "APPROX", "WARN")
comparison_path <- ffv2_write_csv(
  roles, file.path(closeout_root, "exdqlm_1p1p1_scoped_vs_authority.csv")
)

authority <- ffv2_read_csv(imi_v1_authority_interface_path(repo_root, i111_authority_id))
candidate <- authority
candidate$article_interface_id <- "independent_exdqlm_1p1p1_scoped_candidate"
interval_fields <- c("posterior_sd", "cri_lower", "posterior_median", "cri_upper",
                     "posterior_mean_inside_cri", "n_draws", "n_chains",
                     "interval_label", "diagnostic_grade", "replay_id")
for (stem in c("fit", "forecast_mae", "forecast_check")) {
  for (field in interval_fields) {
    column <- paste0(stem, "_", field)
    if (!column %in% names(candidate)) candidate[[column]] <- NA
  }
}
candidate$compatibility_point_fit_rmse <- NA_real_
candidate$compatibility_point_forecast_mae <- NA_real_
candidate$compatibility_point_forecast_check_loss <- NA_real_
for (i in seq_len(nrow(roles))) {
  role <- roles[i, , drop = FALSE]
  match_row <- candidate$inference == role$inference[[1L]] &
    candidate$model_variant == "exdqlm" & candidate$family == role$family[[1L]] &
    abs(candidate$tau - role$tau[[1L]]) < 1e-12
  if (sum(match_row) != 1L) stop("Candidate interface join failed.", call. = FALSE)
  stem <- switch(role$metric_role[[1L]], fit = "fit", forecast_mae = "forecast_mae",
                 forecast_check = "forecast_check")
  point_column <- switch(role$metric_role[[1L]], fit = "fit_qtrue_rmse",
                         forecast_mae = "forecast_qtrue_mae_H1000",
                         forecast_check = "forecast_check_loss_H1000")
  candidate[[point_column]][match_row] <- role$posterior_mean[[1L]]
  for (field in interval_fields) {
    candidate[[paste0(stem, "_", field)]][match_row] <- role[[field]][[1L]]
  }
  compatibility_column <- switch(
    role$metric_role[[1L]], fit = "compatibility_point_fit_rmse",
    forecast_mae = "compatibility_point_forecast_mae",
    forecast_check = "compatibility_point_forecast_check_loss"
  )
  candidate[[compatibility_column]][match_row] <- role$point_mean[[1L]]
}
exdqlm_rows <- candidate$model_variant == "exdqlm"
candidate$package_version[exdqlm_rows] <- i111_package_version
candidate$validation_branch[exdqlm_rows] <- system2(
  "git", c("-C", repo_root, "branch", "--show-current"), stdout = TRUE
)
candidate$validation_commit[exdqlm_rows] <- system2(
  "git", c("-C", repo_root, "rev-parse", "HEAD"), stdout = TRUE
)
candidate$source_promotion_id[exdqlm_rows] <- "independent_exdqlm_1p1p1_scoped_candidate"
candidate$metric_estimator_contract[exdqlm_rows] <-
  "posterior_mean_draw_metric_equal_tailed_95cri_v1"
candidate_path <- ffv2_write_csv(
  candidate, file.path(closeout_root, "candidate_full_interface_exdqlm_only_replacement.csv")
)
candidate_rows_path <- ffv2_write_csv(
  candidate[exdqlm_rows, , drop = FALSE],
  file.path(closeout_root, "candidate_exdqlm_rows.csv")
)

heavy <- unique(unlist(lapply(unique(plan$job_root), function(root) {
  if (!dir.exists(root)) return(character(0))
  list.files(root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
             full.names = TRUE, ignore.case = TRUE)
}), use.names = FALSE))
checks <- c(
  jobs_36 = nrow(job_audit) == i111s_expected_jobs,
  jobs_verified = all(job_audit$checks_pass),
  vb_jobs_9 = sum(job_audit$inference == "vb") == i111s_expected_vb_jobs,
  mcmc_jobs_27 = sum(job_audit$inference == "mcmc") == i111s_expected_mcmc_jobs,
  sources_18 = length(unique(source_summary$replay_id)) == i111s_expected_source_identities,
  source_metric_rows_54 = nrow(source_summary) == i111s_expected_metric_roles,
  point_metric_rows_54 = nrow(point_summary) == i111s_expected_metric_roles,
  roles_54 = nrow(roles) == i111s_expected_metric_roles,
  candidate_rows_18 = sum(exdqlm_rows) == i111s_expected_article_rows,
  intervals_ordered = all(roles$cri_lower <= roles$posterior_median &
                            roles$posterior_median <= roles$cri_upper),
  mcmc_draws_12000 = all(source_summary$n_draws[source_summary$inference == "mcmc"] ==
                           12000L),
  vb_draws_10000 = all(source_summary$n_draws[source_summary$inference == "vb"] ==
                         10000L),
  mcmc_diagnostics_27 = nrow(inference_diagnostics[inference_diagnostics$inference == "mcmc", ]) ==
    i111s_expected_mcmc_jobs,
  mcmc_collapsed_slice = all(
    inference_diagnostics$observed_mh_proposal[inference_diagnostics$inference == "mcmc"] ==
      "collapsed_slice"
  ),
  no_heavy_binaries = length(heavy) == 0L,
  article_write_performed_false = isFALSE(manifest$execution_policy$article_write_performed)
)
checks_path <- ffv2_write_csv(
  data.frame(check = names(checks), pass = unname(checks), stringsAsFactors = FALSE),
  file.path(closeout_root, "closeout_checks.csv")
)
if (!all(checks)) {
  stop(sprintf("Scoped closeout failed: %s",
               paste(names(checks)[!checks], collapse = ", ")), call. = FALSE)
}
decision <- if (any(roles$material_point_change_1e6)) {
  "READY_FOR_INTEGRATION"
} else "READY_NO_ARTICLE_CHANGE"
handoff <- list(
  schema_version = i111s_schema, status = decision,
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  run_id = as.character(manifest$run_id), scope_id = i111s_scope_id,
  authority_id = i111_authority_id,
  package_version = i111_package_version,
  package_source_commit = i111_package_source_commit,
  package_tarball_sha256 = as.character(manifest$package_tarball_sha256),
  jobs = nrow(job_audit), sources = length(unique(source_summary$replay_id)),
  metric_roles = nrow(roles),
  strict_point_improvements = sum(roles$strict_point_improvement),
  strict_posterior_improvements = sum(roles$strict_posterior_improvement),
  material_point_changes_1e6 = sum(roles$material_point_change_1e6),
  mcmc_metric_warning_rows = sum(metric_diagnostics$diagnostic_grade == "WARN"),
  job_artifact_audit_path = job_audit_path,
  job_artifact_audit_sha256 = ffv2_file_sha256(job_audit_path),
  comparison_path = comparison_path,
  comparison_sha256 = ffv2_file_sha256(comparison_path),
  point_summary_path = point_summary_path,
  point_summary_sha256 = ffv2_file_sha256(point_summary_path),
  source_summary_path = source_summary_path,
  source_summary_sha256 = ffv2_file_sha256(source_summary_path),
  metric_diagnostics_path = metric_diagnostics_path,
  metric_diagnostics_sha256 = ffv2_file_sha256(metric_diagnostics_path),
  inference_diagnostics_path = diagnostics_path,
  inference_diagnostics_sha256 = ffv2_file_sha256(diagnostics_path),
  candidate_interface_path = candidate_path,
  candidate_interface_sha256 = ffv2_file_sha256(candidate_path),
  candidate_rows_path = candidate_rows_path,
  candidate_rows_sha256 = ffv2_file_sha256(candidate_rows_path),
  checks_path = checks_path, checks_sha256 = ffv2_file_sha256(checks_path),
  replacement_policy = paste(
    "The 18 exDQLM rows form one coherent exdqlm 1.1.1 compatibility block;",
    "the integration lane must not cherry-pick only favorable cells."
  ),
  article_write_performed = FALSE,
  integration_owner = "ARTICLE_QDESN_INTEGRATION",
  git_commit = system2("git", c("-C", repo_root, "rev-parse", "HEAD"), stdout = TRUE)
)
handoff_path <- file.path(closeout_root, "integration_handoff.json")
ffv2_write_json(handoff, handoff_path)
writeLines(c(
  "# exDQLM 1.1.1 scoped continuation closeout",
  "",
  sprintf("- Decision: `%s`", decision),
  sprintf("- Completed jobs: %d/%d", nrow(job_audit), i111s_expected_jobs),
  sprintf("- Strict point-metric improvements: %d/%d",
          sum(roles$strict_point_improvement), nrow(roles)),
  sprintf("- Strict posterior-metric improvements: %d/%d",
          sum(roles$strict_posterior_improvement), nrow(roles)),
  sprintf("- MCMC metric diagnostic warnings: %d/%d",
          sum(metric_diagnostics$diagnostic_grade == "WARN"), nrow(metric_diagnostics)),
  "- Article, shared-validation, and Overleaf writes: none",
  "- Integration policy: replace or retain the complete 18-row exDQLM block; do not cherry-pick."
), file.path(closeout_root, "CLOSEOUT.md"), useBytes = TRUE)
cat(sprintf("exDQLM-only 1.1.1 closeout: %s\n", decision))

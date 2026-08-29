iems_v1_schema <- "independent_exdqlm_mcmc_rolling_state_fix_v1"
iems_v1_expected_branch <-
  "validation/independent-exdqlm-mcmc-rolling-state-fix-v1-1.0.0"
iems_v1_cran_version <- "1.1.1"
iems_v1_cran_tarball_sha256 <-
  "3f3ed643ded7602fd62357d7f62024ca9071e0096214456650ed2de79722443e"
iems_v1_sentinel_run_id <-
  "independent_exdqlm_mcmc_rolling_state_fix_v1_sentinel_20260829_022824"
iems_v1_expected_full_jobs <- 27L
iems_v1_expected_cells <- 9L
iems_v1_expected_chains <- 3L
iems_v1_point_metric_columns <- c(
  fit_rmse = "fit_q_rmse",
  forecast_mae = "forecast_h1000_q_mae",
  forecast_check_loss = "forecast_h1000_pinball_mean"
)
iems_v1_immutable_artifact_roles <- c(
  "row_status_path", "row_health_path", "row_metrics_path",
  "fit_path_summary_path", "forecast_path_summary_path",
  "forecast_lead_metrics_path", "metric_draws_path",
  "metric_interval_summary_path", "metric_interval_manifest_path",
  "row_config_path"
)

iems_v1_promotion_root <- function(repo_root) {
  file.path(
    repo_root,
    "validation", "fitforecast_v2", "promotions",
    "independent_exdqlm_1p1p1_scoped_compatibility_v2_20260828"
  )
}

iems_v1_job_audit_path <- function(repo_root) {
  file.path(iems_v1_promotion_root(repo_root), "job_artifact_audit.csv")
}

iems_v1_task_tracker <- function(repo_root) {
  file.path(
    repo_root, "validation", "fitforecast_v2", "local_trackers",
    "independent_exdqlm_mcmc_rolling_state_fix_v1"
  )
}

iems_v1_results_root <- function(repo_root, run_id) {
  file.path(
    repo_root, "results", "qdesn_mcmc_validation",
    "qdesn_dqlm_500obs_independent_exdqlm_mcmc_rolling_state_fix_v1",
    run_id
  )
}

iems_v1_check_cran_package <- function() {
  desc <- utils::packageDescription("exdqlm")
  checks <- c(
    version = identical(as.character(desc$Version), iems_v1_cran_version),
    repository = identical(as.character(desc$Repository), "CRAN"),
    mcmc_default = identical(
      eval(formals(exdqlm::exdqlmMCMC)$mh.proposal)[[1L]],
      "collapsed_slice"
    ),
    state_method = identical(
      ffv2_exdqlm_mcmc_predictive_state_update_method(),
      "deterministic_plugin_filter_mcmc_posterior_predictive_moments_v1"
    )
  )
  if (!all(checks)) {
    stop(sprintf(
      "CRAN exdqlm preflight failed: %s",
      paste(names(checks)[!checks], collapse = ", ")
    ), call. = FALSE)
  }
  checks
}

iems_v1_check_cran_tarball <- function(repo_root) {
  tarball <- file.path(
    iems_v1_task_tracker(repo_root), "package", "exdqlm_1.1.1.tar.gz"
  )
  if (!file.exists(tarball)) {
    stop(sprintf("Missing CRAN source tarball: %s", tarball), call. = FALSE)
  }
  observed <- ffv2_file_sha256(tarball)
  if (!identical(observed, iems_v1_cran_tarball_sha256)) {
    stop(sprintf("CRAN source tarball hash mismatch: %s", observed), call. = FALSE)
  }
  list(path = normalizePath(tarball, winslash = "/", mustWork = TRUE), sha256 = observed)
}

iems_v1_check_exal_moment_contract <- function(n = 50000L, seed = 20260829L) {
  p0 <- 0.05
  sigma <- 2.8
  gamma <- 4.6
  set.seed(as.integer(seed))
  sample <- exdqlm::rexal(
    as.integer(n), p0 = p0, mu = 0, sigma = sigma, gamma = gamma
  )
  a <- ffv2_pkg_internal("A.fn")(p0, gamma)
  b <- ffv2_pkg_internal("B.fn")(p0, gamma)
  alpha <- ffv2_pkg_internal("C.fn")(p0, gamma) * abs(gamma)
  expected_mean <- sigma * (a + alpha * sqrt(2 / pi))
  expected_var <- sigma^2 * (b + a^2 + alpha^2 * (1 - 2 / pi))
  empirical_mean <- mean(sample)
  empirical_var <- stats::var(sample)
  empirical_quantile <- unname(stats::quantile(sample, p0))
  mean_z <- (empirical_mean - expected_mean) / sqrt(expected_var / n)
  variance_relative_error <- (empirical_var - expected_var) / expected_var
  checks <- c(
    mean_agreement = abs(mean_z) < 5,
    variance_agreement = abs(variance_relative_error) < 0.05,
    target_quantile_agreement = abs(empirical_quantile) < 0.25
  )
  if (!all(checks)) {
    stop(sprintf(
      "CRAN exAL generator moment contract failed: %s",
      paste(names(checks)[!checks], collapse = ", ")
    ), call. = FALSE)
  }
  list(
    checks = as.list(checks),
    n = as.integer(n),
    seed = as.integer(seed),
    p0 = p0,
    sigma = sigma,
    gamma = gamma,
    expected_mean = as.numeric(expected_mean),
    empirical_mean = empirical_mean,
    mean_z = mean_z,
    expected_variance = as.numeric(expected_var),
    empirical_variance = empirical_var,
    variance_relative_error = variance_relative_error,
    empirical_target_quantile = empirical_quantile
  )
}

iems_v1_select_source_jobs <- function(audit, mode = c("sentinel", "full")) {
  mode <- match.arg(mode)
  out <- audit[
    audit$model_variant == "exdqlm" & audit$inference == "mcmc",
    , drop = FALSE
  ]
  if (mode == "sentinel") {
    sentinel <-
      (out$family == "normal" & out$tau == 0.05 & out$chain_id == 1L) |
      (out$family == "gausmix" & out$tau == 0.25 & out$chain_id == 1L) |
      (out$family == "normal" & out$tau == 0.50 & out$chain_id == 1L)
    out <- out[sentinel, , drop = FALSE]
  }
  expected <- if (mode == "sentinel") 3L else 27L
  if (nrow(out) != expected || anyDuplicated(out$job_id)) {
    stop(sprintf("Expected %d unique %s jobs; found %d.", expected, mode, nrow(out)),
         call. = FALSE)
  }
  out[order(out$family, out$tau, out$chain_id), , drop = FALSE]
}

iems_v1_validate_launcher_manifest <- function(manifest) {
  required <- c(
    "row_id", "row_key", "spec_id", "family", "tau", "fit_size",
    "model_variant", "inference", "phase", "chain_id", "row_config_path",
    "row_status_path"
  )
  missing <- setdiff(required, names(manifest))
  if (length(missing)) {
    stop(sprintf(
      "Launcher manifest is missing required fields: %s",
      paste(missing, collapse = ", ")
    ), call. = FALSE)
  }
  if (any(!file.exists(manifest$row_config_path))) {
    stop("Launcher manifest references a missing row config.", call. = FALSE)
  }
  invisible(TRUE)
}

iems_v1_verify_row_artifacts <- function(config, row_key = NA_character_) {
  label <- as.character(row_key %||% config$row_key %||% "unknown")[1L]
  required_paths <- c(
    config$row_metrics_path, config$fit_path_summary_path,
    config$forecast_path_summary_path, config$forecast_lead_metrics_path,
    config$metric_draws_path, config$metric_interval_summary_path,
    config$metric_interval_manifest_path, config$inference_diagnostics_path,
    config$row_health_path, config$artifact_manifest_path
  )
  path_exists <- vapply(required_paths, function(path) {
    path <- as.character(path %||% "")[1L]
    nzchar(path) && file.exists(path)
  }, logical(1L))
  if (!all(path_exists)) {
    stop(sprintf("A required row artifact is missing: %s", label), call. = FALSE)
  }

  artifact_manifest <- ffv2_read_json(config$artifact_manifest_path)
  artifact_roles <- vapply(
    artifact_manifest$artifacts, function(x) as.character(x$role), character(1L)
  )
  missing_roles <- setdiff(iems_v1_immutable_artifact_roles, artifact_roles)
  if (length(missing_roles)) {
    stop(sprintf(
      "Immutable artifact roles are missing for %s: %s",
      label, paste(missing_roles, collapse = ", ")
    ), call. = FALSE)
  }
  artifact_index <- setNames(artifact_manifest$artifacts, artifact_roles)
  immutable_ok <- vapply(iems_v1_immutable_artifact_roles, function(role) {
    entry <- artifact_index[[role]]
    path <- as.character(entry$path)
    expected_path <- as.character(config[[role]])
    isTRUE(entry$exists) && file.exists(path) &&
      identical(normalizePath(path, winslash = "/", mustWork = TRUE),
                normalizePath(expected_path, winslash = "/", mustWork = TRUE)) &&
      identical(ffv2_file_sha256(path), as.character(entry$sha256))
  }, logical(1L))
  if (!all(immutable_ok)) {
    stop(sprintf(
      "Immutable artifact verification failed for %s: %s",
      label,
      paste(iems_v1_immutable_artifact_roles[!immutable_ok], collapse = ", ")
    ), call. = FALSE)
  }

  metric_interval_manifest <- ffv2_read_json(config$metric_interval_manifest_path)
  interval_manifest_ok <- identical(
    ffv2_file_sha256(config$metric_draws_path),
    as.character(metric_interval_manifest$metric_draws_sha256)
  ) && identical(
    ffv2_file_sha256(config$metric_interval_summary_path),
    as.character(metric_interval_manifest$metric_interval_summary_sha256)
  )
  if (!interval_manifest_ok) {
    stop(sprintf("Metric-interval manifest failed for %s", label), call. = FALSE)
  }
  list(
    immutable_roles = iems_v1_immutable_artifact_roles,
    artifact_manifest_path = normalizePath(
      config$artifact_manifest_path, winslash = "/", mustWork = TRUE
    ),
    artifact_manifest_sha256 = ffv2_file_sha256(config$artifact_manifest_path),
    inference_diagnostics_path = normalizePath(
      config$inference_diagnostics_path, winslash = "/", mustWork = TRUE
    ),
    inference_diagnostics_sha256 = ffv2_file_sha256(config$inference_diagnostics_path)
  )
}

iems_v1_full_cell_summary <- function(chain_summary) {
  required <- c(
    "family", "tau", "chain_id", "historical_fit_rmse", "corrected_fit_rmse",
    "historical_forecast_mae", "corrected_forecast_mae",
    "historical_forecast_check", "corrected_forecast_check",
    "historical_first_origin_mae", "corrected_first_origin_mae", "health_gate"
  )
  missing <- setdiff(required, names(chain_summary))
  if (length(missing)) {
    stop(sprintf(
      "Full chain summary is missing required fields: %s",
      paste(missing, collapse = ", ")
    ), call. = FALSE)
  }
  key <- paste(chain_summary$family, sprintf("%.2f", chain_summary$tau), sep = "|")
  groups <- split(seq_len(nrow(chain_summary)), key)
  rows <- lapply(groups, function(index) {
    x <- chain_summary[index, , drop = FALSE]
    mean_sd <- function(field) {
      value <- as.numeric(x[[field]])
      c(mean = mean(value), sd = if (length(value) > 1L) stats::sd(value) else 0)
    }
    old_fit <- mean_sd("historical_fit_rmse")
    new_fit <- mean_sd("corrected_fit_rmse")
    old_mae <- mean_sd("historical_forecast_mae")
    new_mae <- mean_sd("corrected_forecast_mae")
    old_check <- mean_sd("historical_forecast_check")
    new_check <- mean_sd("corrected_forecast_check")
    old_first <- mean_sd("historical_first_origin_mae")
    new_first <- mean_sd("corrected_first_origin_mae")
    data.frame(
      family = as.character(x$family[[1L]]),
      tau = as.numeric(x$tau[[1L]]),
      chains = nrow(x),
      historical_fit_rmse = old_fit[["mean"]],
      corrected_fit_rmse = new_fit[["mean"]],
      corrected_fit_rmse_chain_sd = new_fit[["sd"]],
      fit_rmse_change = new_fit[["mean"]] - old_fit[["mean"]],
      historical_forecast_mae = old_mae[["mean"]],
      corrected_forecast_mae = new_mae[["mean"]],
      corrected_forecast_mae_chain_sd = new_mae[["sd"]],
      forecast_mae_change = new_mae[["mean"]] - old_mae[["mean"]],
      forecast_mae_ratio = new_mae[["mean"]] / old_mae[["mean"]],
      historical_forecast_check = old_check[["mean"]],
      corrected_forecast_check = new_check[["mean"]],
      corrected_forecast_check_chain_sd = new_check[["sd"]],
      forecast_check_change = new_check[["mean"]] - old_check[["mean"]],
      forecast_check_ratio = new_check[["mean"]] / old_check[["mean"]],
      historical_first_origin_mae = old_first[["mean"]],
      corrected_first_origin_mae = new_first[["mean"]],
      first_origin_mae_change = new_first[["mean"]] - old_first[["mean"]],
      health_pass_chains = sum(as.character(x$health_gate) == "PASS"),
      health_warn_chains = sum(as.character(x$health_gate) == "WARN"),
      health_fail_chains = sum(as.character(x$health_gate) == "FAIL"),
      stringsAsFactors = FALSE
    )
  })
  out <- ffv2_bind_rows(rows)
  out[order(out$family, out$tau), , drop = FALSE]
}

iems_v1_full_confirmation_checks <- function(chain_summary, cell_summary,
                                              pooled_intervals, run_root,
                                              manifest) {
  point_fields <- c(
    "historical_fit_rmse", "corrected_fit_rmse",
    "historical_forecast_mae", "corrected_forecast_mae",
    "historical_forecast_check", "corrected_forecast_check",
    "historical_first_origin_mae", "corrected_first_origin_mae"
  )
  point_finite <- all(vapply(point_fields, function(field) {
    all(is.finite(as.numeric(chain_summary[[field]])))
  }, logical(1L)))
  interval_fields <- c(
    "posterior_mean", "posterior_sd", "cri_lower", "posterior_median", "cri_upper"
  )
  interval_finite <- all(vapply(interval_fields, function(field) {
    all(is.finite(as.numeric(pooled_intervals[[field]])))
  }, logical(1L)))
  heavy <- if (dir.exists(run_root)) {
    list.files(
      run_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
      full.names = TRUE, ignore.case = TRUE
    )
  } else character(0)
  cell_key <- paste(chain_summary$family, sprintf("%.2f", chain_summary$tau), sep = "|")
  chain_key <- paste(cell_key, chain_summary$chain_id, sep = "|")
  c(
    jobs_27 = nrow(chain_summary) == iems_v1_expected_full_jobs,
    cells_9 = nrow(cell_summary) == iems_v1_expected_cells &&
      length(unique(cell_key)) == iems_v1_expected_cells,
    chains_3_per_cell = all(table(cell_key) == iems_v1_expected_chains) &&
      !anyDuplicated(chain_key),
    manifest_27 = nrow(manifest) == iems_v1_expected_full_jobs &&
      all(as.logical(manifest$scientific_contract_equal)),
    point_metrics_finite = point_finite,
    pooled_intervals_27 = nrow(pooled_intervals) == 27L && interval_finite,
    intervals_ordered = all(
      pooled_intervals$cri_lower <= pooled_intervals$posterior_median &
        pooled_intervals$posterior_median <= pooled_intervals$cri_upper
    ),
    pooled_draws_12000 = all(as.integer(pooled_intervals$n_draws) == 12000L),
    state_method_exact = all(
      chain_summary$state_update_method ==
        ffv2_exdqlm_mcmc_predictive_state_update_method()
    ),
    package_cran_1p1p1 = all(chain_summary$package_version == iems_v1_cran_version) &&
      all(chain_summary$package_repository == "CRAN"),
    collapsed_slice_exact = all(
      chain_summary$requested_mh_proposal == "collapsed_slice" &
        chain_summary$observed_mh_proposal == "collapsed_slice"
    ),
    fit_invariant_1e6 = all(abs(chain_summary$fit_rmse_change) <= 1e-6),
    first_origin_invariant_1e6 = all(
      abs(chain_summary$first_origin_mae_change) <= 1e-6
    ),
    complete_path_shapes = all(chain_summary$fit_rows == 500L) &&
      all(chain_summary$forecast_rows == 1000L) &&
      all(chain_summary$forecast_origins == 34L) &&
      all(chain_summary$forecast_max_lead == 30L),
    health_disclosed = all(chain_summary$health_gate %in% c("PASS", "WARN", "FAIL")),
    no_heavy_binaries = length(heavy) == 0L
  )
}

iems_v1_remap_output_path <- function(path, source_root, target_root) {
  path <- as.character(path %||% "")[1L]
  if (!nzchar(path) || !startsWith(path, paste0(source_root, "/"))) return(path)
  file.path(target_root, substring(path, nchar(source_root) + 2L))
}

iems_v1_config_contract_audit <- function(source, target) {
  all_fields <- union(names(source), names(target))
  changed <- all_fields[vapply(all_fields, function(field) {
    !identical(source[[field]], target[[field]])
  }, logical(1L))]
  input_paths <- c(
    "series_wide_path", "true_quantile_grid_path", "sim_output_path", "meta_path"
  )
  generated_paths <- setdiff(
    all_fields[grepl("_path$", all_fields)],
    input_paths
  )
  allowed <- unique(c(
    generated_paths,
    "run_tag", "run_root", "repo_root", "harness_root", "defaults_path",
    "state_update_method", "status", "screen_stage", "candidate_notes",
    "source_config_sha256", "package_contract", "state_update_contract",
    "handoff", "retention"
  ))
  unexpected <- setdiff(changed, allowed)
  if (length(unexpected)) {
    stop(sprintf(
      "Unexpected scientific config changes: %s",
      paste(unexpected, collapse = ", ")
    ), call. = FALSE)
  }
  missing_inputs <- input_paths[!vapply(input_paths, function(field) {
    identical(source[[field]], target[[field]])
  }, logical(1L))]
  if (length(missing_inputs)) {
    stop(sprintf(
      "Input path contract changed: %s", paste(missing_inputs, collapse = ", ")
    ), call. = FALSE)
  }
  list(
    changed_fields = sort(changed),
    allowed_fields = sort(intersect(changed, allowed)),
    unexpected_fields = unexpected,
    scientific_contract_equal = !length(unexpected) && !length(missing_inputs)
  )
}

iems_v1_remap_config <- function(config, repo_root, run_id, source_config_path,
                                 source_config_sha256) {
  source_run_root <- as.character(config$run_root)[1L]
  tau_label <- ffv2_tau_label(config$tau)
  job_tag <- sprintf(
    "%s__%s_%s_c%02d",
    run_id, config$family, tau_label, as.integer(config$chain_id)
  )
  target_run_root <- file.path(iems_v1_results_root(repo_root, run_id), "dqlm", job_tag)

  path_fields <- names(config)[grepl("_path$", names(config))]
  input_fields <- c(
    "series_wide_path", "true_quantile_grid_path", "sim_output_path", "meta_path"
  )
  for (field in setdiff(path_fields, input_fields)) {
    config[[field]] <- iems_v1_remap_output_path(
      config[[field]], source_run_root, target_run_root
    )
  }
  config$run_tag <- job_tag
  config$run_root <- target_run_root
  config$repo_root <- repo_root
  config$harness_root <- file.path(repo_root, "validation", "fitforecast_v2")
  config$defaults_path <- file.path(
    repo_root, "validation", "fitforecast_v2", "config",
    "exdqlm_dynamic_fitforecast_v2_defaults.yaml"
  )
  config$state_update_method <- ffv2_exdqlm_mcmc_predictive_state_update_method()
  config$status <- "pending"
  config$screen_stage <- "mcmc_posterior_predictive_state_update_fix_v1"
  config$candidate_notes <- paste(
    "Exact prior exDQLM specification and MCMC seed; only the held-out",
    "rolling-state pseudo-observation moments change."
  )
  config$source_config_path <- normalizePath(
    source_config_path, winslash = "/", mustWork = TRUE
  )
  config$source_config_sha256 <- source_config_sha256
  config$package_contract <- list(
    version = iems_v1_cran_version,
    authority = "CRAN",
    url = "https://CRAN.R-project.org/package=exdqlm",
    source_tarball_sha256 = iems_v1_cran_tarball_sha256,
    gamma_update = "collapsed_slice"
  )
  config$state_update_contract <- list(
    method = ffv2_exdqlm_mcmc_predictive_state_update_method(),
    location = "posterior mean of exact exAL error mean",
    variance = "posterior predictive exAL error variance",
    posterior_draw_source = "paired samp.sigma and samp.gamma",
    historical_method = ffv2_exdqlm_plugin_state_update_method(),
    scientific_change_scope = "held-out rolling state updates only"
  )
  config$handoff$prune_fit_on_success <- TRUE
  config$retention$allow_success_binary_payloads <- FALSE
  config
}

iems_v1_materialize <- function(repo_root, run_id, mode = c("sentinel", "full")) {
  mode <- match.arg(mode)
  branch <- system2("git", c("-C", repo_root, "branch", "--show-current"), stdout = TRUE)
  if (!identical(branch, iems_v1_expected_branch)) {
    stop(sprintf("Refusing unexpected branch: %s", branch), call. = FALSE)
  }
  package_checks <- iems_v1_check_cran_package()
  tarball <- iems_v1_check_cran_tarball(repo_root)
  moment_contract <- iems_v1_check_exal_moment_contract()
  audit_path <- iems_v1_job_audit_path(repo_root)
  audit <- ffv2_read_csv(audit_path)
  jobs <- iems_v1_select_source_jobs(audit, mode = mode)
  config_ok <- vapply(seq_len(nrow(jobs)), function(i) {
    path <- as.character(jobs$config_path[[i]])
    file.exists(path) && identical(ffv2_file_sha256(path), jobs$config_sha256[[i]])
  }, logical(1L))
  if (!all(config_ok)) {
    stop(sprintf("Frozen source config verification failed for: %s",
                 paste(jobs$job_id[!config_ok], collapse = ", ")), call. = FALSE)
  }

  run_root <- iems_v1_results_root(repo_root, run_id)
  if (dir.exists(run_root)) {
    stop(sprintf("Refusing pre-existing run root: %s", run_root), call. = FALSE)
  }
  ffv2_ensure_dir(file.path(run_root, "manifests"))
  manifest_rows <- vector("list", nrow(jobs))
  contract_audits <- vector("list", nrow(jobs))
  for (i in seq_len(nrow(jobs))) {
    source_path <- as.character(jobs$config_path[[i]])
    source_config <- ffv2_read_json(source_path)
    config <- iems_v1_remap_config(
      source_config, repo_root, run_id, source_path, jobs$config_sha256[[i]]
    )
    contract_audits[[i]] <- iems_v1_config_contract_audit(source_config, config)
    config_path <- config$row_config_path
    ffv2_ensure_dir(dirname(config_path))
    ffv2_write_json(config, config_path)
    manifest_rows[[i]] <- data.frame(
      row_id = as.integer(config$row_id),
      row_key = as.character(config$row_key),
      spec_id = as.character(config$spec_id),
      family = as.character(config$family),
      tau = as.numeric(config$tau),
      fit_size = as.integer(config$fit_size),
      model_variant = as.character(config$model_variant),
      inference = as.character(config$inference),
      phase = as.character(config$phase),
      chain_id = as.integer(config$chain_id),
      status = "pending",
      row_config_path = normalizePath(config_path, winslash = "/", mustWork = TRUE),
      row_status_path = as.character(config$row_status_path),
      row_config_sha256 = ffv2_file_sha256(config_path),
      source_job_id = as.character(jobs$job_id[[i]]),
      source_config_path = normalizePath(source_path, winslash = "/", mustWork = TRUE),
      source_config_sha256 = as.character(jobs$config_sha256[[i]]),
      state_update_method = as.character(config$state_update_method),
      scientific_contract_equal = contract_audits[[i]]$scientific_contract_equal,
      changed_top_level_fields = paste(
        contract_audits[[i]]$changed_fields, collapse = ";"
      ),
      stringsAsFactors = FALSE
    )
  }
  manifest <- ffv2_bind_rows(manifest_rows)
  iems_v1_validate_launcher_manifest(manifest)
  manifest_path <- ffv2_write_csv(
    manifest, file.path(run_root, "manifests", "job_manifest.csv")
  )
  preflight_path <- ffv2_write_json(list(
    schema_version = iems_v1_schema,
    generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    package_checks = as.list(package_checks),
    package_description = as.list(utils::packageDescription("exdqlm")[c(
      "Package", "Version", "Repository", "Built", "Packaged"
    )]),
    installed_package_path = normalizePath(
      find.package("exdqlm"), winslash = "/", mustWork = TRUE
    ),
    cran_tarball = tarball,
    exal_generator_moment_contract = moment_contract,
    r_version = R.version.string,
    session_info = capture.output(utils::sessionInfo()),
    thread_environment = as.list(Sys.getenv(c(
      "OMP_NUM_THREADS", "OMP_THREAD_LIMIT", "OMP_DYNAMIC",
      "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS", "BLIS_NUM_THREADS",
      "VECLIB_MAXIMUM_THREADS", "NUMEXPR_NUM_THREADS",
      "RCPP_PARALLEL_NUM_THREADS"
    )))
  ), file.path(run_root, "manifests", "preflight_report.json"))
  frozen <- list(
    schema_version = iems_v1_schema,
    generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    run_id = run_id,
    mode = mode,
    repo_root = repo_root,
    branch = branch,
    head = system2("git", c("-C", repo_root, "rev-parse", "HEAD"), stdout = TRUE),
    package_version = as.character(utils::packageVersion("exdqlm")),
    package_repository = as.character(utils::packageDescription("exdqlm")$Repository),
    cran_tarball_sha256 = iems_v1_cran_tarball_sha256,
    state_update_method = ffv2_exdqlm_mcmc_predictive_state_update_method(),
    source_job_audit_path = audit_path,
    source_job_audit_sha256 = ffv2_file_sha256(audit_path),
    preflight_report_path = preflight_path,
    preflight_report_sha256 = ffv2_file_sha256(preflight_path),
    jobs = nrow(manifest),
    manifest_path = manifest_path,
    manifest_sha256 = ffv2_file_sha256(manifest_path),
    numerical_threads_per_job = 1L,
    article_write_performed = FALSE,
    shared_validation_write_performed = FALSE
  )
  ffv2_write_json(frozen, file.path(run_root, "manifests", "materialization_manifest.json"))
  list(run_root = run_root, manifest_path = manifest_path, jobs = manifest)
}

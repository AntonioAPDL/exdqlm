test_that("rolling-state repair selects the intended sentinel and full surfaces", {
  audit <- data.frame(
    job_id = paste0("job", seq_len(27)),
    model_variant = "exdqlm",
    inference = "mcmc",
    family = rep(c("gausmix", "laplace", "normal"), each = 9),
    tau = rep(rep(c(0.05, 0.25, 0.50), each = 3), 3),
    chain_id = rep(1:3, 9),
    stringsAsFactors = FALSE
  )
  sentinel <- iems_v1_select_source_jobs(audit, "sentinel")
  full <- iems_v1_select_source_jobs(audit, "full")
  expect_equal(nrow(sentinel), 3L)
  expect_equal(nrow(full), 27L)
  expect_true(any(sentinel$family == "normal" & sentinel$tau == 0.05))
  expect_true(any(sentinel$family == "gausmix" & sentinel$tau == 0.25))
  expect_true(any(sentinel$family == "normal" & sentinel$tau == 0.50))
  expect_true(all(sentinel$chain_id == 1L))
})

test_that("rolling-state repair enforces the generic launcher schema", {
  config_path <- tempfile(fileext = ".json")
  writeLines("{}", config_path)
  manifest <- data.frame(
    row_id = 1L, row_key = "row_0001", spec_id = "spec", family = "normal",
    tau = 0.05, fit_size = 500L, model_variant = "exdqlm",
    inference = "mcmc", phase = "mcmc_tt500", chain_id = 1L,
    row_config_path = config_path, row_status_path = tempfile(fileext = ".csv"),
    stringsAsFactors = FALSE
  )
  expect_true(iems_v1_validate_launcher_manifest(manifest))
  expect_error(
    iems_v1_validate_launcher_manifest(manifest[, setdiff(names(manifest), "row_status_path")]),
    "row_status_path"
  )
})

test_that("rolling-state repair remaps only generated output paths", {
  source_config <- tempfile(fileext = ".json")
  writeLines("{}", source_config)
  config <- list(
    family = "normal", tau = 0.05, chain_id = 1L,
    run_root = "/old/run",
    row_config_path = "/old/run/configs/row_0002_config.json",
    row_metrics_path = "/old/run/metrics/row_0002_metrics.csv",
    series_wide_path = "/shared/source/series_wide.csv",
    true_quantile_grid_path = "/shared/source/true_quantile_grid.csv",
    sim_output_path = "/shared/source/sim_output.rds",
    meta_path = "/shared/source/meta.txt",
    row_id = 2L, row_key = "row_0002", spec_id = "spec",
    fit_size = 500L, model_variant = "exdqlm", inference = "mcmc",
    phase = "mcmc_tt500", status = "pending",
    handoff = list(prune_fit_on_success = TRUE),
    retention = list(allow_success_binary_payloads = FALSE)
  )
  out <- iems_v1_remap_config(
    config, "/repo", "run1", source_config, "sha"
  )
  expect_true(startsWith(out$row_metrics_path, "/repo/results/"))
  expect_identical(out$series_wide_path, config$series_wide_path)
  expect_identical(
    out$state_update_method,
    ffv2_exdqlm_mcmc_predictive_state_update_method()
  )
  expect_identical(out$package_contract$authority, "CRAN")
  audit <- iems_v1_config_contract_audit(config, out)
  expect_true(audit$scientific_contract_equal)
  expect_length(audit$unexpected_fields, 0L)

  bad <- out
  bad$tau <- 0.25
  expect_error(
    iems_v1_config_contract_audit(config, bad),
    "Unexpected scientific config changes: tau"
  )
})

test_that("full confirmation aggregates three chains for all nine cells", {
  chain_summary <- expand.grid(
    family = c("gausmix", "laplace", "normal"),
    tau = c(0.05, 0.25, 0.50),
    chain_id = 1:3,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  chain_summary$historical_fit_rmse <- 2
  chain_summary$corrected_fit_rmse <- 2
  chain_summary$historical_forecast_mae <- 10
  chain_summary$corrected_forecast_mae <- 2 + chain_summary$chain_id / 10
  chain_summary$historical_forecast_check <- 5
  chain_summary$corrected_forecast_check <- 4 + chain_summary$chain_id / 100
  chain_summary$historical_first_origin_mae <- 1
  chain_summary$corrected_first_origin_mae <- 1
  chain_summary$health_gate <- c("PASS", "WARN", "FAIL")[chain_summary$chain_id]

  cells <- iems_v1_full_cell_summary(chain_summary)
  expect_equal(nrow(cells), 9L)
  expect_true(all(cells$chains == 3L))
  expect_equal(cells$corrected_forecast_mae, rep(2.2, 9), tolerance = 1e-12)
  expect_equal(cells$forecast_mae_ratio, rep(0.22, 9), tolerance = 1e-12)
  expect_true(all(cells$health_pass_chains == 1L))
  expect_true(all(cells$health_warn_chains == 1L))
  expect_true(all(cells$health_fail_chains == 1L))
})

test_that("full closeout verifies immutable row evidence and interval hashes", {
  root <- tempfile("iems_row_artifacts_")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  role_paths <- setNames(
    file.path(root, paste0(iems_v1_immutable_artifact_roles, ".txt")),
    iems_v1_immutable_artifact_roles
  )
  for (path in role_paths) writeLines(basename(path), path)
  inference_path <- file.path(root, "inference.json")
  artifact_manifest_path <- file.path(root, "artifacts.json")
  writeLines("{}", inference_path)
  ffv2_write_json(list(
    metric_draws_sha256 = ffv2_file_sha256(role_paths[["metric_draws_path"]]),
    metric_interval_summary_sha256 =
      ffv2_file_sha256(role_paths[["metric_interval_summary_path"]])
  ), role_paths[["metric_interval_manifest_path"]])
  artifacts <- lapply(names(role_paths), function(role) list(
    role = role, path = role_paths[[role]], exists = TRUE,
    sha256 = ffv2_file_sha256(role_paths[[role]])
  ))
  ffv2_write_json(list(status = "done", artifacts = artifacts), artifact_manifest_path)
  config <- as.list(role_paths)
  config$inference_diagnostics_path <- inference_path
  config$artifact_manifest_path <- artifact_manifest_path

  audit <- iems_v1_verify_row_artifacts(config, "synthetic_row")
  expect_equal(length(audit$immutable_roles), 10L)
  expect_identical(audit$artifact_manifest_sha256,
                   ffv2_file_sha256(artifact_manifest_path))

  writeLines("tampered", role_paths[["row_metrics_path"]])
  expect_error(
    iems_v1_verify_row_artifacts(config, "synthetic_row"),
    "Immutable artifact verification failed"
  )
})

test_that("full confirmation gates the complete contract and heavy binaries", {
  chain_summary <- expand.grid(
    family = c("gausmix", "laplace", "normal"),
    tau = c(0.05, 0.25, 0.50),
    chain_id = 1:3,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  chain_summary$historical_fit_rmse <- 2
  chain_summary$corrected_fit_rmse <- 2
  chain_summary$fit_rmse_change <- 0
  chain_summary$historical_forecast_mae <- 10
  chain_summary$corrected_forecast_mae <- 2
  chain_summary$historical_forecast_check <- 5
  chain_summary$corrected_forecast_check <- 4
  chain_summary$historical_first_origin_mae <- 1
  chain_summary$corrected_first_origin_mae <- 1
  chain_summary$first_origin_mae_change <- 0
  chain_summary$health_gate <- "PASS"
  chain_summary$state_update_method <-
    ffv2_exdqlm_mcmc_predictive_state_update_method()
  chain_summary$package_version <- iems_v1_cran_version
  chain_summary$package_repository <- "CRAN"
  chain_summary$requested_mh_proposal <- "collapsed_slice"
  chain_summary$observed_mh_proposal <- "collapsed_slice"
  chain_summary$fit_rows <- 500L
  chain_summary$forecast_rows <- 1000L
  chain_summary$forecast_origins <- 34L
  chain_summary$forecast_max_lead <- 30L

  cells <- iems_v1_full_cell_summary(chain_summary)
  intervals <- expand.grid(
    family = c("gausmix", "laplace", "normal"),
    tau = c(0.05, 0.25, 0.50),
    metric = c("fit_rmse", "forecast_mae", "forecast_check_loss"),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  intervals$posterior_mean <- 2
  intervals$posterior_sd <- 0.2
  intervals$cri_lower <- 1.5
  intervals$posterior_median <- 2
  intervals$cri_upper <- 2.5
  intervals$n_draws <- 12000L
  manifest <- data.frame(
    row_id = seq_len(27), scientific_contract_equal = TRUE,
    stringsAsFactors = FALSE
  )
  run_root <- tempfile("iems_full_checks_")
  dir.create(run_root)
  on.exit(unlink(run_root, recursive = TRUE, force = TRUE), add = TRUE)

  checks <- iems_v1_full_confirmation_checks(
    chain_summary, cells, intervals, run_root, manifest
  )
  expect_true(all(checks))

  saveRDS(list(transient = TRUE), file.path(run_root, "unexpected_model.rds"))
  checks_with_binary <- iems_v1_full_confirmation_checks(
    chain_summary, cells, intervals, run_root, manifest
  )
  expect_false(unname(checks_with_binary[["no_heavy_binaries"]]))
  expect_true(all(checks_with_binary[names(checks_with_binary) != "no_heavy_binaries"]))
})

test_that("promotion contract requires the complete corrected exDQLM block", {
  point <- expand.grid(
    family = c("gausmix", "laplace", "normal"),
    tau = c(0.05, 0.25, 0.50),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  point$inference <- "mcmc"
  point$model_variant <- "exdqlm"
  point$package_version <- iems_v1_cran_version
  point$state_update_method <- ffv2_exdqlm_mcmc_predictive_state_update_method()
  point$fit_rmse_change <- 0
  point$first_origin_mae_change <- 0
  point$forecast_mae_change <- -1
  point$forecast_check_change <- -0.1
  point$health_pass_chains <- 3L
  point$health_warn_chains <- 0L
  point$health_fail_chains <- 0L
  point$article_consumption_allowed <- TRUE

  interval <- merge(
    point[c("family", "tau")],
    data.frame(metric = c("fit_rmse", "forecast_mae", "forecast_check_loss")),
    by = NULL
  )
  interval$posterior_mean <- 2
  interval$cri_lower <- 1
  interval$posterior_median <- 2
  interval$cri_upper <- 3
  interval$n_draws <- 12000L
  interval$n_chains <- 3L
  interval$inference <- "mcmc"
  interval$model_variant <- "exdqlm"
  interval$package_version <- iems_v1_cran_version
  interval$state_update_method <-
    ffv2_exdqlm_mcmc_predictive_state_update_method()

  chains <- merge(
    point[c("family", "tau")], data.frame(chain_id = 1:3), by = NULL
  )
  chains$status <- "done"
  chains$health_gate <- "PASS"
  chains$fit_rmse_change <- 0
  chains$first_origin_mae_change <- 0
  chains$state_update_method <-
    ffv2_exdqlm_mcmc_predictive_state_update_method()
  chains$package_version <- iems_v1_cran_version
  chains$package_repository <- "CRAN"
  chains$requested_mh_proposal <- "collapsed_slice"
  chains$observed_mh_proposal <- "collapsed_slice"

  metric_diagnostics <- interval[c("family", "tau", "metric")]
  metric_diagnostics$diagnostic_grade <- "PASS"
  confirmation_checks <- data.frame(
    check = paste0("check_", seq_len(23)), pass = TRUE
  )
  checks <- iems_v1_promotion_contract_checks(
    point, interval, chains, metric_diagnostics, confirmation_checks
  )
  expect_true(all(checks))

  point$forecast_mae_change[[1L]] <- 0
  failed <- iems_v1_promotion_contract_checks(
    point, interval, chains, metric_diagnostics, confirmation_checks
  )
  expect_false(unname(failed[["point_forecast_mae_improved_9"]]))
})

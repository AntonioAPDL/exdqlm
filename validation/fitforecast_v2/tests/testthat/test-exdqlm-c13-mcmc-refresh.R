test_that("c13 MCMC refresh dry-run creates exactly the current-best TT500 grid", {
  defaults <- ffv2_test_defaults()
  candidate <- ffv2_c13_mcmc_candidate()
  defaults <- ffv2_c13_mcmc_defaults(
    defaults,
    run_tag = "test_c13_mcmc_refresh",
    candidate = candidate,
    workers = 18L
  )
  ffv2_test_write_sources(defaults)
  registry <- ffv2_collect_source_registry(defaults, require_sources = TRUE)
  manifest <- ffv2_prepare_c13_mcmc_refresh_manifest(
    defaults = defaults,
    registry = registry,
    candidate = candidate,
    run_root = tempfile("c13_mcmc_refresh_"),
    dry_run = TRUE,
    workers = 18L
  )

  expect_equal(nrow(registry), 9L)
  expect_equal(nrow(manifest), 18L)
  expect_true(all(as.integer(manifest$fit_size) == 500L))
  expect_true(all(as.character(manifest$inference) == "mcmc"))
  expect_true(all(as.character(manifest$phase) == "mcmc_tt500"))
  expect_true(all(as.character(manifest$model_variant) %in% c("dqlm", "exdqlm")))
  expect_true(all(as.character(manifest$candidate_id) == ffv2_c13_mcmc_candidate_id()))
  expect_true(all(as.character(manifest$screen_stage) == "current_best_c13_mcmc_refresh"))
  expect_equal(length(unique(manifest$spec_id)), 18L)
  expect_equal(length(unique(manifest$model_spec_hash)), 1L)
  expect_equal(sum(manifest$smoke %in% c(TRUE, "TRUE", "true", "1")), 2L)
  expect_equal(sum(manifest$pilot %in% c(TRUE, "TRUE", "true", "1")), 4L)
  expect_equal(sort(unique(as.character(manifest$family))), c("gausmix", "laplace", "normal"))
  expect_equal(sort(unique(as.numeric(manifest$tau))), c(0.05, 0.25, 0.5))
})

test_that("c13 MCMC refresh writes stamped configs with separate smoke pilot and full budgets", {
  defaults <- ffv2_test_defaults()
  candidate <- ffv2_c13_mcmc_candidate()
  defaults <- ffv2_c13_mcmc_defaults(
    defaults,
    run_tag = "test_c13_mcmc_refresh_write",
    candidate = candidate,
    workers = 18L
  )
  ffv2_test_write_sources(defaults)
  registry <- ffv2_collect_source_registry(defaults, require_sources = TRUE)
  run_root <- tempfile("c13_mcmc_refresh_")
  manifest <- ffv2_prepare_c13_mcmc_refresh_manifest(
    defaults = defaults,
    registry = registry,
    candidate = candidate,
    run_root = run_root,
    dry_run = FALSE,
    workers = 18L
  )

  expect_true(file.exists(file.path(run_root, "manifests", "row_manifest.csv")))
  expect_true(file.exists(file.path(run_root, "manifests", "c13_mcmc_candidate.csv")))
  expect_true(file.exists(file.path(run_root, "manifests", "smoke_rows.csv")))
  expect_true(file.exists(file.path(run_root, "manifests", "pilot_rows.csv")))

  smoke_row <- ffv2_stage_rows(manifest, "smoke", include_completed = TRUE)[1L, , drop = FALSE]
  pilot_row <- ffv2_stage_rows(manifest, "pilot", include_completed = TRUE)
  pilot_row <- pilot_row[!(pilot_row$row_id %in% smoke_row$row_id), , drop = FALSE][1L, , drop = FALSE]
  full_row <- manifest[
    !(manifest$row_id %in% c(smoke_row$row_id, ffv2_stage_rows(manifest, "pilot", include_completed = TRUE)$row_id)),
    ,
    drop = FALSE
  ][1L, , drop = FALSE]

  smoke_cfg <- ffv2_read_json(smoke_row$row_config_path[[1L]])
  pilot_cfg <- ffv2_read_json(pilot_row$row_config_path[[1L]])
  full_cfg <- ffv2_read_json(full_row$row_config_path[[1L]])

  for (cfg in list(smoke_cfg, pilot_cfg, full_cfg)) {
    expect_equal(cfg$candidate_id, ffv2_c13_mcmc_candidate_id())
    expect_equal(cfg$screen_stage, "current_best_c13_mcmc_refresh")
    expect_equal(cfg$models$calibration_id, "clock_c13_trend100_season1_df0995s099")
    expect_equal(cfg$models$trend_C0_scale, 100)
    expect_equal(cfg$models$seasonal_C0_scale, 1)
    expect_equal(cfg$df_value, "0.995,0.99")
    expect_equal(cfg$dim_df, "2,4")
    expect_equal(cfg$handoff$reuse_vb_init, TRUE)
    expect_match(cfg$spec_id, "exdqlm_dqlm__")
  }
  expect_equal(smoke_cfg$budget$mcmc$n_burn, 20L)
  expect_equal(smoke_cfg$budget$mcmc$n_mcmc, 40L)
  expect_equal(smoke_cfg$budget$mcmc$init_from_vb, FALSE)
  expect_equal(pilot_cfg$budget$mcmc$n_burn, 50L)
  expect_equal(pilot_cfg$budget$mcmc$n_mcmc, 100L)
  expect_equal(pilot_cfg$budget$mcmc$init_from_vb, TRUE)
  expect_equal(full_cfg$budget$mcmc$n_burn, 5000L)
  expect_equal(full_cfg$budget$mcmc$n_mcmc, 20000L)
  expect_equal(full_cfg$budget$mcmc$init_from_vb, TRUE)
})

ffv2_test_c13_mcmc_interface_rows <- function(expected_cells = 2L, expected_leads = 30L) {
  cells <- ffv2_c13_mcmc_expected_cells()[seq_len(expected_cells), , drop = FALSE]
  pieces <- list()
  idx <- 0L
  for (ii in seq_len(nrow(cells))) {
    for (lead in seq_len(expected_leads)) {
      idx <- idx + 1L
      pieces[[idx]] <- data.frame(
        validation_contract_id = "contract",
        interface_schema_version = ffv2_shared_interface_schema_version(),
        model_family = "exdqlm_dqlm",
        model_variant = cells$model_variant[[ii]],
        inference = "mcmc",
        family = cells$family[[ii]],
        tau = cells$tau[[ii]],
        fit_size = 500L,
        candidate_id = ffv2_c13_mcmc_candidate_id(),
        calibration_id = "clock_c13_trend100_season1_df0995s099",
        status = "done",
        health_gate = "PASS",
        signoff_grade = "PASS",
        forecast_lead = lead,
        n_origins_scored = if (lead <= 10L) 34L else 33L,
        fit_qtrue_rmse = 1 + ii,
        fit_pinball_mean = 0.1 + ii,
        forecast_qtrue_mae = 2 + lead / 100,
        forecast_qtrue_rmse = 3 + lead / 100,
        forecast_pinball_mean = 0.2 + lead / 1000,
        runtime_sec_total = 100 + ii,
        source_registry_hash_value = ffv2_shared_source_registry_hash_value(),
        validation_branch = "validation/shared-fitforecast-v2-1.0.0",
        validation_commit = "abc",
        run_tag = ffv2_c13_mcmc_default_run_tag(),
        package_version = "1.0.0",
        forecast_protocol = "rolling_origin_no_refit_state_update",
        state_update_method = "deterministic_plugin_filter_train_median_latent_moments",
        max_lead_configured = expected_leads,
        origin_stride = 30L,
        train_start_source_index = 8501L,
        train_end_source_index = 9000L,
        forecast_origin_source_index = 9000L,
        forecast_block_start_source_index = 9001L,
        forecast_block_end_source_index = 10000L,
        stringsAsFactors = FALSE
      )
    }
  }
  ffv2_bind_rows(pieces)
}

test_that("c13 MCMC interface audit summarizes complete lead grids and flags incomplete ones", {
  rows <- ffv2_test_c13_mcmc_interface_rows(expected_cells = 2L, expected_leads = 30L)
  issues <- ffv2_validate_c13_mcmc_interface(rows, expected_cells = 2L, expected_leads = 30L)
  expect_equal(issues, character(0))
  summary <- ffv2_c13_mcmc_cell_summary(rows)
  expect_equal(nrow(summary), 2L)
  expect_true(all(summary$n_leads == 30L))
  expect_true(all(summary$n_origins_scored_total == 1000L))

  incomplete <- rows[as.integer(rows$forecast_lead) != 30L, , drop = FALSE]
  issues <- ffv2_validate_c13_mcmc_interface(incomplete, expected_cells = 2L, expected_leads = 30L)
  expect_true(any(grepl("Expected 60 lead rows", issues)))
  expect_true(any(grepl("Incomplete lead grid", issues)))
})

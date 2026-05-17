test_that("stage filters select exactly the intended model and fit-size lanes", {
  defaults <- ffv2_test_defaults()
  ffv2_test_write_sources(defaults)
  registry <- ffv2_collect_source_registry(defaults, require_sources = TRUE)
  manifest <- ffv2_prepare_manifest(defaults, registry, dry_run = TRUE)

  expect_equal(nrow(ffv2_stage_rows(manifest, "smoke")), 2L)
  expect_equal(nrow(ffv2_stage_rows(manifest, "pilot")), 4L)
  expect_true(any(ffv2_stage_rows(manifest, "pilot")$inference == "mcmc"))
  expect_true(all(ffv2_stage_rows(manifest, "vb_full")$inference == "vb"))
  expect_true(all(ffv2_stage_rows(manifest, "mcmc_tt500")$inference == "mcmc"))
  expect_true(all(ffv2_stage_rows(manifest, "mcmc_tt500")$fit_size == 500L))
  expect_true(all(ffv2_stage_rows(manifest, "mcmc_tt5000")$fit_size == 5000L))
})

test_that("smoke row configs receive explicit tiny smoke budgets", {
  defaults <- ffv2_test_defaults()
  ffv2_test_write_sources(defaults)
  registry <- ffv2_collect_source_registry(defaults, require_sources = TRUE)
  manifest <- ffv2_prepare_manifest(defaults, registry, dry_run = FALSE)

  smoke_row <- ffv2_stage_rows(manifest, "smoke")[1L, , drop = FALSE]
  full_row <- manifest[!isTRUE(manifest$smoke) & manifest$inference == "vb", , drop = FALSE][1L, , drop = FALSE]
  smoke_cfg <- jsonlite::read_json(smoke_row$row_config_path)
  full_cfg <- jsonlite::read_json(full_row$row_config_path)

  expect_equal(as.integer(smoke_cfg$budget$stored_draws), 100L)
  expect_equal(as.integer(smoke_cfg$budget$forecast_draws), 100L)
  expect_equal(as.integer(smoke_cfg$budget$vb$max_iter), 15L)
  expect_equal(as.integer(smoke_cfg$budget$vb$n_samp), 200L)
  expect_equal(as.integer(full_cfg$budget$stored_draws), 2000L)
  expect_equal(as.integer(full_cfg$budget$vb$max_iter), 300L)
})

test_that("pilot row configs receive explicit micro-pilot budgets", {
  defaults <- ffv2_test_defaults()
  ffv2_test_write_sources(defaults)
  registry <- ffv2_collect_source_registry(defaults, require_sources = TRUE)
  manifest <- ffv2_prepare_manifest(defaults, registry, dry_run = FALSE)

  pilot_mcmc <- ffv2_stage_rows(manifest, "pilot")
  pilot_mcmc <- pilot_mcmc[pilot_mcmc$inference == "mcmc", , drop = FALSE][1L, , drop = FALSE]
  pilot_cfg <- jsonlite::read_json(pilot_mcmc$row_config_path)

  expect_equal(as.integer(pilot_cfg$budget$stored_draws), 200L)
  expect_equal(as.integer(pilot_cfg$budget$forecast_draws), 200L)
  expect_equal(as.integer(pilot_cfg$budget$mcmc$n_burn), 50L)
  expect_equal(as.integer(pilot_cfg$budget$mcmc$n_mcmc), 100L)
  expect_equal(as.integer(pilot_cfg$runtime$heartbeat_seconds), 300L)
})

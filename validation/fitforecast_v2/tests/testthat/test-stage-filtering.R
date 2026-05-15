test_that("stage filters select exactly the intended model and fit-size lanes", {
  defaults <- ffv2_test_defaults()
  ffv2_test_write_sources(defaults)
  registry <- ffv2_collect_source_registry(defaults, require_sources = TRUE)
  manifest <- ffv2_prepare_manifest(defaults, registry, dry_run = TRUE)

  expect_equal(nrow(ffv2_stage_rows(manifest, "smoke")), 4L)
  expect_true(all(ffv2_stage_rows(manifest, "vb_full")$inference == "vb"))
  expect_true(all(ffv2_stage_rows(manifest, "mcmc_tt500")$inference == "mcmc"))
  expect_true(all(ffv2_stage_rows(manifest, "mcmc_tt500")$fit_size == 500L))
  expect_true(all(ffv2_stage_rows(manifest, "mcmc_tt5000")$fit_size == 5000L))
})

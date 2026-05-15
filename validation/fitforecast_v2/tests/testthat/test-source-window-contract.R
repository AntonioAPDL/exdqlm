test_that("source window verification enforces train through 9000 and forecast to 10000", {
  defaults <- ffv2_test_defaults()
  ffv2_test_write_sources(defaults)
  registry <- ffv2_collect_source_registry(defaults, require_sources = TRUE)
  verification <- ffv2_verify_source_windows(registry, stop_on_fail = TRUE)

  expect_true(all(verification$status == "PASS"))
  expect_equal(unique(verification$train_end_source_index), 9000L)
  expect_equal(unique(verification$forecast_start_source_index), 9001L)
  expect_equal(unique(verification$forecast_end_source_index), 10000L)
  expect_equal(sort(unique(verification$train_n)), c(500L, 5000L))
  expect_equal(unique(verification$forecast_n), 1000L)
})

test_that("prepare manifest creates the 72-row model/inference grid", {
  defaults <- ffv2_test_defaults()
  ffv2_test_write_sources(defaults)
  registry <- ffv2_collect_source_registry(defaults, require_sources = TRUE)
  manifest <- ffv2_prepare_manifest(defaults, registry, dry_run = TRUE)

  expect_equal(nrow(manifest), 72L)
  expect_equal(sum(manifest$smoke %in% c(TRUE, "TRUE", "true", "1")), 4L)
  expect_equal(as.integer(table(manifest$phase)[["vb_full"]]), 36L)
  expect_equal(as.integer(table(manifest$phase)[["mcmc_tt500"]]), 18L)
  expect_equal(as.integer(table(manifest$phase)[["mcmc_tt5000"]]), 18L)
})

test_that("source registry records the shared v2 source cells and hashes", {
  defaults <- ffv2_test_defaults()
  ffv2_test_write_sources(defaults)
  registry <- ffv2_collect_source_registry(defaults, require_sources = TRUE)

  expect_equal(nrow(registry), 18L)
  expect_true(all(registry$source_present))
  expect_true(all(c(
    "source_cell_id", "series_wide_sha256", "true_quantile_grid_sha256",
    "train_start_source_index", "forecast_end_source_index"
  ) %in% names(registry)))
  expect_equal(sort(unique(registry$fit_size)), c(500L, 5000L))
  expect_false(any(grepl("^/home/jaguir26/local/src", registry$series_wide_path)))
})

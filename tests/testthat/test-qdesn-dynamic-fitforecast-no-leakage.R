test_that("compact fit paths preserve fit+forecast source-index boundaries", {
  tmp <- tempfile("qdesn-no-leakage-")
  dir.create(tmp, recursive = TRUE)
  fixture <- make_fitforecast_compact_fixture(tmp, fit_size = 500L)
  method_dir <- file.path(tmp, "fits", "vb_al")

  paths <- exdqlm:::.qdesn_validation_write_compact_fit_paths(
    fixture$summary_obj,
    fixture$root_spec,
    method_dir,
    defaults = list(metrics = list(forecast_horizons = c(100L, 1000L)))
  )

  expect_equal(paths$train_rows, 500L)
  expect_equal(paths$holdout_rows, 1000L)
  expect_identical(paths$index_alignment_status, "PASS")

  train_df <- utils::read.csv(paths$train, stringsAsFactors = FALSE)
  forecast_df <- utils::read.csv(paths$holdout, stringsAsFactors = FALSE)
  align <- utils::read.csv(paths$index_alignment, stringsAsFactors = FALSE)

  expect_equal(range(train_df$source_index), c(8501L, 9000L))
  expect_equal(range(forecast_df$source_index), c(9001L, 10000L))
  expect_true(all(align$status == "PASS"))
  expect_false(any(forecast_df$source_index <= 9000L))
})

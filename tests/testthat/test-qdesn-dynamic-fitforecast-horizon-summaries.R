test_that("forecast horizon summaries expose H100 and H1000 windows", {
  tmp <- tempfile("qdesn-horizon-")
  dir.create(tmp, recursive = TRUE)
  fixture <- make_fitforecast_compact_fixture(tmp, fit_size = 500L)
  method_dir <- file.path(tmp, "fits", "vb_exal")

  paths <- exdqlm:::.qdesn_validation_write_compact_fit_paths(
    fixture$summary_obj,
    fixture$root_spec,
    method_dir,
    defaults = list(metrics = list(forecast_horizons = c(100L, 1000L)))
  )

  expect_equal(paths$forecast_horizon_rows, 2L)
  hz <- utils::read.csv(paths$forecast_horizon_summary, stringsAsFactors = FALSE)

  expect_equal(sort(hz$horizon), c(100L, 1000L))
  h100 <- hz[hz$horizon == 100L, , drop = FALSE]
  h1000 <- hz[hz$horizon == 1000L, , drop = FALSE]

  expect_equal(h100$source_index_first, 9001L)
  expect_equal(h100$source_index_last, 9100L)
  expect_equal(h1000$source_index_first, 9001L)
  expect_equal(h1000$source_index_last, 10000L)
  expect_true(all(is.finite(hz$qtrue_mae)))
  expect_true(all(is.finite(hz$pinball_tau)))
})

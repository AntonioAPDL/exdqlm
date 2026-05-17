test_that("primary Hmax=30 S=30 grid covers the forecast block exactly once", {
  grid <- ffv2_rolling_grid(hmax = 30L, origin_stride = 30L)
  summary <- ffv2_rolling_grid_lead_summary(grid)

  expect_equal(nrow(grid), 1000L)
  expect_equal(sort(grid$target_source_index), 9001:10000)
  expect_equal(length(unique(grid$target_source_index)), 1000L)
  expect_equal(unique(grid$max_lead_configured), 30L)
  expect_equal(unique(grid$origin_stride), 30L)
  expect_equal(range(grid$forecast_origin_source_index), c(9000L, 9990L))
  expect_equal(sort(unique(grid$forecast_lead)), 1:30)
  expect_equal(summary$n_origins_scored[summary$forecast_lead <= 10L], rep(34L, 10L))
  expect_equal(summary$n_origins_scored[summary$forecast_lead > 10L], rep(33L, 20L))
})

test_that("S=Hmax grids partition the 1000-point forecast block for candidate leads", {
  candidates <- list(`10` = c(10L, 10L), `45` = c(45L, 45L), `90` = c(90L, 90L))
  for (nm in names(candidates)) {
    hmax <- candidates[[nm]][[1L]]
    stride <- candidates[[nm]][[2L]]
    grid <- ffv2_rolling_grid(hmax = hmax, origin_stride = stride)
    ffv2_validate_rolling_grid(grid, require_complete_targets = TRUE)
    expect_equal(nrow(grid), 1000L)
    expect_equal(length(unique(grid$target_source_index)), 1000L)
  }
})

test_that("one-by-one rolling grid keeps triangular end-of-block lead counts", {
  grid <- ffv2_rolling_grid(hmax = 3L, origin_stride = 1L)
  summary <- ffv2_rolling_grid_lead_summary(grid)

  expect_equal(nrow(grid), 2997L)
  expect_equal(summary$n_origins_scored, c(1000L, 999L, 998L))
  expect_equal(summary$origin_end_source_index, c(9999L, 9998L, 9997L))
  expect_equal(summary$target_end_source_index, rep(10000L, 3L))
})

test_that("rolling grid can be constructed from shared defaults", {
  defaults <- ffv2_load_defaults()
  grid <- ffv2_rolling_grid_from_defaults(defaults, hmax = 30L, origin_stride = 30L)

  expect_equal(nrow(grid), 1000L)
  expect_equal(unique(grid$initial_forecast_origin_source_index), 9000L)
  expect_equal(unique(grid$forecast_block_start_source_index), 9001L)
  expect_equal(unique(grid$forecast_block_end_source_index), 10000L)
})

test_that("rolling grid rejects incoherent windows and horizons", {
  expect_error(
    ffv2_rolling_grid(initial_origin_source_index = 9000L, forecast_block_start_source_index = 9002L),
    "must equal initial_origin_source_index"
  )
  expect_error(ffv2_rolling_grid(hmax = 0L), "hmax must be >= 1")
  expect_error(ffv2_rolling_grid(origin_stride = 0L), "origin_stride must be >= 1")
  expect_error(ffv2_rolling_grid(hmax = 1001L), "hmax must be <= forecast block size")
})

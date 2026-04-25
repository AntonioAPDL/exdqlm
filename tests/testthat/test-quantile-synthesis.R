# Tests for synthesis helper orientation robustness and monotonicity smoke checks.

test_that("synthesis handles draw orientation consistently", {
  draws_low <- matrix(
    c(0.10, 0.12, 0.14, 0.16, 0.18,
      0.20, 0.22, 0.24, 0.26, 0.28,
      0.30, 0.32, 0.34, 0.36, 0.38),
    nrow = 3,
    byrow = TRUE
  )
  draws_high <- draws_low + 0.25

  out_rows <- quantileSynthesis(
    draws_list = list(draws_low, draws_high),
    p = c(0.2, 0.8),
    grid_M = 31L,
    n_samp = 24L,
    seed = 42L,
    T_expected = 3L
  )

  out_cols <- quantileSynthesis(
    draws_list = list(t(draws_low), t(draws_high)),
    p = c(0.2, 0.8),
    grid_M = 31L,
    n_samp = 24L,
    seed = 42L,
    T_expected = 3L
  )

  expect_equal(dim(out_rows$draws), c(3L, 24L))
  expect_true(isTRUE(all.equal(out_rows$draws, out_cols$draws, tolerance = 1e-12)))
})

test_that("synthesis smoke output is finite and monotone over levels", {
  draws_p90 <- matrix(
    c(2.0, 2.2, 2.4, 2.6,
      2.1, 2.3, 2.5, 2.7,
      1.9, 2.1, 2.3, 2.5),
    nrow = 3,
    byrow = TRUE
  )
  draws_p10 <- draws_p90 - 1.0
  draws_p50 <- draws_p90 - 0.5

  out <- quantileSynthesis(
    draws_list = list(draws_p90, draws_p10, draws_p50),
    p = c(0.9, 0.1, 0.5),
    grid_M = 41L,
    n_samp = 32L,
    seed = 1L,
    T_expected = 3L
  )

  monotone_levels <- all(apply(out$quantiles, 1L, function(row) all(diff(row) >= -1e-10)))
  expect_true(all(is.finite(out$draws)) && all(is.finite(out$quantiles)))
  expect_true(monotone_levels)
})

test_that("synthesis accepts dynamic fit objects and forecast objects", {
  draws_low <- matrix(
    c(0.10, 0.12, 0.14, 0.16,
      0.20, 0.22, 0.24, 0.26),
    nrow = 2,
    byrow = TRUE
  )
  draws_high <- draws_low + 0.3

  fit_low <- structure(list(samp.post.pred = draws_low), class = "exdqlmLDVB")
  fit_high <- structure(list(samp.post.pred = draws_high), class = "exdqlmMCMC")
  out_fit <- quantileSynthesis(
    draws_list = list(fit_low, fit_high),
    p = c(0.2, 0.8),
    n_samp = 20L,
    seed = 42L,
    T_expected = 2L
  )
  expect_equal(dim(out_fit$draws), c(2L, 20L))
  expect_true(all(is.finite(out_fit$draws)))

  fc_low <- structure(list(samp.fore = draws_low), class = "exdqlmForecast")
  fc_high <- structure(list(samp.fore = draws_high), class = "exdqlmForecast")
  out_fc <- quantileSynthesis(
    draws_list = list(fc_low, fc_high),
    p = c(0.2, 0.8),
    n_samp = 20L,
    seed = 42L,
    T_expected = 2L
  )
  expect_equal(dim(out_fc$draws), c(2L, 20L))
  expect_true(all(is.finite(out_fc$draws)))
})

test_that("synthesis errors clearly when forecast draws are missing", {
  fc_bad <- structure(list(k = 2), class = "exdqlmForecast")
  fc_ok <- structure(list(samp.fore = matrix(1:8, nrow = 2)), class = "exdqlmForecast")
  expect_error(
    quantileSynthesis(draws_list = list(fc_bad, fc_ok), p = c(0.2, 0.8), T_expected = 2L),
    "return.draws = TRUE",
    fixed = TRUE
  )
})

test_that("forecast diagnostics score one forecast object", {
  y <- c(0.2, 1.2, 1.8)
  draws <- matrix(
    c(-0.1, 0.1, 0.2, 0.4,
      0.8, 1.0, 1.1, 1.4,
      1.5, 1.8, 2.0, 2.2),
    nrow = 3,
    byrow = TRUE
  )
  fc <- structure(
    list(k = 3L, ff = c(0, 1, 2), samp.fore = draws, m1 = list(p0 = 0.5)),
    class = "exdqlmForecast"
  )

  out <- exdqlmForecastDiagnostics(
    fc, y = y,
    crps_probs = c(0.25, 0.5, 0.75),
    crps_weights = c(1, 2, 1)
  )

  expected_check <- CheckLossFn(0.5, y - fc$ff)
  expected_crps <- .exdqlm_crps_vec(
    y, draws,
    probs = c(0.25, 0.5, 0.75),
    weights = c(0.25, 0.5, 0.25)
  )

  expect_s3_class(out, "exdqlmForecastDiagnostic")
  expect_true(is.exdqlmForecastDiagnostic(out))
  expect_equal(out$p0, 0.5)
  expect_equal(out$horizon, 3L)
  expect_equal(out$crps.method, "integrated_quantile_score")
  expect_equal(out$crps.probs, c(0.25, 0.5, 0.75))
  expect_equal(out$crps.weights, c(0.25, 0.5, 0.25))
  expect_equal(out$m1.check_loss, mean(expected_check))
  expect_equal(out$m1.CRPS, mean(expected_crps))
  expect_s3_class(out$m1.pointwise, "data.frame")
  expect_equal(out$m1.pointwise$check_loss, as.numeric(expected_check))
  expect_equal(out$m1.pointwise$CRPS, as.numeric(expected_crps))
})

test_that("forecast diagnostics compare two forecast objects", {
  y <- c(1, 2)
  fc1 <- structure(
    list(
      k = 2L,
      ff = c(0.8, 1.9),
      samp.fore = matrix(c(0.7, 0.9, 1.7, 2.1), nrow = 2, byrow = TRUE),
      m1 = list(p0 = 0.8)
    ),
    class = "exdqlmForecast"
  )
  fc2 <- structure(
    list(
      k = 2L,
      ff = c(1.1, 2.3),
      samp.fore = matrix(c(1.0, 1.2, 2.1, 2.5), nrow = 2, byrow = TRUE),
      m1 = list(p0 = 0.8)
    ),
    class = "exdqlmForecast"
  )

  out <- exdqlmForecastDiagnostics(fc1, fc2, y = y)
  expect_true(all(c("m1.check_loss", "m1.CRPS", "m2.check_loss", "m2.CRPS") %in% names(out)))
  expect_s3_class(out$m2.pointwise, "data.frame")

  expect_output(print(out), "Held-out exDQLM forecast diagnostics")
  expect_output(summary_table <- summary(out), "Diagnostic")
  expect_s3_class(summary_table, "data.frame")
  expect_true(all(c("Diagnostic", "M1", "M2") %in% names(summary_table)))
})

test_that("forecast diagnostics validate inputs clearly", {
  y <- c(1, 2)
  fc <- structure(
    list(
      k = 2L,
      ff = c(1, 2),
      samp.fore = matrix(c(0.9, 1.1, 1.9, 2.1), nrow = 2, byrow = TRUE),
      m1 = list(p0 = 0.5)
    ),
    class = "exdqlmForecast"
  )
  fc_no_draws <- structure(list(k = 2L, ff = c(1, 2), m1 = list(p0 = 0.5)), class = "exdqlmForecast")
  fc_bad_p0 <- structure(
    list(k = 2L, ff = c(1, 2), samp.fore = fc$samp.fore, m1 = list(p0 = 0.8)),
    class = "exdqlmForecast"
  )

  expect_error(
    exdqlmForecastDiagnostics(fc_no_draws, y = y),
    "return.draws = TRUE",
    fixed = TRUE
  )
  expect_error(
    exdqlmForecastDiagnostics(fc, y = y[1]),
    "length\\(y\\) must equal"
  )
  expect_error(
    exdqlmForecastDiagnostics(fc, fc_bad_p0, y = y),
    "same quantile"
  )
  expect_error(
    exdqlmForecastDiagnostics(fc, y = y, p0 = 0.8),
    "does not match"
  )
  expect_error(
    exdqlmForecastDiagnostics(fc, y = y, crps_probs = c(0.2, 1)),
    "strictly between"
  )
  expect_error(
    exdqlmForecastDiagnostics(fc, y = c(1, NA)),
    "finite"
  )
})

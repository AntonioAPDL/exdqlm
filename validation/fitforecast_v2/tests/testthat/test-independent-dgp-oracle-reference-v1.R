testthat::test_that("independent DGP oracle formulas match frozen values", {
  expected <- data.frame(
    family = rep(c("normal", "laplace", "gausmix"), each = 3L),
    tau = rep(c(0.05, 0.25, 0.50), 3L),
    value = c(
      1.03135640375314, 3.17776572684424, 3.98942280401433,
      1.65129254649702, 4.23286795139986, 5.00000000000000,
      1.50873188854851, 4.50183076116227, 5.41483373548381
    )
  )
  observed <- mapply(
    idor_v1_expected_check_analytic,
    expected$family,
    expected$tau
  )
  numerical <- mapply(
    idor_v1_expected_check_numerical,
    expected$family,
    expected$tau
  )
  testthat::expect_equal(unname(observed), expected$value, tolerance = 1e-10)
  testthat::expect_equal(unname(observed), unname(numerical), tolerance = 1e-8)
})

testthat::test_that("raw innovation quantiles satisfy the DGP contract", {
  expected_shifts <- c(
    -16.4485362695147, -6.74489750196082, 0,
    -23.0258509299405, -6.93147180559945, 0,
    -22.8982822702506, -7.84183696773899, 0.237322463147006
  )
  cells <- expand.grid(
    tau = idor_v1_taus,
    family = idor_v1_families,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  cells <- cells[order(match(cells$family, idor_v1_families), cells$tau), ]
  observed <- mapply(idor_v1_raw_quantile, cells$family, cells$tau)
  cdf <- mapply(idor_v1_cdf, observed, cells$family)
  testthat::expect_equal(unname(observed), expected_shifts, tolerance = 1e-9)
  testthat::expect_equal(unname(cdf), cells$tau, tolerance = 1e-10)
})

testthat::test_that("oracle forecast grid tiles the held-out block exactly once", {
  grid <- idor_v1_forecast_grid()
  testthat::expect_equal(nrow(grid), 1000L)
  testthat::expect_equal(length(unique(grid$forecast_origin_source_index)), 34L)
  testthat::expect_identical(sort(grid$target_source_index), 9001:10000)
  testthat::expect_identical(anyDuplicated(grid$target_source_index), 0L)
  testthat::expect_equal(max(grid$forecast_lead), 30L)
})

testthat::test_that("frozen source series produce a complete oracle ledger", {
  source_root <- idor_v1_default_source_root()
  testthat::skip_if_not(dir.exists(source_root), "Frozen shared DGP source is unavailable")
  result <- idor_v1_build(source_root)
  testthat::expect_true(all(result$checks$pass),
                        info = paste(result$checks$detail[!result$checks$pass], collapse = "; "))
  testthat::expect_equal(nrow(result$source_registry), 9L)
  testthat::expect_equal(nrow(result$reference_ledger), 27L)
  testthat::expect_true(all(
    result$reference_ledger$plot_reference_value[
      result$reference_ledger$metric_role != "forecast_check"
    ] == 0
  ))
})

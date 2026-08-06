testthat::test_that("train-only scaling excludes held-out rows", {
  y <- c(1:5, 1000)
  X <- cbind(x = c(2:6, 2000))
  z <- qdesn_ttav2_scale_train_only(y, X, 5L)
  testthat::expect_equal(z$y_center, 3)
  testthat::expect_equal(unname(z$x_center), 4)
  testthat::expect_gt(z$y[[6L]], 100)
})

testthat::test_that("intercept correction uses only the requested training tail", {
  tr <- data.frame(effective_train = TRUE, y = 1:10, q_pred = rep(0, 10))
  testthat::expect_equal(qdesn_ttav2_intercept_shift(tr, 0.5, 4), 8.5)
})

testthat::test_that("transfer gate requires the same candidate on both sources", {
  x <- expand.grid(source_role = c("frozen_article", "untouched_confirmation"),
                   arm_code = "compact_raw", calibration_window = 180L)
  x$median_forecast_mae_ratio <- c(.94, .96)
  x$median_fit_rmse_ratio <- 1
  x$median_forecast_check_ratio <- 1
  x$worst_seed_forecast_mae_ratio <- 1.05
  testthat::expect_length(qdesn_ttav2_candidate_gate(x), 0L)
  x$median_forecast_mae_ratio <- .94
  testthat::expect_equal(qdesn_ttav2_candidate_gate(x), "compact_raw:k180")
})

testthat::test_that("exAL capability audit separates model APIs", {
  x <- qdesn_ttav2_exal_capabilities()
  testthat::expect_true(all(x$supported_in_1p0p0[x$model_lane == "exDQLM"]))
  testthat::expect_false(any(x$supported_in_1p0p0[x$model_lane == "Q-DESN exAL"]))
})

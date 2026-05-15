test_that("future model arrays satisfy the exdqlmForecast H=1000 API", {
  set.seed(1)
  model <- as.exdqlm(list(m0 = 0, C0 = matrix(1, 1, 1), FF = 1, GG = 1))
  y <- c(0.1, -0.1, 0.05, 0.2)
  fit <- exdqlmLDVB(
    y = y, p0 = 0.5, model = model, df = 1, dim.df = 1,
    dqlm.ind = TRUE, n.samp = 8, tol = 1e-3, verbose = FALSE
  )
  future <- ffv2_make_future_model_arrays(fit$model, 1000L)
  fc <- exdqlmForecast(
    start.t = length(y), k = 1000L, m1 = fit,
    fFF = future$fFF, fGG = future$fGG, plot = FALSE,
    return.draws = TRUE, n.samp = 5L, seed = 42L
  )
  expect_equal(length(fc$ff), 1000L)
  expect_equal(dim(fc$samp.fore), c(1000L, 5L))
  expect_true(all(is.finite(fc$ff)))
})

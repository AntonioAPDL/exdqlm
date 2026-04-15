test_that("dlm_df smoother tolerates nearly singular predictive covariance", {
  TT <- 5L
  GG <- array(0, dim = c(2L, 2L, TT))
  for (t in seq_len(TT)) {
    GG[, , t] <- matrix(c(1, 0.15 * t, 0, 1), 2, 2)
  }
  FF <- rbind(rep(1, TT), rep(0, TT))
  model <- list(
    m0 = c(0, 0),
    C0 = matrix(c(1, 0, 0, 0), 2, 2),
    GG = GG,
    FF = FF
  )

  fit <- dlm_df(
    y = rep(0, TT),
    model = model,
    df = c(0.98, 0.98),
    dim.df = c(1L, 1L),
    s.priors = list(l0 = 1, S0 = 1),
    just.lik = FALSE
  )

  expect_true(all(is.finite(fit$m)))
  expect_true(all(is.finite(fit$C)))
})

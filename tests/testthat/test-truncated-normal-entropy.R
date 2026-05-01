test_that("positive truncated-normal entropy uses lower-truncation sign", {
  mu <- c(-2, -0.5, 0, 0.75, 2)
  tau2 <- c(0.25, 0.8, 1, 1.5, 3)
  tau <- sqrt(tau2)
  alpha <- mu / tau
  moms <- exdqlm:::.exdqlm_pos_truncnorm_moments(mu, tau2)

  entropy_terms <- exdqlm:::.exdqlm_pos_truncnorm_entropy(
    mu, tau2, moments = moms, total = FALSE
  )
  reference_terms <- 0.5 * log(2 * pi * exp(1) * tau2) +
    log(pmax(stats::pnorm(alpha), 1e-12)) -
    0.5 * alpha * moms$Lambda
  wrong_sign_terms <- 0.5 * log(2 * pi * tau2) +
    log(pmax(moms$Phi, 1e-12)) +
    0.5 * (1 + alpha * moms$Lambda)

  expect_equal(entropy_terms, reference_terms, tolerance = 1e-12)
  expect_false(isTRUE(all.equal(entropy_terms, wrong_sign_terms)))
  expect_equal(
    exdqlm:::.exdqlm_pos_truncnorm_entropy(mu, tau2, moments = moms),
    sum(reference_terms),
    tolerance = 1e-12
  )
})

test_that("internal CRPS helper is available and finite", {
  y <- c(0, 1)
  draws <- matrix(
    c(
      -0.5, 0.0, 0.5, 1.0,
       0.5, 1.0, 1.5, 2.0
    ),
    nrow = 2,
    byrow = TRUE
  )

  out <- .exdqlm_crps_vec(y, draws)
  expect_length(out, 2L)
  expect_true(all(is.finite(out)))
  expect_true(all(out >= 0))
})

test_that("CRPS helper uses finite integrated quantile score approximation", {
  draws <- matrix(c(-1, 0, 1), nrow = 1)
  probs <- c(0.25, 0.50, 0.75)

  out <- .exdqlm_crps_vec(0, draws, probs = probs)

  qhat <- c(-0.5, 0, 0.5)
  manual <- 2 * mean(CheckLossFn(probs, 0 - qhat))
  expect_equal(out, manual, tolerance = 1e-12)
  expect_false(isTRUE(all.equal(out, .exdqlm_crps_sample_vec(0, draws))))
})

test_that("CRPS helper validates probabilities and weights", {
  draws <- matrix(c(-1, 0, 1), nrow = 1)

  expect_error(.exdqlm_crps_vec(0, draws, probs = c(0, 0.5)), "strictly between")
  expect_error(.exdqlm_crps_vec(0, draws, probs = c(0.5, 0.5)), "duplicate")
  expect_error(
    .exdqlm_crps_vec(0, draws, probs = c(0.25, 0.75), weights = 1),
    "length equal"
  )
  expect_error(
    .exdqlm_crps_vec(0, draws, probs = c(0.25, 0.75), weights = c(1, -1)),
    "non-negative"
  )

  weighted <- .exdqlm_crps_vec(
    0.25, draws,
    probs = c(0.25, 0.75),
    weights = c(1, 3)
  )
  manual <- 2 * sum(c(0.25, 0.75) * CheckLossFn(c(0.25, 0.75), 0.25 - c(-0.5, 0.5)))
  expect_equal(weighted, manual, tolerance = 1e-12)
})

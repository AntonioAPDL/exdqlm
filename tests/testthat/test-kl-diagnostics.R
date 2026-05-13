test_that("internal KL normality helper is deterministic and direction-aware", {
  x <- sqrt(2) * stats::qnorm((seq_len(80) - 0.5) / 80)

  out <- exdqlm:::.exdqlm_kl_normality_1d(x, kl_k = c(3, 5))
  out_repeat <- exdqlm:::.exdqlm_kl_normality_1d(x, kl_k = c(3, 5))

  expect_equal(out$KL, out_repeat$KL)
  expect_equal(out$KL.flip, out_repeat$KL.flip)
  expect_equal(out$KL.by_k, out_repeat$KL.by_k)
  expect_equal(out$KL.flip.by_k, out_repeat$KL.flip.by_k)
  expect_equal(out$KL, stats::median(out$KL.by_k$KL))
  expect_equal(out$KL.flip, stats::median(out$KL.flip.by_k$KL))

  expect_equal(out$KL.gaussian, 0.5 * (2 - 1 - log(2)), tolerance = 0.03)
  expect_equal(out$KL.flip.gaussian, 0.5 * (0.5 - 1 + log(2)), tolerance = 0.03)
  expect_gt(out$KL.gaussian, out$KL.flip.gaussian)
})

test_that("internal KL normality helper validates k and handles duplicate distances", {
  x <- c(rep(0, 10), seq(-1, 1, length.out = 30))

  out <- exdqlm:::.exdqlm_kl_normality_1d(x, kl_k = c(1, 3))
  expect_true(is.finite(out$KL))
  expect_true(is.finite(out$KL.flip))
  expect_gt(out$zero_distance_count, 0L)

  expect_error(exdqlm:::.exdqlm_kl_normality_1d(x, kl_k = 0), "positive finite")
  expect_error(exdqlm:::.exdqlm_kl_normality_1d(x, kl_k = c(1, 1)), "duplicate")
  expect_error(exdqlm:::.exdqlm_kl_normality_1d(x, kl_k = 1.5), "integer")
  expect_error(exdqlm:::.exdqlm_kl_normality_1d(x, kl_k = length(x)), "no larger")
})

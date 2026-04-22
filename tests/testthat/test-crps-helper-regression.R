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

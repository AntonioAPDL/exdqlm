test_that("rqr_desn_fit reuses the Q-DESN design shell and records RQR target", {
  set.seed(7301)
  y <- as.numeric(sin(seq_len(36) / 4) + 0.05 * rnorm(36))
  args <- list(
    D = 1L,
    n = 6L,
    m = 3L,
    alpha = 0.25,
    rho = 0.8,
    act_f = "tanh",
    act_k = "identity",
    pi_w = 0.3,
    pi_in = 1.0,
    washout = 3L,
    add_bias = TRUE,
    seed = 7301L
  )

  design_q <- do.call(exdqlm::qdesn_fit_vb, c(list(y = y, p0 = 0.5, fit_readout = FALSE, vb_args = list()), args))
  design_r <- do.call(exdqlm::rqr_desn_fit, c(list(y = y, coverage_level = 0.8, fit_readout = FALSE), args))

  expect_equal(design_r$X, design_q$X)
  expect_equal(design_r$y_fit, design_q$y_fit)
  expect_equal(design_r$meta$keep_idx, design_q$meta$keep_idx)
  expect_equal(design_r$meta$rqr_coverage_level, 0.8)
  expect_true(isTRUE(design_r$meta$rqr_design_only))
})

test_that("rqr_desn_fit rejects weights before Q-DESN sqrt premultiplication", {
  y <- seq_len(20)
  expect_error(
    exdqlm::rqr_desn_fit(
      y = y,
      coverage_level = 0.8,
      D = 1L,
      n = 4L,
      m = 2L,
      washout = 2L,
      weights = rep(1, length(y)),
      fit_readout = FALSE
    ),
    "rejects observation weights"
  )
})

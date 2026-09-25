testthat::test_that("redesigned independent protocol is complete and launch disabled", {
  protocol <- iqre_v1_read_protocol()
  checks <- iqre_v1_protocol_checks(protocol)
  testthat::expect_true(all(checks$pass), info = paste(
    checks$check[!checks$pass], collapse = ", "
  ))
  testthat::expect_false(protocol$protocol$launch_enabled)
  testthat::expect_identical(
    protocol$protocol$supersession_decision,
    "SUPERSEDED_BY_REDESIGNED_INDEPENDENT_PROTOCOL"
  )
})
testthat::test_that("connectivity holds expected recurrent degree fixed", {
  widths <- c(20L, 100L, 200L, 300L)
  pi <- iqre_v1_expected_pi_w(widths, expected_indegree = 10)
  testthat::expect_equal(pi, c(.5, .1, .05, 1 / 30))
  testthat::expect_equal(widths * pi, rep(10, length(widths)))
})

testthat::test_that("identity Q preserves every layer in the readout", {
  withr::local_seed(910001)
  y <- 20 + sin(seq_len(100L) / 8) + stats::rnorm(100L, sd = .1)
  shape <- iqre_v1_identity_projection_args(c(7L, 5L, 4L))
  fit <- qdesn_fit_vb(
    y = y, p0 = .25, D = shape$D, n = shape$n,
    n_tilde = shape$n_tilde, m = 3L, standardize_inputs = TRUE,
    alpha = .4, rho = rep(.8, shape$D), act_f = "tanh",
    act_k = "identity", pi_w = iqre_v1_expected_pi_w(shape$n),
    pi_in = 1, w_dist = function(n) stats::runif(n, -1, 1),
    in_dist = function(n) stats::runif(n, -1, 1), washout = 5L,
    add_bias = TRUE, seed = 910001L, fit_readout = FALSE
  )
  contract <- iqre_v1_assert_identity_projection(fit)
  testthat::expect_identical(contract$n_tilde, c(7L, 5L))
  testthat::expect_equal(contract$readout_columns, 17L)
  testthat::expect_true(all(fit$reservoir$Q_is_identity))
})

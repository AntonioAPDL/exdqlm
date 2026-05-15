make_state_resid_y_cfg <- function() {
  list(
    enabled = TRUE,
    backend = "r",
    state_estimate = "filtered",
    components = c("trend", "seasonal", "residual"),
    trend = list(degree = 1L),
    seasonal = list(period = 12, harmonics = c(1L, 2L)),
    input_builder = "state_resid_y",
    input_lags = list(trend = 2L, seasonal = 2L, residual = 3L),
    state_resid_y = list(
      state_lags = 2L,
      residual_lags = 3L,
      y_lags = 4L,
      include_xreg = FALSE,
      xreg_lags = 0L
    ),
    discount = list(trend = 0.98, seasonal = 0.97),
    variance = list(mode = "unknown_constant", l0 = 2, S0 = 1),
    forecast = list(residual_recursion = "sampled_path")
  )
}

test_that("state_resid_y builder is normalized and retained", {
  info <- exdqlm:::.qdesn_resolve_input_mode_scaffold(
    input_mode = "dlm_decomp_lags",
    decomposition = make_state_resid_y_cfg(),
    m_default = 12L,
    context = "test"
  )

  expect_identical(info$input_mode_effective, "dlm_decomp_lags")
  expect_identical(info$decomposition$input_builder, "state_resid_y")
  expect_identical(info$decomposition$state_resid_y$state_lags, 2L)
  expect_identical(info$decomposition$state_resid_y$residual_lags, 3L)
  expect_identical(info$decomposition$state_resid_y$y_lags, 4L)
  expect_false(isTRUE(info$decomposition$state_resid_y$include_xreg))
})

test_that("state_resid_y lag vector ordering matches [alpha lags | residual lags | y lags]", {
  withr::local_seed(20260324)

  tt <- seq_len(140L)
  y <- as.numeric(1.5 + 0.01 * tt + sin(2 * pi * tt / 12) + stats::rnorm(length(tt), sd = 0.05))

  info <- exdqlm:::.qdesn_resolve_input_mode_scaffold(
    input_mode = "dlm_decomp_lags",
    decomposition = make_state_resid_y_cfg(),
    m_default = 5L,
    context = "test"
  )
  runtime <- exdqlm:::.qdesn_prepare_decomposition_runtime(y, info$decomposition, context = "test")

  expect_identical(runtime$input_builder, "state_resid_y")

  tau <- 25L
  buffers <- exdqlm:::.qdesn_init_decomp_input_buffers(runtime, tau = tau)
  vec <- exdqlm:::.qdesn_decomp_input_vector(buffers, runtime)

  n_state <- ncol(runtime$state_effective)
  Ls <- runtime$state_resid_y_lags$state
  Lr <- runtime$state_resid_y_lags$residual
  Ly <- runtime$state_resid_y_lags$y

  expected_state <- unlist(lapply(seq_len(Ls), function(k) runtime$state_effective[tau - (k - 1L), ]), use.names = FALSE)
  expected_resid <- as.numeric(runtime$series$residual[seq.int(tau, tau - Lr + 1L, by = -1L)])
  expected_y <- as.numeric(runtime$y[seq.int(tau, tau - Ly + 1L, by = -1L)])
  expected <- c(expected_state, expected_resid, expected_y)

  expect_equal(length(vec), length(expected))
  expect_equal(vec, expected, tolerance = 1e-10)

  expect_equal(runtime$m_input, as.integer(Ls * n_state + Lr + Ly))
})

test_that("state_resid_y forecast recursion runs and uses R backend when cpp postpred is requested", {
  withr::local_seed(20260325)
  withr::local_options(list(
    exdqlm.use_cpp_postpred = TRUE,
    exdqlm.use_cpp_postpred_omp = FALSE,
    exdqlm.use_cpp_postpred_precompute = FALSE
  ))

  tt <- seq_len(160L)
  y <- as.numeric(2.0 + 0.02 * tt + sin(2 * pi * tt / 12) + stats::rnorm(length(tt), sd = 0.08))

  fit <- exdqlm:::qdesn_fit_vb(
    y = y,
    p0 = 0.5,
    D = 1L,
    n = 14L,
    n_tilde = integer(0),
    m = 4L,
    alpha = 0.2,
    rho = 0.9,
    pi_w = 1.0,
    pi_in = 1.0,
    washout = 6L,
    add_bias = TRUE,
    seed = 1234,
    fit_readout = TRUE,
    input_mode = "dlm_decomp_lags",
    decomposition = make_state_resid_y_cfg(),
    vb_args = list(max_iter = 8L, min_iter_elbo = 2L, tol = 1e-3, tol_par = 1e-3, verbose = FALSE)
  )

  expect_identical(fit$meta$input_mode_effective, "dlm_decomp_lags")
  expect_identical(fit$states$decomposition$input_builder, "state_resid_y")

  fc <- exdqlm:::forecast_paths.qdesn_fit(
    object = fit,
    H = 5L,
    nd = 12L,
    chunk = 6L,
    seed = 99L
  )

  expect_identical(attr(fc, "backend"), "r")
  expect_equal(dim(fc$yrep), c(5L, 12L))
  expect_equal(dim(fc$mu_draws), c(5L, 12L))
  expect_true(all(is.finite(fc$yrep)))
  expect_true(all(is.finite(fc$mu_draws)))
})

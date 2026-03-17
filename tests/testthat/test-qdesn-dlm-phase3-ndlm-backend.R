make_ndlm_fixture <- function(T_len = 96L) {
  trend <- polytrendMod(order = 2L, m0 = c(0, 0), C0 = diag(100, 2))
  seasonal <- seasMod(p = 12, h = c(1L, 2L), m0 = rep(0, 4), C0 = diag(100, 4))
  model <- combineMods(trend, seasonal)
  model <- check_mod(model)

  n_state <- length(model$m0)
  if (is.null(dim(model$GG)[3]) || is.na(dim(model$GG)[3])) {
    model$GG <- array(as.matrix(model$GG), dim = c(n_state, n_state, T_len))
  }
  if (ncol(model$FF) == 1L) {
    model$FF <- matrix(model$FF[, 1L], nrow = n_state, ncol = T_len)
  }

  list(
    model = model,
    df = c(0.98, 0.97),
    dim_df = c(2L, 4L),
    l0 = 2,
    S0 = 1.5
  )
}

make_ndlm_data <- function(T_len = 96L) {
  tt <- seq_len(T_len)
  as.numeric(1.0 + 0.02 * tt + 0.5 * sin(2 * pi * tt / 12) + stats::rnorm(T_len, sd = 0.15))
}

test_that("R NDLM filter matches legacy dlm_df filtered moments", {
  withr::local_seed(1001)
  fixture <- make_ndlm_fixture(90L)
  y <- make_ndlm_data(90L)

  ref <- dlm_df(
    y = y,
    model = fixture$model,
    df = fixture$df,
    dim.df = fixture$dim_df,
    s.priors = list(l0 = fixture$l0, S0 = fixture$S0),
    just.lik = FALSE
  )

  expanded <- exdqlm:::.qdesn_expand_state_space(fixture$model, T_len = length(y), context = "test")
  fit_r <- exdqlm:::qdesn_ndlm_filter_smooth(
    y = y,
    FF = expanded$FF,
    GG = expanded$GG,
    m0 = expanded$m0,
    C0 = expanded$C0,
    df = fixture$df,
    dim_df = fixture$dim_df,
    l0 = fixture$l0,
    S0 = fixture$S0,
    backend = "r",
    compute_smoothed = TRUE,
    return_intermediates = TRUE,
    jitter = 1e-10
  )

  expect_identical(fit_r$backend, "r")
  expect_equal(fit_r$fm, ref$fm, tolerance = 1e-9)
  expect_equal(fit_r$fC, ref$fC, tolerance = 1e-9)
  expect_equal(fit_r$s, ref$s, tolerance = 1e-10)
  expect_equal(fit_r$n, ref$n, tolerance = 1e-10)

  expect_true(is.matrix(fit_r$sm))
  expect_equal(dim(fit_r$sm), dim(fit_r$fm))
  expect_true(is.array(fit_r$sC))
  expect_equal(dim(fit_r$sC), dim(fit_r$fC))
  expect_true(all(is.finite(fit_r$sm)))
  expect_true(all(is.finite(fit_r$sC)))
})

test_that("CPP NDLM backend matches R backend for filter and smoother outputs", {
  withr::local_seed(1002)
  fixture <- make_ndlm_fixture(92L)
  y <- make_ndlm_data(92L)
  expanded <- exdqlm:::.qdesn_expand_state_space(fixture$model, T_len = length(y), context = "test")

  fit_r <- exdqlm:::qdesn_ndlm_filter_smooth(
    y = y,
    FF = expanded$FF,
    GG = expanded$GG,
    m0 = expanded$m0,
    C0 = expanded$C0,
    df = fixture$df,
    dim_df = fixture$dim_df,
    l0 = fixture$l0,
    S0 = fixture$S0,
    backend = "r",
    compute_smoothed = TRUE,
    return_intermediates = TRUE,
    jitter = 1e-10
  )

  fit_cpp <- exdqlm:::qdesn_ndlm_filter_smooth(
    y = y,
    FF = expanded$FF,
    GG = expanded$GG,
    m0 = expanded$m0,
    C0 = expanded$C0,
    df = fixture$df,
    dim_df = fixture$dim_df,
    l0 = fixture$l0,
    S0 = fixture$S0,
    backend = "cpp",
    compute_smoothed = TRUE,
    return_intermediates = TRUE,
    jitter = 1e-10
  )

  expect_identical(fit_cpp$backend, "cpp")
  expect_equal(fit_cpp$fm, fit_r$fm, tolerance = 1e-8)
  expect_equal(fit_cpp$fC, fit_r$fC, tolerance = 1e-8)
  expect_equal(fit_cpp$sm, fit_r$sm, tolerance = 1e-8)
  expect_equal(fit_cpp$sC, fit_r$sC, tolerance = 1e-7)
  expect_equal(fit_cpp$a, fit_r$a, tolerance = 1e-8)
  expect_equal(fit_cpp$R_unscaled, fit_r$R_unscaled, tolerance = 1e-8)
  expect_equal(fit_cpp$C_unscaled, fit_r$C_unscaled, tolerance = 1e-8)
  expect_equal(fit_cpp$Q_unscaled, fit_r$Q_unscaled, tolerance = 1e-9)
  expect_equal(fit_cpp$f, fit_r$f, tolerance = 1e-9)
  expect_equal(fit_cpp$e, fit_r$e, tolerance = 1e-9)
  expect_equal(fit_cpp$K, fit_r$K, tolerance = 1e-8)

  tau <- 70L
  tr_r <- exdqlm:::qdesn_ndlm_structured_forecast(
    GG = expanded$GG,
    FF = expanded$FF,
    state_origin = fit_r$fm[tau, ],
    idx_trend = 1:2,
    idx_seasonal = 3:6,
    origin_index = tau,
    H = 8L,
    backend = "r"
  )
  tr_cpp <- exdqlm:::qdesn_ndlm_structured_forecast(
    GG = expanded$GG,
    FF = expanded$FF,
    state_origin = fit_r$fm[tau, ],
    idx_trend = 1:2,
    idx_seasonal = 3:6,
    origin_index = tau,
    H = 8L,
    backend = "cpp"
  )

  expect_identical(tr_cpp$backend, "cpp")
  expect_equal(tr_cpp$trend, tr_r$trend, tolerance = 1e-9)
  expect_equal(tr_cpp$seasonal, tr_r$seasonal, tolerance = 1e-9)
  expect_equal(tr_cpp$structured, tr_r$structured, tolerance = 1e-9)
  expect_equal(tr_cpp$state_last, tr_r$state_last, tolerance = 1e-8)
})

test_that("qdesn decomposition mode uses cpp backend when requested", {
  withr::local_seed(1003)
  withr::local_options(list(exdqlm.use_cpp_postpred = FALSE))

  tt <- seq_len(140)
  y <- as.numeric(2 + 0.015 * tt + sin(2 * pi * tt / 12) + stats::rnorm(140, sd = 0.1))

  decomp_cfg <- list(
    enabled = TRUE,
    backend = "cpp",
    state_estimate = "filtered",
    components = c("trend", "seasonal", "residual"),
    trend = list(degree = 1L),
    seasonal = list(period = 12, harmonics = c(1L, 2L)),
    input_lags = list(trend = 3L, seasonal = 2L, residual = 3L),
    discount = list(trend = 0.98, seasonal = 0.97),
    variance = list(mode = "unknown_constant", l0 = 2, S0 = 1),
    forecast = list(residual_recursion = "sampled_path")
  )

  fit <- exdqlm:::qdesn_fit_vb(
    y = y,
    p0 = 0.5,
    D = 1L,
    n = 12L,
    n_tilde = integer(0),
    m = 4L,
    alpha = 0.2,
    rho = 0.9,
    pi_w = 1.0,
    pi_in = 1.0,
    washout = 5L,
    add_bias = TRUE,
    seed = 123,
    fit_readout = TRUE,
    input_mode = "dlm_decomp_lags",
    decomposition = decomp_cfg,
    vb_args = list(max_iter = 8L, min_iter_elbo = 2L, tol = 1e-3, tol_par = 1e-3, verbose = FALSE)
  )

  expect_identical(fit$meta$input_mode_effective, "dlm_decomp_lags")
  expect_identical(fit$meta$decomposition$backend_effective, "cpp")
  expect_identical(fit$states$decomposition$backend_effective, "cpp")

  tr <- exdqlm:::.qdesn_decomp_forecast_trajectory(
    runtime = fit$states$decomposition,
    origin_index = 110L,
    H = 5L,
    context = "test"
  )
  expect_identical(tr$backend, "cpp")

  readout_spec <- list(
    include_input = FALSE,
    input_position = "after_reservoir",
    input_mode_requested = "dlm_decomp_lags",
    input_mode_effective = "dlm_decomp_lags",
    input_mode = "dlm_decomp_lags",
    decomposition = decomp_cfg,
    input_lags_y = integer(0),
    input_lags_x = list(),
    reservoir_lags = 0L,
    y_lags = integer(0),
    x_names = character(0),
    x_lags = list(),
    p_res = ncol(fit$X),
    scale_info = NULL
  )

  out <- exdqlm:::forecast_paths.qdesn_fit(
    object = fit,
    H = 4L,
    nd = 12L,
    readout_spec = readout_spec,
    origin_index = 110L,
    seed = 99L
  )

  expect_equal(dim(out$yrep), c(4L, 12L))
  expect_equal(dim(out$mu_draws), c(4L, 12L))
  expect_true(all(is.finite(out$mu_draws)))
})

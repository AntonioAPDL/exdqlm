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

test_that("CPP extended NDLM component forecast matches R backend", {
  withr::local_seed(1005)

  tt <- seq_len(120L)
  X <- cbind(
    x_reg = sin(2 * pi * tt / 15),
    x_tf = cos(2 * pi * tt / 21)
  )
  y <- as.numeric(
    1.2 + 0.02 * tt +
      0.5 * sin(2 * pi * tt / 12) +
      0.3 * X[, "x_reg"] +
      stats::rnorm(length(tt), sd = 0.1)
  )

  decomp_cfg <- list(
    enabled = TRUE,
    backend = "cpp",
    state_estimate = "filtered",
    components = c("trend", "seasonal", "regression", "transfer", "residual"),
    trend = list(degree = 0L),
    seasonal = list(period = 12, harmonics = c(1L, 2L)),
    regression = list(enabled = TRUE, x_cols = "x_reg"),
    transfer = list(enabled = TRUE, x_cols = "x_tf", lambda = 0.9),
    input_lags = list(trend = 2L, seasonal = 2L, regression = 2L, transfer = 2L, residual = 2L),
    discount = list(trend = 0.99, seasonal = 0.98, regression = 1.0, transfer_zeta = 0.98, transfer_psi = 1.0),
    variance = list(mode = "unknown_constant", l0 = 2, S0 = 1)
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
    washout = 6L,
    add_bias = TRUE,
    seed = 2222,
    fit_readout = TRUE,
    input_mode = "dlm_decomp_lags",
    decomposition = decomp_cfg,
    decomposition_xreg = X,
    vb_args = list(max_iter = 10L, min_iter_elbo = 2L, tol = 1e-3, tol_par = 1e-3, verbose = FALSE)
  )

  runtime <- fit$states$decomposition
  tau <- 100L
  H <- 7L

  fc_r <- exdqlm:::qdesn_ndlm_component_forecast(
    GG = runtime$model$GG,
    FF = runtime$model$FF,
    state_origin = runtime$state_filtered[tau, ],
    idx_trend = runtime$idx$trend,
    idx_seasonal = runtime$idx$seasonal,
    idx_regression = runtime$idx$regression,
    idx_transfer = runtime$idx$transfer,
    origin_index = tau,
    H = H,
    backend = "r"
  )
  fc_cpp <- exdqlm:::qdesn_ndlm_component_forecast(
    GG = runtime$model$GG,
    FF = runtime$model$FF,
    state_origin = runtime$state_filtered[tau, ],
    idx_trend = runtime$idx$trend,
    idx_seasonal = runtime$idx$seasonal,
    idx_regression = runtime$idx$regression,
    idx_transfer = runtime$idx$transfer,
    origin_index = tau,
    H = H,
    backend = "cpp"
  )

  expect_identical(fc_cpp$backend, "cpp")
  expect_equal(fc_cpp$trend, fc_r$trend, tolerance = 1e-9)
  expect_equal(fc_cpp$seasonal, fc_r$seasonal, tolerance = 1e-9)
  expect_equal(fc_cpp$regression, fc_r$regression, tolerance = 1e-9)
  expect_equal(fc_cpp$transfer, fc_r$transfer, tolerance = 1e-9)
  expect_equal(fc_cpp$structured, fc_r$structured, tolerance = 1e-9)
  expect_equal(fc_cpp$state_last, fc_r$state_last, tolerance = 1e-8)
})

test_that("CPP extended NDLM component forecast validates component indices", {
  fixture <- make_ndlm_fixture(60L)
  expanded <- exdqlm:::.qdesn_expand_state_space(fixture$model, T_len = 60L, context = "test")
  n_state <- nrow(expanded$FF)

  expect_error(
    exdqlm:::dlm_ndlm_component_forecast_cpp(
      GG = expanded$GG,
      FF = expanded$FF,
      state_origin = as.numeric(expanded$m0),
      idx_trend = as.integer(c(0L)),
      idx_seasonal = as.integer(c(1L)),
      idx_regression = as.integer(c(2L)),
      idx_transfer = as.integer(c(n_state + 2L)),
      origin_index = 10L,
      H = 4L
    ),
    "idx_transfer index out of range"
  )
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

test_that("decomposition forecast_paths cpp matches r with fixed noise draws", {
  withr::local_seed(1004)

  tt <- seq_len(150)
  y <- as.numeric(2.5 + 0.01 * tt + 0.7 * sin(2 * pi * tt / 12) + stats::rnorm(150, sd = 0.1))

  decomp_cfg <- list(
    enabled = TRUE,
    backend = "cpp",
    state_estimate = "filtered",
    components = c("trend", "seasonal", "residual"),
    trend = list(degree = 0L),
    seasonal = list(period = 12, harmonics = c(1L, 2L)),
    input_lags = list(trend = 4L, seasonal = 4L, residual = 4L),
    discount = list(trend = 0.98, seasonal = 0.97),
    variance = list(mode = "unknown_constant", l0 = 2, S0 = 1)
  )

  fit <- exdqlm:::qdesn_fit_vb(
    y = y,
    p0 = 0.5,
    D = 1L,
    n = 14L,
    n_tilde = integer(0),
    m = 5L,
    alpha = 0.2,
    rho = 0.9,
    pi_w = 1.0,
    pi_in = 1.0,
    washout = 8L,
    add_bias = TRUE,
    seed = 222,
    fit_readout = TRUE,
    input_mode = "dlm_decomp_lags",
    decomposition = decomp_cfg,
    vb_args = list(max_iter = 12L, min_iter_elbo = 2L, tol = 1e-3, tol_par = 1e-3, verbose = FALSE)
  )

  nd <- 18L
  H <- 6L
  origin_index <- 120L
  draws <- exdqlm::exal_posterior_draws(fit$fit, nd = nd)

  withr::local_seed(44)
  noise_draws <- list(
    s = matrix(abs(stats::rnorm(H * nd)), nrow = H, ncol = nd),
    v = matrix(abs(stats::rnorm(H * nd)) + 0.1, nrow = H, ncol = nd),
    z = matrix(stats::rnorm(H * nd), nrow = H, ncol = nd)
  )

  run_case <- function(residual_recursion) {
    readout_spec <- list(
      include_input = FALSE,
      input_position = "after_reservoir",
      input_mode_requested = "dlm_decomp_lags",
      input_mode_effective = "dlm_decomp_lags",
      input_mode = "dlm_decomp_lags",
      decomposition = utils::modifyList(decomp_cfg, list(forecast = list(residual_recursion = residual_recursion))),
      input_lags_y = integer(0),
      input_lags_x = list(),
      reservoir_lags = 0L,
      y_lags = integer(0),
      x_names = character(0),
      x_lags = list(),
      p_res = ncol(fit$X),
      scale_info = NULL
    )

    withr::local_options(list(
      exdqlm.use_cpp_postpred = FALSE,
      exdqlm.use_cpp_postpred_precompute = FALSE,
      exdqlm.use_cpp_postpred_omp = FALSE
    ))
    out_r <- exdqlm:::forecast_paths.qdesn_fit(
      object = fit,
      H = H,
      nd = nd,
      readout_spec = readout_spec,
      origin_index = origin_index,
      draws = draws,
      noise_draws = noise_draws,
      seed = 999
    )

    withr::local_options(list(
      exdqlm.use_cpp_postpred = TRUE,
      exdqlm.use_cpp_postpred_precompute = FALSE,
      exdqlm.use_cpp_postpred_omp = FALSE
    ))
    out_cpp <- exdqlm:::forecast_paths.qdesn_fit(
      object = fit,
      H = H,
      nd = nd,
      readout_spec = readout_spec,
      origin_index = origin_index,
      draws = draws,
      noise_draws = noise_draws,
      seed = 999
    )

    expect_identical(attr(out_r, "backend"), "r")
    expect_identical(attr(out_cpp, "backend"), "cpp")
    expect_equal(out_cpp$mu_draws, out_r$mu_draws, tolerance = 1e-10)
    expect_equal(out_cpp$yrep, out_r$yrep, tolerance = 1e-10)
  }

  run_case("sampled_path")
  run_case("deterministic_plugin")
})

test_that("decomposition forecast_paths cpp matches r with regression and transfer components", {
  withr::local_seed(3001)

  tt <- seq_len(180L)
  X <- cbind(
    x_reg = sin(2 * pi * tt / 18),
    x_tf = cos(2 * pi * tt / 27)
  )
  y <- as.numeric(
    1.8 + 0.01 * tt +
      0.8 * sin(2 * pi * tt / 12) +
      0.4 * X[, "x_reg"] +
      stats::rnorm(length(tt), sd = 0.08)
  )

  decomp_cfg <- list(
    enabled = TRUE,
    backend = "cpp",
    state_estimate = "filtered",
    components = c("trend", "seasonal", "regression", "transfer", "residual"),
    trend = list(degree = 0L),
    seasonal = list(period = 12, harmonics = c(1L, 2L)),
    regression = list(enabled = TRUE, x_cols = "x_reg"),
    transfer = list(enabled = TRUE, x_cols = "x_tf", lambda = 0.92),
    input_lags = list(trend = 2L, seasonal = 2L, regression = 2L, transfer = 2L, residual = 2L),
    discount = list(trend = 0.99, seasonal = 0.98, regression = 1.0, transfer_zeta = 0.98, transfer_psi = 1.0),
    variance = list(mode = "unknown_constant", l0 = 2, S0 = 1),
    forecast = list(residual_recursion = "sampled_path")
  )

  fit <- exdqlm:::qdesn_fit_vb(
    y = y,
    p0 = 0.5,
    D = 1L,
    n = 14L,
    n_tilde = integer(0),
    m = 5L,
    alpha = 0.2,
    rho = 0.9,
    pi_w = 1.0,
    pi_in = 1.0,
    washout = 8L,
    add_bias = TRUE,
    seed = 333,
    fit_readout = TRUE,
    input_mode = "dlm_decomp_lags",
    decomposition = decomp_cfg,
    decomposition_xreg = X,
    vb_args = list(max_iter = 12L, min_iter_elbo = 2L, tol = 1e-3, tol_par = 1e-3, verbose = FALSE)
  )

  nd <- 16L
  H <- 5L
  origin_index <- 140L
  draws <- exdqlm::exal_posterior_draws(fit$fit, nd = nd)
  withr::local_seed(3002)
  noise_draws <- list(
    s = matrix(abs(stats::rnorm(H * nd)), nrow = H, ncol = nd),
    v = matrix(abs(stats::rnorm(H * nd)) + 0.1, nrow = H, ncol = nd),
    z = matrix(stats::rnorm(H * nd), nrow = H, ncol = nd)
  )

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

  withr::local_options(list(
    exdqlm.use_cpp_postpred = FALSE,
    exdqlm.use_cpp_postpred_precompute = FALSE,
    exdqlm.use_cpp_postpred_omp = FALSE
  ))
  out_r <- exdqlm:::forecast_paths.qdesn_fit(
    object = fit,
    H = H,
    nd = nd,
    readout_spec = readout_spec,
    origin_index = origin_index,
    draws = draws,
    noise_draws = noise_draws,
    seed = 111
  )

  withr::local_options(list(
    exdqlm.use_cpp_postpred = TRUE,
    exdqlm.use_cpp_postpred_precompute = FALSE,
    exdqlm.use_cpp_postpred_omp = FALSE
  ))
  out_cpp <- exdqlm:::forecast_paths.qdesn_fit(
    object = fit,
    H = H,
    nd = nd,
    readout_spec = readout_spec,
    origin_index = origin_index,
    draws = draws,
    noise_draws = noise_draws,
    seed = 111
  )

  expect_identical(attr(out_r, "backend"), "r")
  expect_identical(attr(out_cpp, "backend"), "cpp")
  expect_equal(out_cpp$mu_draws, out_r$mu_draws, tolerance = 1e-10)
  expect_equal(out_cpp$yrep, out_r$yrep, tolerance = 1e-10)
})

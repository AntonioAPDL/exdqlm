make_phase2_decomp_cfg <- function(residual_recursion = "sampled_path") {
  list(
    enabled = TRUE,
    backend = "r",
    state_estimate = "filtered",
    components = c("trend", "seasonal", "residual"),
    trend = list(degree = 1L),
    seasonal = list(period = 12, harmonics = c(1L, 2L)),
    input_lags = list(trend = 3L, seasonal = 2L, residual = 4L),
    discount = list(trend = 0.98, seasonal = 0.97),
    variance = list(mode = "unknown_constant", l0 = 2, S0 = 1),
    forecast = list(residual_recursion = residual_recursion)
  )
}

test_that("input mode resolver keeps decomposition mode active in phase 2", {
  withr::local_options(list(
    exdqlm.warned_dlm_smoothed_predictive = TRUE
  ))

  info <- exdqlm:::.qdesn_resolve_input_mode_scaffold(
    input_mode = "dlm_decomp_lags",
    decomposition = list(
      enabled = TRUE,
      backend = "cpp",
      state_estimate = "smoothed",
      trend = list(degree = 2L),
      seasonal = list(period = 12, harmonics = c(1L, 2L)),
      input_lags = list(trend = 5L, seasonal = 6L, residual = 7L),
      variance = list(mode = "unknown_constant", l0 = 3, S0 = 4)
    ),
    m_default = 4L,
    context = "test"
  )

  expect_identical(info$input_mode_requested, "dlm_decomp_lags")
  expect_identical(info$input_mode_effective, "dlm_decomp_lags")
  expect_true(isTRUE(info$decomposition$enabled))
  expect_identical(info$decomposition$backend_effective, "cpp")
  expect_identical(info$decomposition$state_estimate_effective, "filtered")
  expect_identical(info$decomposition$trend$degree, 2L)
  expect_equal(info$decomposition$seasonal$period, 12)
  expect_equal(info$decomposition$seasonal$harmonics, c(1, 2))
  expect_identical(info$decomposition$input_lags$trend, 5L)
  expect_identical(info$decomposition$input_lags$seasonal, 6L)
  expect_identical(info$decomposition$input_lags$residual, 7L)
  expect_identical(info$decomposition$variance$l0, 3)
  expect_identical(info$decomposition$variance$S0, 4)
})

test_that("decomposition lag mode defaults to component-only and ignores m_default", {
  withr::local_options(list(
    exdqlm.warned_dlm_smoothed_predictive = TRUE
  ))

  info <- exdqlm:::.qdesn_resolve_input_mode_scaffold(
    input_mode = "dlm_decomp_lags",
    decomposition = list(
      enabled = TRUE,
      backend = "r",
      state_estimate = "smoothed",
      trend = list(degree = 1L),
      seasonal = list(period = 12, harmonics = c(1L, 2L))
    ),
    m_default = 30L,
    context = "test"
  )

  expect_identical(info$decomposition$input_lags_mode, "component")
  expect_identical(info$decomposition$input_lags$trend, 12L)
  expect_identical(info$decomposition$input_lags$seasonal, 12L)
  expect_identical(info$decomposition$input_lags$residual, 12L)
})

test_that("decomposition lag mode inherit_m uses m_default for missing components", {
  info <- exdqlm:::.qdesn_resolve_input_mode_scaffold(
    input_mode = "dlm_decomp_lags",
    decomposition = list(
      enabled = TRUE,
      backend = "r",
      state_estimate = "filtered",
      input_lags_mode = "inherit_m",
      input_lags = list(trend = 5L)
    ),
    m_default = 30L,
    context = "test"
  )

  expect_identical(info$decomposition$input_lags_mode, "inherit_m")
  expect_identical(info$decomposition$input_lags$trend, 5L)
  expect_identical(info$decomposition$input_lags$seasonal, 30L)
  expect_identical(info$decomposition$input_lags$residual, 30L)
})

test_that("seasonal auto-harmonic selection picks dominant harmonics for fixed period", {
  withr::local_seed(20260317)

  tt <- seq_len(240L)
  y <- as.numeric(
    1.5 * sin(2 * pi * 2 * tt / 12) +
      1.1 * sin(2 * pi * 4 * tt / 12) +
      stats::rnorm(length(tt), sd = 0.05)
  )

  info <- exdqlm:::.qdesn_resolve_input_mode_scaffold(
    input_mode = "dlm_decomp_lags",
    decomposition = list(
      enabled = TRUE,
      backend = "r",
      state_estimate = "filtered",
      components = c("trend", "seasonal", "residual"),
      trend = list(degree = 0L),
      seasonal = list(
        period = 12,
        harmonics = integer(0),
        auto = list(
          enabled = TRUE,
          top_k = 2L,
          min_harmonic = 1L,
          max_harmonic = 6L,
          use_log_score = TRUE,
          center = TRUE,
          prefer_manual = TRUE
        )
      ),
      input_lags = list(trend = 2L, seasonal = 2L, residual = 2L),
      discount = list(trend = 0.99, seasonal = 0.99),
      variance = list(mode = "unknown_constant", l0 = 2, S0 = 1)
    ),
    m_default = 2L,
    context = "test"
  )

  runtime <- exdqlm:::.qdesn_prepare_decomposition_runtime(y, info$decomposition, context = "test")
  expect_identical(runtime$seasonal$harmonics_source, "auto_spectral")
  expect_equal(length(runtime$seasonal$harmonics_effective), 2L)
  expect_true(all(c(2L, 4L) %in% runtime$seasonal$harmonics_effective))
  expect_false(is.null(runtime$seasonal$auto_selection))
  expect_true(is.data.frame(runtime$seasonal$auto_selection$ranking))
})

test_that("manual seasonal harmonics can be preferred over auto selection", {
  withr::local_seed(20260318)

  tt <- seq_len(180L)
  y <- as.numeric(
    1.2 * sin(2 * pi * 2 * tt / 12) +
      0.9 * sin(2 * pi * 4 * tt / 12) +
      stats::rnorm(length(tt), sd = 0.05)
  )

  info <- exdqlm:::.qdesn_resolve_input_mode_scaffold(
    input_mode = "dlm_decomp_lags",
    decomposition = list(
      enabled = TRUE,
      backend = "r",
      state_estimate = "filtered",
      components = c("trend", "seasonal", "residual"),
      trend = list(degree = 0L),
      seasonal = list(
        period = 12,
        harmonics = c(1L, 3L),
        auto = list(
          enabled = TRUE,
          top_k = 2L,
          min_harmonic = 1L,
          max_harmonic = 6L,
          prefer_manual = TRUE
        )
      ),
      input_lags = list(trend = 2L, seasonal = 2L, residual = 2L),
      discount = list(trend = 0.99, seasonal = 0.99),
      variance = list(mode = "unknown_constant", l0 = 2, S0 = 1)
    ),
    m_default = 2L,
    context = "test"
  )

  runtime <- exdqlm:::.qdesn_prepare_decomposition_runtime(y, info$decomposition, context = "test")
  expect_identical(runtime$seasonal$harmonics_source, "manual_preferred_over_auto")
  expect_equal(runtime$seasonal$harmonics_effective, c(1, 3))
})

test_that("manual seasonal harmonics can include values smaller than 1", {
  withr::local_seed(20260320)

  tt <- seq_len(240L)
  period <- 363.5854
  harmonics_manual <- c(1, 2, 0.1469108476)
  y <- as.numeric(
    0.8 * sin(2 * pi * harmonics_manual[1] * tt / period) +
      0.6 * sin(2 * pi * harmonics_manual[2] * tt / period) +
      0.4 * sin(2 * pi * harmonics_manual[3] * tt / period) +
      stats::rnorm(length(tt), sd = 0.03)
  )

  info <- exdqlm:::.qdesn_resolve_input_mode_scaffold(
    input_mode = "dlm_decomp_lags",
    decomposition = list(
      enabled = TRUE,
      backend = "r",
      state_estimate = "filtered",
      components = c("trend", "seasonal", "residual"),
      trend = list(degree = 0L),
      seasonal = list(
        period = period,
        harmonics = harmonics_manual
      ),
      input_lags = list(trend = 2L, seasonal = 2L, residual = 2L),
      discount = list(trend = 0.99, seasonal = 0.99),
      variance = list(mode = "unknown_constant", l0 = 2, S0 = 1)
    ),
    m_default = 2L,
    context = "test"
  )

  runtime <- exdqlm:::.qdesn_prepare_decomposition_runtime(y, info$decomposition, context = "test")
  expect_identical(runtime$seasonal$harmonics_source, "manual")
  expect_equal(runtime$seasonal$harmonics_effective, sort(harmonics_manual), tolerance = 1e-12)
  expect_true(any(runtime$seasonal$harmonics_effective < 1))
})

test_that("qdesn_fit_vb builds decomposition runtime and input width", {
  withr::local_seed(123)

  tt <- seq_len(120)
  y <- as.numeric(2 + 0.02 * tt + sin(2 * pi * tt / 12) + stats::rnorm(120, sd = 0.08))
  decomp_cfg <- make_phase2_decomp_cfg()

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
    washout = 5L,
    add_bias = TRUE,
    seed = 42L,
    fit_readout = FALSE,
    standardize_inputs = TRUE,
    input_mode = "dlm_decomp_lags",
    decomposition = decomp_cfg
  )

  expect_identical(fit$meta$input_mode_effective, "dlm_decomp_lags")
  expect_identical(fit$meta$input_mode, "dlm_decomp_lags")
  expect_equal(fit$meta$m_input, 9L)
  expect_equal(fit$meta$input_lag_warmup, 4L)
  expect_equal(length(fit$meta$lag_center), fit$meta$m_input)
  expect_equal(length(fit$meta$lag_scale), fit$meta$m_input)

  expect_false(is.null(fit$states$decomposition))
  expect_equal(length(fit$states$decomposition$series$trend), length(y))
  expect_equal(length(fit$states$decomposition$series$seasonal), length(y))
  expect_equal(length(fit$states$decomposition$series$residual), length(y))
  expect_identical(fit$states$decomposition$input_components, c("trend", "seasonal", "residual"))
})

test_that("qdesn decomposition runtime supports regression and transfer components", {
  withr::local_seed(90210)

  tt <- seq_len(160L)
  x1 <- sin(2 * pi * tt / 20)
  x2 <- cos(2 * pi * tt / 15)
  X <- cbind(x_reg = x1, x_tf = x2)
  y <- as.numeric(
    1.5 + 0.015 * tt +
      0.7 * sin(2 * pi * tt / 12) +
      0.5 * x1 +
      stats::rnorm(length(tt), sd = 0.05)
  )

  decomp_cfg <- list(
    enabled = TRUE,
    backend = "r",
    state_estimate = "filtered",
    components = c("trend", "seasonal", "regression", "transfer", "residual"),
    trend = list(degree = 0L),
    seasonal = list(period = 12, harmonics = c(1L, 2L)),
    regression = list(enabled = TRUE, x_cols = "x_reg"),
    transfer = list(enabled = TRUE, x_cols = "x_tf", lambda = 0.9),
    input_lags = list(trend = 2L, seasonal = 2L, regression = 2L, transfer = 2L, residual = 2L),
    discount = list(trend = 0.99, seasonal = 0.99, regression = 1.0, transfer_zeta = 0.98, transfer_psi = 1.0),
    variance = list(mode = "unknown_constant", l0 = 2, S0 = 1)
  )

  fit <- exdqlm:::qdesn_fit_vb(
    y = y,
    p0 = 0.5,
    D = 1L,
    n = 16L,
    n_tilde = integer(0),
    m = 4L,
    alpha = 0.2,
    rho = 0.9,
    pi_w = 1.0,
    pi_in = 1.0,
    washout = 5L,
    add_bias = TRUE,
    seed = 2026L,
    fit_readout = FALSE,
    input_mode = "dlm_decomp_lags",
    decomposition = decomp_cfg,
    decomposition_xreg = X
  )

  runtime <- fit$states$decomposition
  expect_false(is.null(runtime))
  expect_true(all(c("trend", "seasonal", "regression", "transfer", "residual") %in% names(runtime$series)))
  expect_identical(runtime$input_components, c("trend", "seasonal", "regression", "transfer", "residual"))
  expect_equal(fit$meta$m_input, 10L)
  expect_equal(length(runtime$idx$regression), 1L)
  expect_equal(length(runtime$idx$transfer), 2L)
  expect_true(all(is.finite(runtime$series$regression)))
  expect_true(all(is.finite(runtime$series$transfer)))
})

test_that("decomposition regression/transfer feature engineering supports lags squares and interactions", {
  withr::local_seed(90212)

  tt <- seq_len(140L)
  X <- cbind(
    soil = sin(2 * pi * tt / 17),
    ppt = cos(2 * pi * tt / 23)
  )
  y <- as.numeric(
    2 + 0.01 * tt +
      0.5 * X[, "soil"] +
      0.3 * X[, "ppt"] +
      stats::rnorm(length(tt), sd = 0.06)
  )

  decomp_cfg <- list(
    enabled = TRUE,
    backend = "r",
    state_estimate = "filtered",
    components = c("trend", "regression", "transfer", "residual"),
    trend = list(degree = 0L),
    regression = list(
      enabled = TRUE,
      x_cols = c("soil", "ppt"),
      features = list(
        lags = c(0L, 1L, 2L, 3L),
        include_squares = TRUE,
        include_interactions = TRUE,
        interaction_pairs = list(c("soil", "ppt")),
        same_lag_only = TRUE
      )
    ),
    transfer = list(
      enabled = TRUE,
      x_cols = c("soil", "ppt"),
      lambda = 0.97,
      features = list(
        lags = c(0L, 1L, 2L, 3L),
        include_squares = TRUE,
        include_interactions = TRUE,
        interaction_pairs = list(c("soil", "ppt")),
        same_lag_only = TRUE
      )
    ),
    input_lags = list(trend = 2L, regression = 2L, transfer = 2L, residual = 2L),
    discount = list(trend = 0.99, regression = 1.0, transfer_zeta = 0.98, transfer_psi = 1.0),
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
    washout = 5L,
    add_bias = TRUE,
    seed = 2026L,
    fit_readout = FALSE,
    input_mode = "dlm_decomp_lags",
    decomposition = decomp_cfg,
    decomposition_xreg = X
  )

  runtime <- fit$states$decomposition
  reg_info <- runtime$regression
  tf_info <- runtime$transfer

  # raw(2*4) + sq(2*4) + interactions(1*4) = 20 engineered predictors
  expect_equal(length(reg_info$feature_names), 20L)
  expect_equal(reg_info$n_state, 20L)

  # transfer has zeta + engineered predictors
  expect_equal(length(tf_info$feature_names), 20L)
  expect_equal(tf_info$n_state, 21L)
  expect_equal(tf_info$lambda[1], 0.97)
})

test_that("qdesn decomposition regression/transfer blocks require decomposition covariates", {
  withr::local_seed(90211)

  y <- as.numeric(1 + 0.01 * seq_len(80L) + stats::rnorm(80L, sd = 0.05))
  decomp_cfg <- list(
    enabled = TRUE,
    backend = "r",
    state_estimate = "filtered",
    components = c("trend", "regression", "transfer", "residual"),
    trend = list(degree = 0L),
    regression = list(enabled = TRUE),
    transfer = list(enabled = TRUE, lambda = 0.9),
    input_lags = list(trend = 2L, regression = 2L, transfer = 2L, residual = 2L),
    discount = list(trend = 0.99, regression = 1.0, transfer_zeta = 0.99, transfer_psi = 1.0),
    variance = list(mode = "unknown_constant", l0 = 2, S0 = 1)
  )

  expect_error(
    exdqlm:::qdesn_fit_vb(
      y = y,
      p0 = 0.5,
      D = 1L,
      n = 10L,
      n_tilde = integer(0),
      m = 4L,
      alpha = 0.2,
      rho = 0.9,
      pi_w = 1.0,
      pi_in = 1.0,
      washout = 5L,
      add_bias = TRUE,
      seed = 2026L,
      fit_readout = FALSE,
      input_mode = "dlm_decomp_lags",
      decomposition = decomp_cfg
    ),
    regexp = "requires decomposition covariates"
  )
})

test_that("qdesn_fit_vb uses component lag policy independent of m", {
  withr::local_seed(456)

  tt <- seq_len(140)
  y <- as.numeric(1 + 0.03 * tt + 0.7 * sin(2 * pi * tt / 12) + stats::rnorm(140, sd = 0.07))

  fit <- exdqlm:::qdesn_fit_vb(
    y = y,
    p0 = 0.5,
    D = 1L,
    n = 12L,
    n_tilde = integer(0),
    m = 30L,
    alpha = 0.2,
    rho = 0.9,
    pi_w = 1.0,
    pi_in = 1.0,
    washout = 5L,
    add_bias = TRUE,
    seed = 77L,
    fit_readout = FALSE,
    standardize_inputs = TRUE,
    input_mode = "dlm_decomp_lags",
    decomposition = list(
      enabled = TRUE,
      backend = "r",
      state_estimate = "filtered",
      input_lags_mode = "component",
      components = c("trend", "seasonal", "residual"),
      trend = list(degree = 0L),
      seasonal = list(period = 12, harmonics = c(1L, 2L))
    )
  )

  expect_identical(fit$meta$decomposition$input_lags_mode, "component")
  expect_equal(fit$meta$m_input, 36L)
  expect_equal(fit$meta$input_lag_warmup, 12L)
})

test_that("forecast paths/lattice run in decomposition mode with non-terminal origins", {
  withr::local_seed(321)
  withr::local_options(list(exdqlm.use_cpp_postpred = FALSE))

  tt <- seq_len(150)
  y <- as.numeric(3 + 0.01 * tt + 0.8 * sin(2 * pi * tt / 12) + stats::rnorm(150, sd = 0.1))

  fit <- exdqlm:::qdesn_fit_vb(
    y = y,
    p0 = 0.5,
    D = 1L,
    n = 12L,
    n_tilde = integer(0),
    m = 5L,
    alpha = 0.25,
    rho = 0.9,
    pi_w = 1.0,
    pi_in = 1.0,
    washout = 6L,
    add_bias = TRUE,
    seed = 11L,
    fit_readout = TRUE,
    input_mode = "dlm_decomp_lags",
    decomposition = make_phase2_decomp_cfg(),
    vb_args = list(
      max_iter = 10L,
      min_iter_elbo = 2L,
      tol = 1e-3,
      tol_par = 1e-3,
      verbose = FALSE
    )
  )

  readout_spec <- list(
    include_input = FALSE,
    input_position = "after_reservoir",
    input_mode_requested = "dlm_decomp_lags",
    input_mode_effective = "dlm_decomp_lags",
    input_mode = "dlm_decomp_lags",
    decomposition = make_phase2_decomp_cfg(residual_recursion = "deterministic_plugin"),
    input_lags_y = integer(0),
    input_lags_x = list(),
    reservoir_lags = 0L,
    y_lags = integer(0),
    x_names = character(0),
    x_lags = list(),
    p_res = ncol(fit$X),
    scale_info = NULL
  )

  paths <- exdqlm:::forecast_paths.qdesn_fit(
    object = fit,
    H = 5L,
    nd = 20L,
    readout_spec = readout_spec,
    origin_index = 100L,
    seed = 99L
  )

  expect_equal(dim(paths$yrep), c(5L, 20L))
  expect_equal(dim(paths$mu_draws), c(5L, 20L))
  expect_true(all(is.finite(paths$mu_draws)))

  fit$meta$readout_spec <- readout_spec
  lattice <- exdqlm:::forecast_lattice.qdesn_fit(
    object = fit,
    y_all = y,
    origins = c(95L, 105L),
    H = 3L,
    nd = 16L,
    keep_origin_draws = TRUE,
    seed = 101L
  )

  expect_equal(length(lattice$yrep_by_origin), 2L)
  expect_equal(dim(lattice$yrep_by_origin[[1L]])[1], 3L)
  expect_equal(dim(lattice$mu_by_origin[[2L]])[1], 3L)
  mu_mix <- as.numeric(lattice$mix$mu)
  expect_true(all(is.finite(mu_mix[!is.na(mu_mix)])))
  expect_gt(sum(is.finite(mu_mix)), 0L)
})

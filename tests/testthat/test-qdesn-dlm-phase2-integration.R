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
  expect_identical(info$decomposition$seasonal$harmonics, c(1L, 2L))
  expect_identical(info$decomposition$input_lags$trend, 5L)
  expect_identical(info$decomposition$input_lags$seasonal, 6L)
  expect_identical(info$decomposition$input_lags$residual, 7L)
  expect_identical(info$decomposition$variance$l0, 3)
  expect_identical(info$decomposition$variance$S0, 4)
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
  expect_identical(runtime$seasonal$harmonics_effective, c(1L, 3L))
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

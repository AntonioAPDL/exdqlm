test_that("residual ablation protocol is fixed at tau0 0.1 and single origins", {
  protocol <- qdesn_residual_ablation_protocol()
  expect_equal(protocol$rhs_tau0, 0.1)
  expect_equal(protocol$validation$origin, 900L)
  expect_equal(protocol$validation$horizon, 100L)
  expect_equal(protocol$final$origin, 1000L)
  expect_equal(protocol$final$horizon, 100L)
  expect_equal(protocol$p_vec, c(0.50, 0.75, 0.95))
  expect_equal(length(protocol$confirmation$all_seeds), 6L)
  expect_true(protocol$confirmation$reuse_screening_fits)
})

test_that("candidate design contains the fixed 18-run screen and anchor", {
  candidates <- qdesn_residual_ablation_candidates()
  expect_equal(nrow(candidates), 19L)
  expect_false(anyDuplicated(candidates$candidate_id) > 0L)
  expect_setequal(unique(candidates$D), c(2L, 3L))
  expect_setequal(unique(candidates$n), c(20L, 30L, 50L))
  expect_setequal(unique(candidates$m), c(3L, 12L, 24L))
  expect_setequal(unique(candidates$alpha), c(0.10, 0.30, 0.50))
  expect_setequal(unique(candidates$rho), c(0.70, 0.85, 0.95))
})


test_that("the fit-forecast cell cannot receive held-out responses", {
  expect_false("y_future" %in% names(formals(.qdesn_ablation_fit_forecast_cell)))
})

test_that("plain reroll preserves the legacy design and skip zero is nested", {
  y <- sin(seq_len(90L) / 7) + 0.1 * cos(seq_len(90L) / 3)
  paired <- qdesn_build_paired_architecture_designs(
    y = y,
    D = 2L,
    n = 6L,
    m = 3L,
    alpha = 0.30,
    rho = 0.85,
    pi_w = 0.40,
    pi_in = 1,
    washout = 20L,
    add_bias = TRUE,
    standardize_inputs = TRUE,
    seed = 812L,
    skip_scale = 0
  )
  expect_lt(paired$plain$meta$legacy_parity_max_abs_error, 1e-10)
  expect_equal(
    paired$plain$X,
    paired$interlayer_residual$X,
    tolerance = 1e-10
  )
  expect_identical(
    paired$plain$meta$base_reservoir_sha256,
    paired$interlayer_residual$meta$base_reservoir_sha256
  )
})

test_that("a one-layer model is a residual no-op", {
  y <- sin(seq_len(70L) / 5)
  paired <- qdesn_build_paired_architecture_designs(
    y = y,
    D = 1L,
    n = 5L,
    m = 2L,
    alpha = 0.30,
    rho = 0.80,
    pi_w = 0.50,
    pi_in = 1,
    washout = 15L,
    add_bias = TRUE,
    seed = 913L,
    skip_scale = 1
  )
  expect_equal(
    paired$plain$X,
    paired$interlayer_residual$X,
    tolerance = 1e-10
  )
})

test_that("a nonzero residual skip changes a deep design only", {
  y <- sin(seq_len(90L) / 7) + 0.1 * cos(seq_len(90L) / 3)
  paired <- qdesn_build_paired_architecture_designs(
    y = y,
    D = 2L,
    n = 6L,
    m = 3L,
    alpha = 0.30,
    rho = 0.85,
    pi_w = 0.40,
    pi_in = 1,
    washout = 20L,
    add_bias = TRUE,
    standardize_inputs = TRUE,
    seed = 814L,
    skip_scale = 1
  )
  expect_gt(
    max(abs(paired$plain$X - paired$interlayer_residual$X)),
    1e-8
  )
  expect_equal(
    paired$plain$reservoir$W,
    paired$interlayer_residual$reservoir$W,
    tolerance = 0
  )
  expect_equal(
    paired$plain$reservoir$Win,
    paired$interlayer_residual$reservoir$Win,
    tolerance = 0
  )
})

test_that("the residual candidate adds the projected lower state", {
  reservoir_plain <- list(
    D = 2L,
    n = c(1L, 1L),
    n_tilde = 1L,
    alpha = c(0.5, 0.5),
    W = list(matrix(0, 1, 1), matrix(0, 1, 1)),
    Win = list(matrix(1, 1, 1), matrix(1, 1, 1)),
    Q = list(matrix(1, 1, 1)),
    Q_is_identity = TRUE,
    act_f = "tanh",
    act_k = "identity",
    connection_type = "plain",
    skip_scale = 0,
    Pskip = list(matrix(1, 1, 1))
  )
  reservoir_res <- reservoir_plain
  reservoir_res$connection_type <- "interlayer_residual"
  reservoir_res$skip_scale <- 1

  h0 <- list(0, 0)
  plain <- .qdesn_forward_architecture_one(h0, 1, reservoir_plain)
  residual <- .qdesn_forward_architecture_one(h0, 1, reservoir_res)

  expect_equal(residual$h[[1]], plain$h[[1]], tolerance = 1e-14)
  expect_equal(
    residual$h[[2]] - plain$h[[2]],
    0.5 * residual$h[[1]],
    tolerance = 1e-14
  )
})

test_that("rectangular identity projections have the requested dimensions", {
  P <- .qdesn_rectangular_identity(3L, 5L)
  expect_equal(dim(P), c(3L, 5L))
  expect_equal(P[, 1:3], diag(3L))
  expect_equal(P[, 4:5], matrix(0, 3L, 2L))
})


test_that("authoritative runner rejects a different RHS global scale", {
  expect_error(
    qdesn_run_residual_ablation(
      y = rep(0, 1100L),
      output_dir = tempfile("qdesn-residual-"),
      tau0 = 0.01,
      quick = TRUE
    ),
    "fixes tau0 = 0.1"
  )
})

test_that("vectorized path propagation matches scalar propagation", {
  reservoir <- list(
    D = 2L,
    n = c(2L, 2L),
    n_tilde = 2L,
    alpha = c(0.25, 0.40),
    W = list(
      matrix(c(0.1, -0.2, 0.05, 0.1), 2, 2),
      matrix(c(0.2, 0, -0.1, 0.15), 2, 2)
    ),
    Win = list(
      matrix(c(0.2, -0.1, 0.3, 0.4), 2, 2),
      diag(c(0.5, -0.25))
    ),
    Q = list(diag(2L)),
    Q_is_identity = TRUE,
    act_f = "tanh",
    act_k = "identity",
    connection_type = "interlayer_residual",
    skip_scale = 1,
    Pskip = list(diag(2L))
  )
  h_paths <- list(
    matrix(c(0.1, -0.1, 0.2, 0.0, -0.2, 0.3), 2, 3),
    matrix(c(0.0, 0.2, -0.1, 0.1, 0.3, -0.2), 2, 3)
  )
  u_paths <- matrix(c(1, 0.2, 1, -0.3, 1, 0.5), 2, 3)
  vectorized <- .qdesn_forward_architecture_paths(h_paths, u_paths, reservoir)

  for (j in seq_len(3L)) {
    scalar <- .qdesn_forward_architecture_one(
      lapply(h_paths, function(x) x[, j]),
      u_paths[, j],
      reservoir
    )
    expect_equal(vectorized$h[[1L]][, j], scalar$h[[1L]], tolerance = 1e-14)
    expect_equal(vectorized$h[[2L]][, j], scalar$h[[2L]], tolerance = 1e-14)
    expect_equal(vectorized$x_raw[, j], scalar$x_raw, tolerance = 1e-14)
  }
})

test_that("identity residual states satisfy the layerwise tanh bound", {
  y <- sin(seq_len(100L) / 8) + 0.2 * cos(seq_len(100L) / 11)
  paired <- qdesn_build_paired_architecture_designs(
    y = y,
    D = 3L,
    n = 4L,
    m = 2L,
    alpha = 0.30,
    rho = 0.80,
    pi_w = 0.50,
    pi_in = 1,
    washout = 20L,
    add_bias = TRUE,
    standardize_inputs = TRUE,
    seed = 915L,
    skip_scale = 1
  )
  for (d in seq_len(3L)) {
    expect_lte(max(abs(paired$interlayer_residual$states$H_all[[d]])), d + 1e-10)
  }
})

test_that("AL-VB readout fixes gamma and preserves RHS tau0", {
  skip_on_cran()
  y <- 0.6 * sin(seq_len(90L) / 7) + 0.15 * cos(seq_len(90L) / 4)
  paired <- qdesn_build_paired_architecture_designs(
    y = y,
    D = 2L,
    n = 4L,
    m = 2L,
    alpha = 0.30,
    rho = 0.80,
    pi_w = 0.50,
    pi_in = 1,
    washout = 25L,
    add_bias = TRUE,
    standardize_inputs = TRUE,
    seed = 916L,
    skip_scale = 1
  )
  fit <- qdesn_fit_al_vb_from_design(
    paired$plain,
    p0 = 0.75,
    tau0 = 0.1,
    vb_control = list(max_iter = 30L, min_iter_elbo = 5L, n_samp_xi = 50L),
    fit_seed = 1001L
  )
  expect_identical(fit$meta$likelihood_family, "al")
  expect_equal(fit$meta$al_fixed_gamma, 0)
  expect_equal(fit$fit$beta_prior$hypers$tau0, 0.1)

  posterior <- exal_posterior_draws(fit$fit, nd = 20L)
  expect_equal(posterior$gamma, rep(0, 20L), tolerance = 0)

  noise <- .qdesn_ablation_noise(H = 5L, nd = 20L, seed = 1002L)
  fc1 <- qdesn_forecast_single_origin_al_vb(
    fit, y_history = y, H = 5L, nd = 20L,
    posterior_seed = 1003L, noise_draws = noise
  )
  fc2 <- qdesn_forecast_single_origin_al_vb(
    fit, y_history = y, H = 5L, nd = 20L,
    posterior_seed = 1003L, noise_draws = noise
  )
  expect_equal(fc1$yrep, fc2$yrep, tolerance = 0)
  expect_equal(fc1$qhat, fc2$qhat, tolerance = 0)
})

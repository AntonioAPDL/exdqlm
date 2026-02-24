make_online_fixture <- function(n = 36L, k = 5L, seed = 42L) {
  set.seed(seed)
  X <- cbind(1, matrix(rnorm(n * (k - 1L)), nrow = n, ncol = k - 1L))
  beta <- c(0.5, -0.8, 0.35, 0.2, -0.15)[seq_len(k)]
  y <- as.numeric(X %*% beta + 0.35 * rt(n, df = 6))
  list(y = y, X = X)
}

make_online_init <- function(y, X, T0 = 24L, control = list()) {
  p0 <- 0.5
  bounds <- get_gamma_bounds(p0)
  beta_obj <- beta_prior("ridge", ridge = list(tau2 = 5))

  batch_fit <- exal_ldvb_fit(
    y = y[seq_len(T0)],
    X = X[seq_len(T0), , drop = FALSE],
    p0 = p0,
    gamma_bounds = bounds,
    vb_control = list(max_iter = 30L, tol = 1e-4, tol_par = 1e-4, verbose = FALSE),
    beta_prior_obj = beta_obj
  )

  exal_online_init(
    y = y[seq_len(T0)],
    X = X[seq_len(T0), , drop = FALSE],
    p0 = p0,
    gamma_bounds = bounds,
    control = control,
    batch_fit = batch_fit,
    beta_prior_obj = beta_obj,
    prior_gamma = list(mu0 = 0, s20 = 10),
    prior_sigma = list(a = 1, b = 1)
  )
}

test_that("online init returns valid state and prediction", {
  dat <- make_online_fixture()
  st <- make_online_init(dat$y, dat$X, T0 = 24L, control = list(M = 0L, K = 0L))

  expect_s3_class(st, "exal_online_vbld_state")
  expect_length(st$qbeta$m, ncol(dat$X))
  expect_equal(dim(st$qbeta$V), c(ncol(dat$X), ncol(dat$X)))
  expect_true(all(is.finite(st$qbeta$m)))
  expect_true(all(is.finite(st$qbeta$V)))

  pred <- exal_online_predict_quantile(st, dat$X[1L, ])
  expect_true(is.finite(pred))
})

test_that("strict streaming updates stay finite and SPD", {
  dat <- make_online_fixture(seed = 43L)
  T0 <- 22L
  st <- make_online_init(
    dat$y, dat$X, T0 = T0,
    control = list(M = 0L, K = 0L, W = 0L, L_loc = 2L)
  )

  for (tt in seq.int(T0 + 1L, nrow(dat$X))) {
    st <- exal_online_step(
      state = st,
      y_t = dat$y[tt],
      x_t = dat$X[tt, ],
      update_rhs = FALSE,
      update_sigmagam = FALSE
    )
  }

  expect_equal(st$t_current, as.integer(nrow(dat$X)))
  expect_true(all(is.finite(st$qbeta$m)))
  expect_true(all(is.finite(st$qbeta$V)))
  expect_true(all(is.finite(st$history$barw)))
  expect_true(all(st$history$barw > 0))

  evals <- eigen(0.5 * (st$P + t(st$P)), symmetric = TRUE, only.values = TRUE)$values
  expect_gt(min(evals), 0)
})

test_that("scheduled refresh hooks run without breaking state", {
  dat <- make_online_fixture(seed = 44L)
  T0 <- 20L
  st <- make_online_init(
    dat$y, dat$X, T0 = T0,
    control = list(M = 2L, K = 3L, W = 5L, L_loc = 2L, window_passes = 1L)
  )

  for (tt in seq.int(T0 + 1L, nrow(dat$X))) {
    st <- exal_online_step(
      state = st,
      y_t = dat$y[tt],
      x_t = dat$X[tt, ],
      update_rhs = TRUE,
      update_sigmagam = TRUE
    )
  }

  expect_gte(st$refresh_counts$rhs, 1L)
  expect_gte(st$refresh_counts$sigmagam, 1L)
  expect_true(all(is.finite(st$qbeta$m)))
  expect_true(all(is.finite(st$qbeta$V)))
  expect_true(all(is.finite(c(st$qsiggam$eta_hat, st$qsiggam$ell_hat))))
  expect_false(is.na(st$diagnostics$last_sigmagam_refresh_ok))
})

test_that("windowed online refresh tracks full-batch solution closely", {
  dat <- make_online_fixture(n = 28L, k = 4L, seed = 99L)
  p0 <- 0.5
  bounds <- get_gamma_bounds(p0)
  beta_obj <- beta_prior("ridge", ridge = list(tau2 = 5))
  T0 <- 18L

  init_fit <- exal_ldvb_fit(
    y = dat$y[seq_len(T0)],
    X = dat$X[seq_len(T0), , drop = FALSE],
    p0 = p0,
    gamma_bounds = bounds,
    vb_control = list(max_iter = 35L, tol = 1e-4, tol_par = 1e-4, verbose = FALSE),
    beta_prior_obj = beta_obj
  )

  st <- exal_online_init(
    y = dat$y[seq_len(T0)],
    X = dat$X[seq_len(T0), , drop = FALSE],
    p0 = p0,
    gamma_bounds = bounds,
    control = list(M = 1L, K = 1L, W = 200L, L_loc = 2L, window_passes = 1L),
    batch_fit = init_fit,
    beta_prior_obj = beta_obj
  )

  for (tt in seq.int(T0 + 1L, nrow(dat$X))) {
    st <- exal_online_step(
      state = st,
      y_t = dat$y[tt],
      x_t = dat$X[tt, ],
      update_rhs = TRUE,
      update_sigmagam = TRUE
    )
  }

  fit_full <- exal_ldvb_fit(
    y = dat$y,
    X = dat$X,
    p0 = p0,
    gamma_bounds = bounds,
    vb_control = list(max_iter = 35L, tol = 1e-4, tol_par = 1e-4, verbose = FALSE),
    beta_prior_obj = beta_obj
  )

  l2_beta <- sqrt(sum((st$qbeta$m - fit_full$qbeta$m)^2))
  expect_lt(l2_beta, 0.1)
})

test_that("online runner matches manual stepping and returns trace", {
  dat <- make_online_fixture(seed = 123L)
  T0 <- 20L
  st0 <- make_online_init(
    dat$y, dat$X, T0 = T0,
    control = list(M = 3L, K = 4L, W = 0L, L_loc = 2L)
  )

  st_manual <- st0
  for (tt in seq.int(T0 + 1L, nrow(dat$X))) {
    st_manual <- exal_online_step(
      state = st_manual,
      y_t = dat$y[tt],
      x_t = dat$X[tt, ],
      update_rhs = TRUE,
      update_sigmagam = TRUE
    )
  }

  out <- exal_online_run(
    state = st0,
    y_new = dat$y[seq.int(T0 + 1L, nrow(dat$X))],
    X_new = dat$X[seq.int(T0 + 1L, nrow(dat$X)), , drop = FALSE],
    update_rhs = TRUE,
    update_sigmagam = TRUE,
    keep_trace = TRUE
  )

  expect_true(is.list(out))
  expect_true(all(c("state", "trace") %in% names(out)))
  expect_equal(nrow(out$trace), nrow(dat$X) - T0)
  expect_true(all(c(
    "y_t", "yhat_pre", "check_loss_pre", "covered_pre",
    "solver_method", "solver_fallback", "jitter_eps"
  ) %in% names(out$trace)))
  expect_equal(out$state$t_current, st_manual$t_current)
  expect_equal(out$state$qbeta$m, st_manual$qbeta$m, tolerance = 1e-10)
  expect_equal(out$state$P, st_manual$P, tolerance = 1e-10)

  td <- exal_online_trace_diagnostics(out$trace, p0 = 0.5, rolling_window = 5L)
  expect_true(is.list(td))
  expect_equal(td$n, nrow(out$trace))
  expect_true(is.finite(td$coverage_mean))
  expect_true(is.finite(td$check_loss_mean))
})

test_that("online health check reports valid diagnostics", {
  dat <- make_online_fixture(seed = 101L)
  T0 <- 21L
  st <- make_online_init(
    dat$y, dat$X, T0 = T0,
    control = list(M = 2L, K = 3L, W = 4L, L_loc = 2L)
  )

  out <- exal_online_run(
    state = st,
    y_new = dat$y[seq.int(T0 + 1L, nrow(dat$X))],
    X_new = dat$X[seq.int(T0 + 1L, nrow(dat$X)), , drop = FALSE],
    keep_trace = TRUE
  )

  st <- out$state
  hc <- exal_online_health_check(st, trace = out$trace, p0 = 0.5, rolling_window = 5L)
  expect_true(is.list(hc))
  expect_true(isTRUE(hc$is_finite_beta))
  expect_true(isTRUE(hc$is_finite_sigmagam))
  expect_true(isTRUE(hc$barw_positive))
  expect_true(isTRUE(hc$P_spd))
  expect_true(is.finite(hc$min_eig_P))
  expect_true(is.finite(hc$solve_calls))
  expect_true(is.finite(hc$solve_fallbacks))
  expect_true(hc$solve_calls >= hc$solve_fallbacks)
  expect_true(is.list(hc$trace_diag))
  expect_true(is.finite(hc$trace_diag$coverage_mean))
  expect_true(is.finite(hc$trace_diag$check_loss_mean))
  expect_equal(hc$t_current, st$t_current)
  expect_equal(hc$n_history, length(st$history$y))
})

test_that("exal_online_fit preserves exal_vb interface in batch mode", {
  dat <- make_online_fixture(n = 30L, k = 4L, seed = 211L)
  p0 <- 0.5
  bounds <- get_gamma_bounds(p0)
  beta_obj <- beta_prior("ridge", ridge = list(tau2 = 5))

  fit <- exal_online_fit(
    y = dat$y,
    X = dat$X,
    p0 = p0,
    gamma_bounds = bounds,
    control = list(enabled = FALSE),
    vb_control = list(max_iter = 25L, tol = 1e-4, tol_par = 1e-4, verbose = FALSE),
    beta_prior_obj = beta_obj
  )

  expect_s3_class(fit, "exal_vb")
  expect_equal(length(fit$qbeta$m), ncol(dat$X))
  expect_true(is.list(fit$misc$online))
  expect_false(isTRUE(fit$misc$online$enabled))
})

test_that("exal_online_fit returns exal_vb-compatible object in online mode", {
  dat <- make_online_fixture(n = 34L, k = 4L, seed = 212L)
  p0 <- 0.5
  bounds <- get_gamma_bounds(p0)
  beta_obj <- beta_prior("ridge", ridge = list(tau2 = 5))

  fit <- exal_online_fit(
    y = dat$y,
    X = dat$X,
    p0 = p0,
    gamma_bounds = bounds,
    control = list(
      enabled = TRUE,
      strict = FALSE,
      M = 2L,
      K = 3L,
      W = 8L,
      L_loc = 2L,
      window_passes = 1L,
      warm_start_n = 20L,
      keep_trace = TRUE
    ),
    vb_control = list(max_iter = 30L, tol = 1e-4, tol_par = 1e-4, verbose = FALSE),
    log_prior_gamma = function(g) 0,
    beta_prior_obj = beta_obj
  )

  expect_s3_class(fit, "exal_vb")
  expect_true(isTRUE(fit$misc$online$enabled))
  expect_true(is.list(fit$misc$online$health))
  expect_true(is.data.frame(fit$misc$online$trace))
  expect_equal(nrow(fit$misc$online$trace), nrow(dat$X) - fit$misc$online$t0)

  dr <- exal_vb_posterior_draws(fit, nd = 50L)
  expect_equal(dim(dr$beta), c(50L, ncol(dat$X)))
  expect_length(dr$sigma, 50L)
  expect_length(dr$gamma, 50L)
})

test_that("exal_online_fit normalizes control defaults and enforces K >= M", {
  dat <- make_online_fixture(n = 32L, k = 4L, seed = 333L)
  p0 <- 0.5
  bounds <- get_gamma_bounds(p0)
  beta_obj <- beta_prior("ridge", ridge = list(tau2 = 5))

  fit_default <- exal_online_fit(
    y = dat$y,
    X = dat$X,
    p0 = p0,
    gamma_bounds = bounds,
    control = list(enabled = FALSE),
    vb_control = list(max_iter = 20L, tol = 1e-4, tol_par = 1e-4, verbose = FALSE),
    beta_prior_obj = beta_obj
  )

  ctrl_default <- fit_default$misc$online$control
  expect_false(isTRUE(ctrl_default$enabled))
  expect_false(isTRUE(ctrl_default$strict))
  expect_equal(as.integer(ctrl_default$M), 10L)
  expect_equal(as.integer(ctrl_default$K), 40L)
  expect_equal(as.integer(ctrl_default$W), 100L)
  expect_equal(as.integer(ctrl_default$L_loc), 2L)

  fit_online <- exal_online_fit(
    y = dat$y,
    X = dat$X,
    p0 = p0,
    gamma_bounds = bounds,
    control = list(
      enabled = TRUE,
      strict = FALSE,
      M = 6L,
      K = 2L,
      W = 12L,
      L_loc = 2L,
      warm_start_n = 20L
    ),
    vb_control = list(max_iter = 20L, tol = 1e-4, tol_par = 1e-4, verbose = FALSE),
    beta_prior_obj = beta_obj
  )

  ctrl_online <- fit_online$misc$online$control
  expect_true(isTRUE(ctrl_online$enabled))
  expect_equal(as.integer(ctrl_online$M), 6L)
  expect_equal(as.integer(ctrl_online$K), 6L)
})

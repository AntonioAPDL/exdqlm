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

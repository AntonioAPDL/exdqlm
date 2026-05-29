make_online_vbld_data <- function(seed = 20260660L, n = 24L, k = 3L) {
  set.seed(as.integer(seed))
  X <- cbind(1, matrix(stats::rnorm(n * (k - 1L)), nrow = n, ncol = k - 1L))
  beta <- c(0.4, -0.2, 0.1, 0.05)[seq_len(k)]
  y <- as.numeric(X %*% beta + stats::rnorm(n, sd = 0.2))
  list(X = X, y = y)
}

online_vbld_batch_control <- function(max_iter = 6L) {
  list(
    max_iter = as.integer(max_iter),
    tol = 0,
    tol_par = 0,
    n_samp_xi = 8L,
    verbose = FALSE
  )
}

expect_online_health_ok <- function(health) {
  expect_true(isTRUE(health$P_spd))
  expect_true(isTRUE(health$is_finite_beta))
  expect_true(isTRUE(health$is_finite_sigmagam))
  expect_true(isTRUE(health$barw_positive))
}

test_that("online VB-LD disabled path preserves batch fit semantics", {
  dat <- make_online_vbld_data()
  gamma_bounds <- exdqlm::get_gamma_bounds(0.5)
  ctrl <- online_vbld_batch_control()

  direct <- exdqlm::exal_ldvb_fit(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    gamma_bounds = gamma_bounds,
    vb_control = ctrl
  )
  wrapped <- exdqlm::exal_online_fit(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    gamma_bounds = gamma_bounds,
    control = list(enabled = FALSE),
    vb_control = ctrl
  )

  expect_false(isTRUE(wrapped$misc$online$enabled))
  expect_equal(wrapped$qbeta$m, direct$qbeta$m, tolerance = 1e-10)
  expect_equal(wrapped$qbeta$V, direct$qbeta$V, tolerance = 1e-10)
})

test_that("online VB-LD state serializes and resumes for a one-row update", {
  dat <- make_online_vbld_data(seed = 20260661L)
  gamma_bounds <- exdqlm::get_gamma_bounds(0.5)
  ctrl <- online_vbld_batch_control()
  t0 <- 18L

  fit_init <- exdqlm::exal_ldvb_fit(
    y = dat$y[seq_len(t0)],
    X = dat$X[seq_len(t0), , drop = FALSE],
    p0 = 0.5,
    gamma_bounds = gamma_bounds,
    vb_control = ctrl
  )
  state <- exdqlm::exal_online_init(
    y = dat$y[seq_len(t0)],
    X = dat$X[seq_len(t0), , drop = FALSE],
    p0 = 0.5,
    gamma_bounds = gamma_bounds,
    control = list(M = 0L, K = 0L, W = 0L, L_loc = 1L),
    batch_fit = fit_init
  )

  path <- tempfile(fileext = ".rds")
  saveRDS(state, path)
  restored <- readRDS(path)

  expect_s3_class(restored, "exal_online_vbld_state")
  expect_equal(
    exdqlm::exal_online_predict_quantile(restored, dat$X[t0 + 1L, ]),
    exdqlm::exal_online_predict_quantile(state, dat$X[t0 + 1L, ]),
    tolerance = 1e-12
  )

  out <- exdqlm::exal_online_run(
    state = restored,
    y_new = dat$y[t0 + 1L],
    X_new = dat$X[t0 + 1L, , drop = FALSE],
    keep_trace = TRUE
  )
  expect_equal(out$state$t_current, t0 + 1L)
  expect_equal(nrow(out$trace), 1L)
  expect_online_health_ok(exdqlm::exal_online_health_check(out$state, out$trace))
})

test_that("online VB-LD one-batch wrapper records streaming metadata", {
  dat <- make_online_vbld_data(seed = 20260662L)
  gamma_bounds <- exdqlm::get_gamma_bounds(0.5)

  fit <- exdqlm::exal_online_fit(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    gamma_bounds = gamma_bounds,
    control = list(
      enabled = TRUE,
      warm_start_n = nrow(dat$X) - 1L,
      M = 0L,
      K = 0L,
      W = 0L,
      L_loc = 1L,
      keep_trace = TRUE
    ),
    vb_control = online_vbld_batch_control()
  )

  expect_true(isTRUE(fit$misc$online$enabled))
  expect_identical(fit$misc$online$t_stream, 1L)
  expect_equal(nrow(fit$misc$online$trace), 1L)
  expect_online_health_ok(fit$misc$online$health)
})

test_that("online VB-LD is reproducible and order-sensitive", {
  dat <- make_online_vbld_data(seed = 20260663L)
  gamma_bounds <- exdqlm::get_gamma_bounds(0.5)
  ctrl <- online_vbld_batch_control()
  t0 <- 16L

  bench <- exdqlm::exal_online_stage0_benchmark(
    seed = 20260664L,
    n = 22L,
    k = 3L,
    t0 = 15L,
    batch_vb_control = ctrl,
    online_control = list(M = 2L, K = 4L, W = 6L, L_loc = 1L, window_passes = 1L, jitter = 1e-10),
    check_repro = TRUE,
    return_trace = TRUE
  )
  expect_true(isTRUE(bench$reproducibility$hashes_equal))
  expect_equal(bench$reproducibility$max_abs_beta_mu_diff, 0)
  expect_online_health_ok(bench$run1$health)

  fit_init <- exdqlm::exal_ldvb_fit(
    y = dat$y[seq_len(t0)],
    X = dat$X[seq_len(t0), , drop = FALSE],
    p0 = 0.5,
    gamma_bounds = gamma_bounds,
    vb_control = ctrl
  )
  state <- exdqlm::exal_online_init(
    y = dat$y[seq_len(t0)],
    X = dat$X[seq_len(t0), , drop = FALSE],
    p0 = 0.5,
    gamma_bounds = gamma_bounds,
    control = list(M = 2L, K = 4L, W = 6L, L_loc = 1L, window_passes = 1L),
    batch_fit = fit_init
  )

  idx <- seq.int(t0 + 1L, nrow(dat$X))
  fwd <- exdqlm::exal_online_run(state, dat$y[idx], dat$X[idx, , drop = FALSE])
  rev_idx <- rev(idx)
  revd <- exdqlm::exal_online_run(state, dat$y[rev_idx], dat$X[rev_idx, , drop = FALSE])
  expect_online_health_ok(exdqlm::exal_online_health_check(fwd))
  expect_online_health_ok(exdqlm::exal_online_health_check(revd))
  expect_gt(max(abs(fwd$qbeta$m - revd$qbeta$m)), 1e-8)
})

test_that("online VB-LD support is explicit for exAL and rejects enabled AL", {
  dat <- make_online_vbld_data(seed = 20260665L)
  gamma_bounds <- exdqlm::get_gamma_bounds(0.5)

  expect_error(
    exdqlm::exal_online_fit(
      y = dat$y,
      X = dat$X,
      p0 = 0.5,
      gamma_bounds = gamma_bounds,
      likelihood_family = "al",
      al_fixed_gamma = 0,
      control = list(enabled = TRUE, warm_start_n = 18L, M = 0L, K = 0L, W = 0L),
      vb_control = online_vbld_batch_control()
    ),
    "likelihood_family = 'exal'"
  )

  disabled_al <- exdqlm::exal_online_fit(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    gamma_bounds = gamma_bounds,
    likelihood_family = "al",
    al_fixed_gamma = 0,
    control = list(enabled = FALSE),
    vb_control = online_vbld_batch_control()
  )
  expect_false(isTRUE(disabled_al$misc$online$enabled))
  expect_identical(disabled_al$misc$likelihood_family, "al")
})

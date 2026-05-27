make_exact_chunking_stats_fixture <- function(n = 17L) {
  set.seed(20260527)
  x <- seq(-1, 1, length.out = n)
  X <- cbind(`(Intercept)` = 1, x = x, x2 = x^2, s = sin(seq_len(n) / 3))
  beta <- c(0.2, -0.4, 0.15, 0.1)
  y <- as.numeric(X %*% beta + stats::rnorm(n, sd = 0.1))
  list(
    X = X,
    y = y,
    xis = list(
      xi1 = 1.25,
      xi_lambda = 0.35,
      xi_lambda2 = 0.12,
      xi_A = -0.18,
      xi_A2 = 0.42,
      xi_siginv = 1.1,
      zeta_lam = 0.04
    ),
    qv = list(
      m = seq(0.8, 1.3, length.out = n),
      m_inv = seq(1.4, 0.7, length.out = n)
    ),
    qs = list(
      m = seq(0.6, 1.1, length.out = n),
      m2 = seq(0.9, 1.7, length.out = n)
    )
  )
}

test_that("exact row chunk helper covers rows sequentially", {
  expect_equal(exdqlm:::.exal_make_row_chunks(5L), list(1:5))
  expect_equal(exdqlm:::.exal_make_row_chunks(5L, 2L), list(1:2, 3:4, 5L))
  expect_equal(exdqlm:::.exal_make_row_chunks(3L, 10L), list(1:3))
  expect_error(exdqlm:::.exal_make_row_chunks(5L, 0L), "positive integer")
  expect_error(exdqlm:::.exal_make_row_chunks(-1L), "non-negative")
})

test_that("beta data-stat helpers are additive across exact chunks", {
  dat <- make_exact_chunking_stats_fixture()
  chunks <- exdqlm:::.exal_make_row_chunks(nrow(dat$X), 4L)

  full <- exdqlm:::.exal_beta_data_stats(
    X = dat$X,
    y = dat$y,
    xis = dat$xis,
    qv_m_inv = dat$qv$m_inv,
    qs_m = dat$qs$m
  )
  chunked <- exdqlm:::.exal_beta_data_stats_chunks(
    X = dat$X,
    y = dat$y,
    xis = dat$xis,
    qv_m_inv = dat$qv$m_inv,
    qs_m = dat$qs$m,
    chunks = chunks
  )

  expect_equal(chunked$barw, full$barw, tolerance = 1e-14)
  expect_equal(chunked$barm, full$barm, tolerance = 1e-14)
  expect_equal(chunked$S, full$S, tolerance = 1e-12)
  expect_equal(chunked$g, full$g, tolerance = 1e-12)

  prec_diag <- c(1.0e-8, 0.7, 0.8, 0.9)
  compat <- exdqlm:::.exal_beta_natural_stats(
    X = dat$X,
    y = dat$y,
    xis = dat$xis,
    qv_m_inv = dat$qv$m_inv,
    qs_m = dat$qs$m,
    prec_diag = prec_diag
  )
  solved <- exdqlm:::.exal_beta_solve_from_data_stats(full, prec_diag)

  expect_equal(compat$barw, full$barw, tolerance = 1e-14)
  expect_equal(compat$barm, full$barm, tolerance = 1e-14)
  expect_equal(compat$S, full$S, tolerance = 1e-14)
  expect_equal(compat$g, full$g, tolerance = 1e-14)
  expect_equal(compat$P, solved$P, tolerance = 1e-14)
  expect_equal(compat$h, solved$h, tolerance = 1e-14)
  expect_equal(compat$prec_diag, solved$prec_diag, tolerance = 1e-14)
})

test_that("local and sigma/gamma chunk helpers match unchunked row algebra", {
  dat <- make_exact_chunking_stats_fixture()
  chunks <- exdqlm:::.exal_make_row_chunks(nrow(dat$X), 5L)
  qbeta <- list(
    m = c(0.1, -0.2, 0.05, 0.3),
    V = diag(c(0.4, 0.3, 0.2, 0.25))
  )

  xb <- as.numeric(dat$X %*% qbeta$m)
  q_i <- rowSums((dat$X %*% qbeta$V) * dat$X)
  qv_full <- exdqlm:::.exal_local_qv_update(
    y = dat$y,
    xb = xb,
    q_i = q_i,
    qs_m = dat$qs$m,
    qs_m2 = dat$qs$m2,
    xis = dat$xis
  )
  qs_full <- exdqlm:::.exal_local_qs_update(
    y = dat$y,
    xb = xb,
    qv_m_inv = qv_full$m_inv,
    xis = dat$xis
  )

  local_chunked <- exdqlm:::.exal_local_updates_chunks(
    X = dat$X,
    y = dat$y,
    qbeta = qbeta,
    qv = dat$qv,
    qs = dat$qs,
    xis = dat$xis,
    chunks = chunks
  )

  expect_equal(local_chunked$xb, xb, tolerance = 1e-14)
  expect_equal(local_chunked$q_i, q_i, tolerance = 1e-14)
  expect_equal(local_chunked$qv$m, qv_full$m, tolerance = 1e-14)
  expect_equal(local_chunked$qv$m_inv, qv_full$m_inv, tolerance = 1e-14)
  expect_equal(local_chunked$qv$chi, qv_full$chi, tolerance = 1e-14)
  expect_equal(local_chunked$qv$psi, qv_full$psi, tolerance = 1e-14)
  expect_equal(local_chunked$qv$z, qv_full$z, tolerance = 1e-14)
  expect_equal(local_chunked$qs$m, qs_full$m, tolerance = 1e-14)
  expect_equal(local_chunked$qs$m2, qs_full$m2, tolerance = 1e-14)
  expect_equal(local_chunked$qs$mu, qs_full$mu, tolerance = 1e-14)
  expect_equal(local_chunked$qs$tau2, qs_full$tau2, tolerance = 1e-14)

  qv_new <- list(m = qv_full$m, m_inv = qv_full$m_inv)
  qs_new <- list(m = qs_full$m, m2 = qs_full$m2)
  t_i <- dat$y - xb
  stats_full <- list(
    S1 = sum(qv_new$m_inv * (t_i^2 + q_i)),
    S2 = sum(t_i),
    S3 = sum(qv_new$m),
    S4 = sum(qs_new$m * qv_new$m_inv * t_i),
    S5 = sum(qs_new$m2 * qv_new$m_inv),
    S6 = sum(qs_new$m)
  )
  stats_chunked <- exdqlm:::.exal_sigmagam_stats_chunks(
    X = dat$X,
    y = dat$y,
    qbeta = qbeta,
    qv = qv_new,
    qs = qs_new,
    chunks = chunks,
    xb = xb,
    q_i = q_i
  )

  expect_equal(stats_chunked$S1, stats_full$S1, tolerance = 1e-12)
  expect_equal(stats_chunked$S2, stats_full$S2, tolerance = 1e-12)
  expect_equal(stats_chunked$S3, stats_full$S3, tolerance = 1e-12)
  expect_equal(stats_chunked$S4, stats_full$S4, tolerance = 1e-12)
  expect_equal(stats_chunked$S5, stats_full$S5, tolerance = 1e-12)
  expect_equal(stats_chunked$S6, stats_full$S6, tolerance = 1e-12)
})

test_that("exact chunking also preserves small exAL VB fits", {
  set.seed(802)
  x <- seq(-1, 1, length.out = 22L)
  X <- cbind(1, x, sin(seq_along(x) / 4))
  y <- as.numeric(X %*% c(0.1, 0.25, -0.15) + stats::rnorm(length(x), sd = 0.18))
  prior <- exdqlm:::exal_make_beta_prior(type = "ridge", tau2 = 15)
  ctrl <- list(max_iter = 10L, min_iter_elbo = 4L, tol = 0, tol_par = 0, n_samp_xi = 32L, verbose = FALSE)

  fit_full <- exdqlm:::exal_fit(
    y = y,
    X = X,
    p0 = 0.5,
    gamma_bounds = c(-3, 3),
    method = "vb",
    likelihood_family = "exal",
    vb_control = ctrl,
    prior_gamma = list(mu0 = 0, s20 = 10),
    prior_sigma = list(a = 1, b = 1),
    beta_prior_obj = prior
  )
  ctrl_chunked <- modifyList(ctrl, list(chunking = list(enabled = TRUE, chunk_size = 6L)))
  fit_chunked <- exdqlm:::exal_fit(
    y = y,
    X = X,
    p0 = 0.5,
    gamma_bounds = c(-3, 3),
    method = "vb",
    likelihood_family = "exal",
    vb_control = ctrl_chunked,
    prior_gamma = list(mu0 = 0, s20 = 10),
    prior_sigma = list(a = 1, b = 1),
    beta_prior_obj = prior
  )

  expect_equal(fit_chunked$qbeta$m, fit_full$qbeta$m, tolerance = 1e-7)
  expect_equal(fit_chunked$qbeta$V, fit_full$qbeta$V, tolerance = 1e-7)
  expect_equal(fit_chunked$qv$m, fit_full$qv$m, tolerance = 1e-7)
  expect_equal(fit_chunked$qs$m, fit_full$qs$m, tolerance = 1e-7)
  expect_equal(fit_chunked$misc$elbo_trace, fit_full$misc$elbo_trace, tolerance = 1e-7)
})

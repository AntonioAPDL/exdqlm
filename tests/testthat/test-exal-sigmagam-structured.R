skip_on_cran()

test_that("structured exAL scale-skewness block has finite moments and repeatable draws", {
  stats <- exdqlm:::.exal_sigmagam_stats_from_vectors(
    t_i = c(-0.15, 0.05, 0.18, -0.08),
    inv_v = c(1.2, 0.9, 1.1, 0.8),
    v = 1 / c(1.2, 0.9, 1.1, 0.8),
    s = c(0.3, -0.2, 0.15, 0.05),
    a_sigma = 2.5,
    b_sigma = 1.2
  )
  p0 <- 0.5
  bounds <- exdqlm:::.gamma_bounds(p0)
  prior_gamma <- function(gamma) stats::dnorm(gamma, mean = 0, sd = 2, log = TRUE)

  qsg <- exdqlm:::.exal_sigmagam_structured_update(
    stats = stats,
    p0 = p0,
    bounds = bounds,
    PriorSigma = list(a_sig = 2.5, b_sig = 1.2),
    log_prior_gamma = prior_gamma,
    eta_start = 0,
    grid_size = 31L
  )

  expect_identical(qsg$factorization, "structured_qgamma_qsigma_given_gamma")
  expect_true(is.finite(qsg$E.sigma))
  expect_true(is.finite(qsg$E.inv.sigma))
  expect_true(is.finite(qsg$E.gam))
  expect_true(is.finite(qsg$entrop))
  expect_true(is.list(qsg$xi))
  expect_true(all(c("eta", "gamma", "weight", "chi", "psi", "k") %in% names(qsg$structured$grid)))
  expect_equal(qsg$structured$optimizer_start, 0, tolerance = 0)
  expect_identical(qsg$structured$optimizer_start_source, "eta_start")

  set.seed(9201)
  draw1 <- exdqlm:::.exal_sigmagam_structured_sample(qsg, 12L)
  set.seed(9201)
  draw2 <- exdqlm:::.exal_sigmagam_structured_sample(qsg, 12L)
  expect_equal(draw1, draw2, tolerance = 0)
  expect_true(all(draw1$sigma > 0))
  expect_true(all(draw1$gamma > bounds[1] & draw1$gamma < bounds[2]))
})

test_that("structured and legacy static LDVB scale-skewness factors remain selectable", {
  set.seed(9202)
  n <- 14L
  X <- cbind(1, seq(-1, 1, length.out = n))
  y <- as.numeric(X %*% c(0.2, -0.1) + stats::rnorm(n, sd = 0.12))
  base_ctrl <- list(
    max_iter = 12L,
    tol = 0.25,
    n_samp_xi = 20L,
    verbose = FALSE
  )

  fit_structured <- do.call(
    exalStaticLDVB,
    c(list(y = y, X = X, p0 = 0.5), base_ctrl)
  )
  fit_legacy <- exalStaticLDVB(
    y = y,
    X = X,
    p0 = 0.5,
    max_iter = 12L,
    tol = 0.25,
    n_samp_xi = 20L,
    vb_control = exal_make_vb_control(
      sigmagam = exal_make_vb_sigmagam_control(factorization = "laplace_delta")
    ),
    verbose = FALSE
  )

  expect_identical(fit_structured$misc$sigmagam$factorization, "structured")
  expect_identical(fit_structured$qsiggam$factorization, "structured_qgamma_qsigma_given_gamma")
  expect_identical(fit_legacy$misc$sigmagam$factorization, "laplace_delta")
  expect_identical(fit_legacy$qsiggam$factorization, "laplace_delta")
  expect_true(all(is.finite(fit_structured$samp.gamma)))
  expect_true(all(is.finite(fit_legacy$samp.gamma)))
})

test_that("structured LDVB consumes exact conditional-GIG moments across seven quantiles", {
  set.seed(9203)
  n <- 40L
  x <- seq(-1, 1, length.out = n)
  X <- cbind(1, x, sin(2 * pi * x), stats::rnorm(n))
  y <- as.numeric(X %*% c(0.2, -0.35, 0.25, 0.12) + stats::rt(n, df = 6) * 0.3)
  taus <- c(0.10, 0.25, 0.45, 0.50, 0.55, 0.75, 0.90)
  sigmagam <- exal_make_vb_sigmagam_control(
    factorization = "structured",
    structured_grid_size = 61L,
    structured_span_sd = 6,
    freeze_warmup_iters = 3L,
    force_after_warmup = TRUE,
    postwarmup_damping = 0.2,
    postwarmup_damping_iters = 18L,
    min_postwarmup_updates = 2L
  )
  control <- exal_make_vb_control(
    max_iter = 30L,
    min_iter_elbo = 25L,
    tol = 1e-6,
    tol_par = 1e-6,
    n_samp_xi = 16L,
    progress_every = 1000000L,
    verbose = FALSE,
    sigmagam = sigmagam
  )

  fits <- lapply(taus, function(tau) {
    exal_ldvb_fit(
      y = y,
      X = X,
      p0 = tau,
      gamma_bounds = c(exdqlm:::L.fn(tau), exdqlm:::U.fn(tau)),
      likelihood_family = "exal",
      beta_prior_obj = beta_prior("ridge", ridge = list(tau2 = 100)),
      prior_sigma = list(a = 1, b = 1),
      prior_gamma = list(mu0 = 0, s20 = 10),
      vb_control = control,
      init = list(
        beta_m = rep(0, ncol(X)),
        beta_V = diag(1, ncol(X)),
        sigma = stats::sd(y),
        gamma = 0
      )
    )
  })

  gamma <- vapply(fits, function(fit) fit$qsiggam$gamma_mean, numeric(1L))
  sigma <- vapply(fits, function(fit) fit$qsiggam$sigma_mean, numeric(1L))
  exact_commits <- vapply(
    fits, function(fit) fit$misc$structured_exact_commit_count, integer(1L)
  )
  lower <- vapply(taus, exdqlm:::L.fn, numeric(1L))
  upper <- vapply(taus, exdqlm:::U.fn, numeric(1L))
  boundary_margin <- pmin((gamma - lower) / (upper - lower),
                          (upper - gamma) / (upper - lower))

  expect_true(all(is.finite(gamma)))
  expect_true(all(is.finite(sigma) & sigma > 0))
  expect_true(all(exact_commits > 0L))
  expect_true(all(vapply(
    fits,
    function(fit) identical(fit$qsiggam$moment_source, "conditional_gig_exact"),
    logical(1L)
  )))
  expect_gt(min(boundary_margin), 0.02)
  expect_gt(gamma[[1L]], 0)
  expect_lt(gamma[[length(gamma)]], 0)
  expect_lt(stats::cor(taus, gamma, method = "spearman"), -0.8)
  expect_lt(max(sigma) / min(sigma), 4)

  for (fit in fits) {
    grid <- fit$qsiggam$structured$grid
    reconstructed <- c(
      xi1 = sum(grid$weight * (1 / grid$B) * grid$E_inv_sigma),
      xi_lambda = sum(grid$weight * grid$lambda / grid$B),
      xi_lambda2 = sum(grid$weight * (grid$lambda^2 / grid$B) * grid$E_sigma),
      xi_A = sum(grid$weight * (grid$A / grid$B) * grid$E_inv_sigma),
      xi_A2 = sum(grid$weight * (grid$A^2 / grid$B) * grid$E_inv_sigma),
      zeta_lam = sum(grid$weight * grid$lambda * grid$A / grid$B),
      zeta_logB = sum(grid$weight * log(grid$B)),
      xi_siginv = sum(grid$weight * grid$E_inv_sigma),
      zeta_logsigma = sum(grid$weight * grid$E_log_sigma)
    )
    expect_equal(
      unlist(fit$qsiggam$xi[names(reconstructed)]),
      reconstructed,
      tolerance = 1e-10
    )
  }
})

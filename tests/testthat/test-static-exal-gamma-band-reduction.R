test_that("tight gamma band behaves like the AL submodel numerically", {
  band <- 1e-6
  taus <- c(0.05, 0.50, 0.95)

  diffs <- lapply(taus, function(tau) {
    a0 <- exdqlm:::A.fn(tau, 0)
    b0 <- exdqlm:::B.fn(tau, 0)
    g <- c(-band, band)
    c(
      max_abs_A_diff = max(abs(exdqlm:::A.fn(tau, g) - a0)),
      max_abs_B_diff = max(abs(exdqlm:::B.fn(tau, g) - b0)),
      max_abs_lambda = max(abs(exdqlm:::C.fn(tau, g) * abs(g)))
    )
  })
  diffs <- do.call(rbind, diffs)

  expect_true(all(diffs[, "max_abs_A_diff"] < 5e-4))
  expect_true(all(diffs[, "max_abs_B_diff"] < 1e-3))
  expect_true(all(diffs[, "max_abs_lambda"] < 5e-5))
})

test_that("static exAL accepts a tight gamma band around zero", {
  set.seed(20260306)
  n <- 24
  X <- cbind(1, seq(-1, 1, length.out = n))
  y <- as.numeric(0.3 + 0.8 * X[, 2] + stats::rnorm(n, sd = 0.15))
  band <- 1e-6

  vb_fit <- exalStaticLDVB(
    y = y,
    X = X,
    p0 = 0.5,
    max_iter = 12,
    tol = 1e-3,
    gamma_bounds = c(-band, band),
    init = list(gamma = 0),
    n_samp_xi = 50,
    ld_controls = list(
      damping = 0.5,
      xi_damping = 0.7,
      xi_mode = "single",
      optimizer_maxit = 50,
      eig_floor = 1e-6,
      eig_cap = 5
    ),
    verbose = FALSE
  )

  expect_true(is.list(vb_fit))
  expect_lte(abs(as.numeric(vb_fit$qsiggam$gamma_mean)[1]), band + 1e-8)

  init <- list(
    beta = as.numeric(vb_fit$qbeta$m),
    sigma = as.numeric(vb_fit$qsiggam$sigma_mean)[1],
    gamma = 0,
    v = as.numeric(vb_fit$qv$E_v),
    s = as.numeric(vb_fit$qs$E_s)
  )

  m_fit <- exalStaticMCMC(
    y = y,
    X = X,
    p0 = 0.5,
    gamma_bounds = c(-band, band),
    init = init,
    init.from.vb = FALSE,
    n.burn = 10,
    n.mcmc = 12,
    thin = 1,
    mh.proposal = "rw",
    mh.adapt = FALSE,
    verbose = FALSE
  )

  expect_true(is.list(m_fit))
  expect_true(all(abs(as.numeric(m_fit$samp.gamma)) <= band + 1e-8))
})

test_that("shared static exAL MCMC ingredients reduce to AL at gamma zero", {
  set.seed(20260306)
  n <- 12
  X <- cbind(1, seq(-1, 1, length.out = n))
  beta <- c(0.4, -0.2)
  sigma <- 0.7
  v <- rep(1.1, n)
  s <- rexp(n)
  y <- as.numeric(X %*% beta + stats::rnorm(n, sd = 0.1))
  p0 <- 0.95
  A_tau <- (1 - 2 * p0) / (p0 * (1 - p0))
  B_tau <- 2 / (p0 * (1 - p0))

  lambda <- exdqlm:::C.fn(p0, 0) * abs(0)
  z_ex <- y - as.numeric(X %*% beta) - lambda * sigma * s
  z_al <- y - as.numeric(X %*% beta)
  expect_equal(z_ex, z_al, tolerance = 1e-12)

  chi_ex <- (z_ex^2) / (B_tau * sigma)
  chi_al <- (z_al^2) / (B_tau * sigma)
  psi_ex <- (A_tau^2) / (B_tau * sigma) + (2 / sigma)
  psi_al <- (A_tau^2 / B_tau + 2) / sigma
  expect_equal(chi_ex, chi_al, tolerance = 1e-12)
  expect_equal(psi_ex, psi_al, tolerance = 1e-12)

  W_ex <- 1 / (B_tau * sigma * v)
  W_al <- 1 / (B_tau * sigma * v)
  rhs_ex <- crossprod(X, W_ex * (y - lambda * sigma * s - A_tau * v))
  rhs_al <- crossprod(X, W_al * (y - A_tau * v))
  expect_equal(W_ex, W_al, tolerance = 1e-12)
  expect_equal(rhs_ex, rhs_al, tolerance = 1e-12)

  tau2_s <- 1 / (1 + (lambda^2) * sigma / (B_tau * v))
  mu_s <- tau2_s * (lambda * (y - as.numeric(X %*% beta) - A_tau * v)) / (B_tau * v)
  expect_equal(tau2_s, rep(1, n), tolerance = 1e-12)
  expect_equal(mu_s, rep(0, n), tolerance = 1e-12)
})

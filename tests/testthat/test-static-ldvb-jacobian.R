# Static LDVB checks for transformed objective/Jacobian consistency.

test_that("static LDVB transformed objective includes Jacobian term", {
  eta <- 0.35
  ell <- -0.2
  L <- -2
  U <- 2
  y <- c(0.3, -0.1, 0.2, 0.5)
  X <- cbind(1, c(-1, -0.2, 0.3, 1.1))

  state <- list(
    y = y,
    X = X,
    n = length(y),
    m_beta = c(0.1, -0.05),
    V_beta = diag(c(0.08, 0.12)),
    E_inv_v = c(1.1, 0.9, 1.2, 1.0),
    E_v = c(0.95, 1.05, 1.1, 0.9),
    E_s = c(0.6, 0.5, 0.7, 0.55),
    E_s2 = c(0.5, 0.45, 0.55, 0.48),
    a_sigma = 1,
    b_sigma = 1,
    L = L,
    U = U,
    A_of = function(g) A.fn(0.5, g),
    B_of = function(g) B.fn(0.5, g),
    lam_of = function(g) C.fn(0.5, g) * abs(g),
    g_from_eta = function(v) L + (U - L) * stats::plogis(v),
    sig_from_ell = function(v) exp(v),
    log_prior_gamma = function(g) 0
  )

  without_jac <- exdqlm:::.exal_static_ld_log_qsiggam(
    c(eta, ell),
    state = state,
    include_jacobian = FALSE
  )
  with_jac <- exdqlm:::.exal_static_ld_log_qsiggam(
    c(eta, ell),
    state = state,
    include_jacobian = TRUE
  )
  jac <- exdqlm:::.exal_static_ld_log_jacobian(eta, ell, L = L, U = U)

  expect_true(is.finite(with_jac))
  expect_equal(with_jac - without_jac, jac, tolerance = 1e-10)
})

test_that("static LDVB xi includes finite Jacobian expectation", {
  set.seed(42)
  n <- 10
  X <- cbind(1, seq(-1, 1, length.out = n))
  beta <- c(0.25, -0.1)
  y <- as.numeric(X %*% beta + rnorm(n, sd = 0.05))

  fit <- exalStaticLDVB(
    y = y,
    X = X,
    p0 = 0.5,
    max_iter = 3,
    tol = 1e-2,
    n_samp_xi = 20,
    verbose = FALSE
  )

  expect_true(is.finite(fit$qsiggam$xi$zeta_logJ))
  expect_true(is.finite(tail(fit$misc$elbo, 1)))
})

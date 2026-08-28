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

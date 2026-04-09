# Regression coverage for the static p0 = 0.25 benchmark that previously
# produced non-finite LDVB warm starts and downstream MCMC warnings.

static_p025_benchmark <- function(n = 60L, seed = 20260409L) {
  set.seed(seed)
  x <- sort(stats::runif(n, -2, 2))
  X <- cbind(1, x)
  mu <- 0 + 0.5 * x
  sigma <- 1.2 + 0.35 * x
  y <- mu + sigma * stats::rnorm(n)
  list(y = y, X = X)
}

test_that("positive truncated-normal helper stays valid in the extreme left tail", {
  moms <- exdqlm:::.exdqlm_pos_truncnorm_moments(
    mu = c(-10, -100, -1000, -1e10),
    tau2 = c(1, 1e-2, 1e-3, 0.625)
  )

  expect_true(all(is.finite(moms$mean)))
  expect_true(all(is.finite(moms$second)))
  expect_true(all(moms$mean > 0))
  expect_true(all(moms$second >= moms$mean^2))
})

test_that("static LDVB p0=0.25 benchmark converges with finite state", {
  dat <- static_p025_benchmark()

  expect_warning(
    fit <- exdqlm::exal_static_LDVB(
      y = dat$y,
      X = dat$X,
      p0 = 0.25,
      max_iter = 120,
      tol = 1e-4,
      verbose = FALSE
    ),
    NA
  )

  expect_true(isTRUE(fit$converged))
  expect_true(all(is.finite(fit$qbeta$m)))
  expect_true(all(is.finite(fit$qv$E_v)))
  expect_true(all(is.finite(fit$qv$E_inv_v)))
  expect_true(all(is.finite(fit$qs$E_s)))
  expect_true(all(is.finite(fit$qs$E_s2)))
  expect_true(is.finite(fit$qsiggam$gamma_mean))
  expect_true(is.finite(fit$qsiggam$sigma_mean))
  expect_true(any(fit$diagnostics$ld_block$trace$xi_stabilized, na.rm = TRUE))
  expect_true(fit$diagnostics$ld_block$xi$stabilized_iter_count >= 1L)
})

test_that("static MCMC slice warm start is clean on the p0=0.25 benchmark", {
  dat <- static_p025_benchmark()

  expect_warning(
    fit <- exdqlm::exal_static_mcmc(
      y = dat$y,
      X = dat$X,
      p0 = 0.25,
      n.burn = 15,
      n.mcmc = 15,
      thin = 1,
      mh.proposal = "slice",
      init.from.vb = TRUE,
      vb_init_controls = list(
        max_iter = 80,
        tol = 1e-4,
        verbose = FALSE
      ),
      verbose = FALSE
    ),
    NA
  )

  expect_true(all(is.finite(as.numeric(fit$samp.beta))))
  expect_true(all(is.finite(as.numeric(fit$samp.sigma))))
  expect_true(all(is.finite(as.numeric(fit$samp.gamma))))
  expect_identical(fit$mh.diagnostics$proposal, "slice")
  expect_true(isTRUE(fit$init.from.vb))
})

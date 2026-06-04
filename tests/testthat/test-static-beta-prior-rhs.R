skip_on_cran()

tiny_rhs_xy <- function(n = 20L) {
  x <- seq(-1, 1, length.out = n)
  X <- cbind(`(Intercept)` = 1, x = x, x2 = x^2)
  y <- as.numeric(0.5 + 0.8 * x - 0.3 * x^2 + stats::rnorm(n, sd = 0.15))
  list(X = X, y = y)
}

test_that("static VB RHS warns about ignored Gaussian prior inputs and returns RHS metadata", {
  set.seed(601)
  dat <- tiny_rhs_xy(18)

  expect_warning(
    fit <- exalStaticLDVB(
      y = dat$y,
      X = dat$X,
      p0 = 0.5,
      beta_prior = "rhs",
      b0 = rep(0.2, ncol(dat$X)),
      V0 = diag(2, ncol(dat$X)),
      beta_prior_controls = list(tau0 = 0.5, nu = 3, s2 = 1, shrink_intercept = FALSE),
      max_iter = 40,
      tol = 5e-3,
      n_samp_xi = 40,
      ld_controls = list(
        xi_method = "delta",
        optimizer_method = "lbfgsb",
        direct_commit = TRUE,
        sigma_init_mode = "data_scale"
      ),
      verbose = FALSE
    ),
    "ignores b0/V0"
  )

  expect_identical(fit$beta_prior$type, "rhs")
  expect_false(isTRUE(fit$beta_prior$summary$shrink_intercept))
  expect_true(is.finite(fit$beta_prior$summary$tau))
  expect_true(is.finite(fit$beta_prior$summary$c2))
  expect_true(is.list(fit$diagnostics$rhs))
  expect_true(is.list(fit$diagnostics$rhs$preflight))
  expect_true(is.finite(fit$diagnostics$rhs$preflight$init_log_tau))
  expect_true(is.finite(fit$diagnostics$rhs$preflight$init_tau))

  vb_state <- fit$beta_prior$state
  expect_true(is.list(vb_state))
  expect_true(all(c("eta_lambda_hat", "eta_tau_hat", "eta_c_hat") %in% names(vb_state)))

  init <- list(
    beta = as.numeric(fit$qbeta$m),
    sigma = as.numeric(fit$qsiggam$sigma_mean)[1],
    gamma = as.numeric(fit$qsiggam$gamma_mean)[1],
    v = as.numeric(fit$qv$E_v),
    s = as.numeric(fit$qs$E_s),
    lambda = exp(as.numeric(vb_state$eta_lambda_hat)),
    tau = exp(as.numeric(vb_state$eta_tau_hat)[1]),
    c2 = exp(as.numeric(vb_state$eta_c_hat)[1])
  )
  expect_true(all(c("lambda", "tau", "c2") %in% names(init)))
  expect_length(init$lambda, ncol(dat$X))
  expect_true(is.finite(init$tau))
  expect_true(is.finite(init$c2))
})

test_that("static AL VB reduced path supports RHS prior", {
  set.seed(602)
  dat <- tiny_rhs_xy(16)

  fit <- exalStaticLDVB(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    dqlm.ind = TRUE,
    beta_prior = "rhs",
    beta_prior_controls = list(tau0 = 0.5, nu = 3, s2 = 1, shrink_intercept = FALSE),
    max_iter = 50,
    tol = 5e-3,
    verbose = FALSE
  )

  expect_identical(fit$beta_prior$type, "rhs")
  expect_true(is.finite(fit$beta_prior$summary$tau))
  expect_true(is.numeric(fit$qbeta$m))
  expect_true(is.list(fit$diagnostics$rhs))
  expect_true(is.list(fit$diagnostics$rhs$preflight))
})

test_that("static MCMC RHS warns, stores latent draws, and normalizes cleanly", {
  set.seed(603)
  dat <- tiny_rhs_xy(18)

  expect_warning(
    fit <- exalStaticMCMC(
      y = dat$y,
      X = dat$X,
      p0 = 0.5,
      beta_prior = "rhs",
      b0 = rep(0.2, ncol(dat$X)),
      V0 = diag(2, ncol(dat$X)),
      beta_prior_controls = list(tau0 = 0.5, nu = 3, s2 = 1, shrink_intercept = FALSE),
      n.burn = 10,
      n.mcmc = 12,
      mh.proposal = "slice",
      trace.diagnostics = FALSE,
      verbose = FALSE
    ),
    "ignores b0/V0"
  )

  expect_identical(fit$beta_prior$type, "rhs")
  expect_s3_class(fit$samp.lambda, "mcmc")
  expect_s3_class(fit$samp.tau, "mcmc")
  expect_s3_class(fit$samp.c2, "mcmc")
  expect_true(is.list(fit$rhs.diagnostics))
  expect_true(is.finite(fit$rhs.diagnostics$summary$tau))
  expect_true(is.finite(fit$rhs.diagnostics$summary$c2))
  expect_true(is.list(fit$rhs.diagnostics$preflight))
  expect_true(is.finite(fit$rhs.diagnostics$preflight$init_log_tau))
  expect_true(is.finite(fit$rhs.diagnostics$preflight$init_tau))
  expect_true(is.list(fit$beta_prior))
  expect_identical(fit$beta_prior$type, "rhs")
  expect_true(is.list(fit$beta_prior$summary))
})

test_that("static AL MCMC reduced path supports RHS prior", {
  set.seed(604)
  dat <- tiny_rhs_xy(18)

  fit <- exalStaticMCMC(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    dqlm.ind = TRUE,
    beta_prior = "rhs",
    beta_prior_controls = list(tau0 = 0.5, nu = 3, s2 = 1, shrink_intercept = FALSE),
    n.burn = 8,
    n.mcmc = 10,
    trace.diagnostics = FALSE,
    verbose = FALSE
  )

  expect_identical(fit$beta_prior$type, "rhs")
  expect_s3_class(fit$samp.lambda, "mcmc")
  expect_true(is.finite(fit$rhs.diagnostics$summary$tau))
  expect_true(is.finite(fit$rhs.diagnostics$summary$c2))
  expect_true(is.list(fit$rhs.diagnostics$preflight))
})

test_that("static RHS VB warmup freezes tau before the forced post-warmup update", {
  obj <- exdqlm:::.static_beta_prior_make(
    beta_prior = "rhs",
    p = 3L,
    b0 = rep(0, 3L),
    V0 = diag(1, 3L),
    beta_prior_controls = list(
      tau0 = 0.5,
      nu = 3,
      s2 = 1,
      shrink_intercept = FALSE,
      freeze_tau_iters = 3L,
      freeze_tau_warmup_iters = 3L,
      update_every = 5L,
      force_tau_after_warmup = TRUE
    )
  )
  state <- obj$init_vb()
  tau_init <- exp(state$eta_tau_hat)
  qbeta <- list(m = c(0, 0.8, -0.4), V = diag(c(1e-6, 0.1, 0.1)))

  state <- obj$update_vb(state, qbeta)
  expect_equal(exp(state$eta_tau_hat), tau_init, tolerance = 1e-12)
  expect_true(isTRUE(state$last_schedule$tau_warmup))
  expect_identical(state$tau_update_count, 0L)

  state <- obj$update_vb(state, qbeta)
  state <- obj$update_vb(state, qbeta)
  expect_identical(state$tau_update_count, 0L)

  state <- obj$update_vb(state, qbeta)
  expect_false(isTRUE(state$last_schedule$tau_warmup))
  expect_identical(state$last_schedule$reason, "force_after_warmup")
  expect_identical(state$tau_update_count, 1L)
})

test_that("static RHS-family priors keep the package default tau warmup", {
  rhs_ctrl <- exdqlm:::.static_parse_beta_prior_controls(list(), prior_type = "rhs")
  rhs_ns_ctrl <- exdqlm:::.static_parse_beta_prior_controls(list(), prior_type = "rhs_ns")

  expect_identical(rhs_ctrl$freeze_tau_iters, 50L)
  expect_identical(rhs_ctrl$freeze_tau_warmup_iters, 50L)
  expect_true(isTRUE(rhs_ctrl$force_tau_after_warmup))

  expect_identical(rhs_ns_ctrl$freeze_tau_iters, 50L)
  expect_identical(rhs_ns_ctrl$freeze_tau_warmup_iters, 50L)
  expect_true(isTRUE(rhs_ns_ctrl$force_tau_after_warmup))
})

test_that("static RHS collapse diagnostic flags tau collapse and zeroed slopes", {
  ctrl <- exdqlm:::.static_parse_beta_prior_controls(list(
    tau0 = 1,
    nu = 4,
    s2 = 1,
    shrink_intercept = FALSE
  ))
  state <- exdqlm:::.static_rhs_init_vb_state(4L, ctrl)
  state$eta_tau_hat <- ctrl$eta_bounds$tau[1]
  qbeta <- list(m = c(0.7, 1e-8, -3e-7, 6e-7), V = diag(rep(1e-10, 4L)))

  diag <- exdqlm:::.static_rhs_collapse_diag(state, qbeta, ctrl)
  expect_true(isTRUE(diag$collapse_flag))
  expect_true(isTRUE(diag$tau_near_zero))
  expect_true(isTRUE(diag$slope_collapse))
  expect_true(is.finite(diag$tau_ratio))
  expect_match(diag$warning, "collapsed near zero")
})

test_that("static RHS init_log_tau null/unset resolves to log(1)=0 and tau=1", {
  ctrl <- exdqlm:::.static_parse_beta_prior_controls(list(
    tau0 = 1e-10,
    init_log_tau = NULL
  ))
  expect_equal(ctrl$init_log_tau, 0)
  expect_equal(ctrl$init_tau, 1)
  expect_identical(ctrl$init_tau_source, "default_log_tau_0")
})

test_that("static RHS explicit numeric init_log_tau override is preserved", {
  ctrl <- exdqlm:::.static_parse_beta_prior_controls(list(
    tau0 = 1e-10,
    init_log_tau = -3.5
  ))
  expect_equal(ctrl$init_log_tau, -3.5)
  expect_equal(ctrl$init_tau, exp(-3.5), tolerance = 1e-12)
  expect_identical(ctrl$init_tau_source, "init_log_tau")
})

test_that("static RHS small tau0 does not force collapse-prone init when unset", {
  ctrl <- exdqlm:::.static_parse_beta_prior_controls(list(
    tau0 = 1e-12
  ))
  expect_equal(ctrl$tau0, 1e-12, tolerance = 1e-20)
  expect_equal(ctrl$init_log_tau, 0)
  expect_equal(ctrl$init_tau, 1)
  expect_gt(ctrl$init_tau, ctrl$tau0)
})

test_that("static RHS preflight fails on non-finite resolved tau init", {
  expect_error(
    exdqlm:::.static_parse_beta_prior_controls(list(init_log_tau = NaN)),
    "must be finite"
  )
  expect_error(
    exdqlm:::.static_parse_beta_prior_controls(list(init_tau = NA_real_)),
    "must be finite and > 0"
  )
})

test_that("static RHS collapse diagnostic flags precision-beta pattern without tau at lower bound", {
  ctrl <- exdqlm:::.static_parse_beta_prior_controls(list(
    tau0 = 1,
    nu = 4,
    s2 = 1,
    shrink_intercept = FALSE,
    collapse_invV_med_tol = 1e8,
    collapse_beta_l2_tol = 1e-6,
    collapse_small_beta_frac_tol = 0.95,
    small_beta_abs_tol = 1e-4
  ))
  state <- exdqlm:::.static_rhs_init_vb_state(4L, ctrl)
  state$eta_tau_hat <- -10
  qbeta <- list(m = c(0.4, 1e-8, -2e-8, 3e-8), V = diag(rep(1e-12, 4L)))

  diag <- exdqlm:::.static_rhs_collapse_diag(state, qbeta, ctrl)
  expect_true(isTRUE(diag$precision_beta_pattern))
  expect_true(isTRUE(diag$collapse_flag))
  expect_false(isTRUE(diag$tau_near_zero))
  expect_match(diag$warning, "precision/beta pattern")
})

test_that("static RHS_NS slab aliases map to RHS slab controls", {
  ctrl <- exdqlm:::.static_parse_beta_prior_controls(
    list(a_zeta = 3, b_zeta = 6, shrink_intercept = FALSE),
    prior_type = "rhs_ns"
  )
  expect_equal(ctrl$a_zeta, 3, tolerance = 1e-12)
  expect_equal(ctrl$b_zeta, 6, tolerance = 1e-12)
  expect_equal(ctrl$nu, 6, tolerance = 1e-12)
  expect_equal(ctrl$s2, 2, tolerance = 1e-12)
  expect_equal(ctrl$s, sqrt(2), tolerance = 1e-12)
  expect_true(is.null(ctrl$zeta2_fixed))
})

test_that("static VB RHS_NS supports fixed zeta2 via zeta2_fixed", {
  set.seed(605)
  dat <- tiny_rhs_xy(16)
  zeta2_fixed <- 0.75

  fit <- exalStaticLDVB(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    beta_prior = "rhs_ns",
    beta_prior_controls = list(
      tau0 = 0.5,
      a_zeta = 2,
      b_zeta = 1,
      zeta2_fixed = zeta2_fixed,
      shrink_intercept = FALSE
    ),
    max_iter = 50,
    tol = 5e-3,
    n_samp_xi = 40,
    ld_controls = list(
      xi_method = "delta",
      optimizer_method = "lbfgsb",
      direct_commit = TRUE,
      sigma_init_mode = "data_scale"
    ),
    verbose = FALSE
  )

  expect_identical(fit$beta_prior$type, "rhs_ns")
  expect_true(is.list(fit$diagnostics$rhs))
  expect_equal(fit$beta_prior$summary$c2, zeta2_fixed, tolerance = 1e-12)
  expect_equal(fit$beta_prior$summary$zeta2, zeta2_fixed, tolerance = 1e-12)
  expect_equal(fit$beta_prior$summary$zeta2_fixed, zeta2_fixed, tolerance = 1e-12)
  expect_equal(fit$diagnostics$rhs$preflight$zeta2_fixed, zeta2_fixed, tolerance = 1e-12)
  expect_equal(fit$beta_prior$summary$a_zeta, 2, tolerance = 1e-12)
  expect_equal(fit$beta_prior$summary$b_zeta, 1, tolerance = 1e-12)
})

test_that("static MCMC RHS_NS fixed zeta2 keeps c2 draws constant", {
  set.seed(606)
  dat <- tiny_rhs_xy(16)
  zeta2_fixed <- 0.9

  fit <- exalStaticMCMC(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    beta_prior = "rhs_ns",
    beta_prior_controls = list(
      tau0 = 0.5,
      a_zeta = 2,
      b_zeta = 1,
      zeta2_fixed = zeta2_fixed,
      shrink_intercept = FALSE
    ),
    n.burn = 8,
    n.mcmc = 10,
    mh.proposal = "slice",
    trace.diagnostics = FALSE,
    verbose = FALSE
  )

  expect_identical(fit$beta_prior$type, "rhs_ns")
  expect_s3_class(fit$samp.c2, "mcmc")
  expect_true(all(abs(as.numeric(fit$samp.c2) - zeta2_fixed) <= 1e-12))
  expect_equal(fit$beta_prior$summary$zeta2_fixed, zeta2_fixed, tolerance = 1e-12)
  expect_equal(fit$rhs.diagnostics$summary$zeta2, zeta2_fixed, tolerance = 1e-12)
})

test_that("static RHS_NS VB uses closed-form IG block moments and precision map", {
  obj <- exdqlm:::.static_beta_prior_make(
    beta_prior = "rhs_ns",
    p = 4L,
    b0 = rep(0, 4L),
    V0 = diag(1, 4L),
    beta_prior_controls = list(
      tau0 = 0.7,
      a_zeta = 2.5,
      b_zeta = 1.2,
      shrink_intercept = FALSE,
      n_inner = 1L,
      freeze_tau_warmup_iters = 0L,
      update_every = 1L
    )
  )
  st <- obj$init_vb()
  qbeta <- list(
    m = c(0.25, 0.7, -0.35, 0.15),
    V = diag(c(1e-4, 0.08, 0.05, 0.04))
  )

  st <- obj$update_vb(st, qbeta)
  active <- 2:4

  expect_true(all(is.finite(st$lambda2[active])))
  expect_true(all(st$lambda2[active] > 0))
  expect_true(is.finite(st$tau2))
  expect_true(st$tau2 > 0)
  expect_true(is.finite(st$xi))
  expect_true(st$xi > 0)
  expect_true(is.finite(st$zeta2))
  expect_true(st$zeta2 > 0)

  expect_equal(st$a_lambda[active], rep(1, length(active)), tolerance = 1e-12)
  expect_equal(st$a_nu[active], rep(1, length(active)), tolerance = 1e-12)
  expect_equal(st$a_tau, (length(active) + 1) / 2, tolerance = 1e-12)
  expect_equal(st$a_xi, 1, tolerance = 1e-12)
  expect_equal(st$a_zeta, obj$controls$a_zeta + length(active) / 2, tolerance = 1e-12)

  prec <- obj$beta_system_vb(st)$prec_diag
  expect_equal(prec[1], obj$controls$intercept_prec, tolerance = 1e-12)
  expect_equal(
    prec[active],
    st$E_inv_tau2 * st$E_inv_lambda2[active] + st$E_inv_zeta2,
    tolerance = 1e-10
  )
})

test_that("static RHS_NS MCMC uses closed-form Gibbs scales and exact precision expression", {
  set.seed(607)
  obj <- exdqlm:::.static_beta_prior_make(
    beta_prior = "rhs_ns",
    p = 4L,
    b0 = rep(0, 4L),
    V0 = diag(1, 4L),
    beta_prior_controls = list(
      tau0 = 0.6,
      a_zeta = 2,
      b_zeta = 1,
      shrink_intercept = FALSE,
      freeze_tau_warmup_iters = 1L
    )
  )
  beta_vec <- c(0.2, 0.9, -0.5, 0.3)
  active <- 2:4

  st0 <- obj$init_mcmc()
  tau2_0 <- st0$tau2

  st1 <- obj$update_mcmc(st0, beta_vec)
  expect_true(isTRUE(st1$freeze_tau))
  expect_equal(st1$tau2, tau2_0, tolerance = 1e-12)

  st2 <- obj$update_mcmc(st1, beta_vec)
  expect_false(isTRUE(st2$freeze_tau))
  expect_true(is.finite(st2$tau2))
  expect_true(st2$tau2 > 0)
  expect_true(all(st2$lambda2[active] > 0))
  expect_true(all(st2$nu[active] > 0))

  prec <- obj$beta_system_mcmc(st2)$prec_diag
  expect_equal(prec[1], obj$controls$intercept_prec, tolerance = 1e-12)
  expect_equal(
    prec[active],
    1 / (st2$tau2 * st2$lambda2[active]) + 1 / st2$zeta2,
    tolerance = 1e-10
  )
})

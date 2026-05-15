test_that("Q-DESN RHS-family constructors enforce shrink_intercept = FALSE", {
  withr::local_options(list(exdqlm.warned_qdesn_rhs_shrink_intercept_forced_false = FALSE))

  expect_warning(
    prior_rhs <- exdqlm::beta_prior("rhs", rhs = list(
      tau0 = 0.4,
      nu = 4,
      s2 = 1.0,
      shrink_intercept = TRUE
    )),
    "forcing shrink_intercept=FALSE"
  )
  expect_false(isTRUE(prior_rhs$hypers$shrink_intercept))

  withr::local_options(list(exdqlm.warned_qdesn_rhs_shrink_intercept_forced_false = FALSE))
  expect_warning(
    prior_ns <- exdqlm::beta_prior("rhs_ns", rhs = list(
      tau0 = 0.4,
      a_zeta = 2.0,
      b_zeta = 1.0,
      s2 = 1.0,
      shrink_intercept = TRUE
    )),
    "forcing shrink_intercept=FALSE"
  )
  expect_false(isTRUE(prior_ns$hypers$shrink_intercept))
})

test_that("inference resolver defaults beta prior to rhs_ns and enforces intercept policy", {
  cfg_default <- list(
    inference = list(
      method = "vb",
      vb = list(priors = list(beta = list()))
    )
  )
  inf_default <- exdqlm:::resolve_exal_inference_config(cfg_default, p_vec = c(0.5), verbose = FALSE)
  expect_identical(inf_default$beta_prior_type, "rhs_ns")
  expect_false(isTRUE(inf_default$beta_prior_rhs$shrink_intercept))

  withr::local_options(list(exdqlm.warned_qdesn_rhs_shrink_intercept_forced_false = FALSE))
  cfg_force <- list(
    inference = list(
      method = "mcmc",
      mcmc = list(
        priors = list(
          beta = list(
            type = "rhs_ns",
            rhs_ns = list(
              tau0 = 0.35,
              a_zeta = 2.0,
              b_zeta = 1.0,
              shrink_intercept = TRUE
            )
          )
        )
      )
    )
  )
  expect_warning(
    inf_force <- exdqlm:::resolve_exal_inference_config(cfg_force, p_vec = c(0.5), verbose = FALSE),
    "forcing shrink_intercept=FALSE"
  )
  expect_identical(inf_force$beta_prior_type, "rhs_ns")
  expect_false(isTRUE(inf_force$beta_prior_rhs$shrink_intercept))
})

test_that("qdesn_fit defaults to rhs_ns prior in VB and MCMC paths", {
  withr::local_seed(20260329)
  y <- as.numeric(3 + sin(seq_len(36L) / 4) + 0.10 * stats::rnorm(36L))

  fit_vb <- exdqlm::qdesn_fit(
    y = y,
    p0 = 0.5,
    method = "vb",
    D = 1L,
    n = 8L,
    m = 4L,
    alpha = 0.3,
    rho = 0.9,
    act_f = "tanh",
    act_k = "identity",
    pi_w = 0.2,
    pi_in = 1.0,
    washout = 4L,
    add_bias = TRUE,
    seed = 123L,
    vb_args = list(
      max_iter = 12L,
      min_iter_elbo = 4L,
      tol = 1e-3,
      n_samp_xi = 50L,
      verbose = FALSE
    )
  )
  expect_identical(fit_vb$fit$beta_prior$type, "rhs_ns")
  expect_false(isTRUE(fit_vb$fit$beta_prior$hypers$shrink_intercept))

  fit_mcmc <- exdqlm::qdesn_fit(
    y = y,
    p0 = 0.5,
    method = "mcmc",
    D = 1L,
    n = 8L,
    m = 4L,
    alpha = 0.3,
    rho = 0.9,
    act_f = "tanh",
    act_k = "identity",
    pi_w = 0.2,
    pi_in = 1.0,
    washout = 4L,
    add_bias = TRUE,
    seed = 123L,
    mcmc_args = list(
      n_burn = 10L,
      n_mcmc = 12L,
      thin = 1L,
      verbose = FALSE,
      init_from_vb = FALSE
    )
  )
  expect_identical(fit_mcmc$fit$beta_prior$type, "rhs_ns")
  expect_false(isTRUE(fit_mcmc$fit$beta_prior$hypers$shrink_intercept))
})

test_that("rhs_ns beta prior object honors VB tau warmup before the first forced update", {
  prior_obj <- exdqlm::beta_prior("rhs_ns", rhs = list(
    tau0 = 0.5,
    a_zeta = 2.0,
    b_zeta = 1.0,
    s2 = 1.0,
    shrink_intercept = FALSE,
    n_inner = 1L,
    freeze_tau_iters = 3L,
    freeze_tau_warmup_iters = 3L,
    force_tau_after_warmup = TRUE
  ))

  st0 <- prior_obj$init(4L)
  tau2_init <- st0$tau2
  qbeta <- list(
    m = c(0.25, 0.7, -0.35, 0.15),
    V = diag(c(1e-4, 0.08, 0.05, 0.04))
  )

  st1 <- prior_obj$update(st0, qbeta)
  st2 <- prior_obj$update(st1, qbeta)
  st3 <- prior_obj$update(st2, qbeta)
  st4 <- prior_obj$update(st3, qbeta)

  expect_true(isTRUE(st1$freeze_tau))
  expect_true(isTRUE(st2$freeze_tau))
  expect_true(isTRUE(st3$freeze_tau))
  expect_equal(st1$tau2, tau2_init, tolerance = 1e-12)
  expect_equal(st2$tau2, tau2_init, tolerance = 1e-12)
  expect_equal(st3$tau2, tau2_init, tolerance = 1e-12)
  expect_identical(st3$tau_update_count, 0L)

  expect_false(isTRUE(st4$freeze_tau))
  expect_identical(st4$last_schedule$reason, "force_after_warmup")
  expect_true(isTRUE(st4$last_schedule$tau_updated))
  expect_identical(st4$tau_update_count, 1L)
  expect_true(isTRUE(st4$has_post_warmup_tau_update))
  expect_gt(abs(as.numeric(st4$tau2) - as.numeric(tau2_init)), 1e-8)
})

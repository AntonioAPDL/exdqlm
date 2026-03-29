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


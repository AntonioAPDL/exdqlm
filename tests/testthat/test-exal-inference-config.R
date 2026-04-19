test_that("RHS NULL init_log_tau keeps legacy default tau initialization", {
  cfg <- list(
    inference = list(
      method = "vb",
      vb = list(
        priors = list(
          beta = list(
            type = "rhs",
            rhs = list(
              tau0 = 0.001,
              nu = 4.0,
              s2 = 0.1,
              init_log_tau = NULL
            )
          )
        )
      )
    )
  )

  inf <- exdqlm:::resolve_exal_inference_config(cfg, p_vec = c(0.50), verbose = FALSE)
  expect_equal(as.numeric(inf$beta_prior_rhs$init_log_tau), 0.0, tolerance = 1e-12)

  prior_obj <- exdqlm:::exal_make_beta_prior(type = "rhs", rhs = inf$beta_prior_rhs)
  st <- prior_obj$init(5L)
  expect_equal(as.numeric(st$eta_tau_hat), 0.0, tolerance = 1e-12)
})

test_that("RHS explicit init_log_tau override is preserved", {
  init_log_tau_target <- log(0.2)
  cfg <- list(
    inference = list(
      method = "vb",
      vb = list(
        priors = list(
          beta = list(
            type = "rhs",
            rhs = list(
              tau0 = 0.001,
              nu = 4.0,
              s2 = 0.1,
              init_log_tau = init_log_tau_target
            )
          )
        )
      )
    )
  )

  inf <- exdqlm:::resolve_exal_inference_config(cfg, p_vec = c(0.50), verbose = FALSE)
  expect_equal(as.numeric(inf$beta_prior_rhs$init_log_tau), init_log_tau_target, tolerance = 1e-12)

  prior_obj <- exdqlm:::exal_make_beta_prior(type = "rhs", rhs = inf$beta_prior_rhs)
  st <- prior_obj$init(5L)
  expect_equal(as.numeric(st$eta_tau_hat), init_log_tau_target, tolerance = 1e-12)
})

test_that("RHS non-numeric init_log_tau override falls back to legacy default with warning", {
  cfg <- list(
    inference = list(
      method = "vb",
      vb = list(
        priors = list(
          beta = list(
            type = "rhs",
            rhs = list(
              tau0 = 0.001,
              nu = 4.0,
              s2 = 0.1,
              init_log_tau = "not-a-number"
            )
          )
        )
      )
    )
  )

  expect_warning(
    inf <- exdqlm:::resolve_exal_inference_config(cfg, p_vec = c(0.50), verbose = FALSE),
    "non-numeric"
  )
  expect_equal(as.numeric(inf$beta_prior_rhs$init_log_tau), 0.0, tolerance = 1e-12)
})

test_that("RHS_NS settings resolve and instantiate beta prior object", {
  cfg <- list(
    inference = list(
      method = "vb",
      vb = list(
        rhs = list(
          freeze_tau_iters = 7L,
          freeze_tau_warmup_iters = 9L,
          force_tau_after_warmup = TRUE
        ),
        priors = list(
          beta = list(
            type = "rhs_ns",
            rhs_ns = list(
              tau0 = 0.25,
              a_zeta = 3.0,
              b_zeta = 2.0,
              s2 = 0.5,
              shrink_intercept = FALSE,
              init_log_tau = log(0.4)
            )
          )
        )
      )
    )
  )

  inf <- exdqlm:::resolve_exal_inference_config(cfg, p_vec = c(0.5), verbose = FALSE)
  expect_identical(inf$beta_prior_type, "rhs_ns")
  expect_equal(as.numeric(inf$beta_prior_rhs$tau0), 0.25, tolerance = 1e-12)
  expect_equal(as.numeric(inf$beta_prior_rhs$a_zeta), 3.0, tolerance = 1e-12)
  expect_equal(as.numeric(inf$beta_prior_rhs$b_zeta), 2.0, tolerance = 1e-12)
  expect_true(is.finite(as.numeric(inf$beta_prior_rhs$init_tau2)))
  expect_equal(as.integer(inf$beta_prior_rhs$freeze_tau_iters), 7L)
  expect_equal(as.integer(inf$beta_prior_rhs$freeze_tau_warmup_iters), 9L)
  expect_true(isTRUE(inf$beta_prior_rhs$force_tau_after_warmup))

  prior_obj <- exdqlm:::exal_make_beta_prior(type = "rhs_ns", rhs = inf$beta_prior_rhs)
  expect_identical(prior_obj$type, "rhs_ns")
  expect_equal(as.integer(prior_obj$control$freeze_tau_iters), 7L)
  expect_equal(as.integer(prior_obj$control$freeze_tau_warmup_iters), 9L)
  expect_true(isTRUE(prior_obj$control$force_tau_after_warmup))
  st <- prior_obj$init(4L)
  expect_equal(length(st$lambda2), 4L)
  expect_true(all(is.finite(st$lambda2)))
  expect_true(st$tau2 > 0)
  expect_true(st$zeta2 > 0)
})

test_that("RHS_NS NULL init_log_tau keeps guardrail default log_tau=0", {
  cfg <- list(
    inference = list(
      method = "vb",
      vb = list(
        priors = list(
          beta = list(
            type = "rhs_ns",
            rhs_ns = list(
              tau0 = 0.001,
              s2 = 0.1,
              init_log_tau = NULL
            )
          )
        )
      )
    )
  )

  inf <- exdqlm:::resolve_exal_inference_config(cfg, p_vec = c(0.5), verbose = FALSE)
  expect_equal(as.numeric(inf$beta_prior_rhs$init_log_tau), 0.0, tolerance = 1e-12)
  expect_equal(as.numeric(inf$beta_prior_rhs$init_tau2), 1.0, tolerance = 1e-12)
})

test_that("RHS_NS non-numeric init_log_tau falls back to guardrail default with warning", {
  cfg <- list(
    inference = list(
      method = "vb",
      vb = list(
        priors = list(
          beta = list(
            type = "rhs_ns",
            rhs_ns = list(
              tau0 = 0.001,
              s2 = 0.1,
              init_log_tau = "not-a-number"
            )
          )
        )
      )
    )
  )

  expect_warning(
    inf <- exdqlm:::resolve_exal_inference_config(cfg, p_vec = c(0.5), verbose = FALSE),
    "non-numeric"
  )
  expect_equal(as.numeric(inf$beta_prior_rhs$init_log_tau), 0.0, tolerance = 1e-12)
  expect_equal(as.numeric(inf$beta_prior_rhs$init_tau2), 1.0, tolerance = 1e-12)
})

test_that("likelihood family defaults to exal and supports explicit al routing", {
  cfg_default <- list(
    inference = list(
      method = "vb",
      vb = list(priors = list(beta = list(type = "ridge", tau2 = 1e4)))
    )
  )
  inf_default <- exdqlm:::resolve_exal_inference_config(cfg_default, p_vec = c(0.5), verbose = FALSE)
  expect_identical(inf_default$likelihood_family, "exal")
  spec_default <- exdqlm:::resolve_exal_quantile_fit_spec(inf_default, idx_p = 1L, p0 = 0.5)
  expect_identical(spec_default$likelihood_family, "exal")

  cfg_al <- list(
    inference = list(
      method = "mcmc",
      likelihood_family = "al",
      mcmc = list(priors = list(beta = list(type = "rhs_ns")))
    )
  )
  inf_al <- exdqlm:::resolve_exal_inference_config(cfg_al, p_vec = c(0.5), verbose = FALSE)
  expect_identical(inf_al$likelihood_family, "al")
  spec_al <- exdqlm:::resolve_exal_quantile_fit_spec(inf_al, idx_p = 1L, p0 = 0.5)
  expect_identical(spec_al$likelihood_family, "al")
})

test_that("sigmagam warmup controls resolve for VB, MCMC warm start, and MCMC core", {
  cfg <- list(
    inference = list(
      method = "mcmc",
      vb = list(
        sigmagam = list(
          freeze_warmup_iters = 12L,
          force_after_warmup = FALSE,
          postwarmup_damping = 0.6,
          postwarmup_damping_iters = 4L,
          min_postwarmup_updates = 2L
        )
      ),
      mcmc = list(
        vb_warm_start_control = list(
          max_iter = 25L,
          sigmagam = list(
            freeze_warmup_iters = 8L,
            force_after_warmup = TRUE,
            postwarmup_damping = 0.5,
            postwarmup_damping_iters = 3L,
            min_postwarmup_updates = 1L
          )
        ),
        sigmagam = list(
          freeze_burnin_iters = 15L,
          freeze_only_during_burn = FALSE,
          force_after_warmup = FALSE,
          delay_adapt_until_after_warmup = FALSE,
          delay_laplace_refresh_until_after_warmup = FALSE
        ),
        latent_v = list(
          enabled = TRUE,
          freeze_burnin_iters = 9L,
          freeze_only_during_burn = TRUE,
          sparse_update_every = 5L,
          sparse_update_until_iter = 40L,
          force_first_postwarmup_update = FALSE,
          trace = FALSE
        ),
        priors = list(
          beta = list(type = "ridge", tau2 = 5)
        )
      )
    )
  )

  inf <- exdqlm:::resolve_exal_inference_config(cfg, p_vec = c(0.25, 0.75), verbose = FALSE)

  expect_equal(inf$vb$args_base$sigmagam$freeze_warmup_iters, 12L)
  expect_false(isTRUE(inf$vb$args_base$sigmagam$force_after_warmup))
  expect_equal(inf$vb$args_base$sigmagam$postwarmup_damping, 0.6, tolerance = 1e-12)
  expect_equal(inf$vb$args_base$sigmagam$postwarmup_damping_iters, 4L)
  expect_equal(inf$vb$args_base$sigmagam$min_postwarmup_updates, 2L)

  expect_equal(inf$mcmc$control_base$vb_warm_start_control$max_iter, 25L)
  expect_equal(inf$mcmc$control_base$vb_warm_start_control$sigmagam$freeze_warmup_iters, 8L)
  expect_true(isTRUE(inf$mcmc$control_base$vb_warm_start_control$sigmagam$force_after_warmup))
  expect_equal(inf$mcmc$control_base$vb_warm_start_control$sigmagam$postwarmup_damping, 0.5, tolerance = 1e-12)
  expect_equal(inf$mcmc$control_base$vb_warm_start_control$sigmagam$postwarmup_damping_iters, 3L)
  expect_equal(inf$mcmc$control_base$vb_warm_start_control$sigmagam$min_postwarmup_updates, 1L)

  expect_equal(inf$mcmc$control_base$sigmagam$freeze_burnin_iters, 15L)
  expect_false(isTRUE(inf$mcmc$control_base$sigmagam$freeze_only_during_burn))
  expect_false(isTRUE(inf$mcmc$control_base$sigmagam$force_after_warmup))
  expect_false(isTRUE(inf$mcmc$control_base$sigmagam$delay_adapt_until_after_warmup))
  expect_false(isTRUE(inf$mcmc$control_base$sigmagam$delay_laplace_refresh_until_after_warmup))
  expect_true(isTRUE(inf$mcmc$control_base$latent_v$enabled))
  expect_equal(inf$mcmc$control_base$latent_v$freeze_burnin_iters, 9L)
  expect_true(isTRUE(inf$mcmc$control_base$latent_v$freeze_only_during_burn))
  expect_equal(inf$mcmc$control_base$latent_v$sparse_update_every, 5L)
  expect_equal(inf$mcmc$control_base$latent_v$sparse_update_until_iter, 40L)
  expect_false(isTRUE(inf$mcmc$control_base$latent_v$force_first_postwarmup_update))
  expect_false(isTRUE(inf$mcmc$control_base$latent_v$trace))
})

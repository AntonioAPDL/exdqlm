tiny_static_xy_builder <- function(n = 18L) {
  x <- seq(-1, 1, length.out = n)
  X <- cbind(1, x)
  y <- as.numeric(X %*% c(0.25, -0.2) + stats::rnorm(n, sd = 0.15))
  list(X = X, y = y)
}

tiny_dyn_model_builder <- function(TT) {
  as.exdqlm(list(
    m0 = 0,
    C0 = matrix(1, 1, 1),
    FF = matrix(1, nrow = 1, ncol = TT),
    GG = array(1, dim = c(1, 1, TT))
  ))
}

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

test_that("VB exact chunking config resolves without changing absent defaults", {
  cfg_default <- list(
    inference = list(
      method = "vb",
      vb = list(priors = list(beta = list(type = "ridge", tau2 = 1e4)))
    )
  )
  inf_default <- exdqlm:::resolve_exal_inference_config(cfg_default, p_vec = c(0.5), verbose = FALSE)
  expect_false("chunking" %in% names(inf_default$vb$args_base))

  cfg_chunked <- list(
    inference = list(
      method = "vb",
      vb = list(
        chunking = list(
          enabled = TRUE,
          mode = "exact",
          chunk_size = 64L,
          order = "sequential",
          trace = TRUE
        ),
        priors = list(beta = list(type = "ridge", tau2 = 1e4))
      )
    )
  )
  inf_chunked <- exdqlm:::resolve_exal_inference_config(cfg_chunked, p_vec = c(0.5), verbose = FALSE)
  expect_true(isTRUE(inf_chunked$vb$args_base$chunking$enabled))
  expect_identical(inf_chunked$vb$args_base$chunking$mode, "exact")
  expect_equal(inf_chunked$vb$args_base$chunking$chunk_size, 64L)
  expect_identical(inf_chunked$vb$args_base$chunking$order, "sequential")
  expect_true(isTRUE(inf_chunked$vb$args_base$chunking$trace))
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
          rescue_on_invalid = TRUE,
          rescue_strategy = "previous_state",
          rescue_max_consecutive = 4L,
          rescue_burn_only = TRUE,
          rescue_force_retry_next_iter = FALSE,
          record_rescue_trace = FALSE,
          trace = FALSE
        ),
        latent_s = list(
          enabled = TRUE,
          freeze_burnin_iters = 11L,
          freeze_only_during_burn = FALSE,
          sparse_update_every = 4L,
          sparse_update_until_iter = 55L,
          force_first_postwarmup_update = FALSE,
          trace = FALSE
        ),
        theta = list(
          enabled = TRUE,
          freeze_burnin_iters = 13L,
          freeze_only_during_burn = TRUE,
          sparse_update_every = 3L,
          sparse_update_until_iter = 60L,
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
  expect_true(isTRUE(inf$mcmc$control_base$latent_v$rescue_on_invalid))
  expect_identical(inf$mcmc$control_base$latent_v$rescue_strategy, "previous_state")
  expect_equal(inf$mcmc$control_base$latent_v$rescue_max_consecutive, 4L)
  expect_true(isTRUE(inf$mcmc$control_base$latent_v$rescue_burn_only))
  expect_false(isTRUE(inf$mcmc$control_base$latent_v$rescue_force_retry_next_iter))
  expect_false(isTRUE(inf$mcmc$control_base$latent_v$record_rescue_trace))
  expect_false(isTRUE(inf$mcmc$control_base$latent_v$trace))
  expect_true(isTRUE(inf$mcmc$control_base$latent_s$enabled))
  expect_equal(inf$mcmc$control_base$latent_s$freeze_burnin_iters, 11L)
  expect_false(isTRUE(inf$mcmc$control_base$latent_s$freeze_only_during_burn))
  expect_equal(inf$mcmc$control_base$latent_s$sparse_update_every, 4L)
  expect_equal(inf$mcmc$control_base$latent_s$sparse_update_until_iter, 55L)
  expect_false(isTRUE(inf$mcmc$control_base$latent_s$force_first_postwarmup_update))
  expect_false(isTRUE(inf$mcmc$control_base$latent_s$trace))
  expect_true(isTRUE(inf$mcmc$control_base$theta$enabled))
  expect_equal(inf$mcmc$control_base$theta$freeze_burnin_iters, 13L)
  expect_true(isTRUE(inf$mcmc$control_base$theta$freeze_only_during_burn))
  expect_equal(inf$mcmc$control_base$theta$sparse_update_every, 3L)
  expect_equal(inf$mcmc$control_base$theta$sparse_update_until_iter, 60L)
  expect_false(isTRUE(inf$mcmc$control_base$theta$force_first_postwarmup_update))
  expect_false(isTRUE(inf$mcmc$control_base$theta$trace))
})

test_that("precision-beta presets normalize to the validated recovery profiles", {
  recommended <- exdqlm::exal_make_precision_beta_control()
  eigen <- exdqlm::exal_make_precision_beta_control("eigen_v1")

  expect_identical(as.character(recommended$preset), "ladder_v2")
  expect_true(isTRUE(recommended$enabled))
  expect_false(isTRUE(recommended$eigen_fallback))
  expect_equal(max(as.numeric(recommended$jitter_ladder)), 1e-2, tolerance = 1e-12)

  expect_identical(as.character(eigen$preset), "eigen_v1")
  expect_true(isTRUE(eigen$enabled))
  expect_true(isTRUE(eigen$eigen_fallback))
  expect_equal(max(as.numeric(eigen$jitter_ladder)), 1e-6, tolerance = 1e-12)
})

test_that("precision-beta config resolves preset aliases and explicit overrides", {
  cfg <- list(
    inference = list(
      method = "mcmc",
      mcmc = list(
        precision_beta = "recommended",
        priors = list(beta = list(type = "ridge", tau2 = 5))
      )
    )
  )

  inf <- exdqlm:::resolve_exal_inference_config(cfg, p_vec = c(0.5), verbose = FALSE)
  expect_identical(as.character(inf$mcmc$control_base$precision_beta$preset), "ladder_v2")
  expect_true(isTRUE(inf$mcmc$control_base$precision_beta$enabled))
  expect_equal(max(as.numeric(inf$mcmc$control_base$precision_beta$jitter_ladder)), 1e-2, tolerance = 1e-12)

  cfg_override <- list(
    inference = list(
      method = "mcmc",
      mcmc = list(
        precision_beta = list(
          preset = "eigen_v1",
          eigen_floor_abs = 1e-5,
          trace = FALSE
        ),
        priors = list(beta = list(type = "ridge", tau2 = 5))
      )
    )
  )

  inf_override <- exdqlm:::resolve_exal_inference_config(cfg_override, p_vec = c(0.5), verbose = FALSE)
  expect_identical(as.character(inf_override$mcmc$control_base$precision_beta$preset), "eigen_v1")
  expect_true(isTRUE(inf_override$mcmc$control_base$precision_beta$eigen_fallback))
  expect_equal(as.numeric(inf_override$mcmc$control_base$precision_beta$eigen_floor_abs), 1e-5, tolerance = 1e-12)
  expect_false(isTRUE(inf_override$mcmc$control_base$precision_beta$trace))
})

test_that("public control builders expose the normalized advanced warmup surface", {
  vb_sigmagam_default <- exdqlm::exal_make_vb_sigmagam_control()
  expect_equal(vb_sigmagam_default$freeze_warmup_iters, 10L)
  expect_true(isTRUE(vb_sigmagam_default$force_after_warmup))
  expect_equal(vb_sigmagam_default$postwarmup_damping, 0.6, tolerance = 1e-12)
  expect_equal(vb_sigmagam_default$postwarmup_damping_iters, 5L)
  expect_equal(vb_sigmagam_default$min_postwarmup_updates, 1L)

  vb_sigmagam <- exdqlm::exal_make_vb_sigmagam_control(
    freeze_warmup_iters = 12L,
    force_after_warmup = FALSE,
    postwarmup_damping = 0.5,
    postwarmup_damping_iters = 3L,
    min_postwarmup_updates = 2L
  )
  expect_equal(vb_sigmagam$freeze_warmup_iters, 12L)
  expect_false(isTRUE(vb_sigmagam$force_after_warmup))
  expect_equal(vb_sigmagam$postwarmup_damping, 0.5, tolerance = 1e-12)
  expect_equal(vb_sigmagam$postwarmup_damping_iters, 3L)
  expect_equal(vb_sigmagam$min_postwarmup_updates, 2L)

  vb_sts <- exdqlm::exal_make_vb_sts_control(
    freeze_warmup_iters = 10L,
    force_after_warmup = FALSE,
    min_postwarmup_updates = 3L
  )
  expect_equal(vb_sts$freeze_warmup_iters, 10L)
  expect_false(isTRUE(vb_sts$force_after_warmup))
  expect_equal(vb_sts$min_postwarmup_updates, 3L)

  vb_control <- exdqlm::exal_make_vb_control(
    max_iter = 180L,
    min_iter_elbo = 14L,
    tol = 2e-4,
    tol_par = 3e-4,
    n_samp_xi = 600L,
    progress_every = 50L,
    verbose = TRUE,
    sigmagam = vb_sigmagam,
    sts = vb_sts,
    rhs = list(
      freeze_tau_warmup_iters = 15L,
      update_every_warmup = 4L,
      force_tau_after_warmup = FALSE
    ),
    diagnostics = list(rhs_trace = TRUE)
  )
  expect_equal(vb_control$max_iter, 180L)
  expect_equal(vb_control$min_iter_elbo, 14L)
  expect_equal(vb_control$tol, 2e-4, tolerance = 1e-12)
  expect_equal(vb_control$tol_par, 3e-4, tolerance = 1e-12)
  expect_equal(vb_control$progress_every, 50L)
  expect_true(isTRUE(vb_control$rhs_trace))
  expect_equal(vb_control$rhs_freeze_tau_warmup_iters, 15L)
  expect_equal(vb_control$rhs_update_every_warmup, 4L)
  expect_false(isTRUE(vb_control$rhs_force_tau_after_warmup))
  expect_equal(vb_control$sigmagam$freeze_warmup_iters, 12L)
  expect_equal(vb_control$sts$freeze_warmup_iters, 10L)
  expect_false(isTRUE(vb_control$sts$force_after_warmup))

  vb_control_chunked <- exdqlm::exal_make_vb_control(
    chunking = list(
      enabled = TRUE,
      mode = "exact",
      chunk_size = 128L,
      order = "sequential",
      trace = TRUE
    )
  )
  expect_true(isTRUE(vb_control_chunked$chunking$enabled))
  expect_identical(vb_control_chunked$chunking$mode, "exact")
  expect_equal(vb_control_chunked$chunking$chunk_size, 128L)
  expect_identical(vb_control_chunked$chunking$order, "sequential")
  expect_true(isTRUE(vb_control_chunked$chunking$trace))

  expect_false("chunking" %in% names(exdqlm::exal_make_vb_control()))
  vb_control_stochastic <- exdqlm::exal_make_vb_control(
    chunking = list(
      enabled = TRUE,
      mode = "stochastic",
      chunk_size = 64L,
      order = "random",
      seed = 20260527L
    )
  )
  expect_true(isTRUE(vb_control_stochastic$chunking$enabled))
  expect_identical(vb_control_stochastic$chunking$mode, "stochastic")
  expect_equal(vb_control_stochastic$chunking$chunk_size, 64L)
  expect_identical(vb_control_stochastic$chunking$order, "random")
  expect_equal(vb_control_stochastic$chunking$seed, 20260527L)

  latent_state <- exdqlm::exal_make_mcmc_latent_state_control(
    mode = "u_st_pair",
    freeze_burnin_iters = 22L,
    freeze_only_during_burn = FALSE,
    force_after_warmup = FALSE,
    min_postwarmup_updates = 2L,
    trace = FALSE
  )
  expect_identical(latent_state$mode, "u_st_pair")
  expect_equal(latent_state$freeze_burnin_iters, 22L)
  expect_false(isTRUE(latent_state$freeze_only_during_burn))
  expect_false(isTRUE(latent_state$force_after_warmup))
  expect_equal(latent_state$min_postwarmup_updates, 2L)
  expect_false(isTRUE(latent_state$trace))

  dqlm_sigma <- exdqlm::exal_make_mcmc_dqlm_sigma_control(
    freeze_burnin_iters = 14L,
    freeze_only_during_burn = FALSE,
    force_after_warmup = FALSE,
    trace = FALSE
  )
  expect_equal(dqlm_sigma$freeze_burnin_iters, 14L)
  expect_false(isTRUE(dqlm_sigma$freeze_only_during_burn))
  expect_false(isTRUE(dqlm_sigma$force_after_warmup))
  expect_false(isTRUE(dqlm_sigma$trace))

  mcmc_sigmagam_default <- exdqlm::exal_make_mcmc_sigmagam_control()
  expect_equal(mcmc_sigmagam_default$freeze_burnin_iters, 25L)
  expect_true(isTRUE(mcmc_sigmagam_default$freeze_only_during_burn))
  expect_true(isTRUE(mcmc_sigmagam_default$force_after_warmup))
  expect_true(isTRUE(mcmc_sigmagam_default$delay_adapt_until_after_warmup))
  expect_true(isTRUE(mcmc_sigmagam_default$delay_laplace_refresh_until_after_warmup))

  rhs_control_default <- exdqlm::exal_make_mcmc_rhs_control()
  expect_equal(rhs_control_default$freeze_tau_burnin_iters, 50L)
  expect_true(isTRUE(rhs_control_default$freeze_tau_only_during_burn))

  rhs_control <- exdqlm::exal_make_mcmc_rhs_control(
    freeze_tau_burnin_iters = 40L,
    width_adapt_enabled = TRUE,
    width_adapt_warmup_iters = 50L,
    step_size = 0.08
  )
  expect_equal(rhs_control$freeze_tau_burnin_iters, 40L)
  expect_true(isTRUE(rhs_control$width_adapt$enabled))
  expect_equal(rhs_control$width_adapt$warmup_iters, 50L)
  expect_equal(rhs_control$width_adapt$step_size, 0.08, tolerance = 1e-12)

  mcmc_control <- exdqlm::exal_make_mcmc_control(
    n_burn = 600L,
    n_mcmc = 200L,
    thin = 2L,
    sigmagam = exdqlm::exal_make_mcmc_sigmagam_control(
      freeze_burnin_iters = 30L,
      force_after_warmup = FALSE
    ),
    theta = exdqlm::exal_make_mcmc_theta_control(
      freeze_burnin_iters = 20L,
      sparse_update_every = 3L,
      sparse_update_until_iter = 50L,
      force_first_postwarmup_update = FALSE
    ),
    latent_state = latent_state,
    dqlm_sigma = dqlm_sigma,
    latent_v = exdqlm::exal_make_mcmc_latent_v_control(
      freeze_burnin_iters = 25L,
      sparse_update_every = 4L,
      sparse_update_until_iter = 60L,
      rescue_on_invalid = TRUE,
      rescue_max_consecutive = 5L,
      trace = FALSE
    ),
    latent_s = exdqlm::exal_make_mcmc_latent_s_control(
      freeze_burnin_iters = 18L,
      sparse_update_every = 5L,
      sparse_update_until_iter = 45L,
      trace = FALSE
    ),
    rhs = rhs_control,
    precision_beta = exdqlm::exal_make_precision_beta_control("eigen_v1")
  )
  expect_equal(mcmc_control$n_burn, 600L)
  expect_equal(mcmc_control$n_mcmc, 200L)
  expect_equal(mcmc_control$thin, 2L)
  expect_equal(mcmc_control$sigmagam$freeze_burnin_iters, 30L)
  expect_false(isTRUE(mcmc_control$sigmagam$force_after_warmup))
  expect_equal(mcmc_control$theta$freeze_burnin_iters, 20L)
  expect_equal(mcmc_control$theta$sparse_update_every, 3L)
  expect_false(isTRUE(mcmc_control$theta$force_first_postwarmup_update))
  expect_identical(mcmc_control$latent_state$mode, "u_st_pair")
  expect_equal(mcmc_control$latent_state$freeze_burnin_iters, 22L)
  expect_false(isTRUE(mcmc_control$latent_state$trace))
  expect_equal(mcmc_control$dqlm_sigma$freeze_burnin_iters, 14L)
  expect_false(isTRUE(mcmc_control$dqlm_sigma$trace))
  expect_equal(mcmc_control$latent_v$freeze_burnin_iters, 25L)
  expect_true(isTRUE(mcmc_control$latent_v$rescue_on_invalid))
  expect_equal(mcmc_control$latent_v$rescue_max_consecutive, 5L)
  expect_false(isTRUE(mcmc_control$latent_v$trace))
  expect_equal(mcmc_control$latent_s$freeze_burnin_iters, 18L)
  expect_false(isTRUE(mcmc_control$latent_s$trace))
  expect_equal(mcmc_control$rhs$freeze_tau_burnin_iters, 40L)
  expect_true(isTRUE(mcmc_control$rhs$width_adapt$enabled))
  expect_identical(as.character(mcmc_control$precision_beta$preset), "eigen_v1")
})

test_that("builder helpers preserve existing control lists and fill only missing defaults", {
  vb_control <- exal_make_vb_control(control = list(
    max_iter = 80L,
    sigmagam = list(freeze_warmup_iters = 3L)
  ))
  expect_equal(vb_control$max_iter, 80L)
  expect_equal(vb_control$tol, 1e-4, tolerance = 1e-12)
  expect_equal(vb_control$n_samp_xi, 500L)
  expect_null(vb_control$progress_every)
  expect_equal(vb_control$sigmagam$freeze_warmup_iters, 3L)

  vb_control_override <- exal_make_vb_control(
    control = list(max_iter = 80L),
    max_iter = 60L,
    verbose = TRUE
  )
  expect_equal(vb_control_override$max_iter, 60L)
  expect_true(isTRUE(vb_control_override$verbose))

  mcmc_control <- exal_make_mcmc_control(control = list(
    n_burn = 40L,
    sigmagam = list(freeze_burnin_iters = 4L),
    theta = list(enabled = TRUE, freeze_burnin_iters = 7L)
  ))
  expect_equal(mcmc_control$n_burn, 40L)
  expect_equal(mcmc_control$n_mcmc, 1500L)
  expect_equal(mcmc_control$sigmagam$freeze_burnin_iters, 4L)
  expect_true(isTRUE(mcmc_control$theta$enabled))
  expect_equal(mcmc_control$theta$freeze_burnin_iters, 7L)

  mcmc_control_override <- exal_make_mcmc_control(
    control = list(n_burn = 40L, init_from_vb = FALSE),
    n_burn = 25L,
    init_from_vb = TRUE
  )
  expect_equal(mcmc_control_override$n_burn, 25L)
  expect_true(isTRUE(mcmc_control_override$init_from_vb))
})

test_that("static entrypoints accept normalized control builders", {
  set.seed(1801)
  dat <- tiny_static_xy_builder()

  vb_fit <- exalStaticLDVB(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    vb_control = exal_make_vb_control(
      max_iter = 25L,
      tol = 5e-3,
      n_samp_xi = 30L,
      sigmagam = exal_make_vb_sigmagam_control(freeze_warmup_iters = 2L)
    ),
    verbose = FALSE
  )
  expect_equal(vb_fit$misc$sigmagam$freeze_warmup_iters, 2L)

  mcmc_fit <- exalStaticMCMC(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    mcmc_control = exal_make_mcmc_control(
      n_burn = 8L,
      n_mcmc = 10L,
      init_from_vb = TRUE,
      sigmagam = exal_make_mcmc_sigmagam_control(freeze_burnin_iters = 3L)
    ),
    thin = 1L,
    verbose = FALSE
  )
  expect_equal(mcmc_fit$diagnostics$sigmagam$freeze_burnin_iters, 3L)
})

test_that("entrypoints apply the default warmup profile and allow explicit opt-out", {
  set.seed(1803)
  dat <- tiny_static_xy_builder()

  vb_fit_default <- exalStaticLDVB(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    max_iter = 40L,
    n_samp_xi = 30L,
    verbose = FALSE
  )
  expect_equal(vb_fit_default$misc$sigmagam$freeze_warmup_iters, 10L)
  expect_equal(vb_fit_default$misc$sigmagam$postwarmup_damping, 0.6, tolerance = 1e-12)

  vb_fit_none <- exalStaticLDVB(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    max_iter = 40L,
    vb_control = exal_make_vb_control(
      n_samp_xi = 30L,
      sigmagam = exal_make_vb_sigmagam_control(
        freeze_warmup_iters = 0L,
        postwarmup_damping = 1.0,
        postwarmup_damping_iters = 0L,
        min_postwarmup_updates = 0L
      )
    ),
    verbose = FALSE
  )
  expect_equal(vb_fit_none$misc$sigmagam$freeze_warmup_iters, 0L)

  mcmc_fit_default <- exalStaticMCMC(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    n.burn = 30L,
    n.mcmc = 12L,
    thin = 1L,
    verbose = FALSE
  )
  expect_equal(mcmc_fit_default$diagnostics$sigmagam$freeze_burnin_iters, 25L)

  mcmc_fit_none <- exalStaticMCMC(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    n.burn = 30L,
    n.mcmc = 12L,
    thin = 1L,
    mcmc_control = exal_make_mcmc_control(
      sigmagam = exal_make_mcmc_sigmagam_control(freeze_burnin_iters = 0L)
    ),
    verbose = FALSE
  )
  expect_equal(mcmc_fit_none$diagnostics$sigmagam$freeze_burnin_iters, 0L)
})

test_that("default sigmagam warmup clamps to the available iteration budget", {
  set.seed(1804)
  dat <- tiny_static_xy_builder()

  vb_fit <- exalStaticLDVB(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    max_iter = 12L,
    n_samp_xi = 30L,
    verbose = FALSE
  )
  expect_equal(vb_fit$misc$sigmagam$freeze_warmup_iters, 2L)

  mcmc_fit <- exalStaticMCMC(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    n.burn = 6L,
    n.mcmc = 8L,
    thin = 1L,
    verbose = FALSE
  )
  expect_equal(mcmc_fit$diagnostics$sigmagam$freeze_burnin_iters, 1L)
})

test_that("dynamic entrypoints accept normalized control builders", {
  set.seed(1802)
  TT <- 18L
  y <- cumsum(stats::rnorm(TT, sd = 0.15))
  model <- tiny_dyn_model_builder(TT)

  old_opts <- options(
    exdqlm.use_cpp_kf = FALSE,
    exdqlm.use_cpp_mcmc = FALSE,
    exdqlm.compute_elbo = TRUE,
    exdqlm.max_iter = 25L,
    exdqlm.vb.min_iter = 5L,
    exdqlm.vb.patience = 2L
  )
  on.exit(options(old_opts), add = TRUE)

  vb_fit <- exdqlmLDVB(
    y = y, p0 = 0.5, model = model, df = 1, dim.df = 1,
    fix.sigma = FALSE,
    vb_control = exal_make_vb_control(
      tol = 0.1,
      sigmagam = exal_make_vb_sigmagam_control(freeze_warmup_iters = 2L),
      sts = exal_make_vb_sts_control(freeze_warmup_iters = 2L)
    ),
    n.samp = 10,
    verbose = FALSE
  )
  expect_equal(vb_fit$misc$sigmagam$freeze_warmup_iters, 2L)
  expect_equal(vb_fit$misc$sts$freeze_warmup_iters, 2L)

  mcmc_fit <- exdqlmMCMC(
    y = y, p0 = 0.5, model = model, df = 1, dim.df = 1,
    fix.sigma = FALSE,
    mcmc_control = exal_make_mcmc_control(
      n_burn = 10L,
      n_mcmc = 10L,
      init_from_vb = TRUE,
      vb_warm_start_control = list(method = "ldvb", tol = 0.2, n.samp = 20L, max_iter = 10L, verbose = FALSE),
      sigmagam = exal_make_mcmc_sigmagam_control(freeze_burnin_iters = 2L),
      theta = exal_make_mcmc_theta_control(enabled = TRUE, freeze_burnin_iters = 2L),
      latent_state = exal_make_mcmc_latent_state_control(
        mode = "u_st_pair",
        freeze_burnin_iters = 2L
      )
    ),
    verbose = FALSE
  )
  expect_equal(mcmc_fit$diagnostics$latent_state$freeze_burnin_iters, 2L)
  expect_identical(mcmc_fit$diagnostics$latent_state$mode, "u_st_pair")
})

test_that("dynamic entrypoints use the default sigmagam warmup profile", {
  set.seed(1805)
  TT <- 18L
  y <- cumsum(stats::rnorm(TT, sd = 0.15))
  model <- tiny_dyn_model_builder(TT)

  old_opts <- options(
    exdqlm.use_cpp_kf = FALSE,
    exdqlm.use_cpp_mcmc = FALSE,
    exdqlm.compute_elbo = TRUE,
    exdqlm.max_iter = 30L,
    exdqlm.vb.min_iter = 5L,
    exdqlm.vb.patience = 2L
  )
  on.exit(options(old_opts), add = TRUE)

  vb_fit <- exdqlmLDVB(
    y = y, p0 = 0.5, model = model, df = 1, dim.df = 1,
    fix.sigma = FALSE,
    n.samp = 10,
    verbose = FALSE
  )
  expect_equal(vb_fit$misc$sigmagam$freeze_warmup_iters, 10L)

  mcmc_fit <- exdqlmMCMC(
    y = y, p0 = 0.5, model = model, df = 1, dim.df = 1,
    fix.sigma = FALSE,
    n.burn = 30L,
    n.mcmc = 10L,
    verbose = FALSE
  )
  expect_equal(mcmc_fit$diagnostics$sigmagam$freeze_burnin_iters, 25L)
})

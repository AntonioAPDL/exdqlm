make_sigmagam_summary_obj <- function(fit, status = "SUCCESS") {
  summary_row <- data.frame(
    status = status,
    wall_seconds = NA_real_,
    total_stage_seconds = NA_real_,
    forecast_CRPS_mean = NA_real_,
    forecast_PinballMean_mean = NA_real_,
    forecast_S_mean = NA_real_,
    rhs_diag_available = NA,
    rhs_collapse_flag_any = FALSE,
    rhs_collapse_flag_bound_any = FALSE,
    rhs_collapse_flag_shrink_any = FALSE,
    rhs_unhealthy_any = FALSE,
    rhs_unhealthy_reason = NA_character_,
    rhs_root_cause_context = NA_character_,
    rhs_tau_last = NA_real_,
    rhs_E_invV_med_last = NA_real_,
    rhs_beta_l2_last = NA_real_,
    rhs_beta_small_frac_1e4_last = NA_real_,
    stringsAsFactors = FALSE
  )

  list(
    summary = summary_row,
    forecast_objects = list(
      fits_fc = list(
        list(
          fit_train = list(fit = fit)
        )
      )
    )
  )
}

make_sigmagam_root_spec <- function(method) {
  list(
    root_id = paste0("sigmagam-", method),
    scenario = "toy_sine_small",
    tau = 0.5,
    likelihood_family = "exal",
    beta_prior_type = "ridge",
    seed = 123L,
    reservoir_profile = "tiny_d1_n8"
  )
}

test_that("VB validation export carries sigmagam warmup trace columns and health fields", {
  withr::local_seed(20260419)

  n <- 24L
  X <- cbind(1, stats::rnorm(n), stats::rnorm(n))
  y <- as.numeric(X %*% c(0.2, -0.25, 0.1) + stats::rnorm(n, sd = 0.25))

  fit <- exdqlm::exal_fit(
    y = y,
    X = X,
    p0 = 0.5,
    gamma_bounds = c(exdqlm::get_gamma_bounds(0.5)),
    method = "vb",
    vb_control = list(
      max_iter = 14L,
      min_iter_elbo = 5L,
      tol = 1e-4,
      tol_par = 1e-4,
      n_samp_xi = 30L,
      verbose = FALSE,
      sigmagam = list(
        freeze_warmup_iters = 2L,
        force_after_warmup = TRUE,
        min_postwarmup_updates = 1L
      )
    )
  )

  summary_obj <- make_sigmagam_summary_obj(fit)
  progress <- exdqlm:::.qdesn_validation_method_progress_trace("vb", summary_obj)
  sigmagam_trace <- exdqlm:::.qdesn_validation_method_sigmagam_trace("vb", summary_obj)
  health <- exdqlm:::.qdesn_validation_method_health("vb", make_sigmagam_root_spec("vb"), summary_obj)

  expect_true(all(c(
    "sigmagam_frozen",
    "sigmagam_update_reason",
    "sigmagam_update_count",
    "sigmagam_forced_postwarmup"
  ) %in% names(progress)))
  expect_true(all(progress$sigmagam_frozen[1:2]))
  expect_false(isTRUE(progress$sigmagam_frozen[3L]))
  expect_identical(progress$sigmagam_update_reason[[3L]], "force_after_warmup")
  expect_true(isTRUE(progress$sigmagam_forced_postwarmup[[3L]]))
  expect_true(all(diff(progress$sigmagam_update_count) >= 0))
  expect_true(all(c(
    "phase",
    "sigmagam_frozen",
    "sigmagam_update_reason",
    "sigmagam_forced_postwarmup"
  ) %in% names(sigmagam_trace)))
  expect_true(all(sigmagam_trace$phase == "vb"))
  expect_true(all(sigmagam_trace$sigmagam_frozen[1:2]))
  expect_identical(sigmagam_trace$sigmagam_update_reason[[3L]], "force_after_warmup")
  expect_true(isTRUE(sigmagam_trace$sigmagam_forced_postwarmup[[3L]]))

  expect_equal(health$vb_sigmagam_warmup_iters, 2L)
  expect_equal(health$vb_sigmagam_required_postwarmup_updates, 1L)
  expect_equal(health$vb_sigmagam_first_active_iter, 3L)
  expect_gte(health$vb_sigmagam_update_count, 1L)
})

test_that("MCMC validation health carries sigmagam warmup summaries", {
  withr::local_seed(20260420)

  n <- 18L
  X <- cbind(1, stats::rnorm(n), stats::rnorm(n))
  y <- as.numeric(X %*% c(0.25, -0.15, 0.12) + stats::rnorm(n, sd = 0.28))

  fit <- exdqlm::exal_fit(
    y = y,
    X = X,
    p0 = 0.5,
    gamma_bounds = c(exdqlm::get_gamma_bounds(0.5)),
    method = "mcmc",
    mcmc_control = list(
      n_burn = 5L,
      n_mcmc = 7L,
      thin = 1L,
      verbose = FALSE,
      init_from_vb = FALSE,
      sigmagam = list(
        freeze_burnin_iters = 3L,
        freeze_only_during_burn = TRUE,
        force_after_warmup = TRUE
      )
    ),
    init = list(
      beta = rep(0, ncol(X)),
      sigma = 1,
      gamma = 0.5,
      v = rep(1, n),
      s = rep(0.1, n)
    )
  )

  summary_obj <- make_sigmagam_summary_obj(fit)
  sigmagam_trace <- exdqlm:::.qdesn_validation_method_sigmagam_trace("mcmc", summary_obj)
  health <- exdqlm:::.qdesn_validation_method_health("mcmc", make_sigmagam_root_spec("mcmc"), summary_obj)

  expect_true(all(c(
    "phase",
    "sigmagam_frozen",
    "sigmagam_update_reason",
    "sigmagam_forced_postwarmup",
    "sigmagam_update_count",
    "gamma_slice_steps_out",
    "gamma_slice_shrink"
  ) %in% names(sigmagam_trace)))
  expect_true(all(sigmagam_trace$phase[1:5] == "burn"))
  expect_true(all(sigmagam_trace$phase[6:nrow(sigmagam_trace)] == "keep"))
  expect_true(all(sigmagam_trace$sigmagam_frozen[1:3]))
  expect_false(isTRUE(sigmagam_trace$sigmagam_frozen[4L]))
  expect_identical(sigmagam_trace$sigmagam_update_reason[[4L]], "force_after_warmup")
  expect_true(isTRUE(sigmagam_trace$sigmagam_forced_postwarmup[[4L]]))
  expect_true(all(diff(sigmagam_trace$sigmagam_update_count) >= 0))
  expect_true(all(is.na(sigmagam_trace$gamma_slice_steps_out[1:3])))
  expect_true(all(is.na(sigmagam_trace$gamma_slice_shrink[1:3])))

  expect_equal(health$mcmc_sigmagam_warmup_iters, 3L)
  expect_equal(health$mcmc_sigmagam_first_active_iter, 4L)
  expect_equal(health$mcmc_sigmagam_updates_burn, 2L)
  expect_equal(health$mcmc_sigmagam_updates_keep, 7L)
  expect_equal(health$mcmc_sigmagam_frozen_burn_rate, 3 / 5, tolerance = 1e-12)
})

test_that("MCMC validation export carries latent-s warmup summaries and trace columns", {
  withr::local_seed(20260420)

  n <- 18L
  X <- cbind(1, stats::rnorm(n), stats::rnorm(n))
  y <- as.numeric(X %*% c(0.20, -0.12, 0.09) + stats::rnorm(n, sd = 0.22))

  fit <- exdqlm::exal_fit(
    y = y,
    X = X,
    p0 = 0.5,
    gamma_bounds = c(exdqlm::get_gamma_bounds(0.5)),
    method = "mcmc",
    mcmc_control = list(
      n_burn = 5L,
      n_mcmc = 7L,
      thin = 1L,
      verbose = FALSE,
      init_from_vb = FALSE,
      latent_s = list(
        enabled = TRUE,
        freeze_burnin_iters = 3L,
        freeze_only_during_burn = TRUE,
        sparse_update_every = 2L,
        sparse_update_until_iter = 5L,
        force_first_postwarmup_update = TRUE,
        trace = TRUE
      )
    ),
    init = list(
      beta = rep(0, ncol(X)),
      sigma = 1,
      gamma = 0.5,
      v = rep(1, n),
      s = rep(0.1, n)
    )
  )

  summary_obj <- make_sigmagam_summary_obj(fit)
  latent_trace <- exdqlm:::.qdesn_validation_method_latent_v_trace("mcmc", summary_obj)
  health <- exdqlm:::.qdesn_validation_method_health("mcmc", make_sigmagam_root_spec("mcmc"), summary_obj)

  expect_true(all(c(
    "phase",
    "latent_s_warmup_active",
    "latent_s_hard_freeze",
    "latent_s_sparse_window",
    "latent_s_force_update",
    "latent_s_update_performed",
    "latent_s_update_reason",
    "latent_s_update_count"
  ) %in% names(latent_trace)))
  expect_true(all(latent_trace$phase[1:5] == "burn"))
  expect_true(all(latent_trace$phase[6:nrow(latent_trace)] == "keep"))
  expect_true(all(latent_trace$latent_s_hard_freeze[1:3]))
  expect_false(isTRUE(latent_trace$latent_s_hard_freeze[4L]))
  expect_identical(latent_trace$latent_s_update_reason[[4L]], "force_after_warmup")
  expect_identical(latent_trace$latent_s_update_reason[[5L]], "sparse_hold")
  expect_true(isTRUE(latent_trace$latent_s_force_update[[4L]]))
  expect_false(isTRUE(latent_trace$latent_s_update_performed[[5L]]))
  expect_true(all(diff(latent_trace$latent_s_update_count) >= 0))

  expect_equal(health$mcmc_latent_s_warmup_iters, 3L)
  expect_equal(health$mcmc_latent_s_sparse_update_every, 2L)
  expect_equal(health$mcmc_latent_s_sparse_update_until_iter, 5L)
  expect_equal(health$mcmc_latent_s_first_postwarmup_update_iter, 4L)
  expect_equal(health$mcmc_latent_s_updates_burn, 1L)
  expect_equal(health$mcmc_latent_s_updates_keep, 7L)
  expect_equal(health$mcmc_latent_s_frozen_burn_rate, 3 / 5, tolerance = 1e-12)
  expect_equal(health$mcmc_latent_s_sparse_hold_burn_rate, 1 / 5, tolerance = 1e-12)
})

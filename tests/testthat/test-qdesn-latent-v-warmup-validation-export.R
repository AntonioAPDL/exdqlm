make_latent_v_summary_obj <- function(fit, status = "SUCCESS") {
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

make_latent_v_root_spec <- function() {
  list(
    root_id = "latent-v-mcmc",
    scenario = "toy_sine_small",
    tau = 0.5,
    likelihood_family = "exal",
    beta_prior_type = "ridge",
    seed = 321L,
    reservoir_profile = "tiny_d1_n8"
  )
}

test_that("MCMC validation export carries latent-v warmup traces and health summaries", {
  withr::local_seed(20260420)

  n <- 18L
  X <- cbind(1, stats::rnorm(n), stats::rnorm(n))
  y <- as.numeric(X %*% c(0.2, -0.1, 0.12) + stats::rnorm(n, sd = 0.25))

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
      latent_v = list(
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

  summary_obj <- make_latent_v_summary_obj(fit)
  latent_v_trace <- exdqlm:::.qdesn_validation_method_latent_v_trace("mcmc", summary_obj)
  health <- exdqlm:::.qdesn_validation_method_health("mcmc", make_latent_v_root_spec(), summary_obj)

  expect_true(all(c(
    "phase",
    "latent_v_warmup_active",
    "latent_v_hard_freeze",
    "latent_v_sparse_window",
    "latent_v_force_update",
    "latent_v_update_performed",
    "latent_v_update_reason",
    "latent_v_update_count"
  ) %in% names(latent_v_trace)))
  expect_true(all(latent_v_trace$phase[1:5] == "burn"))
  expect_true(all(latent_v_trace$phase[6:nrow(latent_v_trace)] == "keep"))
  expect_true(all(latent_v_trace$latent_v_hard_freeze[1:3]))
  expect_false(isTRUE(latent_v_trace$latent_v_hard_freeze[4L]))
  expect_identical(latent_v_trace$latent_v_update_reason[[4L]], "force_after_warmup")
  expect_identical(latent_v_trace$latent_v_update_reason[[5L]], "sparse_hold")
  expect_true(isTRUE(latent_v_trace$latent_v_force_update[[4L]]))
  expect_false(isTRUE(latent_v_trace$latent_v_update_performed[[5L]]))
  expect_true(all(diff(latent_v_trace$latent_v_update_count) >= 0))

  expect_equal(health$mcmc_latent_v_warmup_iters, 3L)
  expect_equal(health$mcmc_latent_v_sparse_update_every, 2L)
  expect_equal(health$mcmc_latent_v_sparse_update_until_iter, 5L)
  expect_equal(health$mcmc_latent_v_first_postwarmup_update_iter, 4L)
  expect_equal(health$mcmc_latent_v_updates_burn, 1L)
  expect_equal(health$mcmc_latent_v_updates_keep, 7L)
  expect_equal(health$mcmc_latent_v_frozen_burn_rate, 3 / 5, tolerance = 1e-12)
  expect_equal(health$mcmc_latent_v_sparse_hold_burn_rate, 1 / 5, tolerance = 1e-12)
})

test_that("failure health rows persist latent-v failure summaries without a fit object", {
  payload <- list(
    latent_v_failure = list(
      failure_family = "latent_v_invalid_draws",
      iteration = 17L,
      phase = "keep",
      sigma = 0.21,
      gamma = 1.4,
      tau = 0.05,
      c2 = 0.7,
      beta_norm = 2.3,
      latent_v_warmup_active = FALSE,
      latent_v_update_reason = "scheduled",
      chi_v = list(min = 0.1, max = 4.2, mean = 1.7, n_nonfinite = 0L),
      psi_v = list(min = 0.2, max = 6.8, mean = 2.6, n_nonfinite = 1L)
    )
  )

  health <- exdqlm:::.qdesn_validation_failure_health_row(
    method = "mcmc",
    root_spec = make_latent_v_root_spec(),
    status = "FAIL",
    error_payload = payload
  )

  expect_identical(as.character(health$status[[1L]]), "FAIL")
  expect_identical(as.character(health$mcmc_failure_family[[1L]]), "latent_v_invalid_draws")
  expect_equal(health$mcmc_failure_iteration, 17L)
  expect_identical(as.character(health$mcmc_failure_phase[[1L]]), "keep")
  expect_equal(health$mcmc_failure_sigma, 0.21, tolerance = 1e-12)
  expect_equal(health$mcmc_failure_gamma, 1.4, tolerance = 1e-12)
  expect_equal(health$mcmc_failure_tau, 0.05, tolerance = 1e-12)
  expect_equal(health$mcmc_failure_c2, 0.7, tolerance = 1e-12)
  expect_equal(health$mcmc_failure_beta_norm, 2.3, tolerance = 1e-12)
  expect_false(isTRUE(health$mcmc_failure_latent_v_warmup_active))
  expect_identical(as.character(health$mcmc_failure_latent_v_update_reason[[1L]]), "scheduled")
  expect_equal(health$mcmc_failure_chi_v_max, 4.2, tolerance = 1e-12)
  expect_equal(health$mcmc_failure_psi_v_nonfinite_n, 1L)
})

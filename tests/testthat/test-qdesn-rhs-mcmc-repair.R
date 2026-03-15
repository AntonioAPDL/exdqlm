test_that("RHS MCMC repair resolver materializes A1 correctly", {
  resolved <- exdqlm:::qdesn_rhs_mcmc_repair_resolve_experiment(
    experiment_id = "A1_current_long",
    matrix_path = file.path("config", "validation", "qdesn_rhs_mcmc_repair_matrix.csv"),
    profiles_path = file.path("config", "validation", "qdesn_rhs_mcmc_repair_profiles.yaml")
  )

  expect_true(isTRUE(resolved$executable))
  expect_equal(basename(resolved$grid_path), "qdesn_rhs_primary_hard_grid.csv")
  expect_equal(resolved$defaults$campaign$name, "A1_current_long")

  rhs_override <- resolved$defaults$pipeline$inference$mcmc$prior_overrides$rhs
  expect_equal(rhs_override$n_burn, 2000L)
  expect_equal(rhs_override$n_mcmc, 4000L)
  expect_equal(rhs_override$slice$width_rhs_tau, 0.15)
  expect_equal(rhs_override$slice$max_shrink, 250L)
  expect_equal(rhs_override$rhs$freeze_tau_burnin_iters, 0L)
  expect_true(isTRUE(rhs_override$rhs$freeze_tau_only_during_burn))
  expect_equal(rhs_override$vb_warm_start_control$max_iter, 60L)
  expect_equal(rhs_override$vb_warm_start_control$rhs$freeze_tau_iters, 10L)
})

test_that("RHS MCMC repair resolver rejects placeholder experiments", {
  resolved <- exdqlm:::qdesn_rhs_mcmc_repair_resolve_experiment(
    experiment_id = "C1_taufreeze_10",
    matrix_path = file.path("config", "validation", "qdesn_rhs_mcmc_repair_matrix.csv"),
    profiles_path = file.path("config", "validation", "qdesn_rhs_mcmc_repair_profiles.yaml")
  )

  expect_false(isTRUE(resolved$executable))
  expect_true("vb_warm_start_profile_placeholder" %in% resolved$blockers)
})

test_that("RHS MCMC repair resolver accepts Stage C override inputs", {
  resolved <- exdqlm:::qdesn_rhs_mcmc_repair_resolve_experiment(
    experiment_id = "C1_taufreeze_10",
    matrix_path = file.path("config", "validation", "qdesn_rhs_mcmc_repair_matrix.csv"),
    profiles_path = file.path("config", "validation", "qdesn_rhs_mcmc_repair_profiles.yaml"),
    vb_warm_start_profile_override = "vb_rhs_stronger_tau20"
  )

  expect_true(isTRUE(resolved$executable))
  expect_equal(resolved$applied_controls$vb_warm_start_profile, "vb_rhs_stronger_tau20")
  expect_equal(
    resolved$defaults$pipeline$inference$mcmc$prior_overrides$rhs$rhs$freeze_tau_burnin_iters,
    10L
  )
  expect_equal(
    resolved$defaults$pipeline$inference$mcmc$prior_overrides$rhs$vb_warm_start_control$rhs$freeze_tau_iters,
    20L
  )
})

test_that("RHS MCMC repair ranking prioritizes eligibility then stability", {
  summary_df <- data.frame(
    experiment_id = c("B1", "B2", "B3"),
    pair_eligible_count = c(2L, 3L, 3L),
    pair_signoff_score_sum = c(2, 2, 3),
    mcmc_signoff_score_sum = c(2, 1, 2),
    mcmc_fail_count = c(1L, 1L, 0L),
    forecast_qhat_mae_delta_mean = c(-0.2, -0.3, -0.1),
    forecast_pinball_tau_delta_mean = c(-0.05, -0.06, -0.02),
    mcmc_fit_runtime_seconds_mean = c(100, 90, 95),
    runtime_ratio_mcmc_vs_vb_mean = c(10, 9, 9.5),
    stringsAsFactors = FALSE
  )

  ranked <- exdqlm:::.qdesn_rhs_mcmc_repair_rank_experiments(summary_df)
  expect_equal(as.character(ranked$experiment_id[[1L]]), "B3")
  expect_equal(ranked$rank, c(1, 2, 3))
})

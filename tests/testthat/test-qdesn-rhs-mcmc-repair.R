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

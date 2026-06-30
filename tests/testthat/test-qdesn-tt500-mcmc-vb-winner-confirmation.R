qdesn_mcmc_vbwin_repo_path <- function(...) {
  root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  file.path(root, ...)
}

test_that("TT500 MCMC VB-winner confirmation config bundle is frozen and narrow", {
  stub <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_winner_confirmation"
  defaults_path <- qdesn_mcmc_vbwin_repo_path("config", "validation", paste0(stub, "_defaults.yaml"))
  grid_path <- qdesn_mcmc_vbwin_repo_path("config", "validation", paste0(stub, "_grid.csv"))
  winners_path <- qdesn_mcmc_vbwin_repo_path("config", "validation", paste0(stub, "_winners.csv"))
  assignments_path <- qdesn_mcmc_vbwin_repo_path("config", "validation", paste0(stub, "_cell_assignments.csv"))

  expect_true(file.exists(defaults_path))
  expect_true(file.exists(grid_path))
  expect_true(file.exists(winners_path))
  expect_true(file.exists(assignments_path))

  defaults <- yaml::read_yaml(defaults_path)
  grid <- utils::read.csv(grid_path, stringsAsFactors = FALSE, check.names = FALSE)
  winners <- utils::read.csv(winners_path, stringsAsFactors = FALSE, check.names = FALSE)
  assignments <- utils::read.csv(assignments_path, stringsAsFactors = FALSE, check.names = FALSE)

  expect_equal(nrow(winners), 9L)
  expect_equal(nrow(grid), 9L)
  expect_equal(nrow(assignments), 9L)
  expect_equal(sort(unique(as.character(grid$source_family))), c("gausmix", "laplace", "normal"))
  expect_equal(sort(unique(as.numeric(grid$tau))), c(0.05, 0.25, 0.5))
  expect_true(all(as.character(grid$beta_prior_type) == "rhs_ns"))
  expect_true(all(as.character(grid$screening_profile_id) %in% as.character(winners$screening_profile_id)))

  expect_identical(as.character(defaults$execution$methods), "mcmc")
  expect_identical(as.character(defaults$execution$likelihood_families), "exal")
  expect_equal(as.integer(defaults$reference_contract$expected_qdesn_roots), 27L)
  expect_equal(as.integer(defaults$reference_contract$expected_selected_qdesn_roots), 9L)
  expect_equal(as.integer(defaults$study_contract$budget$mcmc_n_burn), 5000L)
  expect_equal(as.integer(defaults$study_contract$budget$mcmc_n_mcmc), 20000L)
  expect_equal(as.integer(defaults$pipeline$inference$mcmc$progress_every), 50L)
  expect_true(isTRUE(defaults$pipeline$inference$mcmc$init_from_vb))
  expect_true(isFALSE(defaults$multiseed$enabled))
  expect_equal(as.integer(defaults$multiseed$mcmc_seed_reps), 1L)
  expect_true(isFALSE(defaults$pipeline$outputs$keep_draws))
  expect_true(isFALSE(defaults$pipeline$outputs$save_forecast_objects))
  expect_true(isTRUE(defaults$pipeline$outputs$save_compact_fit_paths))
})

test_that("TT500 MCMC VB-winner confirmation uses the promoted per-cell profile set", {
  stub <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_winner_confirmation"
  winners <- utils::read.csv(
    qdesn_mcmc_vbwin_repo_path("config", "validation", paste0(stub, "_winners.csv")),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  key <- paste(winners$family, sprintf("%.2f", winners$tau), sep = ":")
  profile_by_key <- stats::setNames(as.character(winners$screening_profile_id), key)

  primary <- "tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3"
  expect_equal(profile_by_key[["normal:0.25"]], primary)
  expect_equal(profile_by_key[["normal:0.50"]], primary)
  expect_equal(profile_by_key[["laplace:0.25"]], primary)
  expect_equal(profile_by_key[["gausmix:0.25"]], primary)
  expect_equal(
    profile_by_key[["gausmix:0.05"]],
    "tt500vb_f3_d2_n20_a0p05_r0p6_m15_lag15_rl0_pw0p03_pin0p3"
  )
  expect_equal(
    profile_by_key[["gausmix:0.50"]],
    "tt500vb_f3_d1_n30_a0p03_r0p5_m15_lag15_rl0_pw0p03_pin0p3"
  )
})

test_that("p90 steepertrend defaults encode the promoted dynamic surface", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_defaults.yaml"
  ))

  expect_identical(
    as.character(defaults$source_materialization$scenarios),
    "dlm_constV_p90_m0amp_highnoise_steepertrend_v1"
  )
  expect_identical(as.integer(defaults$study_contract$budget$posterior_metric_draws), 20000L)
  expect_identical(as.integer(defaults$study_contract$budget$vb_sampling_nd_draws), 20000L)
  expect_identical(as.integer(defaults$study_contract$budget$vb_synthesis_n_samp), 20000L)
  expect_identical(as.integer(defaults$study_contract$budget$mcmc_n_burn), 5000L)
  expect_identical(as.integer(defaults$study_contract$budget$mcmc_n_mcmc), 20000L)
  expect_identical(as.integer(defaults$pipeline$inference$vb$max_iter), 300L)
  expect_identical(as.integer(defaults$pipeline$inference$vb$rhs$freeze_tau_iters), 50L)
  expect_identical(as.integer(defaults$pipeline$inference$mcmc$rhs$freeze_tau_burnin_iters), 500L)
  expect_true(isTRUE(defaults$pipeline$inference$mcmc$init_from_vb))
  expect_false(isTRUE(defaults$pipeline$outputs$keep_mcmc_vb_init))
  expect_identical(as.integer(defaults$source_materialization$windows[[1L]]$source_total_size), 813L)
  expect_identical(as.integer(defaults$source_materialization$windows[[2L]]$source_total_size), 5313L)
})

test_that("MCMC VB warm-start artifacts can be pruned without dropping metadata", {
  obj <- list(
    fits_fc = list(
      list(
        fit_train = list(
          fit = list(
            control = list(
              init_from_vb = TRUE,
              vb_warm_start_seed = 1777L,
              vb_warm_start_control = list(max_iter = 20L)
            ),
            diagnostics = list(warm_start = "ldvb"),
            misc = list(
              vb_warm = list(heavy = stats::rnorm(4)),
              nested = list(vb_init_fit = list(heavy = stats::rnorm(3)))
            )
          )
        )
      )
    ),
    cfg = list(outputs = list(keep_mcmc_vb_init = FALSE))
  )

  pruned <- exdqlm:::qdesn_prune_mcmc_vb_init_artifacts(obj)
  fit <- pruned$fits_fc[[1L]]$fit_train$fit

  expect_true(isTRUE(fit$control$init_from_vb))
  expect_equal(fit$control$vb_warm_start_seed, 1777L)
  expect_equal(fit$control$vb_warm_start_control$max_iter, 20L)
  expect_identical(fit$diagnostics$warm_start, "ldvb")
  expect_null(fit$misc$vb_warm)
  expect_null(fit$misc$nested$vb_init_fit)
})

test_that("p90 steepertrend full and subset grids stay coherent", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_defaults.yaml"
  ))
  full_grid <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_full_grid.csv"
  ))

  validation <- exdqlm:::qdesn_dynamic_crossstudy_validate_grid(full_grid, defaults)
  expect_identical(as.integer(validation$enabled_roots), 36L)
  expect_identical(as.integer(validation$unique_dataset_cells), 18L)
  expect_identical(sort(as.character(validation$priors)), c("rhs_ns", "ridge"))
  expect_equal(as.numeric(validation$taus), c(0.05, 0.25, 0.50))

  subset_specs <- list(
    smoke = list(path = "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_smoke_grid.csv", rows = 6L),
    ridge = list(path = "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_ridge_full_grid.csv", rows = 18L),
    rhsns = list(path = "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_rhsns_full_grid.csv", rows = 18L),
    mcmc_ridge_tt500 = list(path = "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_mcmc_ridge_tt500_grid.csv", rows = 9L),
    mcmc_ridge_tt5000 = list(path = "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_mcmc_ridge_tt5000_grid.csv", rows = 9L),
    mcmc_rhsns_tt500 = list(path = "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_mcmc_rhsns_tt500_grid.csv", rows = 9L),
    mcmc_rhsns_tt5000 = list(path = "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_mcmc_rhsns_tt5000_grid.csv", rows = 9L)
  )

  for (spec in subset_specs) {
    subset_grid <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(file.path(
      repo_root,
      "config",
      "validation",
      spec$path
    ))
    exdqlm:::qdesn_dynamic_crossstudy_validate_grid(subset_grid, defaults, allow_subset = TRUE)
    expect_identical(as.integer(nrow(subset_grid)), spec$rows)
    expect_identical(length(unique(subset_grid$root_id)), nrow(subset_grid))
    expect_true(all(as.character(subset_grid$source_scenario) == "dlm_constV_p90_m0amp_highnoise_steepertrend_v1"))
    expect_true(all(as.integer(subset_grid$source_total_size) %in% c(813L, 5313L)))
  }
})

test_that("p90 steepertrend n300m50 relaunch spec encodes the larger DESN", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_defaults.yaml"
  ))
  full_grid <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_full_grid.csv"
  ))

  profile_id <- "deep_d3_n300x3_skip100_w300_m50"
  profile <- defaults$reservoir_profiles[[profile_id]]
  validation <- exdqlm:::qdesn_dynamic_crossstudy_validate_grid(full_grid, defaults)

  expect_identical(defaults$campaign$name, "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation")
  expect_identical(defaults$pilot$reservoir_profile, profile_id)
  expect_identical(unique(as.character(full_grid$reservoir_profile)), profile_id)
  expect_identical(as.integer(validation$enabled_roots), 36L)
  expect_identical(as.integer(validation$unique_dataset_cells), 18L)
  expect_identical(as.integer(nrow(full_grid) * 4L), 144L)

  expect_identical(as.integer(profile$D), 3L)
  expect_identical(as.integer(profile$n), c(300L, 300L, 300L))
  expect_identical(as.integer(profile$n_tilde), c(300L, 300L))
  expect_identical(as.integer(profile$m), 50L)
  expect_equal(as.numeric(profile$alpha), c(0.25, 0.25, 0.25))
  expect_equal(as.numeric(profile$rho), c(0.95, 0.95, 0.95))
  expect_identical(as.character(profile$act_f), c("tanh", "tanh", "tanh"))
  expect_identical(as.character(profile$act_k), c("identity", "identity", "identity"))
  expect_equal(as.numeric(profile$pi_w), c(0.1, 0.1, 0.1))
  expect_equal(as.numeric(profile$pi_in), c(1.0, 1.0, 1.0))
  expect_identical(as.integer(profile$washout), 300L)
  expect_true(isTRUE(profile$add_bias))
  expect_identical(as.integer(profile$seed), 123L)
  expect_true(isTRUE(defaults$pipeline$inference$mcmc$init_from_vb))
  expect_false(isTRUE(defaults$pipeline$outputs$keep_mcmc_vb_init))
  expect_identical(as.integer(defaults$runtime$workers), 16L)
  expect_identical(as.character(defaults$runtime$root_scheduler), "load_balanced")
})

test_that("tau050 failed-mcmc thetafreeze defaults encode the theta-plus-tau crash-only relaunch contract", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_thetafreeze_defaults.yaml"
  ))
  grid <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_exal_grid.csv"
  ))

  sample_row <- subset(
    grid,
    source_family == "normal" &
      abs(tau - 0.05) < 1e-8 &
      fit_size == 500L &
      beta_prior_type == "rhs_ns"
  )[1L, , drop = FALSE]
  root_spec <- exdqlm:::qdesn_dynamic_crossstudy_enrich_root_spec(sample_row, defaults)
  cfg <- exdqlm:::qdesn_static_crossstudy_build_pipeline_cfg(
    root_spec = root_spec,
    defaults = defaults,
    method = "mcmc",
    likelihood_family = "exal",
    x_cols = character(0),
    T_use = root_spec$fit_size
  )

  expect_identical(
    as.character(defaults$campaign$name),
    "qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_thetafreeze_validation"
  )
  expect_identical(as.character(defaults$study_contract$id), "tau050_failed_mcmc_thetafreeze")
  expect_false(isTRUE(defaults$study_contract$core_lane))
  expect_identical(as.integer(cfg$inference$mcmc$vb_warm_start_control$max_iter), 500L)
  expect_identical(as.integer(cfg$inference$mcmc$vb_warm_start_control$min_iter_elbo), 80L)
  expect_identical(as.integer(cfg$inference$mcmc$vb_warm_start_control$sigmagam$freeze_warmup_iters), 20L)
  expect_identical(as.integer(cfg$inference$mcmc$rhs$freeze_tau_burnin_iters), 500L)
  expect_true(isTRUE(cfg$inference$mcmc$theta$enabled))
  expect_identical(as.integer(cfg$inference$mcmc$theta$freeze_burnin_iters), 50L)
  expect_true(isTRUE(cfg$inference$mcmc$theta$freeze_only_during_burn))
  expect_identical(as.integer(cfg$inference$mcmc$theta$sparse_update_every), 10L)
  expect_identical(as.integer(cfg$inference$mcmc$theta$sparse_update_until_iter), 500L)
  expect_true(isTRUE(cfg$inference$mcmc$theta$force_first_postwarmup_update))
  expect_true(isTRUE(cfg$inference$mcmc$theta$trace))
  expect_false(isTRUE(cfg$inference$mcmc$latent_v$enabled))
  expect_false(isTRUE(cfg$inference$mcmc$latent_s$enabled))
  expect_identical(as.integer(cfg$inference$mcmc$sigmagam$freeze_burnin_iters), 0L)
})

test_that("tau050 failed-mcmc thetafreeze defaults accept the audited AL and EXAL crash-only grids", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_thetafreeze_defaults.yaml"
  ))

  subset_specs <- list(
    failed_mcmc_al = list(path = "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_al_grid.csv", rows = 9L),
    failed_mcmc_exal = list(path = "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_exal_grid.csv", rows = 14L)
  )

  for (spec in subset_specs) {
    subset_grid <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(file.path(
      repo_root,
      "config",
      "validation",
      spec$path
    ))
    validation <- exdqlm:::qdesn_dynamic_crossstudy_validate_grid(
      subset_grid,
      defaults,
      allow_subset = TRUE
    )
    expect_identical(as.integer(nrow(subset_grid)), spec$rows)
    expect_identical(length(unique(subset_grid$root_id)), nrow(subset_grid))
    expect_true(validation$enabled_roots >= 1L)
  }
})

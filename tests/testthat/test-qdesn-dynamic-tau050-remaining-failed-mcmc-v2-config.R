test_that("tau050 remaining-failed mcmc v2 defaults encode the latent-v recovery contract", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_defaults.yaml"
  ))
  grid <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v2_grid.csv"
  ))

  sample_row <- subset(
    grid,
    source_family == "gausmix" &
      abs(tau - 0.25) < 1e-8 &
      fit_size == 5000 &
      beta_prior_type == "rhs_ns"
  )[1L, , drop = FALSE]
  root_spec <- exdqlm:::qdesn_dynamic_crossstudy_enrich_root_spec(sample_row, defaults)
  cfg <- exdqlm:::qdesn_static_crossstudy_build_pipeline_cfg(
    root_spec = root_spec,
    defaults = defaults,
    method = "mcmc",
    likelihood_family = "al",
    x_cols = character(0),
    T_use = root_spec$fit_size
  )

  expect_identical(as.character(defaults$campaign$name), "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_validation")
  expect_identical(as.character(defaults$study_contract$id), "tau050_remaining_failed_mcmc_v2")
  expect_false(isTRUE(defaults$study_contract$core_lane))
  expect_identical(as.integer(cfg$inference$mcmc$vb_warm_start_control$max_iter), 500L)
  expect_identical(as.integer(cfg$inference$mcmc$vb_warm_start_control$min_iter_elbo), 80L)
  expect_identical(as.integer(cfg$inference$mcmc$vb_warm_start_control$sigmagam$freeze_warmup_iters), 20L)
  expect_equal(as.numeric(cfg$inference$mcmc$vb_warm_start_control$sigmagam$postwarmup_damping), 0.35, tolerance = 1e-12)
  expect_identical(as.integer(cfg$inference$mcmc$vb_warm_start_control$sigmagam$postwarmup_damping_iters), 10L)
  expect_identical(as.integer(cfg$inference$mcmc$vb_warm_start_control$sigmagam$min_postwarmup_updates), 3L)
  expect_identical(as.integer(cfg$inference$mcmc$rhs$freeze_tau_burnin_iters), 500L)
  expect_identical(as.integer(cfg$inference$mcmc$sigmagam$freeze_burnin_iters), 500L)
  expect_true(isTRUE(cfg$inference$mcmc$latent_v$enabled))
  expect_identical(as.integer(cfg$inference$mcmc$latent_v$freeze_burnin_iters), 50L)
  expect_true(isTRUE(cfg$inference$mcmc$latent_v$freeze_only_during_burn))
  expect_identical(as.integer(cfg$inference$mcmc$latent_v$sparse_update_every), 10L)
  expect_identical(as.integer(cfg$inference$mcmc$latent_v$sparse_update_until_iter), 500L)
  expect_true(isTRUE(cfg$inference$mcmc$latent_v$force_first_postwarmup_update))
  expect_true(isTRUE(cfg$inference$mcmc$latent_v$trace))
})

test_that("tau050 remaining-failed mcmc v2 grids stay inside the remaining-failure surface", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_defaults.yaml"
  ))

  subset_specs <- list(
    al_v2 = list(path = "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v2_grid.csv", rows = 7L),
    exal_v2 = list(path = "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v2_grid.csv", rows = 11L),
    al_canary = list(path = "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v2_canary_grid.csv", rows = 2L),
    exal_canary = list(path = "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v2_canary_grid.csv", rows = 3L),
    al_residual = list(path = "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v2_residual_grid.csv", rows = 5L),
    exal_residual = list(path = "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v2_residual_grid.csv", rows = 8L)
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

test_that("remaining-failed mcmc v2 materializer reproduces the checked-in v2 grids", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  al_v2_out <- tempfile("remaining_failed_al_v2_", fileext = ".csv")
  exal_v2_out <- tempfile("remaining_failed_exal_v2_", fileext = ".csv")
  al_canary_out <- tempfile("remaining_failed_al_v2_canary_", fileext = ".csv")
  exal_canary_out <- tempfile("remaining_failed_exal_v2_canary_", fileext = ".csv")
  al_residual_out <- tempfile("remaining_failed_al_v2_residual_", fileext = ".csv")
  exal_residual_out <- tempfile("remaining_failed_exal_v2_residual_", fileext = ".csv")
  script_path <- file.path(
    repo_root,
    "scripts",
    "materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_grids.R"
  )

  status <- system2(
    "Rscript",
    c(
      script_path,
      "--al-v2-output", al_v2_out,
      "--exal-v2-output", exal_v2_out,
      "--al-canary-output", al_canary_out,
      "--exal-canary-output", exal_canary_out,
      "--al-residual-output", al_residual_out,
      "--exal-residual-output", exal_residual_out
    ),
    stdout = TRUE,
    stderr = TRUE
  )
  exit_status <- attr(status, "status", exact = TRUE)
  if (is.null(exit_status)) exit_status <- 0L
  expect_identical(as.integer(exit_status), 0L)

  checked_al_v2 <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v2_grid.csv"
  ))
  checked_exal_v2 <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v2_grid.csv"
  ))
  checked_al_canary <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v2_canary_grid.csv"
  ))
  checked_exal_canary <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v2_canary_grid.csv"
  ))
  checked_al_residual <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v2_residual_grid.csv"
  ))
  checked_exal_residual <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v2_residual_grid.csv"
  ))

  expect_identical(
    sort(exdqlm:::qdesn_dynamic_crossstudy_load_grid(al_v2_out)$root_id),
    sort(checked_al_v2$root_id)
  )
  expect_identical(
    sort(exdqlm:::qdesn_dynamic_crossstudy_load_grid(exal_v2_out)$root_id),
    sort(checked_exal_v2$root_id)
  )
  expect_identical(
    sort(exdqlm:::qdesn_dynamic_crossstudy_load_grid(al_canary_out)$root_id),
    sort(checked_al_canary$root_id)
  )
  expect_identical(
    sort(exdqlm:::qdesn_dynamic_crossstudy_load_grid(exal_canary_out)$root_id),
    sort(checked_exal_canary$root_id)
  )
  expect_identical(
    sort(exdqlm:::qdesn_dynamic_crossstudy_load_grid(al_residual_out)$root_id),
    sort(checked_al_residual$root_id)
  )
  expect_identical(
    sort(exdqlm:::qdesn_dynamic_crossstudy_load_grid(exal_residual_out)$root_id),
    sort(checked_exal_residual$root_id)
  )
})

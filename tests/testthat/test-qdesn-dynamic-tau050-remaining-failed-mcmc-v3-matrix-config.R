test_that("tau050 remaining-failed mcmc v3 rescue defaults encode the base rescue arm", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_rescue_defaults.yaml"
  ))
  grid <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v3_grid.csv"
  ))

  sample_row <- subset(
    grid,
    source_family == "gausmix" &
      abs(tau - 0.50) < 1e-8 &
      fit_size == 5000 &
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

  expect_identical(as.character(defaults$campaign$name), "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_matrix_validation")
  expect_identical(as.character(defaults$study_contract$id), "tau050_remaining_failed_mcmc_v3_rescue")
  expect_true(isTRUE(cfg$inference$mcmc$latent_v$rescue_on_invalid))
  expect_identical(as.character(cfg$inference$mcmc$latent_v$rescue_strategy), "previous_state")
  expect_identical(as.integer(cfg$inference$mcmc$latent_v$rescue_max_consecutive), 3L)
  expect_false(isTRUE(cfg$inference$mcmc$latent_v$rescue_burn_only))
  expect_true(isTRUE(cfg$inference$mcmc$latent_v$rescue_force_retry_next_iter))
  expect_true(isTRUE(cfg$inference$mcmc$latent_v$record_rescue_trace))
  expect_identical(as.integer(cfg$inference$mcmc$latent_v$freeze_burnin_iters), 50L)
  expect_identical(as.integer(cfg$inference$mcmc$latent_v$sparse_update_every), 10L)
  expect_identical(as.integer(cfg$inference$mcmc$latent_v$sparse_update_until_iter), 500L)
})

test_that("tau050 remaining-failed mcmc v3 matrix arms encode distinct kernel hypotheses", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  exal_grid <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v3_grid.csv"
  ))
  sample_row <- subset(
    exal_grid,
    source_family == "gausmix" &
      abs(tau - 0.50) < 1e-8 &
      fit_size == 5000
  )[1L, , drop = FALSE]

  load_cfg <- function(filename) {
    defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(file.path(
      repo_root,
      "config",
      "validation",
      filename
    ))
    root_spec <- exdqlm:::qdesn_dynamic_crossstudy_enrich_root_spec(sample_row, defaults)
    cfg <- exdqlm:::qdesn_static_crossstudy_build_pipeline_cfg(
      root_spec = root_spec,
      defaults = defaults,
      method = "mcmc",
      likelihood_family = "exal",
      x_cols = character(0),
      T_use = root_spec$fit_size
    )
    list(defaults = defaults, cfg = cfg)
  }

  extended <- load_cfg("qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_rescue_extended_defaults.yaml")
  qr_tight <- load_cfg("qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_exal_qr_tightslice_defaults.yaml")
  altcore <- load_cfg("qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_exal_altcore_defaults.yaml")

  expect_identical(as.character(extended$defaults$study_contract$id), "tau050_remaining_failed_mcmc_v3_rescue_extended")
  expect_identical(as.integer(extended$cfg$inference$mcmc$latent_v$freeze_burnin_iters), 100L)
  expect_identical(as.integer(extended$cfg$inference$mcmc$latent_v$sparse_update_every), 5L)
  expect_identical(as.integer(extended$cfg$inference$mcmc$latent_v$sparse_update_until_iter), 2000L)
  expect_identical(as.integer(extended$cfg$inference$mcmc$latent_v$rescue_max_consecutive), 5L)

  expect_identical(as.character(qr_tight$defaults$study_contract$id), "tau050_remaining_failed_mcmc_v3_exal_qr_tightslice")
  expect_identical(as.character(qr_tight$cfg$inference$mcmc$conditioning$mode), "qr_whiten")
  expect_identical(as.character(qr_tight$cfg$inference$mcmc$slice$core_update_mode), "sigma_then_gamma")
  expect_equal(as.numeric(qr_tight$cfg$inference$mcmc$slice$width_gamma), 0.30, tolerance = 1e-12)
  expect_equal(as.numeric(qr_tight$cfg$inference$mcmc$slice$width_sigma), 0.20, tolerance = 1e-12)

  expect_identical(as.character(altcore$defaults$study_contract$id), "tau050_remaining_failed_mcmc_v3_exal_altcore")
  expect_identical(as.character(altcore$cfg$inference$mcmc$conditioning$mode), "qr_whiten")
  expect_identical(as.character(altcore$cfg$inference$mcmc$slice$core_update_mode), "gamma_sigma_gamma")
  expect_equal(as.numeric(altcore$cfg$inference$mcmc$slice$width_gamma), 0.30, tolerance = 1e-12)
  expect_equal(as.numeric(altcore$cfg$inference$mcmc$slice$width_sigma), 0.20, tolerance = 1e-12)
})

test_that("remaining-failed mcmc v3 materializer reproduces the checked-in v3 grids", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  al_v3_out <- tempfile("remaining_failed_al_v3_", fileext = ".csv")
  exal_v3_out <- tempfile("remaining_failed_exal_v3_", fileext = ".csv")
  al_canary_out <- tempfile("remaining_failed_al_v3_canary_", fileext = ".csv")
  exal_canary_out <- tempfile("remaining_failed_exal_v3_canary_", fileext = ".csv")
  al_residual_out <- tempfile("remaining_failed_al_v3_residual_", fileext = ".csv")
  exal_residual_out <- tempfile("remaining_failed_exal_v3_residual_", fileext = ".csv")
  script_path <- file.path(
    repo_root,
    "scripts",
    "materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_grids.R"
  )

  status <- system2(
    "Rscript",
    c(
      script_path,
      "--al-v3-output", al_v3_out,
      "--exal-v3-output", exal_v3_out,
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

  checked_files <- list(
    al_v3 = "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v3_grid.csv",
    exal_v3 = "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v3_grid.csv",
    al_canary = "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v3_canary_grid.csv",
    exal_canary = "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v3_canary_grid.csv",
    al_residual = "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v3_residual_grid.csv",
    exal_residual = "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v3_residual_grid.csv"
  )
  temp_files <- list(
    al_v3 = al_v3_out,
    exal_v3 = exal_v3_out,
    al_canary = al_canary_out,
    exal_canary = exal_canary_out,
    al_residual = al_residual_out,
    exal_residual = exal_residual_out
  )
  expected_rows <- c(al_v3 = 3L, exal_v3 = 7L, al_canary = 2L, exal_canary = 4L, al_residual = 1L, exal_residual = 3L)

  for (nm in names(checked_files)) {
    checked <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(file.path(
      repo_root,
      "config",
      "validation",
      checked_files[[nm]]
    ))
    generated <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(temp_files[[nm]])
    expect_identical(as.integer(nrow(checked)), expected_rows[[nm]])
    expect_identical(sort(generated$root_id), sort(checked$root_id))
  }
})

`%||%` <- function(a, b) if (is.null(a)) b else a

build_run_specific_cfg <- function(defaults_path, grid_path, method = "mcmc", likelihood_family = "exal") {
  defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(defaults_path)
  grid <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(grid_path)
  root_spec <- exdqlm:::qdesn_dynamic_crossstudy_enrich_root_spec(grid[1L, , drop = FALSE], defaults)
  cfg <- exdqlm:::qdesn_static_crossstudy_build_pipeline_cfg(
    root_spec = root_spec,
    defaults = defaults,
    method = method,
    likelihood_family = likelihood_family,
    x_cols = character(0),
    T_use = root_spec$fit_size
  )
  list(defaults = defaults, grid = grid, cfg = cfg)
}

test_that("run-specific remaining-fail materializer writes cluster-specific grids and defaults", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  script_path <- file.path(
    repo_root,
    "scripts",
    "materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_run_specific_remaining_fail_grids.R"
  )

  latent_v_al_grid_path <- tempfile("latent_v_al_", fileext = ".csv")
  latent_v_exal_grid_path <- tempfile("latent_v_exal_", fileext = ".csv")
  exal_ridge_grid_path <- tempfile("exal_ridge_", fileext = ".csv")
  latent_v_al_defaults_path <- tempfile("latent_v_al_", fileext = ".yaml")
  latent_v_exal_defaults_path <- tempfile("latent_v_exal_", fileext = ".yaml")
  exal_ridge_v1_defaults_path <- tempfile("exal_ridge_v1_", fileext = ".yaml")
  exal_ridge_v2_defaults_path <- tempfile("exal_ridge_v2_", fileext = ".yaml")

  output <- system2(
    "Rscript",
    c(
      script_path,
      "--latent-v-al-output", latent_v_al_grid_path,
      "--latent-v-exal-output", latent_v_exal_grid_path,
      "--exal-ridge-output", exal_ridge_grid_path,
      "--latent-v-al-defaults-output", latent_v_al_defaults_path,
      "--latent-v-exal-defaults-output", latent_v_exal_defaults_path,
      "--exal-ridge-v1-defaults-output", exal_ridge_v1_defaults_path,
      "--exal-ridge-v2-defaults-output", exal_ridge_v2_defaults_path
    ),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(output, "status", exact = TRUE) %||% 0L
  expect_identical(as.integer(status), 0L, info = paste(output, collapse = "\n"))

  latent_v_al_grid <- utils::read.csv(latent_v_al_grid_path, stringsAsFactors = FALSE)
  latent_v_exal_grid <- utils::read.csv(latent_v_exal_grid_path, stringsAsFactors = FALSE)
  exal_ridge_grid <- utils::read.csv(exal_ridge_grid_path, stringsAsFactors = FALSE)

  expect_identical(nrow(latent_v_al_grid), 7L)
  expect_identical(nrow(latent_v_exal_grid), 5L)
  expect_identical(nrow(exal_ridge_grid), 3L)

  expect_true(all(latent_v_al_grid$beta_prior_type %in% c("rhs_ns", "ridge")))
  expect_true(all(latent_v_exal_grid$beta_prior_type %in% c("rhs_ns")))
  expect_true(all(exal_ridge_grid$beta_prior_type %in% c("ridge")))

  latent_v_al <- build_run_specific_cfg(latent_v_al_defaults_path, latent_v_al_grid_path, likelihood_family = "al")
  latent_v_exal <- build_run_specific_cfg(latent_v_exal_defaults_path, latent_v_exal_grid_path, likelihood_family = "exal")
  exal_ridge_v1 <- build_run_specific_cfg(exal_ridge_v1_defaults_path, exal_ridge_grid_path, likelihood_family = "exal")
  exal_ridge_v2 <- build_run_specific_cfg(exal_ridge_v2_defaults_path, exal_ridge_grid_path, likelihood_family = "exal")

  expect_identical(
    as.character(latent_v_al$defaults$campaign$name),
    "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_latent_v_al_validation"
  )
  expect_identical(
    as.character(latent_v_exal$defaults$campaign$name),
    "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_latent_v_exal_validation"
  )
  expect_identical(
    as.character(exal_ridge_v1$defaults$campaign$name),
    "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_exal_ridge_precision_v1_validation"
  )
  expect_identical(
    as.character(exal_ridge_v2$defaults$campaign$name),
    "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_exal_ridge_precision_v2_validation"
  )

  expect_true(isTRUE(latent_v_al$cfg$inference$mcmc$theta$enabled))
  expect_true(isTRUE(latent_v_al$cfg$inference$mcmc$latent_v$rescue_on_invalid))
  expect_identical(as.character(latent_v_al$cfg$inference$mcmc$latent_v$rescue_strategy), "previous_state")
  expect_identical(as.integer(latent_v_al$cfg$inference$mcmc$latent_v$rescue_max_consecutive), 1L)
  expect_false(isTRUE(latent_v_al$cfg$inference$mcmc$latent_v$rescue_burn_only))
  expect_true(
    is.null(latent_v_al$cfg$inference$mcmc$conditioning$mode) ||
      !nzchar(as.character(latent_v_al$cfg$inference$mcmc$conditioning$mode %||% "")) ||
      identical(as.character(latent_v_al$cfg$inference$mcmc$conditioning$mode), "none")
  )

  expect_true(isTRUE(latent_v_exal$cfg$inference$mcmc$theta$enabled))
  expect_true(isTRUE(latent_v_exal$cfg$inference$mcmc$latent_v$rescue_on_invalid))
  expect_true(
    is.null(latent_v_exal$cfg$inference$mcmc$conditioning$mode) ||
      !nzchar(as.character(latent_v_exal$cfg$inference$mcmc$conditioning$mode %||% "")) ||
      identical(as.character(latent_v_exal$cfg$inference$mcmc$conditioning$mode), "none")
  )

  expect_true(isTRUE(exal_ridge_v1$cfg$inference$mcmc$theta$enabled))
  expect_true(isTRUE(exal_ridge_v1$cfg$inference$mcmc$latent_v$rescue_on_invalid))
  expect_identical(as.character(exal_ridge_v1$cfg$inference$mcmc$conditioning$mode), "qr_whiten")
  expect_equal(as.numeric(exal_ridge_v1$cfg$inference$mcmc$conditioning$gram_ridge), 1e-6, tolerance = 1e-12)
  expect_identical(as.character(exal_ridge_v1$cfg$inference$mcmc$slice$core_update_mode), "sigma_then_gamma")

  expect_identical(as.character(exal_ridge_v2$cfg$inference$mcmc$conditioning$mode), "qr_whiten")
  expect_equal(as.numeric(exal_ridge_v2$cfg$inference$mcmc$conditioning$gram_ridge), 1e-4, tolerance = 1e-12)
  expect_identical(as.character(exal_ridge_v2$cfg$inference$mcmc$slice$core_update_mode), "gamma_sigma_gamma")
})

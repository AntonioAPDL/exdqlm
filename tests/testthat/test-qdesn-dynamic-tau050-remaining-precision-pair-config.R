`%||%` <- function(a, b) if (is.null(a)) b else a

build_remaining_precision_cfg <- function(defaults_path, grid_path, likelihood_family) {
  defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(defaults_path)
  grid <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(grid_path)
  root_spec <- exdqlm:::qdesn_dynamic_crossstudy_enrich_root_spec(grid[1L, , drop = FALSE], defaults)
  cfg <- exdqlm:::qdesn_static_crossstudy_build_pipeline_cfg(
    root_spec = root_spec,
    defaults = defaults,
    method = "mcmc",
    likelihood_family = likelihood_family,
    x_cols = character(0),
    T_use = root_spec$fit_size
  )
  list(defaults = defaults, grid = grid, cfg = cfg)
}

test_that("remaining precision-pair materializer writes the exact two-root relaunch package", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  script_path <- file.path(
    repo_root,
    "scripts",
    "materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_grids.R"
  )

  pair_map_path <- tempfile("remaining_precision_pair_map_", fileext = ".csv")
  al_grid_path <- tempfile("remaining_precision_pair_al_", fileext = ".csv")
  exal_grid_path <- tempfile("remaining_precision_pair_exal_", fileext = ".csv")
  al_defaults_path <- tempfile("remaining_precision_pair_al_", fileext = ".yaml")
  exal_defaults_path <- tempfile("remaining_precision_pair_exal_", fileext = ".yaml")

  output <- system2(
    "Rscript",
    c(
      script_path,
      "--pair-map-output", pair_map_path,
      "--al-output", al_grid_path,
      "--exal-output", exal_grid_path,
      "--al-defaults-output", al_defaults_path,
      "--exal-defaults-output", exal_defaults_path
    ),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(output, "status", exact = TRUE) %||% 0L
  expect_identical(as.integer(status), 0L, info = paste(output, collapse = "\n"))

  pair_map <- utils::read.csv(pair_map_path, stringsAsFactors = FALSE)
  al_grid <- utils::read.csv(al_grid_path, stringsAsFactors = FALSE)
  exal_grid <- utils::read.csv(exal_grid_path, stringsAsFactors = FALSE)

  expect_identical(nrow(pair_map), 2L)
  expect_identical(nrow(al_grid), 1L)
  expect_identical(nrow(exal_grid), 1L)
  expect_identical(
    as.character(al_grid$root_id[[1L]]),
    "root__dynamic__dlm_constV_smallW__laplace__tau_0p50__lasttt_5000__qdesn_ridge"
  )
  expect_identical(as.character(exal_grid$root_id[[1L]]), as.character(al_grid$root_id[[1L]]))
  expect_identical(as.character(pair_map$spec_id[[1L]]), "tau_theta_precision_al_v1")
  expect_identical(as.character(pair_map$spec_id[[2L]]), "tau_theta_precision_exal_v2")

  al_cfg <- build_remaining_precision_cfg(al_defaults_path, al_grid_path, likelihood_family = "al")
  exal_cfg <- build_remaining_precision_cfg(exal_defaults_path, exal_grid_path, likelihood_family = "exal")

  expect_identical(
    as.character(al_cfg$defaults$campaign$name),
    "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_al_v1_validation"
  )
  expect_identical(
    as.character(exal_cfg$defaults$campaign$name),
    "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_exal_v2_validation"
  )

  expect_true(isTRUE(al_cfg$cfg$inference$mcmc$theta$enabled))
  expect_true(isTRUE(al_cfg$cfg$inference$mcmc$latent_v$rescue_on_invalid))
  expect_identical(as.character(al_cfg$cfg$inference$mcmc$conditioning$mode), "qr_whiten")
  expect_equal(as.numeric(al_cfg$cfg$inference$mcmc$conditioning$gram_ridge), 1e-6, tolerance = 1e-12)
  expect_identical(as.character(al_cfg$cfg$inference$mcmc$slice$core_update_mode), "sigma_then_gamma")

  expect_true(isTRUE(exal_cfg$cfg$inference$mcmc$theta$enabled))
  expect_true(isTRUE(exal_cfg$cfg$inference$mcmc$latent_v$rescue_on_invalid))
  expect_identical(as.character(exal_cfg$cfg$inference$mcmc$conditioning$mode), "qr_whiten")
  expect_equal(as.numeric(exal_cfg$cfg$inference$mcmc$conditioning$gram_ridge), 1e-4, tolerance = 1e-12)
  expect_identical(as.character(exal_cfg$cfg$inference$mcmc$slice$core_update_mode), "gamma_sigma_gamma")
})

`%||%` <- function(a, b) if (is.null(a)) b else a

build_remaining_precision_matrix_cfg <- function(defaults_path, grid_path, likelihood_family) {
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

test_that("remaining precision matrix materializer writes the broad root-specific experiment suite", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  script_path <- file.path(
    repo_root,
    "scripts",
    "materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_matrix.R"
  )

  map_path <- tempfile("remaining_precision_matrix_map_", fileext = ".csv")

  output <- system2(
    "Rscript",
    c(script_path, "--matrix-map-output", map_path),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(output, "status", exact = TRUE) %||% 0L
  expect_identical(as.integer(status), 0L, info = paste(output, collapse = "\n"))

  matrix_map <- utils::read.csv(map_path, stringsAsFactors = FALSE)
  expect_identical(nrow(matrix_map), 7L)

  expect_identical(sum(matrix_map$lane == "al"), 3L)
  expect_identical(sum(matrix_map$lane == "exal"), 4L)
  expect_true(all(grepl("root__dynamic__dlm_constV_smallW__laplace__tau_0p50__lasttt_5000__qdesn_ridge", matrix_map$root_id)))

  al_qr_v2 <- build_remaining_precision_matrix_cfg(
    file.path(repo_root, "config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_matrix_al_qr_v2_defaults.yaml"),
    file.path(repo_root, "config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_al_grid.csv"),
    likelihood_family = "al"
  )
  exal_qr_v2 <- build_remaining_precision_matrix_cfg(
    file.path(repo_root, "config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_matrix_exal_qr_v2_defaults.yaml"),
    file.path(repo_root, "config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_exal_grid.csv"),
    likelihood_family = "exal"
  )
  exal_diag_v1 <- build_remaining_precision_matrix_cfg(
    file.path(repo_root, "config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_matrix_exal_diag_v1_defaults.yaml"),
    file.path(repo_root, "config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_exal_grid.csv"),
    likelihood_family = "exal"
  )

  expect_identical(as.character(al_qr_v2$cfg$inference$mcmc$conditioning$mode), "qr_whiten")
  expect_equal(as.numeric(al_qr_v2$cfg$inference$mcmc$conditioning$gram_ridge), 1e-2, tolerance = 1e-12)
  expect_true(isTRUE(al_qr_v2$cfg$inference$mcmc$transforms$use_log_sigma))
  expect_equal(as.numeric(al_qr_v2$cfg$inference$mcmc$slice$width_sigma), 0.20, tolerance = 1e-12)
  expect_identical(as.integer(al_qr_v2$cfg$inference$mcmc$slice$core_extra_passes), 2L)

  expect_identical(as.character(exal_qr_v2$cfg$inference$mcmc$conditioning$mode), "qr_whiten")
  expect_equal(as.numeric(exal_qr_v2$cfg$inference$mcmc$conditioning$gram_ridge), 1e-2, tolerance = 1e-12)
  expect_identical(as.character(exal_qr_v2$cfg$inference$mcmc$slice$core_update_mode), "gamma_sigma_gamma")
  expect_true(isTRUE(exal_qr_v2$cfg$inference$mcmc$transforms$use_log_sigma))
  expect_identical(as.integer(exal_qr_v2$cfg$inference$mcmc$slice$core_extra_passes), 2L)

  expect_identical(as.character(exal_diag_v1$cfg$inference$mcmc$conditioning$mode), "diag_scale")
  expect_identical(as.character(exal_diag_v1$cfg$inference$mcmc$conditioning$scale_metric), "rms")
  expect_identical(as.character(exal_diag_v1$cfg$inference$mcmc$slice$core_update_mode), "gamma_sigma_gamma")
  expect_true(isTRUE(exal_diag_v1$cfg$inference$mcmc$transforms$use_log_sigma))
})

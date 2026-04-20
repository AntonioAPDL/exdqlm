`%||%` <- function(a, b) if (is.null(a)) b else a

build_remaining_precision_code_cfg <- function(defaults_path, grid_path, likelihood_family) {
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

test_that("remaining precision code matrix materializer writes the pair-only code-rescue experiment suite", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  script_path <- file.path(
    repo_root,
    "scripts",
    "materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_code_matrix.R"
  )

  map_path <- tempfile("remaining_precision_code_matrix_map_", fileext = ".csv")

  output <- system2(
    "Rscript",
    c(script_path, "--matrix-map-output", map_path),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(output, "status", exact = TRUE) %||% 0L
  expect_identical(as.integer(status), 0L, info = paste(output, collapse = "\n"))

  matrix_map <- utils::read.csv(map_path, stringsAsFactors = FALSE)
  expect_identical(nrow(matrix_map), 6L)
  expect_identical(sum(matrix_map$lane == "al"), 3L)
  expect_identical(sum(matrix_map$lane == "exal"), 3L)
  expect_true(all(grepl("root__dynamic__dlm_constV_smallW__laplace__tau_0p50__lasttt_5000__qdesn_ridge", matrix_map$root_id)))

  al_ladder_v2 <- build_remaining_precision_code_cfg(
    file.path(repo_root, "config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_code_al_ladder_v2_defaults.yaml"),
    file.path(repo_root, "config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_al_grid.csv"),
    likelihood_family = "al"
  )
  exal_eigen_v1 <- build_remaining_precision_code_cfg(
    file.path(repo_root, "config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_code_exal_eigen_v1_defaults.yaml"),
    file.path(repo_root, "config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_exal_grid.csv"),
    likelihood_family = "exal"
  )

  expect_true(isTRUE(al_ladder_v2$cfg$inference$mcmc$precision_beta$enabled))
  expect_true(isTRUE(al_ladder_v2$cfg$inference$mcmc$precision_beta$symmetrize))
  expect_false(isTRUE(al_ladder_v2$cfg$inference$mcmc$precision_beta$eigen_fallback))
  expect_equal(max(as.numeric(al_ladder_v2$cfg$inference$mcmc$precision_beta$jitter_ladder)), 1e-2, tolerance = 1e-12)

  expect_true(isTRUE(exal_eigen_v1$cfg$inference$mcmc$precision_beta$enabled))
  expect_true(isTRUE(exal_eigen_v1$cfg$inference$mcmc$precision_beta$eigen_fallback))
  expect_equal(as.numeric(exal_eigen_v1$cfg$inference$mcmc$precision_beta$eigen_floor_abs), 1e-6, tolerance = 1e-12)
  expect_equal(as.numeric(exal_eigen_v1$cfg$inference$mcmc$precision_beta$eigen_floor_rel), 1e-8, tolerance = 1e-12)
})

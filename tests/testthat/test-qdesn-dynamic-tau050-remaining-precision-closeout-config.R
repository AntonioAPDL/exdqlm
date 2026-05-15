`%||%` <- function(a, b) if (is.null(a)) b else a

build_remaining_precision_closeout_cfg <- function(defaults_path, grid_path, likelihood_family) {
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
  resolved <- exdqlm:::resolve_exal_inference_config(
    cfg,
    p_vec = c(as.numeric(root_spec$tau[[1L]])),
    verbose = FALSE
  )
  list(defaults = defaults, grid = grid, cfg = cfg, resolved = resolved)
}

test_that("remaining precision closeout materializer writes the promoted ladder_v2 closeout package", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  script_path <- file.path(
    repo_root,
    "scripts",
    "materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_closeout.R"
  )

  map_path <- tempfile("remaining_precision_closeout_map_", fileext = ".csv")
  al_grid_path <- tempfile("remaining_precision_closeout_al_", fileext = ".csv")
  exal_grid_path <- tempfile("remaining_precision_closeout_exal_", fileext = ".csv")

  output <- system2(
    "Rscript",
    c(
      script_path,
      "--closeout-map-output", map_path,
      "--al-output-grid", al_grid_path,
      "--exal-output-grid", exal_grid_path
    ),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(output, "status", exact = TRUE) %||% 0L
  expect_identical(as.integer(status), 0L, info = paste(output, collapse = "\n"))

  closeout_map <- utils::read.csv(map_path, stringsAsFactors = FALSE)
  expect_identical(nrow(closeout_map), 4L)
  expect_identical(sum(closeout_map$role == "canonical_live"), 2L)
  expect_identical(sum(closeout_map$role == "fallback_prepared"), 2L)
  expect_identical(sum(closeout_map$precision_beta_preset == "ladder_v2"), 2L)
  expect_identical(sum(closeout_map$precision_beta_preset == "eigen_v1"), 2L)
  expect_true(all(grepl("root__dynamic__dlm_constV_smallW__laplace__tau_0p50__lasttt_5000__qdesn_ridge", closeout_map$root_id)))

  al_ladder_v2 <- build_remaining_precision_closeout_cfg(
    file.path(repo_root, "config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_closeout_al_ladder_v2_defaults.yaml"),
    file.path(repo_root, "config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_closeout_al_grid.csv"),
    likelihood_family = "al"
  )
  exal_eigen_v1 <- build_remaining_precision_closeout_cfg(
    file.path(repo_root, "config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_closeout_exal_eigen_v1_defaults.yaml"),
    file.path(repo_root, "config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_closeout_exal_grid.csv"),
    likelihood_family = "exal"
  )

  expect_identical(nrow(al_ladder_v2$grid), 1L)
  expect_identical(nrow(exal_eigen_v1$grid), 1L)
  expect_true(isTRUE(al_ladder_v2$resolved$mcmc$control_base$precision_beta$enabled))
  expect_identical(as.character(al_ladder_v2$resolved$mcmc$control_base$precision_beta$preset), "ladder_v2")
  expect_false(isTRUE(al_ladder_v2$resolved$mcmc$control_base$precision_beta$eigen_fallback))
  expect_equal(max(as.numeric(al_ladder_v2$resolved$mcmc$control_base$precision_beta$jitter_ladder)), 1e-2, tolerance = 1e-12)

  expect_true(isTRUE(exal_eigen_v1$resolved$mcmc$control_base$precision_beta$enabled))
  expect_identical(as.character(exal_eigen_v1$resolved$mcmc$control_base$precision_beta$preset), "eigen_v1")
  expect_true(isTRUE(exal_eigen_v1$resolved$mcmc$control_base$precision_beta$eigen_fallback))
  expect_equal(as.numeric(exal_eigen_v1$resolved$mcmc$control_base$precision_beta$eigen_floor_abs), 1e-6, tolerance = 1e-12)
  expect_equal(as.numeric(exal_eigen_v1$resolved$mcmc$control_base$precision_beta$eigen_floor_rel), 1e-8, tolerance = 1e-12)
})

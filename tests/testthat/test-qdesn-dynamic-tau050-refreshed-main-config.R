test_that("tau050 refreshed main defaults encode the canonical dynamic-only surface", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml"
  ))
  grid <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_grid.csv"
  ))

  validation <- exdqlm:::qdesn_dynamic_crossstudy_validate_grid(grid, defaults)
  execution_scope <- exdqlm:::.qdesn_static_crossstudy_execution_scope(defaults)
  rescue_cfg <- exdqlm:::.qdesn_static_crossstudy_rescue_overlays_cfg(defaults)

  expect_identical(as.integer(validation$enabled_roots), 36L)
  expect_identical(as.integer(validation$unique_dataset_cells), 18L)
  expect_equal(as.numeric(validation$taus), c(0.05, 0.25, 0.50))
  expect_identical(as.integer(sort(validation$fit_sizes)), c(500L, 5000L))
  expect_identical(sort(as.character(validation$priors)), c("rhs_ns", "ridge"))
  expect_identical(execution_scope$methods, c("vb", "mcmc"))
  expect_identical(execution_scope$likelihood_families, c("exal", "al"))
  expect_identical(as.integer(execution_scope$requested_fits), 4L)
  expect_identical(length(unique(grid$seed)), nrow(grid))
  expect_false(isTRUE(rescue_cfg$enabled))
})

test_that("tau050 refreshed main mcmc config is slice with explicit LDVB warm start", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml"
  ))
  grid <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_grid.csv"
  ))

  sample_row <- subset(
    grid,
    source_family == "laplace" &
      abs(tau - 0.25) < 1e-8 &
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

  expect_true(isTRUE(cfg$inference$mcmc$init_from_vb))
  expect_identical(as.integer(cfg$inference$mcmc$n_burn), 5000L)
  expect_identical(as.integer(cfg$inference$mcmc$n_mcmc), 20000L)
  expect_identical(as.integer(cfg$inference$mcmc$thin), 1L)
  expect_identical(tolower(as.character(cfg$inference$mcmc$vb_warm_start_control$method)[1L]), "ldvb")
  expect_identical(as.integer(cfg$inference$mcmc$vb_warm_start_control$max_iter), 300L)
  expect_identical(as.integer(cfg$inference$mcmc$vb_warm_start_control$n_samp_xi), 1000L)
  expect_false("mh.proposal" %in% names(cfg$inference$mcmc))
  expect_true(is.list(cfg$inference$mcmc$slice))
  expect_identical(as.character(cfg$inference$mcmc$slice$rhs_global_block_update), "transformed_tau_c2_block")
  expect_identical(as.character(cfg$inference$mcmc$slice$core_update_mode), "sigma_then_gamma")
})

test_that("tau050 refreshed main subset grids stay inside the canonical surface", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml"
  ))

  subset_specs <- list(
    smoke = list(path = "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_smoke_grid.csv", rows = 6L),
    ridge = list(path = "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_mcmc_ridge_grid.csv", rows = 18L),
    rhs_tt500 = list(path = "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_mcmc_rhsns_tt500_grid.csv", rows = 9L),
    rhs_tt5000 = list(path = "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_mcmc_rhsns_tt5000_grid.csv", rows = 9L)
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
    expect_true(validation$enabled_roots >= 1L)
  }
})

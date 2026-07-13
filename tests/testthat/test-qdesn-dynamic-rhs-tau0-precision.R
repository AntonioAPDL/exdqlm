test_that("dynamic Q-DESN RHS screening keeps tiny positive tau0 through root-spec plumbing", {
  repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(file.path(
    repo_root,
    "config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_case_targeted_rhs_v51_defaults.yaml"
  ))
  grid <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(file.path(
    repo_root,
    "config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_case_targeted_rhs_v51_grid.csv"
  ))

  tau0_rows <- grepl("tau0p00003_s123", grid$root_id)
  expect_true(any(tau0_rows))
  expect_true(all(as.numeric(grid$rhs_tau0[tau0_rows]) == 3e-5))

  validation <- exdqlm:::qdesn_dynamic_crossstudy_validate_grid(grid[tau0_rows, , drop = FALSE], defaults, allow_subset = TRUE)
  expect_equal(validation$enabled_roots, sum(tau0_rows))

  root_spec <- exdqlm:::qdesn_dynamic_crossstudy_enrich_root_spec(as.list(grid[which(tau0_rows)[1L], , drop = FALSE]), defaults)
  expect_equal(as.numeric(root_spec$rhs_tau0), 3e-5)

  cfg <- exdqlm:::qdesn_static_crossstudy_build_pipeline_cfg(
    root_spec = root_spec,
    defaults = defaults,
    method = "vb",
    likelihood_family = "exal",
    x_cols = character(0),
    T_use = root_spec$source_total_size
  )
  expect_equal(as.numeric(cfg$inference$vb$priors$beta$rhs_ns$tau0), 3e-5)
})

test_that("dynamic Q-DESN RHS screening rejects nonpositive tau0 before compute", {
  repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(file.path(
    repo_root,
    "config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_case_targeted_rhs_v51_defaults.yaml"
  ))
  grid <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(file.path(
    repo_root,
    "config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_case_targeted_rhs_v51_grid.csv"
  ))
  bad <- grid[1L, , drop = FALSE]
  bad$beta_prior_type <- "rhs_ns"
  bad$rhs_tau0 <- 0

  expect_error(
    exdqlm:::qdesn_dynamic_crossstudy_validate_grid(bad, defaults, allow_subset = TRUE),
    "rhs_ns rows must carry finite positive rhs_tau0"
  )
  expect_error(
    exdqlm:::qdesn_dynamic_crossstudy_enrich_root_spec(as.list(bad), defaults),
    "rhs_tau0 must be finite and positive"
  )
})

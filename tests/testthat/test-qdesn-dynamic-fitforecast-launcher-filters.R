test_that("fit+forecast phase plan separates MCMC TT500 and TT5000", {
  tt500 <- exdqlm:::qdesn_dynamic_fitforecast_phase_plan("mcmc_tt500")
  tt5000 <- exdqlm:::qdesn_dynamic_fitforecast_phase_plan("mcmc_tt5000")
  vb <- exdqlm:::qdesn_dynamic_fitforecast_phase_plan("vb_full")

  expect_identical(tt500$methods, "mcmc")
  expect_identical(tt500$fit_sizes, 500L)
  expect_identical(tt500$batch, "full")
  expect_true(isTRUE(tt500$allow_grid_subset_default))

  expect_identical(tt5000$methods, "mcmc")
  expect_identical(tt5000$fit_sizes, 5000L)
  expect_identical(tt5000$batch, "full")

  smoke <- exdqlm:::qdesn_dynamic_fitforecast_phase_plan("smoke")
  expect_identical(smoke$methods, "vb")
  expect_identical(smoke$likelihoods, "exal")
  expect_identical(smoke$fit_sizes, 500L)
  expect_identical(smoke$batch, "smoke")

  pilot <- exdqlm:::qdesn_dynamic_fitforecast_phase_plan("pilot")
  expect_identical(pilot$methods, "vb,mcmc")
  expect_identical(pilot$likelihoods, "exal")
  expect_identical(pilot$fit_sizes, 500L)
  expect_identical(pilot$batch, "smoke")

  expect_identical(vb$methods, "vb")
  expect_length(vb$fit_sizes, 0L)
})

test_that("Q-DESN smoke/pilot MCMC override still honors core-lane VB warm start", {
  repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(file.path(
    repo_root,
    "config", "validation", "qdesn_dynamic_fitforecast_v2_storage_light_defaults.yaml"
  ))

  expect_true(isTRUE(defaults$study_contract$mcmc$require_init_from_vb))
  expect_true(isTRUE(defaults$smoke$pipeline$inference$mcmc$init_from_vb))
  expect_identical(as.integer(defaults$smoke$budget$mcmc_n_burn), 2L)
  expect_identical(as.integer(defaults$smoke$budget$mcmc_n_mcmc), 4L)
  expect_identical(as.integer(defaults$smoke$pipeline$inference$mcmc$n_burn), 2L)
  expect_identical(as.integer(defaults$smoke$pipeline$inference$mcmc$n_mcmc), 4L)
  expect_identical(as.integer(defaults$smoke$pipeline$inference$mcmc$progress_every), 1L)
  expect_true(isTRUE(defaults$smoke$pipeline$inference$mcmc$verbose))
})

test_that("Q-DESN fit+forecast dependency preflight reports missing packages explicitly", {
  expect_identical(
    exdqlm:::qdesn_dynamic_fitforecast_required_packages(),
    unique(exdqlm:::qdesn_dynamic_fitforecast_required_packages())
  )
  expect_error(
    exdqlm:::qdesn_dynamic_fitforecast_assert_required_packages(c("base", "definitely_missing_qdesn_ffv2_pkg")),
    "Missing required Q-DESN fit\\+forecast v2 packages"
  )
})

test_that("Q-DESN fit+forecast pipeline config carries IJ switch explicitly", {
  repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(file.path(
    repo_root,
    "config", "validation", "qdesn_dynamic_fitforecast_v2_storage_light_defaults.yaml"
  ))
  grid <- utils::read.csv(file.path(
    repo_root,
    "config", "validation", "qdesn_dynamic_fitforecast_v2_full_grid.csv"
  ), stringsAsFactors = FALSE)
  root_spec <- exdqlm:::qdesn_dynamic_crossstudy_enrich_root_spec(grid[1L, , drop = FALSE], defaults)
  cfg <- exdqlm:::qdesn_static_crossstudy_build_pipeline_cfg(
    root_spec = root_spec,
    defaults = defaults,
    method = "vb",
    likelihood_family = "exal",
    T_use = root_spec$source_total_size
  )

  expect_true("ij" %in% names(cfg))
  expect_false(isTRUE(cfg$ij$use_ij_correction))
  expect_equal(as.integer(cfg$ij$nd_draws), 0L)
})

test_that("dynamic grid filters are generic and composable", {
  grid <- data.frame(
    root_id = paste0("r", 1:6),
    source_family = c("normal", "normal", "laplace", "laplace", "gausmix", "gausmix"),
    tau = c(0.25, 0.5, 0.25, 0.5, 0.25, 0.5),
    fit_size = c(500, 5000, 500, 5000, 500, 5000),
    beta_prior_type = c("ridge", "ridge", "rhs_ns", "rhs_ns", "ridge", "rhs_ns"),
    stringsAsFactors = FALSE
  )

  out <- exdqlm:::qdesn_validation_filter_dynamic_grid(
    grid,
    fit_sizes = 5000L,
    families = "laplace",
    taus = 0.5,
    priors = "rhs_ns"
  )

  expect_equal(nrow(out), 1L)
  expect_identical(out$root_id, "r4")
  expect_true(all(out$fit_size == 5000L))
  expect_true(all(out$source_family == "laplace"))
  expect_true(all(out$beta_prior_type == "rhs_ns"))
})

test_that("Q-DESN dynamic fit+forecast atomic spec ids target one method-likelihood fit", {
  root <- tempfile("qdesn-atomic-spec-")
  dir.create(root)
  source_fit_input_dir <- file.path(root, "fit-inputs")
  source_report_root <- file.path(root, "reports")
  dir.create(source_fit_input_dir)
  dir.create(source_report_root)
  series_path <- file.path(root, "series_wide.csv")
  selection_path <- file.path(root, "selection_indices.csv")
  sim_path <- file.path(root, "sim_output.rds")
  utils::write.csv(data.frame(source_index = 1:3, y = 1:3, q_target = 1:3), series_path, row.names = FALSE)
  utils::write.csv(data.frame(source_index = 1:3), selection_path, row.names = FALSE)
  saveRDS(list(q = matrix(1:3, ncol = 1)), sim_path)

  grid <- data.frame(
    root_id = "root-a",
    dataset_cell_id = "cell-a",
    source_root_kind = "dynamic",
    source_scenario = "scenario-a",
    scenario = "scenario-a",
    source_family = "normal",
    tau = 0.25,
    fit_size = 500L,
    effective_fit_size = 500L,
    source_total_size = 10000L,
    beta_prior_type = "ridge",
    source_fit_input_dir = source_fit_input_dir,
    source_report_root = source_report_root,
    source_series_wide_path = series_path,
    source_selection_indices_path = selection_path,
    source_sim_path = sim_path,
    source_reference_root_count = 1L,
    seed = 123L,
    reservoir_profile = "tiny",
    enabled = TRUE,
    stringsAsFactors = FALSE
  )
  defaults <- list(
    execution = list(methods = c("vb", "mcmc"), likelihood_families = c("exal", "al")),
    pipeline = list(validation_p_vec = 0.25),
    reference_contract = list(
      root_kind = "dynamic",
      scenarios = "scenario-a",
      families = "normal",
      taus = 0.25,
      fit_sizes = 500L
    ),
    reservoir_profiles = list(tiny = list(seed = 123L))
  )

  spec_grid <- exdqlm:::qdesn_dynamic_fitforecast_atomic_spec_grid(grid, defaults)
  expect_equal(nrow(spec_grid), 4L)
  expect_equal(length(unique(spec_grid$spec_id)), 4L)

  one <- spec_grid[spec_grid$method == "mcmc" & spec_grid$likelihood_family == "exal", , drop = FALSE]
  root_spec <- exdqlm:::qdesn_dynamic_crossstudy_enrich_root_spec(as.list(grid[1L, , drop = FALSE]), defaults)
  expect_identical(
    one$spec_id,
    exdqlm:::qdesn_dynamic_fitforecast_atomic_spec_id(root_spec, "mcmc", "exal")
  )
})

test_that("fit+forecast launch approval gates separate routine and TT5000 approval", {
  smoke <- exdqlm:::qdesn_dynamic_fitforecast_approval_state(
    "smoke",
    launch_env = "true",
    tt5000_env = "false"
  )
  expect_true(isTRUE(smoke$launch_approved))
  expect_false(isTRUE(smoke$requires_tt5000_approval))

  tt5000 <- exdqlm:::qdesn_dynamic_fitforecast_approval_state(
    "mcmc_tt5000",
    launch_env = "true",
    tt5000_env = "false"
  )
  expect_true(isTRUE(tt5000$launch_approved))
  expect_true(isTRUE(tt5000$requires_tt5000_approval))
  expect_false(isTRUE(tt5000$tt5000_approved))

  withr::local_envvar(
    QDESN_FFV2_LAUNCH_APPROVED = "false",
    QDESN_FFV2_TT5000_APPROVED = "false"
  )
  expect_error(
    exdqlm:::qdesn_dynamic_fitforecast_assert_launch_approved("smoke"),
    "Refusing to launch Q-DESN fit\\+forecast v2 compute"
  )

  withr::local_envvar(
    QDESN_FFV2_LAUNCH_APPROVED = "true",
    QDESN_FFV2_TT5000_APPROVED = "false"
  )
  expect_error(
    exdqlm:::qdesn_dynamic_fitforecast_assert_launch_approved("mcmc_tt5000"),
    "Refusing to launch Q-DESN TT5000/full fit\\+forecast v2 compute"
  )
})

test_that("Q-DESN fit+forecast wrapper refuses unapproved real smoke before tmux launch", {
  withr::local_envvar(
    QDESN_FFV2_LAUNCH_APPROVED = "false",
    QDESN_FFV2_TT5000_APPROVED = "false"
  )
  repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  out <- suppressWarnings(system2(
    Sys.which("Rscript"),
    c(file.path(repo_root, "scripts", "launch_qdesn_dynamic_fitforecast_v2_validation.R"), "--phase", "smoke"),
    stdout = TRUE,
    stderr = TRUE
  ))
  status <- attr(out, "status")
  if (is.null(status)) status <- 0L
  expect_false(identical(as.integer(status), 0L))
  expect_true(any(grepl("Refusing to launch Q-DESN", out)))
})

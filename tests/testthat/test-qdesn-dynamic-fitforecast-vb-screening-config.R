test_that("TT500 VB screening profiles are frozen, compact, and gated", {
  repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(file.path(
    repo_root,
    "config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_screen_defaults.yaml"
  ))
  profiles <- exdqlm:::qdesn_dynamic_fitforecast_load_screening_profiles(defaults)

  expect_true(exdqlm:::qdesn_dynamic_fitforecast_screening_enabled(defaults))
  expect_equal(nrow(profiles), 63L)
  expect_equal(length(unique(profiles$screening_profile_id)), 63L)
  expect_true(all(profiles$profile_role == "primary"))
  expect_true(all(profiles$p_over_n_tt500 <= 0.5))
  expect_identical(sort(unique(profiles$D)), c(1L, 2L, 3L))
  expect_identical(sort(unique(profiles$n_each)), c(30L, 50L, 70L))
  expect_identical(sort(unique(profiles$reservoir_lags)), 0L)
  expect_identical(sort(unique(profiles$readout_y_lags)), 12L)
  expect_identical(sort(unique(profiles$washout)), 300L)
  expect_equal(sort(unique(profiles$rhs_tau0)), c(1e-5, 1e-4, 1e-3))
  expect_identical(exdqlm:::qdesn_dynamic_fitforecast_grid_prior_types(defaults), "rhs_ns")
})

test_that("TT500 VB screening grid expands profiles with unique root ids", {
  repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(file.path(
    repo_root,
    "config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_screen_defaults.yaml"
  ))

  tmp <- tempdir()
  input_dir <- file.path(tmp, "input")
  report_root <- file.path(tmp, "report")
  dir.create(input_dir, showWarnings = FALSE)
  dir.create(report_root, showWarnings = FALSE)
  series_path <- file.path(tmp, "series_wide.csv")
  selection_path <- file.path(tmp, "selection_indices.csv")
  sim_path <- file.path(tmp, "sim_output.rds")
  utils::write.csv(data.frame(source_index = 1:3, y = 1:3, q_target = 1:3), series_path, row.names = FALSE)
  utils::write.csv(data.frame(source_index = 1:3), selection_path, row.names = FALSE)
  saveRDS(list(q = matrix(1:3, ncol = 1)), sim_path)
  materialized <- data.frame(
    source_scenario = "dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast",
    source_family = "normal",
    tau = 0.5,
    fit_size = 500L,
    effective_fit_size = 500L,
    source_total_size = 1812L,
    source_window_label = "effTT500_totalTT1812_trainEnd9000_H1000",
    raw_start_source_index = 8189L,
    raw_end_source_index = 10000L,
    train_start_source_index = 8501L,
    train_end_source_index = 9000L,
    forecast_start_source_index = 9001L,
    forecast_end_source_index = 10000L,
    source_fit_input_dir = input_dir,
    source_report_root = report_root,
    source_series_wide_path = series_path,
    source_series_wide_sha256 = "series-hash",
    source_selection_indices_path = selection_path,
    source_selection_indices_sha256 = "selection-hash",
    source_sim_path = sim_path,
    source_sim_sha256 = "sim-hash",
    stringsAsFactors = FALSE
  )

  grid <- exdqlm:::qdesn_dynamic_crossstudy_build_grid_from_materialized_sources(defaults, materialized)
  expect_equal(nrow(grid), 63L)
  expect_equal(length(unique(grid$root_id)), 63L)
  expect_true(all(grid$beta_prior_type == "rhs_ns"))
  expect_true(all(nzchar(grid$screening_profile_id)))
  expect_true(all(grepl("__profile_tt500vb_", grid$root_id)))
  expect_equal(sort(unique(grid$rhs_tau0)), c(1e-5, 1e-4, 1e-3))

  spec_grid <- exdqlm:::qdesn_dynamic_fitforecast_atomic_spec_grid(grid, defaults)
  expect_equal(nrow(spec_grid), 63L)
  expect_true(all(spec_grid$method == "vb"))
  expect_true(all(spec_grid$likelihood_family == "exal"))
  expect_true(all(!is.na(spec_grid$rhs_tau0)))
})

test_that("TT500 VB screening profile overrides reach the fit config", {
  repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(file.path(
    repo_root,
    "config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_screen_defaults.yaml"
  ))
  profiles <- exdqlm:::qdesn_dynamic_fitforecast_load_screening_profiles(defaults)
  profile <- profiles[profiles$screening_profile_id == "tt500vb_d2_n50_a0p30_r0p85_tau0_1em4", , drop = FALSE]
  reservoir_cfg <- exdqlm:::qdesn_dynamic_fitforecast_screening_reservoir_cfg(defaults, profile$screening_profile_id)

  expect_identical(reservoir_cfg$D, 2L)
  expect_identical(reservoir_cfg$n, c(50L, 50L))
  expect_identical(reservoir_cfg$n_tilde, 50L)
  expect_equal(reservoir_cfg$alpha, c(0.3, 0.3))
  expect_equal(reservoir_cfg$rho, c(0.85, 0.85))

  root_spec <- list(
    root_id = "screen-root",
    beta_prior_type = "rhs_ns",
    reservoir_profile = profile$screening_profile_id,
    rhs_tau0 = profile$rhs_tau0,
    readout_y_lags = profile$readout_y_lags,
    reservoir_lags = profile$reservoir_lags,
    tau = 0.5,
    fit_size = 500L,
    seed = 123L
  )
  cfg <- exdqlm:::qdesn_static_crossstudy_build_pipeline_cfg(
    root_spec = root_spec,
    defaults = defaults,
    method = "vb",
    likelihood_family = "exal",
    T_use = 1812L
  )

  expect_identical(cfg$desn$D, 2L)
  expect_identical(cfg$desn$n, c(50L, 50L))
  expect_identical(cfg$lags$m_y, 12L)
  expect_identical(cfg$readout$reservoir_lags, 0L)
  expect_equal(cfg$inference$vb$priors$beta$rhs_ns$tau0, 1e-4)
  expect_identical(as.integer(cfg$inference$vb$max_iter), 150L)
  expect_identical(as.integer(cfg$inference$vb$progress_every), 50L)
})

test_that("real pipeline preserves DESN n_tilde length D-minus-1 for screening profiles", {
  repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  real_main <- readLines(file.path(repo_root, "scripts", "pipeline_real_main.R"), warn = FALSE)
  real_text <- paste(real_main, collapse = "\n")

  expect_true(grepl("rep\\(as\\.integer\\(nt\\), D_in - 1L\\)", real_text))
  expect_false(grepl("rep\\(as\\.integer\\(nt\\), D_in\\)", real_text, fixed = FALSE))
  expect_true(grepl("expected 0, 1, or D-1", real_text, fixed = TRUE))
})

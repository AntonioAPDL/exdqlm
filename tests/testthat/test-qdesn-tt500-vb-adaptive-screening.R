test_that("adaptive Q-DESN screening profiles are compact and deterministic", {
  confirmation <- exdqlm:::qdesn_dynamic_fitforecast_confirmation_profiles()
  broad <- exdqlm:::qdesn_dynamic_fitforecast_broad_profiles()

  expect_equal(nrow(confirmation), 10L)
  expect_equal(nrow(broad), 55L)
  expect_equal(length(unique(confirmation$screening_profile_id)), 10L)
  expect_equal(length(unique(broad$screening_profile_id)), 55L)
  expect_true(all(confirmation$p_over_n_tt500 <= 0.50))
  expect_true(all(broad$p_over_n_tt500 <= 0.50))
  expect_true(all(confirmation$n_each <= 70L))
  expect_true(all(broad$n_each <= 70L))
  expect_equal(sort(unique(confirmation$rhs_tau0)), 1e-4)
  expect_equal(sort(unique(broad$rhs_tau0)), 1e-4)
  expect_false(any(grepl("_tau0_", confirmation$screening_profile_id)))
  expect_false(any(grepl("_tau0_", broad$screening_profile_id)))
})

test_that("adaptive checked-in configs have expected root counts", {
  repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  confirm_defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(file.path(
    repo_root,
    "config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_confirm_defaults.yaml"
  ))
  broad_defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(file.path(
    repo_root,
    "config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_broad_defaults.yaml"
  ))
  confirm_grid <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(file.path(
    repo_root,
    "config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_confirm_grid.csv"
  ))
  broad_grid <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(file.path(
    repo_root,
    "config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_broad_grid.csv"
  ))

  expect_equal(nrow(confirm_grid), 90L)
  expect_equal(nrow(broad_grid), 330L)
  expect_equal(as.integer(confirm_defaults$reference_contract$expected_qdesn_roots), 90L)
  expect_equal(as.integer(broad_defaults$reference_contract$expected_qdesn_roots), 330L)
  expect_equal(sort(unique(as.numeric(confirm_grid$tau))), c(0.05, 0.25, 0.50))
  expect_equal(sort(unique(as.numeric(broad_grid$tau))), c(0.05, 0.50))
})

test_that("cached materialized source inventory is filtered by stage defaults", {
  repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(file.path(
    repo_root,
    "config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_broad_defaults.yaml"
  ))
  inv <- exdqlm:::qdesn_dynamic_crossstudy_materialize_source_inputs(defaults, refresh = FALSE, verbose = FALSE)
  expect_equal(sort(unique(as.numeric(inv$tau))), c(0.05, 0.50))
  expect_equal(length(unique(paste(inv$source_family, inv$tau, inv$fit_size, sep = "|"))), 6L)
})

test_that("screen ranking uses lead metrics instead of missing campaign forecast scalars", {
  tmp <- tempdir()
  lead_path <- file.path(tmp, "forecast_lead_metrics.csv")
  lead_df <- data.frame(
    root_id = "root_a",
    dataset_cell_id = "cell_a",
    scenario = "scenario",
    family = "normal",
    tau = 0.5,
    fit_size = 500L,
    forecast_protocol = "rolling_origin_no_refit_state_update",
    state_update_method = "forecast_lattice_observed_lag_state_update_no_refit",
    refit_per_origin = FALSE,
    forecast_lead = 1:6,
    origin_stride = 30L,
    max_lead_configured = 30L,
    n_origins_scored = c(34L, 34L, 34L, 34L, 34L, 33L),
    origin_start_source_index = 9000L,
    origin_end_source_index = 9990L,
    target_start_source_index = 9001:9006,
    target_end_source_index = 9991:9996,
    forecast_qtrue_mae = c(1, 2, 3, 4, 5, 6),
    forecast_qtrue_rmse = c(2, 3, 4, 5, 6, 7),
    forecast_qtrue_bias = c(-1, -1, 0, 1, 1, 2),
    forecast_pinball_mean = c(0.5, 0.6, 0.7, 0.8, 0.9, 1.0),
    forecast_coverage = rep(0.5, 6L),
    forecast_coverage_error = rep(0, 6L),
    synthesis_enabled = FALSE,
    posterior_draw_source = "mu_by_origin",
    lead_export_target_scale = "original",
    lead_export_transform = "affine",
    lead_export_scale_status = "original_scale_backtransformed",
    stringsAsFactors = FALSE
  )
  utils::write.csv(lead_df, lead_path, row.names = FALSE)
  fit_path <- file.path(tmp, "campaign_fit_summary.csv")
  fit_df <- data.frame(
    root_id = "root_a",
    scenario = "scenario",
    family = "normal",
    tau = 0.5,
    fit_size = 500L,
    prior = "rhs_ns",
    beta_prior_type = "rhs_ns",
    method = "vb",
    inference = "vb",
    likelihood_family = "exal",
    screening_profile_id = "tt500vb_d1_n30_a0p30_r0p85_tau0_1em4",
    rhs_tau0 = 1e-4,
    D = 1L,
    n_each = 30L,
    alpha = 0.3,
    rho = 0.85,
    train_qtrue_mae = 2,
    holdout_qtrue_mae = 3,
    runtime_sec = 4,
    dimension_p_estimate = 43L,
    p_over_n_tt500 = 0.086,
    forecast_qhat_mae = NA_real_,
    forecast_PinballMean_mean = NA_real_,
    forecast_lead_metrics_path = lead_path,
    stringsAsFactors = FALSE
  )
  utils::write.csv(fit_df, fit_path, row.names = FALSE)

  out <- exdqlm:::qdesn_dynamic_fitforecast_write_screen_ranking(fit_path, out_dir = tmp)
  ranking <- utils::read.csv(out$output_paths$profile_ranking, stringsAsFactors = FALSE)
  expect_equal(nrow(ranking), 1L)
  expect_equal(ranking$screening_profile_base[[1L]], "tt500vb_d1_n30_a0p30_r0p85")
  expect_true(file.exists(out$output_paths$summary))
  expect_true(file.exists(out$output_paths$manifest))
})

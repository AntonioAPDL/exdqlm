qdesn_rhs_fitforecast_rescue_fixture <- function(tmp) {
  fit_path <- file.path(tmp, "fit_forecast_summary.csv")
  baseline_path <- file.path(tmp, "article_baseline.csv")
  mk_profile <- function(id, family, tau, likelihood, train_rmse, fit_check, f_mae, f_check,
                         D = 1L, n_each = 20L, alpha = 0.005, rho = 0.25,
                         m = 15L, pi_w = 0.03, pi_in = 0.30,
                         status = "SUCCESS", eligible = TRUE) {
    n_tilde_each <- if (D <= 1L) 0L else n_each
    p <- D * n_each + max(0L, D - 1L) * n_tilde_each + m + 1L + 5L
    data.frame(
      family = family,
      tau = tau,
      fit_size = 500L,
      screening_profile_id = id,
      status = status,
      comparison_eligible = eligible,
      likelihood_family = likelihood,
      forecast_all_qtrue_mae = f_mae,
      forecast_all_pinball_mean = f_check,
      train_qtrue_rmse = train_rmse,
      train_pinball_tau = fit_check,
      D = D,
      n_each = n_each,
      n_tilde_each = n_tilde_each,
      m = m,
      alpha = alpha,
      rho = rho,
      pi_w = pi_w,
      pi_in = pi_in,
      washout = 300L,
      add_bias = TRUE,
      seed = 123L,
      readout_y_lags = m,
      reservoir_lags = 0L,
      rhs_tau0 = 1e-4,
      dimension_p_estimate = p,
      p_over_n_tt500 = p / 500,
      stringsAsFactors = FALSE
    )
  }
  fit <- rbind(
    mk_profile("tt500vb_ftgt_d1_n20_a0p005_r0p25_m15_lag15_rl0_pw0p03_pin0p3", "gausmix", 0.05, "exal", 4.2, 1.1, 3.0, 1.3, D = 1L, n_each = 20L),
    mk_profile("tt500vb_ftgt_d2_n20_a0p05_r0p6_m15_lag15_rl0_pw0p03_pin0p3", "gausmix", 0.05, "exal", 3.8, 1.2, 3.2, 1.4, D = 2L, n_each = 20L, alpha = 0.05, rho = 0.60),
    mk_profile("tt500vb_ftgt_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3", "normal", 0.50, "al", 2.6, 3.9, 2.0, 4.1, D = 1L, n_each = 30L, alpha = 0.02, rho = 0.45),
    mk_profile("tt500vb_ftgt_d1_n20_a0p005_r0p25_m15_lag15_rl0_pw0p03_pin0p3", "normal", 0.50, "exal", 2.8, 3.8, 2.1, 4.0, D = 1L, n_each = 20L),
    mk_profile("tt500vb_ftgt_d1_n20_a0p005_r0p25_m15_lag15_rl0_pw0p03_pin0p3", "laplace", 0.25, "exal", 2.3, 3.8, 1.6, 4.0, D = 1L, n_each = 20L),
    mk_profile("tt500vb_failed_d1_n10_a0p0025_r0p2_m60_lag60_rl0_pw0p02_pin0p2", "laplace", 0.25, "al", 99, 99, 99, 99, D = 1L, n_each = 10L, alpha = 0.0025, rho = 0.20, m = 60L, status = "FAIL", eligible = FALSE)
  )
  utils::write.csv(fit, fit_path, row.names = FALSE)
  baseline <- data.frame(
    model_family = "exdqlm_dqlm",
    model_variant = rep(c("dqlm", "exdqlm"), each = 3L),
    inference = "vb",
    family = rep(c("gausmix", "normal", "laplace"), times = 2L),
    tau = rep(c(0.05, 0.50, 0.25), times = 2L),
    fit_size = 500L,
    forecast_qtrue_mae_lead_weighted = c(5.0, 1.1, 2.3, 4.8, 1.0, 2.2),
    forecast_pinball_mean_lead_weighted = c(1.6, 4.0, 4.5, 1.5, 3.9, 4.4),
    fit_qtrue_rmse = c(2.0, 1.9, 2.0, 1.8, 1.8, 1.9),
    fit_pinball_mean = c(1.0, 3.7, 3.6, 1.1, 3.6, 3.5),
    stringsAsFactors = FALSE
  )
  utils::write.csv(baseline, baseline_path, row.names = FALSE)
  list(fit = fit_path, baseline = baseline_path)
}

test_that("RHS fit+forecast rescue planner is bounded, cell-specific, and avoids failed shrinkage surface", {
  tmp <- tempfile("qdesn_rhsff_plan_")
  dir.create(tmp)
  fixture <- qdesn_rhs_fitforecast_rescue_fixture(tmp)

  plan <- exdqlm:::qdesn_dynamic_fitforecast_rhs_fitforecast_rescue_plan(
    fit_forecast_summary_path = fixture$fit,
    baseline_path = fixture$baseline,
    screening_wave = "rhsff_test",
    max_profiles_per_cell = 12L,
    max_p_over_n = 0.35
  )

  expect_equal(nrow(plan$cell_plan), 3L)
  expect_lte(nrow(plan$assignments), 36L)
  expect_true(all(plan$assignments$screening_profile_id %in% plan$profiles$screening_profile_id))
  expect_false(any(grepl("failed", plan$profiles$screening_profile_id)))
  expect_false(any(abs(as.numeric(plan$profiles$rhs_tau0) - 3e-5) < 1e-12, na.rm = TRUE))
  expect_true(all(nzchar(plan$cell_plan$best_fit_rmse_profile)))
  expect_true(any(plan$profiles$profile_role == "rescue_normal_edge_forecast"))
  expect_true(any(plan$profiles$profile_role == "rescue_mixture_depth_fit"))
  expect_true(all(as.numeric(plan$profiles$p_over_n_tt500) <= 0.35))
  expect_true(all(c("current_best_fit_rmse_ratio", "bottleneck_metric") %in% names(plan$cell_plan)))
})

test_that("RHS fit+forecast rescue materializes an isolated non-authoritative config bundle", {
  tmp <- tempfile("qdesn_rhsff_materialize_")
  dir.create(tmp)
  fixture <- qdesn_rhs_fitforecast_rescue_fixture(tmp)
  plan <- exdqlm:::qdesn_dynamic_fitforecast_rhs_fitforecast_rescue_plan(
    fit_forecast_summary_path = fixture$fit,
    baseline_path = fixture$baseline,
    screening_wave = "rhsff_test",
    max_profiles_per_cell = 8L,
    max_p_over_n = 0.35
  )
  base_defaults <- file.path(tmp, "base.yaml")
  yaml::write_yaml(
    list(
      campaign = list(name = "base", results_root = "results/base", reports_root = "reports/base"),
      study_contract = list(id = "base", description = "base"),
      screening_profiles = list(enabled = TRUE, csv = "base_profiles.csv", priors = "rhs_ns"),
      reference_contract = list(families = c("gausmix", "laplace", "normal"), taus = c(0.05, 0.25, 0.50), expected_unique_dataset_cells = 3L),
      source_materialization = list(taus = c(0.05, 0.25, 0.50)),
      runtime = list(workers = 1L),
      pipeline = list(outputs = list(save_forecast_objects = FALSE, keep_draws = FALSE))
    ),
    base_defaults
  )

  mat <- exdqlm:::qdesn_dynamic_fitforecast_materialize_forecast_targeted_stage(
    plan = plan,
    base_defaults_path = base_defaults,
    profiles_out = file.path(tmp, "rhsff_profiles.csv"),
    assignments_out = file.path(tmp, "rhsff_assignments.csv"),
    defaults_out = file.path(tmp, "rhsff_defaults.yaml"),
    grid_out = file.path(tmp, "rhsff_grid.csv"),
    workers = 4L,
    refresh_grid = FALSE,
    stage_stub = "qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitforecast_rescue",
    stage_desc = "rhs fit forecast rescue test",
    stage = "rhs_fitforecast_rescue"
  )

  expect_equal(mat$stage, "rhs_fitforecast_rescue")
  expect_equal(mat$n_assignments, nrow(plan$assignments))
  expect_equal(mat$expected_qdesn_roots, nrow(plan$assignments))
  defaults <- yaml::read_yaml(file.path(tmp, "rhsff_defaults.yaml"))
  expect_equal(defaults$campaign$name, "qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitforecast_rescue")
  expect_equal(defaults$runtime$workers, 4L)
  expect_equal(defaults$screening_profiles$selected_assignment_root_count, nrow(plan$assignments))
  expect_false(isTRUE(defaults$pipeline$outputs$save_forecast_objects))
})

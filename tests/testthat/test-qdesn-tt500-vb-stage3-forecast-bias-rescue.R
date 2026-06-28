qdesn_stage3_fixture <- function(tmp) {
  families <- rep(c("gausmix", "laplace", "normal"), each = 3L)
  taus <- rep(c(0.05, 0.25, 0.50), times = 3L)
  spec <- data.frame(
    D = c(2L, 1L, 2L, 1L, 1L, 1L, 1L, 2L, 1L),
    n_each = c(20L, 40L, 20L, 40L, 40L, 40L, 30L, 30L, 30L),
    alpha = c(0.30, 0.03, 0.03, 0.40, 0.10, 0.10, 0.10, 0.03, 0.20),
    rho = c(0.85, 0.50, 0.50, 0.90, 0.70, 0.70, 0.70, 0.50, 0.80),
    m = c(90L, 90L, 30L, 90L, 30L, 30L, 30L, 30L, 30L),
    readout_y_lags = c(90L, 90L, 30L, 90L, 30L, 30L, 30L, 30L, 30L),
    reservoir_lags = c(0L, 1L, 0L, 0L, 0L, 0L, 0L, 0L, 0L),
    pi_w = c(0.05, 0.20, 0.05, 0.05, 0.05, 0.05, 0.10, 0.05, 0.05),
    pi_in = c(0.30, 0.80, 0.30, 0.30, 0.30, 0.30, 0.80, 0.30, 0.30),
    stringsAsFactors = FALSE
  )
  decimal_token <- function(x) gsub("\\.", "p", format(as.numeric(x), trim = TRUE, scientific = FALSE))
  ids <- vapply(seq_len(nrow(spec)), function(i) {
    sprintf(
      "tt500vb_ftgt_d%d_n%d_a%s_r%s_m%d_lag%d_rl%d_pw%s_pin%s",
      spec$D[[i]],
      spec$n_each[[i]],
      decimal_token(spec$alpha[[i]]),
      decimal_token(spec$rho[[i]]),
      spec$m[[i]],
      spec$readout_y_lags[[i]],
      spec$reservoir_lags[[i]],
      decimal_token(spec$pi_w[[i]]),
      decimal_token(spec$pi_in[[i]])
    )
  }, character(1L))
  profiles <- cbind(
    data.frame(screening_profile_id = ids, enabled = TRUE, profile_role = "fixture", stringsAsFactors = FALSE),
    spec
  )
  profiles$n_tilde_each <- ifelse(profiles$D <= 1L, 0L, profiles$n_each)
  profiles$washout <- 300L
  profiles$add_bias <- TRUE
  profiles$seed <- 123L
  profiles$rhs_tau0 <- 1e-4
  profiles$dimension_p_estimate <- profiles$D * profiles$n_each + pmax(0L, profiles$D - 1L) * profiles$n_tilde_each + profiles$readout_y_lags + 1L + 5L
  profiles$p_over_n_tt500 <- profiles$dimension_p_estimate / 500

  worst <- c(0.958, 1.115, 0.987, 0.957, 0.957, 0.960, 0.998, 1.483, 1.470)
  cell <- data.frame(
    family = families,
    tau = taus,
    screening_profile_base = ids,
    forecast_mae_ratio_vs_best_vb_baseline = c(0.64, 1.115, 0.923, 0.392, 0.574, 0.747, 0.998, 1.483, 1.470),
    forecast_pinball_ratio_vs_best_vb_baseline = c(0.958, 1.007, 0.987, 0.957, 0.957, 0.960, 0.994, 1.029, 1.038),
    fit_rmse_ratio_vs_best_vb_baseline = c(0.192, 0.245, 0.122, 0.318, 0.159, 0.133, 0.145, 0.147, 0.151),
    fit_pinball_ratio_vs_best_vb_baseline = c(0.506, 0.470, 0.434, 0.582, 0.455, 0.448, 0.571, 0.489, 0.397),
    primary_worst_ratio_vs_baseline = worst,
    stringsAsFactors = FALSE
  )
  cell_path <- file.path(tmp, "cell_summary.csv")
  profiles_path <- file.path(tmp, "profiles.csv")
  utils::write.csv(cell, cell_path, row.names = FALSE)
  utils::write.csv(profiles, profiles_path, row.names = FALSE)
  list(cell_path = cell_path, profiles_path = profiles_path)
}

test_that("Stage 3 forecast-bias planner targets only cells without a primary-dominating Q-DESN profile", {
  tmp <- tempfile("qdesn_stage3_plan_")
  dir.create(tmp)
  fixture <- qdesn_stage3_fixture(tmp)

  plan <- exdqlm:::qdesn_dynamic_fitforecast_stage3_forecast_bias_profile_plan(
    cell_summary_path = fixture$cell_path,
    source_profiles_path = fixture$profiles_path,
    screening_wave = "stage3_test",
    target_profiles_per_cell = 12L,
    max_p_over_n = 0.50
  )

  expect_equal(nrow(plan$cell_plan), 3L)
  expect_equal(
    paste(plan$cell_plan$family, sprintf("%.2f", plan$cell_plan$tau), sep = ":"),
    c("normal:0.25", "normal:0.50", "gausmix:0.25")
  )
  expect_equal(nrow(plan$assignments), 36L)
  expect_true(all(grepl("^tt500vb_f3_", plan$profiles$screening_profile_id)))
  expect_true(all(as.numeric(plan$profiles$p_over_n_tt500) <= 0.50))
  expect_true(any(as.integer(plan$profiles$m) == 15L))
  expect_true(any(as.numeric(plan$profiles$pi_in) >= 0.80))
  expect_false(any(plan$assignments$family == "laplace"))
})

test_that("Stage 3 materializer writes isolated storage-light config bundle", {
  tmp <- tempfile("qdesn_stage3_materialize_")
  dir.create(tmp)
  fixture <- qdesn_stage3_fixture(tmp)
  plan <- exdqlm:::qdesn_dynamic_fitforecast_stage3_forecast_bias_profile_plan(
    cell_summary_path = fixture$cell_path,
    source_profiles_path = fixture$profiles_path,
    screening_wave = "stage3_test",
    target_profiles_per_cell = 6L,
    max_p_over_n = 0.50
  )
  base_defaults <- file.path(tmp, "base.yaml")
  yaml::write_yaml(
    list(
      campaign = list(name = "base", results_root = "results/base", reports_root = "reports/base"),
      study_contract = list(id = "base", description = "base"),
      screening_profiles = list(enabled = TRUE, csv = "base_profiles.csv", priors = "rhs_ns"),
      reference_contract = list(families = c("normal"), taus = c(0.5)),
      source_materialization = list(taus = c(0.5)),
      runtime = list(workers = 1L),
      pipeline = list(outputs = list(save_forecast_objects = FALSE, keep_draws = FALSE))
    ),
    base_defaults
  )

  mat <- exdqlm:::qdesn_dynamic_fitforecast_materialize_forecast_targeted_stage(
    plan = plan,
    base_defaults_path = base_defaults,
    profiles_out = file.path(tmp, "stage3_profiles.csv"),
    assignments_out = file.path(tmp, "stage3_assignments.csv"),
    defaults_out = file.path(tmp, "stage3_defaults.yaml"),
    grid_out = file.path(tmp, "stage3_grid.csv"),
    workers = 5L,
    refresh_grid = FALSE,
    stage_stub = "qdesn_dynamic_fitforecast_v2_tt500_vb_stage3_forecast_bias_rescue",
    stage_desc = "stage3 test",
    stage = "stage3_forecast_bias_rescue"
  )

  expect_equal(mat$stage, "stage3_forecast_bias_rescue")
  expect_equal(mat$n_assignments, nrow(plan$assignments))
  expect_equal(mat$expected_qdesn_roots, nrow(plan$assignments))
  defaults <- yaml::read_yaml(file.path(tmp, "stage3_defaults.yaml"))
  expect_equal(defaults$campaign$name, "qdesn_dynamic_fitforecast_v2_tt500_vb_stage3_forecast_bias_rescue")
  expect_equal(defaults$runtime$workers, 5L)
  expect_equal(defaults$screening_profiles$selected_assignment_root_count, nrow(plan$assignments))
  expect_false(isTRUE(defaults$pipeline$outputs$save_forecast_objects))
})

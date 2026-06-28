test_that("extended TT500 VB profile identifiers parse complete DESN metadata", {
  ids <- c(
    "tt500vb_hcell_d2_n30_a0p1_r0p7_m90_lag90_rl0_pw0p05_pin0p3",
    "tt500vb_tref_d1_n40_a0p03_r0p5_m90_lag90_rl1_pw0p2_pin0p8",
    "tt500vb_ftgt_d1_n30_a0p05_r0p6_m60_lag60_rl0_pw0p05_pin0p3",
    "tt500vb_d2_n50_a0p30_r0p85"
  )
  parsed <- exdqlm:::qdesn_dynamic_fitforecast_parse_profile_base(ids)

  expect_equal(parsed$D, c(2L, 1L, 1L, 2L))
  expect_equal(parsed$n_each, c(30L, 40L, 30L, 50L))
  expect_equal(parsed$m, c(90L, 90L, 60L, NA_integer_))
  expect_equal(parsed$readout_y_lags, c(90L, 90L, 60L, NA_integer_))
  expect_equal(parsed$reservoir_lags, c(0L, 1L, 0L, NA_integer_))
  expect_equal(parsed$pi_w[1:3], c(0.05, 0.20, 0.05), tolerance = 1e-12)
  expect_equal(parsed$pi_in[1:3], c(0.30, 0.80, 0.30), tolerance = 1e-12)
})

qdesn_tt500_ftgt_fixture <- function(tmp) {
  families <- rep(c("gausmix", "laplace", "normal"), each = 3L)
  taus <- rep(c(0.05, 0.25, 0.50), times = 3L)
  spec <- data.frame(
    D = c(1L, 2L, 2L, 1L, 1L, 2L, 2L, 2L, 1L),
    n_each = c(40L, 30L, 30L, 40L, 30L, 30L, 30L, 40L, 50L),
    alpha = c(0.05, 0.10, 0.20, 0.05, 0.30, 0.30, 0.05, 0.10, 0.20),
    rho = c(0.60, 0.70, 0.80, 0.60, 0.85, 0.85, 0.60, 0.70, 0.80),
    m = c(90L, 90L, 90L, 90L, 60L, 90L, 90L, 90L, 60L),
    readout_y_lags = c(90L, 90L, 90L, 90L, 60L, 90L, 90L, 90L, 60L),
    reservoir_lags = c(0L, 0L, 0L, 0L, 0L, 1L, 0L, 1L, 0L),
    pi_w = c(0.05, 0.10, 0.10, 0.05, 0.05, 0.20, 0.05, 0.20, 0.10),
    pi_in = c(0.30, 0.50, 0.50, 0.30, 0.30, 0.80, 0.30, 0.80, 0.50),
    stringsAsFactors = FALSE
  )
  ids <- vapply(seq_len(nrow(spec)), function(i) {
    exdqlm:::.qdesn_dynamic_fitforecast_dominance_profile_id(
      D = spec$D[[i]],
      n_each = spec$n_each[[i]],
      alpha = spec$alpha[[i]],
      rho = spec$rho[[i]],
      m = spec$m[[i]],
      readout_y_lags = spec$readout_y_lags[[i]],
      reservoir_lags = spec$reservoir_lags[[i]],
      pi_w = spec$pi_w[[i]],
      pi_in = spec$pi_in[[i]],
      prefix = "tt500vb_hcell"
    )
  }, character(1L))
  profile_registry <- cbind(
    data.frame(screening_profile_id = ids, profile_role = "fixture_source", stringsAsFactors = FALSE),
    spec
  )
  profile_registry$washout <- 300L
  profile_registry$add_bias <- TRUE
  profile_registry$seed <- 123L
  profile_registry$rhs_tau0 <- 1e-4
  profile_registry$dimension_p_estimate <- 150L
  profile_registry$p_over_n_tt500 <- 0.30

  cell <- data.frame(
    family = families,
    tau = taus,
    screening_profile_base = ids,
    forecast_mae_ratio_vs_best_vb_baseline = c(0.95, 1.10, 1.20, 0.96, 1.30, 1.60, 1.22, 1.50, 1.63),
    forecast_pinball_ratio_vs_best_vb_baseline = c(0.91, 1.05, 1.10, 0.80, 1.25, 1.45, 1.18, 1.40, 1.50),
    fit_rmse_ratio_vs_best_vb_baseline = rep(0.35, 9L),
    fit_pinball_ratio_vs_best_vb_baseline = rep(0.40, 9L),
    stringsAsFactors = FALSE
  )
  cell_path <- file.path(tmp, "cell_summary.csv")
  registry_path <- file.path(tmp, "profiles.csv")
  utils::write.csv(cell, cell_path, row.names = FALSE)
  utils::write.csv(profile_registry, registry_path, row.names = FALSE)
  list(cell_path = cell_path, registry_path = registry_path)
}

test_that("forecast-targeted planner is cell-specific, bounded, and sentinel-aware", {
  tmp <- tempfile("qdesn_ftgt_plan_")
  dir.create(tmp)
  fixture <- qdesn_tt500_ftgt_fixture(tmp)

  plan <- exdqlm:::qdesn_dynamic_fitforecast_forecast_targeted_profile_plan(
    cell_summary_path = fixture$cell_path,
    source_profiles_path = fixture$registry_path,
    screening_wave = "test_ftgt",
    max_p_over_n = 0.50
  )

  expect_equal(nrow(plan$cell_plan), 9L)
  expect_equal(sort(unique(plan$cell_plan$cell_status)), c("extreme_hard", "hard", "near_pass", "sentinel"))
  expect_equal(sum(plan$cell_plan$target_profiles), nrow(plan$assignments))
  expect_equal(nrow(plan$assignments), 212L)
  expect_true(all(grepl("^tt500vb_ftgt_", plan$profiles$screening_profile_id)))
  expect_true(all(as.numeric(plan$profiles$p_over_n_tt500) <= 0.50))
  expect_true(all(as.integer(plan$profiles$m) <= 90L))
  expect_true(all(as.integer(plan$profiles$readout_y_lags) <= 90L))
  expect_true(any(plan$assignments$cell_status == "sentinel"))
  expect_true(any(plan$assignments$cell_status == "extreme_hard"))
  expect_true(all(c("assignment_key", "assignment_id", "bottleneck_metric") %in% names(plan$assignments)))
})

test_that("forecast-targeted materializer writes reproducible config bundle", {
  tmp <- tempfile("qdesn_ftgt_materialize_")
  dir.create(tmp)
  fixture <- qdesn_tt500_ftgt_fixture(tmp)
  plan <- exdqlm:::qdesn_dynamic_fitforecast_forecast_targeted_profile_plan(
    cell_summary_path = fixture$cell_path,
    source_profiles_path = fixture$registry_path,
    screening_wave = "test_ftgt",
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
      runtime = list(workers = 1L)
    ),
    base_defaults
  )

  mat <- exdqlm:::qdesn_dynamic_fitforecast_materialize_forecast_targeted_stage(
    plan = plan,
    base_defaults_path = base_defaults,
    profiles_out = file.path(tmp, "forecast_targeted_profiles.csv"),
    assignments_out = file.path(tmp, "forecast_targeted_assignments.csv"),
    defaults_out = file.path(tmp, "forecast_targeted_defaults.yaml"),
    grid_out = file.path(tmp, "forecast_targeted_grid.csv"),
    workers = 7L,
    refresh_grid = FALSE
  )

  expect_equal(mat$n_profiles, nrow(plan$profiles))
  expect_equal(mat$n_assignments, nrow(plan$assignments))
  expect_equal(mat$expected_qdesn_roots, nrow(plan$assignments))
  expect_equal(mat$n_grid_rows, 0L)
  expect_true(file.exists(file.path(tmp, "forecast_targeted_profiles.csv")))
  expect_true(file.exists(file.path(tmp, "forecast_targeted_assignments.csv")))
  expect_true(file.exists(file.path(tmp, "forecast_targeted_defaults.yaml")))
  defaults <- yaml::read_yaml(file.path(tmp, "forecast_targeted_defaults.yaml"))
  expect_equal(defaults$campaign$name, "qdesn_dynamic_fitforecast_v2_tt500_vb_forecast_targeted")
  expect_equal(defaults$runtime$workers, 7L)
  expect_equal(defaults$screening_profiles$priors, "rhs_ns")
  expect_equal(defaults$smoke$max_roots, 1L)
})

test_that("dominance ranker fills extended profile metadata from identifiers", {
  tmp <- tempfile("qdesn_ftgt_ranker_")
  dir.create(tmp)
  q_path <- file.path(tmp, "qdesn_summary.csv")
  baseline_path <- file.path(tmp, "baseline.csv")
  id <- "tt500vb_hcell_d2_n30_a0p1_r0p7_m90_lag90_rl1_pw0p2_pin0p8"
  q <- data.frame(
    screening_profile_id = id,
    family = "normal",
    tau = 0.5,
    fit_size = 500L,
    forecast_all_qtrue_mae = 0.8,
    forecast_all_pinball_mean = 0.4,
    train_qtrue_rmse = 0.8,
    train_pinball_tau = 0.4,
    runtime_sec = 10,
    dimension_p_estimate = 140L,
    p_over_n_tt500 = 0.28,
    stringsAsFactors = FALSE
  )
  baseline <- data.frame(
    model_family = "exdqlm_dqlm",
    model_variant = "dqlm",
    inference = "vb",
    family = "normal",
    tau = 0.5,
    fit_size = 500L,
    forecast_qtrue_mae_lead_weighted = 1,
    forecast_pinball_mean_lead_weighted = 0.5,
    fit_qtrue_rmse = 1,
    fit_pinball_mean = 0.5,
    stringsAsFactors = FALSE
  )
  utils::write.csv(q, q_path, row.names = FALSE)
  utils::write.csv(baseline, baseline_path, row.names = FALSE)

  out <- exdqlm:::qdesn_dynamic_fitforecast_rank_screen_against_vb_baseline(
    fit_forecast_summary_path = q_path,
    baseline_path = baseline_path,
    out_dir = tmp
  )
  cell <- out$cell_summary
  expect_equal(cell$D[[1L]], 2L)
  expect_equal(cell$n_each[[1L]], 30L)
  expect_equal(cell$m[[1L]], 90L)
  expect_equal(cell$readout_y_lags[[1L]], 90L)
  expect_equal(cell$reservoir_lags[[1L]], 1L)
  expect_equal(cell$pi_w[[1L]], 0.20, tolerance = 1e-12)
  expect_equal(cell$pi_in[[1L]], 0.80, tolerance = 1e-12)
})

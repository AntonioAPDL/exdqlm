test_that("hard-cell forecast refinement profiles are compact, bounded, and source-contract aware", {
  tmp <- tempfile("qdesn_hcell_profiles_")
  dir.create(tmp)
  cell_path <- file.path(tmp, "cell.csv")
  cells <- expand.grid(
    family = c("gausmix", "laplace", "normal"),
    tau = c(0.05, 0.25, 0.50),
    stringsAsFactors = FALSE
  )
  cells$screening_profile_base <- sprintf(
    "tt500vb_tref_d%d_n%d_a%s_r%s_m90_lag90_rl0_pw0p05_pin0p3",
    rep(c(1L, 2L, 1L), length.out = nrow(cells)),
    rep(c(30L, 40L, 50L), length.out = nrow(cells)),
    rep(c("0p05", "0p1", "0p3"), length.out = nrow(cells)),
    rep(c("0p6", "0p7", "0p85"), length.out = nrow(cells))
  )
  cells$forecast_mae_ratio_vs_best_vb_baseline <- c(0.9, 1.2, 1.4, 0.8, 1.3, 1.6, 1.1, 1.5, 1.7)
  cells$forecast_pinball_ratio_vs_best_vb_baseline <- c(0.8, 1.1, 1.2, 0.9, 1.1, 1.4, 1.0, 1.2, 1.5)
  cells$fit_rmse_ratio_vs_best_vb_baseline <- rep(0.6, nrow(cells))
  cells$fit_pinball_ratio_vs_best_vb_baseline <- rep(0.7, nrow(cells))
  cells$D <- rep(c(1L, 2L, 1L), length.out = nrow(cells))
  cells$n_each <- rep(c(30L, 40L, 50L), length.out = nrow(cells))
  cells$alpha <- rep(c(0.05, 0.10, 0.30), length.out = nrow(cells))
  cells$rho <- rep(c(0.60, 0.70, 0.85), length.out = nrow(cells))
  cells$pi_w <- 0.05
  cells$pi_in <- 0.30
  cells$reservoir_lags <- 0L
  utils::write.csv(cells, cell_path, row.names = FALSE)

  plan <- exdqlm:::qdesn_dynamic_fitforecast_hardcell_forecast_profile_plan(
    cell_summary_path = cell_path,
    max_profiles = 12L,
    max_p_over_n = 0.50
  )

  expect_equal(nrow(plan$cell_plan), 9L)
  expect_gt(sum(plan$cell_plan$cell_role == "hard"), 0L)
  expect_lte(nrow(plan$profiles), 12L)
  expect_equal(length(unique(plan$profiles$screening_profile_id)), nrow(plan$profiles))
  expect_true(all(grepl("^tt500vb_hcell_", plan$profiles$screening_profile_id)))
  expect_true(all(as.numeric(plan$profiles$p_over_n_tt500) <= 0.50))
  expect_true(all(plan$profiles$m == 90L))
  expect_true(all(plan$profiles$readout_y_lags == 90L))
  expect_true(all(c("hardcell_source_cells", "hardcell_profile_rank") %in% names(plan$profiles)))
})

test_that("hard-cell forecast refinement materializes its own stage namespace", {
  tmp <- tempfile("qdesn_hcell_materialize_")
  dir.create(tmp)
  profiles <- data.frame(
    screening_profile_id = "tt500vb_hcell_d1_n30_a0p05_r0p6_m90_lag90_rl0_pw0p05_pin0p3",
    screening_stage = "vb_hardcell_forecast_refinement",
    screening_wave = "hardcell",
    profile_role = "hardcell_sparse",
    enabled = TRUE,
    D = 1L,
    n_each = 30L,
    n_tilde_each = 0L,
    m = 90L,
    alpha = 0.05,
    rho = 0.60,
    pi_w = 0.05,
    pi_in = 0.30,
    washout = 300L,
    add_bias = TRUE,
    seed = 123L,
    readout_y_lags = 90L,
    reservoir_lags = 0L,
    rhs_tau0 = 1e-4,
    dimension_p_estimate = 126L,
    p_over_n_tt500 = 0.252,
    stringsAsFactors = FALSE
  )
  base_defaults <- file.path(tmp, "base.yaml")
  yaml::write_yaml(
    list(
      campaign = list(name = "base", results_root = "results/base", reports_root = "reports/base"),
      study_contract = list(id = "base", description = "base"),
      screening_profiles = list(enabled = TRUE, csv = "base_profiles.csv", priors = "rhs_ns"),
      reference_contract = list(families = c("normal", "laplace"), taus = c(0.25, 0.5)),
      source_materialization = list(taus = c(0.25, 0.5)),
      runtime = list(workers = 1L)
    ),
    base_defaults
  )

  mat <- exdqlm:::qdesn_dynamic_fitforecast_materialize_followup_stage(
    stage = "hardcell_forecast_refinement",
    profiles = profiles,
    base_defaults_path = base_defaults,
    profiles_out = file.path(tmp, "hardcell_profiles.csv"),
    defaults_out = file.path(tmp, "hardcell_defaults.yaml"),
    grid_out = file.path(tmp, "hardcell_grid.csv"),
    workers = 4L,
    refresh_grid = FALSE
  )
  expect_equal(mat$stage_stub, "qdesn_dynamic_fitforecast_v2_tt500_vb_hardcell_forecast_refinement")
  expect_equal(mat$n_profiles, 1L)
  expect_equal(mat$expected_qdesn_roots, 4L)
  defaults <- yaml::read_yaml(file.path(tmp, "hardcell_defaults.yaml"))
  expect_equal(defaults$campaign$name, mat$stage_stub)
  expect_equal(defaults$runtime$workers, 4L)
  expect_equal(defaults$reference_contract$expected_qdesn_roots, 4L)
})

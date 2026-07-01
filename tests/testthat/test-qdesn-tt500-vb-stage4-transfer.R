qdesn_stage4_transfer_fixture <- function(tmp) {
  families <- rep(c("normal", "laplace", "gausmix"), each = 3L)
  taus <- rep(c(0.05, 0.25, 0.50), times = 3L)
  article_rows <- list()
  for (i in seq_along(families)) {
    fam <- families[[i]]
    tau <- taus[[i]]
    for (variant in c("dqlm", "exdqlm")) {
      article_rows[[length(article_rows) + 1L]] <- data.frame(
        model_family = "exdqlm_dqlm",
        model_variant = variant,
        model_key = paste0(variant, "_vb"),
        model_label = variant,
        inference = "vb",
        family = fam,
        tau = tau,
        fit_size = 500L,
        fit_qtrue_rmse = 10,
        fit_pinball_mean = 10,
        forecast_qtrue_mae_lead_weighted = 10,
        forecast_pinball_mean_lead_weighted = 10,
        runtime_hours = 0.01,
        stringsAsFactors = FALSE
      )
    }
    unresolved <- paste(fam, sprintf("%.2f", tau), sep = ":") %in% c(
      "normal:0.05", "laplace:0.05", "laplace:0.25",
      "laplace:0.50", "gausmix:0.05", "gausmix:0.50"
    )
    article_rows[[length(article_rows) + 1L]] <- data.frame(
      model_family = "qdesn",
      model_variant = "exal_rhs_ns",
      model_key = "qdesn_exal_rhs_ns",
      model_label = "Q-DESN EXAL RHS",
      inference = "vb",
      family = fam,
      tau = tau,
      fit_size = 500L,
      fit_qtrue_rmse = 2,
      fit_pinball_mean = 5,
      forecast_qtrue_mae_lead_weighted = if (unresolved) 16 else 8,
      forecast_pinball_mean_lead_weighted = if (unresolved) 13 else 8,
      runtime_hours = 0.02,
      stringsAsFactors = FALSE
    )
  }
  article <- do.call(rbind, article_rows)
  article_path <- file.path(tmp, "article_summary.csv")
  utils::write.csv(article, article_path, row.names = FALSE)

  ids <- c(
    "tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3",
    "tt500vb_f3_d1_n30_a0p03_r0p5_m15_lag15_rl0_pw0p03_pin0p3"
  )
  profiles <- do.call(rbind, lapply(seq_along(ids), function(i) {
    row <- exdqlm:::qdesn_dynamic_fitforecast_profile_row(
      D = 1L,
      n_each = 30L,
      alpha = c(0.02, 0.03)[[i]],
      rho = c(0.45, 0.50)[[i]],
      screening_stage = "fixture",
      screening_wave = "fixture",
      profile_role = "fixture",
      rhs_tau0 = 1e-4,
      m = 15L,
      pi_w = 0.03,
      pi_in = 0.30,
      washout = 300L,
      add_bias = TRUE,
      seed = 123L,
      readout_y_lags = 15L,
      reservoir_lags = 0L
    )
    row$screening_profile_id <- ids[[i]]
    row
  }))
  profiles_path <- file.path(tmp, "profiles.csv")
  utils::write.csv(profiles, profiles_path, row.names = FALSE)
  list(article_path = article_path, profiles_path = profiles_path)
}

test_that("Stage 4A transfer planner targets unresolved Article TT500 VB cells only", {
  tmp <- tempfile("qdesn_stage4_transfer_plan_")
  dir.create(tmp)
  fixture <- qdesn_stage4_transfer_fixture(tmp)

  plan <- exdqlm:::qdesn_dynamic_fitforecast_stage4_transfer_profile_plan(
    article_summary_path = fixture$article_path,
    source_profiles_path = fixture$profiles_path,
    screening_wave = "stage4_test"
  )

  expect_equal(nrow(plan$cell_plan), 6L)
  expect_equal(nrow(plan$profiles), 2L)
  expect_equal(nrow(plan$assignments), 12L)
  expect_true(all(plan$cell_plan$family %in% c("normal", "laplace", "gausmix")))
  expect_false(any(paste(plan$cell_plan$family, sprintf("%.2f", plan$cell_plan$tau), sep = ":") %in% c(
    "normal:0.25", "normal:0.50", "gausmix:0.25"
  )))
  expect_true(all(plan$assignments$screening_profile_id %in% plan$profiles$screening_profile_id))
  expect_true(all(plan$profiles$screening_stage == "vb_stage4_remaining_cells_transfer"))
})

test_that("Stage 4A transfer materializer writes isolated cell-specific config bundle", {
  tmp <- tempfile("qdesn_stage4_transfer_materialize_")
  dir.create(tmp)
  fixture <- qdesn_stage4_transfer_fixture(tmp)
  plan <- exdqlm:::qdesn_dynamic_fitforecast_stage4_transfer_profile_plan(
    article_summary_path = fixture$article_path,
    source_profiles_path = fixture$profiles_path,
    screening_wave = "stage4_test"
  )
  base_defaults <- file.path(tmp, "base.yaml")
  yaml::write_yaml(
    list(
      campaign = list(name = "base", results_root = "results/base", reports_root = "reports/base"),
      study_contract = list(id = "base", description = "base"),
      screening_profiles = list(enabled = TRUE, csv = "base_profiles.csv", priors = "rhs_ns"),
      reference_contract = list(families = c("normal", "laplace", "gausmix"), taus = c(0.05, 0.25, 0.50), expected_unique_dataset_cells = 9L),
      source_materialization = list(taus = c(0.05, 0.25, 0.50)),
      runtime = list(workers = 1L),
      pipeline = list(outputs = list(save_forecast_objects = FALSE, keep_draws = FALSE))
    ),
    base_defaults
  )

  mat <- exdqlm:::qdesn_dynamic_fitforecast_materialize_forecast_targeted_stage(
    plan = plan,
    base_defaults_path = base_defaults,
    profiles_out = file.path(tmp, "stage4_profiles.csv"),
    assignments_out = file.path(tmp, "stage4_assignments.csv"),
    defaults_out = file.path(tmp, "stage4_defaults.yaml"),
    grid_out = file.path(tmp, "stage4_grid.csv"),
    workers = 5L,
    refresh_grid = FALSE,
    stage_stub = "qdesn_dynamic_fitforecast_v2_tt500_vb_stage4_remaining_cells_transfer",
    stage_desc = "stage4 transfer test",
    stage = "stage4_remaining_cells_transfer"
  )

  expect_equal(mat$stage, "stage4_remaining_cells_transfer")
  expect_equal(mat$n_assignments, 12L)
  expect_equal(mat$expected_qdesn_roots, 12L)
  defaults <- yaml::read_yaml(file.path(tmp, "stage4_defaults.yaml"))
  expect_equal(defaults$campaign$name, "qdesn_dynamic_fitforecast_v2_tt500_vb_stage4_remaining_cells_transfer")
  expect_equal(defaults$screening_profiles$execution_grid_policy, "cell_specific_subset_grid")
  expect_equal(defaults$screening_profiles$selected_assignment_root_count, 12L)
})

test_that("Forecast-targeted materializer can freeze ridge priors without changing default RHS-NS behavior", {
  tmp <- tempfile("qdesn_materialize_prior_scope_")
  dir.create(tmp)
  fixture <- qdesn_stage4_transfer_fixture(tmp)
  plan <- exdqlm:::qdesn_dynamic_fitforecast_stage4_transfer_profile_plan(
    article_summary_path = fixture$article_path,
    source_profiles_path = fixture$profiles_path,
    screening_wave = "ridge_prior_test"
  )
  base_defaults <- file.path(tmp, "base.yaml")
  yaml::write_yaml(
    list(
      campaign = list(name = "base", results_root = "results/base", reports_root = "reports/base"),
      study_contract = list(id = "base", description = "base"),
      screening_profiles = list(enabled = TRUE, csv = "base_profiles.csv", priors = "rhs_ns"),
      reference_contract = list(families = c("normal", "laplace", "gausmix"), taus = c(0.05, 0.25, 0.50), expected_unique_dataset_cells = 9L),
      source_materialization = list(taus = c(0.05, 0.25, 0.50)),
      runtime = list(workers = 1L),
      pipeline = list(outputs = list(save_forecast_objects = FALSE, keep_draws = FALSE))
    ),
    base_defaults
  )

  exdqlm:::qdesn_dynamic_fitforecast_materialize_forecast_targeted_stage(
    plan = plan,
    base_defaults_path = base_defaults,
    profiles_out = file.path(tmp, "ridge_profiles.csv"),
    assignments_out = file.path(tmp, "ridge_assignments.csv"),
    defaults_out = file.path(tmp, "ridge_defaults.yaml"),
    grid_out = file.path(tmp, "ridge_grid.csv"),
    workers = 2L,
    refresh_grid = FALSE,
    stage_stub = "ridge_prior_test",
    stage_desc = "ridge prior test",
    stage = "ridge_prior_test",
    priors = "ridge"
  )

  defaults <- yaml::read_yaml(file.path(tmp, "ridge_defaults.yaml"))
  expect_equal(unlist(defaults$screening_profiles$priors, use.names = FALSE), "ridge")
  expect_equal(unlist(defaults$smoke$priors, use.names = FALSE), "ridge")
  expect_equal(unlist(defaults$reference_contract$expected_priors, use.names = FALSE), "ridge")
  expect_equal(defaults$screening_profiles$canonical_qdesn_root_count, 18L)
})

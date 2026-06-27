test_that("dominance diagnostics are cell-aware and preserve top profiles", {
  tmp <- tempfile("qdesn_tref_diag_")
  dir.create(tmp)
  cell_path <- file.path(tmp, "cell.csv")
  rank_path <- file.path(tmp, "ranking.csv")
  cell <- data.frame(
    family = rep(c("normal", "laplace"), each = 3),
    tau = rep(c(0.05, 0.25, 0.50), times = 2),
    screening_profile_base = paste0("prof_", seq_len(6)),
    forecast_mae_ratio_vs_best_vb_baseline = c(1.4, 0.9, 1.2, 0.8, 1.6, 1.1),
    forecast_pinball_ratio_vs_best_vb_baseline = c(1.2, 1.0, 1.1, 0.7, 1.3, 1.0),
    fit_rmse_ratio_vs_best_vb_baseline = rep(0.4, 6),
    fit_pinball_ratio_vs_best_vb_baseline = rep(0.5, 6),
    beats_all_primary_baselines = c(FALSE, FALSE, FALSE, TRUE, FALSE, FALSE),
    D = c(1L, 2L, 1L, 2L, 1L, 2L),
    n_each = c(30L, 20L, 50L, 30L, 30L, 50L),
    alpha = c(0.05, 0.10, 0.20, 0.30, 0.05, 0.10),
    rho = c(0.60, 0.70, 0.80, 0.85, 0.60, 0.70),
    stringsAsFactors = FALSE
  )
  utils::write.csv(cell, cell_path, row.names = FALSE)
  utils::write.csv(data.frame(screening_profile_base = "prof_1"), rank_path, row.names = FALSE)

  out <- exdqlm:::qdesn_dynamic_fitforecast_write_dominance_diagnostics(
    cell_summary_path = cell_path,
    profile_ranking_path = rank_path,
    out_dir = file.path(tmp, "diag"),
    top_n_per_cell = 1L
  )
  expect_equal(nrow(out$cell_gap_summary), 6L)
  expect_equal(nrow(out$top_per_cell), 6L)
  expect_true(file.exists(out$output_paths$top_per_cell))
  expect_true(file.exists(out$output_paths$report))
  expect_true(all(c("best_profile", "best_primary_worst_ratio") %in% names(out$cell_gap_summary)))
})

test_that("targeted refinement profiles are bounded, unique, and source-cell tagged", {
  tmp <- tempfile("qdesn_tref_profiles_")
  dir.create(tmp)
  cell_path <- file.path(tmp, "cell.csv")
  cell <- data.frame(
    family = rep(c("normal", "laplace", "gausmix"), each = 2),
    tau = rep(c(0.25, 0.50), times = 3),
    screening_profile_base = paste0("seed_", seq_len(6)),
    forecast_mae_ratio_vs_best_vb_baseline = c(1.6, 1.2, 1.4, 1.1, 1.0, 1.3),
    forecast_pinball_ratio_vs_best_vb_baseline = c(1.2, 1.0, 1.3, 0.9, 0.8, 1.1),
    fit_rmse_ratio_vs_best_vb_baseline = rep(0.4, 6),
    fit_pinball_ratio_vs_best_vb_baseline = rep(0.5, 6),
    D = c(1L, 2L, 2L, 1L, 2L, 1L),
    n_each = c(30L, 50L, 30L, 20L, 20L, 50L),
    alpha = c(0.05, 0.10, 0.30, 0.20, 0.30, 0.05),
    rho = c(0.60, 0.70, 0.85, 0.80, 0.85, 0.60),
    stringsAsFactors = FALSE
  )
  utils::write.csv(cell, cell_path, row.names = FALSE)

  profiles <- exdqlm:::qdesn_dynamic_fitforecast_targeted_refinement_profiles(
    cell_summary_path = cell_path,
    top_n_per_cell = 1L,
    max_profiles = 40L,
    max_p_over_n = 0.50
  )
  expect_lte(nrow(profiles), 40L)
  expect_equal(length(unique(profiles$screening_profile_id)), nrow(profiles))
  expect_true(all(as.numeric(profiles$p_over_n_tt500) <= 0.50))
  expect_true(all(c("targeted_source_cells", "targeted_source_profiles") %in% names(profiles)))
  expect_true(all(profiles$m == 90L))
  expect_true(all(profiles$readout_y_lags == 90L))
})

test_that("targeted refinement materializes reproducible follow-up configs", {
  tmp <- tempfile("qdesn_tref_materialize_")
  dir.create(tmp)
  profiles <- data.frame(
    screening_profile_id = "target_a",
    screening_stage = "vb_dominance_targeted_refinement",
    screening_wave = "targeted",
    profile_role = "targeted_sparse",
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
      reference_contract = list(families = c("normal"), taus = c(0.5)),
      source_materialization = list(taus = c(0.5)),
      runtime = list(workers = 1L)
    ),
    base_defaults
  )

  mat <- exdqlm:::qdesn_dynamic_fitforecast_materialize_followup_stage(
    stage = "refinement",
    profiles = profiles,
    base_defaults_path = base_defaults,
    profiles_out = file.path(tmp, "targeted_profiles.csv"),
    defaults_out = file.path(tmp, "targeted_defaults.yaml"),
    grid_out = file.path(tmp, "targeted_grid.csv"),
    workers = 3L,
    refresh_grid = FALSE
  )
  expect_equal(mat$n_profiles, 1L)
  expect_equal(mat$expected_qdesn_roots, 1L)
  expect_true(file.exists(file.path(tmp, "targeted_profiles.csv")))
  defaults <- yaml::read_yaml(file.path(tmp, "targeted_defaults.yaml"))
  expect_equal(defaults$runtime$workers, 3L)
  expect_equal(defaults$screening_profiles$priors, "rhs_ns")
  expect_equal(defaults$smoke$max_roots, 1L)
})

test_that("fit+forecast materialization anchors Q-DESN train and forecast source indices", {
  skip_if_not_installed("jsonlite")
  skip_if_not_installed("withr")

  tmp <- withr::local_tempdir()
  scenario <- "toy_fitforecast_v2"
  family <- "normal"
  tau_dir <- "tau_0p25"
  full_root <- file.path(tmp, "sources", scenario, family, tau_dir)
  dir.create(full_root, recursive = TRUE)

  n <- 10000L
  source_df <- data.frame(
    t = seq_len(n),
    y = sin(seq_len(n) / 40),
    q_target = cos(seq_len(n) / 50),
    stringsAsFactors = FALSE
  )
  utils::write.csv(source_df, file.path(full_root, "series_wide.csv"), row.names = FALSE)
  utils::write.csv(
    data.frame(t = seq_len(n), q_true = source_df$q_target),
    file.path(full_root, "true_quantile_grid.csv"),
    row.names = FALSE
  )
  saveRDS(
    list(
      y = source_df$y,
      q = matrix(source_df$q_target, ncol = 1),
      p = 0.25,
      info = list(params = list(TT = n)),
      extras = list(source_index = seq_len(n))
    ),
    file.path(full_root, "sim_output.rds")
  )

  defaults <- list(
    source_materialization = list(
      dynamic_root = file.path(tmp, "sources"),
      staged_root = file.path(tmp, "staged"),
      enforce_effective_train_size = TRUE,
      train_end_source_index = 9000L,
      scenarios = scenario,
      families = family,
      taus = 0.25,
      windows = list(
        list(
          effective_fit_size = 500L,
          source_total_size = 1812L,
          source_dir_name = "fit_input_effTT500_totalTT1812",
          label = "effTT500_totalTT1812"
        )
      )
    ),
    external_data = list(holdout_n = 1000L),
    lags = list(m_y = 12L, m_x = 0L),
    pilot = list(reservoir_profile = "deep"),
    reservoir_profiles = list(deep = list(washout = 300L))
  )

  inventory <- exdqlm:::qdesn_dynamic_crossstudy_materialize_source_inputs(
    defaults,
    refresh = TRUE,
    verbose = FALSE
  )

  expect_equal(inventory$raw_start_source_index, 8189L)
  expect_equal(inventory$train_start_source_index, 8501L)
  expect_equal(inventory$train_end_source_index, 9000L)
  expect_equal(inventory$forecast_start_source_index, 9001L)
  expect_equal(inventory$forecast_end_source_index, 10000L)

  selection <- utils::read.csv(inventory$source_selection_indices_path, stringsAsFactors = FALSE)
  expect_equal(nrow(selection), 1812L)
  expect_equal(selection$source_index[1], 8189L)
  expect_equal(selection$source_index[nrow(selection)], 10000L)
  expect_equal(sum(selection$split_role == "pretrain_context"), 312L)
  expect_equal(sum(selection$split_role == "train"), 500L)
  expect_equal(sum(selection$split_role == "forecast"), 1000L)

  verification <- exdqlm:::qdesn_dynamic_fitforecast_verify_source_windows(
    inventory,
    expected_train_end = 9000L,
    expected_forecast_end = 10000L
  )
  expect_equal(verification$status, "PASS")
  expect_equal(verification$train_n, 500L)
  expect_equal(verification$forecast_n, 1000L)
})

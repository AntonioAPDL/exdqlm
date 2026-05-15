test_that("compact path and metric artifacts satisfy the shared schema", {
  rows <- data.frame(source_index = 1:3, horizon = 1:3, y = c(0, 1, 2), q_true = c(0, 1, 2))
  draws <- matrix(rep(c(0, 1, 2), each = 4), nrow = 3, byrow = TRUE)
  path <- ffv2_path_summary(rows, draws, tau = 0.5, split_role = "forecast", qhat_override = c(0, 1, 2))
  expect_silent(ffv2_validate_path_schema(path))

  config <- list(
    row_id = 1, row_key = "row_0001", run_tag = "test", scenario_id = "s",
    family = "normal", tau = 0.5, tau_label = "0p50", fit_size = 500,
    model_variant = "dqlm", inference = "vb", phase = "vb_full",
    source_cell_id = "cell", series_wide_sha256 = "a",
    true_quantile_grid_sha256 = "b", meta_sha256 = "c"
  )
  metrics <- ffv2_row_metrics(config, path, path, runtime_sec = 1)
  expect_silent(ffv2_validate_metrics_schema(metrics))
  expect_true(all(c("forecast_h100_q_mae", "forecast_h1000_pinball_mean") %in% names(metrics)))
})

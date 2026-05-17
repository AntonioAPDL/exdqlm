test_that("shared interface exports article-mergeable metric rows", {
  root <- tempfile("ffv2_run_")
  dir.create(file.path(root, "metrics"), recursive = TRUE)
  dir.create(file.path(root, "interfaces"), recursive = TRUE)
  manifest <- data.frame(
    study_id = "study",
    row_metrics_path = file.path(root, "metrics", "row_0001_metrics.csv"),
    forecast_lead_metrics_path = file.path(root, "metrics", "row_0001_leads.csv"),
    run_root = root,
    stringsAsFactors = FALSE
  )
  config <- list(
    row_id = 1, row_key = "row_0001", run_tag = "test", scenario_id = "s",
    family = "normal", tau = 0.5, tau_label = "0p50", fit_size = 500,
    model_variant = "dqlm", inference = "vb", phase = "vb_full",
    source_cell_id = "cell", series_wide_sha256 = "a",
    true_quantile_grid_sha256 = "b", meta_sha256 = "c"
  )
  path <- ffv2_path_summary(
    data.frame(source_index = 1:2, horizon = 1:2, y = c(0, 1), q_true = c(0, 1)),
    matrix(c(0, 0, 1, 1), nrow = 2, byrow = TRUE),
    tau = 0.5,
    split_role = "forecast",
    qhat_override = c(0, 1)
  )
  metrics <- ffv2_row_metrics(config, path, path, runtime_sec = 1)
  lead_metrics <- data.frame(
    forecast_protocol = "rolling_origin_no_refit_state_update",
    state_update_method = ffv2_exdqlm_plugin_state_update_method(),
    refit_per_origin = FALSE,
    forecast_lead = 1:2,
    origin_stride = 30L,
    max_lead_configured = 30L,
    n_origins_scored = c(34L, 34L),
    origin_start_source_index = c(9000L, 9000L),
    origin_end_source_index = c(9990L, 9990L),
    target_start_source_index = c(9001L, 9002L),
    target_end_source_index = c(9991L, 9992L),
    forecast_qtrue_mae = c(0.1, 0.2),
    forecast_qtrue_rmse = c(0.11, 0.22),
    forecast_qtrue_bias = c(0.01, 0.02),
    forecast_pinball_mean = c(0.03, 0.04),
    forecast_coverage = c(0.5, 0.6),
    forecast_coverage_error = c(0, 0.1),
    stringsAsFactors = FALSE
  )
  ffv2_write_csv(metrics, manifest$row_metrics_path)
  ffv2_write_csv(lead_metrics, manifest$forecast_lead_metrics_path)
  out <- ffv2_export_shared_interface(manifest, file.path(root, "interfaces", "shared.csv"))

  expect_equal(nrow(out), 2L)
  expect_true(all(ffv2_shared_interface_columns() %in% names(out)))
  expect_identical(out$validation_contract_id[[1L]], "qdesn_exdqlm_dqlm_dynamic_fitforecast_v2_shared_interface")
  expect_identical(out$interface_schema_version[[1L]], ffv2_shared_interface_schema_version())
  expect_identical(out$source_registry_hash_value[[1L]], ffv2_shared_source_registry_hash_value())
  expect_equal(out$forecast_h100_end_source_index[[1L]], 9100L)
  expect_equal(out$forecast_lead, 1:2)
  expect_equal(out$n_origins_scored, c(34L, 34L))
  expect_equal(out$forecast_qtrue_mae, c(0.1, 0.2))
  expect_true(all(out$forecast_protocol == "rolling_origin_no_refit_state_update"))
  expect_true(all(out$uses_true_quantile_for_training == FALSE))
})

test_that("shared interface schema artifact matches exporter columns", {
  schema <- utils::read.csv(
    file.path(ffv2_harness_root(), "schema", "shared_fitforecast_interface_schema.csv"),
    stringsAsFactors = FALSE
  )
  expect_setequal(schema$column, ffv2_shared_interface_columns())
  expect_true(all(schema$required %in% c("true", "false", TRUE, FALSE)))
})

test_that("shared interface schema carries required article guard fields", {
  cols <- ffv2_shared_interface_columns()
  guards <- c(
    "interface_schema_version", "forecast_protocol", "source_registry_hash",
    "forecast_lead", "rolling_origin_start_source_index",
    "rolling_origin_end_source_index", "target_start_source_index",
    "target_end_source_index", "n_origins_scored", "uses_true_quantile_for_training",
    "uses_future_observed_y_for_state", "progress_path", "heartbeat_path",
    "validation_branch", "validation_commit"
  )
  expect_true(all(guards %in% cols))
})

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

test_that("row artifact manifests hash storage-light evidence paths", {
  root <- tempfile("ffv2-artifacts-")
  dir.create(root, recursive = TRUE)
  config <- list(
    row_id = 1L,
    row_key = "row_0001",
    run_tag = "test",
    spec_id = "spec",
    phase = "vb_full",
    validation_stage = "all",
    model_variant = "dqlm",
    inference = "vb",
    fit_size = 500L,
    family = "normal",
    tau = 0.5,
    row_status_path = file.path(root, "rows", "status.csv"),
    row_health_path = file.path(root, "health", "health.csv"),
    row_metrics_path = file.path(root, "metrics", "metrics.csv"),
    fit_path_summary_path = file.path(root, "paths", "fit.csv"),
    forecast_path_summary_path = file.path(root, "paths", "forecast.csv"),
    forecast_lead_metrics_path = file.path(root, "paths", "leads.csv"),
    row_progress_path = file.path(root, "progress", "progress.csv"),
    row_heartbeat_path = file.path(root, "heartbeats", "heartbeat.json"),
    log_path = file.path(root, "logs", "row.log"),
    row_config_path = file.path(root, "configs", "row.json"),
    artifact_manifest_path = file.path(root, "artifact_manifests", "row.json")
  )
  status <- ffv2_status_row(config, "done", started_at = Sys.time(), runtime_sec = 1)
  health <- data.frame(row_id = 1L, row_key = "row_0001", run_tag = "test", gate = "PASS", stringsAsFactors = FALSE)
  rows <- data.frame(source_index = 1:2, horizon = 1:2, y = 1:2, q_true = 1:2)
  draws <- matrix(rep(1:2, each = 2), nrow = 2, byrow = TRUE)
  fit_path <- ffv2_path_summary(rows, draws, tau = 0.5, split_role = "fit", qhat_override = 1:2)
  metrics <- ffv2_row_metrics(
    c(config, list(scenario_id = "s", family = "normal", tau_label = "0p50",
                   fit_size = 500L, model_variant = "dqlm", inference = "vb",
                   phase = "vb_full", source_cell_id = "cell",
                   series_wide_sha256 = "a", true_quantile_grid_sha256 = "b",
                   meta_sha256 = "c")),
    fit_path,
    fit_path,
    runtime_sec = 1
  )
  ffv2_write_row_artifacts(config, health, metrics, fit_path, fit_path, status)
  expect_true(file.exists(config$artifact_manifest_path))
  manifest <- jsonlite::read_json(config$artifact_manifest_path, simplifyVector = TRUE)
  expect_equal(manifest$interface_schema_version, ffv2_shared_interface_schema_version())
  expect_true(all(c("role", "path", "sha256", "storage_class") %in% names(manifest$artifacts)))
  expect_true(any(manifest$artifacts$role == "row_metrics_path"))
})

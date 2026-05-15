test_that("shared interface exports article-mergeable metric rows", {
  root <- tempfile("ffv2_run_")
  dir.create(file.path(root, "metrics"), recursive = TRUE)
  dir.create(file.path(root, "interfaces"), recursive = TRUE)
  manifest <- data.frame(
    study_id = "study",
    row_metrics_path = file.path(root, "metrics", "row_0001_metrics.csv"),
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
  ffv2_write_csv(metrics, manifest$row_metrics_path)
  out <- ffv2_export_shared_interface(manifest, file.path(root, "interfaces", "shared.csv"))

  expect_equal(nrow(out), 1L)
  expect_true(all(ffv2_shared_interface_columns() %in% names(out)))
})

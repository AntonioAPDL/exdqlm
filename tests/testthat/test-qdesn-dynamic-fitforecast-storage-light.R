test_that("fit+forecast analysis retention prunes successful full forecast objects after compact summaries", {
  tmp <- tempfile("qdesn-storage-light-")
  dir.create(tmp, recursive = TRUE)
  fixture <- make_fitforecast_compact_fixture(tmp, fit_size = 500L)
  method_dir <- file.path(tmp, "fits", "mcmc_al")
  dir.create(file.path(method_dir, "models"), recursive = TRUE)
  saveRDS(fixture$summary_obj$forecast_objects, file.path(method_dir, "models", "forecast_objects.rds"))

  manifest <- exdqlm:::.qdesn_validation_apply_output_retention(
    method_dir = method_dir,
    status = "SUCCESS",
    defaults = list(
      metrics = list(forecast_horizons = c(100L, 1000L)),
      pipeline = list(outputs = list(
        retention_profile = "analysis",
        save_forecast_objects = FALSE,
        save_compact_fit_paths = TRUE,
        retain_full_rds_on_failure = FALSE
      ))
    ),
    root_spec = fixture$root_spec,
    summary_obj = fixture$summary_obj
  )

  expect_true(isTRUE(manifest$forecast_objects_pruned))
  expect_false(file.exists(file.path(method_dir, "models", "forecast_objects.rds")))
  expect_equal(manifest$compact_train_rows, 500L)
  expect_equal(manifest$compact_holdout_rows, 1000L)
  expect_identical(manifest$index_alignment_status, "PASS")
  expect_equal(manifest$forecast_horizon_summary_rows, 2L)
})

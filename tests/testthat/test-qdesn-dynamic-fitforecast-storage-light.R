test_that("fit+forecast analysis retention prunes successful full forecast objects after compact summaries", {
  tmp <- tempfile("qdesn-storage-light-")
  dir.create(tmp, recursive = TRUE)
  fixture <- make_fitforecast_compact_fixture(tmp, fit_size = 500L)
  method_dir <- file.path(tmp, "fits", "mcmc_al")
  dir.create(file.path(method_dir, "models"), recursive = TRUE)
  saveRDS(fixture$summary_obj$forecast_objects, file.path(method_dir, "models", "forecast_objects.rds"))
  saveRDS(list(trace = TRUE), file.path(method_dir, "models", "rhs_trace.rds"))
  utils::write.csv(
    data.frame(rhs_trace_available = TRUE, tau_last = 1, stringsAsFactors = FALSE),
    file.path(method_dir, "models", "rhs_run_summary.csv"),
    row.names = FALSE
  )

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
  expect_true(isTRUE(manifest$rhs_trace_pruned))
  expect_false(file.exists(file.path(method_dir, "models", "rhs_trace.rds")))
  expect_equal(manifest$compact_train_rows, 500L)
  expect_equal(manifest$compact_holdout_rows, 1000L)
  expect_identical(manifest$index_alignment_status, "PASS")
  expect_equal(manifest$forecast_horizon_summary_rows, 2L)
})

test_that("storage-light retention prunes when rolling-origin exports pass but legacy alignment fails", {
  tmp <- tempfile("qdesn-storage-light-rolling-")
  dir.create(tmp, recursive = TRUE)
  fixture <- make_fitforecast_compact_fixture(tmp, fit_size = 500L)
  root_spec <- fixture$root_spec
  root_spec$train_start_source_index <- 8500L
  source_df <- utils::read.csv(root_spec$source_series_wide_path, stringsAsFactors = FALSE)
  origin_source <- exdqlm:::.qdesn_validation_rolling_origin_sequence(
    train_end_index = 9000L,
    forecast_end_index = 10000L,
    hmax = 30L,
    origin_stride = 30L
  )
  origin_local <- match(origin_source, as.integer(source_df$t))
  make_origin_draws <- function(origin_src) {
    n_lead <- min(30L, 10000L - as.integer(origin_src))
    matrix(
      rep(seq_len(n_lead), each = 3L) + rep(c(-0.1, 0, 0.1), n_lead),
      nrow = n_lead,
      byrow = TRUE
    )
  }
  mu_by_origin <- lapply(origin_source, make_origin_draws)
  yrep_by_origin <- lapply(mu_by_origin, function(x) x + 1)
  summary_obj <- fixture$summary_obj
  summary_obj$forecast_objects$fits_fc[[1L]]$forecast_full <- list(
    origins = as.integer(origin_local),
    yrep_by_origin = yrep_by_origin,
    mu_by_origin = mu_by_origin
  )
  method_dir <- file.path(tmp, "fits", "vb_exal")
  dir.create(file.path(method_dir, "models"), recursive = TRUE)
  saveRDS(summary_obj$forecast_objects, file.path(method_dir, "models", "forecast_objects.rds"))
  saveRDS(list(trace = TRUE), file.path(method_dir, "models", "rhs_trace.rds"))
  utils::write.csv(
    data.frame(rhs_trace_available = TRUE, tau_last = 1, stringsAsFactors = FALSE),
    file.path(method_dir, "models", "rhs_run_summary.csv"),
    row.names = FALSE
  )

  manifest <- exdqlm:::.qdesn_validation_apply_output_retention(
    method_dir = method_dir,
    status = "SUCCESS",
    defaults = list(
      metrics = list(
        forecast_horizons = c(100L, 1000L),
        rolling_origin = list(
          enabled = TRUE,
          require_lead_export = TRUE,
          max_lead_configured = 30L,
          origin_stride = 30L,
          forecast_protocol = "rolling_origin_no_refit_state_update"
        )
      ),
      pipeline = list(outputs = list(
        retention_profile = "storage_light_screening",
        save_forecast_objects = FALSE,
        save_compact_fit_paths = TRUE,
        retain_full_rds_on_failure = FALSE
      ))
    ),
    root_spec = root_spec,
    summary_obj = summary_obj
  )

  expect_identical(manifest$index_alignment_status, "FAIL")
  expect_true(isTRUE(manifest$rolling_origin_ready_for_pruning))
  expect_true(isTRUE(manifest$compact_ready_for_pruning))
  expect_true(isTRUE(manifest$forecast_objects_pruned))
  expect_false(file.exists(file.path(method_dir, "models", "forecast_objects.rds")))
  expect_true(isTRUE(manifest$rhs_trace_pruned))
  expect_false(file.exists(file.path(method_dir, "models", "rhs_trace.rds")))
  expect_equal(manifest$forecast_rolling_origin_rows, 1000L)
  expect_equal(manifest$forecast_lead_metrics_rows, 30L)
})

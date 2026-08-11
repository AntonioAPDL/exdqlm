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

test_that("required rolling-origin export fails explicitly when global indices are unavailable", {
  tmp <- tempfile("qdesn-required-rolling-failure-")
  dir.create(tmp, recursive = TRUE)
  fixture <- make_fitforecast_compact_fixture(tmp, fit_size = 500L)
  full_source <- utils::read.csv(
    fixture$root_spec$source_series_wide_path,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  staged_source <- full_source[8196:10000, , drop = FALSE]
  staged_source$t <- seq_len(nrow(staged_source))
  staged_source$source_index <- NULL
  staged_path <- file.path(tmp, "staged_source_without_global_index.csv")
  utils::write.csv(staged_source, staged_path, row.names = FALSE)
  root_spec <- fixture$root_spec
  root_spec$source_series_wide_path <- staged_path

  origin_source <- exdqlm:::.qdesn_validation_rolling_origin_sequence(
    train_end_index = 9000L,
    forecast_end_index = 10000L,
    hmax = 30L,
    origin_stride = 30L
  )
  make_origin_draws <- function(origin_src) {
    n_lead <- min(30L, 10000L - as.integer(origin_src))
    matrix(rep(seq_len(n_lead), each = 3L), nrow = n_lead, byrow = TRUE)
  }
  summary_obj <- fixture$summary_obj
  summary_obj$forecast_objects$fits_fc[[1L]]$forecast_full <- list(
    origins = as.integer(origin_source - 8195L),
    yrep_by_origin = lapply(origin_source, make_origin_draws),
    mu_by_origin = lapply(origin_source, make_origin_draws)
  )
  method_dir <- file.path(tmp, "fits", "mcmc_exal")
  dir.create(file.path(method_dir, "models"), recursive = TRUE)
  saveRDS(summary_obj$forecast_objects,
          file.path(method_dir, "models", "forecast_objects.rds"))
  defaults <- list(
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
      retention_profile = "storage_light_required_export_test",
      save_forecast_objects = FALSE,
      save_compact_fit_paths = TRUE,
      retain_full_rds_on_failure = FALSE
    ))
  )

  expect_error(
    exdqlm:::.qdesn_validation_apply_output_retention(
      method_dir = method_dir,
      status = "SUCCESS",
      defaults = defaults,
      root_spec = root_spec,
      summary_obj = summary_obj
    ),
    "Required Q-DESN rolling-origin export failed"
  )
  manifest_path <- file.path(method_dir, "manifest", "output_retention.json")
  expect_true(file.exists(manifest_path))
  manifest <- jsonlite::read_json(manifest_path, simplifyVector = TRUE)
  expect_true(isTRUE(manifest$forecast_rolling_origin_required))
  expect_true(isTRUE(manifest$required_lead_export_failure))
  expect_match(manifest$compact_error, "could not be mapped to staged source rows")
})

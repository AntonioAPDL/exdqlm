test_that("Q-DESN rolling lead export uses per-origin mu draws without synthesis", {
  tmp <- tempfile("qdesn-lead-export-")
  dir.create(tmp, recursive = TRUE)
  fixture <- make_fitforecast_compact_fixture(tmp, fit_size = 500L)
  root_spec <- fixture$root_spec
  root_spec$forecast_end_source_index <- 9004L

  source_df <- utils::read.csv(root_spec$source_series_wide_path, stringsAsFactors = FALSE)
  origin_local <- match(c(9000L, 9002L), as.integer(source_df$t))
  forecast_full <- list(
    origins = as.integer(origin_local),
    targets = 9001:9004,
    mix = list(
      y = matrix(-999, nrow = 4L, ncol = 3L),
      mu = matrix(-999, nrow = 4L, ncol = 3L)
    ),
    yrep_by_origin = list(
      matrix(c(-100, -101, -102, -200, -201, -202), nrow = 2L, byrow = TRUE),
      matrix(c(-300, -301, -302, -400, -401, -402), nrow = 2L, byrow = TRUE)
    ),
    mu_by_origin = list(
      matrix(c(10, 12, 14, 20, 22, 24), nrow = 2L, byrow = TRUE),
      matrix(c(30, 32, 34, 40, 42, 44), nrow = 2L, byrow = TRUE)
    )
  )
  summary_obj <- list(
    forecast_objects = list(fits_fc = list(list(forecast_full = forecast_full)))
  )
  defaults <- list(metrics = list(rolling_origin = list(
    enabled = TRUE,
    require_lead_export = TRUE,
    max_lead_configured = 2L,
    origin_stride = 2L,
    forecast_protocol = "rolling_origin_no_refit_state_update"
  )))

  out <- exdqlm:::.qdesn_validation_qdesn_lead_path_df(
    summary_obj = summary_obj,
    root_spec = root_spec,
    defaults = defaults
  )

  expect_equal(out$source_index, 9001:9004)
  expect_equal(out$forecast_origin_source_index, c(9000L, 9000L, 9002L, 9002L))
  expect_equal(out$forecast_lead, c(1L, 2L, 1L, 2L))
  expect_equal(out$qhat, c(12, 22, 32, 42))
  expect_true(all(out$lead_export_transform == "identity"))
  expect_true(all(out$lead_export_target_scale == "original"))
  expect_true(all(out$lead_export_scale_status == "original_scale_identity"))
  expect_true(all(out$posterior_draw_source == "mu_by_origin"))
  expect_true(all(out$predictive_draws_used_for_primary == FALSE))
  expect_true(all(out$synthesis_enabled == FALSE))
  expect_true(all(out$state_update_method == "forecast_lattice_observed_lag_state_update_no_refit"))

  metrics <- exdqlm:::.qdesn_validation_qdesn_lead_metrics_df(out, root_spec)
  expect_equal(metrics$forecast_lead, c(1L, 2L))
  expect_equal(metrics$n_origins_scored, c(2L, 2L))
  expect_true(all(metrics$synthesis_enabled == FALSE))
  expect_true(all(metrics$lead_export_transform == "identity"))
})

test_that("Q-DESN rolling lead export back-transforms standardized model-scale draws", {
  tmp <- tempfile("qdesn-lead-export-scale-")
  dir.create(tmp, recursive = TRUE)
  fixture <- make_fitforecast_compact_fixture(tmp, fit_size = 500L)
  root_spec <- fixture$root_spec
  root_spec$forecast_end_source_index <- 9004L

  source_df <- utils::read.csv(root_spec$source_series_wide_path, stringsAsFactors = FALSE)
  origin_local <- match(c(9000L, 9002L), as.integer(source_df$t))
  forecast_full <- list(
    origins = as.integer(origin_local),
    targets = 9001:9004,
    yrep_by_origin = list(
      matrix(c(-100, -101, -102, -200, -201, -202), nrow = 2L, byrow = TRUE),
      matrix(c(-300, -301, -302, -400, -401, -402), nrow = 2L, byrow = TRUE)
    ),
    mu_by_origin = list(
      matrix(c(10, 12, 14, 20, 22, 24), nrow = 2L, byrow = TRUE),
      matrix(c(30, 32, 34, 40, 42, 44), nrow = 2L, byrow = TRUE)
    ),
    lead_export_scale = list(
      output_scale = "standardized_model",
      target_scale = "original",
      transform = "affine",
      center = 100,
      scale = 10,
      scale_source = "unit-test"
    )
  )
  summary_obj <- list(
    forecast_objects = list(fits_fc = list(list(forecast_full = forecast_full)))
  )
  defaults <- list(metrics = list(rolling_origin = list(
    enabled = TRUE,
    require_lead_export = TRUE,
    max_lead_configured = 2L,
    origin_stride = 2L,
    forecast_protocol = "rolling_origin_no_refit_state_update"
  )))

  out <- exdqlm:::.qdesn_validation_qdesn_lead_path_df(
    summary_obj = summary_obj,
    root_spec = root_spec,
    defaults = defaults
  )

  expected_qhat <- c(220, 320, 420, 520)
  expected_q_true <- source_df$q_target[match(9001:9004, as.integer(source_df$t))]
  expect_equal(out$qhat, expected_qhat)
  expect_equal(out$qhat_p0500, expected_qhat)
  expect_equal(out$q_error, expected_qhat - expected_q_true)
  expect_equal(out$abs_q_error, abs(expected_qhat - expected_q_true))
  expect_true(all(out$lead_export_transform == "affine"))
  expect_true(all(out$lead_export_target_scale == "original"))
  expect_true(all(out$lead_export_scale_status == "original_scale_backtransformed"))

  metrics <- exdqlm:::.qdesn_validation_qdesn_lead_metrics_df(out, root_spec)
  expect_equal(metrics$forecast_lead, c(1L, 2L))
  expect_equal(metrics$forecast_qtrue_mae, c(
    mean(abs(out$q_error[out$forecast_lead == 1L])),
    mean(abs(out$q_error[out$forecast_lead == 2L]))
  ))
  expect_true(all(metrics$lead_export_transform == "affine"))
})

test_that("Q-DESN rolling lead export is failure-explicit when required", {
  tmp <- tempfile("qdesn-lead-export-missing-")
  dir.create(tmp, recursive = TRUE)
  fixture <- make_fitforecast_compact_fixture(tmp, fit_size = 500L)
  summary_obj <- list(
    forecast_objects = list(fits_fc = list(list(forecast_full = list(origins = 812L))))
  )
  required_defaults <- list(metrics = list(rolling_origin = list(
    enabled = TRUE,
    require_lead_export = TRUE,
    max_lead_configured = 2L,
    origin_stride = 2L
  )))
  optional_defaults <- required_defaults
  optional_defaults$metrics$rolling_origin$require_lead_export <- FALSE

  expect_error(
    exdqlm:::.qdesn_validation_qdesn_lead_path_df(summary_obj, fixture$root_spec, required_defaults),
    "requires forecast_full\\$origins"
  )
  out <- exdqlm:::.qdesn_validation_qdesn_lead_path_df(
    summary_obj,
    fixture$root_spec,
    optional_defaults
  )
  expect_equal(nrow(out), 0L)
})

test_that("Q-DESN fitforecast v2 config enables primary rolling lead export", {
  skip_if_not_installed("yaml")
  repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  defaults <- yaml::read_yaml(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_fitforecast_v2_storage_light_defaults.yaml"
  ))

  expect_true(isTRUE(defaults$metrics$rolling_origin$enabled))
  expect_true(isTRUE(defaults$metrics$rolling_origin$require_lead_export))
  expect_equal(as.integer(defaults$metrics$rolling_origin$max_lead_configured), 30L)
  expect_equal(as.integer(defaults$metrics$rolling_origin$origin_stride), 30L)
  expect_equal(defaults$metrics$rolling_origin$forecast_protocol, "rolling_origin_no_refit_state_update")
  expect_equal(defaults$pipeline$forecast$horizon, 30L)
  expect_equal(defaults$pipeline$forecast$origin_stride, 30L)
  expect_true(isTRUE(defaults$pipeline$forecast$primary_lead_export))
  expect_true(isTRUE(defaults$pipeline$outputs$keep_draws))
})

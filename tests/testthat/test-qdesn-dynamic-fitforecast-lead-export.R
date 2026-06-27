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

test_that("Q-DESN rolling origin sequence includes the final partial stride origin", {
  origins <- exdqlm:::.qdesn_validation_rolling_origin_sequence(
    train_end_index = 9000L,
    forecast_end_index = 10000L,
    hmax = 30L,
    origin_stride = 30L
  )

  expect_equal(head(origins, 3), c(9000L, 9030L, 9060L))
  expect_equal(tail(origins, 3), c(9930L, 9960L, 9990L))
  expect_equal(length(origins), 34L)

  grid <- exdqlm:::.qdesn_validation_rolling_grid(
    train_end_source_index = 9000L,
    forecast_start_source_index = 9001L,
    forecast_end_source_index = 10000L,
    hmax = 30L,
    origin_stride = 30L
  )

  expect_equal(nrow(grid), 1000L)
  final_origin <- grid[grid$forecast_origin_source_index == 9990L, , drop = FALSE]
  expect_equal(final_origin$forecast_lead, 1:10)
  expect_equal(final_origin$target_source_index, 9991:10000)
})

test_that("Q-DESN rolling lead export scores final partial origin rows", {
  tmp <- tempfile("qdesn-lead-export-partial-")
  dir.create(tmp, recursive = TRUE)
  fixture <- make_fitforecast_compact_fixture(tmp, fit_size = 500L)
  root_spec <- fixture$root_spec

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
    base <- as.numeric(origin_src - 9000L)
    matrix(
      rep(base + seq_len(n_lead), each = 3L) + rep(c(-0.1, 0, 0.1), n_lead),
      nrow = n_lead,
      byrow = TRUE
    )
  }
  mu_by_origin <- lapply(origin_source, make_origin_draws)
  yrep_by_origin <- lapply(mu_by_origin, function(x) x + 1)
  forecast_full <- list(
    origins = as.integer(origin_local),
    yrep_by_origin = yrep_by_origin,
    mu_by_origin = mu_by_origin
  )
  summary_obj <- list(
    forecast_objects = list(fits_fc = list(list(forecast_full = forecast_full)))
  )
  defaults <- list(metrics = list(rolling_origin = list(
    enabled = TRUE,
    require_lead_export = TRUE,
    max_lead_configured = 30L,
    origin_stride = 30L,
    forecast_protocol = "rolling_origin_no_refit_state_update"
  )))

  out <- exdqlm:::.qdesn_validation_qdesn_lead_path_df(
    summary_obj = summary_obj,
    root_spec = root_spec,
    defaults = defaults
  )

  expect_equal(nrow(out), 1000L)
  expect_equal(sort(unique(out$forecast_origin_source_index)), origin_source)
  final_origin <- out[out$forecast_origin_source_index == 9990L, , drop = FALSE]
  expect_equal(nrow(final_origin), 10L)
  expect_equal(final_origin$forecast_lead, 1:10)
  expect_equal(final_origin$source_index, 9991:10000)
  expect_equal(final_origin$qhat, 991:1000)

  metrics <- exdqlm:::.qdesn_validation_qdesn_lead_metrics_df(out, root_spec)
  expect_equal(metrics$forecast_lead, 1:30)
  expect_equal(metrics$n_origins_scored[metrics$forecast_lead <= 10L], rep(34L, 10L))
  expect_equal(metrics$n_origins_scored[metrics$forecast_lead > 10L], rep(33L, 20L))
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

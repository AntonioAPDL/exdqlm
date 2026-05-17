ffv2_tiny_dynamic_fit <- function(dqlm_ind = TRUE) {
  set.seed(401)
  y <- as.numeric(scale(sin(seq_len(42) / 6) + stats::rnorm(42, sd = 0.04)))
  y_train <- y[1:30]
  model <- polytrendMod(
    order = 1,
    m0 = stats::quantile(y_train, 0.5),
    C0 = 10,
    backend = "R"
  )
  old <- options(exdqlm.max_iter = 6L)
  on.exit(options(old), add = TRUE)
  fit <- exdqlmLDVB(
    y = y_train,
    p0 = 0.5,
    model = model,
    df = 0.98,
    dim.df = 1,
    dqlm.ind = isTRUE(dqlm_ind),
    gam.init = if (isTRUE(dqlm_ind)) NA else 0.1,
    n.samp = 20,
    tol = 0.5,
    verbose = FALSE
  )
  config <- list(
    row_id = 1L,
    row_key = "row_0001",
    run_tag = "rolling-state-fixture",
    model_family = "exdqlm_dqlm",
    model_variant = if (isTRUE(dqlm_ind)) "dqlm" else "exdqlm",
    inference = "vb",
    fit_size = 30L,
    family = "normal",
    tau = 0.5,
    phase = "vb_full",
    train_end_source_index = 30L,
    forecast_start_source_index = 31L,
    forecast_end_source_index = 40L,
    forecast_origin_source_index = 30L,
    forecast_horizon_max = 10L,
    forecast_protocol = "rolling_origin_no_refit_state_update",
    max_lead_configured = 3L,
    origin_stride = 3L,
    row_status_path = tempfile("status_"),
    row_progress_path = tempfile("progress_"),
    row_heartbeat_path = tempfile("heartbeat_"),
    log_path = tempfile("log_")
  )
  data <- list(
    train = data.frame(
      source_index = 1:30,
      y = y_train,
      q_true = y_train * 0,
      stringsAsFactors = FALSE
    ),
    forecast = data.frame(
      source_index = 31:40,
      horizon = 1:10,
      y = y[31:40],
      q_true = y[31:40] * 0,
      stringsAsFactors = FALSE
    )
  )
  list(fit = fit, config = config, data = data)
}

test_that("plug-in pseudo-observation parameters are finite and positive", {
  dqlm <- ffv2_tiny_dynamic_fit(dqlm_ind = TRUE)$fit
  exdqlm <- ffv2_tiny_dynamic_fit(dqlm_ind = FALSE)$fit

  dqlm_params <- ffv2_fit_plugin_pseudo_params(dqlm, 4L)
  exdqlm_params <- ffv2_fit_plugin_pseudo_params(exdqlm, 4L)

  expect_equal(nrow(dqlm_params), 4L)
  expect_equal(nrow(exdqlm_params), 4L)
  expect_true(all(is.finite(dqlm_params$ex_f)))
  expect_true(all(is.finite(exdqlm_params$ex_f)))
  expect_true(all(is.finite(dqlm_params$ex_q) & dqlm_params$ex_q > 0))
  expect_true(all(is.finite(exdqlm_params$ex_q) & exdqlm_params$ex_q > 0))
})

test_that("state extension updates filtered span without refitting", {
  fixture <- ffv2_tiny_dynamic_fit(dqlm_ind = TRUE)
  fit <- fixture$fit
  extended <- ffv2_extend_fit_to_source_origin(fit, fixture$config, fixture$data, 36L)

  expect_equal(length(fit$y), 30L)
  expect_equal(length(extended$y), 36L)
  expect_equal(ncol(extended$theta.out$fm), 36L)
  expect_equal(dim(extended$theta.out$fC)[[3L]], 36L)
  expect_false(isTRUE(extended$ffv2_state_update$refit_per_origin))
  expect_identical(
    extended$ffv2_state_update$method,
    ffv2_exdqlm_plugin_state_update_method()
  )

  future <- ffv2_make_future_model_arrays(extended$model, 2L)
  forecast <- exdqlmForecast(
    start.t = length(extended$y),
    k = 2L,
    m1 = extended,
    fFF = future$fFF,
    fGG = future$fGG,
    plot = FALSE,
    return.draws = TRUE,
    n.samp = 10L,
    seed = 9L
  )
  expect_equal(length(forecast$ff), 2L)
  expect_equal(dim(forecast$samp.fore), c(2L, 10L))
})

test_that("rolling-origin exDQLM forecast emits lead-level rows on the shared grid", {
  fixture <- ffv2_tiny_dynamic_fit(dqlm_ind = TRUE)
  summary <- ffv2_rolling_exdqlm_forecast_summary(
    fit = fixture$fit,
    config = fixture$config,
    data = fixture$data,
    hmax = 3L,
    origin_stride = 3L,
    n_draws = 10L,
    seed = 12L
  )

  expected_grid <- ffv2_rolling_grid(
    initial_origin_source_index = 30L,
    forecast_block_start_source_index = 31L,
    forecast_block_end_source_index = 40L,
    hmax = 3L,
    origin_stride = 3L
  )
  expect_equal(nrow(summary), nrow(expected_grid))
  expect_true(all(ffv2_required_path_columns() %in% names(summary)))
  expect_true(all(c(
    "forecast_protocol", "state_update_method", "refit_per_origin",
    "forecast_origin_source_index", "forecast_lead", "target_source_index"
  ) %in% names(summary)))
  expect_equal(sort(unique(summary$target_source_index)), 31:40)
  expect_equal(sort(unique(summary$forecast_lead)), 1:3)
  expect_true(all(summary$forecast_protocol == "rolling_origin_no_refit_state_update"))
  expect_true(all(!as.logical(summary$refit_per_origin)))

  lead_metrics <- ffv2_rolling_lead_metrics(fixture$config, summary)
  expect_equal(sort(unique(lead_metrics$forecast_lead)), 1:3)
  expect_true(all(lead_metrics$n_origins_scored > 0))
})

test_that("rolling health gate accepts Hmax below the old fixed-origin H=1000 requirement", {
  fixture <- ffv2_tiny_dynamic_fit(dqlm_ind = TRUE)
  summary <- ffv2_rolling_exdqlm_forecast_summary(
    fit = fixture$fit,
    config = fixture$config,
    data = fixture$data,
    hmax = 3L,
    origin_stride = 3L,
    n_draws = 10L,
    seed = 13L
  )
  health <- ffv2_health_from_outputs(fixture$config, forecast_summary = summary, runtime_sec = 1)
  expect_equal(health$gate[[1L]], "PASS")
})

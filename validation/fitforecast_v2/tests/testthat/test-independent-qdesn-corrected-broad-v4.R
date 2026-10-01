iqcb_v4_load_test_code <- function() {
  source(file.path(harness_root, "R", "utils.R"), local = FALSE)
  files <- c(
    "independent_qdesn_full_redesign_v2.R",
    "independent_qdesn_full_redesign_v2_runtime.R",
    "independent_qdesn_posterior_forecast_rescue_v1.R",
    "independent_qdesn_corrected_forecast_v3.R",
    "independent_qdesn_corrected_forecast_v3_campaign.R",
    "independent_qdesn_fixed_comparator_stride1_v1.R",
    "independent_qdesn_corrected_broad_v4.R"
  )
  for (file in files) source(file.path(harness_root, "R", file), local = FALSE)
  repo_root
}

test_that("v4 protocol freezes the complete forecast-first design", {
  root <- iqcb_v4_load_test_code()
  protocol <- iqcb_v4_read_protocol(root)
  checks <- iqcb_v4_protocol_checks(protocol)
  expect_true(all(checks$pass), info = paste(checks$check[!checks$pass],
                                              collapse = ", "))
  expect_equal(protocol$search$expected_broad_jobs, 288)
  expect_equal(protocol$scope$expected_development_comparator_jobs, 18)
  expect_equal(
    protocol$scope$development_comparators,
    c("dqlm_al_vb", "exdqlm_exal_vb",
      "training_empirical_quantile_constant")
  )
  expect_equal(protocol$shrinkage$broad_tau_multipliers, c(1, 3.5))
  expect_false(protocol$execution$automatic_adaptive_launch)
  expect_false(protocol$execution$automatic_mcmc_launch)
})

test_that("canonical structure normalization enforces identity and fixed seed", {
  iqcb_v4_load_test_code()
  row <- data.frame(
    D = 3L, n = "20;40;20", n_tilde = "1;1", m = 90L,
    alpha = 0.5, rho = 0.9, center_scale = "mean_sd",
    input_bound = "none", input_gain = 0.1,
    recurrent_indegree = 10L, input_fanin_fraction = 0.25,
    input_fanin = 23L, interlayer_fanin = 20L, matrix_seed = 123L,
    stringsAsFactors = FALSE
  )
  out <- iqcb_v4_normalize_structure(row, "normal", "test", "source")
  expect_identical(out$n_tilde, "20;40")
  expect_equal(out$readout_dimension, 81L)
  expect_equal(out$matrix_seed, 920001L)
  expect_match(out$structure_id, "^iqcb4_normal_")
})

test_that("deterministic unseen designs are deep, valid, and distinct", {
  iqcb_v4_load_test_code()
  template <- data.frame(
    D = 1L, n = "20", n_tilde = "", m = 30L, alpha = 0.2, rho = 0.8,
    center_scale = "mean_sd", input_bound = "none", input_gain = 0.1,
    recurrent_indegree = 5L, input_fanin_fraction = 0.25,
    input_fanin = 8L, interlayer_fanin = 5L, matrix_seed = 1L,
    stringsAsFactors = FALSE
  )
  designs <- lapply(c("normal", "laplace", "gausmix"), function(family) {
    iqcb_v4_novel_structure(template, family)
  })
  expect_true(all(vapply(designs, function(x) x$D >= 4L, logical(1L))))
  expect_equal(length(unique(vapply(designs, function(x) {
    x$canonical_structure_signature
  }, character(1L)))), 3L)
  for (design in designs) {
    expect_identical(iqcb_v4_unpack_n(design$n_tilde),
                     head(iqcb_v4_unpack_n(design$n), -1L))
  }
})

test_that("v3 status and result labels can be supplied by a newer protocol", {
  iqcb_v4_load_test_code()
  body_status <- paste(deparse(body(iqcf_v3_status_write)), collapse = "\n")
  body_job <- paste(deparse(body(iqcf_v3_run_job)), collapse = "\n")
  expect_match(body_status, "cfg\\$schema_version")
  expect_match(body_job, "cfg\\$schema_version")
})

test_that("stage launcher enforces one thread, resume hashes, and gates", {
  root <- iqcb_v4_load_test_code()
  script <- paste(readLines(file.path(
    root, "validation", "fitforecast_v2", "scripts",
    "run_independent_qdesn_corrected_broad_v4_stage.sh"
  ), warn = FALSE), collapse = "\n")
  expect_match(script, "OMP_NUM_THREADS=1", fixed = TRUE)
  expect_match(script, "--process-slot-var=IQCB_SLOT", fixed = TRUE)
  expect_match(script, "PASS_UNLOCK_BROAD_SCREEN", fixed = TRUE)
  expect_match(script, "PASS_MATCHED_COMPARATORS_COMPLETE", fixed = TRUE)
  expect_match(script, "PASS_READY_FOR_ADAPTIVE_REFINEMENT", fixed = TRUE)
  expect_match(script, "artifact_sha256", fixed = TRUE)
  expect_false(grepl("origin/main", script, fixed = TRUE))
})

test_that("matched comparator remap changes evaluation but preserves science", {
  root <- iqcb_v4_load_test_code()
  protocol <- iqcb_v4_read_protocol(root)
  source <- list(
    model_variant = "dqlm", family = "normal", tau = 0.25,
    dqlm_ind = TRUE, calibration_id = "frozen", latent_clock_mode = "explicit",
    latent_clock_start_source_index = 10501L, model_C0_scale = 0.01,
    trend_C0_scale = 100, seasonal_C0_scale = 1, df_value = 0.99,
    dim_df = c(2L, 4L), dynamic_model_period = 90L,
    dynamic_model_harmonics = c(1L, 2L), models = list(df_value = 0.99),
    series_wide_path = "/tmp/series.csv", series_wide_sha256 = "series",
    true_quantile_grid_path = "/tmp/truth.csv",
    true_quantile_grid_sha256 = "truth", sim_output_path = "/tmp/sim.rds",
    sim_output_sha256 = "sim", meta_path = "/tmp/meta.txt",
    meta_sha256 = "meta", run_root = tempdir(),
    row_status_path = file.path(tempdir(), "rows/status.csv"),
    row_health_path = file.path(tempdir(), "health/health.csv"),
    row_metrics_path = file.path(tempdir(), "metrics/metrics.csv"),
    fit_path_summary_path = file.path(tempdir(), "fit/fit.csv"),
    forecast_path_summary_path = file.path(tempdir(), "forecast/forecast.csv"),
    row_progress_path = file.path(tempdir(), "progress/progress.csv"),
    row_heartbeat_path = file.path(tempdir(), "heartbeat/heartbeat.json"),
    forecast_lead_metrics_path = file.path(tempdir(), "leads/leads.csv"),
    artifact_manifest_path = file.path(tempdir(), "artifacts/artifacts.json"),
    fit_handoff_path = file.path(tempdir(), "handoff/fit.ffv2handoff"),
    fit_handoff_manifest_path = file.path(tempdir(), "handoff/fit.json"),
    vb_init_handoff_path = file.path(tempdir(), "handoff/vb.ffv2handoff"),
    vb_init_handoff_manifest_path = file.path(tempdir(), "handoff/vb.json"),
    log_path = file.path(tempdir(), "logs/job.log"), metric_draws_path = "",
    metric_interval_summary_path = "", metric_interval_manifest_path = "",
    inference_diagnostics_path = "/tmp/source-job/metrics/inference.json",
    budget = list(vb = list()), runtime = list(), handoff = list(),
    retention = list(), metric_intervals = list()
  )
  registry <- data.frame(source_authority = "test", source_job_id = "source",
                         stringsAsFactors = FALSE)
  target <- iqcb_v4_remap_comparator_config(
    source, root, "/tmp/iqcb-v4-test", registry,
    "/tmp/frozen-source.json", protocol, 1L
  )
  audit <- iqcb_v4_comparator_config_audit(source, target)
  expect_true(audit$pass)
  expect_equal(target$train_end_source_index, 8750L)
  expect_equal(target$forecast_end_source_index, 9000L)
  expect_equal(target$origin_stride, 5L)
  expect_equal(target$forecast_horizon_max, 30L)
  expect_identical(target$inference, "vb")
  expect_identical(target$state_update_method,
                   "deterministic_plugin_filter_train_median_latent_moments")
  expect_false(target$metric_intervals$enabled)
})

test_that("pipeline orders all three gated stages", {
  root <- iqcb_v4_load_test_code()
  path <- file.path(root, "validation", "fitforecast_v2", "scripts",
                    "run_independent_qdesn_corrected_broad_v4_pipeline.sh")
  script <- paste(readLines(path, warn = FALSE), collapse = "\n")
  positions <- vapply(c("current_stage=operator_smoke",
                        "current_stage=development_comparator",
                        "current_stage=broad_screen"),
                      function(token) regexpr(token, script, fixed = TRUE)[[1L]],
                      integer(1L))
  expect_true(all(positions > 0L))
  expect_true(all(diff(positions) > 0L))
  expect_match(script, "memory_gb", fixed = TRUE)
  expect_match(script, "disk_gb", fixed = TRUE)
})

test_that("adaptive budget is exactly 96 under the predeclared allocation", {
  root <- iqcb_v4_load_test_code()
  protocol <- iqcb_v4_read_protocol(root)
  lower <- sum(as.numeric(protocol$scope$quantiles) < 0.5)
  median <- sum(as.numeric(protocol$scope$quantiles) == 0.5)
  per_family_likelihood <- 3L * 2L
  expected <- per_family_likelihood * (
    lower * protocol$adaptive$structures_per_cell *
      length(protocol$adaptive$lower_quantile_multipliers) +
      median * protocol$adaptive$structures_per_cell *
      length(protocol$adaptive$median_multipliers)
  )
  expect_equal(expected, 96)
  expect_equal(expected, protocol$adaptive$maximum_jobs)
})

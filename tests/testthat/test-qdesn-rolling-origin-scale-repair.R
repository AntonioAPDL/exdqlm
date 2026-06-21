test_that("Q-DESN rolling-origin scale repair writes corrected artifacts non-destructively", {
  skip_if_not_installed("jsonlite")
  repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  tmp <- tempfile("qdesn-scale-repair-")
  method_dir <- file.path(tmp, "results", "roots", "root1", "fits", "vb_al")
  dir.create(file.path(method_dir, "tables"), recursive = TRUE)
  dir.create(file.path(method_dir, "manifest"), recursive = TRUE)
  dir.create(file.path(tmp, "results", "roots", "root1", "data"), recursive = TRUE)

  observed <- data.frame(y = c(10, 20, 30, 40))
  utils::write.csv(observed, file.path(tmp, "results", "roots", "root1", "data", "observed.csv"), row.names = FALSE)
  jsonlite::write_json(
    list(config = list(preproc = list(scale_y = TRUE))),
    file.path(method_dir, "fit_request.json"),
    auto_unbox = TRUE
  )

  rolling_path <- file.path(method_dir, "tables", "forecast_rolling_origin_paths.csv")
  metrics_path <- file.path(method_dir, "tables", "forecast_lead_metrics.csv")
  rolling <- data.frame(
    split_role = "rolling_forecast",
    source_index = c(9001L, 9002L),
    y = c(25, 35),
    q_true = c(25, 35),
    qhat = c(0, 1),
    q_error = c(-25, -34),
    abs_q_error = c(25, 34),
    squared_q_error = c(625, 1156),
    pinball_tau = c(12.5, 17),
    hit = c(0L, 0L),
    coverage_minus_tau = c(-0.5, -0.5),
    horizon = c(1L, 2L),
    forecast_protocol = "rolling_origin_no_refit_state_update",
    state_update_method = "forecast_lattice_observed_lag_state_update_no_refit",
    refit_per_origin = FALSE,
    forecast_origin_source_index = c(9000L, 9000L),
    forecast_lead = c(1L, 2L),
    target_source_index = c(9001L, 9002L),
    origin_sequence_id = 1L,
    origin_stride = 30L,
    max_lead_configured = 30L,
    n_origins_for_lead = 1L,
    posterior_draw_source = "mu_by_origin",
    qhat_p0500 = c(0, 1),
    stringsAsFactors = FALSE
  )
  utils::write.csv(rolling, rolling_path, row.names = FALSE)
  metrics <- data.frame(
    root_id = "root1",
    dataset_cell_id = "cell1",
    scenario = "fixture",
    family = "normal",
    tau = 0.5,
    fit_size = 500L,
    forecast_protocol = "rolling_origin_no_refit_state_update",
    state_update_method = "forecast_lattice_observed_lag_state_update_no_refit",
    refit_per_origin = FALSE,
    forecast_lead = c(1L, 2L),
    origin_stride = 30L,
    max_lead_configured = 30L,
    n_origins_scored = 1L,
    forecast_qtrue_mae = c(25, 34),
    forecast_qtrue_rmse = c(25, 34),
    forecast_qtrue_bias = c(-25, -34),
    forecast_pinball_mean = c(12.5, 17),
    forecast_coverage = c(0, 0),
    forecast_coverage_error = c(-0.5, -0.5),
    stringsAsFactors = FALSE
  )
  utils::write.csv(metrics, metrics_path, row.names = FALSE)

  summary_dir <- file.path(tmp, "reports", "run", "campaign", "tables")
  dir.create(summary_dir, recursive = TRUE)
  summary_path <- file.path(summary_dir, "campaign_fit_summary.csv")
  campaign <- data.frame(
    root_id = "root1",
    dataset_cell_id = "cell1",
    scenario = "fixture",
    family = "normal",
    tau = 0.5,
    fit_size = 500L,
    effective_fit_size = 500L,
    beta_prior_type = "ridge",
    inference = "vb",
    likelihood_family = "al",
    status = "SUCCESS",
    forecast_rolling_origin_path_file = rolling_path,
    forecast_lead_metrics_path = metrics_path,
    stringsAsFactors = FALSE
  )
  utils::write.csv(campaign, summary_path, row.names = FALSE)

  out_root <- file.path(tmp, "repair")
  cmd <- c(
    file.path(repo_root, "scripts", "repair_qdesn_rolling_origin_scale_exports.R"),
    "--campaign-fit-summary", summary_path,
    "--out-root", out_root,
    "--write-final-tt500", "false"
  )
  res <- system2(file.path(R.home("bin"), "Rscript"), cmd, stdout = TRUE, stderr = TRUE)
  expect_null(attr(res, "status"))

  repaired_summary_path <- list.files(file.path(out_root, "campaign_summaries"), pattern = "campaign_fit_summary_scale_repaired\\.csv$", full.names = TRUE)
  expect_length(repaired_summary_path, 1L)
  repaired_summary <- utils::read.csv(repaired_summary_path, stringsAsFactors = FALSE, check.names = FALSE)
  expect_true(file.exists(repaired_summary$forecast_rolling_origin_path_file[[1L]]))
  expect_true(file.exists(repaired_summary$forecast_lead_metrics_path[[1L]]))
  expect_true(file.exists(repaired_summary$rolling_origin_scale_repair_manifest[[1L]]))
  expect_true(file.exists(rolling_path))

  repaired_path <- utils::read.csv(repaired_summary$forecast_rolling_origin_path_file[[1L]], stringsAsFactors = FALSE, check.names = FALSE)
  center <- mean(observed$y)
  scale <- stats::sd(observed$y)
  expect_equal(repaired_path$qhat, c(0, 1) * scale + center)
  expect_equal(repaired_path$q_error, repaired_path$qhat - repaired_path$q_true)
  expect_true(all(repaired_path$lead_export_scale_status == "original_scale_repaired"))
})

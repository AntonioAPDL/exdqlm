write_synthetic_pipeline_artifact <- function(out_dir,
                                              mode = "sim",
                                              method = "vb",
                                              prior = "ridge",
                                              family = "exal") {
  dir.create(file.path(out_dir, "manifest"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(out_dir, "tables"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(out_dir, "models"), recursive = TRUE, showWarnings = FALSE)

  writeLines("SUCCESS", file.path(out_dir, "manifest", "status.txt"))
  jsonlite::write_json(
    list(
      status = "SUCCESS",
      mode = mode,
      inference_method = method,
      likelihood_family = family,
      beta_prior_type = prior,
      elapsed_seconds = 1.25
    ),
    file.path(out_dir, "manifest", "runtime_summary.json"),
    pretty = TRUE,
    auto_unbox = TRUE
  )
  jsonlite::write_json(
    list(
      pipeline = list(mode = mode),
      dataset = list(mode = mode),
      cfg = list(pipeline = list(mode = mode))
    ),
    file.path(out_dir, "manifest", "run_manifest.json"),
    pretty = TRUE,
    auto_unbox = TRUE
  )
  utils::write.csv(
    data.frame(
      created_at = as.character(Sys.time()),
      mode = mode,
      inference_method = method,
      likelihood_family = family,
      beta_prior_type = prior,
      n_quantiles = 1L,
      T_use = 20L,
      H_forecast = 5L,
      total_stage_seconds = 1.25,
      n_timed_steps = 2L,
      max_stage_tag = "fit",
      max_stage_seconds = 1,
      stringsAsFactors = FALSE
    ),
    file.path(out_dir, "tables", "timing_summary.csv"),
    row.names = FALSE
  )
  utils::write.csv(
    data.frame(
      when = as.character(Sys.time()),
      tag = c("fit", "forecast"),
      seconds = c(1, 0.25),
      stringsAsFactors = FALSE
    ),
    file.path(out_dir, "tables", "timing_breakdown.csv"),
    row.names = FALSE
  )
  utils::write.csv(
    data.frame(
      split = c("train", "forecast"),
      CRPS_mean = c(0.1, 0.2),
      PinballMean_mean = c(0.05, 0.06),
      S_mean = c(0.15, 0.26),
      stringsAsFactors = FALSE
    ),
    file.path(out_dir, "tables", "scores_summary.csv"),
    row.names = FALSE
  )
  utils::write.csv(
    data.frame(
      quantile_p = 0.25,
      rhs_trace_available = TRUE,
      collapse_flag = FALSE,
      unhealthy_flag = FALSE,
      unhealthy_reason = "",
      root_cause_context = "synthetic",
      stringsAsFactors = FALSE
    ),
    file.path(out_dir, "models", "rhs_run_summary.csv"),
    row.names = FALSE
  )
  saveRDS(
    list(
      cfg = list(
        pipeline = list(mode = mode),
        inference = list(method = method, likelihood_family = family, beta_prior = list(type = prior)),
        split = list(T_use = 20L, n_train = 15L, H_forecast = 5L),
        forecast = list(mode = "origin"),
        p_vec = 0.25
      ),
      fits_fc = list()
    ),
    file.path(out_dir, "models", "forecast_objects.rds")
  )
  invisible(out_dir)
}

test_that("pipeline summary collector reads the required artifact contract", {
  out_dir <- file.path(tempdir(), "pipeline-synthetic-artifact")
  unlink(out_dir, recursive = TRUE, force = TRUE)
  write_synthetic_pipeline_artifact(out_dir)

  summary_obj <- exdqlm:::collect_pipeline_run_summary(out_dir)

  expect_identical(summary_obj$status, "SUCCESS")
  expect_identical(summary_obj$summary$mode[[1L]], "sim")
  expect_identical(summary_obj$summary$inference_method[[1L]], "vb")
  expect_identical(summary_obj$summary$beta_prior_type[[1L]], "ridge")
  expect_equal(summary_obj$summary$forecast_CRPS_mean[[1L]], 0.2)
  expect_true(nrow(summary_obj$timing_breakdown) >= 1L)
  expect_true(nrow(summary_obj$rhs_run_summary) >= 1L)
})

test_that("compatibility entrypoint scripts are syntactically valid", {
  repo <- normalizePath(test_path("..", ".."), winslash = "/", mustWork = TRUE)
  sim_script <- file.path(repo, "scripts", "pipeline_sim_main.R")
  real_script <- file.path(repo, "scripts", "pipeline_real_main.R")

  expect_silent(parse(sim_script))
  expect_silent(parse(real_script))
  expect_true(file.exists(sim_script))
  expect_true(file.exists(real_script))
})

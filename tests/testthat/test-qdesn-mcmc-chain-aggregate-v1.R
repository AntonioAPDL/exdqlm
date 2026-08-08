test_that("chain aggregation recomputes fit, forecast, and check metrics", {
  root <- normalizePath(file.path(testthat::test_path(), "..", ".."),
                        winslash = "/", mustWork = TRUE)
  source(file.path(root, "validation", "fitforecast_v2", "R",
                   "qdesn_mcmc_chain_aggregate_v1.R"))
  fixture <- tempfile("chain-aggregate-fixture-")
  dir.create(fixture)
  make_chain <- function(id, fit_shift, forecast_shift) {
    fit <- data.frame(
      source_index = 10:12, y = c(2, 4, 6), q_true = c(1, 3, 5),
      q_pred = c(1, 3, 5) + fit_shift, effective_train = TRUE
    )
    forecast <- data.frame(
      y = c(2, 6), q_true = c(1, 5), qhat = c(1, 5) + forecast_shift,
      forecast_lead = c(1L, 2L), target_source_index = c(20L, 21L),
      origin_sequence_id = c(1L, 1L)
    )
    fit_path <- file.path(fixture, paste0("fit-", id, ".csv"))
    forecast_path <- file.path(fixture, paste0("forecast-", id, ".csv"))
    utils::write.csv(fit, fit_path, row.names = FALSE)
    utils::write.csv(forecast, forecast_path, row.names = FALSE)
    data.frame(fit_quantile_path_train_file = fit_path,
               forecast_rolling_origin_path_file = forecast_path)
  }
  chains <- rbind(make_chain(1, -1, -1), make_chain(2, 0, 0),
                  make_chain(3, 2, 2))
  result <- qdesn_chainagg_aggregate_paths(
    chains, train_start = 10L, train_end = 12L,
    forecast_start = 20L, forecast_end = 21L, max_lead = 2L, tau = 0.25
  )
  expect_equal(result$metrics$chain_count, 3L)
  expect_equal(result$metrics$fit_qtrue_rmse, 0)
  expect_equal(result$metrics$forecast_qtrue_mae_H1000, 0)
  expect_equal(result$metrics$forecast_check_loss_H1000, 0.25)
})

test_that("chain aggregation rejects a misaligned forecast lattice", {
  root <- normalizePath(file.path(testthat::test_path(), "..", ".."),
                        winslash = "/", mustWork = TRUE)
  source(file.path(root, "validation", "fitforecast_v2", "R",
                   "qdesn_mcmc_chain_aggregate_v1.R"))
  fixture <- tempfile("chain-aggregate-misaligned-")
  dir.create(fixture)
  make_files <- function(id, target) {
    fit <- data.frame(source_index = 10:11, y = 1:2, q_true = 1:2,
                      q_pred = 1:2, effective_train = TRUE)
    forecast <- data.frame(
      y = 1, q_true = 1, qhat = 1, forecast_lead = 1L,
      target_source_index = target, origin_sequence_id = 1L
    )
    fit_path <- file.path(fixture, paste0("fit-", id, ".csv"))
    forecast_path <- file.path(fixture, paste0("forecast-", id, ".csv"))
    utils::write.csv(fit, fit_path, row.names = FALSE)
    utils::write.csv(forecast, forecast_path, row.names = FALSE)
    data.frame(fit_quantile_path_train_file = fit_path,
               forecast_rolling_origin_path_file = forecast_path)
  }
  chains <- rbind(make_files(1, 20L), make_files(2, 21L))
  expect_error(qdesn_chainagg_aggregate_paths(
    chains, train_start = 10L, train_end = 11L,
    forecast_start = 20L, forecast_end = 21L, max_lead = 1L
  ), "forecast lattice keys")
})

test_that("chain aggregation audit contract is explicit and parseable", {
  root <- normalizePath(file.path(testthat::test_path(), "..", ".."),
                        winslash = "/", mustWork = TRUE)
  config_path <- file.path(root, "config", "validation",
                           "qdesn_mcmc_chain_aggregate_v1.yaml")
  script_path <- file.path(root, "validation", "fitforecast_v2", "scripts",
                           "audit_qdesn_mcmc_chain_aggregate_v1.R")
  expect_true(file.exists(config_path))
  expect_silent(parse(script_path))
  config <- yaml::read_yaml(config_path)
  expect_identical(config$estimator$id,
                   "median_of_chain_posterior_point_paths_v1")
  expect_false(config$estimator$posterior_pooling_claim)
  expect_equal(config$estimator$minimum_chains_confirmation, 5L)
  expect_false(config$selection$article_update_automatic)
})

test_that("five-chain confirmation handoff is frozen and storage-light", {
  root <- normalizePath(file.path(testthat::test_path(), "..", ".."),
                        winslash = "/", mustWork = TRUE)
  stage <- "qdesn_dynamic_fitforecast_v2_500obs_mcmc_chain_aggregate_confirm_v1"
  stub <- file.path(root, "config", "validation", stage)
  read_stage <- function(suffix) {
    read.csv(paste0(stub, suffix), check.names = FALSE)
  }
  profiles <- read_stage("_profiles.csv")
  handoff <- read_stage("_chain_handoff.csv")
  grid <- read_stage("_grid.csv")
  specs <- read_stage("_target_spec_ids.csv")
  smoke_specs <- read_stage("_smoke_target_spec_ids.csv")
  generated <- read_stage("_generated_file_manifest.csv")
  frozen <- read_stage("_frozen_input_manifest.csv")
  defaults <- yaml::read_yaml(paste0(stub, "_defaults.yaml"))

  expect_equal(nrow(profiles), 12L)
  expect_equal(nrow(grid), 12L)
  expect_equal(nrow(specs), 12L)
  expect_equal(nrow(handoff), 4L)
  expect_true(all(table(profiles$source_base_design_id) == 3L))
  expect_setequal(unique(profiles$sampler_replicate), 3:5)
  expect_true(all(handoff$expected_total_chains == 5L))
  expect_identical(unique(handoff$estimator_id),
                   "median_of_chain_posterior_point_paths_v1")
  expect_equal(nrow(smoke_specs), 2L)
  expect_setequal(smoke_specs$likelihood_family, c("al", "exal"))
  expect_equal(defaults$runtime$workers, 12L)
  expect_equal(defaults$runtime$threads, 1L)
  expect_equal(defaults$pipeline$inference$mcmc$n_burn, 5000L)
  expect_equal(defaults$pipeline$inference$mcmc$n_mcmc, 20000L)
  expect_false(defaults$pipeline$outputs$keep_draws)
  expect_false(defaults$pipeline$outputs$keep_mcmc_vb_init)
  expect_false(defaults$pipeline$outputs$save_forecast_objects)
  expect_false(defaults$pipeline$outputs$retain_full_rds_on_failure)
  expect_equal(nrow(generated), 16L)
  expect_true(all(file.exists(generated$path)))
  expect_identical(unname(tools::sha256sum(generated$path)),
                   unname(generated$sha256))
  expect_equal(nrow(frozen), 7L)
  expect_true(all(frozen$hash_match))
})

test_that("five-chain confirmation lifecycle reaches its run-root gate", {
  root <- normalizePath(file.path(testthat::test_path(), "..", ".."),
                        winslash = "/", mustWork = TRUE)
  scripts <- file.path(root, "validation", "fitforecast_v2", "scripts")
  r_files <- file.path(scripts, c(
    "materialize_qdesn_mcmc_chain_aggregate_confirm_v1.R",
    "verify_qdesn_mcmc_chain_aggregate_confirm_v1.R",
    "verify_qdesn_mcmc_chain_aggregate_confirm_v1_smoke.R",
    "healthcheck_qdesn_mcmc_chain_aggregate_confirm_v1.R",
    "closeout_qdesn_mcmc_chain_aggregate_confirm_v1.R"
  ))
  shell_files <- file.path(scripts, c(
    "run_qdesn_mcmc_chain_aggregate_confirm_v1_pipeline.sh",
    "launch_qdesn_mcmc_chain_aggregate_confirm_v1.sh"
  ))
  expect_true(all(file.exists(c(r_files, shell_files))))
  invisible(lapply(r_files, function(path) expect_silent(parse(path))))
  pipeline <- paste(readLines(shell_files[[1L]], warn = FALSE), collapse = "\n")
  health <- paste(readLines(r_files[[4L]], warn = FALSE), collapse = "\n")
  expect_match(pipeline, "WORKERS=12", fixed = TRUE)
  expect_match(pipeline, "--prepare-only", fixed = TRUE)
  expect_match(pipeline, "trace_compaction", fixed = TRUE)
  expect_match(pipeline, "storage_audit", fixed = TRUE)
  expect_match(health, "COMPLETE_CLOSED_OUT", fixed = TRUE)

  output <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"),
    c(
      "--vanilla", r_files[[5L]], "--run-tag",
      "chain-aggregate-intentionally-missing", "--output-root",
      tempfile("chain-aggregate-closeout-import-")
    ), stdout = TRUE, stderr = TRUE
  ))
  expect_false(is.null(attr(output, "status")))
  expect_match(paste(output, collapse = "\n"), "Run root does not exist",
               fixed = TRUE)
})

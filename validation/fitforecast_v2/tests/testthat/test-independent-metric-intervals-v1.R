testthat::test_that("draw-wise metric estimands match hand calculations", {
  fit_true <- rep(0, 500L)
  forecast_true <- rep(0, 1000L)
  forecast_y <- rep(c(-2, 2), 500L)
  fit_draws <- cbind(rep(1, 500L), rep(2, 500L))
  forecast_draws <- cbind(rep(1, 1000L), rep(-1, 1000L))
  out <- ffv2_metric_draws_from_paths(
    fit_draws, fit_true, forecast_draws, forecast_true, forecast_y,
    tau = 0.25, chain_id = 3L, draw_source = "fixture"
  )
  testthat::expect_equal(out$fit_rmse, c(1, 2))
  testthat::expect_equal(out$forecast_mae, c(1, 1))
  testthat::expect_equal(out$forecast_check_loss, c(1.25, 0.75))
  testthat::expect_identical(out$chain_id, rep(3L, 2L))
})

testthat::test_that("summaries are ordered and inference labels are explicit", {
  draws <- data.frame(
    chain_id = rep(1:3, each = 20),
    fit_rmse = seq(1, 2, length.out = 60),
    forecast_mae = seq(2, 3, length.out = 60),
    forecast_check_loss = seq(3, 4, length.out = 60)
  )
  mcmc <- ffv2_metric_interval_summary(draws, inference = "mcmc")
  vb <- ffv2_metric_interval_summary(draws, inference = "vb")
  testthat::expect_true(all(mcmc$cri_lower <= mcmc$posterior_median))
  testthat::expect_true(all(mcmc$posterior_median <= mcmc$cri_upper))
  testthat::expect_true(all(mcmc$posterior_mean_inside_cri))
  testthat::expect_identical(unique(mcmc$interval_label), "95pct_credible_interval")
  testthat::expect_identical(unique(vb$interval_label),
                             "approximate_95pct_credible_interval")
})

testthat::test_that("DQLM conditional-quantile adapters exclude response draws", {
  fit <- list(
    samp.theta = array(seq_len(2L * 500L * 6L), dim = c(2L, 500L, 6L)),
    model = list(FF = rbind(rep(1, 500L), rep(2, 500L)))
  )
  out <- ffv2_dqlm_conditional_quantile_draws(fit, n_draws = 4L)
  testthat::expect_equal(dim(out), c(500L, 4L))
  testthat::expect_equal(length(attr(out, "source_draw_index")), 4L)
  forecast <- list(ff = 1:30, fQ = rep(0.25, 30L))
  a <- ffv2_latent_forecast_draws(forecast, 12L, seed = 91L)
  b <- ffv2_latent_forecast_draws(forecast, 12L, seed = 91L)
  testthat::expect_identical(a, b)
  testthat::expect_equal(dim(a), c(30L, 12L))
})

testthat::test_that("the frozen v9 replay authority resolves exactly", {
  audit <- imi_v1_static_audit(repo_root)
  testthat::expect_true(all(audit$checks$pass))
  testthat::expect_equal(nrow(audit$interface), 72L)
  testthat::expect_equal(nrow(audit$metric_roles), 216L)
  testthat::expect_equal(nrow(audit$source_registry), 90L)
  testthat::expect_equal(sum(audit$source_registry$planned_chains), 198L)
  qdesn <- grepl("^qdesn_", audit$source_registry$model_variant)
  testthat::expect_false(any(audit$source_registry$request_resolution[qdesn] == "UNRESOLVED"))
})

testthat::test_that("launch and publication ownership remain lane-scoped", {
  scripts <- file.path(harness_root, "scripts", c(
    "materialize_independent_metric_intervals_v1.R",
    "orchestrate_independent_metric_intervals_v1.R",
    "run_independent_metric_intervals_v1_job.R",
    "verify_independent_metric_intervals_v1_plan.R",
    "closeout_independent_metric_intervals_v1.R",
    "run_independent_metric_intervals_v1_pipeline.sh"
  ))
  text <- paste(unlist(lapply(scripts, readLines, warn = FALSE)), collapse = "\n")
  testthat::expect_true(all(file.exists(scripts)))
  testthat::expect_false(grepl("/home/jaguir26/local/src", text, fixed = TRUE))
  testthat::expect_false(grepl("Article-Q-DESN---Version-2/main.tex", text, fixed = TRUE))
  testthat::expect_match(text, "READY_FOR_INTEGRATION", fixed = TRUE)
  testthat::expect_match(text, "IMI_V1_LAUNCH_APPROVED", fixed = TRUE)
  testthat::expect_match(text, "m0_v_collapsed_support_logit", fixed = TRUE)
})

testthat::test_that("pipeline limits numerical threads before R starts", {
  pipeline <- readLines(file.path(
    harness_root, "scripts", "run_independent_metric_intervals_v1_pipeline.sh"
  ), warn = FALSE)
  required <- c(
    "export OMP_NUM_THREADS=1",
    "export OMP_THREAD_LIMIT=1",
    "export OPENBLAS_NUM_THREADS=1",
    "export MKL_NUM_THREADS=1",
    "export BLIS_NUM_THREADS=1",
    "export RCPP_PARALLEL_NUM_THREADS=1"
  )
  testthat::expect_true(all(required %in% pipeline))
})

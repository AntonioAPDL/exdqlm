testthat::test_that("common-shift intervention separates coupling and location", {
  n_target <- 20L; n_draw <- 200L
  q_true <- seq(-1, 1, length.out = n_target)
  shifts <- seq(-2, 2, length.out = n_draw)
  q <- outer(q_true + 1, rep(1, n_draw)) + outer(rep(1, n_target), shifts)
  draws <- data.frame(chain_id = 1L, draw_id = seq_len(n_draw))
  attr(draws, "metric_dispersion_context") <- list(
    native_q = q, q_true = q_true, y = q_true, tau = 0.5
  )
  defaults <- list(metrics = list(posterior_metric_intervals = list(
    common_shift_intervention = list(enabled = TRUE, required = TRUE)
  )))
  out <- .qdesn_validation_common_shift_summary(draws, defaults)
  testthat::expect_identical(out$status, "PASS")
  effect <- out$effects[out$effects$metric == "forecast_mae", ]
  testthat::expect_lt(effect$variance_ratio[
    effect$intervention == "common_shift_removed"], 1e-10)
  testthat::expect_lt(effect$mean_ratio[
    effect$intervention == "oracle_location_corrected"], 1e-10)
})

testthat::test_that("campaign decision is cell-specific and gated", {
  effects <- expand.grid(
    replay_id = icsi_v1_sources, model_variant = c("al", "exal")[1],
    intervention = c("common_shift_removed", "oracle_location_corrected"),
    metric = c("forecast_mae", "forecast_check_loss"), chain_id = 1:3,
    stringsAsFactors = FALSE
  )
  effects$mean_ratio <- 1; effects$variance_ratio <- 1; effects$width_ratio <- 1
  effects$variance_ratio[effects$intervention == "common_shift_removed"] <- 0.5
  effects$mean_ratio[effects$intervention == "oracle_location_corrected"] <- 0.8
  result <- icsi_v1_decide(effects)
  testthat::expect_true(all(result$decision$common_mode_gate))
  testthat::expect_true(all(result$decision$location_bias_gate))
})

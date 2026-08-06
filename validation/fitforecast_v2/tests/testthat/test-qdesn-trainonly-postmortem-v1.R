testthat::test_that("lead and origin bands are stable", {
  testthat::expect_equal(as.character(qdesn_tpmv1_band_lead(c(1, 5, 6, 15, 16, 30))),
                         c("lead_01_05", "lead_01_05", "lead_06_15", "lead_06_15", "lead_16_30", "lead_16_30"))
  testthat::expect_equal(length(qdesn_tpmv1_band_origin(seq(9000, 9990, 30))), 34L)
})

testthat::test_that("paired paths compute candidate minus parent deltas", {
  base <- data.frame(forecast_origin_source_index = c(9000, 9000), forecast_lead = 1:2,
                     target_source_index = 9001:9002, qhat = 0, q_error = 0,
                     abs_q_error = c(2, 4), pinball_tau = c(1, 2))
  candidate <- base; candidate$abs_q_error <- c(1, 5); candidate$pinball_tau <- c(.5, 2.5)
  out <- qdesn_tpmv1_pair_paths(candidate, base)
  testthat::expect_equal(out$delta_abs_error, c(-1, 1))
  testthat::expect_equal(out$delta_pinball, c(-.5, .5))
})

testthat::test_that("decision gate blocks contradictory or pathological evidence", {
  bands <- data.frame(source_role = c("frozen_article", "untouched_confirmation"),
                      band_type = "overall", mae_ratio = c(1.04, .93), check_ratio = c(1.01, .99))
  exal <- data.frame(median_max_core_acf1 = .988, median_min_core_ess_per_sec = .16)
  testthat::expect_equal(qdesn_tpmv1_decide(data.frame(), bands, exal), "STOP_REASSESS_MODEL_OR_SAMPLER")
})

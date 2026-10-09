repo <- normalizePath(Sys.getenv("IRRV4_REPO", "."), mustWork = TRUE)
for (file in c("independent_qdesn_training1000_runtime_v1.R",
    "independent_qdesn_training1000_campaign_v1.R",
    "independent_qdesn_sentinel_mechanism_v1.R",
    "independent_qdesn_sentinel_mechanism_recovery_v1.R",
    "independent_qdesn_causal_adaptation_v2.R",
    "independent_qdesn_mcmc_finalist_bridge_v3.R",
    "independent_qdesn_rolling_readout_v4.R"))
  source(file.path(repo, "validation/fitforecast_v2/R", file))

candidate <- list(readout_dimension = 144L, effective_p0 = 8,
  sigma_b_source = 19.34568)
base_train <- 7001:8000

testthat::test_that("RHS calibration is dimension and sample-size aware", {
  expected <- 8 / (143 - 8) * 19.34568 / sqrt(1000)
  testthat::expect_equal(irrv4_tau_source(candidate, 1000L), expected,
    tolerance = 1e-12)
  testthat::expect_gt(irrv4_tau_source(candidate, 250L), expected)
  testthat::expect_equal(irrv4_tau_source(candidate, 250L), 2 * expected,
    tolerance = 1e-12)
})

testthat::test_that("readout policies use exact causal row bounds", {
  expanding <- irrv4_readout_contract(candidate, base_train, 8050L,
    "expanding_calibrated")
  rolling <- irrv4_readout_contract(candidate, base_train, 8050L,
    "rolling_750")
  testthat::expect_identical(c(expanding$start, expanding$end, expanding$N),
    c(7001L, 8050L, 1050L))
  testthat::expect_identical(c(rolling$start, rolling$end, rolling$N),
    c(7301L, 8050L, 750L))
  testthat::expect_lte(max(rolling$index), 8050L)
})

testthat::test_that("screen and validation origins remain internal", {
  fold_ends <- c(S1 = 8000L, S2 = 8250L, S3 = 8500L, S4 = 8750L)
  for (end in fold_ends) {
    testthat::expect_lte(max(end + irrv4_screen_offsets + 30L), 9000L)
    targets <- lapply(end + irrv4_validation_offsets,
      function(origin) seq.int(origin + 1L, origin + 30L))
    testthat::expect_equal(length(unique(unlist(targets))), 120L)
    testthat::expect_lte(max(unlist(targets)), 9000L)
  }
})

testthat::test_that("screen gate requires a new policy to beat the anchor", {
  anchor <- data.frame(median_baseline_mae_ratio = 1.04,
    baseline_mae_wins = 6L)
  better <- data.frame(median_baseline_mae_ratio = 1.03,
    baseline_mae_wins = 6L)
  tied_better <- data.frame(median_baseline_mae_ratio = 1.04,
    baseline_mae_wins = 7L)
  worse <- data.frame(median_baseline_mae_ratio = 1.05,
    baseline_mae_wins = 8L)
  testthat::expect_true(irrv4_better_than_anchor(better, anchor))
  testthat::expect_true(irrv4_better_than_anchor(tied_better, anchor))
  testthat::expect_false(irrv4_better_than_anchor(worse, anchor))
})

testthat::test_that("heterogeneous imported and local summaries bind by name", {
  old <- data.frame(metric = "forecast_mae", mean = 1, adaptation_mode = "old")
  new <- data.frame(metric = "forecast_mae", mean = 2, policy_id = "new")
  out <- irrv4_bind_rows(old, new)
  testthat::expect_identical(nrow(out), 2L)
  testthat::expect_setequal(names(out), c("metric", "mean",
    "adaptation_mode", "policy_id"))
  testthat::expect_true(is.na(out$policy_id[1L]))
  testthat::expect_true(is.na(out$adaptation_mode[2L]))
})

testthat::test_that("confirmation aggregation requires three chains per cell", {
  make <- function(chain) {
    z <- expand.grid(policy_id = "rolling_500", fold = ism1_folds,
      refit_origin = 1:4,
      metric = c("fit_rmse", "fit_check_loss", "forecast_mae",
        "forecast_rmse", "forecast_check_loss"), stringsAsFactors = FALSE)
    z$chain <- chain; z$N <- 500L; z$tau_source <- .05; z$mean <- chain; z
  }
  z <- do.call(rbind, lapply(1:3, make))
  out <- irrv4_aggregate_confirmation(z[z$chain == 1, ],
    z[z$chain > 1, ], "rolling_500")
  testthat::expect_true(all(out$mean$mean == 2))
  testthat::expect_true(all(out$spread$chain_range == 2))
  testthat::expect_error(irrv4_aggregate_confirmation(z[z$chain == 1, ],
    z[z$chain == 2, ], "rolling_500"))
})

testthat::test_that("worker freezes causal and exact-M0 contracts", {
  worker <- paste(deparse(body(irrv4_worker)), collapse = "\n")
  testthat::expect_match(worker, "cfg\\$stage")
  testthat::expect_match(worker, "cfg\\$refit_origin \\+ cfg\\$window\\$horizon <= 9000L")
  testthat::expect_match(worker, "max\\(cfg\\$window\\$train\\)")
  testthat::expect_match(worker, "max\\(cfg\\$base_train\\)")
  quantile <- paste(deparse(body(iqt12_quantile)), collapse = "\n")
  testthat::expect_match(quantile, "m0_v_collapsed_support_logit")
})

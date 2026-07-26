test_that("status-agnostic MCMC metric envelope is complete and provenance-explicit", {
  repo_root <- normalizePath(file.path(testthat::test_path(), "..", "..", "..", ".."), mustWork = TRUE)
  root <- file.path(
    repo_root, "validation", "fitforecast_v2", "promotions",
    "qdesn_dqlm_500obs_mcmc_metric_envelope_20260726"
  )
  envelope <- read.csv(
    file.path(root, "qdesn_dqlm_500obs_mcmc_metric_envelope_20260726_article_envelope.csv"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  promotions <- read.csv(
    file.path(root, "qdesn_dqlm_500obs_mcmc_metric_envelope_20260726_promotions.csv"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  expect_equal(nrow(envelope), 36L)
  expect_equal(
    nrow(unique(envelope[c("model_variant", "family", "tau", "fit_size")])),
    36L
  )
  expect_true(all(is.finite(envelope$fit_qtrue_rmse)))
  expect_true(all(is.finite(envelope$forecast_qtrue_mae_H1000)))
  expect_true(all(is.finite(envelope$forecast_check_loss_H1000)))
  expect_true(all(nzchar(envelope$fit_source_candidate_id)))
  expect_true(all(nzchar(envelope$forecast_mae_source_candidate_id)))
  expect_true(all(nzchar(envelope$forecast_check_source_candidate_id)))
  expect_true(all(nzchar(envelope$fit_source_run_tag)))
  expect_true(all(nzchar(envelope$forecast_mae_source_run_tag)))
  expect_true(all(nzchar(envelope$forecast_check_source_run_tag)))
  expect_true(all(promotions$changed_from_article_baseline == "TRUE"))

  target <- envelope[
    envelope$model_variant == "qdesn_exal_rhs_ns" &
      envelope$family == "normal" &
      abs(envelope$tau - 0.05) < 1e-12,
    ,
    drop = FALSE
  ]
  expect_equal(nrow(target), 1L)
  expect_equal(target$fit_source_candidate_id, "mcvbc_060_exal__seed_04")
  expect_equal(target$fit_qtrue_rmse, 2.48100087770012, tolerance = 1e-12)
  expect_equal(target$forecast_qtrue_mae_H1000, 2.65193399312281, tolerance = 1e-12)
  expect_equal(target$forecast_check_loss_H1000, 1.07638111743089, tolerance = 1e-12)
  expect_true(target$metric_source_mixed)
})

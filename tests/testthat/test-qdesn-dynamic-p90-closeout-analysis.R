test_that("p90 closeout manifest points to completed campaign inputs", {
  repo_root <- testthat::test_path("../../")
  manifest <- exdqlm:::`.qdesn_p90_closeout_load_manifest`(
    file.path("config", "validation", "qdesn_dynamic_p90_steepertrend_closeout_analysis_manifest.yaml"),
    repo_root = repo_root
  )

  fit_summary <- exdqlm:::`.qdesn_p90_closeout_load_fit_summary`(manifest, repo_root = repo_root)

  expect_equal(nrow(fit_summary), 144L)
  expect_setequal(unique(fit_summary$prior), c("ridge", "rhs_ns"))
  expect_true(all(fit_summary$status == "SUCCESS"))
  expect_equal(sum(fit_summary$prior == "ridge"), 72L)
  expect_equal(sum(fit_summary$prior == "rhs_ns"), 72L)
})

test_that("p90 closeout pairwise contrasts cover the intended axes", {
  repo_root <- testthat::test_path("../../")
  manifest <- exdqlm:::`.qdesn_p90_closeout_load_manifest`(
    file.path("config", "validation", "qdesn_dynamic_p90_steepertrend_closeout_analysis_manifest.yaml"),
    repo_root = repo_root
  )
  fit_summary <- exdqlm:::`.qdesn_p90_closeout_load_fit_summary`(manifest, repo_root = repo_root)

  vb_mcmc <- exdqlm:::`.qdesn_p90_closeout_pair_delta`(fit_summary, "inference")
  exal_al <- exdqlm:::`.qdesn_p90_closeout_pair_delta`(fit_summary, "model")
  rhs_ridge <- exdqlm:::`.qdesn_p90_closeout_pair_delta`(fit_summary, "prior")

  expect_equal(nrow(vb_mcmc), 72L)
  expect_equal(nrow(exal_al), 72L)
  expect_equal(nrow(rhs_ridge), 72L)
  expect_true("train_qtrue_rmse_delta_mcmc_minus_vb" %in% names(vb_mcmc))
  expect_true("train_qtrue_rmse_delta_exal_minus_al" %in% names(exal_al))
  expect_true("train_qtrue_rmse_delta_rhs_ns_minus_ridge" %in% names(rhs_ridge))
})

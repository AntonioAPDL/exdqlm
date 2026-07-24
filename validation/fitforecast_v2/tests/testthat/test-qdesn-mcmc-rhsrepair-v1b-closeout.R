test_that("Q-DESN MCMC RHS repair v1b closeout is internally consistent", {
  root <- file.path(
    ffv2_repo_root(),
    "validation", "fitforecast_v2", "promotions",
    "qdesn_tt500_mcmc_rhsrepair_v1b_closeout_20260724"
  )
  expect_true(dir.exists(root))

  signoff <- read.csv(
    file.path(root, "qdesn_tt500_mcmc_rhsrepair_v1b_signoff_summary_20260724.csv"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  expect_equal(signoff$n_roots[[1]], 130)
  expect_equal(signoff$n_root_success[[1]], 110)
  expect_equal(signoff$n_root_fail[[1]], 20)
  expect_equal(signoff$n_clean_comparison_pool[[1]], 50)
  expect_equal(signoff$n_nonpromotable[[1]], 80)
  expect_equal(signoff$n_candidate_promotions[[1]], 4)
  expect_equal(signoff$n_objective_improvements[[1]], 2)
  expect_equal(signoff$n_forecast_only_improvements[[1]], 2)

  candidates <- read.csv(
    file.path(root, "qdesn_tt500_mcmc_rhsrepair_v1b_diagnostic_candidate_promotions_20260724.csv"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  expect_equal(nrow(candidates), 4)
  expect_true(all(candidates$v1b_comparison_eligible == "TRUE"))
  expect_true(all(candidates$v1b_signoff_grade %in% c("PASS", "WARN")))
  expect_setequal(
    candidates$promotion_class,
    c(
      "diagnostic_current_best_candidate_objective_improves",
      "diagnostic_forecast_mae_improvement_only"
    )
  )

  nonpromotable <- read.csv(
    file.path(root, "qdesn_tt500_mcmc_rhsrepair_v1b_nonpromotable_roots_20260724.csv"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  failed <- read.csv(
    file.path(root, "qdesn_tt500_mcmc_rhsrepair_v1b_failed_roots_20260724.csv"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  expect_equal(nrow(nonpromotable), 80)
  expect_equal(nrow(failed), 20)
  expect_true(all(failed$nonpromotion_reason == "root_failed_or_incomplete"))

  next_screen <- read.csv(
    file.path(root, "qdesn_tt500_mcmc_rhsrepair_v1c_prelaunch_screen_plan_20260724.csv"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  expect_equal(nrow(next_screen), 10)
  expect_true(all(next_screen$launch_status == "not_launched_prepared_only"))

  storage <- read.csv(
    file.path(root, "qdesn_tt500_mcmc_rhsrepair_v1b_storage_audit_20260724.csv"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  expect_equal(nrow(storage), 0)
})

test_that("Q-DESN MCMC RHS repair v1c status-agnostic closeout is reproducible", {
  root <- file.path(
    ffv2_repo_root(),
    "validation", "fitforecast_v2", "promotions",
    "qdesn_tt500_mcmc_rhsrepair_v1c_status_agnostic_closeout_20260725"
  )
  expect_true(dir.exists(root))

  summary <- read.csv(
    file.path(root, "qdesn_tt500_mcmc_rhsrepair_v1c_status_agnostic_summary_20260725.csv"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  expect_equal(summary$n_v1c_roots[[1]], 110)
  expect_equal(summary$n_v1c_success[[1]], 110)
  expect_equal(summary$n_v1c_warn[[1]], 57)
  expect_equal(summary$n_v1c_fail[[1]], 53)
  expect_equal(summary$n_metric_promotions[[1]], 5)
  expect_equal(summary$n_objective_promotions[[1]], 3)
  expect_equal(summary$n_all_primary_promotions[[1]], 0)
  expect_equal(summary$n_new_same_variant_winners_from_v1c[[1]], 3)
  expect_equal(summary$n_new_global_cell_winners_from_v1c[[1]], 0)
  expect_equal(summary$n_storage_heavy_or_binary[[1]], 0)

  metrics <- read.csv(
    file.path(root, "qdesn_tt500_mcmc_rhsrepair_v1c_metric_promotions_status_agnostic_20260725.csv"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  expect_equal(nrow(metrics), 5)
  expect_true(any(metrics$signoff_grade_v1c == "FAIL"))
  expect_true(all(metrics$status_agnostic_promote == "TRUE"))
  expect_setequal(
    metrics$promotion_class,
    c("status_agnostic_objective_improved", "status_agnostic_metric_only_improved")
  )
  expect_true(all(
    metrics$objective_improved |
      metrics$fit_rmse_improved |
      metrics$forecast_mae_improved |
      metrics$forecast_check_improved
  ))

  objective <- read.csv(
    file.path(root, "qdesn_tt500_mcmc_rhsrepair_v1c_objective_promotions_status_agnostic_20260725.csv"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  expect_equal(nrow(objective), 3)
  expect_true(all(objective$objective_delta < 0))

  same_variant <- read.csv(
    file.path(root, "qdesn_dqlm_500obs_mcmc_status_agnostic_same_variant_winners_20260725.csv"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  same_v1c <- same_variant[same_variant$status_agnostic_selected_from_v1c == "TRUE", , drop = FALSE]
  expect_equal(nrow(same_v1c), 3)
  expect_setequal(
    same_v1c$candidate_id,
    c(
      "mcrv1c_gm005x_a_current_anchor",
      "mcrv1c_lp050a_b_d1_mem12_tau1e4_confirm",
      "mcrv1c_lp050x_b_d1_mem12_tau1e4_confirm"
    )
  )

  cell_winners <- read.csv(
    file.path(root, "qdesn_dqlm_500obs_mcmc_status_agnostic_cell_winners_20260725.csv"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  expect_equal(nrow(cell_winners), 9)
  expect_equal(sum(cell_winners$status_agnostic_selected_from_v1c == "TRUE"), 0)

  target <- read.csv(
    file.path(root, "qdesn_tt500_mcmc_rhsrepair_v1c_targeted_followup_plan_20260725.csv"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  expect_equal(nrow(target), 15)
  expect_true(all(target$launch_status == "not_launched_prepared_only"))
  expect_true("mcmc_mixing_confirmation_for_metric_winner" %in% target$proposed_followup_family)

  storage <- read.csv(
    file.path(root, "qdesn_tt500_mcmc_rhsrepair_v1c_storage_audit_20260725.csv"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  expect_equal(nrow(storage), 0)

  manifest <- jsonlite::read_json(
    file.path(root, "qdesn_tt500_mcmc_rhsrepair_v1c_status_agnostic_manifest_20260725.json")
  )
  expect_equal(manifest$status_policy, "status_agnostic_metric_promotion_requested_by_user")
  expect_match(manifest$metric_promotion_rule, "improves at least one")
})

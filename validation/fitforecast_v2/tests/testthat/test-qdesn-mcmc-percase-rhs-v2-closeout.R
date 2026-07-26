test_that("Q-DESN MCMC per-case RHS v2 closeout is complete and reproducible", {
  root <- ffv2_repo_root()
  promotion_root <- file.path(
    root, "validation", "fitforecast_v2", "promotions",
    "qdesn_tt500_mcmc_percase_rhs_v2_closeout_20260726"
  )
  prefix <- "qdesn_tt500_mcmc_percase_rhs_v2_closeout_20260726"

  summary <- read.csv(
    file.path(promotion_root, paste0(prefix, "_summary.csv")),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  expect_equal(summary$n_planned, 90)
  expect_equal(summary$n_success, 90)
  expect_equal(summary$n_pass, 17)
  expect_equal(summary$n_warn, 44)
  expect_equal(summary$n_fail, 29)
  expect_equal(summary$n_comparison_eligible, 61)
  expect_equal(summary$n_all_primary_candidate_rows, 12)
  expect_equal(summary$n_all_primary_eligible_cells, 5)
  expect_equal(summary$n_current_ledger_promotions, 9)
  expect_equal(summary$n_targeted_confirmations, 1)
  expect_equal(summary$n_heavy_binary_artifacts, 0)
  expect_false(as.logical(summary$article_update_ready))

  candidates <- read.csv(
    file.path(promotion_root, paste0(prefix, "_all_candidates.csv")),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  expect_equal(nrow(candidates), 90)
  expect_equal(length(unique(paste(
    candidates$family, candidates$tau, candidates$likelihood_target
  ))), 18)
  expect_true(all(is.finite(candidates$forecast_qtrue_mae_H1000)))
  expect_true(all(is.finite(candidates$forecast_check_loss_H1000)))
  expect_true(all(grepl(
    "forecast_horizon_summary.csv$",
    candidates$forecast_horizon_summary_path
  )))

  eligible <- read.csv(
    file.path(promotion_root, paste0(prefix, "_eligible_cell_winners.csv")),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  expect_equal(nrow(eligible), 14)
  expect_true(all(eligible$signoff_grade %in% c("PASS", "WARN")))

  promotions <- read.csv(
    file.path(promotion_root, paste0(prefix, "_current_ledger_promotions.csv")),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  expect_equal(nrow(promotions), 9)
  expect_true(all(as.logical(promotions$promote_over_current)))
  expect_setequal(
    unique(promotions$promotion_rule),
    c(
      "replace_failed_current_with_eligible_near_equivalent",
      "replace_current_on_material_minimax_improvement"
    )
  )

  target <- read.csv(
    file.path(promotion_root, paste0(prefix, "_targeted_confirmation_plan.csv")),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  expect_equal(nrow(target), 1)
  expect_equal(target$family, "normal")
  expect_equal(target$tau, 0.05)
  expect_equal(target$likelihood_target, "exal")
  expect_equal(target$screening_profile_id, "mcvbc_060_exal")
  expect_equal(target$signoff_grade, "FAIL")
  expect_true(as.logical(target$all_primary_better_than_dqlm))
  expect_equal(target$required_seed_reps, 4)
  expect_equal(target$launch_status, "prepared_not_launched")

  storage <- read.csv(
    file.path(promotion_root, paste0(prefix, "_storage_audit.csv")),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  expect_equal(nrow(storage), 0)

  manifest <- jsonlite::read_json(
    file.path(promotion_root, paste0(prefix, "_manifest.json"))
  )
  expect_equal(manifest$source_run$run_tag,
               "qdesn-tt500-mcmc-percase-rhs-v2-full-20260725__git-7df241c")
  expect_equal(manifest$article_gate,
               "closed_pending_targeted_normal_0.05_exAL_multiseed_confirmation")
})

test_that("Normal 0.05 exAL multiseed confirmation is narrowly gated", {
  root <- ffv2_repo_root()
  stub <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_normal005_exal_multiseed_v1"
  config_root <- file.path(root, "config", "validation")
  path <- function(suffix) file.path(config_root, paste0(stub, suffix))

  profiles <- read.csv(path("_profiles.csv"), check.names = FALSE,
                       stringsAsFactors = FALSE)
  assignments <- read.csv(path("_cell_assignments.csv"), check.names = FALSE,
                          stringsAsFactors = FALSE)
  grid <- read.csv(path("_grid.csv"), check.names = FALSE,
                   stringsAsFactors = FALSE)
  specs <- read.csv(path("_target_spec_ids.csv"), check.names = FALSE,
                    stringsAsFactors = FALSE)
  defaults <- yaml::read_yaml(path("_defaults.yaml"))
  manifest <- jsonlite::read_json(path("_materialization_manifest.json"))

  expect_equal(nrow(profiles), 1)
  expect_equal(nrow(assignments), 1)
  expect_equal(nrow(grid), 1)
  expect_equal(nrow(specs), 1)
  expect_equal(profiles$screening_profile_id, "mcvbc_060_exal")
  expect_equal(grid$source_family, "normal")
  expect_equal(grid$tau, 0.05)
  expect_equal(assignments$likelihood_target, "exal")
  expect_equal(specs$likelihood_target, "exal")
  expect_match(specs$spec_id, "__normal__0p05__.*__mcmc__exal__")

  expect_true(isTRUE(defaults$multiseed$enabled))
  expect_equal(defaults$multiseed$mcmc_seed_reps, 4)
  expect_equal(defaults$multiseed$parallel_seed_workers, 4)
  expect_equal(defaults$multiseed$selection_metric, "train_qtrue_rmse")
  expect_true(isTRUE(defaults$multiseed$prune_nonwinning_heavy_outputs))
  expect_equal(defaults$study_contract$budget$mcmc_n_burn, 5000)
  expect_equal(defaults$study_contract$budget$mcmc_n_mcmc, 20000)
  expect_true(isTRUE(defaults$pipeline$inference$mcmc$init_from_vb))
  expect_false(isTRUE(defaults$pipeline$outputs$keep_draws))
  expect_false(isTRUE(defaults$pipeline$outputs$save_forecast_objects))
  expect_false(isTRUE(defaults$pipeline$outputs$retain_full_rds_on_failure))
  expect_equal(manifest$launch_status, "prepared_not_launched")

  text <- paste(capture.output(str(list(defaults, profiles, assignments, grid))),
                collapse = "\n")
  stale_root <- paste0("/home/jaguir26", "/local/src")
  expect_false(grepl(stale_root, text, fixed = TRUE))
})

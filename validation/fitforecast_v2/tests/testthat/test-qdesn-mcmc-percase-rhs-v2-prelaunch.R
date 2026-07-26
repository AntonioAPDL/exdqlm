test_that("Q-DESN MCMC per-case RHS v2 handoff is per-cell and launch-safe", {
  root <- ffv2_repo_root()
  stub <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_percase_rhs_v2"
  promo_root <- file.path(
    root,
    "validation", "fitforecast_v2", "promotions",
    "qdesn_tt500_mcmc_percase_rhs_v2_prelaunch_20260725"
  )

  profiles_path <- file.path(root, "config", "validation", paste0(stub, "_profiles.csv"))
  assignments_path <- file.path(root, "config", "validation", paste0(stub, "_cell_assignments.csv"))
  defaults_path <- file.path(root, "config", "validation", paste0(stub, "_defaults.yaml"))
  grid_path <- file.path(root, "config", "validation", paste0(stub, "_grid.csv"))
  target_specs_path <- file.path(root, "config", "validation", paste0(stub, "_target_spec_ids.csv"))
  manifest_path <- file.path(root, "config", "validation", paste0(stub, "_materialization_manifest.json"))

  expect_true(all(file.exists(c(
    profiles_path, assignments_path, defaults_path, grid_path,
    target_specs_path, manifest_path
  ))))
  expect_true(dir.exists(promo_root))

  profiles <- read.csv(profiles_path, check.names = FALSE, stringsAsFactors = FALSE)
  assignments <- read.csv(assignments_path, check.names = FALSE, stringsAsFactors = FALSE)
  grid <- read.csv(grid_path, check.names = FALSE, stringsAsFactors = FALSE)
  target_specs <- read.csv(target_specs_path, check.names = FALSE, stringsAsFactors = FALSE)
  defaults <- yaml::read_yaml(defaults_path)
  manifest <- jsonlite::read_json(manifest_path)

  expect_equal(nrow(target_specs), 90)
  expect_equal(length(unique(target_specs$spec_id)), 90)
  expect_equal(nrow(assignments), 90)
  expect_equal(nrow(grid), 90)
  expect_equal(nrow(profiles), 72)
  expect_equal(as.integer(manifest$counts$target_mcmc_atomic_specs), 90)
  expect_equal(as.integer(manifest$counts$cell_likelihoods), 18)

  cell_keys <- paste(target_specs$family.x, target_specs$tau.x, target_specs$likelihood_target, sep = "|")
  expect_equal(length(unique(cell_keys)), 18)
  expect_true(all(table(cell_keys) == 5))
  expect_setequal(sort(unique(as.character(target_specs$family.x))), c("gausmix", "laplace", "normal"))
  expect_setequal(sort(unique(as.numeric(target_specs$tau.x))), c(0.05, 0.25, 0.5))
  expect_setequal(sort(unique(as.character(target_specs$likelihood_target))), c("al", "exal"))
  expect_setequal(
    sort(unique(as.character(target_specs$candidate_source))),
    c("case_targeted_v51_vb", "historical_all_primary_vb", "qvbm1_mechanism_first_vb")
  )

  expect_equal(as.integer(defaults$study_contract$budget$mcmc_n_burn), 5000)
  expect_equal(as.integer(defaults$study_contract$budget$mcmc_n_mcmc), 20000)
  expect_equal(as.integer(defaults$pipeline$inference$mcmc$progress_every), 50)
  expect_true(isTRUE(defaults$pipeline$inference$mcmc$init_from_vb))
  expect_true(isTRUE(defaults$study_contract$mcmc$require_init_from_vb))
  expect_false(isTRUE(defaults$pipeline$outputs$keep_draws))
  expect_false(isTRUE(defaults$pipeline$outputs$save_forecast_objects))
  expect_false(isTRUE(defaults$pipeline$outputs$retain_full_rds_on_failure))

  ledger_path <- file.path(
    promo_root,
    "qdesn_tt500_mcmc_percase_rhs_v2_current_percase_ledger_20260725.csv"
  )
  plan_path <- file.path(
    promo_root,
    "qdesn_tt500_mcmc_percase_rhs_v2_prelaunch_plan_20260725.csv"
  )
  inventory_path <- file.path(
    promo_root,
    "qdesn_tt500_mcmc_percase_rhs_v2_candidate_inventory_20260725.csv"
  )
  summary_path <- file.path(
    promo_root,
    "qdesn_tt500_mcmc_percase_rhs_v2_prelaunch_summary_20260725.csv"
  )
  expect_true(all(file.exists(c(ledger_path, plan_path, inventory_path, summary_path))))

  ledger <- read.csv(ledger_path, check.names = FALSE, stringsAsFactors = FALSE)
  plan <- read.csv(plan_path, check.names = FALSE, stringsAsFactors = FALSE)
  inventory <- read.csv(inventory_path, check.names = FALSE, stringsAsFactors = FALSE)
  summary <- read.csv(summary_path, check.names = FALSE, stringsAsFactors = FALSE)

  expect_equal(nrow(ledger), 18)
  expect_equal(nrow(plan), 18)
  expect_equal(nrow(inventory), 90)
  expect_equal(sum(plan$n_mcmc_candidate_specs), 90)
  expect_true(all(plan$launch_status == "not_launched_prepared_for_mcmc_confirmation"))
  expect_true(any(plan$action == "tier_a_diagnostic_risk_confirmation"))
  expect_true(any(plan$action == "tier_b_forecast_repair_confirmation"))
  expect_true(any(plan$action == "freeze_or_light_confirm"))
  expect_equal(as.integer(summary$n_current_percase_cells), 18)
  expect_equal(as.integer(summary$n_mcmc_target_specs), 90)
  expect_equal(as.integer(summary$n_cell_likelihoods), 18)
  expect_false(isTRUE(summary$keep_draws[[1]]))
  expect_false(isTRUE(summary$save_forecast_objects[[1]]))
  expect_false(isTRUE(summary$retain_full_rds_on_failure[[1]]))

  path_text <- paste(capture.output(str(list(
    profiles_path = profiles_path,
    assignments_path = assignments_path,
    defaults_path = defaults_path,
    target_specs_path = target_specs_path,
    promotion_root = promo_root,
    defaults = defaults
  ))), collapse = "\n")
  stale_home_root <- paste0("/home/jaguir26", "/local/src")
  expect_false(grepl(stale_home_root, path_text, fixed = TRUE))
})

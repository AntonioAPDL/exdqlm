test_that("Q-DESN MCMC metric-gap v3 is per-cell, staged, and storage-light", {
  root <- ffv2_repo_root()
  stub <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v3"
  promo_root <- file.path(
    root,
    "validation", "fitforecast_v2", "promotions",
    "qdesn_tt500_mcmc_metricgap_v3_prelaunch_20260726"
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

  expect_equal(nrow(profiles), 80)
  expect_equal(nrow(assignments), 80)
  expect_equal(nrow(grid), 80)
  expect_equal(nrow(target_specs), 80)
  expect_equal(length(unique(profiles$screening_profile_id)), 80)
  expect_equal(length(unique(target_specs$spec_id)), 80)

  cell_keys <- paste(
    assignments$family,
    sprintf("%.8f", assignments$tau),
    assignments$likelihood_target,
    sep = "|"
  )
  expect_equal(length(unique(cell_keys)), 16)
  expect_true(all(table(cell_keys) == 5))
  expect_setequal(sort(unique(assignments$family)), c("gausmix", "laplace", "normal"))
  expect_setequal(sort(unique(assignments$tau)), c(0.05, 0.25, 0.5))
  expect_setequal(sort(unique(assignments$likelihood_target)), c("al", "exal"))

  resolved <- paste(c("laplace", "laplace"), c("0.50000000", "0.50000000"), c("al", "exal"), sep = "|")
  expect_false(any(resolved %in% cell_keys))
  expect_true(all(assignments$launch_status == "prepared_not_launched"))
  expect_true(all(profiles$p_over_n_tt500 <= 0.5))
  expect_true(all(profiles$target_cells != ""))

  role_by_cell <- split(profiles$profile_role, profiles$target_cells)
  expect_true(all(vapply(role_by_cell, function(x) {
    sum(x == "metric_source_anchor") == 1L && length(x) == 5L
  }, logical(1L))))

  expect_equal(as.integer(defaults$study_contract$budget$mcmc_n_burn), 2000)
  expect_equal(as.integer(defaults$study_contract$budget$mcmc_n_mcmc), 8000)
  expect_equal(as.integer(defaults$study_contract$confirmation_budget$mcmc_n_burn), 5000)
  expect_equal(as.integer(defaults$study_contract$confirmation_budget$mcmc_n_mcmc), 20000)
  expect_true(isTRUE(defaults$study_contract$confirmation_budget$required_before_article_promotion))
  expect_equal(defaults$study_contract$screening_policy$unit, "family_tau_likelihood")
  expect_equal(defaults$study_contract$screening_policy$launch_status, "prepared_not_launched")

  expect_equal(as.integer(defaults$pipeline$inference$mcmc$progress_every), 50)
  expect_true(isTRUE(defaults$pipeline$inference$mcmc$init_from_vb))
  expect_false(isTRUE(defaults$pipeline$outputs$keep_draws))
  expect_false(isTRUE(defaults$pipeline$outputs$keep_mcmc_vb_init))
  expect_false(isTRUE(defaults$pipeline$outputs$save_forecast_objects))
  expect_false(isTRUE(defaults$pipeline$outputs$retain_full_rds_on_failure))

  expect_equal(as.integer(defaults$source_materialization$train_end_source_index), 9000)
  expect_equal(as.integer(defaults$source_materialization$forecast_origin_source_index), 9000)
  expect_equal(as.integer(defaults$source_materialization$forecast_horizon), 1000)
  expect_equal(as.integer(defaults$metrics$forecast_source_indices), c(9001, 10000))
  expect_equal(as.integer(defaults$metrics$rolling_origin$max_lead_configured), 30)
  expect_equal(as.integer(defaults$metrics$rolling_origin$origin_stride), 30)

  expect_equal(manifest$launch_status, "prepared_not_launched")
  expect_equal(as.integer(manifest$counts$resolved_cells_frozen), 2)
  expect_equal(as.integer(manifest$counts$unresolved_cells), 16)
  expect_equal(as.integer(manifest$counts$candidates_per_cell), 5)
  expect_equal(as.integer(manifest$counts$target_mcmc_atomic_specs), 80)

  promotion_files <- list.files(promo_root, recursive = TRUE, full.names = TRUE)
  forbidden <- promotion_files[grepl("[.](rds|rda|RData)$", promotion_files, ignore.case = TRUE)]
  expect_length(forbidden, 0)

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

test_that("Q-DESN MCMC RHS repair v1c materialization is launch-safe", {
  root <- ffv2_repo_root()
  stub <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_rhs_targeted_repair_v1c"

  profiles_path <- file.path(root, "config", "validation", paste0(stub, "_profiles.csv"))
  assignments_path <- file.path(root, "config", "validation", paste0(stub, "_cell_assignments.csv"))
  grid_path <- file.path(root, "config", "validation", paste0(stub, "_grid.csv"))
  target_specs_path <- file.path(root, "config", "validation", paste0(stub, "_target_spec_ids.csv"))
  defaults_path <- file.path(root, "config", "validation", paste0(stub, "_defaults.yaml"))
  manifest_path <- file.path(root, "config", "validation", paste0(stub, "_materialization_manifest.json"))

  expect_true(all(file.exists(c(
    profiles_path, assignments_path, grid_path, target_specs_path,
    defaults_path, manifest_path
  ))))

  profiles <- read.csv(profiles_path, check.names = FALSE, stringsAsFactors = FALSE)
  assignments <- read.csv(assignments_path, check.names = FALSE, stringsAsFactors = FALSE)
  grid <- read.csv(grid_path, check.names = FALSE, stringsAsFactors = FALSE)
  target_specs <- read.csv(target_specs_path, check.names = FALSE, stringsAsFactors = FALSE)
  defaults <- yaml::read_yaml(defaults_path)
  manifest <- jsonlite::read_json(manifest_path)

  expect_equal(nrow(profiles), 110)
  expect_equal(nrow(assignments), 110)
  expect_equal(nrow(grid), 110)
  expect_equal(nrow(target_specs), 110)
  expect_equal(length(unique(assignments$root_id)), 110)
  expect_equal(length(unique(target_specs$spec_id)), 110)

  cell_keys <- paste(assignments$family, assignments$tau, assignments$likelihood_target, sep = "|")
  expect_equal(length(unique(cell_keys)), 10)
  expect_true(all(table(cell_keys) == 11))

  new_arm <- !grepl("a_current_anchor", profiles$screening_profile_id, fixed = TRUE)
  expect_true(all(profiles$rhs_tau0[new_arm] >= 1e-4))
  expect_lte(max(profiles$m), 90)
  expect_true(all(grepl("^mcrv1c_", profiles$screening_profile_id)))
  expect_true(all(grepl("mcmc_rhs_targeted_repair_v1c", profiles$screening_stage)))

  smoke_profiles <- as.character(unlist(defaults$smoke$screening_profile_ids, use.names = FALSE))
  expect_equal(length(smoke_profiles), 1)
  expect_false(grepl("a_current_anchor", smoke_profiles, fixed = TRUE))
  smoke_row <- assignments[assignments$screening_profile_id %in% smoke_profiles, , drop = FALSE]
  expect_equal(nrow(smoke_row), 1)
  expect_true(smoke_row$family %in% c("gausmix", "normal"))
  expect_equal(as.numeric(smoke_row$tau), 0.25)
  expect_equal(smoke_row$likelihood_target, "exal")

  expect_equal(as.integer(defaults$study_contract$budget$mcmc_n_burn), 5000)
  expect_equal(as.integer(defaults$study_contract$budget$mcmc_n_mcmc), 20000)
  expect_equal(as.integer(defaults$pipeline$inference$mcmc$progress_every), 50)
  expect_true(isTRUE(defaults$pipeline$inference$mcmc$init_from_vb))
  expect_true(isTRUE(defaults$study_contract$mcmc$require_init_from_vb))
  expect_false(isTRUE(defaults$pipeline$outputs$keep_draws))
  expect_false(isTRUE(defaults$pipeline$outputs$save_forecast_objects))

  expect_equal(as.integer(manifest$counts$selected_roots), 110)
  expect_equal(as.integer(manifest$counts$target_mcmc_atomic_specs), 110)
  expect_equal(as.character(manifest$stage_file), stub)

  path_text <- paste(capture.output(str(list(
    profiles = profiles_path,
    assignments = assignments_path,
    grid = grid_path,
    target_specs = target_specs_path,
    defaults = defaults
  ))), collapse = "\n")
  expect_false(grepl("/home/jaguir26/local/src", path_text, fixed = TRUE))
})

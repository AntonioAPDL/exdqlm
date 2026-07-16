qdesn_mcmc_vbcand_path <- function(...) {
  root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  file.path(root, ...)
}

test_that("TT500 MCMC VB-candidate full confirmation materialization is scoped and MCMC-ready", {
  skip_if_not_installed("jsonlite")

  stub <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_candidate_full_confirmation"
  defaults_path <- qdesn_mcmc_vbcand_path("config", "validation", paste0(stub, "_defaults.yaml"))
  grid_path <- qdesn_mcmc_vbcand_path("config", "validation", paste0(stub, "_grid.csv"))
  profiles_path <- qdesn_mcmc_vbcand_path("config", "validation", paste0(stub, "_profiles.csv"))
  assignments_path <- qdesn_mcmc_vbcand_path("config", "validation", paste0(stub, "_cell_assignments.csv"))
  target_specs_path <- qdesn_mcmc_vbcand_path("config", "validation", paste0(stub, "_target_spec_ids.csv"))
  manifest_path <- qdesn_mcmc_vbcand_path("config", "validation", paste0(stub, "_materialization_manifest.json"))

  expect_true(file.exists(defaults_path))
  expect_true(file.exists(grid_path))
  expect_true(file.exists(profiles_path))
  expect_true(file.exists(assignments_path))
  expect_true(file.exists(target_specs_path))
  expect_true(file.exists(manifest_path))

  defaults <- yaml::read_yaml(defaults_path)
  grid <- utils::read.csv(grid_path, stringsAsFactors = FALSE, check.names = FALSE)
  profiles <- utils::read.csv(profiles_path, stringsAsFactors = FALSE, check.names = FALSE)
  assignments <- utils::read.csv(assignments_path, stringsAsFactors = FALSE, check.names = FALSE)
  target_specs <- utils::read.csv(target_specs_path, stringsAsFactors = FALSE, check.names = FALSE)
  manifest <- jsonlite::fromJSON(manifest_path, simplifyVector = FALSE)

  expect_gt(nrow(assignments), 0L)
  expect_gt(nrow(profiles), 0L)
  expect_gt(nrow(grid), 0L)
  expect_equal(nrow(target_specs), nrow(assignments))
  expect_equal(length(unique(as.character(target_specs$spec_id))), nrow(target_specs))

  expect_equal(sort(unique(as.character(assignments$family))), c("gausmix", "laplace", "normal"))
  expect_equal(sort(unique(as.numeric(assignments$tau))), c(0.05, 0.25))
  expect_equal(sort(as.numeric(unlist(defaults$source_materialization$taus, use.names = FALSE))), c(0.05, 0.25))
  expect_equal(sort(as.numeric(unlist(defaults$reference_contract$taus, use.names = FALSE))), c(0.05, 0.25))
  expect_equal(as.integer(defaults$reference_contract$expected_unique_dataset_cells), 6L)
  expect_equal(as.integer(defaults$screening_profiles$canonical_dataset_cell_count), 6L)
  expect_equal(sort(unique(as.character(assignments$likelihood_target))), c("al", "exal"))
  expect_true(all(as.character(grid$beta_prior_type) == "rhs_ns"))
  expect_true(all(as.character(target_specs$method) == "mcmc"))
  expect_true(all(as.character(target_specs$prior) == "rhs_ns"))
  expect_true(all(as.character(target_specs$likelihood_target) %in% c("al", "exal")))

  per_cell_lik <- as.data.frame(table(
    family = assignments$family,
    tau = sprintf("%.2f", as.numeric(assignments$tau)),
    likelihood = assignments$likelihood_target
  ), stringsAsFactors = FALSE)
  per_cell_lik <- per_cell_lik[per_cell_lik$Freq > 0L, , drop = FALSE]
  expect_lte(max(per_cell_lik$Freq), 7L)
  expect_equal(nrow(per_cell_lik), 12L)

  expect_identical(as.character(defaults$execution$methods), "mcmc")
  expect_equal(sort(as.character(unlist(defaults$execution$likelihood_families, use.names = FALSE))), c("al", "exal"))
  expect_equal(length(unlist(defaults$execution$allowed_fit_spec_ids, use.names = FALSE)), nrow(target_specs))
  expect_equal(as.integer(defaults$study_contract$budget$mcmc_n_burn), 5000L)
  expect_equal(as.integer(defaults$study_contract$budget$mcmc_n_mcmc), 20000L)
  expect_true(isTRUE(defaults$study_contract$mcmc$require_init_from_vb))
  expect_true(isTRUE(defaults$pipeline$inference$mcmc$init_from_vb))
  expect_equal(as.integer(defaults$pipeline$inference$mcmc$progress_every), 50L)
  expect_false(isTRUE(defaults$pipeline$outputs$keep_draws))
  expect_false(isTRUE(defaults$pipeline$outputs$save_forecast_objects))
  expect_true(isTRUE(defaults$pipeline$outputs$save_compact_fit_paths))

  expect_equal(manifest$counts$target_mcmc_atomic_specs, nrow(target_specs))
  expect_equal(manifest$counts$selected_candidate_assignments, nrow(assignments))
  expect_true(any(assignments$candidate_source == "qvbm1_mechanism_first_vb"))
  expect_true(any(assignments$candidate_source == "historical_all_primary_vb"))
  expect_true(any(assignments$candidate_source == "case_targeted_v51_vb"))
  expect_true(any(assignments$candidate_source == "qvbm3_lowtau_capacity_vb"))
})

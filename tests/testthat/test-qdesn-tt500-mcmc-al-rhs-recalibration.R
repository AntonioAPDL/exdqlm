qdesn_mcmc_alrhs_repo_path <- function(...) {
  root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  file.path(root, ...)
}

test_that("TT500 MCMC AL RHS recalibration config bundle is narrow and article-facing", {
  stub <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_al_rhs_recalibration"
  defaults_path <- qdesn_mcmc_alrhs_repo_path("config", "validation", paste0(stub, "_defaults.yaml"))
  grid_path <- qdesn_mcmc_alrhs_repo_path("config", "validation", paste0(stub, "_grid.csv"))
  winners_path <- qdesn_mcmc_alrhs_repo_path("config", "validation", paste0(stub, "_winners.csv"))
  assignments_path <- qdesn_mcmc_alrhs_repo_path("config", "validation", paste0(stub, "_cell_assignments.csv"))
  manifest_path <- qdesn_mcmc_alrhs_repo_path("config", "validation", paste0(stub, "_materialization_manifest.json"))

  expect_true(file.exists(defaults_path))
  expect_true(file.exists(grid_path))
  expect_true(file.exists(winners_path))
  expect_true(file.exists(assignments_path))
  expect_true(file.exists(manifest_path))

  defaults <- yaml::read_yaml(defaults_path)
  grid <- utils::read.csv(grid_path, stringsAsFactors = FALSE, check.names = FALSE)
  winners <- utils::read.csv(winners_path, stringsAsFactors = FALSE, check.names = FALSE)
  assignments <- utils::read.csv(assignments_path, stringsAsFactors = FALSE, check.names = FALSE)

  expect_equal(nrow(winners), 9L)
  expect_equal(nrow(grid), 9L)
  expect_equal(nrow(assignments), 9L)
  expect_equal(sort(unique(as.character(grid$source_family))), c("gausmix", "laplace", "normal"))
  expect_equal(sort(unique(as.numeric(grid$tau))), c(0.05, 0.25, 0.5))
  expect_true(all(as.character(grid$beta_prior_type) == "rhs_ns"))
  expect_true(all(as.character(grid$screening_profile_id) %in% as.character(winners$screening_profile_id)))
  expect_false(any(as.numeric(winners$rhs_tau0) == 3e-05, na.rm = TRUE))

  expect_identical(as.character(defaults$execution$methods), "mcmc")
  expect_identical(as.character(defaults$execution$likelihood_families), "al")
  expect_equal(as.integer(defaults$reference_contract$expected_qdesn_roots), 54L)
  expect_equal(as.integer(defaults$reference_contract$expected_selected_qdesn_roots), 9L)
  expect_equal(as.integer(defaults$screening_profiles$canonical_profile_count), 6L)
  expect_equal(as.integer(defaults$screening_profiles$canonical_qdesn_root_count), 54L)
  expect_equal(as.integer(defaults$screening_profiles$selected_assignment_root_count), 9L)
  expect_equal(as.integer(defaults$study_contract$budget$mcmc_n_burn), 5000L)
  expect_equal(as.integer(defaults$study_contract$budget$mcmc_n_mcmc), 20000L)
  expect_equal(as.integer(defaults$pipeline$inference$mcmc$progress_every), 50L)
  expect_true(isTRUE(defaults$pipeline$inference$mcmc$init_from_vb))
  expect_true(isFALSE(defaults$multiseed$enabled))
  expect_true(isFALSE(defaults$pipeline$outputs$keep_draws))
  expect_true(isFALSE(defaults$pipeline$outputs$save_forecast_objects))
  expect_true(isTRUE(defaults$pipeline$outputs$save_compact_fit_paths))
})

test_that("TT500 MCMC AL RHS recalibration roots exactly match recalibrated VB winners", {
  stub <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_al_rhs_recalibration"
  winners <- utils::read.csv(
    qdesn_mcmc_alrhs_repo_path("config", "validation", paste0(stub, "_winners.csv")),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  promotion <- utils::read.csv(
    qdesn_mcmc_alrhs_repo_path(
      "validation", "fitforecast_v2", "promotions",
      "qdesn_tt500_al_rhs_recalibrated_candidate_20260701",
      "qdesn_tt500_al_rhs_recalibrated_candidate_20260701_summary.csv"
    ),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  key <- paste(winners$family, sprintf("%.8f", as.numeric(winners$tau)), sep = "\r")
  promo_key <- paste(promotion$family, sprintf("%.8f", as.numeric(promotion$tau)), sep = "\r")

  expect_equal(sort(key), sort(promo_key))
  winners <- winners[match(promo_key, key), , drop = FALSE]
  expect_equal(as.character(winners$screening_profile_id), as.character(promotion$screening_profile_id))
  expect_equal(as.character(winners$model_key), rep("qdesn_al_rhs_ns", 9L))
  expect_equal(as.character(winners$inference), rep("vb", 9L))
  expect_equal(as.character(winners$signoff_grade), rep("PASS", 9L))
})

test_that("TT500 MCMC AL RHS audit resolves mcmc_al artifact directories", {
  tmp <- tempfile("qdesn_mcmc_alrhs_audit_")
  results_root <- file.path(tmp, "results", "campaign", "tag", "stamp")
  root_dir <- file.path(results_root, "roots", "root_mcmc_al_success")
  method_dir <- file.path(root_dir, "fits", "mcmc_al")
  dir.create(file.path(method_dir, "tables"), recursive = TRUE)
  dir.create(file.path(method_dir, "manifest"), recursive = TRUE)
  dir.create(file.path(root_dir, "manifest"), recursive = TRUE)
  writeLines("SUCCESS", file.path(root_dir, "manifest", "root_status.txt"))
  writeLines("SUCCESS", file.path(method_dir, "manifest", "status.txt"))

  lead <- data.frame(
    forecast_lead = 1:30,
    origin_end_source_index = 9990L,
    pinball_mean = seq_len(30),
    stringsAsFactors = FALSE
  )
  rolling <- data.frame(
    forecast_origin_source_index = c(rep(seq(9000, 9960, by = 30), each = 30), rep(9990L, 10L)),
    forecast_lead = c(rep(1:30, length(seq(9000, 9960, by = 30))), 1:10),
    target_source_index = 9001:10000,
    stringsAsFactors = FALSE
  )
  utils::write.csv(lead, file.path(method_dir, "tables", "forecast_lead_metrics.csv"), row.names = FALSE)
  utils::write.csv(rolling, file.path(method_dir, "tables", "forecast_rolling_origin_paths.csv"), row.names = FALSE)
  exdqlm:::.qdesn_validation_write_json(
    file.path(method_dir, "manifest", "output_retention.json"),
    list(forecast_objects_pruned = TRUE, forecast_objects_exists_after = FALSE)
  )

  audit <- exdqlm:::qdesn_dynamic_fitforecast_audit_screen_campaign(
    results_root = results_root,
    expected_roots = 1L,
    strict = TRUE
  )
  expect_true(audit$summary$strict_ready)
  expect_equal(audit$root_audit$method_dir_name, "mcmc_al")
  expect_true(audit$root_audit$lead_metrics_pass)
  expect_true(audit$root_audit$rolling_paths_pass)
})

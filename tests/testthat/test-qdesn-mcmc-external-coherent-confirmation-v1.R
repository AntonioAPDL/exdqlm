test_that("external-coherent confirmation v1 is exact, staged, and storage-light", {
  root <- normalizePath(file.path(testthat::test_path(), "..", ".."), winslash = "/", mustWork = TRUE)
  stage <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_external_coherent_confirmation_v1"
  config_root <- file.path(root, "config", "validation")
  defaults_path <- file.path(config_root, paste0(stage, "_defaults.yaml"))
  profiles_path <- file.path(config_root, paste0(stage, "_profiles.csv"))
  assignments_path <- file.path(config_root, paste0(stage, "_cell_assignments.csv"))
  grid_path <- file.path(config_root, paste0(stage, "_grid.csv"))
  targets_path <- file.path(config_root, paste0(stage, "_target_spec_ids.csv"))
  manifest_path <- file.path(config_root, paste0(stage, "_materialization_manifest.json"))
  expected_spec <- "qdesn__laplace__0p25__tt500__rhs_ns__mcmc__exal__020293d289bcb0"

  for (path in c(defaults_path, profiles_path, assignments_path, grid_path, targets_path, manifest_path)) {
    expect_true(file.exists(path), info = path)
  }
  defaults <- yaml::read_yaml(defaults_path)
  profiles <- utils::read.csv(profiles_path, check.names = FALSE)
  assignments <- utils::read.csv(assignments_path, check.names = FALSE)
  grid <- utils::read.csv(grid_path, check.names = FALSE)
  targets <- utils::read.csv(targets_path, check.names = FALSE)
  manifest <- jsonlite::read_json(manifest_path, simplifyVector = TRUE)

  expect_identical(as.character(read.dcf(file.path(root, "DESCRIPTION"))[1L, "Version"]), "1.0.0")
  expect_equal(nrow(profiles), 80L)
  expect_equal(nrow(assignments), 1L)
  expect_equal(nrow(grid), 1L)
  expect_equal(nrow(targets), 1L)
  expect_identical(targets$spec_id[[1L]], expected_spec)
  expect_identical(targets$likelihood_target[[1L]], "exal")
  expect_identical(as.integer(grid$seed[[1L]]), 52086L)
  expect_identical(
    as.integer(profiles$seed[profiles$screening_profile_id == "mgv3_16_exal_local"]),
    83016L
  )
  expect_equal(as.numeric(grid$rhs_tau0[[1L]]), 1e-4, tolerance = 1e-14)
  expect_identical(as.integer(grid$train_start_source_index[[1L]]), 8501L)
  expect_identical(as.integer(grid$train_end_source_index[[1L]]), 9000L)
  expect_identical(as.integer(grid$forecast_start_source_index[[1L]]), 9001L)
  expect_identical(as.integer(grid$forecast_end_source_index[[1L]]), 10000L)
  expect_identical(as.integer(defaults$study_contract$budget$mcmc_n_burn), 5000L)
  expect_identical(as.integer(defaults$study_contract$budget$mcmc_n_mcmc), 20000L)
  expect_identical(as.integer(defaults$study_contract$budget$posterior_metric_draws), 200L)
  expect_false(defaults$pipeline$outputs$keep_draws)
  expect_false(defaults$pipeline$outputs$keep_mcmc_vb_init)
  expect_false(defaults$pipeline$outputs$save_forecast_objects)
  expect_false(defaults$pipeline$outputs$retain_full_rds_on_failure)
  expect_identical(manifest$launch_status, "prepared_not_launched")
  expect_identical(as.integer(manifest$counts$externally_coherent_screening_candidates), 2L)
  expect_identical(as.integer(manifest$counts$lower_quantile_redesign_cells), 11L)
  expect_identical(manifest$selected$spec_id, expected_spec)
  expect_true(is.logical(manifest$tracked_source_dirty_before_materialization))
  expect_true(is.logical(manifest$git_dirty_after_materialization))
})

test_that("confirmation scripts enforce prepare, smoke, approval, and closeout gates", {
  root <- normalizePath(file.path(testthat::test_path(), "..", ".."), winslash = "/", mustWork = TRUE)
  paths <- file.path(
    root,
    "scripts",
    c(
      "materialize_qdesn_tt500_mcmc_external_coherent_confirmation_v1.R",
      "orchestrate_qdesn_tt500_mcmc_external_coherent_confirmation_v1.R",
      "closeout_qdesn_tt500_mcmc_external_coherent_confirmation_v1.R"
    )
  )
  for (path in paths) {
    expect_true(file.exists(path), info = path)
    expect_silent(parse(path))
  }
  materializer <- paste(readLines(paths[[1L]], warn = FALSE), collapse = "\n")
  orchestrator <- paste(readLines(paths[[2L]], warn = FALSE), collapse = "\n")
  closeout <- paste(readLines(paths[[3L]], warn = FALSE), collapse = "\n")

  expect_match(materializer, "coherent_external_benchmark", fixed = TRUE)
  expect_match(materializer, "lower_quantile_cell_specific_redesign_handoff.csv", fixed = TRUE)
  expect_match(materializer, "preserve_full_profile_catalog_and_row_order", fixed = TRUE)
  expect_match(materializer, "all three source-file hashes", fixed = TRUE)
  expect_match(orchestrator, "Full confirmation requires --full --launch-approved", fixed = TRUE)
  expect_match(orchestrator, "--prepare-only", fixed = TRUE)
  expect_match(orchestrator, "--stream-child-stdout", fixed = TRUE)
  expect_match(orchestrator, "Full confirmation requires a clean committed worktree", fixed = TRUE)
  expect_match(closeout, "ratio_to_external_best", fixed = TRUE)
  expect_match(closeout, "ratio_to_screening", fixed = TRUE)
  expect_match(closeout, "unexpected_confirmation_payload", fixed = TRUE)
  expect_match(closeout, "source_file_hashes_ok", fixed = TRUE)
  expect_match(closeout, "source_file_hash_audit.csv", fixed = TRUE)
  expect_match(closeout, "fit_request.json", fixed = TRUE)
  expect_match(closeout, "manual_article_review_required", fixed = TRUE)
})

test_that("prelaunch evidence has no stale home paths or forbidden payloads", {
  root <- normalizePath(file.path(testthat::test_path(), "..", ".."), winslash = "/", mustWork = TRUE)
  prelaunch <- file.path(
    root,
    "validation",
    "fitforecast_v2",
    "promotions",
    "qdesn_tt500_mcmc_external_coherent_confirmation_v1_prelaunch_20260727"
  )
  expect_true(dir.exists(prelaunch))
  files <- list.files(prelaunch, recursive = TRUE, full.names = TRUE)
  expect_false(any(grepl("[.](rds|rda|RData)$", files, ignore.case = TRUE)))
  text_files <- files[grepl("[.](csv|json|md|yaml|yml)$", files, ignore.case = TRUE)]
  contents <- paste(unlist(lapply(text_files, readLines, warn = FALSE), use.names = FALSE), collapse = "\n")
  expect_false(grepl("/home/jaguir26/local/src", contents, fixed = TRUE))

  handoff <- utils::read.csv(
    file.path(prelaunch, "lower_quantile_cell_specific_redesign_handoff.csv"),
    check.names = FALSE
  )
  expect_equal(nrow(handoff), 11L)
  expect_true(all(handoff$launch_status == "design_handoff_only_not_launched"))
  expect_true(all(!handoff$global_specification_allowed))
})

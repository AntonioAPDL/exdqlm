test_that("VB train-only rebaseline is an exact 18-cell replay", {
  root <- normalizePath(file.path(testthat::test_path(), "..", ".."),
                        winslash = "/", mustWork = TRUE)
  stage <- "qdesn_dynamic_fitforecast_v2_500obs_vb_trainonly_rebaseline_v1"
  stub <- file.path(root, "config", "validation", stage)
  paths <- c(
    defaults = paste0(stub, "_defaults.yaml"),
    profiles = paste0(stub, "_profiles.csv"),
    candidates = paste0(stub, "_candidate_contract.csv"),
    assignments = paste0(stub, "_cell_assignments.csv"),
    grid = paste0(stub, "_grid.csv"),
    targets = paste0(stub, "_target_spec_ids.csv"),
    smoke_defaults = paste0(stub, "_smoke_defaults.yaml"),
    smoke_targets = paste0(stub, "_smoke_target_spec_ids.csv"),
    request_audit = paste0(stub, "_source_fit_request_audit.csv"),
    manifest = paste0(stub, "_materialization_manifest.json")
  )
  expect_true(all(file.exists(paths)), info = paste(paths[!file.exists(paths)], collapse = ", "))
  defaults <- yaml::read_yaml(paths[["defaults"]])
  profiles <- utils::read.csv(paths[["profiles"]], check.names = FALSE)
  candidates <- utils::read.csv(paths[["candidates"]], check.names = FALSE)
  assignments <- utils::read.csv(paths[["assignments"]], check.names = FALSE)
  grid <- utils::read.csv(paths[["grid"]], check.names = FALSE)
  targets <- utils::read.csv(paths[["targets"]], check.names = FALSE)
  smoke_defaults <- yaml::read_yaml(paths[["smoke_defaults"]])
  smoke_targets <- utils::read.csv(paths[["smoke_targets"]], check.names = FALSE)
  request_audit <- utils::read.csv(paths[["request_audit"]], check.names = FALSE)
  manifest <- jsonlite::read_json(paths[["manifest"]], simplifyVector = TRUE)

  expect_equal(nrow(profiles), 18L)
  expect_equal(nrow(candidates), 18L)
  expect_equal(nrow(assignments), 18L)
  expect_equal(nrow(grid), 18L)
  expect_equal(nrow(targets), 18L)
  expect_equal(length(unique(paste(profiles$model_variant, profiles$family,
                                   sprintf("%.8f", profiles$tau)))), 18L)
  expect_setequal(profiles$model_variant, c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"))
  expect_setequal(targets$likelihood_family, c("al", "exal"))
  expect_true(all(targets$method == "vb"))
  expect_true(all(targets$likelihood_family == targets$likelihood_target))
  expect_true(all(request_audit$hash_match))
  expect_true(all(file.exists(request_audit$source_fit_request_path)))
  expect_true(all(profiles$source_vb_max_iter == 150L))
  expect_true(all(profiles$source_vb_min_iter_elbo == 40L))
  expect_true(all(profiles$source_vb_n_samp_xi == 500L))
  expect_equal(nrow(smoke_targets), 2L)
  expect_setequal(smoke_targets$likelihood_family, c("al", "exal"))
  expect_identical(as.integer(smoke_defaults$study_contract$budget$vb_max_iter), 5L)
  expect_identical(as.integer(manifest$counts$full_specs), 18L)
  expect_false(manifest$article_update_automatic)
})

test_that("VB train-only rebaseline freezes source, preprocessing, and storage contracts", {
  root <- normalizePath(file.path(testthat::test_path(), "..", ".."),
                        winslash = "/", mustWork = TRUE)
  stage <- "qdesn_dynamic_fitforecast_v2_500obs_vb_trainonly_rebaseline_v1"
  stub <- file.path(root, "config", "validation", stage)
  defaults <- yaml::read_yaml(paste0(stub, "_defaults.yaml"))
  grid <- utils::read.csv(paste0(stub, "_grid.csv"), check.names = FALSE)
  registry <- utils::read.csv(paste0(stub, "_source_registry.csv"), check.names = FALSE)

  expect_identical(defaults$execution$methods, "vb")
  expect_identical(defaults$preproc$fit_scope, "train_only")
  expect_identical(defaults$study_contract$preprocessing$scope, "train_only")
  expect_false(defaults$study_contract$preprocessing$heldout_response_used_for_scaling)
  expect_false(defaults$study_contract$preprocessing$heldout_covariates_used_for_scaling)
  expect_identical(as.integer(defaults$study_contract$budget$vb_max_iter), 150L)
  expect_identical(as.integer(defaults$study_contract$budget$vb_min_iter_elbo), 40L)
  expect_identical(as.integer(defaults$study_contract$budget$vb_n_samp_xi), 500L)
  expect_false(defaults$pipeline$outputs$keep_draws)
  expect_false(defaults$pipeline$outputs$keep_mcmc_vb_init)
  expect_false(defaults$pipeline$outputs$save_forecast_objects)
  expect_false(defaults$pipeline$outputs$retain_full_rds_on_failure)
  expect_false(defaults$pipeline$inference$vb$diagnostics$rhs_trace)
  expect_false(defaults$pipeline$inference$vb$diagnostics$rhs_deep)
  expect_equal(nrow(registry), 9L)
  expect_true(all(registry$TT_warmup == 2000L))
  expect_true(all(registry$TT_main == 10000L))
  expect_true(all(registry$TT_total == 12000L))
  expect_true(all(grid$train_start_source_index == 8501L))
  expect_true(all(grid$train_end_source_index == 9000L))
  expect_true(all(grid$forecast_start_source_index == 9001L))
  expect_true(all(grid$forecast_end_source_index == 10000L))
})

test_that("VB train-only lifecycle scripts are staged and parseable", {
  root <- normalizePath(file.path(testthat::test_path(), "..", ".."),
                        winslash = "/", mustWork = TRUE)
  scripts <- file.path(root, "validation", "fitforecast_v2", "scripts")
  r_paths <- file.path(scripts, c(
    "materialize_qdesn_vb_train_only_rebaseline_v1.R",
    "verify_qdesn_vb_train_only_rebaseline_contract.R",
    "verify_qdesn_vb_train_only_rebaseline_smoke.R",
    "healthcheck_qdesn_vb_train_only_rebaseline_v1.R",
    "closeout_qdesn_vb_train_only_rebaseline_v1.R"
  ))
  shell_paths <- file.path(scripts, c(
    "run_qdesn_vb_train_only_rebaseline_v1_pipeline.sh",
    "launch_qdesn_vb_train_only_rebaseline_v1.sh"
  ))
  expect_true(all(file.exists(c(r_paths, shell_paths))))
  invisible(lapply(r_paths, function(path) expect_silent(parse(path))))
  pipeline <- paste(readLines(shell_paths[[1L]], warn = FALSE), collapse = "\n")
  launcher <- paste(readLines(shell_paths[[2L]], warn = FALSE), collapse = "\n")
  closeout <- paste(readLines(r_paths[[5L]], warn = FALSE), collapse = "\n")
  expect_match(pipeline, "source_verification", fixed = TRUE)
  expect_match(pipeline, "--prepare-only", fixed = TRUE)
  expect_match(pipeline, "smoke_audit", fixed = TRUE)
  expect_match(pipeline, "full_resource_gate", fixed = TRUE)
  expect_match(pipeline, "FULL_TRAINONLY_VB_REBASELINE_APPROVED=1", fixed = TRUE)
  expect_match(launcher, "clean committed worktree", fixed = TRUE)
  expect_match(closeout, "CORRECTED_VB_REBASELINE_COMPLETE", fixed = TRUE)
  expect_match(closeout, "article_updated = FALSE", fixed = TRUE)
})

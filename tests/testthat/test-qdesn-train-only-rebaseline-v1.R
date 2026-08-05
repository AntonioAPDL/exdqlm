test_that("train-only rebaseline freezes every current metric-source design", {
  root <- normalizePath(file.path(testthat::test_path(), "..", ".."),
                        winslash = "/", mustWork = TRUE)
  stage <- "qdesn_dynamic_fitforecast_v2_500obs_trainonly_rebaseline_v1"
  stub <- file.path(root, "config", "validation", stage)
  paths <- c(
    defaults = paste0(stub, "_defaults.yaml"),
    profiles = paste0(stub, "_profiles.csv"),
    assignments = paste0(stub, "_cell_assignments.csv"),
    metrics = paste0(stub, "_legacy_metric_contract.csv"),
    grid = paste0(stub, "_grid.csv"),
    targets = paste0(stub, "_target_spec_ids.csv"),
    smoke_defaults = paste0(stub, "_smoke_defaults.yaml"),
    smoke_grid = paste0(stub, "_smoke_grid.csv"),
    smoke_targets = paste0(stub, "_smoke_target_spec_ids.csv"),
    source_audit = paste0(stub, "_source_file_hash_audit.csv"),
    staged_audit = paste0(stub, "_staged_source_hash_audit.csv"),
    request_audit = paste0(stub, "_source_fit_request_audit.csv"),
    manifest = paste0(stub, "_materialization_manifest.json")
  )
  expect_true(all(file.exists(paths)), info = paste(paths[!file.exists(paths)], collapse = ", "))

  defaults <- yaml::read_yaml(paths[["defaults"]])
  profiles <- utils::read.csv(paths[["profiles"]], check.names = FALSE)
  assignments <- utils::read.csv(paths[["assignments"]], check.names = FALSE)
  metrics <- utils::read.csv(paths[["metrics"]], check.names = FALSE)
  grid <- utils::read.csv(paths[["grid"]], check.names = FALSE)
  targets <- utils::read.csv(paths[["targets"]], check.names = FALSE)
  smoke_defaults <- yaml::read_yaml(paths[["smoke_defaults"]])
  smoke_grid <- utils::read.csv(paths[["smoke_grid"]], check.names = FALSE)
  smoke_targets <- utils::read.csv(paths[["smoke_targets"]], check.names = FALSE)
  source_audit <- utils::read.csv(paths[["source_audit"]], check.names = FALSE)
  staged_audit <- utils::read.csv(paths[["staged_audit"]], check.names = FALSE)
  request_audit <- utils::read.csv(paths[["request_audit"]], check.names = FALSE)
  manifest <- jsonlite::read_json(paths[["manifest"]], simplifyVector = TRUE)
  expected <- as.integer(manifest$counts$full_specs)

  expect_identical(as.character(read.dcf(file.path(root, "DESCRIPTION"))[1L, "Version"]), "1.0.0")
  expect_equal(expected, 37L)
  expect_equal(nrow(profiles), expected)
  expect_equal(nrow(assignments), expected)
  expect_equal(nrow(grid), expected)
  expect_equal(nrow(targets), expected)
  expect_equal(nrow(metrics), 54L)
  expect_equal(length(unique(metrics$cell_id)), 18L)
  expect_equal(length(unique(paste(
    profiles$model_variant, profiles$target_family, profiles$target_tau
  ))), 18L)
  expect_identical(anyDuplicated(profiles$candidate_key), 0L)
  expect_identical(anyDuplicated(grid$root_id), 0L)
  expect_identical(anyDuplicated(targets$spec_id), 0L)
  expect_true(all(assignments$root_id %in% grid$root_id))
  expect_true(all(targets$likelihood_family == targets$likelihood_target))
  expect_setequal(unique(targets$likelihood_family), c("al", "exal"))

  expect_equal(nrow(smoke_grid), 2L)
  expect_equal(nrow(smoke_targets), 2L)
  expect_setequal(smoke_targets$likelihood_family, c("al", "exal"))
  expect_identical(as.integer(smoke_defaults$study_contract$budget$mcmc_n_burn), 4L)
  expect_identical(as.integer(smoke_defaults$study_contract$budget$mcmc_n_mcmc), 4L)

  expect_true(all(source_audit$hash_match))
  expect_true(all(staged_audit$hash_match))
  expect_true(all(request_audit$hash_match))
  expect_true(all(file.exists(request_audit$source_fit_request_path)))
  expect_true(all(targets$source_registry_hash_value == manifest$source_registry_hash_value))
  expect_false(manifest$article_update_automatic)
  expect_identical(manifest$launch_status, "materialized_not_launched")
})

test_that("train-only rebaseline preserves source, budget, and storage contracts", {
  root <- normalizePath(file.path(testthat::test_path(), "..", ".."),
                        winslash = "/", mustWork = TRUE)
  stage <- "qdesn_dynamic_fitforecast_v2_500obs_trainonly_rebaseline_v1"
  stub <- file.path(root, "config", "validation", stage)
  defaults <- yaml::read_yaml(paste0(stub, "_defaults.yaml"))
  grid <- utils::read.csv(paste0(stub, "_grid.csv"), check.names = FALSE)
  registry <- utils::read.csv(paste0(stub, "_source_registry.csv"), check.names = FALSE)

  expect_identical(defaults$preproc$fit_scope, "train_only")
  expect_identical(defaults$study_contract$preprocessing$scope, "train_only")
  expect_identical(defaults$study_contract$preprocessing$preprocessing_fit_rows,
                   c(1L, 890L))
  expect_false(defaults$study_contract$preprocessing$heldout_response_used_for_scaling)
  expect_false(defaults$study_contract$preprocessing$heldout_covariates_used_for_scaling)
  expect_identical(as.integer(defaults$study_contract$budget$mcmc_n_burn), 5000L)
  expect_identical(as.integer(defaults$study_contract$budget$mcmc_n_mcmc), 20000L)
  expect_identical(as.integer(defaults$study_contract$budget$posterior_metric_draws), 200L)
  expect_identical(as.integer(defaults$pipeline$inference$mcmc$progress_every), 50L)
  expect_false(defaults$pipeline$outputs$keep_draws)
  expect_false(defaults$pipeline$outputs$keep_mcmc_vb_init)
  expect_false(defaults$pipeline$outputs$save_forecast_objects)
  expect_false(defaults$pipeline$outputs$retain_full_rds_on_failure)

  expect_equal(nrow(registry), 9L)
  expect_true(all(registry$TT_warmup == 2000L))
  expect_true(all(registry$TT_main == 10000L))
  expect_true(all(registry$TT_total == 12000L))
  expect_true(all(registry$train_start_source_index == 8501L))
  expect_true(all(registry$train_end_source_index == 9000L))
  expect_true(all(registry$forecast_origin_source_index == 9000L))
  expect_true(all(registry$forecast_start_source_index == 9001L))
  expect_true(all(registry$forecast_end_source_index == 10000L))
  expect_true(all(registry$max_lead_configured == 30L))
  expect_true(all(registry$origin_stride == 30L))
  expect_true(all(!registry$refit_per_origin))
  expect_true(all(grid$train_start_source_index == 8501L))
  expect_true(all(grid$train_end_source_index == 9000L))
  expect_true(all(grid$forecast_start_source_index == 9001L))
  expect_true(all(grid$forecast_end_source_index == 10000L))
})

test_that("train-only rebaseline lifecycle is staged and parseable", {
  root <- normalizePath(file.path(testthat::test_path(), "..", ".."),
                        winslash = "/", mustWork = TRUE)
  scripts <- file.path(root, "validation", "fitforecast_v2", "scripts")
  r_paths <- file.path(scripts, c(
    "materialize_qdesn_train_only_rebaseline_v1.R",
    "verify_qdesn_train_only_rebaseline_contract.R",
    "verify_qdesn_train_only_rebaseline_smoke.R",
    "healthcheck_qdesn_train_only_rebaseline_v1.R",
    "closeout_qdesn_train_only_rebaseline_v1.R"
  ))
  shell_paths <- file.path(scripts, c(
    "run_qdesn_train_only_rebaseline_v1_pipeline.sh",
    "launch_qdesn_train_only_rebaseline_v1.sh"
  ))
  expect_true(all(file.exists(c(r_paths, shell_paths))))
  invisible(lapply(r_paths, function(path) expect_silent(parse(path))))
  pipeline <- paste(readLines(shell_paths[[1L]], warn = FALSE), collapse = "\n")
  launcher <- paste(readLines(shell_paths[[2L]], warn = FALSE), collapse = "\n")
  healthcheck <- paste(readLines(r_paths[[4L]], warn = FALSE), collapse = "\n")
  closeout <- paste(readLines(r_paths[[5L]], warn = FALSE), collapse = "\n")
  expect_match(pipeline, "FULL_TRAINONLY_REBASELINE_APPROVED=1", fixed = TRUE)
  expect_match(pipeline, "HEARTBEAT_SECONDS:-1800", fixed = TRUE)
  expect_match(pipeline, "STALE_THRESHOLD_SECONDS:-1800", fixed = TRUE)
  expect_match(pipeline, "source_verification", fixed = TRUE)
  expect_match(pipeline, "--prepare-only", fixed = TRUE)
  expect_match(pipeline, "smoke_audit", fixed = TRUE)
  expect_match(pipeline, "full_resource_gate", fixed = TRUE)
  expect_match(pipeline, "closeout", fixed = TRUE)
  expect_match(launcher, "clean committed worktree", fixed = TRUE)
  expect_match(healthcheck, "grepl(root_id, ps_lines", fixed = TRUE)
  expect_false(grepl("grepl(as.character(spec$spec_id), ps_lines", healthcheck,
                     fixed = TRUE))
  expect_match(healthcheck, "COMPLETED_CLOSED_OUT", fixed = TRUE)
  expect_match(healthcheck, "authoritative_gate", fixed = TRUE)
  expect_match(healthcheck, "gate_decision", fixed = TRUE)
  expect_match(closeout, "article_updated = FALSE", fixed = TRUE)
  expect_match(closeout, "CORRECTED_REBASELINE_COMPLETE", fixed = TRUE)
  expect_match(
    closeout,
    "study_contract$source_registry_hash_value",
    fixed = TRUE
  )
  expect_match(closeout, "launch_git_short", fixed = TRUE)
  expect_match(closeout, "observed_root_git_sha_counts", fixed = TRUE)
})

test_that("active train-only assets contain no stale home paths or binaries", {
  root <- normalizePath(file.path(testthat::test_path(), "..", ".."),
                        winslash = "/", mustWork = TRUE)
  stage <- "qdesn_dynamic_fitforecast_v2_500obs_trainonly_rebaseline_v1"
  files <- list.files(
    file.path(root, "config", "validation"),
    pattern = paste0("^", stage), full.names = TRUE
  )
  expect_false(any(grepl("[.](rds|rda|RData)$", files, ignore.case = TRUE)))
  text <- paste(unlist(lapply(files, readLines, warn = FALSE), use.names = FALSE),
                collapse = "\n")
  expect_false(grepl("/home/jaguir26/local/src", text, fixed = TRUE))
})

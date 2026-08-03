test_that("alpha/rho confirmation v1 freezes eight explicit paired roots", {
  root <- normalizePath(file.path(testthat::test_path(), "..", ".."),
                        winslash = "/", mustWork = TRUE)
  stage <- "qdesn_dynamic_fitforecast_v2_500obs_alpha_rho_confirmation_v1"
  stub <- file.path(root, "config", "validation", stage)
  paths <- c(
    defaults = paste0(stub, "_defaults.yaml"),
    profiles = paste0(stub, "_profiles.csv"),
    assignments = paste0(stub, "_cell_assignments.csv"),
    cell_plan = paste0(stub, "_cell_plan.csv"),
    grid = paste0(stub, "_grid.csv"),
    targets = paste0(stub, "_target_spec_ids.csv"),
    seed_audit = paste0(stub, "_seed_contract_audit.csv"),
    registry = paste0(stub, "_source_registry.csv"),
    source_audit = paste0(stub, "_source_file_hash_audit.csv"),
    staged_audit = paste0(stub, "_staged_source_hash_audit.csv"),
    smoke_defaults = paste0(stub, "_smoke_defaults.yaml"),
    smoke_grid = paste0(stub, "_smoke_grid.csv"),
    smoke_targets = paste0(stub, "_smoke_target_spec_ids.csv"),
    manifest = paste0(stub, "_materialization_manifest.json")
  )
  expect_true(all(file.exists(paths)), info = paste(paths[!file.exists(paths)], collapse = ", "))

  defaults <- yaml::read_yaml(paths[["defaults"]])
  profiles <- utils::read.csv(paths[["profiles"]], check.names = FALSE)
  assignments <- utils::read.csv(paths[["assignments"]], check.names = FALSE)
  grid <- utils::read.csv(paths[["grid"]], check.names = FALSE)
  targets <- utils::read.csv(paths[["targets"]], check.names = FALSE)
  seed_audit <- utils::read.csv(paths[["seed_audit"]], check.names = FALSE)
  registry <- utils::read.csv(paths[["registry"]], check.names = FALSE)
  source_audit <- utils::read.csv(paths[["source_audit"]], check.names = FALSE)
  staged_audit <- utils::read.csv(paths[["staged_audit"]], check.names = FALSE)
  smoke_defaults <- yaml::read_yaml(paths[["smoke_defaults"]])
  smoke_grid <- utils::read.csv(paths[["smoke_grid"]], check.names = FALSE)
  smoke_targets <- utils::read.csv(paths[["smoke_targets"]], check.names = FALSE)
  manifest <- jsonlite::read_json(paths[["manifest"]], simplifyVector = TRUE)

  expect_identical(as.character(read.dcf(file.path(root, "DESCRIPTION"))[1L, "Version"]), "1.0.0")
  expect_equal(nrow(profiles), 8L)
  expect_equal(nrow(assignments), 8L)
  expect_equal(nrow(grid), 8L)
  expect_equal(nrow(targets), 8L)
  expect_equal(nrow(seed_audit), 8L)
  expect_equal(nrow(registry), 2L)
  expect_equal(nrow(smoke_grid), 4L)
  expect_equal(nrow(smoke_targets), 4L)
  expect_setequal(unique(profiles$target_cell_id), c(
    "exal_gausmix_t0p25", "exal_laplace_t0p05"
  ))
  expect_setequal(unique(profiles$comparison_role), c("candidate", "parent_exact"))
  expect_true(all(table(profiles$confirmation_pair_id) == 2L))
  expect_true(all(table(profiles$target_cell_id) == 4L))
  expect_true(all(table(profiles$reservoir_replicate) == 4L))
  expect_true(all(seed_audit$status == "PASS"))
  expect_identical(anyDuplicated(targets$spec_id), 0L)
  expect_true(all(targets$likelihood_family == "exal"))
  expect_true(all(targets$likelihood_target == "exal"))

  for (pair_id in unique(grid$confirmation_pair_id)) {
    pair <- grid[grid$confirmation_pair_id == pair_id, , drop = FALSE]
    expect_equal(nrow(pair), 2L)
    expect_setequal(pair$comparison_role, c("candidate", "parent_exact"))
    for (field in c(
      "desn_seed", "mcmc_seed", "mcmc_rng_seed",
      "vb_warm_start_seed", "synthesis_seed"
    )) {
      expect_equal(length(unique(pair[[field]])), 1L, info = paste(pair_id, field))
    }
  }
  seed_by_cell <- split(profiles, profiles$target_cell_id)
  expect_true(all(vapply(seed_by_cell, function(x) {
    length(unique(x$seed[x$comparison_role == "candidate"])) == 2L
  }, logical(1L))))

  expect_identical(as.integer(defaults$study_contract$budget$mcmc_n_burn), 5000L)
  expect_identical(as.integer(defaults$study_contract$budget$mcmc_n_mcmc), 20000L)
  expect_identical(as.integer(defaults$study_contract$budget$posterior_metric_draws), 200L)
  expect_identical(as.integer(defaults$pipeline$inference$mcmc$progress_every), 50L)
  expect_false(defaults$multiseed$enabled)
  expect_false(defaults$pipeline$outputs$keep_draws)
  expect_false(defaults$pipeline$outputs$keep_mcmc_vb_init)
  expect_false(defaults$pipeline$outputs$save_forecast_objects)
  expect_false(defaults$pipeline$outputs$retain_full_rds_on_failure)
  expect_identical(as.integer(smoke_defaults$study_contract$budget$mcmc_n_burn), 4L)
  expect_identical(as.integer(smoke_defaults$study_contract$budget$mcmc_n_mcmc), 4L)

  expected_hash <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
  expect_true(all(grid$source_registry_hash_value == expected_hash))
  expect_identical(manifest$source_registry_hash_value, expected_hash)
  expect_true(manifest$source_file_hashes_verified)
  expect_true(manifest$staged_source_hashes_verified)
  expect_true(manifest$seed_contract_verified)
  expect_false(manifest$generic_multiseed_enabled)
  expect_false(manifest$article_update_automatic)
  expect_identical(manifest$launch_status, "materialized_not_launched")
  expect_true(all(source_audit$hash_match))
  expect_true(all(staged_audit$hash_match))
})

test_that("confirmation protocol preserves source windows and rolling horizons", {
  root <- normalizePath(file.path(testthat::test_path(), "..", ".."),
                        winslash = "/", mustWork = TRUE)
  stage <- "qdesn_dynamic_fitforecast_v2_500obs_alpha_rho_confirmation_v1"
  stub <- file.path(root, "config", "validation", stage)
  grid <- utils::read.csv(paste0(stub, "_grid.csv"), check.names = FALSE)
  registry <- utils::read.csv(paste0(stub, "_source_registry.csv"), check.names = FALSE)
  defaults <- yaml::read_yaml(paste0(stub, "_defaults.yaml"))

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
  expect_true(defaults$metrics$rolling_origin$enabled)
  expect_identical(as.integer(defaults$metrics$rolling_origin$max_lead_configured), 30L)
  expect_identical(as.integer(defaults$metrics$rolling_origin$origin_stride), 30L)
  expect_false(defaults$metrics$rolling_origin$refit_per_origin)
})

test_that("confirmation lifecycle is staged, gated, and parseable", {
  root <- normalizePath(file.path(testthat::test_path(), "..", ".."),
                        winslash = "/", mustWork = TRUE)
  r_paths <- file.path(root, "validation", "fitforecast_v2", "scripts", c(
    "materialize_qdesn_alpha_rho_confirmation_v1.R",
    "verify_qdesn_alpha_rho_confirmation_smoke.R",
    "closeout_qdesn_alpha_rho_confirmation_v1.R",
    "healthcheck_qdesn_alpha_rho_confirmation_v1.R"
  ))
  shell_paths <- file.path(root, "validation", "fitforecast_v2", "scripts", c(
    "run_qdesn_alpha_rho_confirmation_v1_pipeline.sh",
    "launch_qdesn_alpha_rho_confirmation_v1.sh"
  ))
  expect_true(all(file.exists(c(r_paths, shell_paths))))
  invisible(lapply(r_paths, function(path) expect_silent(parse(path))))
  pipeline <- paste(readLines(shell_paths[[1L]], warn = FALSE), collapse = "\n")
  launcher <- paste(readLines(shell_paths[[2L]], warn = FALSE), collapse = "\n")
  closeout <- paste(readLines(r_paths[[3L]], warn = FALSE), collapse = "\n")
  expect_match(pipeline, "FULL_CONFIRMATION_APPROVED=1", fixed = TRUE)
  expect_match(pipeline, "HEARTBEAT_SECONDS:-1800", fixed = TRUE)
  expect_match(pipeline, "--prepare-only", fixed = TRUE)
  expect_match(pipeline, "smoke_audit", fixed = TRUE)
  expect_match(pipeline, "full_resource_gate", fixed = TRUE)
  expect_match(pipeline, "closeout", fixed = TRUE)
  expect_match(launcher, "clean committed worktree", fixed = TRUE)
  expect_match(closeout, "diagnostic_status_counts", fixed = TRUE)
  expect_match(closeout, "article_updated = FALSE", fixed = TRUE)
  expect_match(closeout, "NO_TRANSPORT_STOP_ALPHA_RHO_LOCAL_DIRECTION", fixed = TRUE)
})

test_that("confirmation tracked evidence has no stale paths or binary payloads", {
  root <- normalizePath(file.path(testthat::test_path(), "..", ".."),
                        winslash = "/", mustWork = TRUE)
  stage <- "qdesn_dynamic_fitforecast_v2_500obs_alpha_rho_confirmation_v1"
  files <- list.files(
    file.path(root, "config", "validation"),
    pattern = paste0("^", stage), full.names = TRUE
  )
  expect_false(any(grepl("[.](rds|rda|RData)$", files, ignore.case = TRUE)))
  text <- paste(unlist(lapply(files, readLines, warn = FALSE), use.names = FALSE),
                collapse = "\n")
  expect_false(grepl("/home/jaguir26/local/src", text, fixed = TRUE))
})

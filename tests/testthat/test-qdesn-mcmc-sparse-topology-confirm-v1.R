test_that("sparse-topology confirmation freezes 21 fresh full-budget specs", {
  root <- normalizePath(file.path(testthat::test_path(), "..", ".."),
                        winslash = "/", mustWork = TRUE)
  stage <- "qdesn_dynamic_fitforecast_v2_500obs_mcmc_sparse_topology_confirm_v1"
  stub <- file.path(root, "config", "validation", stage)
  path <- function(suffix) paste0(stub, suffix)
  files <- c(
    defaults = path("_defaults.yaml"),
    profiles = path("_profiles.csv"),
    assignments = path("_cell_assignments.csv"),
    designs = path("_selected_designs.csv"),
    pairs = path("_pair_map.csv"),
    grid = path("_grid.csv"),
    targets = path("_target_spec_ids.csv"),
    seeds = path("_seed_contract_audit.csv"),
    topology = path("_topology_audit.csv"),
    registry = path("_source_registry.csv"),
    source_audit = path("_source_file_hash_audit.csv"),
    smoke_defaults = path("_smoke_defaults.yaml"),
    smoke_grid = path("_smoke_grid.csv"),
    smoke_targets = path("_smoke_target_spec_ids.csv"),
    article = path("_current_article_metric_context.csv"),
    promotion = path("_promotion_contract.csv"),
    generated = path("_generated_file_manifest.csv"),
    frozen = path("_frozen_input_manifest.csv"),
    manifest = path("_materialization_manifest.json")
  )
  expect_true(all(file.exists(files)), info = paste(files[!file.exists(files)], collapse = ", "))

  defaults <- yaml::read_yaml(files[["defaults"]])
  profiles <- read.csv(files[["profiles"]], check.names = FALSE)
  assignments <- read.csv(files[["assignments"]], check.names = FALSE)
  designs <- read.csv(files[["designs"]], check.names = FALSE)
  pairs <- read.csv(files[["pairs"]], check.names = FALSE)
  grid <- read.csv(files[["grid"]], check.names = FALSE)
  targets <- read.csv(files[["targets"]], check.names = FALSE)
  seeds <- read.csv(files[["seeds"]], check.names = FALSE)
  topology <- read.csv(files[["topology"]], check.names = FALSE)
  generated <- read.csv(files[["generated"]], check.names = FALSE)
  frozen <- read.csv(files[["frozen"]], check.names = FALSE)
  manifest <- jsonlite::read_json(files[["manifest"]], simplifyVector = TRUE)

  expect_identical(as.character(read.dcf(file.path(root, "DESCRIPTION"))[1L, "Version"]),
                   "1.0.0")
  expect_equal(nrow(profiles), 21L)
  expect_equal(nrow(assignments), 21L)
  expect_equal(nrow(designs), 7L)
  expect_equal(nrow(pairs), 9L)
  expect_equal(nrow(grid), 21L)
  expect_equal(nrow(targets), 21L)
  expect_equal(nrow(seeds), 21L)
  expect_identical(anyDuplicated(profiles$screening_profile_id), 0L)
  expect_identical(anyDuplicated(targets$spec_id), 0L)
  expect_setequal(unique(profiles$sampler_replicate), 3:5)
  expect_true(all(table(profiles$source_base_design_id) == 3L))
  expect_equal(sum(profiles$comparison_role == "candidate"), 9L)
  expect_equal(sum(profiles$comparison_role == "matched_sparse_parent"), 12L)
  expect_true(all(seeds$status == "PASS"))
  expect_true(all(topology$topology_valid))
  expect_true(all(topology$recurrent_nnz == topology$recurrent_edges_target))
  expect_true(all(targets$likelihood_family == targets$likelihood_target))

  for (pair_id in unique(profiles$sampler_pair_id)) {
    block <- profiles[profiles$sampler_pair_id == pair_id, , drop = FALSE]
    for (field in c("mcmc_seed", "mcmc_rng_seed", "vb_warm_start_seed",
                    "synthesis_seed")) {
      expect_equal(length(unique(block[[field]])), 1L, info = paste(pair_id, field))
    }
  }

  expect_equal(nrow(generated), 16L)
  expect_true(all(file.exists(generated$path)))
  expect_identical(unname(tools::sha256sum(generated$path)), unname(generated$sha256))
  expect_equal(nrow(frozen), 5L)
  expect_true(all(frozen$hash_match))
  expect_identical(unname(tools::sha256sum(frozen$path)),
                   unname(frozen$expected_sha256))
  expect_identical(manifest$authority_interface_sha256,
                   "90744fae79f8af79c6e844e5862c90330ea14d9bbd2df69f630440887fed1393")
  expect_false(manifest$article_update_automatic)
})

test_that("sparse-topology confirmation preserves source and storage contracts", {
  root <- normalizePath(file.path(testthat::test_path(), "..", ".."),
                        winslash = "/", mustWork = TRUE)
  stage <- "qdesn_dynamic_fitforecast_v2_500obs_mcmc_sparse_topology_confirm_v1"
  stub <- file.path(root, "config", "validation", stage)
  defaults <- yaml::read_yaml(paste0(stub, "_defaults.yaml"))
  smoke <- yaml::read_yaml(paste0(stub, "_smoke_defaults.yaml"))
  registry <- read.csv(paste0(stub, "_source_registry.csv"), check.names = FALSE)
  grid <- read.csv(paste0(stub, "_grid.csv"), check.names = FALSE)
  source_audit <- read.csv(paste0(stub, "_source_file_hash_audit.csv"),
                           check.names = FALSE)

  expect_equal(registry$TT_warmup, 2000L)
  expect_equal(registry$TT_main, 10000L)
  expect_equal(registry$TT_total, 12000L)
  expect_true(all(grid$train_start_source_index == 8501L))
  expect_true(all(grid$train_end_source_index == 9000L))
  expect_true(all(grid$forecast_start_source_index == 9001L))
  expect_true(all(grid$forecast_end_source_index == 10000L))
  expect_true(all(source_audit$hash_match))
  expect_equal(defaults$study_contract$rolling_origin$max_lead_configured, 30L)
  expect_equal(defaults$study_contract$rolling_origin$origin_stride, 30L)
  expect_true(defaults$study_contract$rolling_origin$no_refit)
  expect_equal(defaults$pipeline$inference$mcmc$n_burn, 5000L)
  expect_equal(defaults$pipeline$inference$mcmc$n_mcmc, 20000L)
  expect_equal(defaults$pipeline$inference$mcmc$progress_every, 50L)
  expect_false(defaults$pipeline$outputs$keep_draws)
  expect_false(defaults$pipeline$outputs$keep_mcmc_vb_init)
  expect_false(defaults$pipeline$outputs$save_forecast_objects)
  expect_false(defaults$pipeline$outputs$retain_full_rds_on_failure)
  expect_equal(smoke$pipeline$inference$mcmc$n_burn, 4L)
  expect_equal(smoke$pipeline$inference$mcmc$n_mcmc, 4L)
})

test_that("sparse-topology confirmation lifecycle is staged and parseable", {
  root <- normalizePath(file.path(testthat::test_path(), "..", ".."),
                        winslash = "/", mustWork = TRUE)
  scripts <- file.path(root, "validation", "fitforecast_v2", "scripts")
  r_files <- file.path(scripts, c(
    "materialize_qdesn_mcmc_sparse_topology_confirm_v1.R",
    "verify_qdesn_mcmc_sparse_topology_confirm_v1.R",
    "verify_qdesn_mcmc_sparse_topology_confirm_v1_smoke.R",
    "healthcheck_qdesn_mcmc_sparse_topology_confirm_v1.R",
    "closeout_qdesn_mcmc_sparse_topology_confirm_v1.R"
  ))
  shell_files <- file.path(scripts, c(
    "run_qdesn_mcmc_sparse_topology_confirm_v1_pipeline.sh",
    "launch_qdesn_mcmc_sparse_topology_confirm_v1.sh"
  ))
  expect_true(all(file.exists(c(r_files, shell_files))))
  invisible(lapply(r_files, function(path) expect_silent(parse(path))))
  pipeline <- paste(readLines(shell_files[[1L]], warn = FALSE), collapse = "\n")
  healthcheck <- paste(readLines(r_files[[4L]], warn = FALSE), collapse = "\n")
  closeout <- paste(readLines(r_files[[5L]], warn = FALSE), collapse = "\n")
  expect_match(pipeline, "--prepare-only", fixed = TRUE)
  expect_match(pipeline, "verify_qdesn_mcmc_sparse_topology_confirm_v1_smoke.R",
               fixed = TRUE)
  expect_match(pipeline, "wait_for_resources", fixed = TRUE)
  expect_match(pipeline, "WORKERS=20", fixed = TRUE)
  expect_match(pipeline, "trace_compaction", fixed = TRUE)
  expect_match(pipeline, "storage_audit", fixed = TRUE)
  expect_match(healthcheck, "return(iteration)", fixed = TRUE)
  expect_false(grepl("5000L + retained", healthcheck, fixed = TRUE))
  expect_match(closeout, "fresh_replicates_below_authority", fixed = TRUE)
  expect_match(closeout, "reported_but_not_used_for_metric_selection", fixed = TRUE)
  expect_match(closeout, "article_updated = FALSE", fixed = TRUE)
})

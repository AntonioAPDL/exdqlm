test_that("metric-gap v3 tau0 repair is the exact 25-spec precision-loss subset", {
  repo <- normalizePath(test_path("..", ".."), winslash = "/", mustWork = TRUE)
  stage <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v3_tau0_repair"
  source_stage <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v3"
  config_path <- function(stub, suffix) {
    file.path(repo, "config", "validation", paste0(stub, "_", suffix))
  }

  targets <- read.csv(
    config_path(stage, "target_spec_ids.csv"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  source_targets <- read.csv(
    config_path(source_stage, "target_spec_ids.csv"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  grid <- read.csv(
    config_path(stage, "grid.csv"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  profiles <- read.csv(
    config_path(stage, "profiles.csv"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  assignments <- read.csv(
    config_path(stage, "cell_assignments.csv"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  expect_equal(nrow(targets), 25L)
  expect_equal(length(unique(targets$spec_id)), 25L)
  expect_equal(length(unique(targets$root_id)), 25L)
  expect_true(all(abs(as.numeric(targets$rhs_tau0) - 3e-5) <= 1e-12))
  expect_setequal(targets$spec_id, source_targets$spec_id[abs(source_targets$rhs_tau0 - 3e-5) <= 1e-12])
  expect_equal(nrow(grid), 25L)
  expect_equal(nrow(profiles), 80L)
  expect_equal(nrow(assignments), 25L)
  expect_setequal(grid$root_id, targets$root_id)
  expect_setequal(assignments$root_id, targets$root_id)
  expect_true(all(targets$screening_profile_id.x %in% profiles$screening_profile_id))
  expect_true(all(grid$train_start_source_index == 8501L))
  expect_true(all(grid$train_end_source_index == 9000L))
  expect_true(all(grid$forecast_start_source_index == 9001L))
  expect_true(all(grid$forecast_end_source_index == 10000L))
})

test_that("metric-gap v3 repair defaults and manifest keep the repair isolated", {
  repo <- normalizePath(test_path("..", ".."), winslash = "/", mustWork = TRUE)
  stage <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v3_tau0_repair"
  config_path <- function(suffix) {
    file.path(repo, "config", "validation", paste0(stage, "_", suffix))
  }
  defaults <- yaml::read_yaml(config_path("defaults.yaml"))
  targets <- read.csv(
    config_path("target_spec_ids.csv"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  manifest <- jsonlite::read_json(
    config_path("materialization_manifest.json"),
    simplifyVector = FALSE
  )

  expect_identical(defaults$campaign$name, stage)
  expect_match(defaults$campaign$results_root, paste0(stage, "$"))
  expect_match(defaults$campaign$reports_root, paste0(stage, "$"))
  expect_setequal(
    unlist(defaults$execution$allowed_fit_spec_ids, use.names = FALSE),
    targets$spec_id
  )
  expect_equal(defaults$reference_contract$expected_selected_qdesn_roots, 25L)
  expect_equal(defaults$screening_profiles$canonical_profile_count, 80L)
  expect_equal(defaults$screening_profiles$selected_assignment_root_count, 25L)
  expect_false(defaults$study_contract$repair_contract$statistical_spec_change)
  expect_false(defaults$study_contract$repair_contract$overwrite_source_results)
  expect_equal(manifest$counts$source_successful_roots_preserved, 55L)
  expect_equal(manifest$counts$repair_target_specs, 25L)
  expect_equal(manifest$invariants$exact_tau0, 3e-5)
  expect_true(manifest$invariants$source_failure_set_equals_repair_set)
  expect_false(manifest$invariants$overlaps_source_success_set)
  expect_false(manifest$invariants$full_confirmation_launched)
})

test_that("metric-gap v3 repair orchestration and closeout are staged and parseable", {
  repo <- normalizePath(test_path("..", ".."), winslash = "/", mustWork = TRUE)
  scripts <- c(
    materialize = file.path(repo, "scripts", "materialize_qdesn_tt500_mcmc_metricgap_v3_tau0_repair.R"),
    orchestrate = file.path(repo, "scripts", "orchestrate_qdesn_tt500_mcmc_metricgap_v3_tau0_repair.R"),
    closeout = file.path(repo, "scripts", "closeout_qdesn_tt500_mcmc_metricgap_v3.R")
  )
  expect_true(all(file.exists(scripts)))
  invisible(lapply(scripts, function(path) expect_silent(parse(path))))

  orchestrator <- paste(readLines(scripts[["orchestrate"]], warn = FALSE), collapse = "\n")
  closeout <- paste(readLines(scripts[["closeout"]], warn = FALSE), collapse = "\n")
  expect_match(orchestrator, "Full repair launch requires --full --launch-approved", fixed = TRUE)
  expect_match(orchestrator, "--prepare-only", fixed = TRUE)
  expect_match(orchestrator, "--stream-child-stdout", fixed = TRUE)
  expect_match(closeout, "80 metric-row", fixed = TRUE)
  expect_match(closeout, "55 successful / 25 failed", fixed = TRUE)
  expect_match(closeout, "original_successful_root_ids", fixed = TRUE)
  expect_match(closeout, "Could not isolate the 55 original successful metric rows", fixed = TRUE)
  expect_match(closeout, "best_candidate_spec_id", fixed = TRUE)
  expect_match(closeout, "closest_balanced_candidates", fixed = TRUE)
  expect_match(closeout, "mixed_metric_envelope_cells", fixed = TRUE)
  expect_match(closeout, "family_tau_likelihood", fixed = TRUE)
  expect_match(closeout, "primary_improvement_minimum", fixed = TRUE)
  expect_match(closeout, "article_gate", fixed = TRUE)
})

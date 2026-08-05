test_that("train-only mechanism v1 freezes the intended per-cell design", {
  plan <- qdesn_tmv1_build_plan(repo_root)

  expect_equal(nrow(plan$targets), 3L)
  expect_equal(sum(plan$targets$primary_target), 2L)
  expect_equal(nrow(plan$profiles), 30L)
  expect_equal(nrow(plan$assignments), 30L)
  expect_equal(
    as.integer(table(plan$profiles$bundle_id)[c("raw", "c12", "c123", "sr")]),
    c(14L, 6L, 6L, 4L)
  )
  expect_setequal(unique(plan$profiles$paired_reservoir_seed), c(910001L, 910002L))
  expect_true(all(plan$profiles$D == 1L))
  expect_true(all(plan$profiles$rhs_tau0 == 3e-4))
})

test_that("mechanism arms have active paired topology", {
  plan <- qdesn_tmv1_build_plan(repo_root)
  audit <- qdesn_tmv1_topology_audit(plan$profiles)

  expect_equal(nrow(audit), 30L)
  expect_true(all(audit$total_topology_valid[audit$arm_code != "parent_exact"]))
  expect_true(all(!audit$total_topology_valid[audit$arm_code == "parent_exact"]))

  compact <- audit[grepl("^compact_", audit$arm_code), , drop = FALSE]
  keys <- paste(compact$target_cell_id, compact$reservoir_replicate, sep = "\r")
  invariant <- vapply(split(seq_len(nrow(compact)), keys), function(idx) {
    length(unique(compact$recurrent_mask_sha256[idx])) == 1L &&
      length(unique(compact$input_mask_sha256[idx])) == 1L
  }, logical(1L))
  expect_true(all(invariant))
})

test_that("materialized mechanism bundles preserve protocol and storage gates", {
  stub <- file.path(
    repo_root, "config", "validation",
    "qdesn_dynamic_fitforecast_v2_500obs_trainonly_mechanism_v1"
  )
  index <- utils::read.csv(paste0(stub, "_bundle_index.csv"), check.names = FALSE)
  expect_equal(index$expected_specs, c(42L, 18L, 18L, 12L))
  expect_equal(sum(index$expected_specs), 90L)

  for (i in seq_len(nrow(index))) {
    bundle <- as.character(index$bundle_id[[i]])
    defaults <- yaml::read_yaml(index$defaults_path[[i]])
    grid <- utils::read.csv(index$grid_path[[i]], check.names = FALSE)
    specs <- utils::read.csv(index$target_specs_path[[i]], check.names = FALSE)

    expect_equal(nrow(grid), index$expected_specs[[i]], info = bundle)
    expect_equal(nrow(specs), index$expected_specs[[i]], info = bundle)
    expect_equal(anyDuplicated(specs$spec_id), 0L, info = bundle)
    expect_true(all(specs$likelihood_family == specs$likelihood_target), info = bundle)
    expect_true(all(grid$train_start_source_index == 8501L), info = bundle)
    expect_true(all(grid$train_end_source_index == 9000L), info = bundle)
    expect_true(all(grid$forecast_start_source_index == 9001L), info = bundle)
    expect_true(all(grid$forecast_end_source_index == 10000L), info = bundle)
    expect_identical(defaults$preproc$fit_scope, "train_only", info = bundle)
    expect_false(defaults$pipeline$outputs$keep_draws, info = bundle)
    expect_false(defaults$pipeline$outputs$keep_mcmc_vb_init, info = bundle)
    expect_false(defaults$pipeline$outputs$save_forecast_objects, info = bundle)
    expect_false(defaults$pipeline$outputs$retain_full_rds_on_failure, info = bundle)
    expect_equal(defaults$pipeline$inference$mcmc$progress_every, 50L, info = bundle)
    expect_true(defaults$pipeline$inference$mcmc$init_from_vb, info = bundle)

    if (bundle == "raw") {
      expect_identical(defaults$pipeline$readout$input_mode, "raw_y_lags")
      expect_false(defaults$pipeline$decomposition$enabled)
    } else {
      expect_identical(defaults$pipeline$readout$input_mode, "dlm_decomp_lags")
      expect_true(defaults$pipeline$decomposition$enabled)
      expect_true(defaults$pipeline$validation_guardrails$allow_dlm_decomp_lags)
    }
  }
})

test_that("mechanism source contract uses fresh deterministic trajectories", {
  cfg <- yaml::read_yaml(file.path(
    repo_root, "config", "validation",
    "qdesn_dynamic_fitforecast_v2_500obs_trainonly_mechanism_v1_source_replicates.yaml"
  ))
  ids <- vapply(cfg$replicates, function(x) as.character(x$scenario_id), character(1L))

  expect_equal(length(ids), 3L)
  expect_true(all(grepl("^dlm_constV_p90_trainonly_mech_dev0[123]_TTmain10000_fitforecast$", ids)))
  expect_equal(cfg$generation$TT_warmup, 2000L)
  expect_equal(cfg$generation$TT_main, 10000L)
  expect_equal(cfg$generation$TT_total, 12000L)
  expect_equal(cfg$selection_contract$expected_total_specs, 90L)
})

test_that("legacy cleanup is exact, auditable, and idempotent", {
  script_path <- file.path(
    repo_root, "validation", "fitforecast_v2", "scripts",
    "cleanup_qdesn_trainonly_mechanism_v1_legacy_outputs.sh"
  )
  script <- paste(readLines(script_path, warn = FALSE), collapse = "\n")
  evidence_dir <- file.path(
    repo_root, "validation", "fitforecast_v2", "docs",
    "qdesn_trainonly_mechanism_v1_cleanup_20260805"
  )
  dry_run <- utils::read.csv(file.path(evidence_dir, "legacy_cleanup_dry_run.csv"), check.names = FALSE)
  removed <- utils::read.csv(file.path(evidence_dir, "legacy_cleanup_removed.csv"), check.names = FALSE)
  classification <- utils::read.csv(
    file.path(evidence_dir, "legacy_cleanup_classification.csv"),
    check.names = FALSE
  )

  expect_match(script, 'mode="dry-run"', fixed = TRUE)
  expect_match(script, "mcmc_nested_cellwise_v1_origin7000", fixed = TRUE)
  expect_match(script, "mcmc_nested_cellwise_v1_origin8000", fixed = TRUE)
  expect_match(script, "mcmc_nested_final_origin9000_v1", fixed = TRUE)
  expect_match(script, "Cleanup already completed; preserving", fixed = TRUE)
  expect_false(grepl("rm -rf", script, fixed = TRUE))
  expect_equal(nrow(dry_run), 7946L)
  expect_equal(nrow(removed), 7946L)
  expect_identical(as.character(dry_run$path), as.character(removed$path))
  expect_identical(as.numeric(dry_run$size_bytes), as.numeric(removed$size_bytes))
  expect_identical(as.character(dry_run$sha256), as.character(removed$sha256))
  expect_equal(sum(as.numeric(dry_run$size_bytes)), 5322171042)
  expect_true(all(classification$action %in% c("keep", "delete selected files")))
  expect_true(any(classification$action == "keep"))
  expect_true(any(classification$action == "delete selected files"))
})

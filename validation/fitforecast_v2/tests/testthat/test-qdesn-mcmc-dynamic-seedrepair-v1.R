interface_path <- file.path(
  repo_root, "validation", "fitforecast_v2", "promotions",
  "qdesn_dqlm_500obs_trainonly_article_v1_20260805",
  "qdesn_dqlm_500obs_trainonly_article_v1_20260805_interface.csv"
)
stage_stub <- file.path(
  repo_root, "config", "validation",
  "qdesn_dynamic_fitforecast_v2_500obs_mcmc_dynamic_seedrepair_v1"
)

test_that("dynamic seed-repair targets only the two inert Normal p=0.25 cells", {
  expect_identical(qdesn_dsr1_target_cells(), c("al_normal_t0p25", "exal_normal_t0p25"))
  expect_equal(
    qdesn_dsr1_alpha_levels("al_normal_t0p25"),
    c(0.40, 0.50, 0.55, 0.60, 0.65, 0.70, 0.75, 0.80, 0.85, 0.90, 0.95, 0.99)
  )
  expect_equal(
    qdesn_dsr1_alpha_levels("exal_normal_t0p25"),
    c(0.40, 0.50, 0.60, 0.70, 0.80, 0.85, 0.90, 0.925, 0.95, 0.975, 0.99, 0.995)
  )
  expect_error(qdesn_dsr1_alpha_levels("al_laplace_t0p25"), "No dynamic seed-repair")
})

test_that("authority is hash-pinned and exact parent structure is preserved", {
  expect_identical(
    unname(tools::sha256sum(interface_path)),
    "dff814fab1e920c10760645ac9e8d37dfa7f33ae2afba34ee8ed2a5509f4952a"
  )
  authority <- qdesn_dsr1_authority(interface_path)
  parents <- authority$parents

  expect_equal(nrow(parents), 2L)
  expect_setequal(parents$target_cell_id, qdesn_dsr1_target_cells())
  expect_true(all(parents$family == "normal"))
  expect_true(all(parents$tau == 0.25))
  expect_true(all(parents$target_metrics == "forecast_qtrue_mae_H1000"))
  expect_true(all(parents$D == 1L))
  expect_true(all(parents$n_each == 6L))
  expect_true(all(parents$m == 1L))
  expect_true(all(parents$alpha == 0.00075))
  expect_true(all(parents$rho == 0.35))
  expect_true(all(parents$pi_w == 0.0025))
  expect_true(all(parents$pi_in == 0.05))
  expect_true(all(parents$rhs_tau0 == 3e-4))
  expect_true(all(parents$seed == 123L))
  expect_true(all(file.exists(parents$parent_fit_request_path)))
})

test_that("bias-only authority defect is reproduced and repaired outcome-blind", {
  plan <- qdesn_dsr1_build_plan(interface_path)
  parent <- plan$parents[1L, , drop = FALSE]
  authority_stats <- qdesn_dsr1_topology_stats(parent, 123L)

  expect_equal(authority_stats$recurrent_nnz, 0L)
  expect_equal(authority_stats$input_nnz, 1L)
  expect_equal(authority_stats$bias_input_nnz, 1L)
  expect_equal(authority_stats$dynamic_input_nnz, 0L)
  expect_identical(plan$seed_contract$seed, c(900124L, 900126L, 900132L))
  expect_true(all(plan$seed_contract$dynamic_input_nnz > 0L))
  expect_true(all(!plan$seed_search_audit$selection_valid[plan$seed_search_audit$seed < 900124L]))
  expect_identical(
    which(plan$seed_search_audit$selection_valid)[1:3],
    match(plan$seed_contract$seed, plan$seed_search_audit$seed)
  )
  expect_match(plan$seed_contract$selection_rule[[1L]], "dynamic_input_nnz_gt_zero", fixed = TRUE)
})

test_that("profile design is cell-specific, paired, and structurally frozen", {
  plan <- qdesn_dsr1_build_plan(interface_path)
  profiles <- plan$profiles

  expect_equal(nrow(profiles), 80L)
  expect_equal(sum(profiles$comparison_role == "authority_parent"), 2L)
  expect_equal(sum(profiles$comparison_role == "dynamic_parent"), 6L)
  expect_equal(sum(profiles$comparison_role == "candidate"), 72L)
  expect_equal(anyDuplicated(profiles$screening_profile_id), 0L)
  expect_true(all(profiles$launch_phase == "discovery"))
  expect_true(all(profiles$D == 1L & profiles$n_each == 6L & profiles$m == 1L))
  expect_true(all(profiles$rho == 0.35 & profiles$pi_w == 0.0025 & profiles$pi_in == 0.05))
  expect_true(all(profiles$rhs_tau0 == 3e-4))
  expect_true(all(profiles$readout_y_lags == 1L & profiles$reservoir_lags == 0L))
  expect_true(all(profiles$topology_search_mode == "dynamic_seed_alpha_only"))

  candidate <- profiles[profiles$comparison_role == "candidate", , drop = FALSE]
  per_cell_seed <- table(candidate$target_cell_id, candidate$reservoir_replicate)
  expect_true(all(per_cell_seed == 12L))
  expect_setequal(unique(candidate$paired_reservoir_seed), c(900124L, 900126L, 900132L))
})

test_that("searched profiles have dynamic input and alpha-sensitive state paths", {
  plan <- qdesn_dsr1_build_plan(interface_path)
  topology <- qdesn_dsr1_topology_audit(plan$profiles)
  authority <- topology[topology$comparison_role == "authority_parent", , drop = FALSE]
  searched <- topology[topology$comparison_role != "authority_parent", , drop = FALSE]

  expect_equal(nrow(topology), 80L)
  expect_equal(nrow(authority), 2L)
  expect_true(all(authority$dynamic_input_nnz == 0L))
  expect_equal(nrow(searched), 78L)
  expect_true(all(searched$dynamic_input_nnz > 0L))
  expect_true(all(searched$candidate_topology_valid))
  expect_true(all(searched$topology_invariant_within_seed))
  expect_true(all(searched$probe_state_unique_within_seed))
  expect_true(all(is.na(authority$topology_invariant_within_seed)))
  expect_true(all(is.na(authority$probe_state_unique_within_seed)))
})

test_that("materialized discovery is 240 paired, explicit-seed, storage-light specs", {
  defaults_path <- paste0(stage_stub, "_discovery_defaults.yaml")
  skip_if_not(file.exists(defaults_path), "campaign has not been materialized")
  defaults <- yaml::read_yaml(defaults_path)
  grid <- utils::read.csv(paste0(stage_stub, "_discovery_grid.csv"), check.names = FALSE)
  specs <- utils::read.csv(paste0(stage_stub, "_discovery_target_spec_ids.csv"), check.names = FALSE)
  seed_audit <- utils::read.csv(paste0(stage_stub, "_seed_execution_contract.csv"), check.names = FALSE)

  expect_equal(nrow(grid), 240L)
  expect_equal(nrow(specs), 240L)
  expect_equal(nrow(seed_audit), 240L)
  expect_equal(anyDuplicated(specs$spec_id), 0L)
  expect_true(all(specs$likelihood_family == specs$likelihood_target))
  expect_true(all(seed_audit$status == "PASS"))
  expect_true(all(grid$train_start_source_index == 8501L))
  expect_true(all(grid$train_end_source_index == 9000L))
  expect_true(all(grid$forecast_start_source_index == 9001L))
  expect_true(all(grid$forecast_end_source_index == 10000L))
  expect_equal(length(unique(grid$source_scenario)), 3L)
  expect_equal(length(unique(grid$screening_profile_id)), 80L)
  expect_equal(length(unique(grid$sampler_pair_id)), 6L)

  seed_columns <- c("mcmc_seed", "mcmc_rng_seed", "vb_warm_start_seed", "synthesis_seed")
  pair_consistency <- vapply(split(seq_len(nrow(grid)), grid$sampler_pair_id), function(idx) {
    all(vapply(seed_columns, function(column) length(unique(grid[[column]][idx])) == 1L, logical(1L)))
  }, logical(1L))
  expect_true(all(pair_consistency))

  expect_identical(defaults$preproc$fit_scope, "train_only")
  expect_equal(defaults$runtime$workers, 20L)
  expect_equal(defaults$runtime$threads, 1L)
  expect_equal(defaults$pipeline$inference$mcmc$n_burn, 1000L)
  expect_equal(defaults$pipeline$inference$mcmc$n_mcmc, 3000L)
  expect_equal(defaults$pipeline$inference$mcmc$progress_every, 50L)
  expect_true(defaults$pipeline$inference$mcmc$init_from_vb)
  expect_false(defaults$pipeline$outputs$keep_draws)
  expect_false(defaults$pipeline$outputs$keep_mcmc_vb_init)
  expect_false(defaults$pipeline$outputs$save_forecast_objects)
  expect_false(defaults$pipeline$outputs$retain_full_rds_on_failure)
})

test_that("source identity and staged launch gates are explicit", {
  continuity_path <- file.path(
    repo_root, "reports", "qdesn_mcmc_validation",
    "qdesn_dynamic_fitforecast_v2_500obs_mcmc_dynamic_seedrepair_v1",
    "materialization", "source_identity_continuity_audit.csv"
  )
  skip_if_not(file.exists(continuity_path), "campaign has not been materialized")
  continuity <- utils::read.csv(continuity_path, check.names = FALSE)
  expect_equal(nrow(continuity), 4L)
  expect_true(all(continuity$all_hashes_and_scenario_match))

  pipeline <- paste(readLines(file.path(
    repo_root, "validation", "fitforecast_v2", "scripts",
    "run_qdesn_mcmc_dynamic_seedrepair_v1_pipeline.sh"
  ), warn = FALSE), collapse = "\n")
  expect_match(pipeline, "WORKERS=20", fixed = TRUE)
  expect_match(pipeline, "OPENBLAS_NUM_THREADS=1", fixed = TRUE)
  expect_match(pipeline, "getconf _NPROCESSORS_ONLN", fixed = TRUE)
  expect_match(pipeline, "taskset -c", fixed = TRUE)
  expect_match(pipeline, "FULL_CONFIRMATION_APPROVED=FALSE", fixed = TRUE)
  expect_match(pipeline, "ARTICLE_PROMOTION_APPROVED=FALSE", fixed = TRUE)
  expect_false(grepl("5000", pipeline, fixed = TRUE))
  expect_false(grepl("20000", pipeline, fixed = TRUE))

  launcher <- paste(readLines(file.path(
    repo_root, "validation", "fitforecast_v2", "scripts",
    "launch_qdesn_mcmc_dynamic_seedrepair_v1.sh"
  ), warn = FALSE), collapse = "\n")
  expect_match(launcher, "validation/qdesn-mcmc-dynamic-seedrepair-v1-1.0.0", fixed = TRUE)
  expect_match(launcher, "upstream mismatch", fixed = TRUE)
})

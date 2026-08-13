repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                           winslash = "/", mustWork = TRUE)
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "qdesn_lower_tail_cellwise_mcmc_v1.R"))
stub <- file.path(repo_root, "config", "validation", qdesn_ltcv1_stage)
materialization_root <- Sys.getenv(
  "QDESN_LTCV1_MATERIALIZATION_ROOT",
  unset = file.path(
    repo_root, "reports", "shared_fitforecast_v2_orchestration",
    "qdesn_lower_tail_cellwise_mcmc_v1_materialization"
  )
)

testthat::test_that("v6 authority resolves ten cell-specific lower-tail targets", {
  targets <- qdesn_ssv2_read_csv(paste0(stub, "_target_cells.csv"))
  testthat::expect_equal(nrow(targets), 10L)
  testthat::expect_equal(sum(targets$tier == "A"), 6L)
  testthat::expect_equal(sum(targets$tier == "B"), 4L)
  testthat::expect_equal(anyDuplicated(targets$target_cell_id), 0L)
  testthat::expect_setequal(targets$likelihood_target, c("al", "exal"))
  testthat::expect_true(all(targets$tau %in% c(.05, .25)))
  testthat::expect_true(all(file.exists(file.path(repo_root, targets$parent_request_path))))
  testthat::expect_identical(
    unique(qdesn_ltcv1_interface(repo_root)$source_registry_hash_value),
    qdesn_ssv2_registry_hash
  )
})

testthat::test_that("candidate profiles are per-cell, history-aware, and capacity-safe", {
  targets <- qdesn_ssv2_read_csv(paste0(stub, "_target_cells.csv"))
  parents <- qdesn_ssv2_read_csv(paste0(stub, "_parent_controls.csv"))
  profiles <- qdesn_ssv2_read_csv(paste0(stub, "_candidate_profiles.csv"))
  history <- qdesn_ssv2_read_csv(paste0(stub, "_history_signature_ledger.csv"))
  testthat::expect_equal(nrow(parents), 10L)
  testthat::expect_equal(nrow(profiles), 80L)
  testthat::expect_true(all(table(profiles$target_cell_id) == 8L))
  testthat::expect_equal(anyDuplicated(profiles$candidate_id), 0L)
  testthat::expect_false(any(profiles$profile_signature %in% history$profile_signature))
  testthat::expect_true(all(profiles$effective_readout_dimension <= 900L))
  testthat::expect_true(any(profiles$max_alpha >= .95))
  testthat::expect_true(any(profiles$D >= 3L))
  testthat::expect_true(any(profiles$m >= 90L))
  testthat::expect_setequal(unique(profiles$target_cell_id), targets$target_cell_id)
  testthat::expect_setequal(
    unique(profiles$selection_arm),
    c("local_tau_lower", "local_tau_upper", "local_readout_memory",
      "local_input_memory", "mechanism_slow", "mechanism_persistent",
      "history_gap_maximin", "history_boundary_maximin")
  )
})

testthat::test_that("source and stage contracts are frozen", {
  cfg <- yaml::read_yaml(paste0(stub, "_sources.yaml"))
  roles <- vapply(cfg$replicates, function(x) as.character(x$role), character(1L))
  testthat::expect_identical(cfg$generation$TT_warmup, 2000L)
  testthat::expect_identical(cfg$generation$TT_main, 10000L)
  testthat::expect_identical(cfg$generation$TT_total, 12000L)
  testthat::expect_equal(sum(roles == "discovery"), 2L)
  testthat::expect_equal(sum(roles == "replication"), 1L)
  testthat::expect_equal(sum(roles == "sealed_holdout"), 4L)
  testthat::expect_identical(qdesn_ltcv1_budget("tier_a_discovery")$n_burn, 1000L)
  testthat::expect_identical(qdesn_ltcv1_budget("tier_a_discovery")$n_mcmc, 3000L)
  testthat::expect_identical(qdesn_ltcv1_budget("tier_a_confirmation")$n_mcmc, 20000L)
})

testthat::test_that("materialized plans preserve AL and explicit exAL M0 dispatch", {
  plans <- lapply(c("smoke", "calibration", "tier_a_discovery"), function(stage) {
    qdesn_ssv2_read_csv(file.path(materialization_root, paste0(stage, "_plan.csv")))
  })
  testthat::expect_equal(vapply(plans, nrow, integer(1L)), c(2L, 6L, 108L))
  discovery <- plans[[3L]]
  testthat::expect_equal(length(unique(discovery$target_cell_id)), 6L)
  testthat::expect_true(all(table(discovery$target_cell_id) == 18L))
  jobs <- lapply(discovery$config_path, qdesn_ssv2_read_json)
  exal <- vapply(jobs, function(job) job$likelihood_target == "exal", logical(1L))
  testthat::expect_true(any(exal) && any(!exal))
  testthat::expect_true(all(vapply(jobs[exal], function(job) {
    identical(job$config$inference$mcmc$slice$core_update_mode,
              qdesn_ssv2_method_id)
  }, logical(1L))))
  testthat::expect_true(all(vapply(jobs[!exal], function(job) {
    !identical(job$config$inference$mcmc$slice$core_update_mode,
               qdesn_ssv2_method_id)
  }, logical(1L))))
})

testthat::test_that("jobs separate randomness and enforce storage-light output", {
  plan <- qdesn_ssv2_read_csv(file.path(
    materialization_root, "tier_a_discovery_plan.csv"
  ))
  cell <- plan[plan$target_cell_id == plan$target_cell_id[[1L]], , drop = FALSE]
  jobs <- lapply(cell$config_path[1:4], qdesn_ssv2_read_json)
  testthat::expect_true(all(vapply(jobs, function(job) {
    identical(job$seed_contract_mode,
              "paired_target_cell_panel_independent_of_source_and_candidate")
  }, logical(1L))))
  testthat::expect_equal(length(unique(vapply(
    jobs, function(job) as.integer(job$config$desn$seed), integer(1L)
  ))), 1L)
  testthat::expect_true(all(vapply(jobs, function(job) {
    !isTRUE(job$config$outputs$keep_draws) &&
      !isTRUE(job$config$outputs$keep_mcmc_vb_init) &&
      !isTRUE(job$config$outputs$save_forecast_objects) &&
      !isTRUE(job$config$outputs$retain_full_rds_on_failure) &&
      !isTRUE(job$study_contract$posterior_recycled_as_prior)
  }, logical(1L))))
})

testthat::test_that("launchers are scoped, resumable, and stop after discovery", {
  pipeline <- readLines(file.path(
    repo_root, "validation", "fitforecast_v2", "scripts",
    "run_qdesn_lower_tail_cellwise_mcmc_v1_pipeline.sh"
  ), warn = FALSE)
  text <- paste(pipeline, collapse = "\n")
  testthat::expect_match(text, qdesn_ltcv1_branch, fixed = TRUE)
  testthat::expect_match(text, "WORKERS=\"${WORKERS:-20}\"", fixed = TRUE)
  testthat::expect_match(text, "AUTO_STOP_AFTER_TIER_A_DISCOVERY=TRUE", fixed = TRUE)
  testthat::expect_match(text, "same_run_tag_resumes_completed_jobs", fixed = TRUE)
  testthat::expect_match(
    text, 'STATE_ROOT="$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/',
    fixed = TRUE
  )
  testthat::expect_match(text, "trap on_error ERR", fixed = TRUE)
  testthat::expect_false(grepl("/home/jaguir26/local/src", text, fixed = TRUE))
  testthat::expect_match(
    text,
    "printf 'Lower-tail cellwise MCMC v1 discovery complete: %s\\n'",
    fixed = TRUE
  )
  testthat::expect_false(grepl(
    'cat "Lower-tail cellwise MCMC v1 discovery complete:', text, fixed = TRUE
  ))

  replication <- paste(readLines(file.path(
    repo_root, "validation", "fitforecast_v2", "scripts",
    "run_qdesn_lower_tail_cellwise_mcmc_v1_replication.sh"
  ), warn = FALSE), collapse = "\n")
  testthat::expect_match(replication, "tier_a_replication_preflight", fixed = TRUE)
  testthat::expect_match(replication, "tier_a_replication_plan.csv", fixed = TRUE)
  testthat::expect_match(replication, "same_run_tag_resumes_completed_jobs", fixed = TRUE)
  testthat::expect_match(
    replication, "72-job sealed plan materialized;not launched", fixed = TRUE
  )
  testthat::expect_false(grepl("tier_a_sealed_workers", replication, fixed = TRUE))
  testthat::expect_false(grepl("/home/jaguir26/local/src", replication, fixed = TRUE))

  advance <- paste(readLines(file.path(
    repo_root, "validation", "fitforecast_v2", "scripts",
    "advance_qdesn_lower_tail_cellwise_mcmc_v1.R"
  ), warn = FALSE), collapse = "\n")
  testthat::expect_match(advance, "source_count >= minimum_sources", fixed = TRUE)
  testthat::expect_match(advance, "minimum_sources = 3L", fixed = TRUE)
  testthat::expect_match(advance, "x$mean_paired_ratio < 1", fixed = TRUE)
  testthat::expect_match(advance, "x$median_paired_ratio < 1", fixed = TRUE)
  testthat::expect_match(advance, "x$sources_improved >= 3L", fixed = TRUE)
  testthat::expect_match(advance, "launch_approved = FALSE", fixed = TRUE)
  testthat::expect_match(advance, "Confirmation exceeds the 24-chain cap", fixed = TRUE)
})

testthat::test_that("replication handoff is paired, independent, and gated", {
  adaptive_root <- file.path(dirname(materialization_root), "adaptive")
  required <- c(
    "tier_a_discovery_gate.csv", "advance_after_tier_a_discovery.json",
    "tier_a_replication_ranking.csv", "tier_a_replication_plan.csv"
  )
  testthat::skip_if_not(all(file.exists(file.path(adaptive_root, required))))
  plan <- qdesn_ssv2_read_csv(file.path(adaptive_root, "tier_a_replication_plan.csv"))
  ranking <- qdesn_ssv2_read_csv(file.path(
    adaptive_root, "tier_a_replication_ranking.csv"
  ))
  testthat::expect_equal(nrow(plan), 24L)
  testthat::expect_true(all(table(plan$target_cell_id) == 4L))
  testthat::expect_identical(unique(plan$source_id), "dev11")
  testthat::expect_identical(unique(plan$source_role), "replication")
  testthat::expect_identical(unique(plan$reservoir_seed_id), "r02")
  testthat::expect_equal(nrow(ranking), 18L)
  testthat::expect_true(all(table(ranking$target_cell_id) == 3L))
})

testthat::test_that("sealed handoff uses untouched sources and remains confirmation-gated", {
  adaptive_root <- file.path(dirname(materialization_root), "adaptive")
  required <- c(
    "tier_a_replication_gate.csv", "advance_after_tier_a_replication.json",
    "tier_a_sealed_ranking.csv", "tier_a_sealed_plan.csv"
  )
  testthat::skip_if_not(all(file.exists(file.path(adaptive_root, required))))
  plan <- qdesn_ssv2_read_csv(file.path(adaptive_root, "tier_a_sealed_plan.csv"))
  ranking <- qdesn_ssv2_read_csv(file.path(adaptive_root, "tier_a_sealed_ranking.csv"))
  testthat::expect_equal(nrow(plan), 72L)
  testthat::expect_true(all(table(plan$target_cell_id) == 12L))
  testthat::expect_true(all(table(plan$target_cell_id, plan$source_id) == 3L))
  testthat::expect_setequal(unique(plan$source_id), c(
    "dev12", "dev13", "dev14", "dev15"
  ))
  testthat::expect_identical(unique(plan$source_role), "sealed_holdout")
  testthat::expect_identical(unique(plan$reservoir_seed_id), "r03")
  testthat::expect_equal(nrow(ranking), 12L)
  testthat::expect_true(all(table(ranking$target_cell_id) == 2L))

  sealed <- paste(readLines(file.path(
    repo_root, "validation", "fitforecast_v2", "scripts",
    "run_qdesn_lower_tail_cellwise_mcmc_v1_sealed.sh"
  ), warn = FALSE), collapse = "\n")
  testthat::expect_match(sealed, "tier_a_sealed_handoff_verification", fixed = TRUE)
  testthat::expect_match(sealed, "tier_a_sealed_plan.csv", fixed = TRUE)
  testthat::expect_match(sealed, "same_run_tag_resumes_completed_jobs", fixed = TRUE)
  testthat::expect_match(sealed, "confirmation not launched", fixed = TRUE)
  testthat::expect_match(sealed, "article v6 unchanged", fixed = TRUE)
  testthat::expect_false(grepl("tier_a_confirmation_workers", sealed, fixed = TRUE))
  testthat::expect_false(grepl("/home/jaguir26/local/src", sealed, fixed = TRUE))
})

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/", mustWork = TRUE
)
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "qdesn_postm0_legacy_recheck_v1.R"))
stub <- file.path(repo_root, "config", "validation", qdesn_plrv1_stage)
materialization_root <- Sys.getenv(
  "QDESN_PLRV1_MATERIALIZATION_ROOT",
  file.path(repo_root, "reports", "shared_fitforecast_v2_orchestration",
            "qdesn_postm0_legacy_recheck_v1_materialization")
)

testthat::test_that("frozen history is typed by inference era", {
  audit <- qdesn_plrv1_history_audit(repo_root)
  testthat::expect_equal(nrow(audit$rows), 9268L)
  testthat::expect_equal(nrow(audit$signatures), 2398L)
  testthat::expect_true(any(audit$rows$evidence_class == "pre_m0_vb"))
  testthat::expect_true(any(
    audit$rows$evidence_class == "pre_m0_mcmc_sampler_confounded"
  ))
  testthat::expect_false(any(audit$rows$eligible_as_negative_m0_evidence))
})

testthat::test_that("M0 same-design relaunch established material sampler gains", {
  ledger <- qdesn_ssv2_read_csv(file.path(
    repo_root, "validation", "fitforecast_v2", "promotions",
    "qdesn_dqlm_500obs_trainonly_article_v4_exal_m0_20260809",
    "metric_decision_ledger.csv"
  ))
  testthat::expect_equal(nrow(ledger), 27L)
  testthat::expect_equal(sum(grepl("^PROMOTE_M0", ledger$decision)), 22L)
  testthat::expect_true(all(ledger$ratio_m0_to_base[
    grepl("^PROMOTE_M0", ledger$decision)
  ] < 1))
})

testthat::test_that("five targets and exact historical candidates are frozen", {
  targets <- qdesn_ssv2_read_csv(paste0(stub, "_target_cells.csv"))
  profiles <- qdesn_ssv2_read_csv(paste0(stub, "_candidate_profiles.csv"))
  postm0 <- qdesn_ssv2_read_csv(paste0(stub, "_postm0_signature_coverage.csv"))
  history <- qdesn_ssv2_read_csv(paste0(stub, "_historical_evidence_rows.csv"))
  testthat::expect_setequal(targets$target_cell_id, qdesn_plrv1_target_ids)
  testthat::expect_true(all(targets$likelihood_target == "exal"))
  testthat::expect_true(all(file.exists(file.path(
    repo_root, targets$parent_metric_path
  ))))
  testthat::expect_equal(
    unname(vapply(file.path(repo_root, targets$parent_metric_path),
                  qdesn_ssv2_sha256, character(1L))),
    targets$parent_metric_sha256
  )
  metric_evidence <- lapply(
    file.path(repo_root, targets$parent_metric_path), qdesn_ssv2_read_csv
  )
  testthat::expect_true(all(vapply(metric_evidence, nrow, integer(1L)) == 1L))
  testthat::expect_setequal(
    vapply(metric_evidence, `[[`, character(1L), "target_cell_id"),
    targets$target_cell_id
  )
  testthat::expect_equal(nrow(profiles), 40L)
  testthat::expect_true(all(table(profiles$target_cell_id) == 8L))
  testthat::expect_true(all(profiles$profile_signature %in% history$profile_signature))
  testthat::expect_false(any(
    profiles$profile_signature %in% postm0$profile_signature
  ))
  testthat::expect_true(all(profiles$historical_evidence_class %in% c(
    "pre_m0_vb_all_primary_win",
    "pre_m0_mcmc_sampler_confounded_ranked"
  )))
})

testthat::test_that("fresh source seeds do not overlap earlier lower-tail sources", {
  current <- qdesn_ssv2_read_csv(paste0(stub, "_source_seed_contract.csv"))
  old <- qdesn_ssv2_read_csv(file.path(
    repo_root, "config", "validation",
    "qdesn_dynamic_fitforecast_v2_500obs_lower_tail_cellwise_mcmc_v1_source_seed_contract.csv"
  ))
  testthat::expect_equal(nrow(current), 21L)
  testthat::expect_equal(
    anyDuplicated(c(current$latent_seed, current$noise_seed)), 0L
  )
  testthat::expect_length(intersect(
    c(current$latent_seed, current$noise_seed),
    c(old$latent_seed, old$noise_seed)
  ), 0L)
  testthat::expect_setequal(current$source_id, paste0("dev", 30:36))
})

testthat::test_that("materialized jobs enforce exact M0 and storage-light output", {
  paths <- file.path(materialization_root, c(
    "smoke_plan.csv", "calibration_plan.csv", "tier_a_discovery_plan.csv"
  ))
  testthat::expect_true(all(file.exists(paths)))
  plans <- lapply(paths, qdesn_ssv2_read_csv)
  testthat::expect_equal(vapply(plans, nrow, integer(1L)), c(2L, 5L, 90L))
  jobs <- lapply(unlist(lapply(plans, `[[`, "config_path"), use.names = FALSE),
                 qdesn_ssv2_read_json)
  testthat::expect_true(all(vapply(jobs, function(job) {
    identical(job$schema_version,
              "qdesn_postm0_legacy_recheck_v1_job_v1") &&
      identical(job$config$inference$likelihood_family, "exal") &&
      identical(job$config$inference$mcmc$slice$core_update_mode,
                qdesn_ssv2_method_id) &&
      isTRUE(job$study_contract$exact_M0_required) &&
      !isTRUE(job$study_contract$pre_m0_negative_evidence_veto) &&
      !isTRUE(job$config$outputs$keep_draws) &&
      !isTRUE(job$config$outputs$keep_mcmc_vb_init) &&
      !isTRUE(job$config$outputs$save_forecast_objects) &&
      !isTRUE(job$config$outputs$retain_full_rds_on_failure)
  }, logical(1L))))
  historical_d1 <- jobs[vapply(jobs, function(job) {
    identical(as.integer(job$profile$D), 1L) &&
      identical(as.character(job$profile$n_tilde), "NA")
  }, logical(1L))]
  testthat::expect_gt(length(historical_d1), 0L)
  recovered <- lapply(historical_d1, qdesn_ssv2_profile_from_job)
  testthat::expect_true(all(vapply(recovered, function(profile) {
    identical(profile$n_tilde[[1L]], "") &&
    is.finite(profile$effective_readout_dimension[[1L]]) &&
      profile$effective_readout_dimension[[1L]] <=
        qdesn_ssv2_max_effective_readout_dimension
  }, logical(1L))))
  binary <- list.files(materialization_root,
                       pattern = "[.](rds|rda|RData)$", recursive = TRUE,
                       full.names = TRUE, ignore.case = TRUE)
  testthat::expect_length(binary, 0L)
})

testthat::test_that("tracked provenance closes over inherited execution code", {
  tracked <- qdesn_plrv1_tracked_manifest(repo_root)
  required <- file.path("validation", "fitforecast_v2", c(
    "R/independent_exal_m0_structural_screen_v2.R",
    "R/qdesn_lower_tail_cellwise_mcmc_v1.R",
    "R/qdesn_postm0_legacy_recheck_v1.R",
    "scripts/recover_qdesn_postm0_legacy_recheck_v1_replication_closeout.R",
    "tests/testthat/test-independent-exal-m0-structural-screen-v2.R",
    "tests/testthat/test-qdesn-postm0-legacy-recheck-v1.R"
  ))
  testthat::expect_true(all(required %in% tracked$relative_path))
  testthat::expect_equal(anyDuplicated(tracked$relative_path), 0L)
  testthat::expect_true(all(tracked$bytes > 0))
  testthat::expect_true(all(nchar(tracked$sha256) == 64L))
})

testthat::test_that("launcher is resource-gated and stops before replication", {
  pipeline <- paste(readLines(file.path(
    repo_root, "validation", "fitforecast_v2", "scripts",
    "run_qdesn_postm0_legacy_recheck_v1_pipeline.sh"
  ), warn = FALSE), collapse = "\n")
  advance <- paste(readLines(file.path(
    repo_root, "validation", "fitforecast_v2", "scripts",
    "advance_qdesn_postm0_legacy_recheck_v1.R"
  ), warn = FALSE), collapse = "\n")
  testthat::expect_match(pipeline, "wait_for_resources", fixed = TRUE)
  testthat::expect_match(pipeline, "WORKERS must be between 1 and 20", fixed = TRUE)
  testthat::expect_match(pipeline, "replication waits for review", fixed = TRUE)
  testthat::expect_match(advance, "explicit_human_approval", fixed = TRUE)
  testthat::expect_match(advance, "15-chain cap", fixed = TRUE)
  testthat::expect_false(grepl("/home/jaguir26/local/src", pipeline, fixed = TRUE))
  staged <- paste(readLines(file.path(
    repo_root, "validation", "fitforecast_v2", "scripts",
    "run_qdesn_postm0_legacy_recheck_v1_stage.sh"
  ), warn = FALSE), collapse = "\n")
  testthat::expect_match(staged, "EXPECTED_JOBS=20", fixed = TRUE)
  testthat::expect_match(staged, "EXPECTED_JOBS=60", fixed = TRUE)
  testthat::expect_match(staged, "Launch requires synchronized HEAD", fixed = TRUE)
  testthat::expect_match(staged, "CLOSEOUT_ONLY=TRUE", fixed = TRUE)
  testthat::expect_match(staged, "workers_bypassed", fixed = TRUE)
  testthat::expect_match(
    staged, "matching_config_hash", fixed = TRUE
  )
  testthat::expect_match(
    staged, "${STAGE}_verification\" FAILED", fixed = TRUE
  )
  testthat::expect_match(staged, "${STAGE}_advance\" FAILED", fixed = TRUE)
  launcher <- paste(readLines(file.path(
    repo_root, "validation", "fitforecast_v2", "scripts",
    "launch_qdesn_postm0_legacy_recheck_v1_stage.sh"
  ), warn = FALSE), collapse = "\n")
  testthat::expect_match(launcher, ">> '$STDOUT_LOG' 2>&1", fixed = TRUE)
  verifier <- paste(readLines(file.path(
    repo_root, "validation", "fitforecast_v2", "scripts",
    "verify_qdesn_postm0_legacy_recheck_v1.R"
  ), warn = FALSE), collapse = "\n")
  testthat::expect_match(verifier, "tracked_dependency_coverage", fixed = TRUE)
  testthat::expect_match(verifier, "replication_evidence_frozen", fixed = TRUE)
})

testthat::test_that("forecast-first confirmation ignores mixing grades", {
  rows <- data.frame(
    target_cell_id = rep("exal_gausmix_t0p25", 3L),
    candidate_id = rep("plrv1_exal_gausmix_t0p25_08_576957a0bd", 3L),
    chain_id = 1:3,
    metric = rep("forecast_qtrue_mae_H1000", 3L),
    value = c(3.0, 3.1, 3.2), current_value = rep(3.39645452464865, 3L),
    status = rep("SUCCESS", 3L),
    signoff_grade = c("PASS", "WARN", "FAIL"),
    stringsAsFactors = FALSE
  )
  decision <- qdesn_plrv1_forecast_first_decision(rows)
  testthat::expect_true(decision$promote)
  testthat::expect_false(decision$diagnostics_used_as_promotion_gate)
  testthat::expect_equal(decision$signoff_grades_observed, "FAIL;PASS;WARN")
  testthat::expect_equal(
    decision$decision,
    "PROMOTE_STRICT_FORECAST_MAE_GAIN_DIAGNOSTICS_RECORDED"
  )
  rows$value <- c(3.4, 3.5, 3.6)
  decision <- qdesn_plrv1_forecast_first_decision(rows)
  testthat::expect_false(decision$promote)
  testthat::expect_equal(decision$decision,
                         "NO_CANONICAL_FORECAST_GAIN_RETAIN_V6")
})

testthat::test_that("forecast-first confirmation retains execution gates", {
  rows <- data.frame(
    target_cell_id = rep("exal_gausmix_t0p25", 3L),
    candidate_id = rep("plrv1_exal_gausmix_t0p25_08_576957a0bd", 3L),
    chain_id = 1:3,
    metric = rep("forecast_qtrue_mae_H1000", 3L),
    value = c(2.0, 2.1, 2.2), current_value = rep(3.39645452464865, 3L),
    status = c("SUCCESS", "FAIL", "SUCCESS"),
    signoff_grade = c("PASS", "FAIL", "WARN"),
    stringsAsFactors = FALSE
  )
  decision <- qdesn_plrv1_forecast_first_decision(rows)
  testthat::expect_false(decision$promote)
  testthat::expect_equal(decision$decision, "INVALID_EXECUTION_NO_PROMOTION")
})

testthat::test_that("forecast-first launcher is explicit and bounded", {
  path <- file.path(repo_root, "validation", "fitforecast_v2", "scripts",
                    "run_qdesn_postm0_legacy_recheck_v1_confirmation.sh")
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")
  testthat::expect_match(text, "QDESN_PLRV1_FORECAST_CONFIRMATION_APPROVED",
                         fixed = TRUE)
  testthat::expect_match(text, "WORKERS must be 1..3", fixed = TRUE)
  testthat::expect_match(text, "diagnostics recorded but not gated", fixed = TRUE)
})

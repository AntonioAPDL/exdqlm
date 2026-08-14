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
  binary <- list.files(materialization_root,
                       pattern = "[.](rds|rda|RData)$", recursive = TRUE,
                       full.names = TRUE, ignore.case = TRUE)
  testthat::expect_length(binary, 0L)
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
})

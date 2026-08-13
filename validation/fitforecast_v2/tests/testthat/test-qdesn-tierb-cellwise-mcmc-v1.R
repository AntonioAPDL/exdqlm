repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                           winslash = "/", mustWork = TRUE)
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "qdesn_tierb_cellwise_mcmc_v1.R"))
stub <- file.path(repo_root, "config", "validation", qdesn_tbcv1_stage)
materialization_root <- Sys.getenv(
  "QDESN_TBCV1_MATERIALIZATION_ROOT",
  unset = file.path(
    repo_root, "reports", "shared_fitforecast_v2_orchestration",
    "qdesn_tierb_cellwise_mcmc_v1_materialization"
  )
)

testthat::test_that("v6 authority resolves only the four open Tier-B cells", {
  targets <- qdesn_ssv2_read_csv(paste0(stub, "_target_cells.csv"))
  testthat::expect_equal(nrow(targets), 4L)
  testthat::expect_true(all(targets$tier == "B"))
  testthat::expect_true(all(targets$likelihood_target == "al"))
  testthat::expect_setequal(targets$family, c("laplace", "gausmix"))
  testthat::expect_setequal(targets$tau, c(.05, .25))
  testthat::expect_true(all(targets$objective_metric == "fit_qtrue_rmse"))
  testthat::expect_equal(anyDuplicated(targets$target_cell_id), 0L)
  testthat::expect_true(all(file.exists(file.path(repo_root, targets$parent_request_path))))
  testthat::expect_identical(
    unique(qdesn_tbcv1_interface(repo_root)$source_registry_hash_value),
    qdesn_ssv2_registry_hash
  )
})

testthat::test_that("candidate designs distinguish admitted-unrun and new signatures", {
  targets <- qdesn_ssv2_read_csv(paste0(stub, "_target_cells.csv"))
  parents <- qdesn_ssv2_read_csv(paste0(stub, "_parent_controls.csv"))
  profiles <- qdesn_ssv2_read_csv(paste0(stub, "_candidate_profiles.csv"))
  history <- qdesn_ssv2_read_csv(paste0(stub, "_history_signature_ledger.csv"))
  allowlist <- qdesn_ssv2_read_csv(paste0(stub, "_configured_unrun_allowlist.csv"))
  testthat::expect_equal(nrow(parents), 4L)
  testthat::expect_equal(nrow(profiles), 32L)
  testthat::expect_true(all(table(profiles$target_cell_id) == 8L))
  testthat::expect_equal(anyDuplicated(profiles$candidate_id), 0L)
  testthat::expect_equal(nrow(allowlist), 16L)
  admitted <- profiles$history_disposition ==
    "admitted_configured_unrun_not_evaluated"
  testthat::expect_equal(sum(admitted), 16L)
  testthat::expect_false(any(
    profiles$profile_signature[!admitted] %in% history$profile_signature
  ))
  testthat::expect_setequal(unique(profiles$selection_arm), c(
    "local_tau_lower", "local_tau_upper", "local_readout_memory",
    "local_input_memory", "coupled_tau_input_memory",
    "coupled_tau_readout_memory", "local_alpha_rho_bridge",
    "shallow_high_alpha_sentinel"
  ))
  testthat::expect_true(all(profiles$effective_readout_dimension <= 900L))
  testthat::expect_true(all(table(
    profiles$target_cell_id[profiles$selection_arm == "shallow_high_alpha_sentinel"]
  ) == 1L))
  testthat::expect_true(all(profiles$max_alpha[
    profiles$selection_arm == "shallow_high_alpha_sentinel"
  ] >= .40))
  testthat::expect_setequal(unique(profiles$target_cell_id), targets$target_cell_id)
})

testthat::test_that("source and stage contracts are frozen", {
  cfg <- yaml::read_yaml(paste0(stub, "_sources.yaml"))
  roles <- vapply(cfg$replicates, function(x) as.character(x$role), character(1L))
  testthat::expect_identical(cfg$generation$TT_warmup, 2000L)
  testthat::expect_identical(cfg$generation$TT_main, 10000L)
  testthat::expect_identical(cfg$generation$TT_total, 12000L)
  testthat::expect_identical(cfg$generation$period, 90L)
  testthat::expect_equal(sum(roles == "discovery"), 3L)
  testthat::expect_equal(sum(roles == "replication"), 1L)
  testthat::expect_equal(sum(roles == "sealed_holdout"), 4L)
  testthat::expect_identical(qdesn_tbcv1_budget("tier_b_discovery")$n_burn, 1000L)
  testthat::expect_identical(qdesn_tbcv1_budget("tier_b_discovery")$n_mcmc, 3000L)
  testthat::expect_identical(qdesn_tbcv1_budget("tier_b_confirmation")$n_mcmc, 20000L)
})

testthat::test_that("materialized plans are AL-only, paired, and storage-light", {
  manifest <- qdesn_ssv2_read_json(file.path(
    materialization_root, "materialization_manifest.json"
  ))
  testthat::expect_identical(
    as.integer(manifest$counts$source_authority_binary_files), 64L
  )
  testthat::expect_identical(
    as.integer(manifest$counts$fitted_model_binary_files), 0L
  )
  plans <- lapply(c("smoke", "calibration", "tier_b_discovery"), function(stage) {
    qdesn_ssv2_read_csv(file.path(materialization_root, paste0(stage, "_plan.csv")))
  })
  testthat::expect_equal(vapply(plans, nrow, integer(1L)), c(2L, 4L, 108L))
  discovery <- plans[[3L]]
  testthat::expect_equal(length(unique(discovery$target_cell_id)), 4L)
  testthat::expect_true(all(table(discovery$target_cell_id) == 27L))
  testthat::expect_setequal(unique(discovery$source_id), c("dev16", "dev17", "dev18"))
  testthat::expect_true(all(table(discovery$target_cell_id, discovery$source_id) == 9L))
  jobs <- lapply(discovery$config_path, qdesn_ssv2_read_json)
  testthat::expect_true(all(vapply(jobs, function(job) {
    identical(job$likelihood_target, "al") &&
      !identical(job$config$inference$mcmc$slice$core_update_mode,
                 qdesn_ssv2_method_id) &&
      identical(job$study_contract$closed_tier_a_decision,
                qdesn_tbcv1_closed_tiera_decision) &&
      !isTRUE(job$config$outputs$keep_draws) &&
      !isTRUE(job$config$outputs$keep_mcmc_vb_init) &&
      !isTRUE(job$config$outputs$save_forecast_objects) &&
      !isTRUE(job$config$outputs$retain_full_rds_on_failure) &&
      !isTRUE(job$study_contract$posterior_recycled_as_prior)
  }, logical(1L))))
})

testthat::test_that("launch and advancement remain staged and resumable", {
  scripts <- file.path(repo_root, "validation", "fitforecast_v2", "scripts")
  pipeline <- paste(readLines(file.path(
    scripts, "run_qdesn_tierb_cellwise_mcmc_v1_pipeline.sh"
  ), warn = FALSE), collapse = "\n")
  advance <- paste(readLines(file.path(
    scripts, "advance_qdesn_tierb_cellwise_mcmc_v1.R"
  ), warn = FALSE), collapse = "\n")
  confirmation <- paste(readLines(file.path(
    scripts, "run_qdesn_tierb_cellwise_mcmc_v1_confirmation.sh"
  ), warn = FALSE), collapse = "\n")
  testthat::expect_match(pipeline, qdesn_tbcv1_branch, fixed = TRUE)
  testthat::expect_match(pipeline, "WORKERS=\"${WORKERS:-16}\"", fixed = TRUE)
  testthat::expect_match(pipeline, "CMD INSTALL --preclean --clean", fixed = TRUE)
  testthat::expect_match(pipeline, "PACKAGE_FINGERPRINT", fixed = TRUE)
  testthat::expect_match(pipeline, "AUTO_STOP_AFTER_TIER_B_DISCOVERY=TRUE", fixed = TRUE)
  testthat::expect_match(pipeline, "same_run_tag_resumes_completed_jobs", fixed = TRUE)
  testthat::expect_match(pipeline, "trap on_error ERR", fixed = TRUE)
  testthat::expect_match(advance, "minimum_sources = 3L", fixed = TRUE)
  testthat::expect_match(advance, "minimum_sources = 4L", fixed = TRUE)
  testthat::expect_match(advance, "x$mean_paired_ratio < 1", fixed = TRUE)
  testthat::expect_match(advance, "x$median_paired_ratio < 1", fixed = TRUE)
  testthat::expect_match(advance, "launch_approved = FALSE", fixed = TRUE)
  testthat::expect_match(advance, "Confirmation exceeds the 12-chain cap", fixed = TRUE)
  testthat::expect_match(confirmation, "QDESN_TBCV1_CONFIRMATION_APPROVED", fixed = TRUE)
  testthat::expect_false(grepl("/home/jaguir26/local/src", paste(
    pipeline, advance, confirmation
  ), fixed = TRUE))
})

testthat::test_that("worker resumes matching successes and prunes binary payloads", {
  worker <- paste(readLines(file.path(
    repo_root, "validation", "fitforecast_v2", "scripts",
    "run_qdesn_tierb_cellwise_mcmc_v1_chain.R"
  ), warn = FALSE), collapse = "\n")
  testthat::expect_match(worker, "skip completed job", fixed = TRUE)
  testthat::expect_match(worker, "config_sha256", fixed = TRUE)
  testthat::expect_match(worker, "binary_prune_manifest.csv", fixed = TRUE)
  testthat::expect_match(worker, "unlink(binary_paths, force = TRUE)", fixed = TRUE)
  testthat::expect_false(grepl("pkgload::load_all", worker, fixed = TRUE))
})

testthat::test_that("compact rolling summaries preserve exact reported metrics", {
  root <- tempfile("tbcv1-pruned-")
  dir.create(file.path(root, "tables"), recursive = TRUE)
  dir.create(file.path(root, "manifest"), recursive = TRUE)
  origins <- c(rep(34L, 10L), rep(33L, 20L))
  lead <- data.frame(
    forecast_lead = 1:30, n_origins_scored = origins,
    forecast_qtrue_mae = seq(1, 3.9, length.out = 30L),
    forecast_pinball_mean = seq(.1, .39, length.out = 30L)
  )
  qdesn_ssv2_write_csv(lead, file.path(root, "tables", "forecast_lead_metrics.csv"))
  qdesn_ssv2_write_json(list(
    forecast_rolling_origin_status = "PASS", forecast_rolling_origin_rows = 1000L,
    forecast_lead_metrics_rows = 30L, rolling_origin_ready_for_pruning = TRUE,
    required_lead_export_failure = FALSE
  ), file.path(root, "manifest", "output_retention.json"))
  testthat::expect_equal(
    qdesn_tbcv1_compact_forecast_metric_value(root, "forecast_qtrue_mae_H1000"),
    stats::weighted.mean(lead$forecast_qtrue_mae, origins)
  )
  testthat::expect_equal(
    qdesn_tbcv1_compact_forecast_metric_value(root, "forecast_check_loss_H1000"),
    stats::weighted.mean(lead$forecast_pinball_mean, origins)
  )
})

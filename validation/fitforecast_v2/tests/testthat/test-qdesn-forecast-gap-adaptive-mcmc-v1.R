repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/", mustWork = TRUE
)
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "qdesn_forecast_gap_adaptive_mcmc_v1.R"))
materialization_root <- Sys.getenv("QDESN_FGAV1_MATERIALIZATION_ROOT", "")

testthat::test_that("v7 authority resolves eight cell-specific forecast gaps", {
  targets <- qdesn_fgav1_targets(repo_root, freeze_requests = FALSE)
  roles <- qdesn_fgav1_metric_role_ledger(repo_root)
  testthat::expect_equal(nrow(targets), 8L)
  testthat::expect_equal(sum(targets$tier == "A"), 5L)
  testthat::expect_equal(sum(targets$tier == "B"), 3L)
  testthat::expect_equal(targets$candidates_per_cell, c(rep(12L, 5L), rep(8L, 3L)))
  testthat::expect_equal(nrow(roles), 14L)
  testthat::expect_equal(
    anyDuplicated(paste(roles$target_cell_id, roles$metric)), 0L
  )
  testthat::expect_true(all(roles$metric %in% qdesn_fgav1_promotion_metrics))
  testthat::expect_true(all(is.finite(roles$current_value)))
  testthat::expect_true(all(roles$relative_gap_pct > 0))
  testthat::expect_true(all(nzchar(roles$authority_candidate_id)))
})

testthat::test_that("the MCMC budgets and telemetry match the frozen protocol", {
  testthat::expect_equal(
    unname(unlist(qdesn_fgav1_budget("smoke")[1:2])), c(4L, 4L)
  )
  testthat::expect_equal(
    unname(unlist(qdesn_fgav1_budget("calibration")[1:2])), c(200L, 500L)
  )
  testthat::expect_equal(
    unname(unlist(qdesn_fgav1_budget("discovery")[1:2])), c(1000L, 3000L)
  )
  testthat::expect_equal(
    unname(unlist(qdesn_fgav1_budget("sealed")[1:2])), c(2000L, 6000L)
  )
  testthat::expect_equal(
    unname(unlist(qdesn_fgav1_budget("confirmation")[1:2])), c(5000L, 20000L)
  )
})

testthat::test_that("materialized designs are diverse, bounded, and nonrepeating", {
  testthat::skip_if(!nzchar(materialization_root) || !dir.exists(materialization_root))
  stub <- file.path(repo_root, "config", "validation", qdesn_fgav1_stage)
  targets <- qdesn_ssv2_read_csv(paste0(stub, "_target_cells.csv"))
  profiles <- qdesn_ssv2_read_csv(paste0(stub, "_candidate_profiles.csv"))
  history <- qdesn_ssv2_read_csv(paste0(stub, "_history_signature_ledger.csv"))
  testthat::expect_equal(nrow(profiles), 84L)
  testthat::expect_equal(
    as.integer(table(factor(profiles$target_cell_id, levels = targets$target_cell_id))),
    as.integer(targets$candidates_per_cell)
  )
  testthat::expect_equal(anyDuplicated(paste(
    profiles$target_cell_id, profiles$profile_signature
  )), 0L)
  testthat::expect_false(any(profiles$profile_signature %in% history$profile_signature))
  testthat::expect_true(all(profiles$effective_readout_dimension <= 900L))
  testthat::expect_true(any(profiles$max_alpha >= .95))
  testthat::expect_true(any(profiles$min_alpha <= .01))
  testthat::expect_true(any(profiles$max_rho >= .98))
  testthat::expect_true(all(c(
    "compact_low_alpha", "compact_high_alpha", "lag_readout_heavy",
    "lag_reservoir_heavy", "history_boundary_maximin"
  ) %in% profiles$selection_arm))
})

testthat::test_that("source and initial plan cardinalities are exact", {
  testthat::skip_if(!nzchar(materialization_root) || !dir.exists(materialization_root))
  plans <- lapply(c("smoke", "calibration", "discovery"), function(stage) {
    qdesn_ssv2_read_csv(file.path(materialization_root, paste0(stage, "_plan.csv")))
  })
  testthat::expect_equal(vapply(plans, nrow, integer(1L)), c(2L, 8L, 184L))
  discovery <- plans[[3L]]
  testthat::expect_equal(sort(unique(discovery$source_id)), c("dev37", "dev38"))
  testthat::expect_equal(length(unique(discovery$target_cell_id)), 8L)
  testthat::expect_true(all(table(discovery$target_cell_id, discovery$source_id) %in%
                              c(9L, 13L)))
  testthat::expect_equal(anyDuplicated(discovery$job_id), 0L)
  testthat::expect_true(all(file.exists(discovery$config_path)))
})

testthat::test_that("all initial jobs enforce method, storage, and thread contracts", {
  testthat::skip_if(!nzchar(materialization_root) || !dir.exists(materialization_root))
  discovery <- qdesn_ssv2_read_csv(file.path(materialization_root, "discovery_plan.csv"))
  jobs <- lapply(discovery$config_path, qdesn_ssv2_read_json)
  testthat::expect_true(all(vapply(jobs, function(job) {
    likelihood <- as.character(job$likelihood_target)
    method_ok <- likelihood != "exal" || identical(
      as.character(job$config$inference$mcmc$slice$core_update_mode),
      qdesn_ssv2_method_id
    )
    method_ok && identical(as.integer(job$config$cpp$postpred_threads), 1L) &&
      identical(as.integer(job$config$telemetry$progress_every), 50L) &&
      identical(as.integer(job$config$telemetry$heartbeat_seconds), 1800L) &&
      !isTRUE(job$config$outputs$keep_draws) &&
      !isTRUE(job$config$outputs$keep_mcmc_vb_init) &&
      !isTRUE(job$config$outputs$save_forecast_objects) &&
      !isTRUE(job$study_contract$posterior_recycled_as_prior)
  }, logical(1L))))
})

testthat::test_that("the orchestrator automatically applies every hard gate", {
  scripts <- file.path(repo_root, "validation", "fitforecast_v2", "scripts")
  pipeline <- paste(readLines(file.path(
    scripts, "run_qdesn_forecast_gap_adaptive_mcmc_v1_pipeline.sh"
  ), warn = FALSE), collapse = "\n")
  advance <- paste(readLines(file.path(
    scripts, "advance_qdesn_forecast_gap_adaptive_mcmc_v1.R"
  ), warn = FALSE), collapse = "\n")
  testthat::expect_match(pipeline, 'WORKERS="${WORKERS:-20}"', fixed = TRUE)
  testthat::expect_match(pipeline, "run_stage discovery", fixed = TRUE)
  testthat::expect_match(pipeline, "run_stage replication", fixed = TRUE)
  testthat::expect_match(pipeline, "run_stage sealed", fixed = TRUE)
  testthat::expect_match(pipeline, "run_stage confirmation", fixed = TRUE)
  testthat::expect_match(pipeline, "MIN_MEMORY_GB", fixed = TRUE)
  testthat::expect_match(pipeline, "MIN_DISK_GB", fixed = TRUE)
  testthat::expect_match(advance, 'c("dev39", "dev40")', fixed = TRUE)
  testthat::expect_match(advance, 'c("dev41", "dev42", "dev43", "dev44")',
                         fixed = TRUE)
  testthat::expect_match(advance, "nrow(plan) != 64L", fixed = TRUE)
  testthat::expect_match(advance, "nrow(plan) != 96L", fixed = TRUE)
  testthat::expect_false(grepl("/home/jaguir26/local/src", pipeline, fixed = TRUE))
})

testthat::test_that("canonical closeout is metric-specific and diagnostic-descriptive", {
  scripts <- file.path(repo_root, "validation", "fitforecast_v2", "scripts")
  materializer <- paste(readLines(file.path(
    scripts, "materialize_qdesn_forecast_gap_adaptive_mcmc_v1_confirmation.R"
  ), warn = FALSE), collapse = "\n")
  closeout <- paste(readLines(file.path(
    scripts, "closeout_qdesn_forecast_gap_adaptive_mcmc_v1_confirmation.R"
  ), warn = FALSE), collapse = "\n")
  testthat::expect_match(materializer, "3L * nrow(combos)", fixed = TRUE)
  testthat::expect_match(materializer, "nrow(plan) > 42L", fixed = TRUE)
  testthat::expect_match(materializer, "5000L", fixed = TRUE)
  testthat::expect_match(materializer, "20000L", fixed = TRUE)
  testthat::expect_match(closeout, "mean(x$value) < x$current_value", fixed = TRUE)
  testthat::expect_match(closeout, "diagnostics_used_as_promotion_veto = FALSE",
                         fixed = TRUE)
  testthat::expect_match(closeout, "PROMOTE_STRICT_FORECAST_GAIN", fixed = TRUE)
  testthat::expect_match(closeout, "article_update_automatic = FALSE", fixed = TRUE)
})

testthat::test_that("pruned paths retain exact compact forecast metrics", {
  root <- tempfile("fgav1-pruned-")
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
    qdesn_fgav1_compact_forecast_metric_value(root, "forecast_qtrue_mae_H1000"),
    stats::weighted.mean(lead$forecast_qtrue_mae, origins)
  )
  testthat::expect_equal(
    qdesn_fgav1_compact_forecast_metric_value(root, "forecast_check_loss_H1000"),
    stats::weighted.mean(lead$forecast_pinball_mean, origins)
  )
})

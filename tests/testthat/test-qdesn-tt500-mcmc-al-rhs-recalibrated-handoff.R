qdesn_mcmc_alrhs_handoff_repo_path <- function(...) {
  root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  file.path(root, ...)
}

test_that("TT500 MCMC AL RHS recalibrated handoff is article-compatible and pinned", {
  skip_if_not_installed("jsonlite")

  promotion_id <- "qdesn_tt500_mcmc_al_rhs_recalibrated_authoritative_20260702"
  promotion_dir <- qdesn_mcmc_alrhs_handoff_repo_path(
    "validation", "fitforecast_v2", "promotions", promotion_id
  )
  summary_path <- file.path(promotion_dir, paste0(promotion_id, "_summary.csv"))
  manifest_path <- file.path(promotion_dir, paste0(promotion_id, "_manifest.json"))
  sources_path <- file.path(promotion_dir, paste0(promotion_id, "_sources.csv"))

  expect_true(file.exists(summary_path))
  expect_true(file.exists(manifest_path))
  expect_true(file.exists(sources_path))

  summary <- utils::read.csv(summary_path, stringsAsFactors = FALSE, check.names = FALSE)
  sources <- utils::read.csv(sources_path, stringsAsFactors = FALSE, check.names = FALSE)
  manifest <- jsonlite::fromJSON(manifest_path, simplifyVector = FALSE)

  expect_equal(nrow(summary), 9L)
  expect_equal(unique(summary$promotion_id), promotion_id)
  expect_equal(unique(summary$promotion_status), "authoritative_article_facing_diagnostic_qualified")
  expect_equal(unique(summary$diagnostic_qualification), "diagnostic_qualified_authoritative_mcmc_al_rhs_recalibrated")
  expect_equal(unique(summary$model_family), "qdesn")
  expect_equal(unique(summary$model_variant), "rhs_ns")
  expect_equal(unique(summary$model_key), "qdesn_al_rhs_ns")
  expect_equal(unique(summary$qdesn_likelihood), "al")
  expect_equal(unique(summary$method), "mcmc")
  expect_equal(unique(summary$inference), "mcmc")
  expect_equal(unique(summary$likelihood_family), "al")
  expect_equal(unique(summary$prior), "rhs_ns")
  expect_equal(sort(unique(summary$family)), c("gausmix", "laplace", "normal"))
  expect_equal(sort(unique(as.numeric(summary$tau))), c(0.05, 0.25, 0.5))
  expect_equal(unique(as.integer(summary$fit_size)), 500L)
  expect_equal(unique(as.integer(summary$effective_fit_size)), 500L)
  expect_equal(unique(summary$status), "SUCCESS")
  expect_true(all(summary$signoff_grade %in% c("PASS", "WARN")))
  expect_false(any(summary$signoff_grade == "FAIL"))
  expect_true(all(as.logical(summary$comparison_eligible)))

  expect_equal(unique(as.integer(summary$n_leads)), 30L)
  expect_equal(unique(as.integer(summary$n_origins_scored_total)), 1000L)
  expect_equal(unique(as.integer(summary$forecast_max_lead_configured)), 30L)
  expect_equal(unique(as.integer(summary$forecast_origin_stride)), 30L)
  expect_equal(unique(summary$forecast_protocol), "rolling_origin_no_refit_state_update")
  expect_equal(unique(as.integer(summary$train_start_source_index)), 8501L)
  expect_equal(unique(as.integer(summary$train_end_source_index)), 9000L)
  expect_equal(unique(as.integer(summary$forecast_origin_source_index)), 9000L)
  expect_equal(unique(as.integer(summary$forecast_block_start_source_index)), 9001L)
  expect_equal(unique(as.integer(summary$forecast_block_end_source_index)), 10000L)
  expect_equal(unique(summary$validation_branch), "validation/shared-fitforecast-v2-1.0.0")
  expect_equal(unique(summary$package_version), "1.0.0")
  expect_equal(
    unique(summary$source_registry_hash_value),
    "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
  )

  metric_cols <- c(
    "fit_qtrue_rmse", "fit_pinball_mean",
    "forecast_qtrue_mae_lead_weighted", "forecast_qtrue_rmse_lead_weighted",
    "forecast_pinball_mean_lead_weighted", "runtime_hours"
  )
  expect_true(all(is.finite(as.numeric(unlist(summary[metric_cols], use.names = FALSE)))))

  expect_true(all(sources$hash_verified))
  expect_equal(
    sources$observed_sha256[sources$source_id == "campaign_fit_summary"],
    "6c6ed171a392151cac33e90574fcd326f9ef23b91e2e0b81cfc74d23a9267585"
  )
  expect_equal(
    sources$observed_sha256[sources$source_id == "audit_summary"],
    "cb9a66fabbe01d348e83e0ca4695a5044dd56a5132aeaacf33da3ace8e9382e3"
  )
  expect_equal(
    sources$observed_sha256[sources$source_id == "audit_root"],
    "9d238e39412fc73e0ac30af94f77fda51d3fc73c5697f216d83ef6cc57170ad5"
  )

  expect_equal(manifest$promotion_id, promotion_id)
  expect_equal(manifest$diagnostic_qualification, "diagnostic_qualified_authoritative_mcmc_al_rhs_recalibrated")
  expect_true(isTRUE(manifest$run_evidence$strict_ready))
  expect_equal(manifest$run_evidence$audit_success, 9L)
  expect_equal(manifest$run_evidence$audit_fail, 0L)
  expect_equal(manifest$run_evidence$forbidden_binary_count_total, 0L)
  expect_equal(manifest$storage_policy$forbidden_binary_count, 0L)
  expect_equal(manifest$artifacts$summary_csv$sha256, unname(tools::sha256sum(summary_path)))
  expect_equal(manifest$artifacts$sources_csv$sha256, unname(tools::sha256sum(sources_path)))
})

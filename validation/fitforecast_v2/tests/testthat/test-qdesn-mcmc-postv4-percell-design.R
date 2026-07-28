test_that("Q-DESN MCMC post-v4 per-cell design is review-gated and reproducible", {
  root <- ffv2_repo_root()
  promotion_id <- "qdesn_tt500_mcmc_postv4_percell_design_20260727"
  source_hash <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
  promo_root <- file.path(root, "validation", "fitforecast_v2", "promotions", promotion_id)

  expect_true(dir.exists(promo_root))

  read_table <- function(suffix) {
    read.csv(
      file.path(promo_root, paste0(promotion_id, suffix)),
      check.names = FALSE,
      stringsAsFactors = FALSE
    )
  }

  summary <- read_table("_summary.csv")
  diagnostic <- read_table("_unresolved_cell_diagnostic.csv")
  history <- read_table("_historical_candidate_pool.csv")
  metric_winners <- read_table("_historical_metric_winners_by_cell.csv")
  coherent <- read_table("_historical_coherent_candidates_by_cell.csv")
  design <- read_table("_candidate_arm_design.csv")
  checklist <- read_table("_launch_review_checklist.csv")
  manifest <- jsonlite::read_json(
    file.path(promo_root, paste0(promotion_id, "_manifest.json")),
    simplifyVector = TRUE
  )
  file_manifest <- read.csv(
    file.path(promo_root, "file_manifest.csv"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  source_manifest <- read.csv(
    file.path(promo_root, "source_manifest.csv"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  expect_equal(nrow(summary), 1L)
  expect_equal(summary$parent_closeout_id, "qdesn_tt500_mcmc_metricgap_v4_targeted_closeout_20260727")
  expect_equal(summary$parent_envelope_id, "qdesn_dqlm_500obs_mcmc_metric_envelope_20260727")
  expect_identical(summary$source_registry_hash_value, source_hash)
  expect_equal(summary$historical_ledger_files, 6L)
  expect_gte(summary$historical_candidate_rows, 700L)
  expect_equal(summary$unresolved_cells, 15L)
  expect_equal(summary$fit_dominated_cells, 7L)
  expect_equal(summary$forecast_dominated_cells, 8L)
  expect_equal(summary$lower_quantile_primary_goal_cells, 11L)
  expect_equal(summary$metric_winner_rows, 45L)
  expect_equal(summary$candidate_arm_rows, 90L)
  expect_equal(summary$candidate_arms_per_cell, 6L)
  expect_identical(summary$launch_status, "prepared_not_launched_review_required")
  expect_identical(summary$article_update_decision, "do_not_update_article_from_design_only")

  expect_equal(nrow(diagnostic), 15L)
  expect_equal(nrow(unique(diagnostic[c("model_variant", "family", "tau", "fit_size")])), 15L)
  expect_equal(as.integer(table(diagnostic$dominant_gap_class)[["fit_dominated"]]), 7L)
  expect_equal(as.integer(table(diagnostic$dominant_gap_class)[["forecast_dominated"]]), 8L)
  expect_equal(as.integer(table(diagnostic$scientific_priority)[["primary_lower_quantile_goal"]]), 11L)
  expect_true(all(diagnostic$source_registry_hash_value == source_hash))

  expect_gte(nrow(history), 700L)
  expect_true(all(history$model_variant %in% c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns")))
  expect_true(all(history$fit_size == 500L))

  expect_equal(nrow(metric_winners), 45L)
  metric_key <- paste(metric_winners$model_variant, metric_winners$family, metric_winners$tau, metric_winners$fit_size, sep = "|")
  expect_true(all(table(metric_key) == 3L))
  expect_setequal(
    unique(metric_winners$metric),
    c("fit_qtrue_rmse", "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000")
  )
  expect_true(all(is.finite(metric_winners$historical_best_value)))

  expect_equal(nrow(coherent), 45L)
  coherent_key <- paste(coherent$model_variant, coherent$family, coherent$tau, coherent$fit_size, sep = "|")
  expect_true(all(table(coherent_key) == 3L))
  expect_true(all(coherent$rank_within_cell %in% 1:3))

  expect_equal(nrow(design), 90L)
  expect_equal(nrow(unique(design[c("model_variant", "family", "tau", "fit_size")])), 15L)
  design_key <- paste(design$model_variant, design$family, design$tau, design$fit_size, sep = "|")
  expect_true(all(table(design_key) == 6L))
  expect_setequal(
    unique(design$arm_role),
    c(
      "replay_primary_metric_winner",
      "replay_coherent_best",
      "local_tau0_3em7",
      "local_tau0_1em7",
      "axis_specific_breakout_a",
      "axis_specific_breakout_b"
    )
  )
  expect_true(all(design$launch_status == "not_materialized_not_launched_review_required"))
  expect_true(all(design$review_gate == "requires_explicit_user_approval_before_orchestrator_materialization"))
  expect_true(all(is.na(design$blocked_reason) | design$blocked_reason == ""))
  expect_true(all(design$launch_ready_after_review))
  expect_lte(max(design$p_over_n_tt500), 1.60)
  expect_lte(max(design$p_over_n_tt500), 0.80)
  expect_true(all(is.finite(design$rhs_tau0)))
  expect_true(all(design$rhs_tau0 > 0))
  expect_setequal(
    unique(design$rhs_tau0[design$arm_role == "local_tau0_3em7"]),
    3e-7
  )
  expect_setequal(
    unique(design$rhs_tau0[design$arm_role == "local_tau0_1em7"]),
    1e-7
  )

  expect_equal(nrow(checklist), 10L)
  expect_equal(as.integer(table(checklist$status)[["complete"]]), 5L)
  expect_equal(as.integer(table(checklist$status)[["pending_review"]]), 5L)

  expect_identical(manifest$promotion_id, promotion_id)
  expect_identical(manifest$source_registry_hash_value, source_hash)
  expect_equal(as.integer(manifest$n_unresolved_cells), 15L)
  expect_equal(as.integer(manifest$n_candidate_arm_rows), 90L)
  expect_identical(manifest$launch_status, "prepared_not_launched_review_required")

  expect_true(all(file.exists(file_manifest$path)))
  expect_equal(unname(tools::sha256sum(file_manifest$path)), file_manifest$sha256)
  expect_true(all(file.exists(source_manifest$path)))
  expect_equal(unname(tools::sha256sum(source_manifest$path)), source_manifest$sha256)

  heavy <- list.files(
    promo_root,
    pattern = "[.](rds|rda|RData)$|__design[.]rds$",
    recursive = TRUE,
    full.names = TRUE
  )
  expect_length(heavy, 0L)

  design_text <- paste(capture.output(str(list(
    summary = summary,
    diagnostic = diagnostic,
    metric_winners = metric_winners,
    coherent = coherent,
    design = design,
    manifest = manifest
  ))), collapse = "\n")
  expect_false(grepl("/home/jaguir26/local/src", design_text, fixed = TRUE))
  expect_false(grepl("Article-Q-DESN", design_text, fixed = TRUE))
})

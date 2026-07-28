test_that("Q-DESN MCMC post-v4 per-cell closeout is complete and non-repeating", {
  root <- ffv2_repo_root()
  promotion_id <- "qdesn_tt500_mcmc_postv4_percell_closeout_20260728"
  run_tag <- "qdesn-tt500-mcmc-postv4-percell-full-20260727__git-786905f"
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
  execution <- read_table("_execution_audit.csv")
  storage <- read_table("_storage_audit.csv")
  candidates <- read_table("_postv4_candidate_metrics.csv")
  target_best <- read_table("_target_cell_best.csv")
  target_promotions <- read_table("_target_metric_promotions.csv")
  metric_promotions <- read_table("_metricwise_promotions.csv")
  metric_comparison <- read_table("_metricwise_comparison_all.csv")
  envelope <- read_table("_refreshed_article_envelope.csv")
  unresolved <- read_table("_unresolved_cells.csv")
  next_screen <- read_table("_next_screen_handoff.csv")
  nonrepeat <- read_table("_nonrepeat_audit.csv")
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
  expect_equal(summary$planned_roots, 90L)
  expect_equal(summary$completed_roots, 90L)
  expect_equal(summary$failed_roots, 0L)
  expect_equal(summary$iter_like_min, 8000L)
  expect_equal(summary$iter_like_max, 8000L)
  expect_equal(summary$signoff_pass, 10L)
  expect_equal(summary$signoff_warn, 27L)
  expect_equal(summary$signoff_fail, 53L)
  expect_equal(summary$target_cells, 15L)
  expect_equal(summary$candidates_per_cell, 6L)
  expect_equal(summary$target_cell_improvements, 3L)
  expect_equal(summary$metricwise_promotions, 4L)
  expect_equal(summary$metricwise_promotion_cells, 3L)
  expect_equal(summary$refreshed_envelope_rows, 36L)
  expect_equal(summary$unresolved_cells, 15L)
  expect_equal(summary$storage_heavy_files_found, 0L)
  expect_identical(summary$source_registry_hash_value, source_hash)
  expect_identical(
    summary$recommendation,
    "closeout_ready_promote_material_metricwise_gains_only_do_not_repeat_postv4_surface"
  )

  expect_equal(execution$fit_summary_rows, 90L)
  expect_equal(execution$forecast_h1000_rows, 90L)
  expect_equal(execution$root_success, 90L)
  expect_equal(execution$root_failed, 0L)
  expect_equal(execution$iter_like_min, 8000L)
  expect_equal(execution$iter_like_max, 8000L)
  expect_equal(execution$metricwise_promotions, 4L)
  expect_equal(execution$storage_heavy_files_found, 0L)

  expect_equal(nrow(candidates), 90L)
  expect_equal(nrow(target_best), 15L)
  expect_equal(nrow(target_promotions), 3L)
  expect_equal(nrow(metric_promotions), 4L)
  expect_equal(nrow(metric_comparison), 108L)
  expect_equal(nrow(envelope), 36L)
  expect_equal(nrow(unresolved), 15L)
  expect_equal(nrow(next_screen), 15L)
  expect_equal(nrow(unique(envelope[c("model_variant", "family", "tau", "fit_size")])), 36L)

  target_cell_keys <- paste(
    candidates$model_variant,
    candidates$family,
    sprintf("%.8f", candidates$tau),
    candidates$fit_size,
    sep = "|"
  )
  expect_equal(length(unique(target_cell_keys)), 15L)
  expect_true(all(table(target_cell_keys) == 6L))
  expect_true(all(candidates$run_tag == run_tag))
  expect_true(all(candidates$source_registry_hash_value == source_hash))
  expect_true(all(candidates$iter_like == 8000L))

  expected_metric_promotion_keys <- c(
    "qdesn_exal_rhs_ns|gausmix|0.25000000|fit_qtrue_rmse",
    "qdesn_exal_rhs_ns|gausmix|0.25000000|forecast_qtrue_mae_H1000",
    "qdesn_exal_rhs_ns|normal|0.05000000|fit_qtrue_rmse",
    "qdesn_exal_rhs_ns|normal|0.50000000|forecast_qtrue_mae_H1000"
  )
  observed_metric_promotion_keys <- paste(
    metric_promotions$model_variant,
    metric_promotions$family,
    sprintf("%.8f", metric_promotions$tau),
    metric_promotions$metric,
    sep = "|"
  )
  expect_setequal(observed_metric_promotion_keys, expected_metric_promotion_keys)
  expect_true(all(metric_promotions$changed))
  expect_true(all(metric_promotions$materially_changed))
  expect_true(all(metric_promotions$improvement > metric_promotions$materiality_tolerance))
  expect_true(all(metric_promotions$refreshed_run_tag == run_tag))

  expected_target_promotion_keys <- c(
    "qdesn_exal_rhs_ns|gausmix|0.25000000|forecast_mae",
    "qdesn_exal_rhs_ns|normal|0.05000000|fit",
    "qdesn_exal_rhs_ns|normal|0.50000000|forecast_mae"
  )
  observed_target_promotion_keys <- paste(
    target_promotions$model_variant,
    target_promotions$family,
    sprintf("%.8f", target_promotions$tau),
    target_promotions$primary_gap,
    sep = "|"
  )
  expect_setequal(observed_target_promotion_keys, expected_target_promotion_keys)
  expect_true(all(target_promotions$target_improvement > target_promotions$target_materiality_tolerance))

  expect_true(all(storage$heavy_files_found == 0L))
  expect_true(all(storage$action == "keep_no_cleanup_needed"))

  expect_true("qdesn_metricgap_v4_targeted_mcmc_screen" %in% nonrepeat$source_key)
  expect_true("qdesn_postv4_percell_mcmc_screen" %in% nonrepeat$source_key)
  guarded <- nonrepeat[nonrepeat$source_key %in% c(
    "qdesn_metricgap_v4_targeted_mcmc_screen",
    "qdesn_postv4_percell_mcmc_screen"
  ), , drop = FALSE]
  expect_true(all(guarded$action == "do_not_repeat_as_broad_screen"))
  expect_true(all(grepl("do_not_repeat", next_screen$repeat_guard, fixed = TRUE)))
  expect_setequal(
    unique(next_screen$next_screen_role),
    c(
      "confirm_postv4_improvement_before_more_surface_search",
      "new_hypothesis_required_do_not_repeat_postv4_surface"
    )
  )

  expect_identical(manifest$promotion_id, promotion_id)
  expect_identical(manifest$parent_promotion_id, "qdesn_tt500_mcmc_metricgap_v4_targeted_closeout_20260727")
  expect_identical(manifest$source_registry_hash_value, source_hash)
  expect_equal(as.integer(manifest$n_postv4_candidates), 90L)
  expect_equal(as.integer(manifest$n_target_cell_improvements), 3L)
  expect_equal(as.integer(manifest$n_metricwise_promotions), 4L)
  expect_equal(as.integer(manifest$n_metricwise_promotion_cells), 3L)
  expect_equal(as.integer(manifest$n_refreshed_envelope_rows), 36L)
  expect_equal(as.integer(manifest$storage_heavy_files_found), 0L)
  expect_identical(
    manifest$nonrepeat_guard,
    "do_not_relaunch_metricgap_v4_or_postv4_surfaces_without_a_new_hypothesis"
  )

  expect_true(all(file.exists(file_manifest$path)))
  expect_equal(unname(tools::sha256sum(file_manifest$path)), file_manifest$sha256)
  expect_true(all(file.exists(source_manifest$path)))
  expect_equal(unname(tools::sha256sum(source_manifest$path)), source_manifest$sha256)

  closeout_text <- paste(capture.output(str(list(
    summary = summary,
    execution = execution,
    candidates = candidates,
    envelope = envelope,
    unresolved = unresolved,
    next_screen = next_screen,
    manifest = manifest
  ))), collapse = "\n")
  expect_false(grepl("/home/jaguir26/local/src", closeout_text, fixed = TRUE))
  expect_false(grepl("/data/jaguir26/local/src/Article-Q-DESN", closeout_text, fixed = TRUE))
})

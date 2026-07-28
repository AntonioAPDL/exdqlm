test_that("Q-DESN MCMC metric-gap v4 closeout is complete and promotion-scoped", {
  root <- ffv2_repo_root()
  promotion_id <- "qdesn_tt500_mcmc_metricgap_v4_targeted_closeout_20260727"
  run_tag <- "qdesn-tt500-mcmc-metricgap-v4-targeted-full-20260727__git-4f42747"
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
  candidates <- read_table("_v4_candidate_metrics.csv")
  target_best <- read_table("_target_cell_best.csv")
  target_promotions <- read_table("_target_metric_promotions.csv")
  metric_promotions <- read_table("_metricwise_promotions.csv")
  envelope <- read_table("_refreshed_article_envelope.csv")
  unresolved <- read_table("_unresolved_cells.csv")
  next_screen <- read_table("_next_screen_handoff.csv")
  manifest <- jsonlite::read_json(
    file.path(promo_root, paste0(promotion_id, "_manifest.json")),
    simplifyVector = TRUE
  )
  file_manifest <- read.csv(
    file.path(promo_root, "file_manifest.csv"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  expect_equal(nrow(summary), 1L)
  expect_equal(summary$planned_roots, 75L)
  expect_equal(summary$completed_roots, 75L)
  expect_equal(summary$failed_roots, 0L)
  expect_equal(summary$target_cells, 15L)
  expect_equal(summary$target_cell_improvements, 6L)
  expect_equal(summary$metricwise_promotions, 7L)
  expect_equal(summary$metricwise_promotion_cells, 6L)
  expect_equal(summary$refreshed_envelope_rows, 36L)
  expect_equal(summary$unresolved_cells, 15L)
  expect_equal(summary$storage_heavy_files_found, 0L)
  expect_identical(summary$source_registry_hash_value, source_hash)

  expect_equal(execution$fit_summary_rows, 75L)
  expect_equal(execution$forecast_h1000_rows, 75L)
  expect_equal(execution$root_success, 75L)
  expect_equal(execution$metricwise_promotions, 7L)
  expect_equal(execution$storage_heavy_files_found, 0L)

  expect_equal(nrow(candidates), 75L)
  expect_equal(nrow(target_best), 15L)
  expect_equal(nrow(target_promotions), 6L)
  expect_equal(nrow(metric_promotions), 7L)
  expect_equal(nrow(envelope), 36L)
  expect_equal(nrow(unresolved), 15L)
  expect_equal(nrow(next_screen), 15L)
  expect_equal(nrow(unique(envelope[c("model_variant", "family", "tau", "fit_size")])), 36L)
  expect_equal(
    as.integer(table(unresolved$metricgap_v4_status)[["improved_by_v4"]]),
    6L
  )
  expect_equal(
    as.integer(table(unresolved$metricgap_v4_status)[["not_improved_by_v4"]]),
    9L
  )

  target_cell_keys <- paste(
    candidates$model_variant,
    candidates$family,
    sprintf("%.8f", candidates$tau),
    candidates$fit_size,
    sep = "|"
  )
  expect_equal(length(unique(target_cell_keys)), 15L)
  expect_true(all(table(target_cell_keys) == 5L))
  expect_true(all(candidates$run_tag == run_tag))
  expect_true(all(candidates$source_registry_hash_value == source_hash))

  expected_metric_promotion_keys <- c(
    "qdesn_al_rhs_ns|gausmix|0.05000000|fit_qtrue_rmse",
    "qdesn_al_rhs_ns|gausmix|0.25000000|fit_qtrue_rmse",
    "qdesn_al_rhs_ns|gausmix|0.25000000|forecast_check_loss_H1000",
    "qdesn_al_rhs_ns|gausmix|0.50000000|forecast_qtrue_mae_H1000",
    "qdesn_exal_rhs_ns|gausmix|0.05000000|fit_qtrue_rmse",
    "qdesn_exal_rhs_ns|gausmix|0.25000000|forecast_qtrue_mae_H1000",
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
  expect_true(all(metric_promotions$improvement > 0))
  expect_true(all(metric_promotions$refreshed_run_tag == run_tag))

  expect_true(all(storage$heavy_files_found == 0L))
  expect_true(all(storage$action == "keep_no_cleanup_needed"))

  expect_identical(manifest$promotion_id, promotion_id)
  expect_identical(manifest$parent_promotion_id, "qdesn_dqlm_500obs_mcmc_metric_envelope_20260727")
  expect_identical(manifest$source_registry_hash_value, source_hash)
  expect_equal(as.integer(manifest$n_v4_candidates), 75L)
  expect_equal(as.integer(manifest$n_target_cell_improvements), 6L)
  expect_equal(as.integer(manifest$n_metricwise_promotions), 7L)
  expect_equal(as.integer(manifest$n_refreshed_envelope_rows), 36L)
  expect_equal(as.integer(manifest$storage_heavy_files_found), 0L)

  expect_true(all(file.exists(file_manifest$path)))
  observed_hash <- unname(tools::sha256sum(file_manifest$path))
  expect_equal(observed_hash, file_manifest$sha256)

  closeout_text <- paste(capture.output(str(list(
    summary = summary,
    execution = execution,
    candidates = candidates,
    envelope = envelope,
    unresolved = unresolved,
    manifest = manifest
  ))), collapse = "\n")
  expect_false(grepl("/home/jaguir26/local/src", closeout_text, fixed = TRUE))
})

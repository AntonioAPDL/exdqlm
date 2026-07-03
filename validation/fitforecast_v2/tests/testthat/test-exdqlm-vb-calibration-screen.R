test_that("VB calibration candidate registry is strict and canonical", {
  candidates <- ffv2_read_vb_calibration_candidates()
  expect_equal(nrow(candidates), 16L)
  expect_named(candidates, ffv2_required_vb_calibration_candidate_columns())
  expect_equal(anyDuplicated(candidates$candidate_id), 0L)
  expect_equal(anyDuplicated(candidates$calibration_id), 0L)
  expect_true(all(candidates$trend_C0_scale > 0))
  expect_true(all(candidates$seasonal_C0_scale > 0))
  expect_equal(candidates$df_value[[1L]], "0.98,0.98")
  expect_equal(candidates$dim_df[[1L]], "2,4")
})

test_that("VB calibration candidate registry rejects malformed candidates", {
  path <- tempfile(fileext = ".csv")
  utils::write.csv(
    data.frame(
      candidate_id = c("bad", "bad"),
      calibration_id = c("dup", "dup2"),
      trend_C0_scale = c(1, 2),
      seasonal_C0_scale = c(1, 2),
      df_value = c("0.98,0.98", "0.99,0.98"),
      dim_df = c("2,4", "2,4"),
      notes = c("one", "two"),
      stringsAsFactors = FALSE
    ),
    path,
    row.names = FALSE
  )
  expect_error(ffv2_read_vb_calibration_candidates(path), "candidate_id values must be unique")
})

ffv2_test_vb_screen_candidates <- function(path = tempfile(fileext = ".csv")) {
  utils::write.csv(
    data.frame(
      candidate_id = c("c00_baseline", "c01_diffuse"),
      calibration_id = c("test_c00", "test_c01"),
      trend_C0_scale = c(0.01, 100),
      seasonal_C0_scale = c(0.01, 1),
      df_value = c("0.98,0.98", "0.995,0.98"),
      dim_df = c("2,4", "2,4"),
      notes = c("baseline", "diffuse prior"),
      stringsAsFactors = FALSE
    ),
    path,
    row.names = FALSE
  )
  path
}

test_that("VB calibration screen dry-run expands only TT500 VB rows", {
  defaults <- ffv2_test_defaults()
  defaults <- ffv2_vb_screen_defaults(defaults, run_tag = "test_vb_screen")
  ffv2_test_write_sources(defaults)
  registry <- ffv2_collect_source_registry(defaults, require_sources = TRUE)
  candidates <- ffv2_read_vb_calibration_candidates(ffv2_test_vb_screen_candidates())
  manifest <- ffv2_prepare_vb_calibration_screen_manifest(
    defaults = defaults,
    registry = registry,
    candidates = candidates,
    run_root = tempfile("screen_run_"),
    dry_run = TRUE
  )
  expect_equal(nrow(registry), 9L)
  expect_equal(nrow(manifest), 36L)
  expect_true(all(as.integer(manifest$fit_size) == 500L))
  expect_true(all(as.character(manifest$inference) == "vb"))
  expect_true(all(as.character(manifest$phase) == "vb_full"))
  expect_true(all(as.character(manifest$validation_stage) == "fit-only"))
  expect_true(all(as.character(manifest$model_variant) %in% c("dqlm", "exdqlm")))
  expect_equal(anyDuplicated(manifest$spec_id), 0L)
  expect_equal(anyDuplicated(paste(manifest$source_cell_id, manifest$model_variant, manifest$candidate_id)), 0L)
  expect_equal(sum(as.logical(manifest$screen_sentinel)), 14L)
  expect_equal(length(unique(manifest$model_spec_hash)), 2L)
})

test_that("VB calibration screen writes configs and sentinel manifests", {
  defaults <- ffv2_test_defaults()
  defaults <- ffv2_vb_screen_defaults(defaults, run_tag = "test_vb_screen_write")
  ffv2_test_write_sources(defaults)
  registry <- ffv2_collect_source_registry(defaults, require_sources = TRUE)
  candidates <- ffv2_read_vb_calibration_candidates(ffv2_test_vb_screen_candidates())
  run_root <- tempfile("screen_run_")
  manifest <- ffv2_prepare_vb_calibration_screen_manifest(
    defaults = defaults,
    registry = registry,
    candidates = candidates,
    run_root = run_root,
    dry_run = FALSE
  )
  expect_true(file.exists(file.path(run_root, "manifests", "row_manifest.csv")))
  expect_true(file.exists(file.path(run_root, "manifests", "candidate_registry.csv")))
  expect_true(file.exists(file.path(run_root, "manifests", "sentinel_rows.csv")))
  expect_true(file.exists(file.path(run_root, "manifests", "sentinel_row_ids.txt")))
  selected <- manifest[manifest$candidate_id == "c01_diffuse", , drop = FALSE][1L, , drop = FALSE]
  cfg <- ffv2_read_json(selected$row_config_path[[1L]])
  expect_equal(cfg$candidate_id, "c01_diffuse")
  expect_equal(cfg$screen_stage, "fit_only_sentinel_screen")
  expect_equal(cfg$validation_stage, "fit-only")
  expect_equal(cfg$budget$vb$max_iter, 150L)
  expect_equal(cfg$budget$vb$n_samp, 5000L)
  expect_equal(cfg$models$calibration_id, "test_c01")
  expect_equal(cfg$models$trend_C0_scale, 100)
  expect_equal(cfg$models$seasonal_C0_scale, 1)
  expect_equal(cfg$df_value, "0.995,0.98")
  expect_match(cfg$spec_id, "exdqlm_dqlm__")
})

test_that("candidate provenance reaches metrics and shared interface schema", {
  expect_true(all(c("candidate_id", "screen_stage", "candidate_notes", "screen_sentinel") %in%
                    ffv2_shared_interface_columns()))
  cfg <- list(
    row_id = 1L, row_key = "row_0001", spec_id = "spec", run_tag = "run",
    scenario_id = "scenario", family = "normal", tau = 0.5, tau_label = "0p50",
    fit_size = 500L, model_variant = "dqlm", inference = "vb", phase = "vb_full",
    validation_stage = "fit-only", source_cell_id = "cell",
    series_wide_sha256 = "src", true_quantile_grid_sha256 = "truth", meta_sha256 = "meta",
    calibration_id = "cal", model_spec_hash = "hash", candidate_id = "c01",
    screen_stage = "fit_only_sentinel_screen", candidate_notes = "note", screen_sentinel = TRUE
  )
  metrics <- ffv2_row_metrics(
    config = cfg,
    fit_summary = ffv2_empty_path_summary("fit"),
    forecast_summary = ffv2_empty_path_summary("forecast"),
    runtime_sec = 1,
    status = "fit_done"
  )
  expect_equal(metrics$candidate_id[[1L]], "c01")
  expect_equal(metrics$screen_stage[[1L]], "fit_only_sentinel_screen")
  expect_true(metrics$screen_sentinel[[1L]])
})

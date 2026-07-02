test_that("dynamic model clock defaults preserve historical source-index behavior", {
  config <- list(
    train_start_source_index = 8501L,
    TT_warmup = 2000L
  )

  expect_equal(ffv2_model_clock_mode(config), "source_index_only")
  expect_equal(ffv2_model_clock_start_index(config), 8501L)
  expect_equal(ffv2_model_clock_offset(config), 0L)
})

test_that("post-warmup latent clock aligns source windows to generated latent time", {
  config <- list(
    train_start_source_index = 8501L,
    TT_warmup = 2000L,
    models = list(latent_clock_mode = "post_warmup_source_index")
  )

  expect_equal(ffv2_model_clock_mode(config), "post_warmup_source_index")
  expect_equal(ffv2_model_clock_start_index(config), 10501L)
  expect_equal(ffv2_model_clock_offset(config), 2000L)
})

test_that("explicit latent clock start is validated", {
  config <- list(
    train_start_source_index = 100L,
    TT_warmup = 20L,
    latent_clock_mode = "explicit",
    latent_clock_start_source_index = 222L
  )

  expect_equal(ffv2_model_clock_start_index(config), 222L)
  expect_error(
    ffv2_model_clock_start_index(list(train_start_source_index = 100L, latent_clock_mode = "explicit")),
    "requires latent_clock_start_source_index"
  )
  expect_error(
    ffv2_model_clock_start_index(list(train_start_source_index = 100L, latent_clock_mode = "bad-mode")),
    "latent_clock_mode must be one of"
  )
})

test_that("dynamic model builder uses corrected clock and block C0 scales", {
  base <- list(
    train_start_source_index = 4L,
    TT_warmup = 3L,
    period = 90L,
    harmonics = "1, 2",
    level0 = 10,
    slope0 = 2,
    harmonic1_amplitude = 0,
    harmonic1_phase = 0,
    harmonic2_amplitude = 0,
    harmonic2_phase = 0,
    C0_scale = 0.01,
    models = list(
      trend_C0_scale = 4,
      seasonal_C0_scale = 9
    )
  )

  old_model <- ffv2_build_dynamic_model(base, train_n = 2L)
  aligned <- base
  aligned$models$latent_clock_mode <- "post_warmup_source_index"
  aligned_model <- ffv2_build_dynamic_model(aligned, train_n = 2L)

  expect_equal(as.numeric(old_model$m0)[1:2], c(16, 2))
  expect_equal(as.numeric(aligned_model$m0)[1:2], c(22, 2))
  expect_equal(diag(aligned_model$C0)[1:2], c(4, 4))
  expect_equal(diag(aligned_model$C0)[3:6], rep(9, 4))
})

test_that("prepared manifests carry calibration and clock provenance", {
  defaults <- ffv2_test_defaults()
  defaults$models$calibration_id <- "clock-test"
  defaults$models$latent_clock_mode <- "post_warmup_source_index"
  defaults$models$trend_C0_scale <- 4
  defaults$models$seasonal_C0_scale <- 9
  ffv2_test_write_sources(defaults)
  registry <- ffv2_collect_source_registry(defaults, require_sources = TRUE)
  manifest <- ffv2_prepare_manifest(defaults, registry, dry_run = TRUE)

  expect_true(all(c(
    "calibration_id", "latent_clock_mode", "latent_clock_start_source_index",
    "latent_clock_offset", "trend_C0_scale", "seasonal_C0_scale",
    "df_value", "dim_df", "model_spec_hash", "base_spec_id"
  ) %in% names(manifest)))
  expect_true(all(manifest$calibration_id == "clock-test"))
  expect_true(all(manifest$latent_clock_mode == "post_warmup_source_index"))
  expect_true(all(as.integer(manifest$latent_clock_offset) == as.integer(manifest$TT_warmup)))
  expect_true(all(as.integer(manifest$latent_clock_start_source_index) ==
                    as.integer(manifest$train_start_source_index) + as.integer(manifest$TT_warmup)))
  expect_true(all(as.numeric(manifest$trend_C0_scale) == 4))
  expect_true(all(as.numeric(manifest$seasonal_C0_scale) == 9))
})

test_that("calibration knobs participate in atomic spec identity", {
  defaults <- ffv2_test_defaults()
  ffv2_test_write_sources(defaults)
  registry <- ffv2_collect_source_registry(defaults, require_sources = TRUE)
  manifest <- ffv2_prepare_manifest(defaults, registry, dry_run = TRUE)
  row <- manifest[1L, , drop = FALSE]

  changed_clock <- row
  changed_clock$latent_clock_start_source_index <- as.integer(row$latent_clock_start_source_index) + 1L
  changed_clock$model_spec_hash <- ffv2_sync_model_provenance(as.list(changed_clock))$model_spec_hash

  changed_c0 <- row
  changed_c0$trend_C0_scale <- as.numeric(row$trend_C0_scale) * 10
  changed_c0$model_spec_hash <- ffv2_sync_model_provenance(as.list(changed_c0))$model_spec_hash

  expect_false(identical(ffv2_make_spec_id(row), ffv2_make_spec_id(changed_clock)))
  expect_false(identical(ffv2_make_spec_id(row), ffv2_make_spec_id(changed_c0)))
})

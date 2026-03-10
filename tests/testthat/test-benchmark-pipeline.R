fixture_path <- function(...) {
  file.path(test_path("fixtures", "benchmarks"), ...)
}

test_that("Monash TSF parser reads series attributes and values", {
  parsed <- exdqlm:::bench_parse_tsf_file(fixture_path("sample_monash.tsf"))

  expect_s3_class(parsed$series_attributes, "data.table")
  expect_equal(nrow(parsed$series_attributes), 2L)
  expect_equal(parsed$series_attributes$series_name, c("S1", "S2"))
  expect_equal(parsed$series_attributes$horizon, c(3, 2))
  expect_equal(nrow(parsed$panel), 10L)
  expect_true(any(is.na(parsed$panel$y)))
})

test_that("Monash split builder creates tail validation and test segments", {
  meta_dt <- data.table::data.table(
    dataset = "toy_monash",
    source_family = "monash",
    series_id = "S1",
    forecast_horizon = 6L,
    n_obs = 30L
  )
  cfg <- list(split = list(monash_protocol = "train_val_test_tail", validation = list(min_train_points = 12L)))

  split_dt <- exdqlm:::bench_build_monash_splits(meta_dt, cfg)
  expect_equal(split_dt$train_end, 18L)
  expect_equal(split_dt$val_start, 19L)
  expect_equal(split_dt$val_end, 24L)
  expect_equal(split_dt$test_start, 25L)
  expect_equal(split_dt$test_end, 30L)
})

test_that("M4 builder preserves official test length and panel consistency", {
  td <- withr::local_tempdir()
  dir.create(file.path(td, "m4", "monthly"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(td, "m4", "metadata"), recursive = TRUE, showWarnings = FALSE)

  file.copy(fixture_path("m4_monthly_train.csv"), file.path(td, "m4", "monthly", "Monthly-train.csv"))
  file.copy(fixture_path("m4_monthly_test.csv"), file.path(td, "m4", "monthly", "Monthly-test.csv"))
  file.copy(fixture_path("m4_info.csv"), file.path(td, "m4", "metadata", "M4-info.csv"))

  context <- exdqlm:::bench_read_pipeline_config()
  context$paths$raw_m4 <- file.path(td, "m4")
  context$paths$repo_root <- td

  info_dt <- exdqlm:::bench_parse_m4_info(file.path(td, "m4", "metadata", "M4-info.csv"))
  freq_spec <- list(
    dataset = "m4_monthly",
    dataset_label = "M4 Monthly",
    benchmark_pool = "m4_official",
    frequency_label = "monthly",
    seasonal_period = 12L,
    train_url = "Monthly-train.csv",
    test_url = "Monthly-test.csv"
  )

  res <- exdqlm:::bench_build_m4_frequency("monthly", freq_spec, info_dt, context)

  expect_equal(nrow(res$metadata), 2L)
  expect_equal(nrow(res$splits), 2L)
  expect_equal(nrow(res$panel[res$panel$series_id == "M1", ]), 6L)
  expect_equal(res$splits[res$splits$series_id == "M1", ]$official_test_start, 5L)
  expect_equal(res$splits[res$splits$series_id == "M1", ]$official_test_end, 6L)
  expect_equal(res$metadata[res$metadata$series_id == "M1", ]$n_train, 4L)
  expect_equal(res$metadata[res$metadata$series_id == "M1", ]$n_test, 2L)
})

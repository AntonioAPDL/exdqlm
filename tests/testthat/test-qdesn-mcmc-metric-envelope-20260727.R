test_that("20260727 MCMC envelope adds coherent evidence without changing minima", {
  root <- normalizePath(
    file.path(testthat::test_path(), "..", ".."),
    winslash = "/",
    mustWork = TRUE
  )
  promotion_id <- "qdesn_dqlm_500obs_mcmc_metric_envelope_20260727"
  promotion_root <- file.path(
    root, "validation", "fitforecast_v2", "promotions", promotion_id
  )
  script <- file.path(
    root,
    "validation",
    "fitforecast_v2",
    "scripts",
    "materialize_qdesn_mcmc_metric_envelope_20260727.R"
  )
  expect_true(file.exists(script))
  expect_silent(parse(script))

  paths <- file.path(
    promotion_root,
    c(
      paste0(promotion_id, "_all_candidates.csv"),
      paste0(promotion_id, "_article_envelope.csv"),
      paste0(promotion_id, "_coherent_confirmation.csv"),
      paste0(promotion_id, "_metric_promotions.csv"),
      paste0(promotion_id, "_manifest.json"),
      "file_manifest.csv",
      "source_manifest.csv",
      "README.md"
    )
  )
  for (path in paths) expect_true(file.exists(path), info = path)

  candidates <- utils::read.csv(paths[[1L]], check.names = FALSE)
  envelope <- utils::read.csv(paths[[2L]], check.names = FALSE)
  confirmation <- utils::read.csv(paths[[3L]], check.names = FALSE)
  promotions <- utils::read.csv(paths[[4L]], check.names = FALSE)
  manifest <- jsonlite::read_json(paths[[5L]], simplifyVector = TRUE)

  expect_equal(nrow(candidates), 129L)
  expect_equal(nrow(envelope), 36L)
  expect_equal(nrow(confirmation), 1L)
  expect_equal(nrow(promotions), 0L)
  expect_identical(
    confirmation$candidate_id[[1L]],
    "mgv3_16_exal_local__full_5787212"
  )
  expect_true(confirmation$all_external_metrics_within_1p05[[1L]])
  expect_true(confirmation$all_metrics_stable_within_1p10[[1L]])
  expect_false(confirmation$fit_envelope_winner[[1L]])
  expect_false(confirmation$forecast_mae_envelope_winner[[1L]])
  expect_false(confirmation$forecast_check_envelope_winner[[1L]])
  expect_false(manifest$displayed_envelope_changed)
  expect_identical(as.integer(manifest$n_metric_promotions), 0L)
  expect_identical(as.integer(manifest$coherent_confirmation_rows), 1L)
  expect_identical(manifest$package_version, "1.0.0")

  files <- list.files(promotion_root, recursive = TRUE, full.names = TRUE)
  expect_false(any(grepl("[.](rds|rda|RData)$", files, ignore.case = TRUE)))
  text_files <- files[grepl("[.](csv|json|md)$", files, ignore.case = TRUE)]
  contents <- paste(
    unlist(lapply(text_files, readLines, warn = FALSE), use.names = FALSE),
    collapse = "\n"
  )
  expect_false(grepl("/home/jaguir26/local/src", contents, fixed = TRUE))
})

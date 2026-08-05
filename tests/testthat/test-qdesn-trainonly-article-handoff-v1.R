test_that("train-only article handoff scripts encode the frozen contract", {
  repo_root <- normalizePath(file.path("..", ".."), winslash = "/", mustWork = TRUE)
  materializer <- file.path(
    repo_root, "validation", "fitforecast_v2", "scripts",
    "promote_qdesn_500obs_trainonly_article_v1.R"
  )
  verifier <- file.path(
    repo_root, "validation", "fitforecast_v2", "scripts",
    "verify_qdesn_500obs_trainonly_article_v1.R"
  )

  expect_silent(parse(file = materializer))
  expect_silent(parse(file = verifier))
  text <- paste(readLines(materializer, warn = FALSE), collapse = "\n")
  expect_match(text, "qdesn_dqlm_500obs_trainonly_article_v1_20260805", fixed = TRUE)
  expect_match(text, "REPLACE_PRE_REPAIR_QDESN_ROWS_AND_EXCLUDE_UNCORRECTED_RIDGE", fixed = TRUE)
  expect_match(text, "preprocessing_scope <- \"train_only\"", fixed = TRUE)
  expect_match(text, "nrow(article) != 72L", fixed = TRUE)
  expect_match(text, "forecast_origin_source_index = 9000L", fixed = TRUE)
  expect_match(text, "forecast_max_lead_configured = 30L", fixed = TRUE)
  expect_match(text, "forecast_origin_stride = 30L", fixed = TRUE)
})

helper_path <- testthat::test_path("..", "..", "tools", "merge_reports", "20260305_dynamic_dgp_model_helpers.R")
if (!exists("as.exdqlm", mode = "function")) {
  pkgload::load_all(testthat::test_path("..", ".."), quiet = TRUE)
}
testthat::skip_if_not(file.exists(helper_path), "dynamic DGP helper script unavailable in test sandbox")
source(helper_path, local = TRUE)

test_that("dynamic DGP helper reconstructs lean family-qspec schema defaults", {
  params <- list(
    family = "gausmix",
    TT = 500L,
    TT_warmup = 2000L,
    period = 50L,
    alpha = 1e-4,
    normal_sigma = 3,
    laplace_scale = 3,
    gausmix_sigma = c(1, sqrt(5)),
    gausmix_weights = c(0.1, 0.9),
    gausmix_offset = 1,
    gpd_xi = 3
  )

  model <- build_dynamic_dgp_matched_model(params, TT = 24L)

  expect_s3_class(model, "exdqlm")
  expect_equal(dim(model$FF), c(6L, 1L))
  expect_equal(dim(model$GG), c(6L, 6L))
  expect_equal(as.numeric(model$m0), rep(0, 6L))
  expect_equal(model$C0, diag(25, 6L))
  expect_equal(model$GG[1:2, 1:2], matrix(c(1, 1, 0, 1), nrow = 2, byrow = TRUE))
})

test_that("dynamic DGP helper honors explicit prior metadata and no-trend structure", {
  params <- list(
    period = 12L,
    no_trend = TRUE,
    m0 = seq_len(6),
    C0_scale = 4
  )

  model <- build_dynamic_dgp_matched_model(params, TT = 18L)

  expect_equal(as.numeric(model$m0), seq_len(6))
  expect_equal(model$C0, diag(4, 6L))
  expect_equal(model$GG[1:2, 1:2], diag(2))
})

test_that("dynamic DGP helper fails loudly for malformed supplied prior fields", {
  expect_error(
    build_dynamic_dgp_matched_model(list(period = 12L, m0 = c(1, 2)), TT = 10L),
    "params\\$m0 must be a finite numeric vector of length 6"
  )
  expect_error(
    build_dynamic_dgp_matched_model(list(period = 12L, C0 = matrix(1, 2, 2)), TT = 10L),
    "params\\$C0 must be a finite 6x6 matrix"
  )
  expect_error(
    build_dynamic_dgp_matched_model(list(period = 12L, C0_scale = -1), TT = 10L),
    "params\\$C0_scale must be a positive finite scalar"
  )
})

test_that("dynamic fresh and resume scripts both use the shared lean-schema helper", {
  script_pipeline <- testthat::test_path("..", "..", "tools", "merge_reports", "20260305_vb_then_mcmc_pipeline.R")
  script_resume <- testthat::test_path("..", "..", "tools", "merge_reports", "20260305_resume_dynamic_mcmc_from_vb.R")
  helper_rel <- "tools/merge_reports/20260305_dynamic_dgp_model_helpers.R"

  skip_if_not(file.exists(script_pipeline), "dynamic pipeline script path unavailable in test sandbox")
  skip_if_not(file.exists(script_resume), "dynamic resume script path unavailable in test sandbox")

  pipeline_lines <- readLines(script_pipeline, warn = FALSE)
  resume_lines <- readLines(script_resume, warn = FALSE)

  expect_true(any(grepl(sprintf('source\\("%s"\\)', helper_rel), pipeline_lines)))
  expect_true(any(grepl(sprintf('source\\("%s"\\)', helper_rel), resume_lines)))
  expect_true(any(grepl("build_dynamic_dgp_matched_model\\(", pipeline_lines)))
  expect_true(any(grepl("build_dynamic_dgp_matched_model\\(", resume_lines)))
})

testthat::test_that("canonical-gap v9 promotion tooling freezes the intended contract", {
  repo <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                        winslash = "/", mustWork = TRUE)
  scripts <- file.path(repo, "validation", "fitforecast_v2", "scripts")
  promoter <- file.path(scripts, "promote_qdesn_canonical_gap_mcmc_v2.R")
  verifier <- file.path(scripts, "verify_qdesn_canonical_gap_mcmc_v2_promotion.R")

  testthat::expect_true(file.exists(promoter))
  testthat::expect_true(file.exists(verifier))
  testthat::expect_silent(parse(promoter))
  testthat::expect_silent(parse(verifier))

  promoter_text <- paste(readLines(promoter, warn = FALSE), collapse = "\n")
  testthat::expect_match(promoter_text, "diagnostics_used_as_promotion_gate = FALSE",
                         fixed = TRUE)
  testthat::expect_match(promoter_text, "c(0L, 2L, 2L)", fixed = TRUE)
  testthat::expect_match(promoter_text, "M0_v_collapsed_support_logit",
                         fixed = TRUE)
  testthat::expect_match(promoter_text, "fit_metric_policy = \"retain_v8_all_fit_metrics\"",
                         fixed = TRUE)
})

testthat::test_that("materialized canonical-gap v9 authority verifies independently", {
  repo <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                        winslash = "/", mustWork = TRUE)
  promotion_id <-
    "qdesn_dqlm_500obs_trainonly_article_v9_canonical_gap_20260821"
  promotion_dir <- file.path(repo, "validation", "fitforecast_v2", "promotions",
                             promotion_id)
  testthat::skip_if_not(dir.exists(promotion_dir))

  verifier <- file.path(
    repo, "validation", "fitforecast_v2", "scripts",
    "verify_qdesn_canonical_gap_mcmc_v2_promotion.R"
  )
  output <- system2(file.path(R.home("bin"), "Rscript"), verifier,
                    stdout = TRUE, stderr = TRUE)
  status <- attr(output, "status")
  if (is.null(status)) status <- 0L
  testthat::expect_equal(status, 0L,
                         info = paste(output, collapse = "\n"))
  testthat::expect_true(any(grepl("ARTICLE_CONSUMPTION=PASS", output, fixed = TRUE)))
})

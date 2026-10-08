repo <- normalizePath(Sys.getenv("ICAV2_REPO", "."), mustWork = TRUE)
source(file.path(repo,
  "validation/fitforecast_v2/R/independent_qdesn_training1000_runtime_v1.R"))
source(file.path(repo,
  "validation/fitforecast_v2/R/independent_qdesn_training1000_campaign_v1.R"))
source(file.path(repo,
  "validation/fitforecast_v2/R/independent_qdesn_sentinel_mechanism_v1.R"))
source(file.path(repo,
  "validation/fitforecast_v2/R/independent_qdesn_sentinel_mechanism_recovery_v1.R"))
source(file.path(repo,
  "validation/fitforecast_v2/R/independent_qdesn_causal_adaptation_v2.R"))

testthat::test_that("adaptation candidates have matched parent MCMC evidence", {
  testthat::expect_identical(icav2_candidates, c(
    "23eb3c867723c85379f2", "3a7a6653cb244f49813c",
    "1b071df459e29d74d20f"))
})

testthat::test_that("hash manifests reject directories", {
  root <- tempfile("hash-files-"); dir.create(root)
  file <- file.path(root, "one.txt"); writeLines("one", file)
  manifest <- file.path(root, "manifest.csv")
  iqt12_hash(file, manifest)
  testthat::expect_true(iqt12_verify(manifest))
  testthat::expect_error(iqt12_hash(root, manifest), "files only")
})

testthat::test_that("recursive closeout collection contains files only", {
  root <- tempfile("nested-files-"); dir.create(file.path(root, "a", "b"),
    recursive = TRUE)
  writeLines("x", file.path(root, "a", "b", "x.txt"))
  files <- icav2_files(root)
  testthat::expect_length(files, 1L)
  testthat::expect_false(any(file.info(files)$isdir))
})

testthat::test_that("online modes isolate declared update blocks", {
  testthat::expect_identical(icav2_mode_flags("beta_only"),
    list(update_rhs = FALSE, update_sigmagam = FALSE))
  testthat::expect_identical(icav2_mode_flags("beta_rhs"),
    list(update_rhs = TRUE, update_sigmagam = FALSE))
  testthat::expect_identical(icav2_mode_flags("full"),
    list(update_rhs = TRUE, update_sigmagam = TRUE))
  testthat::expect_error(icav2_mode_flags("unknown"), "Unknown")
})

testthat::test_that("adaptation rank uses paired folds and forecast MAE", {
  rows <- list(); add <- function(id, mode, fold, mae, check) {
    rows[[length(rows) + 1L]] <<- data.frame(candidate_id = id, mode = mode,
      fold = fold, metric = c("forecast_mae", "forecast_check_loss"),
      mean = c(mae, check))
  }
  for (fold in ism1_folds) {
    add("a", "static", fold, 3, 1)
    add("a", "beta_only", fold, if (fold == "S4") 3.1 else 2.5, 1.01)
  }
  rank <- icav2_adaptation_rank(do.call(rbind, rows))
  z <- rank[rank$mode == "beta_only", ]
  testthat::expect_equal(z$folds_improved, 3L)
  testthat::expect_lt(z$median_forecast_mae, z$static_median_forecast_mae)
})

testthat::test_that("bridge offsets are bounded inside each internal fold", {
  testthat::expect_identical(icav2_bridge_offsets, c(50L, 125L, 200L))
  for (fold in ism1_folds) {
    end <- c(S1 = 8000L, S2 = 8250L, S3 = 8500L, S4 = 8750L)[fold]
    testthat::expect_lte(max(end + icav2_bridge_offsets + 30L), 9000L)
  }
})

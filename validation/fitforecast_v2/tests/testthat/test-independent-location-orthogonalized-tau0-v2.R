testthat::test_that("location-orthogonalized V2 freezes cell-specific targets", {
  repo <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                        winslash = "/")
  source(file.path(
    repo, "validation", "fitforecast_v2", "R",
    "independent_location_orthogonalized_tau0_v2.R"
  ), local = TRUE)
  targets <- idol_v2_read_targets(repo)
  testthat::expect_equal(nrow(targets), 3L)
  testthat::expect_setequal(
    targets$target_cell_id,
    c("al_normal_t0p05", "al_normal_t0p50", "exal_normal_t0p50")
  )
  testthat::expect_true(all(targets$family == "normal"))
  testthat::expect_true(all(file.exists(file.path(repo, targets$parent_request_path))))
})

testthat::test_that("location-orthogonalized V2 uses distinct per-cell tau0 ladders", {
  repo <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                        winslash = "/")
  source(file.path(
    repo, "validation", "fitforecast_v2", "R",
    "independent_location_orthogonalized_tau0_v2.R"
  ), local = TRUE)
  ladder <- idol_v2_read_ladder(repo)
  by_cell <- split(ladder$tau0, ladder$target_cell_id)
  testthat::expect_equal(length(by_cell), 3L)
  testthat::expect_true(all(vapply(by_cell, length, integer(1L)) == 5L))
  testthat::expect_equal(
    sort(by_cell$al_normal_t0p05),
    sort(c(1e-10, 3e-10, 1e-9, 3e-9, 1e-8))
  )
  testthat::expect_equal(
    sort(by_cell$al_normal_t0p50),
    sort(c(1e-7, 1e-6, 1e-5, 1e-4, 3e-4))
  )
  testthat::expect_equal(
    sort(by_cell$exal_normal_t0p50),
    sort(c(3e-8, 3e-7, 3e-6, 3e-5, 3e-4))
  )
})

testthat::test_that("location-orthogonalized V2 is a non-global 33-profile design", {
  repo <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                        winslash = "/")
  source(file.path(
    repo, "validation", "fitforecast_v2", "R",
    "independent_location_orthogonalized_tau0_v2.R"
  ), local = TRUE)
  candidates <- idol_v2_build_candidates(repo)
  testthat::expect_equal(nrow(candidates), 33L)
  testthat::expect_true(all(table(candidates$target_cell_id) == 11L))
  testthat::expect_equal(sum(candidates$selection_arm == "C0_parent"), 3L)
  testthat::expect_equal(sum(candidates$selection_arm == "O1_orthogonalized"), 15L)
  testthat::expect_equal(
    sum(candidates$selection_arm == "O2_orthogonalized_svd"), 15L
  )
  testthat::expect_equal(anyDuplicated(candidates$candidate_id), 0L)
  testthat::expect_equal(anyDuplicated(candidates$exact_signature), 0L)
})

testthat::test_that("location-orthogonalized V2 freezes staged MCMC budgets", {
  repo <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                        winslash = "/")
  source(file.path(
    repo, "validation", "fitforecast_v2", "R",
    "independent_location_orthogonalized_tau0_v2.R"
  ), local = TRUE)
  testthat::expect_equal(idol_v2_budget("screen")$n_mcmc, 4000L)
  testthat::expect_equal(idol_v2_budget("replication")$n_mcmc, 7500L)
  testthat::expect_equal(idol_v2_budget("confirmation")$n_mcmc, 20000L)
  testthat::expect_identical(qdesn_ssv2_method_id,
                             "m0_v_collapsed_support_logit")
  testthat::expect_equal(idol_v2_reconstruction_tolerance, 1e-6)
  testthat::expect_setequal(
    idol_v2_promotion_metrics,
    c("forecast_qtrue_mae_H1000", "forecast_check_loss_H1000")
  )
})

testthat::test_that("preflight scripts load the transform parser before use", {
  repo <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                        winslash = "/")
  scripts <- file.path(
    repo, "validation", "fitforecast_v2", "scripts",
    c("run_independent_location_orthogonalized_tau0_v2_chain.R",
      "verify_independent_location_orthogonalized_tau0_v2.R")
  )
  for (script in scripts) {
    lines <- readLines(script, warn = FALSE)
    source_line <- grep('source\\(file.path\\(repo, "R", "readout_transform.R"\\)\\)',
                        lines)
    use_line <- grep("\\.qdesn_readout_transform_spec\\(", lines)
    testthat::expect_length(source_line, 1L)
    testthat::expect_true(source_line[[1L]] < min(use_line))
  }
})

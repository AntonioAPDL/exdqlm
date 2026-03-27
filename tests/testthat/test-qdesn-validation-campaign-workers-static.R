test_that("qdesn_validation_run_campaign exposes worker control", {
  repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  file_path <- file.path(repo_root, "R", "qdesn_mcmc_validation.R")
  expect_true(file.exists(file_path))

  lines <- readLines(file_path, warn = FALSE)
  expect_true(any(grepl("qdesn_validation_run_campaign <- function", lines, fixed = TRUE)))
  expect_true(any(grepl("workers = NULL", lines, fixed = TRUE)))
  expect_true(any(grepl("parallel::mclapply", lines, fixed = TRUE)))
  expect_true(any(grepl("campaign_workers", lines, fixed = TRUE)))
})

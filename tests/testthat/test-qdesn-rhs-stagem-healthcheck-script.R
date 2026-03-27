test_that("Stage-M healthcheck script exists", {
  repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  script_path <- file.path(repo_root, "scripts", "healthcheck_qdesn_rhs_stageM_repair_wave.R")

  expect_true(file.exists(script_path))
  lines <- readLines(script_path, warn = FALSE)
  expect_true(any(grepl("--run-tag", lines, fixed = TRUE)))
  expect_true(any(grepl("stageM_repair_manifest.json", lines, fixed = TRUE)))
  expect_true(any(grepl("campaign_completed.json", lines, fixed = TRUE)))
})

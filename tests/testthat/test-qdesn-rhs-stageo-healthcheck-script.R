test_that("Stage-O healthcheck script exists", {
  repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  script_path <- file.path(repo_root, "scripts", "healthcheck_qdesn_rhs_stageO_wave.R")

  expect_true(file.exists(script_path))
  lines <- readLines(script_path, warn = FALSE)
  expect_true(any(grepl("--run-tag", lines, fixed = TRUE)))
  expect_true(any(grepl("--manifest", lines, fixed = TRUE)))
  expect_true(any(grepl("qdesn_rhs_stageO_manifest.yaml", lines, fixed = TRUE)))
  expect_true(any(grepl("selected_candidate.json", lines, fixed = TRUE)))
})

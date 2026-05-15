test_that("Stage-M repair supervisor script exists and exposes key controls", {
  repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  script_path <- file.path(repo_root, "scripts", "run_qdesn_rhs_stageM_repair_supervisor.sh")

  expect_true(file.exists(script_path))
  lines <- readLines(script_path, warn = FALSE)
  expect_true(any(grepl("--run-tag", lines, fixed = TRUE)))
  expect_true(any(grepl("--manifest", lines, fixed = TRUE)))
  expect_true(any(grepl("--max-attempts", lines, fixed = TRUE)))
  expect_true(any(grepl("stageM_repair_manifest.json", lines, fixed = TRUE)))
})

test_that("Q-DESN compatibility pipeline entrypoints are present", {
  repo <- normalizePath(test_path("..", ".."), winslash = "/", mustWork = TRUE)
  sim_path <- file.path(repo, "scripts", "pipeline_sim_main.R")
  real_path <- file.path(repo, "scripts", "pipeline_real_main.R")
  orchestrator_path <- file.path(repo, "scripts", "orchestrate_shared_fitforecast_v2_validation.R")

  expect_true(file.exists(sim_path))
  expect_true(file.exists(real_path))
  expect_true(file.exists(orchestrator_path))
  expect_match(paste(readLines(sim_path, n = 6L, warn = FALSE), collapse = "\n"), "Compatibility source note")
  expect_match(paste(readLines(real_path, n = 6L, warn = FALSE), collapse = "\n"), "Compatibility source note")
  expect_silent(parse(orchestrator_path))
  orchestrator <- paste(readLines(orchestrator_path, warn = FALSE), collapse = "\n")
  expect_match(orchestrator, "SHARED_FFV2_ORCHESTRATOR_APPROVED")
  expect_match(orchestrator, "SHARED_FFV2_TT5000_APPROVED")
  expect_match(orchestrator, "qdesn_inner_session")
  expect_match(orchestrator, "stage_live")
  expect_false(grepl("pipeline_real_main|pipeline_sim_main", orchestrator, fixed = TRUE))
})

test_that("run_esn_pipeline_from_cfg chooses entrypoint by pipeline mode", {
  repo <- normalizePath(test_path("..", ".."), winslash = "/", mustWork = TRUE)

  expect_true(file.exists(file.path(repo, "scripts", "pipeline_sim_main.R")))
  expect_true(file.exists(file.path(repo, "scripts", "pipeline_real_main.R")))

  sim_cfg <- list(pipeline = list(mode = "sim"))
  real_cfg <- list(pipeline = list(mode = "real"))

  expect_error(
    exdqlm::run_esn_pipeline_from_cfg(sim_cfg, file_long = tempfile(), out_dir = tempdir(), repo_root = repo),
    "file_long not found"
  )
  expect_error(
    exdqlm::run_esn_pipeline_from_cfg(real_cfg, file_long = tempfile(), file_obs = tempfile(), out_dir = tempdir(), repo_root = repo),
    "file_long not found|file_obs not found"
  )
})

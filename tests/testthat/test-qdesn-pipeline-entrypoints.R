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

test_that("run_esn_pipeline_from_cfg can stream child output for validation diagnostics", {
  repo <- tempfile("qdesn-pipeline-repo-")
  dir.create(repo, recursive = TRUE)
  child <- file.path(repo, "child_pipeline.R")
  writeLines(c(
    "cat('child-start\\n')",
    "cat(Sys.getenv('EXDQLM_OUT_DIR'), '\\n')"
  ), child)
  file_long <- tempfile("qdesn-observed-")
  writeLines("y\n1\n2\n", file_long)
  out_dir <- tempfile("qdesn-pipeline-out-")

  res <- exdqlm::run_esn_pipeline_from_cfg(
    cfg = list(
      pipeline = list(mode = "sim"),
      validation = list(stream_child_stdout = TRUE, timeout_seconds = 20)
    ),
    file_long = file_long,
    out_dir = out_dir,
    repo_root = repo,
    rscript = file.path(R.home("bin"), "Rscript"),
    pipeline_script = "child_pipeline.R",
    verbose = FALSE
  )

  live_log <- file.path(out_dir, "logs", "pipeline_child_live.log")
  expect_identical(res$status, 0L)
  expect_true(file.exists(live_log))
  expect_true(any(grepl("child-start", readLines(live_log, warn = FALSE), fixed = TRUE)))
  expect_true(any(grepl("child-start", res$stdout, fixed = TRUE)))
})

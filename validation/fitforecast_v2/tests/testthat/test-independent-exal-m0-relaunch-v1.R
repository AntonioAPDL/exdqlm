testthat::test_that("independent exAL M0 relaunch freezes 15 exact per-metric anchors", {
  repo_root <- normalizePath(
    system("git rev-parse --show-toplevel", intern = TRUE),
    winslash = "/", mustWork = TRUE
  )
  source(file.path(
    repo_root, "validation", "fitforecast_v2", "R",
    "independent_exal_m0_relaunch_v1.R"
  ))
  stub <- qdesn_m0v1_config_stub(repo_root)
  anchors <- qdesn_m0v1_read_csv(paste0(stub, "_anchor_registry.csv"))
  metrics <- qdesn_m0v1_read_csv(paste0(stub, "_metric_contract.csv"))
  plan <- qdesn_m0v1_read_csv(paste0(stub, "_chain_plan.csv"))
  budgets <- qdesn_m0v1_read_csv(paste0(stub, "_budget_contract.csv"))

  testthat::expect_equal(nrow(anchors), 15L)
  testthat::expect_equal(nrow(metrics), 27L)
  testthat::expect_equal(nrow(plan), 60L)
  testthat::expect_equal(sum(plan$budget == "smoke"), 6L)
  testthat::expect_equal(sum(plan$budget == "canary"), 9L)
  testthat::expect_equal(sum(plan$budget == "full"), 45L)
  canary_budget <- budgets[budgets$budget == "canary", , drop = FALSE]
  testthat::expect_identical(canary_budget$n_burn, 1000L)
  testthat::expect_identical(canary_budget$n_mcmc, 3000L)
  testthat::expect_equal(length(unique(plan$anchor_id[plan$budget == "full"])), 15L)
  testthat::expect_true(all(table(plan$anchor_id[plan$budget == "full"]) == 3L))
  testthat::expect_true(all(plan$core_update_mode == qdesn_m0v1_method_id))
  testthat::expect_true(all(plan$gamma_slice_width == 4))
  testthat::expect_true(all(plan$core_extra_passes == 0L))
  testthat::expect_true(all(plan$source_request_sha256 == anchors$source_request_sha256[
    match(plan$anchor_id, anchors$anchor_id)
  ]))
  testthat::expect_true(all(plan$observed_sha256 == anchors$observed_sha256[
    match(plan$anchor_id, anchors$anchor_id)
  ]))
})

testthat::test_that("resolved M0 jobs preserve model, data, and prior configuration", {
  repo_root <- normalizePath(
    system("git rev-parse --show-toplevel", intern = TRUE),
    winslash = "/", mustWork = TRUE
  )
  source(file.path(
    repo_root, "validation", "fitforecast_v2", "R",
    "independent_exal_m0_relaunch_v1.R"
  ))
  stub <- qdesn_m0v1_config_stub(repo_root)
  plan <- qdesn_m0v1_read_csv(paste0(stub, "_chain_plan.csv"))
  for (i in seq_len(nrow(plan))) {
    job <- qdesn_m0v1_read_json(file.path(repo_root, plan$config_path[[i]]))
    source_request <- qdesn_m0v1_read_json(
      file.path(repo_root, plan$source_request_path[[i]])
    )
    testthat::expect_identical(job$config$desn, source_request$config$desn)
    testthat::expect_identical(job$config$split, source_request$config$split)
    testthat::expect_identical(job$config$preproc, source_request$config$preproc)
    testthat::expect_identical(job$config$readout, source_request$config$readout)
    testthat::expect_identical(job$config$forecast, source_request$config$forecast)
    testthat::expect_identical(
      job$config$inference$mcmc$priors,
      source_request$config$inference$mcmc$priors
    )
    testthat::expect_identical(
      job$config$inference$mcmc$slice$core_update_mode,
      qdesn_m0v1_method_id
    )
    testthat::expect_equal(as.numeric(
      job$config$inference$mcmc$slice$width_gamma
    ), 4)
    testthat::expect_identical(job$config$inference$mcmc$slice$core_extra_passes, 0L)
    testthat::expect_false(isTRUE(job$config$outputs$keep_draws))
    testthat::expect_false(isTRUE(job$config$outputs$save_forecast_objects))
    testthat::expect_false(isTRUE(job$config$outputs$retain_full_rds_on_failure))
    testthat::expect_true(isTRUE(job$config$metrics$rolling_origin$enabled))
    testthat::expect_true(isTRUE(
      job$config$metrics$rolling_origin$require_lead_export
    ))
    testthat::expect_identical(
      job$config$metrics$rolling_origin$max_lead_configured, 30L
    )
    testthat::expect_identical(
      job$config$metrics$rolling_origin$origin_stride, 30L
    )
    testthat::expect_false(isTRUE(
      job$config$metrics$rolling_origin$refit_per_origin
    ))
    testthat::expect_identical(
      job$source_registry_hash_value, qdesn_m0v1_registry_hash
    )
  }
})

testthat::test_that("active M0 campaign paths are canonical and binary-free", {
  repo_root <- normalizePath(
    system("git rev-parse --show-toplevel", intern = TRUE),
    winslash = "/", mustWork = TRUE
  )
  source(file.path(
    repo_root, "validation", "fitforecast_v2", "R",
    "independent_exal_m0_relaunch_v1.R"
  ))
  stub <- qdesn_m0v1_config_stub(repo_root)
  files <- c(
    paste0(stub, "_anchor_registry.csv"),
    paste0(stub, "_chain_plan.csv"),
    list.files(paste0(stub, "_resolved_configs"), recursive = TRUE, full.names = TRUE)
  )
  text <- paste(unlist(lapply(files, readLines, warn = FALSE)), collapse = "\n")
  testthat::expect_false(grepl("/home/jaguir26/local/src", text, fixed = TRUE))
  binaries <- list.files(
    dirname(stub), pattern = "[.](rds|rda|RData)$", recursive = TRUE,
    full.names = TRUE, ignore.case = TRUE
  )
  campaign_binaries <- binaries[grepl(basename(stub), binaries, fixed = TRUE)]
  testthat::expect_length(campaign_binaries, 0L)
})

testthat::test_that("M0 health classification distinguishes all lifecycle states", {
  repo_root <- normalizePath(
    system("git rev-parse --show-toplevel", intern = TRUE),
    winslash = "/", mustWork = TRUE
  )
  source(file.path(
    repo_root, "validation", "fitforecast_v2", "R",
    "independent_exal_m0_relaunch_v1.R"
  ))
  testthat::expect_identical(
    qdesn_m0v1_classify_health("RUNNING", TRUE, 120), "progressing"
  )
  testthat::expect_identical(
    qdesn_m0v1_classify_health("RUNNING", TRUE, 1801), "stalled"
  )
  testthat::expect_identical(
    qdesn_m0v1_classify_health("RUNNING", FALSE, 10), "interrupted"
  )
  testthat::expect_identical(
    qdesn_m0v1_classify_health("SUCCESS", FALSE, 9999), "completed"
  )
  testthat::expect_identical(
    qdesn_m0v1_classify_health("FAIL", FALSE, 9999), "failed"
  )
})

testthat::test_that("strict-mode budget launcher initializes dependent locals safely", {
  repo_root <- normalizePath(
    system("git rev-parse --show-toplevel", intern = TRUE),
    winslash = "/", mustWork = TRUE
  )
  pipeline_path <- file.path(
    repo_root, "validation", "fitforecast_v2", "scripts",
    "run_independent_exal_m0_relaunch_v1_pipeline.sh"
  )
  pipeline <- readLines(pipeline_path, warn = FALSE)
  testthat::expect_true(any(grepl('^  local budget="\\$1"$', pipeline)))
  testthat::expect_true(any(grepl(
    '^  local list="\\$STATE_ROOT/\\$\\{budget\\}_configs[.]txt"$', pipeline
  )))
  testthat::expect_false(any(grepl(
    'local budget=.*list=.*\\$\\{budget\\}', pipeline
  )))
})

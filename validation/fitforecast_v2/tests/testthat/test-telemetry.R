ffv2_fixture_config <- function(root = tempfile("ffv2_telemetry_"),
                                row_id = 1L,
                                status = "running") {
  row_key <- sprintf("row_%04d", as.integer(row_id))
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  list(
    row_id = as.integer(row_id),
    row_key = row_key,
    run_tag = "telemetry-fixture",
    model_family = "exdqlm_dqlm",
    model_variant = "exdqlm",
    inference = "mcmc",
    fit_size = 500L,
    family = "normal",
    tau = 0.5,
    phase = "mcmc_tt500",
    row_status_path = file.path(root, "rows", sprintf("%s_status.csv", row_key)),
    row_progress_path = file.path(root, "progress", sprintf("%s_progress.csv", row_key)),
    row_heartbeat_path = file.path(root, "heartbeats", sprintf("%s_heartbeat.json", row_key)),
    row_health_path = file.path(root, "health", sprintf("%s_health.csv", row_key)),
    row_metrics_path = file.path(root, "metrics", sprintf("%s_metrics.csv", row_key)),
    log_path = file.path(root, "logs", sprintf("%s.log", row_key)),
    runtime = list(
      progress_every = 50L,
      trace_every = 50L,
      heartbeat_seconds = 1800L,
      healthcheck_stale_seconds = 1800L
    ),
    status = status
  )
}

ffv2_fixture_manifest_row <- function(config) {
  data.frame(
    row_id = as.integer(config$row_id),
    row_key = as.character(config$row_key),
    run_tag = as.character(config$run_tag),
    model_variant = as.character(config$model_variant),
    inference = as.character(config$inference),
    fit_size = as.integer(config$fit_size),
    family = as.character(config$family),
    tau = as.numeric(config$tau),
    row_status_path = as.character(config$row_status_path),
    row_progress_path = as.character(config$row_progress_path),
    row_heartbeat_path = as.character(config$row_heartbeat_path),
    stringsAsFactors = FALSE
  )
}

ffv2_fixture_status <- function(config, status, now = Sys.time()) {
  ffv2_write_csv(
    ffv2_status_row(config, status, started_at = now, finished_at = now, runtime_sec = 0),
    config$row_status_path
  )
}

test_that("progress and heartbeat writers produce stable schemas", {
  config <- ffv2_fixture_config()
  row <- ffv2_record_progress(
    config,
    stage = "fit",
    substage = "mcmc",
    event = "progress",
    phase = "burn",
    current_iter = 50L,
    total_iter = 100L,
    burn_iter = 50L,
    burn_total = 60L,
    keep_iter = 0L,
    keep_total = 40L,
    mcmc_iter = 50L,
    mcmc_total_iter = 100L,
    elapsed_seconds = 10,
    message = "fixture MCMC progress"
  )

  expect_true(file.exists(config$row_progress_path))
  expect_true(file.exists(config$row_heartbeat_path))
  expect_true(all(ffv2_required_progress_columns() %in% names(row)))

  progress <- ffv2_read_progress(config$row_progress_path)
  heartbeat <- ffv2_read_heartbeat(config$row_heartbeat_path)
  expect_true(all(ffv2_required_progress_columns() %in% names(progress)))
  expect_true(all(ffv2_required_heartbeat_fields() %in% names(heartbeat)))
  expect_equal(progress$current_iter[[1L]], 50L)
  expect_equal(heartbeat$current_iter[[1L]], 50L)
  expect_equal(heartbeat$status[[1L]], "running")
})

test_that("log parser normalizes VB and MCMC progress lines", {
  config <- ffv2_fixture_config()
  started <- as.POSIXct("2026-05-16 21:00:00", tz = "UTC")
  stamp <- as.POSIXct("2026-05-16 21:01:00", tz = "UTC")
  lines <- c(
    "LDVB progress | model=exDQLM | iter=50 | elbo=-123.4",
    "MCMC progress | model=exDQLM | phase=keep | iter=150/200 | kept=50/100"
  )

  parsed <- ffv2_parse_exdqlm_progress_lines(
    config,
    lines,
    started_at = started,
    vb_max_iter = 300L,
    timestamp = stamp
  )

  expect_equal(nrow(parsed), 2L)
  expect_equal(parsed$substage, c("vb", "mcmc"))
  expect_equal(parsed$vb_iter[[1L]], 50L)
  expect_equal(parsed$vb_max_iter[[1L]], 300L)
  expect_equal(parsed$mcmc_iter[[2L]], 150L)
  expect_equal(parsed$mcmc_total_iter[[2L]], 200L)
})

test_that("MCMC progress callback writes burn and keep counters", {
  config <- ffv2_fixture_config()
  callback <- ffv2_make_mcmc_progress_callback(config, started_at = Sys.time())
  callback(list(
    event = "progress",
    iter = 75L,
    total_iter = 120L,
    phase = "keep",
    n_burn = 50L,
    n_mcmc = 70L
  ))
  progress <- ffv2_read_progress(config$row_progress_path)
  expect_equal(progress$mcmc_iter[[1L]], 75L)
  expect_equal(progress$burn_iter[[1L]], 50L)
  expect_equal(progress$keep_iter[[1L]], 25L)
})

test_that("telemetry summary classifies progressing, stalled, interrupted, completed, and failed rows", {
  root <- tempfile("ffv2_telemetry_states_")
  now <- as.POSIXct("2026-05-16 22:00:00", tz = "UTC")
  configs <- lapply(seq_len(5L), function(i) ffv2_fixture_config(root, row_id = i))
  manifest <- ffv2_bind_rows(lapply(configs, ffv2_fixture_manifest_row))

  ffv2_fixture_status(configs[[1L]], "running", now)
  ffv2_record_progress(
    configs[[1L]],
    stage = "fit",
    substage = "mcmc",
    event = "progress",
    current_iter = 50L,
    total_iter = 100L,
    timestamp = now - 60
  )

  ffv2_fixture_status(configs[[2L]], "running", now)
  ffv2_record_progress(
    configs[[2L]],
    stage = "fit",
    substage = "mcmc",
    event = "progress",
    current_iter = 10L,
    total_iter = 100L,
    timestamp = now - 3600
  )

  ffv2_fixture_status(configs[[3L]], "failed_interrupted", now)
  ffv2_record_progress(
    configs[[3L]],
    stage = "fit",
    substage = "vb",
    event = "failed",
    timestamp = now - 120
  )

  ffv2_fixture_status(configs[[4L]], "done", now)
  ffv2_record_progress(
    configs[[4L]],
    stage = "row",
    substage = "done",
    event = "complete",
    status = "done",
    timestamp = now - 10
  )

  ffv2_fixture_status(configs[[5L]], "failed_runtime", now)
  ffv2_record_progress(
    configs[[5L]],
    stage = "row",
    substage = "failed",
    event = "failed",
    status = "failed_runtime",
    timestamp = now - 10
  )

  summary <- ffv2_telemetry_summary(manifest, now = now, stale_seconds = 1800L)
  states <- stats::setNames(summary$telemetry_state, summary$row_id)

  expect_equal(states[["1"]], "progressing")
  expect_equal(states[["2"]], "stalled")
  expect_equal(states[["3"]], "interrupted")
  expect_equal(states[["4"]], "completed")
  expect_equal(states[["5"]], "failed")
})

test_that("prepared manifests include telemetry paths and smoke runtime cadence", {
  defaults <- ffv2_test_defaults()
  ffv2_test_write_sources(defaults)
  registry <- ffv2_collect_source_registry(defaults, require_sources = TRUE)
  manifest <- ffv2_prepare_manifest(defaults, registry, dry_run = FALSE)

  expect_true(all(c("row_progress_path", "row_heartbeat_path") %in% names(manifest)))
  smoke_row <- ffv2_stage_rows(manifest, "smoke")[1L, , drop = FALSE]
  full_row <- manifest[!isTRUE(manifest$smoke) & manifest$inference == "vb", , drop = FALSE][1L, , drop = FALSE]
  smoke_cfg <- jsonlite::read_json(smoke_row$row_config_path)
  full_cfg <- jsonlite::read_json(full_row$row_config_path)

  expect_equal(as.integer(smoke_cfg$runtime$progress_every), 1L)
  expect_equal(as.integer(smoke_cfg$runtime$trace_every), 1L)
  expect_equal(as.integer(smoke_cfg$runtime$heartbeat_seconds), 30L)
  expect_equal(as.integer(full_cfg$runtime$progress_every), 50L)
  expect_equal(as.integer(full_cfg$runtime$trace_every), 50L)
  expect_equal(as.integer(full_cfg$runtime$heartbeat_seconds), 1800L)
})

local({
  repo_root <- normalizePath(testthat::test_path("..", ".."), winslash = "/", mustWork = TRUE)
  old_wd <- setwd(repo_root)
  on.exit(setwd(old_wd), add = TRUE)
  source(file.path(repo_root, "tools", "merge_reports", "LOCAL_refreshed288_helpers_20260422_p90_full288.R"))
})

test_that("refreshed288 launch selector honors phase and status filters", {
  td <- tempfile("refreshed288_selector_")
  dir.create(td, recursive = TRUE)
  on.exit(unlink(td, recursive = TRUE), add = TRUE)
  manifest_path <- file.path(td, "manifest.csv")
  status_path <- file.path(td, "status.csv")

  manifest <- data.frame(
    row_id = c(1L, 2L, 3L, 4L),
    phase = c("full_static_vb", "full_dynamic_mcmc", "full_dynamic_mcmc", "full_dynamic_mcmc"),
    phase_order = c(1L, 4L, 4L, 4L),
    stringsAsFactors = FALSE
  )
  status <- data.frame(
    row_id = c(1L, 2L, 3L, 4L),
    status_current = c("done", "running", "not_started", "done"),
    gate_current = c("PASS", "", "", "FAIL"),
    stringsAsFactors = FALSE
  )

  utils::write.csv(manifest, manifest_path, row.names = FALSE)
  utils::write.csv(status, status_path, row.names = FALSE)

  expect_equal(
    select_row_ids_for_launch_refreshed288(
      manifest_path = manifest_path,
      phase_filter = "full_dynamic_mcmc",
      status_filter = "running,not_started",
      status_path = status_path
    ),
    c(2L, 3L)
  )

  expect_equal(
    select_row_ids_for_launch_refreshed288(
      manifest_path = manifest_path,
      phase_filter = "full_dynamic_mcmc",
      status_filter = NULL,
      status_path = status_path
    ),
    c(2L, 3L, 4L)
  )

  expect_equal(
    select_row_ids_for_launch_refreshed288(
      manifest_path = manifest_path,
      phase_filter = "full_dynamic_mcmc",
      status_filter = "running,not_started,failed_runtime",
      outcome_filter = "FAIL",
      filter_mode = "any",
      status_path = status_path
    ),
    c(2L, 3L, 4L)
  )
})

test_that("refreshed288 launch selector treats missing status snapshots as not_started", {
  td <- tempfile("refreshed288_selector_missing_")
  dir.create(td, recursive = TRUE)
  on.exit(unlink(td, recursive = TRUE), add = TRUE)
  manifest_path <- file.path(td, "manifest.csv")

  manifest <- data.frame(
    row_id = c(10L, 11L),
    phase = c("full_dynamic_mcmc", "full_dynamic_mcmc"),
    phase_order = c(4L, 4L),
    stringsAsFactors = FALSE
  )

  utils::write.csv(manifest, manifest_path, row.names = FALSE)

  expect_equal(
    select_row_ids_for_launch_refreshed288(
      manifest_path = manifest_path,
      phase_filter = "full_dynamic_mcmc",
      status_filter = "not_started",
      status_path = file.path(td, "missing.csv")
    ),
    c(10L, 11L)
  )
})

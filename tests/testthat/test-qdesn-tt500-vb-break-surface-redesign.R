`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

test_that("break-surface redesign scripts are launch-inert by construction", {
  root <- testthat::test_path("..", "..")
  materializer <- file.path(root, "scripts", "materialize_qdesn_tt500_vb_break_surface_redesign.R")
  auditor <- file.path(root, "scripts", "audit_qdesn_tt500_vb_break_surface_materialization.R")
  plan <- file.path(root, "validation", "fitforecast_v2", "docs", "QDESN_500OBS_VB_BREAK_SURFACE_REDESIGN_PLAN_2026-07-13.md")

  expect_true(file.exists(materializer))
  expect_true(file.exists(auditor))
  expect_true(file.exists(plan))

  script_text <- paste(readLines(materializer, warn = FALSE), collapse = "\n")
  audit_text <- paste(readLines(auditor, warn = FALSE), collapse = "\n")
  combined <- paste(script_text, audit_text, sep = "\n")

  expect_false(grepl("tmux", combined, fixed = TRUE))
  expect_false(grepl("orchestrate_qdesn", combined, fixed = TRUE))
  expect_false(grepl("run_qdesn", combined, fixed = TRUE))
  expect_true(grepl("explicit_human_approval_required", script_text, fixed = TRUE))
  expect_true(grepl("DRY_PASS_LAUNCH_BLOCKED", audit_text, fixed = TRUE))
})

test_that("break-surface materialized bundles carry required metadata when present", {
  root <- testthat::test_path("..", "..")
  stages <- c(
    bridge = "qdesn_dynamic_fitforecast_v2_tt500_vb_break_surface_bridge",
    newaxis = "qdesn_dynamic_fitforecast_v2_tt500_vb_break_surface_newaxis"
  )
  required_profile <- c(
    "design_axis", "seasonal_feature_mode", "seasonal_period", "seasonal_lag_block",
    "raw_lag_block", "reservoir_width_mode", "likelihood_target", "blocker_target",
    "source_frontier_row", "requires_runner_feature_support", "launch_gate"
  )
  for (lane in names(stages)) {
    stage <- stages[[lane]]
    profiles_path <- file.path(root, "config", "validation", paste0(stage, "_profiles.csv"))
    defaults_path <- file.path(root, "config", "validation", paste0(stage, "_defaults.yaml"))
    grid_path <- file.path(root, "config", "validation", paste0(stage, "_grid.csv"))
    testthat::skip_if_not(
      file.exists(profiles_path) && file.exists(defaults_path) && file.exists(grid_path),
      sprintf("Break-surface %s materialization has not been generated in this environment.", lane)
    )

    profiles <- utils::read.csv(profiles_path, check.names = FALSE, stringsAsFactors = FALSE)
    defaults <- yaml::read_yaml(defaults_path)
    grid <- utils::read.csv(grid_path, check.names = FALSE, stringsAsFactors = FALSE)
    expect_true(all(required_profile %in% names(profiles)))
    expect_equal(as.character(defaults$execution$methods), "vb")
    expect_false(isTRUE((defaults$pipeline$outputs %||% list())$save_forecast_objects))
    expect_false(isTRUE((defaults$pipeline$outputs %||% list())$keep_draws))
    expect_gt(nrow(profiles), 0L)
    expect_gt(nrow(grid), 0L)
    expect_true(all(tolower(as.character(profiles$design_lane)) == lane))
    if (identical(lane, "newaxis")) {
      expect_true(any(tolower(as.character(profiles$requires_runner_feature_support)) %in% c("true", "t", "yes", "1")))
    }
  }
})

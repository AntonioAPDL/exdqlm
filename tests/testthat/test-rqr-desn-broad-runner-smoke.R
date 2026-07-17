run_broad_runner <- function(repo_root, output_dir, extra_args = character()) {
  script_path <- file.path(repo_root, "scripts", "run_rqr_desn_broad_simulation.R")
  args <- c(
    script_path,
    "--output-dir", output_dir,
    "--stage-id", "fixed_design_calibration",
    "--family-id", "symmetric_linear",
    "--inference", "baseline",
    "--max-scenarios", "2",
    "--workers", "1",
    extra_args
  )
  output <- system2(file.path(R.home("bin"), "Rscript"), args, stdout = TRUE, stderr = TRUE)
  status <- attr(output, "status", exact = TRUE) %||% 0L
  expect_identical(as.integer(status), 0L, info = paste(output, collapse = "\n"))
  output
}

test_that("RQR-DESN broad runner executes a baseline smoke slice", {
  repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  output_dir <- tempfile("rqr_desn_broad_runner_smoke_")
  dir.create(output_dir, recursive = TRUE)

  run_broad_runner(repo_root, output_dir)

  expected_files <- c(
    "manifest.csv",
    "scenario_manifest.csv",
    "launch_manifest.csv",
    "interval_metrics.csv",
    "fit_summary.csv",
    "failure_log.csv",
    "run_status.csv",
    "metric_summary.csv",
    "closeout.md",
    "README.md",
    "output_hashes.csv"
  )
  expect_true(all(file.exists(file.path(output_dir, expected_files))))

  launch_manifest <- utils::read.csv(file.path(output_dir, "launch_manifest.csv"), stringsAsFactors = FALSE)
  metrics <- utils::read.csv(file.path(output_dir, "interval_metrics.csv"), stringsAsFactors = FALSE)
  failures <- utils::read.csv(file.path(output_dir, "failure_log.csv"), stringsAsFactors = FALSE)
  statuses <- utils::read.csv(file.path(output_dir, "run_status.csv"), stringsAsFactors = FALSE)
  metric_summary <- utils::read.csv(file.path(output_dir, "metric_summary.csv"), stringsAsFactors = FALSE)

  expect_identical(nrow(launch_manifest), 2L)
  expect_identical(nrow(metrics), 2L)
  expect_identical(nrow(failures), 0L)
  expect_identical(nrow(metric_summary), 2L)
  expect_true(all(statuses$status == "completed"))
  expect_true(all(metrics$inference == "baseline"))
  expect_true(all(metric_summary$inference == "baseline"))
  expect_true(all(metric_summary$learning_rate == "not_applicable"))
  expect_false(any(as.logical(metrics$response_likelihood)))
  expect_false(any(as.logical(metrics$response_predictive_draws)))
  expect_false(any(as.logical(metrics$recursive_response_sampling)))
})

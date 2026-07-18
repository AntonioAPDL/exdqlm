`%||%` <- function(a, b) if (is.null(a)) b else a

write_target_candidate_grid <- function(path) {
  grid <- data.frame(
    stage_id = c("fixed_design_calibration", "fixed_design_calibration", "fixed_design_calibration"),
    family_id = c("symmetric_linear", "symmetric_linear", "symmetric_linear"),
    coverage_level = c(0.8, 0.8, 0.8),
    backend_id = c("rqr_fixed_design_mcmc", "rqr_fixed_design_mcmc", "rqr_fixed_design_mcmc"),
    inference = c("mcmc", "mcmc", "mcmc"),
    prior_type = c("ridge", "ridge", "rhs_ns"),
    learning_rate = c(1.5, 1.5, 1.0),
    design_id = c("fixed_linear_true_features", "fixed_linear_true_features", "fixed_linear_true_features"),
    interval_score_mean = c(1.0, 1.0, 1.2),
    empirical_coverage = c(0.84, 0.84, 0.81),
    coverage_error = c(0.04, 0.04, 0.01),
    calibration_class = c("green", "green", "green"),
    recommendation_class = c("promote_to_targeted_confirmation", "promote_to_targeted_confirmation", "promote_to_targeted_confirmation"),
    confirmation_role = c("winner", "nearest_nominal_coverage", "score_runner_up"),
    stringsAsFactors = FALSE
  )
  utils::write.csv(grid, path, row.names = FALSE)
}

run_targeted_manifest <- function(repo_root, output_dir, candidate_grid, extra_args = character()) {
  script_path <- file.path(repo_root, "scripts", "materialize_rqr_desn_targeted_confirmation_manifest.R")
  config_path <- file.path(repo_root, "config", "rqr_desn", "rqr_desn_targeted_confirmation_20260717.R")
  args <- c(
    script_path,
    "--config", config_path,
    "--candidate-grid", candidate_grid,
    "--output-dir", output_dir,
    "--fixed-replicates", "2",
    "--dynamic-replicates", "1",
    "--seed-base", "2026071700",
    extra_args
  )
  output <- system2(file.path(R.home("bin"), "Rscript"), args, stdout = TRUE, stderr = TRUE)
  status <- attr(output, "status", exact = TRUE) %||% 0L
  expect_identical(as.integer(status), 0L, info = paste(output, collapse = "\n"))
  output
}

test_that("RQR-DESN targeted confirmation manifest materializes fresh MCMC-only denominator", {
  repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  output_dir <- tempfile("rqr_desn_target_confirm_")
  dir.create(output_dir, recursive = TRUE)
  candidate_grid <- tempfile("rqr_target_candidates_", fileext = ".csv")
  write_target_candidate_grid(candidate_grid)

  run_targeted_manifest(repo_root, output_dir, candidate_grid)

  expected_files <- c(
    "manifest.csv",
    "scenario_manifest.csv",
    "scenario_manifest_summary.csv",
    "targeted_candidate_specs.csv",
    "dgp_manifest.csv",
    "design_manifest.csv",
    "TARGETED_CONFIRMATION_PLAN.md",
    "closeout.md",
    "README.md",
    "output_hashes.csv"
  )
  expect_true(all(file.exists(file.path(output_dir, expected_files))))

  manifest <- utils::read.csv(file.path(output_dir, "manifest.csv"), stringsAsFactors = FALSE)
  scenarios <- utils::read.csv(file.path(output_dir, "scenario_manifest.csv"), stringsAsFactors = FALSE)
  candidates <- utils::read.csv(file.path(output_dir, "targeted_candidate_specs.csv"), stringsAsFactors = FALSE)

  expect_identical(nrow(candidates), 2L)
  expect_identical(nrow(scenarios), 6L)
  expect_identical(sum(scenarios$inference == "baseline"), 2L)
  expect_identical(sum(scenarios$inference == "mcmc"), 4L)
  expect_identical(sum(scenarios$inference == "vb"), 0L)
  expect_identical(length(unique(scenarios$scenario_id)), nrow(scenarios))
  expect_identical(length(unique(scenarios$scenario_spec_hash)), nrow(scenarios))
  expect_identical(length(unique(scenarios$seed)), nrow(scenarios))
  expect_identical(range(scenarios$seed), c(2026071701L, 2026071706L))
  expect_false(any(as.logical(scenarios$response_likelihood)))
  expect_false(any(as.logical(scenarios$response_predictive_draws)))
  expect_false(any(as.logical(scenarios$recursive_response_sampling)))
  expect_false(any(names(scenarios) %in% c("target_p", "p0")))
  expect_true(any(grepl("winner", scenarios$confirmation_role, fixed = TRUE)))
  expect_identical(manifest$value[match("article_update_allowed", manifest$key)], "FALSE")
})

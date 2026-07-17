`%||%` <- function(a, b) if (is.null(a)) b else a

source_rqr_broad_config <- function(path) {
  env <- new.env(parent = baseenv())
  sys.source(path, envir = env)
  get("rqr_desn_broad_simulation_config", envir = env)
}

run_rqr_broad_preflight <- function(repo_root, output_dir, extra_args = character()) {
  script_path <- file.path(repo_root, "scripts", "materialize_rqr_desn_broad_scenario_manifest.R")
  config_path <- file.path(repo_root, "config", "rqr_desn", "rqr_desn_broad_simulation_frozen_20260716_v2.R")
  args <- c(
    script_path,
    "--config", config_path,
    "--output-dir", output_dir,
    extra_args
  )
  output <- system2(file.path(R.home("bin"), "Rscript"), args, stdout = TRUE, stderr = TRUE)
  status <- attr(output, "status", exact = TRUE) %||% 0L
  expect_identical(as.integer(status), 0L, info = paste(output, collapse = "\n"))
  output
}

manifest_value <- function(manifest_df, key) {
  manifest_df$value[match(key, manifest_df$key)]
}

test_that("RQR-DESN broad v2 config is a seed-contract repair of v1", {
  repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  v1_path <- file.path(repo_root, "config", "rqr_desn", "rqr_desn_broad_simulation_frozen_20260716.R")
  v2_path <- file.path(repo_root, "config", "rqr_desn", "rqr_desn_broad_simulation_frozen_20260716_v2.R")
  v1 <- source_rqr_broad_config(v1_path)
  v2 <- source_rqr_broad_config(v2_path)

  expect_false(isTRUE(v2$launch_authorized))
  expect_false(isTRUE(v2$article_update_allowed))
  expect_identical(v2$status, "frozen_no_launch")
  expect_match(v2$config_id, "seed_repair")

  expect_identical(v2$scientific_contract, v1$scientific_contract)
  expect_identical(v2$output_contract, v1$output_contract)
  expect_identical(v2$scoring, v1$scoring)
  expect_identical(v2$mcmc_control, v1$mcmc_control)
  expect_identical(v2$vb_control, v1$vb_control)
  expect_identical(v2$priors, v1$priors)
  expect_identical(v2$stages, v1$stages)

  expect_identical(v2$randomization$seed_base, v1$randomization$seed_base)
  expect_match(v2$randomization$seed_rule, "scenario_index")
  expect_identical(v2$randomization$seed_collision_policy, "fail")
  expect_true(all(c(
    "stage_index", "family_index", "replicate_id", "design_index",
    "backend_index", "prior_index", "coverage_index", "learning_rate_index"
  ) %in% v2$randomization$scenario_order))
})

test_that("RQR-DESN broad manifest preflight materializes exact denominator and contracts", {
  repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  output_dir <- tempfile("rqr_desn_broad_preflight_")
  dir.create(output_dir, recursive = TRUE)
  run_rqr_broad_preflight(repo_root, output_dir)

  expected_files <- c(
    "manifest.csv",
    "scenario_manifest.csv",
    "scenario_manifest_summary.csv",
    "dgp_manifest.csv",
    "design_manifest.csv",
    "interval_metrics.csv",
    "fit_summary.csv",
    "mcmc_diagnostics.csv",
    "vb_diagnostics.csv",
    "failure_log.csv",
    "closeout.md",
    "session_info.txt",
    "git_state.txt",
    "output_hashes.csv",
    "README.md"
  )
  expect_true(all(file.exists(file.path(output_dir, expected_files))))

  manifest <- utils::read.csv(file.path(output_dir, "manifest.csv"), stringsAsFactors = FALSE)
  scenarios <- utils::read.csv(file.path(output_dir, "scenario_manifest.csv"), stringsAsFactors = FALSE)
  summary <- utils::read.csv(file.path(output_dir, "scenario_manifest_summary.csv"), stringsAsFactors = FALSE)
  dgps <- utils::read.csv(file.path(output_dir, "dgp_manifest.csv"), stringsAsFactors = FALSE)
  designs <- utils::read.csv(file.path(output_dir, "design_manifest.csv"), stringsAsFactors = FALSE)
  output_hashes <- utils::read.csv(file.path(output_dir, "output_hashes.csv"), stringsAsFactors = FALSE)

  expect_identical(nrow(scenarios), 3312L)
  expect_identical(sum(scenarios$stage_id == "fixed_design_calibration"), 1440L)
  expect_identical(sum(scenarios$stage_id == "teacher_forced_desn_dynamic"), 1872L)
  expect_identical(sum(scenarios$inference == "mcmc"), 2880L)
  expect_identical(sum(scenarios$inference == "vb"), 168L)
  expect_identical(sum(scenarios$inference == "baseline"), 264L)

  expect_identical(length(unique(scenarios$scenario_id)), 3312L)
  expect_identical(length(unique(scenarios$scenario_spec_hash)), 3312L)
  expect_identical(length(unique(scenarios$seed)), 3312L)
  expect_identical(length(unique(scenarios$metric_file)), 3312L)
  expect_identical(range(scenarios$seed), c(9130001L, 9133312L))

  expect_false(any(names(scenarios) %in% c("target_p", "p0")))
  expect_false(any(as.logical(scenarios$response_likelihood)))
  expect_false(any(as.logical(scenarios$response_predictive_draws)))
  expect_false(any(as.logical(scenarios$recursive_response_sampling)))

  expect_identical(as.integer(manifest_value(manifest, "total_scenario_rows")), 3312L)
  expect_identical(as.integer(manifest_value(manifest, "unique_scenario_ids")), 3312L)
  expect_identical(as.integer(manifest_value(manifest, "unique_scenario_hashes")), 3312L)
  expect_identical(as.integer(manifest_value(manifest, "unique_seeds")), 3312L)
  expect_identical(manifest_value(manifest, "launch_authorized"), "FALSE")
  expect_identical(manifest_value(manifest, "article_update_allowed"), "FALSE")
  expect_identical(manifest_value(manifest, "response_likelihood"), "FALSE")

  expect_identical(sum(summary$scenario_rows), 3312L)
  expect_identical(nrow(dgps), 6L)
  expect_identical(sum(dgps$oracle_endpoints), 4L)
  expect_identical(nrow(designs), 5L)
  expect_true(all(expected_files[expected_files != "output_hashes.csv"] %in% output_hashes$file))
})

test_that("RQR-DESN broad manifest preflight supports stage filtering", {
  repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  output_dir <- tempfile("rqr_desn_broad_preflight_fixed_")
  dir.create(output_dir, recursive = TRUE)
  run_rqr_broad_preflight(repo_root, output_dir, extra_args = c("--stage-id", "fixed_design_calibration"))

  scenarios <- utils::read.csv(file.path(output_dir, "scenario_manifest.csv"), stringsAsFactors = FALSE)
  manifest <- utils::read.csv(file.path(output_dir, "manifest.csv"), stringsAsFactors = FALSE)

  expect_identical(nrow(scenarios), 1440L)
  expect_true(all(scenarios$stage_id == "fixed_design_calibration"))
  expect_identical(sum(scenarios$inference == "mcmc"), 1152L)
  expect_identical(sum(scenarios$inference == "vb"), 96L)
  expect_identical(sum(scenarios$inference == "baseline"), 192L)
  expect_identical(length(unique(scenarios$seed)), 1440L)
  expect_identical(as.integer(manifest_value(manifest, "total_scenario_rows")), 1440L)
})

load_rqr_audit_env <- function() {
  repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  env <- new.env(parent = globalenv())
  sys.source(file.path(repo_root, "scripts", "audit_rqr_desn_broad_results_promotion.R"), envir = env)
  env
}

write_test_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
}

make_audit_metric_row <- function(scenario_id, replicate_id, backend_id, inference, prior_type,
                                  learning_rate, design_id, coverage, score, emp_cov, width,
                                  finite = TRUE) {
  data.frame(
    scenario_id = scenario_id,
    stage_id = "fixed_design_calibration",
    family_id = "symmetric_linear",
    design_id = design_id,
    backend_id = backend_id,
    inference = inference,
    prior_type = prior_type,
    replicate_id = replicate_id,
    seed = 1000L + replicate_id,
    dgp_seed = 2000L + replicate_id,
    design_seed = 3000L + replicate_id,
    coverage_level = coverage,
    learning_rate = learning_rate,
    n_train = 20L,
    n_test = 10L,
    endpoint_summary = "oracle",
    empirical_coverage = emp_cov,
    mean_width = width,
    interval_score_mean = score,
    midpoint_mae = score / 10,
    endpoint_mae = score / 8,
    finite_lower = finite,
    finite_upper = finite,
    ordered_intervals = finite,
    positive_mean_width = finite,
    runtime_sec = 1,
    response_likelihood = FALSE,
    response_predictive_draws = FALSE,
    recursive_response_sampling = FALSE,
    stringsAsFactors = FALSE
  )
}

make_minimal_rqr_audit_run <- function(run_dir, failed = FALSE, include_vb = TRUE) {
  rows <- list()
  ii <- 1L
  for (replicate_id in 1:2) {
    rows[[ii]] <- make_audit_metric_row(
      sprintf("baseline_%d", replicate_id), replicate_id,
      "empirical_train_interval", "baseline", "none", NA_real_, "none",
      0.8, score = 2.0, emp_cov = 0.75, width = 1.0
    )
    ii <- ii + 1L
    rows[[ii]] <- make_audit_metric_row(
      sprintf("mcmc_red_score_%d", replicate_id), replicate_id,
      "rqr_fixed_design_mcmc", "mcmc", "ridge", 1.5, "design_red_score",
      0.8, score = 1.0, emp_cov = 0.95, width = 0.8
    )
    ii <- ii + 1L
    rows[[ii]] <- make_audit_metric_row(
      sprintf("mcmc_green_%d", replicate_id), replicate_id,
      "rqr_fixed_design_mcmc", "mcmc", "rhs_ns", 1.0, "design_green",
      0.8, score = 1.2, emp_cov = 0.84, width = 0.9
    )
    ii <- ii + 1L
    if (isTRUE(include_vb)) {
      rows[[ii]] <- make_audit_metric_row(
        sprintf("vb_%d", replicate_id), replicate_id,
        "rqr_fixed_design_vb", "vb", "ridge", 1.0, "design_green",
        0.8, score = 3.0, emp_cov = 1.0, width = 3.0
      )
      ii <- ii + 1L
    }
  }
  metrics <- do.call(rbind, rows)
  write_test_csv(metrics, file.path(run_dir, "interval_metrics.csv"))
  write_test_csv(metrics[0, c("stage_id", "family_id", "backend_id", "inference", "prior_type", "coverage_level", "learning_rate", "empirical_coverage", "mean_width", "interval_score_mean", "midpoint_mae", "endpoint_mae", "runtime_sec")], file.path(run_dir, "metric_summary.csv"))

  status <- metrics[, c("scenario_id", "stage_id", "family_id", "design_id", "backend_id", "inference", "prior_type", "replicate_id"), drop = FALSE]
  status$scenario_index <- seq_len(nrow(status))
  status$status <- ifelse(failed & seq_len(nrow(status)) == 1L, "failed", "completed")
  status$started_at <- "2026-07-17 00:00:00 EDT"
  status$finished_at <- "2026-07-17 00:00:01 EDT"
  status$runtime_sec <- 1
  status$message <- NA_character_
  write_test_csv(status, file.path(run_dir, "run_status.csv"))

  failure_schema <- data.frame(
    scenario_id = character(),
    stage_id = character(),
    family_id = character(),
    design_id = character(),
    backend_id = character(),
    inference = character(),
    prior_type = character(),
    coverage_level = numeric(),
    learning_rate = numeric(),
    failure_stage = character(),
    failure_class = character(),
    failure_message = character(),
    trace_hint = character(),
    created_at = character(),
    stringsAsFactors = FALSE
  )
  if (failed) {
    failure_schema[1, ] <- list(
      "baseline_1", "fixed_design_calibration", "symmetric_linear", "none",
      "empirical_train_interval", "baseline", "none", 0.8, NA_real_,
      "test", "failure", "synthetic failure", NA_character_, "2026-07-17"
    )
  }
  write_test_csv(failure_schema, file.path(run_dir, "failure_log.csv"))

  write_test_csv(metrics[, c(
    "scenario_id", "stage_id", "family_id", "replicate_id", "coverage_level",
    "backend_id", "inference", "prior_type", "learning_rate", "design_id",
    "response_likelihood", "response_predictive_draws", "recursive_response_sampling"
  )], file.path(run_dir, "launch_manifest.csv"))

  write_test_csv(data.frame(file = "interval_metrics.csv", md5 = "synthetic"), file.path(run_dir, "output_hashes.csv"))
  writeLines("synthetic git state", file.path(run_dir, "git_state.txt"))

  fit <- metrics[metrics$inference != "baseline", c("scenario_id", "stage_id", "backend_id", "inference", "prior_type"), drop = FALSE]
  fit$method <- fit$inference
  fit$family <- "rqr_desn"
  fit$n_design_rows <- 20L
  fit$n_design_cols <- 2L
  fit$beta_prior <- fit$prior_type
  fit$response_likelihood <- FALSE
  fit$generalized_bayes <- TRUE
  fit$runtime_sec <- 1
  write_test_csv(fit, file.path(run_dir, "fit_summary.csv"))

  mcmc <- metrics[metrics$inference == "mcmc", c("scenario_id", "prior_type"), drop = FALSE]
  mcmc$n_draws <- 10L
  mcmc$n_design_cols <- 2L
  mcmc$beta_prior <- mcmc$prior_type
  mcmc$loss_first <- 2
  mcmc$loss_last <- 1
  mcmc$loss_tail_mean <- 1
  mcmc$loss_tail_sd <- 0.1
  mcmc$precision_strategy_root1 <- "direct"
  mcmc$precision_strategy_root2 <- "direct"
  mcmc$rhs_stats_available <- mcmc$prior_type == "rhs_ns"
  mcmc$response_likelihood <- FALSE
  mcmc$generalized_bayes <- TRUE
  mcmc$sentinel_chain <- FALSE
  mcmc$prior_type <- NULL
  write_test_csv(mcmc, file.path(run_dir, "mcmc_diagnostics.csv"))

  vb <- metrics[metrics$inference == "vb", c("scenario_id"), drop = FALSE]
  vb$n_draws <- integer(nrow(vb))
  vb$n_design_cols <- integer(nrow(vb))
  vb$converged <- logical(nrow(vb))
  if (nrow(vb)) vb$converged <- c(TRUE, FALSE)[seq_len(nrow(vb))]
  vb$objective_last <- numeric(nrow(vb)) - 10
  vb$delta_last <- numeric(nrow(vb)) + 1e-5
  vb$calibrated_uncertainty <- logical(nrow(vb))
  vb$response_likelihood <- logical(nrow(vb))
  vb$generalized_bayes <- rep(TRUE, nrow(vb))
  write_test_csv(vb, file.path(run_dir, "vb_diagnostics.csv"))

  write_test_csv(data.frame(stage_id = "fixed_design_calibration", family_id = "symmetric_linear"), file.path(run_dir, "dgp_manifest.csv"))
  write_test_csv(data.frame(stage_id = "fixed_design_calibration", design_id = c("none", "design_red_score", "design_green")), file.path(run_dir, "design_manifest.csv"))
  invisible(run_dir)
}

test_that("RQR-DESN results audit builds calibration-aware winner and deltas", {
  env <- load_rqr_audit_env()
  run_dir <- tempfile("rqr_audit_run_")
  out_dir <- tempfile("rqr_audit_out_")
  dir.create(run_dir, recursive = TRUE)
  make_minimal_rqr_audit_run(run_dir)

  result <- env$run_results_audit(run_dir, out_dir)

  expect_true(all(result$preflight$status == "pass"))
  expect_identical(nrow(result$winners), 1L)
  expect_identical(result$winners$design_id, "design_green")
  expect_identical(result$winners$prior_type, "rhs_ns")
  expect_false(as.logical(result$winners$selected_is_unconstrained_score_winner))
  expect_equal(result$winners$interval_score_delta, -0.8)
  expect_equal(result$winners$coverage_error, 0.04)
  expect_identical(result$winners$calibration_class, "green")
  expect_identical(result$recommendation$recommendation, "promote_to_targeted_confirmation")
  expect_false(result$recommendation$article_update_allowed)

  expected_files <- c(
    "audit_preflight.csv",
    "paired_model_baseline_deltas.csv",
    "paired_delta_summary.csv",
    "winner_map.csv",
    "coverage_calibration_flags.csv",
    "mcmc_diagnostic_summary.csv",
    "vb_sidecar_summary.csv",
    "vb_vs_mcmc_delta.csv",
    "stage_specific_claim_contract.csv",
    "article_claim_guardrails.md",
    "promotion_recommendation.md",
    "promotion_recommendation.json",
    "targeted_confirmation_candidate_grid.csv"
  )
  expect_true(all(file.exists(file.path(out_dir, expected_files))))

  vb_summary <- utils::read.csv(file.path(out_dir, "vb_sidecar_summary.csv"), stringsAsFactors = FALSE)
  expect_true(all(grepl("^sidecar_not_primary", vb_summary$caveat_label)))
})

test_that("RQR-DESN results audit fails preflight on failed run rows", {
  env <- load_rqr_audit_env()
  run_dir <- tempfile("rqr_audit_failed_run_")
  out_dir <- tempfile("rqr_audit_failed_out_")
  dir.create(run_dir, recursive = TRUE)
  make_minimal_rqr_audit_run(run_dir, failed = TRUE)

  expect_error(
    env$run_results_audit(run_dir, out_dir),
    "preflight failed"
  )

  preflight <- utils::read.csv(file.path(out_dir, "audit_preflight.csv"), stringsAsFactors = FALSE)
  expect_true(any(preflight$status == "fail"))
})

test_that("RQR-DESN results audit fails clearly on missing required inputs", {
  env <- load_rqr_audit_env()
  run_dir <- tempfile("rqr_audit_missing_run_")
  out_dir <- tempfile("rqr_audit_missing_out_")
  dir.create(run_dir, recursive = TRUE)
  make_minimal_rqr_audit_run(run_dir)
  unlink(file.path(run_dir, "git_state.txt"))

  expect_error(
    env$run_results_audit(run_dir, out_dir),
    "missing: git_state.txt"
  )
})

test_that("RQR-DESN results audit supports targeted confirmation runs without VB", {
  env <- load_rqr_audit_env()
  run_dir <- tempfile("rqr_audit_no_vb_run_")
  out_dir <- tempfile("rqr_audit_no_vb_out_")
  dir.create(run_dir, recursive = TRUE)
  make_minimal_rqr_audit_run(run_dir, include_vb = FALSE)

  result <- env$run_results_audit(run_dir, out_dir, audit_context = "targeted_confirmation")

  expect_true(all(result$preflight$status == "pass"))
  expect_identical(nrow(result$vb_summary), 0L)
  vb_delta <- utils::read.csv(file.path(out_dir, "vb_vs_mcmc_delta.csv"), stringsAsFactors = FALSE)
  expect_identical(nrow(vb_delta), 0L)
  expect_identical(result$recommendation$recommendation, "prepare_cautious_article_or_supplement_draft")
  expect_false(result$recommendation$article_update_allowed)
  expect_identical(result$recommendation$audit_context, "targeted_confirmation")
  expect_true(all(result$winners$recommendation_class == "confirmed_for_cautious_article_draft"))
})

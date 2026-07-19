`%||%` <- function(a, b) if (is.null(a)) b else a

repo_root_for_tests <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
if (requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(repo_root_for_tests, quiet = TRUE)
}

run_script <- function(script, args, expect_success = TRUE) {
  repo_root <- repo_root_for_tests
  out <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"), c(file.path(repo_root, script), args), stdout = TRUE, stderr = TRUE))
  status <- attr(out, "status", exact = TRUE) %||% 0L
  if (expect_success) {
    expect_identical(as.integer(status), 0L, info = paste(out, collapse = "\n"))
  } else {
    expect_true(as.integer(status) != 0L, info = paste(out, collapse = "\n"))
  }
  out
}

test_that("RQR oracle roots satisfy coverage and moment-balance equations", {
  families <- list(
    list(family = "gaussian", params = list(mean = 0, sd = 1)),
    list(family = "laplace", params = list(location = 0, scale = 1)),
    list(family = "student_t", params = list(df = 5, scale = 1)),
    list(family = "centered_gamma", params = list(shape = 2, scale = 1)),
    list(family = "asymmetric_laplace", params = list(tau = 0.25, scale = 1)),
    list(family = "gaussian_mixture", params = list(weights = c(0.1, 0.9), means = c(0, 1), sds = c(0.5, 1.5), center = TRUE))
  )
  for (spec in families) {
    roots <- rqr_oracle_roots(spec$family, 0.80, params = spec$params)
    expect_true(is.finite(roots$lower_root))
    expect_true(is.finite(roots$upper_root))
    expect_lt(roots$lower_root, roots$upper_root)
    expect_lt(abs(roots$coverage_residual), 1e-5)
    expect_lt(abs(roots$moment_residual), 1e-4)
  }
})

test_that("article-congruent manifest materializes the declared denominator", {
  output_dir <- tempfile("rqr_article_manifest_")
  run_script(
    "scripts/materialize_rqr_desn_article_congruent_manifest.R",
    c("--output-dir", output_dir)
  )
  manifest <- utils::read.csv(file.path(output_dir, "manifest.csv"), stringsAsFactors = FALSE)
  scenarios <- utils::read.csv(file.path(output_dir, "scenario_manifest.csv"), stringsAsFactors = FALSE)
  summary <- utils::read.csv(file.path(output_dir, "scenario_manifest_summary.csv"), stringsAsFactors = FALSE)
  split <- utils::read.csv(file.path(output_dir, "split_contract.csv"), stringsAsFactors = FALSE)

  manifest_value <- function(key) manifest$value[match(key, manifest$key)]
  expect_identical(as.integer(manifest_value("total_scenario_rows")), 8040L)
  expect_identical(as.integer(manifest_value("adapter_ready_rows")), 6700L)
  expect_identical(as.integer(manifest_value("external_adapter_rows")), 1340L)
  expect_identical(nrow(scenarios), 8040L)
  expect_identical(length(unique(scenarios$scenario_id)), 8040L)
  expect_identical(length(unique(scenarios$seed)), 8040L)
  expect_false(any(names(scenarios) %in% c("target_p", "p0")))
  expect_false(any(as.logical(scenarios$rqr_response_likelihood)))
  expect_false(any(as.logical(scenarios$rqr_response_predictive_draws)))
  expect_false(any(as.logical(scenarios$rqr_recursive_response_sampling)))
  expect_equal(sum(summary$scenario_rows), 8040L)
  expect_identical(split$value[match("final_fit_length", split$key)], "500")
  expect_identical(split$value[match("test_length", split$key)], "1000")
})

test_that("article-congruent runner refuses unguarded full launch", {
  output_dir <- tempfile("rqr_article_guard_")
  out <- run_script(
    "scripts/run_rqr_desn_article_congruent_simulation.R",
    c("--output-dir", output_dir, "--stage-id", "fixed_design_endpoint_recovery", "--family-id", "symmetric_gaussian", "--method-id", "empirical_train_interval", "--max-scenarios", "1"),
    expect_success = FALSE
  )
  expect_true(any(grepl("--confirm-full-launch true", out, fixed = TRUE)))
})

test_that("article-congruent runner and audit execute adapter-ready smoke slices", {
  output_dir <- tempfile("rqr_article_run_")
  run_script(
    "scripts/run_rqr_desn_article_congruent_simulation.R",
    c(
      "--smoke", "true",
      "--output-dir", output_dir,
      "--scenario-id", paste(c(
        "rqr_article__fixed_design_endpoint_recovery__symmetric_gaussian__rep001__empirical_train_interval__cov0p8__lrna",
        "rqr_article__fixed_design_endpoint_recovery__symmetric_gaussian__rep001__rqr_desn_rhs_mcmc__cov0p8__lr0p5",
        "rqr_article__fixed_design_endpoint_recovery__symmetric_gaussian__rep001__independent_al_qdesn_rhs_mcmc__cov0p8__lrna"
      ), collapse = ","),
      "--chains", "1",
      "--mcmc-burn", "3",
      "--mcmc-keep", "4"
    )
  )
  metrics <- utils::read.csv(file.path(output_dir, "interval_metrics.csv"), stringsAsFactors = FALSE)
  statuses <- utils::read.csv(file.path(output_dir, "run_status.csv"), stringsAsFactors = FALSE)
  gates <- utils::read.csv(file.path(output_dir, "readiness_gates.csv"), stringsAsFactors = FALSE)
  expect_identical(nrow(statuses), 3L)
  expect_true(all(statuses$status == "completed"))
  expect_identical(nrow(metrics), 3L)
  expect_true(all(c("empirical_train_interval", "rqr_desn_rhs_mcmc", "independent_al_qdesn_rhs_mcmc") %in% metrics$method_id))
  expect_true(all(gates$status != "fail"))
  audit_dir <- tempfile("rqr_article_audit_")
  run_script(
    "scripts/audit_rqr_desn_article_congruent_results.R",
    c("--run-dir", output_dir, "--output-dir", audit_dir)
  )
  expect_true(file.exists(file.path(audit_dir, "method_summary.csv")))
  expect_true(file.exists(file.path(audit_dir, "calibration_qualified_winner_table.csv")))
  expect_true(file.exists(file.path(audit_dir, "article_claim_contract.csv")))
})

test_that("learned-scale rich RQR-DESN config materializes and smokes learned-scale rows", {
  config_path <- file.path(
    repo_root_for_tests,
    "config",
    "rqr_desn",
    "rqr_desn_article_congruent_learned_scale_rich_desn_20260719.R"
  )
  output_dir <- tempfile("rqr_article_ls_manifest_")
  run_script(
    "scripts/materialize_rqr_desn_article_congruent_manifest.R",
    c("--config", config_path, "--output-dir", output_dir)
  )
  manifest <- utils::read.csv(file.path(output_dir, "manifest.csv"), stringsAsFactors = FALSE)
  scenarios <- utils::read.csv(file.path(output_dir, "scenario_manifest.csv"), stringsAsFactors = FALSE)
  methods <- utils::read.csv(file.path(output_dir, "method_manifest.csv"), stringsAsFactors = FALSE)
  manifest_value <- function(key) manifest$value[match(key, manifest$key)]

  expect_identical(as.integer(manifest_value("total_scenario_rows")), 9380L)
  expect_identical(as.integer(manifest_value("adapter_ready_rows")), 8040L)
  expect_identical(as.integer(manifest_value("external_adapter_rows")), 1340L)
  expect_true("learning_rate_mode" %in% names(scenarios))
  expect_true("lambda_prior_shape" %in% names(scenarios))
  expect_true(any(scenarios$learning_rate_mode == "learned_scale"))
  expect_true(all(scenarios$lambda_prior_shape[scenarios$learning_rate_mode == "learned_scale"] == 4))
  expect_true(methods$learning_rate_mode[methods$method_id == "rqr_desn_rhs_mcmc_learned_scale"] == "learned_scale")

  run_dir <- tempfile("rqr_article_ls_run_")
  run_script(
    "scripts/run_rqr_desn_article_congruent_simulation.R",
    c(
      "--config", config_path,
      "--smoke", "true",
      "--output-dir", run_dir,
      "--scenario-id", "rqr_article__fixed_design_endpoint_recovery__symmetric_gaussian__rep001__rqr_desn_rhs_mcmc_learned_scale__cov0p8__lr1p0",
      "--chains", "1",
      "--mcmc-burn", "3",
      "--mcmc-keep", "4"
    )
  )
  metrics <- utils::read.csv(file.path(run_dir, "interval_metrics.csv"), stringsAsFactors = FALSE)
  mcmc <- utils::read.csv(file.path(run_dir, "mcmc_diagnostics.csv"), stringsAsFactors = FALSE)
  expect_identical(metrics$learning_rate_mode, "learned_scale")
  expect_true(is.finite(metrics$loss_reference_scale))
  expect_gt(metrics$loss_reference_scale, 0)
  expect_identical(mcmc$learning_rate_mode, "learned_scale")
  expect_true(is.finite(mcmc$effective_learning_rate_mean))
  expect_true(is.finite(mcmc$lambda_mean))
  expect_gt(mcmc$lambda_mean, 0)
})

test_that("n300 tau1e-6 learned-scale config freezes the requested production contract", {
  config_path <- file.path(
    repo_root_for_tests,
    "config",
    "rqr_desn",
    "rqr_desn_article_congruent_n300_tau1em6_lambda1em3_20260719.R"
  )
  env <- new.env(parent = baseenv())
  sys.source(config_path, envir = env)
  cfg <- get("rqr_desn_article_congruent_simulation_config", envir = env)
  design <- cfg$stages[[2L]]$design

  expect_identical(design$DESN_D, 1L)
  expect_identical(design$DESN_n, 300L)
  expect_identical(design$DESN_m, 60L)
  expect_equal(design$alpha, 0.20)
  expect_equal(design$rho, 0.95)
  expect_equal(cfg$priors$rqr_rhs_ns$tau0, 1e-6)
  expect_equal(cfg$priors$qdesn_rhs_ns$tau0, 1e-6)
  expect_equal(cfg$scientific_contract$rqr_learned_scale_prior$shape, 1e-3)
  expect_equal(cfg$scientific_contract$rqr_learned_scale_prior$rate, 1e-3)
  expect_identical(cfg$analysis_scale$rqr_loss_reference_scale, "train_response_variance")

  output_dir <- tempfile("rqr_article_n300_manifest_")
  run_script(
    "scripts/materialize_rqr_desn_article_congruent_manifest.R",
    c("--config", config_path, "--output-dir", output_dir)
  )
  manifest <- utils::read.csv(file.path(output_dir, "manifest.csv"), stringsAsFactors = FALSE)
  scenarios <- utils::read.csv(file.path(output_dir, "scenario_manifest.csv"), stringsAsFactors = FALSE)
  methods <- utils::read.csv(file.path(output_dir, "method_manifest.csv"), stringsAsFactors = FALSE)
  manifest_value <- function(key) manifest$value[match(key, manifest$key)]

  expect_identical(as.integer(manifest_value("total_scenario_rows")), 9380L)
  expect_identical(as.integer(manifest_value("adapter_ready_rows")), 8040L)
  expect_identical(as.integer(manifest_value("external_adapter_rows")), 1340L)
  expect_identical(manifest_value("rqr_loss_reference_scale"), "train_response_variance")
  learned <- scenarios$learning_rate_mode == "learned_scale"
  expect_true(any(learned))
  expect_true(all(scenarios$lambda_prior_shape[learned] == 1e-3))
  expect_true(all(scenarios$lambda_prior_rate[learned] == 1e-3))
  expect_true(methods$learning_rate_mode[methods$method_id == "rqr_desn_rhs_mcmc_learned_scale"] == "learned_scale")
})

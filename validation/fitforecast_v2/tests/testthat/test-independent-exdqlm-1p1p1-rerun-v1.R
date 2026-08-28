test_that("1.1.1 campaign contract is pinned to the current v11 authority", {
  audit <- i111_static_audit(ffv2_repo_root())
  expect_true(all(audit$checks$pass))
  expect_equal(nrow(audit$metric_roles), i111_expected_metric_roles)
  expect_equal(nrow(audit$source_registry), i111_expected_source_identities)
  expect_equal(sum(audit$source_registry$planned_chains), i111_expected_jobs)
})

test_that("1.1.1 seed ledger exactly covers the replay plan", {
  ledger <- i111_read_seed_ledger(ffv2_repo_root())
  expect_equal(nrow(ledger), i111_expected_jobs)
  expect_equal(sum(ledger$seed_source ==
                     "metric_intervals_v1_production_20260823_225856"), 195L)
  expect_equal(sum(ledger$seed_source ==
                     "v11_location_orthogonalized_point_confirmation"), 3L)
  expect_identical(anyDuplicated(paste(ledger$source_identity, ledger$chain_id)), 0L)
  fixture_rows <- nzchar(ledger$source_override_path)
  expect_equal(sum(fixture_rows), 3L)
  expect_true(all(ledger$source_override_sha256[fixture_rows] ==
                    i111_v11_source_fixture_sha256))
  fixture_path <- file.path(ffv2_repo_root(), i111_v11_source_fixture_relpath)
  expect_identical(ffv2_file_sha256(fixture_path), i111_v11_source_fixture_sha256)
})

test_that("structured scale-skewness defaults survive the validation merge", {
  cfg <- exal_make_vb_sigmagam_control()
  expect_identical(cfg$factorization, "structured")
  expect_identical(cfg$structured_grid_size, 151L)
  expect_identical(eval(formals(exdqlmMCMC)$mh.proposal)[[1L]], "collapsed_slice")
  expect_identical(eval(formals(exalStaticMCMC)$mh.proposal)[[1L]], "collapsed_slice")
})

test_that("DQLM row runner accepts an explicit MCMC proposal", {
  body_text <- paste(deparse(body(ffv2_fit_row)), collapse = "\n")
  expect_match(body_text, "mcmc_budget\\$mh_proposal")
})

test_that("DQLM row runner applies the frozen fit seed", {
  body_text <- paste(deparse(body(ffv2_run_row)), collapse = "\n")
  seed_line <- regexpr("set.seed\\(seed\\)", body_text)[[1L]]
  fit_line <- regexpr("fit <- ffv2_fit_row", body_text)[[1L]]
  expect_gt(seed_line, 0L)
  expect_gt(fit_line, seed_line)
})

test_that("compact diagnostics tolerate atomic optional fit fields", {
  fit <- list(
    VB = NA_real_, misc = NA_character_,
    mh.diagnostics = list(proposal = "collapsed_slice"),
    samp.gamma = c(1.5, 1.7, 1.9), samp.sigma = c(2.0, 2.1, 2.2)
  )
  config <- list(
    model_variant = "exdqlm", inference = "mcmc", dqlm_ind = FALSE,
    budget = list(mcmc = list(mh_proposal = "collapsed_slice"))
  )
  out <- ffv2_compact_inference_diagnostics(fit, config)
  expect_identical(out$observed_mh_proposal, "collapsed_slice")
  expect_identical(out$gamma$n, 3L)
  expect_equal(out$sigma$mean, 2.1)
})

test_that("production materialization records the complete scoring contract", {
  text <- paste(readLines(file.path(
    ffv2_repo_root(), "validation", "fitforecast_v2", "scripts",
    "materialize_independent_metric_intervals_v1.R"
  ), warn = FALSE), collapse = "\n")
  expect_match(text, "forecast_origins = 34L", fixed = TRUE)
  expect_match(text, "scored_origin_lead_pairs = 1000L", fixed = TRUE)
  expect_match(text, "conditional_quantile_not_response_predictive", fixed = TRUE)
  expect_match(text, "not_supported_by_the_frozen_independent_validation_tooling",
               fixed = TRUE)
})

test_that("the package builder archives only the committed tree", {
  path <- file.path(ffv2_repo_root(), "validation", "fitforecast_v2", "scripts",
                    "build_independent_exdqlm_1p1p1_tarball_v1.sh")
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_match(text, 'git -C "${REPO_ROOT}" archive --format=tar HEAD',
               fixed = TRUE)
  expect_match(text, "forbidden_runtime_paths = 0L", fixed = TRUE)
})

test_that("the guarded pipeline authenticates its preflight-only state root", {
  scripts <- file.path(ffv2_repo_root(), "validation", "fitforecast_v2", "scripts")
  pipeline <- paste(readLines(file.path(
    scripts, "run_independent_exdqlm_1p1p1_rerun_v1_pipeline.sh"
  ), warn = FALSE), collapse = "\n")
  materializer <- paste(readLines(file.path(
    scripts, "materialize_independent_metric_intervals_v1.R"
  ), warn = FALSE), collapse = "\n")
  expect_match(pipeline, 'if [[ -e "${STATE_ROOT}" ]]', fixed = TRUE)
  expect_match(pipeline, "--allow-pipeline-preflight-root true", fixed = TRUE)
  expect_match(materializer, "authenticated, preflight-only pipeline root", fixed = TRUE)
  expect_match(materializer, 'grepl("^status=RUNNING\\\\b"', fixed = TRUE)
  expect_match(materializer, 'all(as.logical(checks$pass))', fixed = TRUE)
})

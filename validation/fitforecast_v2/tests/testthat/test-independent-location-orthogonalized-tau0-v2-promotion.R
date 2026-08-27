testthat::test_that("V2 promotion evidence selects exactly two forecast gains", {
  repo <- normalizePath(
    system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/",
    mustWork = TRUE
  )
  source(file.path(repo, "validation", "fitforecast_v2", "R", "utils.R"),
         local = TRUE)
  source(file.path(
    repo, "validation", "fitforecast_v2", "R",
    "independent_location_orthogonalized_tau0_v2.R"
  ), local = TRUE)
  source(file.path(
    repo, "validation", "fitforecast_v2", "R",
    "independent_location_orthogonalized_tau0_v2_promotion.R"
  ), local = TRUE)
  evidence <- idolp_v2_assert_evidence(repo, require_clean = FALSE)
  testthat::expect_equal(nrow(evidence$parent), 72L)
  testthat::expect_equal(nrow(evidence$roles), 216L)
  testthat::expect_equal(nrow(evidence$promoted), 2L)
  testthat::expect_setequal(
    evidence$promoted$metric,
    c("forecast_qtrue_mae_H1000", "forecast_check_loss_H1000")
  )
  testthat::expect_equal(nrow(evidence$chain_points), 3L)
  testthat::expect_equal(nrow(evidence$draws), 600L)
  testthat::expect_equal(nrow(evidence$interval_draws), 3000L)
  testthat::expect_equal(
    vapply(evidence$interval_draws_by_chain, nrow, integer(1L)),
    rep(1000L, 3L)
  )
  testthat::expect_identical(evidence$replay_decision$status, "PASS")
  testthat::expect_identical(
    evidence$replay_decision$interval_precision_decision,
    "PASS_USE_RETAINED_3000_DRAWS"
  )
  attribution <- idolp_v2_origin_lead_comparison(evidence)
  testthat::expect_equal(nrow(attribution), 192L)
  testthat::expect_setequal(attribution$dimension, c("lead", "origin"))
  testthat::expect_equal(sort(unique(attribution$chain_id)), 1:3)
  testthat::expect_true(all(vapply(
    attribution[c("candidate_mae", "control_mae", "candidate_check",
                  "control_check")],
    function(x) all(is.finite(x)), logical(1L)
  )))
})

testthat::test_that("retained V2 draws trigger only the declared precision replay", {
  repo <- normalizePath(
    system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/",
    mustWork = TRUE
  )
  source(file.path(repo, "validation", "fitforecast_v2", "R", "utils.R"),
         local = TRUE)
  source(file.path(
    repo, "validation", "fitforecast_v2", "R",
    "independent_location_orthogonalized_tau0_v2.R"
  ), local = TRUE)
  source(file.path(
    repo, "validation", "fitforecast_v2", "R",
    "independent_location_orthogonalized_tau0_v2_promotion.R"
  ), local = TRUE)
  evidence <- idolp_v2_assert_evidence(repo, require_clean = FALSE)
  sensitivity <- idolp_v2_interval_sensitivity(
    evidence$draws_by_chain, evidence$roles
  )
  testthat::expect_identical(
    sensitivity$decision, "STOP_INTERVAL_REPLAY_REQUIRED"
  )
  testthat::expect_identical(
    as.logical(sensitivity$checks$pass), c(TRUE, FALSE)
  )
  check <- sensitivity$checks[
    sensitivity$checks$metric_role == "forecast_check", , drop = FALSE
  ]
  testthat::expect_gt(
    check$bootstrap_max_endpoint_mcse_over_width,
    check$bootstrap_endpoint_mcse_width_limit
  )
  testthat::expect_lt(
    check$bootstrap_max_endpoint_mcse_over_width, 0.06
  )
})

testthat::test_that("interval replay changes only the metric draw budget", {
  repo <- normalizePath(
    system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/",
    mustWork = TRUE
  )
  source(file.path(repo, "validation", "fitforecast_v2", "R", "utils.R"),
         local = TRUE)
  source(file.path(
    repo, "validation", "fitforecast_v2", "R",
    "independent_location_orthogonalized_tau0_v2.R"
  ), local = TRUE)
  source(file.path(
    repo, "validation", "fitforecast_v2", "R",
    "independent_location_orthogonalized_tau0_v2_promotion.R"
  ), local = TRUE)
  source(file.path(
    repo, "validation", "fitforecast_v2", "R",
    "independent_location_orthogonalized_tau0_v2_interval_replay.R"
  ), local = TRUE)
  source_plan <- idolv2r_source_plan(repo)
  for (i in seq_len(nrow(source_plan))) {
    source_job <- idolp_v2_read_json(source_plan$config_path[[i]])
    replay <- idolv2r_replay_job(
      source_job, ffv2_file_sha256(source_plan$config_path[[i]])
    )
    testthat::expect_silent(
      idolv2r_assert_scientific_identity(replay, source_job)
    )
    testthat::expect_equal(
      replay$config$metrics$posterior_metric_intervals$draws, 1000L
    )
    testthat::expect_equal(replay$config$inference$mcmc$n_burn, 5000L)
    testthat::expect_equal(replay$config$inference$mcmc$n_mcmc, 20000L)
    testthat::expect_identical(
      replay$config$inference$mcmc$control,
      source_job$config$inference$mcmc$control
    )
    testthat::expect_identical(
      replay$config$inference$mcmc$priors,
      source_job$config$inference$mcmc$priors
    )
  }
})

testthat::test_that("V2 promotion and replay entry points parse", {
  repo <- normalizePath(
    system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/",
    mustWork = TRUE
  )
  scripts <- file.path(
    repo, "validation", "fitforecast_v2", "scripts",
    c(
      "promote_independent_location_orthogonalized_tau0_v2.R",
      "verify_independent_location_orthogonalized_tau0_v2_promotion.R",
      "materialize_independent_location_orthogonalized_tau0_v2_interval_replay.R",
      "verify_independent_location_orthogonalized_tau0_v2_interval_replay.R"
    )
  )
  testthat::expect_true(all(file.exists(scripts)))
  for (script in scripts) testthat::expect_silent(parse(script))
  shells <- file.path(
    repo, "validation", "fitforecast_v2", "scripts",
    c(
      "run_independent_location_orthogonalized_tau0_v2_interval_replay.sh",
      "launch_independent_location_orthogonalized_tau0_v2_interval_replay.sh"
    )
  )
  status <- vapply(shells, function(script) {
    result <- system2("bash", c("-n", script), stdout = TRUE, stderr = TRUE)
    value <- attr(result, "status")
    if (is.null(value)) 0L else as.integer(value)
  }, integer(1L))
  testthat::expect_true(all(status == 0L))
})

testthat::test_that("materialized V11 authorities verify independently", {
  repo <- normalizePath(
    system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/",
    mustWork = TRUE
  )
  point <- file.path(
    repo, "validation", "fitforecast_v2", "promotions",
    "qdesn_dqlm_500obs_trainonly_article_v11_location_orthogonalized_20260827"
  )
  testthat::skip_if_not(dir.exists(point))
  verifier <- file.path(
    repo, "validation", "fitforecast_v2", "scripts",
    "verify_independent_location_orthogonalized_tau0_v2_promotion.R"
  )
  output <- system2(file.path(R.home("bin"), "Rscript"), verifier,
                    stdout = TRUE, stderr = TRUE)
  status <- attr(output, "status")
  if (is.null(status)) status <- 0L
  testthat::expect_equal(status, 0L, info = paste(output, collapse = "\n"))
})

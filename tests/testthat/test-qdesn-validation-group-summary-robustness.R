local_group_summary_fns <- local({
  env <- new.env(parent = globalenv())
  src_candidates <- c(
    file.path("R", "qdesn_mcmc_validation.R"),
    file.path("..", "..", "R", "qdesn_mcmc_validation.R")
  )
  src_path <- src_candidates[file.exists(src_candidates)][1L]
  if (!is.character(src_path) || !nzchar(src_path)) {
    stop("Could not locate R/qdesn_mcmc_validation.R for robustness test.")
  }
  sys.source(src_path, envir = env)
  list(
    method = get(".qdesn_validation_group_method_summary", envir = env, inherits = FALSE),
    pair = get(".qdesn_validation_group_pair_summary", envir = env, inherits = FALSE),
    tau_method = get(".qdesn_validation_group_tau_set_method_summary", envir = env, inherits = FALSE),
    tau_pair = get(".qdesn_validation_group_tau_set_pair_summary", envir = env, inherits = FALSE)
  )
})

test_that("group method summary handles missing numeric columns without merge failure", {
  method_df <- data.frame(
    scenario = "toy",
    tau = 0.25,
    beta_prior_type = "rhs",
    reservoir_profile = "tiny_d1_n8",
    method = "mcmc",
    status = "FAIL",
    finite_ok = FALSE,
    domain_ok = FALSE,
    signoff_grade = "FAIL",
    comparison_eligible = FALSE,
    stringsAsFactors = FALSE
  )

  out <- local_group_summary_fns$method(method_df)
  expect_true(is.data.frame(out))
  expect_equal(nrow(out), 1L)
  expect_true(all(c("scenario", "tau", "beta_prior_type", "reservoir_profile", "method", "n_roots") %in% names(out)))
  expect_equal(out$n_roots[[1L]], 1)
  expect_equal(out$n_signoff_fail[[1L]], 1)
})

test_that("group pair summary handles missing numeric columns without merge failure", {
  pair_df <- data.frame(
    scenario = "toy",
    tau = 0.25,
    beta_prior_type = "rhs",
    reservoir_profile = "tiny_d1_n8",
    both_success = FALSE,
    both_finite_ok = FALSE,
    both_domain_ok = FALSE,
    pair_signoff_grade = "FAIL",
    pair_comparison_eligible = FALSE,
    mcmc_better_qhat_mae = FALSE,
    mcmc_better_pinball_tau = FALSE,
    stringsAsFactors = FALSE
  )

  out <- local_group_summary_fns$pair(pair_df)
  expect_true(is.data.frame(out))
  expect_equal(nrow(out), 1L)
  expect_true(all(c("scenario", "tau", "beta_prior_type", "reservoir_profile", "n_pairs") %in% names(out)))
  expect_equal(out$n_pairs[[1L]], 1)
  expect_equal(out$n_pair_signoff_fail[[1L]], 1)
})

test_that("tau-set method summary labels complete healthy packs", {
  method_df <- data.frame(
    scenario = rep("toy", 3),
    tau = c(0.05, 0.50, 0.95),
    beta_prior_type = rep("rhs_ns", 3),
    seed = rep(123L, 3),
    reservoir_profile = rep("tiny_d1_n8", 3),
    method = rep("vb", 3),
    status = rep("SUCCESS", 3),
    finite_ok = rep(TRUE, 3),
    domain_ok = rep(TRUE, 3),
    signoff_grade = rep("PASS", 3),
    unhealthy = rep(FALSE, 3),
    wall_seconds = c(1, 2, 3),
    forecast_pinball_tau = c(0.10, 0.11, 0.12),
    stringsAsFactors = FALSE
  )

  out <- local_group_summary_fns$tau_method(method_df, tau_targets = c(0.05, 0.50, 0.95))
  expect_true(is.data.frame(out))
  expect_equal(nrow(out), 1L)
  expect_identical(as.character(out$synthesis_status[[1L]]), "COMPLETE_HEALTHY")
  expect_true(isTRUE(out$tau_complete_healthy[[1L]]))
  expect_equal(as.integer(out$n_tau_present[[1L]]), 3L)
  expect_equal(as.numeric(out$wall_seconds_sum[[1L]]), 6)
})

test_that("tau-set pair summary flags incomplete packs when one method misses tau", {
  method_df <- data.frame(
    scenario = c(rep("toy", 3), rep("toy", 2)),
    tau = c(0.05, 0.50, 0.95, 0.05, 0.50),
    beta_prior_type = rep("rhs_ns", 5),
    seed = rep(123L, 5),
    reservoir_profile = rep("tiny_d1_n8", 5),
    method = c(rep("vb", 3), rep("mcmc", 2)),
    status = rep("SUCCESS", 5),
    finite_ok = rep(TRUE, 5),
    domain_ok = rep(TRUE, 5),
    signoff_grade = rep("PASS", 5),
    unhealthy = rep(FALSE, 5),
    wall_seconds = c(1, 1, 1, 5, 5),
    stringsAsFactors = FALSE
  )

  tau_method <- local_group_summary_fns$tau_method(method_df, tau_targets = c(0.05, 0.50, 0.95))
  pair_out <- local_group_summary_fns$tau_pair(tau_method)
  expect_true(is.data.frame(pair_out))
  expect_equal(nrow(pair_out), 1L)
  expect_identical(as.character(pair_out$pair_synthesis_status[[1L]]), "INCOMPLETE")
  expect_false(isTRUE(pair_out$pair_comparison_eligible[[1L]]))
})

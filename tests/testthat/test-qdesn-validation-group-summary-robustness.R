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
    pair = get(".qdesn_validation_group_pair_summary", envir = env, inherits = FALSE)
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

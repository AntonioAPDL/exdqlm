make_precision_root_spec <- function() {
  list(
    root_id = "root__dynamic__dlm_constV_smallW__laplace__tau_0p50__lasttt_5000__qdesn_ridge",
    scenario = "dynamic",
    tau = 0.50,
    likelihood_family = "exal",
    beta_prior_type = "ridge",
    seed = 41000L,
    reservoir_profile = "qdesn_ridge"
  )
}

test_that("failure health rows persist precision-beta failure summaries without a fit object", {
  payload <- list(
    precision_beta_failure = list(
      failure_family = "precision_beta_chol_failure",
      iteration = 701L,
      phase = "burn",
      sigma = 0.17,
      gamma = 1.2,
      tau = 0.50,
      c2 = NA_real_,
      beta_norm = 3.1,
      theta_update_reason = "scheduled",
      conditioning_mode = "qr_whiten",
      core_update_mode = "gamma_sigma_gamma",
      precision_strategy = "eigen_floor",
      precision_attempt_count = 6L,
      precision_jitter_used = 1e-6,
      precision_max_jitter_tried = 1e-4,
      precision_eigen_attempted = TRUE,
      precision_eigen_floor = 1e-6,
      precision_min_eigen = -0.23,
      precision_matrix_dim = 404L,
      precision_diag_min = 0.01,
      precision_diag_mean = 1.2,
      precision_diag_max = 22.1,
      precision_symmetry_max_abs_diff = 3e-12
    )
  )

  health <- exdqlm:::.qdesn_validation_failure_health_row(
    method = "mcmc",
    root_spec = make_precision_root_spec(),
    status = "FAIL",
    error_payload = payload
  )

  expect_identical(as.character(health$mcmc_failure_family[[1L]]), "precision_beta_chol_failure")
  expect_equal(health$mcmc_failure_iteration, 701L)
  expect_identical(as.character(health$mcmc_failure_phase[[1L]]), "burn")
  expect_identical(as.character(health$mcmc_failure_precision_strategy[[1L]]), "eigen_floor")
  expect_equal(health$mcmc_failure_precision_attempt_count, 6L)
  expect_equal(health$mcmc_failure_precision_matrix_dim, 404L)
  expect_true(isTRUE(health$mcmc_failure_precision_eigen_attempted))
  expect_equal(health$mcmc_failure_precision_min_eigen, -0.23, tolerance = 1e-12)
})

test_that("error payload parser recovers precision-beta failure marker from pipeline logs", {
  payload_json <- jsonlite::toJSON(
    list(
      failure_family = "precision_beta_chol_failure",
      iteration = 812L,
      phase = "burn",
      sigma = 0.18,
      gamma = 1.05,
      tau = 0.50,
      beta_norm = 2.7,
      conditioning_mode = "diag_scale",
      core_update_mode = "sigma_then_gamma",
      precision_strategy = "jitter",
      precision_attempt_count = 5L,
      precision_jitter_used = 1e-4,
      precision_max_jitter_tried = 1e-2,
      precision_eigen_attempted = FALSE,
      precision_matrix_dim = 352L,
      precision_diag_min = 0.02,
      precision_diag_mean = 0.9,
      precision_diag_max = 18.4,
      precision_symmetry_max_abs_diff = 2e-11
    ),
    auto_unbox = TRUE,
    null = "null"
  )

  payload <- exdqlm:::.qdesn_validation_extract_error_payload(
    log_lines = c(
      "[pipeline_stdout] burn-in iteration 800",
      sprintf("QDESN_PRECISION_BETA_FAILURE_JSON=%s", payload_json),
      "Error in chol.default(Prec + 1e-10 * diag(nrow(Prec)))"
    )
  )

  expect_identical(payload$precision_beta_failure$failure_family, "precision_beta_chol_failure")
  expect_equal(payload$precision_beta_failure$iteration, 812L)
  expect_identical(payload$precision_beta_failure$precision_strategy, "jitter")
  expect_equal(payload$precision_beta_failure$precision_jitter_used, 1e-4, tolerance = 1e-12)
})

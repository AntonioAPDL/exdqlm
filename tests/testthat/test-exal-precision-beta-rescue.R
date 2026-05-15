test_that("precision beta jitter ladder rescues near-indefinite precision draws", {
  withr::local_seed(101)

  out <- exdqlm:::.exal_mcmc_sample_mvnorm_prec(
    rhs = c(0, 0),
    Prec = diag(c(1, -1e-7), 2L),
    precision_beta_cfg = list(
      enabled = TRUE,
      symmetrize = TRUE,
      jitter_ladder = c(0, 1e-6),
      eigen_fallback = FALSE
    )
  )

  expect_true(is.list(out))
  expect_length(out$draw, 2L)
  expect_true(all(is.finite(out$draw)))
  expect_identical(as.character(out$info$strategy), "jitter")
  expect_equal(as.numeric(out$info$jitter_used), 1e-6, tolerance = 1e-12)
})

test_that("precision beta eigen fallback rescues strongly indefinite precision draws", {
  withr::local_seed(102)

  out <- exdqlm:::.exal_mcmc_sample_mvnorm_prec(
    rhs = c(0, 0),
    Prec = matrix(c(1, 2, 2, 1), 2, 2),
    precision_beta_cfg = list(
      enabled = TRUE,
      symmetrize = TRUE,
      jitter_ladder = c(0, 1e-6),
      eigen_fallback = TRUE,
      eigen_floor_abs = 1e-4,
      eigen_floor_rel = 1e-6
    )
  )

  expect_true(is.list(out))
  expect_length(out$draw, 2L)
  expect_true(all(is.finite(out$draw)))
  expect_true(grepl("^eigen", as.character(out$info$strategy)))
  expect_true(isTRUE(out$info$eigen_attempted))
})

test_that("precision beta rescue surfaces structured failure payloads when unrepaired", {
  withr::local_seed(103)

  err <- tryCatch(
    exdqlm:::.exal_mcmc_sample_mvnorm_prec(
      rhs = c(0, 0),
      Prec = matrix(c(1, 2, 2, 1), 2, 2),
      precision_beta_cfg = list(
        enabled = TRUE,
        symmetrize = TRUE,
        jitter_ladder = c(0, 1e-6),
        eigen_fallback = FALSE
      ),
      context = list(
        iter = 7L,
        n_burn = 20L,
        likelihood_family = "exal",
        beta_prior_type = "ridge",
        sigma = 0.3,
        gamma = 1.1,
        beta = c(0.2, -0.1),
        conditioning_mode = "qr_whiten",
        core_update_mode = "gamma_sigma_gamma"
      )
    ),
    error = identity
  )

  expect_true(inherits(err, "qdesn_precision_beta_error"))
  expect_identical(err$precision_beta_failure$failure_family, "precision_beta_chol_failure")
  expect_equal(err$precision_beta_failure$iteration, 7L)
  expect_identical(err$precision_beta_failure$phase, "burn")
  expect_identical(err$precision_beta_failure$conditioning_mode, "qr_whiten")
  expect_identical(err$precision_beta_failure$core_update_mode, "gamma_sigma_gamma")
  expect_true(is.finite(err$precision_beta_failure$precision_max_jitter_tried))
})

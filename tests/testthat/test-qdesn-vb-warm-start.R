tiny_qdesn_series_for_warm_start_tests <- function(n = 28L) {
  t <- seq_len(n)
  as.numeric(0.15 * sin(t / 4) + 0.08 * cos(t / 7))
}

tiny_qdesn_warm_common <- function(seed = 20260601L) {
  list(
    p0 = 0.5,
    D = 1L,
    n = 4L,
    m = 1L,
    washout = 4L,
    add_bias = TRUE,
    seed = as.integer(seed),
    fit_readout = TRUE
  )
}

tiny_qdesn_warm_vb_args <- function(likelihood_family = "al",
                                    beta_prior_type = "ridge",
                                    chunking = NULL,
                                    max_iter = 8L) {
  args <- list(
    likelihood_family = likelihood_family,
    al_fixed_gamma = if (identical(likelihood_family, "al")) 0 else NULL,
    max_iter = as.integer(max_iter),
    min_iter_elbo = 2L,
    tol = 0,
    tol_par = 0,
    n_samp_xi = 16L,
    verbose = FALSE,
    beta_prior_type = beta_prior_type,
    beta_ridge_tau2 = 10,
    beta_rhs = list(
      tau0 = 0.5,
      s2 = 1,
      shrink_intercept = FALSE,
      n_inner = 1L
    )
  )
  if (!is.null(chunking)) args$chunking <- chunking
  args
}

test_that("qdesn_vb_make_warm_start records state and validates dimensions", {
  y <- tiny_qdesn_series_for_warm_start_tests()
  common <- tiny_qdesn_warm_common()
  args <- tiny_qdesn_warm_vb_args("al", "ridge", max_iter = 5L)

  fit <- do.call(exdqlm::qdesn_fit_vb, c(list(y = y), common, list(vb_args = args)))
  warm <- exdqlm::qdesn_vb_make_warm_start(fit, package_sha = "test-sha")

  expect_s3_class(warm, "qdesn_vb_warm_start")
  expect_identical(warm$type, "qdesn_vb_warm_start")
  expect_identical(warm$version, "0.1")
  expect_equal(warm$design$n_rows, nrow(fit$X))
  expect_equal(warm$design$n_features, ncol(fit$X))
  expect_true(nzchar(warm$design$design_hash))
  expect_identical(warm$likelihood$family, "al")
  expect_identical(warm$prior$family, "ridge")
  expect_equal(warm$package$sha, "test-sha")
  expect_equal(length(warm$qbeta$mean), ncol(fit$X))
  expect_equal(dim(warm$qbeta$cov), c(ncol(fit$X), ncol(fit$X)))
  expect_equal(length(warm$qv$mean), nrow(fit$X))
  expect_true(all(is.finite(warm$qv$mean)))
  expect_true(all(warm$qv$mean > 0))

  tmp <- tempfile(fileext = ".rds")
  saveRDS(warm, tmp)
  warm_roundtrip <- readRDS(tmp)
  expect_s3_class(warm_roundtrip, "qdesn_vb_warm_start")
  expect_equal(warm_roundtrip$qbeta$mean, warm$qbeta$mean, tolerance = 1e-12)
  expect_identical(warm_roundtrip$design$design_hash, warm$design$design_hash)
})

test_that("Q-DESN warm start routes to the same init as explicit engine init", {
  y <- tiny_qdesn_series_for_warm_start_tests()
  common <- tiny_qdesn_warm_common(seed = 20260602L)
  base_args <- tiny_qdesn_warm_vb_args("al", "ridge", max_iter = 5L)

  seed_fit <- do.call(exdqlm::qdesn_fit_vb, c(list(y = y), common, list(vb_args = base_args)))
  warm <- exdqlm::qdesn_vb_make_warm_start(seed_fit)

  prior_obj <- exdqlm:::exal_make_beta_prior(type = "ridge", tau2 = 10, rhs = list())
  direct_init <- exdqlm:::.qdesn_vb_warm_start_to_init(
    warm_start = warm,
    X = seed_fit$X,
    p0 = 0.5,
    likelihood_family = "al",
    beta_prior_obj = prior_obj,
    al_fixed_gamma = 0
  )

  warm_args <- tiny_qdesn_warm_vb_args("al", "ridge", max_iter = 4L)
  warm_args$warm_start <- warm
  direct_args <- tiny_qdesn_warm_vb_args("al", "ridge", max_iter = 4L)
  direct_args$init <- direct_init

  fit_warm <- do.call(exdqlm::qdesn_fit_vb, c(list(y = y), common, list(vb_args = warm_args)))
  fit_direct <- do.call(exdqlm::qdesn_fit_vb, c(list(y = y), common, list(vb_args = direct_args)))

  expect_true(is.list(fit_warm$meta$warm_start))
  expect_equal(fit_warm$fit$qbeta$m, fit_direct$fit$qbeta$m, tolerance = 1e-10)
  expect_equal(fit_warm$fit$qbeta$V, fit_direct$fit$qbeta$V, tolerance = 1e-10)
  expect_equal(fit_warm$fit$qv$m, fit_direct$fit$qv$m, tolerance = 1e-10)
  expect_equal(fit_warm$fit$misc$sigma_trace, fit_direct$fit$misc$sigma_trace, tolerance = 1e-10)
})

test_that("warm-started exact chunking remains equivalent to warm-started unchunked AL", {
  y <- tiny_qdesn_series_for_warm_start_tests()
  common <- tiny_qdesn_warm_common(seed = 20260603L)
  base_args <- tiny_qdesn_warm_vb_args("al", "ridge", max_iter = 5L)

  seed_fit <- do.call(exdqlm::qdesn_fit_vb, c(list(y = y), common, list(vb_args = base_args)))
  warm <- exdqlm::qdesn_vb_make_warm_start(seed_fit)

  unchunked_args <- tiny_qdesn_warm_vb_args("al", "ridge", max_iter = 5L)
  unchunked_args$warm_start <- warm
  exact_args <- tiny_qdesn_warm_vb_args(
    "al",
    "ridge",
    chunking = list(enabled = TRUE, mode = "exact", chunk_size = 5L),
    max_iter = 5L
  )
  exact_args$warm_start <- warm

  fit_unchunked <- do.call(exdqlm::qdesn_fit_vb, c(list(y = y), common, list(vb_args = unchunked_args)))
  fit_exact <- do.call(exdqlm::qdesn_fit_vb, c(list(y = y), common, list(vb_args = exact_args)))

  expect_equal(fit_exact$fit$qbeta$m, fit_unchunked$fit$qbeta$m, tolerance = 1e-8)
  expect_equal(fit_exact$fit$qbeta$V, fit_unchunked$fit$qbeta$V, tolerance = 1e-8)
  expect_equal(fit_exact$fit$qv$m, fit_unchunked$fit$qv$m, tolerance = 1e-8)
  expect_equal(fit_exact$fit$qs$m, fit_unchunked$fit$qs$m, tolerance = 1e-8)
})

test_that("Q-DESN warm starts support exAL and RHS_NS finite states", {
  y <- tiny_qdesn_series_for_warm_start_tests()
  common <- tiny_qdesn_warm_common(seed = 20260604L)
  base_args <- tiny_qdesn_warm_vb_args("exal", "rhs_ns", max_iter = 5L)

  seed_fit <- do.call(exdqlm::qdesn_fit_vb, c(list(y = y), common, list(vb_args = base_args)))
  warm <- exdqlm::qdesn_vb_make_warm_start(seed_fit)
  expect_identical(warm$likelihood$family, "exal")
  expect_identical(warm$prior$family, "rhs_ns")
  expect_true(is.list(warm$rhs))

  warm_args <- tiny_qdesn_warm_vb_args("exal", "rhs_ns", max_iter = 4L)
  warm_args$warm_start <- warm
  fit_warm <- do.call(exdqlm::qdesn_fit_vb, c(list(y = y), common, list(vb_args = warm_args)))

  expect_s3_class(fit_warm$fit, "exal_vb")
  expect_identical(fit_warm$fit$beta_prior$type, "rhs_ns")
  expect_true(all(is.finite(fit_warm$fit$qbeta$m)))
  expect_true(all(is.finite(fit_warm$fit$qv$m)))
  expect_true(all(is.finite(fit_warm$fit$qs$m)))
  expect_true(is.finite(fit_warm$fit$qsiggam$sigma_mean))
})

test_that("Q-DESN warm starts fail early on mismatches and stochastic mode", {
  y <- tiny_qdesn_series_for_warm_start_tests()
  common <- tiny_qdesn_warm_common(seed = 20260605L)
  base_args <- tiny_qdesn_warm_vb_args("al", "ridge", max_iter = 5L)

  seed_fit <- do.call(exdqlm::qdesn_fit_vb, c(list(y = y), common, list(vb_args = base_args)))
  warm <- exdqlm::qdesn_vb_make_warm_start(seed_fit)

  bad_design <- warm
  bad_design$design$design_hash <- "not-the-design"
  bad_args <- base_args
  bad_args$warm_start <- bad_design
  expect_error(
    do.call(exdqlm::qdesn_fit_vb, c(list(y = y), common, list(vb_args = bad_args))),
    "design hash"
  )

  bad_likelihood <- warm
  bad_likelihood$likelihood$family <- "exal"
  bad_args <- base_args
  bad_args$warm_start <- bad_likelihood
  expect_error(
    do.call(exdqlm::qdesn_fit_vb, c(list(y = y), common, list(vb_args = bad_args))),
    "likelihood family mismatch"
  )

  stochastic_args <- base_args
  stochastic_args$warm_start <- warm
  stochastic_args$chunking <- list(
    enabled = TRUE,
    mode = "stochastic",
    chunk_size = 5L,
    order = "random",
    seed = 20260605L
  )
  expect_error(
    do.call(exdqlm::qdesn_fit_vb, c(list(y = y), common, list(vb_args = stochastic_args))),
    "warm starts for stochastic/hybrid VB are not implemented"
  )

  hybrid_args <- base_args
  hybrid_args$warm_start <- warm
  hybrid_args$chunking <- list(
    enabled = TRUE,
    mode = "hybrid",
    chunk_size = 5L,
    order = "random",
    seed = 20260605L
  )
  expect_error(
    do.call(exdqlm::qdesn_fit_vb, c(list(y = y), common, list(vb_args = hybrid_args))),
    "warm starts for stochastic/hybrid VB are not implemented"
  )
})

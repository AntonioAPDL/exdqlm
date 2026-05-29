test_that("Normal DESN warm-start state records and validates exact ridge fits", {
  set.seed(2026052901L)
  X <- cbind(1, matrix(rnorm(60), nrow = 20L))
  beta <- c(0.3, -0.5, 0.2, 0.1)
  y <- drop(X %*% beta + rnorm(nrow(X), sd = 0.2))

  fit <- exdqlm::normal_desn_fit(X, y)
  ws <- exdqlm::qdesn_normal_make_warm_start(fit, X = X, package_sha = "test-sha")

  expect_s3_class(ws, "qdesn_normal_warm_start")
  expect_identical(ws$type, "qdesn_normal_warm_start")
  expect_identical(ws$target$family, "normal")
  expect_identical(ws$target$label, "normal_scaled_ridge_exact")
  expect_identical(ws$target$exact_status, "exact")
  expect_identical(ws$package$sha, "test-sha")
  expect_identical(ws$design$n_features, as.integer(ncol(X)))
  expect_equal(ws$beta$mean, fit$beta$mean, tolerance = 1e-12)
  expect_equal(ws$beta$cov, fit$beta$cov, tolerance = 1e-12)
  expect_true(isTRUE(exdqlm::qdesn_normal_validate_warm_start(ws, X = X)))
})

test_that("Normal DESN warm-start state distinguishes exact chunked fits", {
  set.seed(2026052902L)
  X <- cbind(1, matrix(rnorm(75), nrow = 25L))
  y <- drop(X %*% c(0.1, 0.2, -0.3, 0.4) + rnorm(nrow(X), sd = 0.25))

  fit <- exdqlm::normal_desn_fit(
    X,
    y,
    control = list(chunking = list(
      enabled = TRUE,
      mode = "exact",
      chunk_size = 6L,
      order = "sequential",
      trace = FALSE
    ))
  )
  ws <- exdqlm::qdesn_normal_make_warm_start(fit, X = X)

  expect_identical(ws$target$exact_status, "exact_chunked")
  expect_identical(ws$target$label, "normal_scaled_ridge_exact_chunked")
  expect_true(isTRUE(exdqlm::qdesn_normal_validate_warm_start(ws, X = X)))
})

test_that("Normal DESN warm-start state validates Q-DESN metadata and serialization", {
  y <- sin(seq_len(42L) / 4) + rnorm(42L, sd = 0.05)
  fit <- exdqlm::qdesn_fit_normal(
    y = y,
    p0 = 0.5,
    D = 1L,
    n = 4L,
    m = 1L,
    washout = 5L,
    add_bias = TRUE,
    seed = 2026052903L
  )
  ws <- exdqlm::qdesn_normal_make_warm_start(fit)

  expect_false(is.na(ws$qdesn$feature_settings_hash))
  expect_true(isTRUE(exdqlm::qdesn_normal_validate_warm_start(ws, X = fit$X, meta = fit$meta)))

  tmp <- tempfile(fileext = ".rds")
  saveRDS(ws, tmp)
  ws2 <- readRDS(tmp)
  expect_true(isTRUE(exdqlm::qdesn_normal_validate_warm_start(ws2, X = fit$X, meta = fit$meta)))

  bad_X <- fit$X
  bad_X[1L, 1L] <- bad_X[1L, 1L] + 0.01
  expect_error(
    exdqlm::qdesn_normal_validate_warm_start(ws, X = bad_X),
    "design hash mismatch"
  )

  bad_meta <- fit$meta
  bad_meta$n <- bad_meta$n + 1L
  expect_error(
    exdqlm::qdesn_normal_validate_warm_start(ws, X = fit$X, meta = bad_meta),
    "feature settings hash mismatch"
  )
})

test_that("Normal DESN warm-start validation rejects corrupted states", {
  set.seed(2026052904L)
  X <- cbind(1, matrix(rnorm(48), nrow = 16L))
  y <- drop(X %*% c(0.2, -0.1, 0.1, 0.5) + rnorm(nrow(X), sd = 0.15))
  ws <- exdqlm::qdesn_normal_make_warm_start(exdqlm::normal_desn_fit(X, y), X = X)

  bad_cov <- ws
  bad_cov$beta$cov[1L, 1L] <- -1
  expect_error(
    exdqlm::qdesn_normal_validate_warm_start(bad_cov),
    "positive definite"
  )

  bad_omega <- ws
  bad_omega$omega2$mean <- -1
  bad_omega$omega2$mode <- NA_real_
  expect_error(
    exdqlm::qdesn_normal_validate_warm_start(bad_omega),
    "omega2"
  )

  bad_sha <- ws
  bad_sha$package$sha <- "not-current-sha"
  expect_true(isTRUE(exdqlm::qdesn_normal_validate_warm_start(bad_sha, X = X)))
  expect_error(
    exdqlm::qdesn_normal_validate_warm_start(bad_sha, X = X, validate_package_sha = TRUE),
    "package SHA mismatch"
  )
})

test_that("Normal DESN warm-start converters preserve moments and source metadata", {
  y <- cos(seq_len(36L) / 5) + rnorm(36L, sd = 0.08)
  fit <- exdqlm::qdesn_fit_normal(
    y = y,
    p0 = 0.5,
    D = 1L,
    n = 4L,
    m = 1L,
    washout = 5L,
    add_bias = TRUE,
    seed = 2026052905L
  )
  ws <- exdqlm::qdesn_normal_make_warm_start(fit)

  direct_vb <- exdqlm::qdesn_normal_to_vb_init(
    fit,
    likelihood_family = "al",
    beta_prior_type = "ridge",
    p0 = 0.5
  )
  warm_vb <- exdqlm::qdesn_normal_warm_start_to_vb_init(
    ws,
    likelihood_family = "al",
    beta_prior_type = "ridge",
    p0 = 0.5
  )
  warm_mcmc <- exdqlm::qdesn_normal_warm_start_to_mcmc_init(
    ws,
    likelihood_family = "exal",
    beta_prior_type = "rhs_ns",
    p0 = 0.5,
    gamma = 0.2
  )

  expect_equal(warm_vb$beta_m, direct_vb$beta_m, tolerance = 1e-12)
  expect_equal(warm_vb$beta_V, direct_vb$beta_V, tolerance = 1e-12)
  expect_identical(warm_vb$source$source_type, "qdesn_normal_warm_start")
  expect_identical(warm_vb$source$design_hash, ws$design$design_hash)
  expect_identical(warm_vb$source$feature_settings_hash, ws$qdesn$feature_settings_hash)
  expect_identical(warm_vb$source$package_sha, ws$package$sha)

  expect_equal(warm_mcmc$beta, fit$fit$beta$mean, tolerance = 1e-12)
  expect_identical(warm_mcmc$source$source_type, "qdesn_normal_warm_start")
  expect_identical(warm_mcmc$source$design_hash, ws$design$design_hash)
  expect_equal(warm_mcmc$gamma, 0.2, tolerance = 0)
})

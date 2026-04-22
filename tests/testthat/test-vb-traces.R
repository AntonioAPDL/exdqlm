tiny_vb_trace_dyn_model <- function(TT) {
  as.exdqlm(list(
    m0 = 0,
    C0 = matrix(1, 1, 1),
    FF = matrix(1, nrow = 1, ncol = TT),
    GG = array(1, dim = c(1, 1, TT))
  ))
}

expect_vb_trace_columns <- function(x) {
  expect_true(all(c(
    "iter", "engine", "dqlm.ind",
    "elbo", "sigma", "gamma",
    "delta_state", "delta_sigma", "delta_gamma", "delta_s", "delta_elbo"
  ) %in% names(x)))
}

test_that("dynamic ISVB stores a standardized vb_trace diagnostics table", {
  set.seed(20260420)
  TT <- 24
  y <- cumsum(stats::rnorm(TT, sd = 0.2))
  model <- tiny_vb_trace_dyn_model(TT)

  old_opts <- options(
    exdqlm.use_cpp_kf = FALSE,
    exdqlm.compute_elbo = TRUE,
    exdqlm.max_iter = 20L,
    exdqlm.vb.min_iter = 3L,
    exdqlm.vb.patience = 2L
  )
  on.exit(options(old_opts), add = TRUE)

  fit <- exdqlmISVB(
    y = y, p0 = 0.5, model = model, df = 1, dim.df = 1,
    fix.sigma = FALSE, tol = 0.1, n.IS = 80, n.samp = 10,
    verbose = FALSE
  )

  tr <- fit$diagnostics$vb_trace
  expect_s3_class(tr, "data.frame")
  expect_vb_trace_columns(tr)
  expect_equal(nrow(tr), fit$iter)
  expect_true(all(tr$engine == "ISVB"))
  expect_true(all(!tr$dqlm.ind))
  expect_equal(tr$iter, seq_len(fit$iter))
  expect_equal(tr$elbo, fit$diagnostics$elbo)
  expect_equal(tr$sigma, fit$seq.sigma[-1], tolerance = 1e-10)
  expect_equal(tr$gamma, fit$seq.gamma[-1], tolerance = 1e-10)
  expect_equal(tr$delta_state, fit$diagnostics$deltas$state, tolerance = 1e-10)
  expect_equal(tr$delta_sigma, fit$diagnostics$deltas$sigma, tolerance = 1e-10)
  expect_equal(tr$delta_gamma, fit$diagnostics$deltas$gamma, tolerance = 1e-10)
  expect_equal(tr$delta_elbo, fit$diagnostics$deltas$elbo, tolerance = 1e-10)
  expect_true(all(is.na(tr$delta_s)))
})

test_that("dynamic LDVB stores a standardized vb_trace diagnostics table", {
  set.seed(20260421)
  TT <- 24
  y <- cumsum(stats::rnorm(TT, sd = 0.15))
  model <- tiny_vb_trace_dyn_model(TT)

  old_opts <- options(
    exdqlm.use_cpp_kf = FALSE,
    exdqlm.compute_elbo = TRUE,
    exdqlm.max_iter = 20L,
    exdqlm.vb.min_iter = 3L,
    exdqlm.vb.patience = 2L
  )
  on.exit(options(old_opts), add = TRUE)

  fit <- exdqlmLDVB(
    y = y, p0 = 0.5, model = model, df = 1, dim.df = 1,
    fix.sigma = FALSE, tol = 0.1, n.samp = 10,
    verbose = FALSE
  )

  tr <- fit$diagnostics$vb_trace
  expect_s3_class(tr, "data.frame")
  expect_vb_trace_columns(tr)
  expect_equal(nrow(tr), fit$iter)
  expect_true(all(tr$engine == "LDVB"))
  expect_true(all(!tr$dqlm.ind))
  expect_equal(tr$iter, seq_len(fit$iter))
  expect_equal(tr$elbo, fit$diagnostics$elbo)
  expect_equal(tr$sigma, fit$seq.sigma[-1], tolerance = 1e-10)
  expect_equal(tr$gamma, fit$seq.gamma[-1], tolerance = 1e-10)
  expect_equal(tr$delta_state, fit$diagnostics$deltas$state, tolerance = 1e-10)
  expect_equal(tr$delta_sigma, fit$diagnostics$deltas$sigma, tolerance = 1e-10)
  expect_equal(tr$delta_gamma, fit$diagnostics$deltas$gamma, tolerance = 1e-10)
  expect_equal(tr$delta_s, fit$diagnostics$deltas$s, tolerance = 1e-10)
  expect_equal(tr$delta_elbo, fit$diagnostics$deltas$elbo, tolerance = 1e-10)
  expect_equal(tr$sigma, fit$diagnostics$ld_block$trace$sigma, tolerance = 1e-10)
  expect_equal(tr$gamma, fit$diagnostics$ld_block$trace$gamma, tolerance = 1e-10)
})

test_that("reduced dynamic VB paths expose vb_trace with gamma columns set to NA", {
  set.seed(20260422)
  TT <- 20
  y <- stats::rnorm(TT, sd = 0.25)
  model <- tiny_vb_trace_dyn_model(TT)

  old_opts <- options(
    exdqlm.use_cpp_kf = FALSE,
    exdqlm.compute_elbo = TRUE,
    exdqlm.max_iter = 18L,
    exdqlm.vb.min_iter = 3L,
    exdqlm.vb.patience = 2L
  )
  on.exit(options(old_opts), add = TRUE)

  fit_isvb <- exdqlmISVB(
    y = y, p0 = 0.5, model = model, df = 1, dim.df = 1,
    dqlm.ind = TRUE, fix.sigma = FALSE, tol = 0.1, n.samp = 10,
    verbose = FALSE
  )
  fit_ldvb <- exdqlmLDVB(
    y = y, p0 = 0.5, model = model, df = 1, dim.df = 1,
    dqlm.ind = TRUE, fix.sigma = FALSE, tol = 0.1, n.samp = 10,
    verbose = FALSE
  )

  for (fit in list(fit_isvb, fit_ldvb)) {
    tr <- fit$diagnostics$vb_trace
    expect_s3_class(tr, "data.frame")
    expect_vb_trace_columns(tr)
    expect_equal(nrow(tr), fit$iter)
    expect_true(all(tr$dqlm.ind))
    expect_true(all(is.na(tr$gamma)))
    expect_true(all(is.na(tr$delta_gamma)))
    expect_equal(tr$elbo, fit$diagnostics$elbo)
  }
  expect_true(all(fit_isvb$diagnostics$vb_trace$engine == "ISVB"))
  expect_true(all(fit_ldvb$diagnostics$vb_trace$engine == "LDVB"))
})

test_that("static LDVB stores a standardized vb_trace diagnostics table", {
  set.seed(20260423)
  n <- 40
  X <- cbind(1, seq(-1, 1, length.out = n))
  y <- as.numeric(X %*% c(0.25, -0.2) + stats::rnorm(n, sd = 0.2))

  fit <- exalStaticLDVB(
    y = y, X = X, p0 = 0.5,
    max_iter = 120, tol = 1e-3, n.samp = 20,
    verbose = FALSE
  )

  tr <- fit$diagnostics$vb_trace
  expect_s3_class(tr, "data.frame")
  expect_vb_trace_columns(tr)
  expect_equal(nrow(tr), fit$iter)
  expect_true(all(tr$engine == "LDVB"))
  expect_true(all(!tr$dqlm.ind))
  expect_equal(tr$iter, seq_len(fit$iter))
  expect_equal(tr$elbo, fit$diagnostics$elbo)
  expect_equal(tr$delta_state, fit$diagnostics$deltas$state, tolerance = 1e-10)
  expect_equal(tr$delta_sigma, fit$diagnostics$deltas$sigma, tolerance = 1e-10)
  expect_equal(tr$delta_gamma, fit$diagnostics$deltas$gamma, tolerance = 1e-10)
  expect_equal(tr$delta_s, fit$diagnostics$deltas$s, tolerance = 1e-10)
  expect_equal(tr$delta_elbo, fit$diagnostics$deltas$elbo, tolerance = 1e-10)
  expect_equal(tr$sigma, fit$diagnostics$ld_block$trace$sigma, tolerance = 1e-10)
  expect_equal(tr$gamma, fit$diagnostics$ld_block$trace$gamma, tolerance = 1e-10)
  expect_true(all(is.finite(tr$elbo)))
  expect_true(all(is.finite(tr$sigma)))
  expect_true(all(is.finite(tr$gamma)))
})

test_that("static reduced LDVB exposes vb_trace with gamma columns set to NA", {
  set.seed(20260424)
  n <- 36
  X <- cbind(1, seq(-1, 1, length.out = n))
  y <- as.numeric(X %*% c(0.15, 0.1) + stats::rnorm(n, sd = 0.15))

  fit <- exalStaticLDVB(
    y = y, X = X, p0 = 0.5,
    dqlm.ind = TRUE,
    max_iter = 100, tol = 1e-3, n.samp = 20,
    verbose = FALSE
  )

  tr <- fit$diagnostics$vb_trace
  expect_s3_class(tr, "data.frame")
  expect_vb_trace_columns(tr)
  expect_equal(nrow(tr), fit$iter)
  expect_true(all(tr$engine == "LDVB"))
  expect_true(all(tr$dqlm.ind))
  expect_true(all(is.na(tr$gamma)))
  expect_true(all(is.na(tr$delta_gamma)))
  expect_true(all(is.finite(tr$elbo)))
  expect_true(all(is.finite(tr$sigma)))
})

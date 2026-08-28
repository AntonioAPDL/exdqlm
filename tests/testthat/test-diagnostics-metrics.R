test_that("dynamic diagnostics expose flipped KL and CRPS metrics", {
  set.seed(20260406)
  TT <- 12
  y <- cumsum(stats::rnorm(TT, sd = 0.15))
  model <- as.exdqlm(list(
    m0 = 0,
    C0 = matrix(1, 1, 1),
    FF = matrix(1, nrow = 1, ncol = TT),
    GG = array(1, dim = c(1, 1, TT))
  ))

  old_exdqlm_opts <- options(
    exdqlm.use_cpp_kf = FALSE,
    exdqlm.compute_elbo = TRUE,
    exdqlm.max_iter = 20L
  )
  on.exit(options(old_exdqlm_opts), add = TRUE)

  fit <- exdqlmLDVB(
    y = y, p0 = 0.5, model = model, df = 1, dim.df = 1,
    dqlm.ind = TRUE, fix.sigma = FALSE,
    tol = 0.05, n.samp = 12, verbose = FALSE
  )
  diags <- exdqlmDiagnostics(
    fit, fit,
    plot = FALSE,
    crps_probs = c(0.25, 0.5, 0.75),
    crps_weights = c(1, 2, 1),
    kl_k = c(1, 3)
  )
  diags_repeat <- exdqlmDiagnostics(
    fit, fit,
    plot = FALSE,
    crps_probs = c(0.25, 0.5, 0.75),
    crps_weights = c(1, 2, 1),
    kl_k = c(1, 3)
  )

  expect_true(all(c("m1.KL.flip", "m1.CRPS", "m2.KL.flip", "m2.CRPS") %in% names(diags)))
  expect_equal(diags$crps.method, "integrated_quantile_score")
  expect_equal(diags$crps.probs, c(0.25, 0.5, 0.75))
  expect_equal(diags$crps.weights, c(0.25, 0.5, 0.25))
  expect_equal(diags$kl.method, "semiclosed_knn_1d")
  expect_equal(diags$kl.k, c(1L, 3L))
  expect_equal(diags$kl.aggregate, "median")
  expect_equal(diags$kl.reference, "normal_quantile_grid")
  expect_equal(diags$m1.KL, diags_repeat$m1.KL)
  expect_equal(diags$m1.KL.flip, diags_repeat$m1.KL.flip)
  expect_equal(diags$m2.KL, diags_repeat$m2.KL)
  expect_equal(diags$m2.KL.flip, diags_repeat$m2.KL.flip)
  expect_false(any(c("m1.KL.by_k", "m1.KL.gaussian", "m2.KL.by_k", "m2.KL.gaussian") %in% names(diags)))
  expect_named(diags$kl.details, c("m1", "m2"))
  expect_equal(diags$kl.details$m1$primary$name, "KL")
  expect_equal(diags$kl.details$m1$primary$estimate, diags$m1.KL)
  expect_equal(diags$kl.details$m1$flipped$name, "KL.flip")
  expect_equal(diags$kl.details$m1$flipped$estimate, diags$m1.KL.flip)
  expect_equal(diags$kl.details$m1$primary$role, "primary calibration diagnostic")
  expect_equal(diags$kl.details$m1$flipped$role, "secondary sensitivity diagnostic")
  expect_s3_class(diags$kl.details$m1$sensitivity$forward_by_k, "data.frame")
  expect_s3_class(diags$kl.details$m1$sensitivity$flipped_by_k, "data.frame")
  expect_equal(diags$kl.details$m1$sensitivity$forward_by_k$k, c(1L, 3L))
  expect_equal(diags$kl.details$m1$sensitivity$flipped_by_k$k, c(1L, 3L))
  expect_equal(diags$kl.details$m1$metadata$method, diags$kl.method)
  expect_equal(diags$kl.details$m1$metadata$k, diags$kl.k)
  expect_true(all(is.finite(c(
    diags$kl.details$m1$sensitivity$gaussian_plugin,
    diags$kl.details$m2$sensitivity$gaussian_plugin
  ))))
  expect_true(all(is.finite(c(
    diags$m1.KL, diags$m1.KL.flip, diags$m1.CRPS,
    diags$m2.KL, diags$m2.KL.flip, diags$m2.CRPS
  ))))

  ref_grid <- stats::qnorm((seq_len(TT) - 0.5) / TT)
  diags_ref <- exdqlmDiagnostics(fit, plot = FALSE, ref = ref_grid, kl_k = c(1, 3))
  diags_no_ref <- exdqlmDiagnostics(fit, plot = FALSE, kl_k = c(1, 3))
  expect_equal(diags_ref$kl.reference, "user_ref")
  expect_equal(diags_ref$m1.KL, diags_no_ref$m1.KL)

  expect_error(
    exdqlmDiagnostics(fit, plot = FALSE, ref = ref_grid[-1]),
    "ref should be"
  )
  expect_error(
    exdqlmDiagnostics(fit, plot = FALSE, kl_k = c(1, 1)),
    "duplicate"
  )
  expect_error(
    exdqlmDiagnostics(fit, plot = FALSE, kl_k = 1.5),
    "integer"
  )
  expect_error(
    exdqlmDiagnostics(fit, plot = FALSE, kl_k = TT),
    "no larger"
  )

  expect_error(
    exdqlmDiagnostics(fit, plot = FALSE, crps_probs = c(0.1, 1)),
    "strictly between"
  )

  old_scipen_opts <- options(scipen = 123L)
  on.exit(options(old_scipen_opts), add = TRUE)
  expected_scipen <- getOption("scipen")
  expect_output(print(diags), "KL \\(flipped\\)")
  expect_identical(getOption("scipen"), expected_scipen)

  expect_output(diag_summary <- summary(diags), "Diagnostic")
  expect_s3_class(diag_summary, "data.frame")
  expect_true(all(c("Diagnostic", "M1", "M2") %in% names(diag_summary)))
})

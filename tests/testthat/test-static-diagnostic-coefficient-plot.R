test_that("static diagnostic coefficient plot validates lightweight inputs", {
  diag_obj <- structure(
    list(
      p0 = 0.25,
      m1.beta.mean = c(0.1, 1.2, -0.3),
      m1.beta.lb = c(-0.1, 0.8, -0.7),
      m1.beta.ub = c(0.3, 1.6, 0.1),
      m2.beta.mean = c(0.0, 1.0, -0.2),
      m2.beta.lb = c(-0.2, 0.6, -0.5),
      m2.beta.ub = c(0.2, 1.4, 0.1),
      beta.names = c("(Intercept)", "x1", "x2"),
      cr.percent = 0.95
    ),
    class = "exalStaticDiagnostic"
  )

  tf <- tempfile(fileext = ".pdf")
  grDevices::pdf(tf)
  on.exit(grDevices::dev.off(), add = TRUE)

  expect_no_error(
    out <- plot(
      diag_obj,
      type = "coefficients",
      beta.ref = c(0, 1, 0),
      include.intercept = FALSE,
      legend.labels = c("LDVB 95% interval", "MCMC 95% interval"),
      beta.ref.label = "truth"
    )
  )
  expect_equal(out$type, "coefficients")
  expect_equal(out$coefficient, c("x1", "x2"))
  expect_equal(out$beta.ref, c(1, 0))
  expect_equal(out$m1.mean, c(1.2, -0.3))
  expect_equal(out$m2.mean, c(1.0, -0.2))

  expect_error(plot(diag_obj, type = "coefficients", beta.ref = 0), "beta.ref")
  expect_error(plot(diag_obj, type = "coefficients", ylim = c(1, -1)), "ylim")
  expect_error(
    plot(diag_obj, type = "coefficients", legend.labels = "LDVB"),
    "legend.labels"
  )
})

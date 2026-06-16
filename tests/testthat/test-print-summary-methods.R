test_that("model specification print and summary identify the object", {
  model <- as.exdqlm(list(m0 = 0, C0 = matrix(1), FF = 1, GG = 1))

  expect_output(print(model), "model specification \\(exdqlm\\)")
  expect_output(smry <- summary(model), "Component dimensions")
  expect_s3_class(smry, "data.frame")
  expect_equal(smry$Component, c("m0", "C0", "FF", "GG"))
})

test_that("dynamic fit print and summary expose the shared fit family", {
  set.seed(20260615)
  model <- as.exdqlm(list(m0 = 0, C0 = matrix(1, 1, 1), FF = 1, GG = 1))
  y <- c(0.1, -0.2, 0.05, 0.15)

  old_opts <- options(
    exdqlm.use_cpp_kf = FALSE,
    exdqlm.compute_elbo = TRUE,
    exdqlm.use_cpp_samplers = FALSE,
    exdqlm.use_cpp_postpred = FALSE
  )
  on.exit(options(old_opts), add = TRUE)

  fit <- exdqlmLDVB(
    y = y, p0 = 0.5, model = model, df = 1, dim.df = 1,
    dqlm.ind = TRUE,
    fix.sigma = FALSE,
    n.samp = 8,
    tol = 1e-3,
    verbose = FALSE
  )

  expect_output(print(fit), "Dynamic quantile state-space fit")
  expect_output(print(fit), "Class: exdqlmLDVB, exdqlmFit")
  expect_output(print(fit), "Inference engine: LDVB")
  expect_output(print(fit), "exdqlmDiagnostics\\(\\)")
  expect_output(print(fit), "predict\\(\\)")

  expect_output(smry <- summary(fit), "Stored draws")
  expect_type(smry, "list")
  expect_s3_class(smry$draws, "data.frame")
  expect_s3_class(smry$scalar, "data.frame")
  expect_s3_class(smry$convergence, "data.frame")

  q_method <- plot(fit, plot = FALSE)
  q_helper <- exdqlmPlot(fit, plot = FALSE)
  expect_equal(q_method, q_helper)
  comp_method <- plot(fit, type = "component", index = 1, plot = FALSE)
  comp_helper <- compPlot(fit, index = 1, plot = FALSE)
  expect_equal(comp_method, comp_helper)
  state_method <- plot(fit, type = "state", index = 1, plot = FALSE)
  state_helper <- compPlot(fit, index = 1, just.theta = TRUE, plot = FALSE)
  expect_equal(state_method, state_helper)
  expect_error(plot(fit, type = "component", plot = FALSE), "index is required")
  expect_error(
    plot(fit, type = "component", index = 1, just.theta = TRUE, plot = FALSE),
    "use type = 'state'"
  )
  expect_error(plot(fit, type = "bad", plot = FALSE), "'arg' should be one of")

  visible_diags <- withVisible(exdqlmDiagnostics(fit))
  expect_true(visible_diags$visible)
  diags <- visible_diags$value
  expect_equal(diags$p0, 0.5)
  expect_equal(diags$n, length(y))
  expect_equal(diags$m1.class, "exdqlmLDVB")
  expect_output(print(diags), "Dynamic quantile model diagnostics")
  expect_output(print(diags), "Models: exdqlmLDVB")
  expect_output(diag_table <- summary(diags), "Observations")
  expect_s3_class(diag_table, "data.frame")
  expect_error(exdqlmDiagnostics(fit, plot = NA), "plot must be")

  tf <- tempfile(fileext = ".pdf")
  grDevices::pdf(tf)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_no_error(diag_plot_visible <- withVisible(plot(diags)))
  expect_false(diag_plot_visible$visible)
  expect_identical(diag_plot_visible$value, diags)
  expect_no_error(diags_plot <- exdqlmDiagnostics(fit, plot = TRUE))
  expect_s3_class(diags_plot, "exdqlmDiagnostic")

  visible_fc <- withVisible(exdqlmForecast(
    start.t = 3, k = 1, m1 = fit
  ))
  expect_true(visible_fc$visible)
  expect_s3_class(visible_fc$value, "exdqlmForecast")
  expect_error(exdqlmForecast(start.t = 3, k = 1, m1 = fit, plot = NA), "plot must be")
  expect_no_error(exdqlmForecast(start.t = 3, k = 1, m1 = fit, plot = TRUE))

  fc <- predict(
    fit,
    start.t = 3, k = 1,
    return.draws = TRUE,
    n.samp = 5,
    seed = 1
  )
  expect_output(print(fc), "Dynamic quantile forecast")
  expect_output(print(fc), "Fitted model class: exdqlmLDVB")
  expect_output(fc_table <- summary(fc), "Forecast summary")
  expect_s3_class(fc_table, "data.frame")
  expect_true(all(c("step", "forecast_quantile", "forecast_variance", "lower", "upper") %in% names(fc_table)))
  expect_equal(dim(fc$samp.fore), c(1L, 5L))
  expect_no_error(fc_plot_visible <- withVisible(plot(fc)))
  expect_false(fc_plot_visible$visible)
  expect_identical(fc_plot_visible$value, fc)
})

test_that("static fit and diagnostic methods expose the shared fit family", {
  set.seed(20260615)
  n <- 12
  X <- cbind(1, seq(-1, 1, length.out = n))
  y <- as.numeric(X %*% c(0.2, -0.1) + stats::rnorm(n, sd = 0.1))

  fit <- exalStaticLDVB(
    y = y, X = X, p0 = 0.5,
    dqlm.ind = TRUE,
    max_iter = 80,
    tol = 1e-3,
    verbose = FALSE
  )

  expect_output(print(fit), "Static Bayesian quantile regression fit")
  expect_output(print(fit), "Class: exalStaticLDVB, exalStaticFit")
  expect_output(print(fit), "exalStaticDiagnostics\\(\\)")

  expect_output(smry <- summary(fit), "Coefficient summaries")
  expect_type(smry, "list")
  expect_s3_class(smry$draws, "data.frame")
  expect_s3_class(smry$scalar, "data.frame")
  expect_s3_class(smry$coefficients, "data.frame")

  visible_diags <- withVisible(exalStaticDiagnostics(fit, X = X, y = y))
  expect_true(visible_diags$visible)
  diags <- visible_diags$value
  expect_equal(diags$p0, 0.5)
  expect_equal(diags$n, n)
  expect_equal(diags$m1.class, "exalStaticLDVB")
  expect_output(print(diags), "Plot types: quantile, coefficients")
  expect_output(diag_table <- summary(diags), "Evaluation rows")
  expect_s3_class(diag_table, "data.frame")
  expect_error(exalStaticDiagnostics(fit, X = X, y = y, plot = c(TRUE, FALSE)), "plot must be")

  tf <- tempfile(fileext = ".pdf")
  grDevices::pdf(tf)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_no_error(plot(diags))
  expect_no_error(diags_plot <- exalStaticDiagnostics(fit, X = X, y = y, plot = TRUE))
  expect_s3_class(diags_plot, "exalStaticDiagnostic")
})

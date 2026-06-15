test_that("JSS-facing S3 methods are registered", {
  expected_plot <- c(
    "exalStaticDiagnostic",
    "exalStaticLDVB",
    "exalStaticMCMC",
    "exdqlmDiagnostic",
    "exdqlmFit",
    "exdqlmForecast",
    "exdqlmISVB",
    "exdqlmLDVB",
    "exdqlmMCMC",
    "exdqlmSynthesis"
  )
  expected_print <- c(
    "exalStaticDiagnostic",
    "exalStaticFit",
    "exalStaticLDVB",
    "exalStaticMCMC",
    "exdqlm",
    "exdqlmDiagnostic",
    "exdqlmFit",
    "exdqlmForecast",
    "exdqlmForecastDiagnostic",
    "exdqlmISVB",
    "exdqlmLDVB",
    "exdqlmMCMC",
    "exdqlmSynthesis"
  )
  expected_summary <- c(
    "exalStaticDiagnostic",
    "exalStaticFit",
    "exalStaticLDVB",
    "exalStaticMCMC",
    "exdqlm",
    "exdqlmDiagnostic",
    "exdqlmFit",
    "exdqlmForecast",
    "exdqlmForecastDiagnostic",
    "exdqlmISVB",
    "exdqlmLDVB",
    "exdqlmMCMC",
    "exdqlmSynthesis"
  )

  for (class_name in expected_plot) {
    expect_type(getS3method("plot", class_name), "closure")
  }
  for (class_name in expected_print) {
    expect_type(getS3method("print", class_name), "closure")
  }
  for (class_name in expected_summary) {
    expect_type(getS3method("summary", class_name), "closure")
  }
  expect_type(getS3method("predict", "exdqlmFit"), "closure")
})

test_that("shared fit predicates remain specific to fitted model families", {
  expect_true(is.exdqlmFit(structure(list(), class = c("exdqlmLDVB", "exdqlmFit"))))
  expect_false(is.exdqlmFit(structure(list(), class = "exalStaticFit")))
  expect_false(is.exdqlmFit(structure(list(), class = "exdqlmDiagnostic")))

  expect_true(is.exalStaticFit(structure(list(), class = c("exalStaticLDVB", "exalStaticFit"))))
  expect_false(is.exalStaticFit(structure(list(), class = "exdqlmFit")))
  expect_false(is.exalStaticFit(structure(list(), class = "exalStaticDiagnostic")))
})

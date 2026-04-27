test_that("BTflow is the observed monthly USGS streamflow series", {
  data("BTflow", package = "exdqlm", envir = environment())

  expect_s3_class(BTflow, "ts")
  expect_equal(stats::frequency(BTflow), 12)
  expect_equal(as.integer(stats::start(BTflow)), c(1987L, 1L))
  expect_equal(as.integer(stats::end(BTflow)), c(2026L, 3L))
  expect_equal(length(BTflow), 471)
  expect_true(all(is.finite(as.numeric(BTflow))))
  expect_gt(min(as.numeric(BTflow)), 0)
})

test_that("climateIndices exposes a complete monthly climate-index panel", {
  data("climateIndices", package = "exdqlm", envir = environment())

  expected_names <- c(
    "date", "nino3", "nao", "nino12", "whwp", "gmt", "oni", "pna",
    "noi", "wp", "nino34", "solar_flux", "amo", "espi", "tsa",
    "nino4", "tna", "soi"
  )

  expect_s3_class(climateIndices, "data.frame")
  expect_named(climateIndices, expected_names)
  expect_s3_class(climateIndices$date, "Date")
  expect_equal(nrow(climateIndices), 516)
  expect_equal(min(climateIndices$date), as.Date("1980-01-01"))
  expect_equal(max(climateIndices$date), as.Date("2022-12-01"))
  expect_identical(climateIndices$date, seq(min(climateIndices$date), max(climateIndices$date), by = "month"))
  expect_true(all(stats::complete.cases(climateIndices)))
  expect_true(all(vapply(climateIndices[-1], is.numeric, logical(1))))
  expect_true(all(c("noi", "soi", "espi", "pna", "whwp", "amo") %in% names(climateIndices)))
})

test_that("BTprec is not shipped in the cleaned package data API", {
  available <- utils::data(package = "exdqlm")$results[, "Item"]
  expect_false("BTprec" %in% available)
})

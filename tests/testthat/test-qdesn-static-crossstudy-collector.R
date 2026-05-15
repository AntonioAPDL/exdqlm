test_that("crossstudy collector skips placeholder and zero-byte root tables", {
  root_base <- tempfile("collector_roots_")
  dir.create(root_base, recursive = TRUE, showWarnings = FALSE)
  root_good <- file.path(root_base, "root_good")
  root_placeholder <- file.path(root_base, "root_placeholder")
  root_zero <- file.path(root_base, "root_zero")
  dir.create(file.path(root_good, "tables"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(root_placeholder, "tables"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(root_zero, "tables"), recursive = TRUE, showWarnings = FALSE)

  utils::write.csv(
    data.frame(root_id = "root_good", signoff_grade = "FAIL", stringsAsFactors = FALSE),
    file.path(root_good, "tables", "fit_summary.csv"),
    row.names = FALSE
  )
  writeLines("\"\"", file.path(root_placeholder, "tables", "fit_summary.csv"))
  invisible(file.create(file.path(root_zero, "tables", "fit_summary.csv")))

  out <- exdqlm:::.qdesn_static_crossstudy_collect_root_tables(
    c(root_good, root_placeholder, root_zero),
    "fit_summary.csv"
  )

  expect_identical(nrow(out), 1L)
  expect_identical(as.character(out$root_id[[1L]]), "root_good")
  expect_identical(as.character(out$signoff_grade[[1L]]), "FAIL")
})

test_that("crossstudy collector returns empty data frame for placeholder-only tables", {
  root_base <- tempfile("collector_empty_")
  dir.create(root_base, recursive = TRUE, showWarnings = FALSE)
  root_placeholder <- file.path(root_base, "root_placeholder")
  dir.create(file.path(root_placeholder, "tables"), recursive = TRUE, showWarnings = FALSE)
  writeLines("\"\"", file.path(root_placeholder, "tables", "model_pair_signoff.csv"))

  out <- exdqlm:::.qdesn_static_crossstudy_collect_root_tables(
    root_placeholder,
    "model_pair_signoff.csv"
  )

  expect_s3_class(out, "data.frame")
  expect_identical(nrow(out), 0L)
  expect_identical(ncol(out), 0L)
})

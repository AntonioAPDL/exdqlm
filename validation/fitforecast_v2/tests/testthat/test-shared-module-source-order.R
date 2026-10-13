testthat::test_that("shared loader orders dependencies without resetting captured hooks", {
  repo <- normalizePath(system2("git", c("rev-parse", "--show-toplevel"),
                               stdout = TRUE)[[1L]], mustWork = TRUE)
  harness <- file.path(repo, "validation", "fitforecast_v2")
  script <- tempfile(fileext = ".R")
  on.exit(unlink(script), add = TRUE)
  writeLines(c(
    "args <- commandArgs(trailingOnly=TRUE)",
    "harness <- normalizePath(args[1L], mustWork=TRUE)",
    "runtime <- file.path(harness, 'R/independent_qdesn_training1000_runtime_v1.R')",
    "original <- new.env(parent=.GlobalEnv)",
    "sys.source(runtime, envir=original)",
    "source(file.path(harness, 'R/utils.R'))",
    "for (attempt in 1:2) {",
    "  ffv2_source_all(harness)",
    "  stopifnot(identical(igc7_cell, ifu8_cell), identical(ifu8_cell, ifu9_cell), identical(ifu9_cell, ilr10_cell))",
    "  stopifnot(identical(body(ism1_base_runtime), body(original$iqt12_runtime)))",
    "  stopifnot(identical(body(ism1_base_design), body(original$iqt12_design)))",
    "  stopifnot(identical(body(ism1_base_prior), body(original$iqt12_prior)))",
    "  stopifnot(identical(iqt12_prior, ism1_prior), identical(iqt12_runtime_hook, ism1_runtime), identical(iqt12_design_hook, ism1_design))",
    "  stopifnot(is.function(ffv2_rolling_grid), is.function(irm13_closeout_verify))",
    "}",
    "cat('SHARED_MODULE_SOURCE_ORDER=PASS attempts=2 frozen_modules_unchanged=TRUE\\n')"
  ), script)
  output <- system2(file.path(R.home("bin"), "Rscript"),
                   c(shQuote(script), shQuote(harness)), stdout = TRUE, stderr = TRUE)
  testthat::expect_null(attr(output, "status"), info = paste(output, collapse = "\n"))
  testthat::expect_true(any(grepl("SHARED_MODULE_SOURCE_ORDER=PASS", output, fixed = TRUE)),
                        info = paste(output, collapse = "\n"))
})

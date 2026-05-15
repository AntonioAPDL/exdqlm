test_that("Q-DESN shared interface exporter writes the common schema header without completed rows", {
  tmp <- tempfile("qdesn-interface-")
  out <- file.path(tmp, "interfaces", "qdesn_interface.csv")
  repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  status <- system2(
    Sys.which("Rscript"),
    c(
      file.path(repo_root, "scripts", "export_qdesn_dynamic_fitforecast_v2_shared_interface.R"),
      "--out", out
    ),
    stdout = TRUE,
    stderr = TRUE
  )
  expect_true(file.exists(out), info = paste(status, collapse = "\n"))
  exported <- utils::read.csv(out, stringsAsFactors = FALSE, check.names = FALSE)
  schema <- utils::read.csv(
    file.path(repo_root, "validation", "fitforecast_v2", "schema", "shared_fitforecast_interface_schema.csv"),
    stringsAsFactors = FALSE
  )
  expect_equal(nrow(exported), 0L)
  expect_setequal(names(exported), schema$column)
})

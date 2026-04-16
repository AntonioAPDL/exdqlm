test_that("debug dump helpers write payloads when enabled", {
  old_dir <- Sys.getenv("EXDQLM_DEBUG_DIR", unset = NA_character_)
  old_case <- Sys.getenv("EXDQLM_DEBUG_CASE", unset = NA_character_)
  old_label <- Sys.getenv("EXDQLM_DEBUG_LABEL", unset = NA_character_)
  on.exit({
    if (is.na(old_dir)) Sys.unsetenv("EXDQLM_DEBUG_DIR") else Sys.setenv(EXDQLM_DEBUG_DIR = old_dir)
    if (is.na(old_case)) Sys.unsetenv("EXDQLM_DEBUG_CASE") else Sys.setenv(EXDQLM_DEBUG_CASE = old_case)
    if (is.na(old_label)) Sys.unsetenv("EXDQLM_DEBUG_LABEL") else Sys.setenv(EXDQLM_DEBUG_LABEL = old_label)
  }, add = TRUE)

  dbg_dir <- file.path(tempdir(), "exdqlm_debug_helper_test")
  unlink(dbg_dir, recursive = TRUE, force = TRUE)
  Sys.setenv(
    EXDQLM_DEBUG_DIR = dbg_dir,
    EXDQLM_DEBUG_CASE = "caseA",
    EXDQLM_DEBUG_LABEL = "labelA"
  )

  expect_true(.exdqlm_debug_enabled())
  path <- .exdqlm_debug_dump(
    "sample_tag",
    .exdqlm_debug_payload(value = 123, stats = .exdqlm_debug_compact_numeric(c(1, 2, NA, Inf)))
  )

  expect_true(file.exists(path))
  payload <- readRDS(path)
  expect_equal(payload$value, 123)
  expect_equal(payload$debug_meta$case, "caseA")
  expect_equal(payload$debug_meta$label, "labelA")
  expect_equal(payload$stats$length, 4)
  expect_equal(payload$stats$finite, 2)
  expect_equal(payload$stats$nonfinite, 2)
})

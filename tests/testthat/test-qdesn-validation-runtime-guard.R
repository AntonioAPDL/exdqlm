test_that("runtime guard records R 4.6 launch metadata", {
  snap <- exdqlm:::qdesn_validation_assert_runtime()

  expect_true(isTRUE(snap$version_ok))
  expect_match(snap$r_version, "^R version")
  expect_true(nzchar(snap$rscript))
  expect_true(nzchar(snap$r_home))
  expect_false(isTRUE(snap$forbidden_rscript))
  expect_true(length(snap$lib_paths) >= 1L)
})

test_that("runtime guard fails fast for impossible minimum version", {
  expect_error(
    exdqlm:::qdesn_validation_assert_runtime(min_version = "999.0.0"),
    "runtime guard failed"
  )
})

test_that("file manifest records hashes for existing files", {
  tmp <- tempfile("qdesn-manifest-")
  writeLines("abc", tmp)
  manifest <- exdqlm:::qdesn_validation_file_manifest(tmp)

  expect_equal(nrow(manifest), 1L)
  expect_true(isTRUE(manifest$exists[[1L]]))
  expect_true(is.finite(manifest$bytes[[1L]]))
  expect_true(nzchar(manifest$md5[[1L]]))
  expect_match(manifest$sha256[[1L]], "^[[:xdigit:]]{64}$")
})

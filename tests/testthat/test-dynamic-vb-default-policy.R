test_that("dynamic exdqlm VB entry points default to free sigma", {
  expect_identical(formals(exdqlmISVB)$fix.sigma, FALSE)
  expect_identical(formals(exdqlmLDVB)$fix.sigma, FALSE)
  expect_identical(formals(exdqlmTransferISVB)$fix.sigma, FALSE)
  expect_identical(formals(exdqlmTransferLDVB)$fix.sigma, FALSE)
})

test_that("dynamic exdqlm MCMC entry points keep free sigma defaults", {
  expect_identical(formals(exdqlmMCMC)$fix.sigma, FALSE)
  expect_identical(formals(exdqlmTransferMCMC)$fix.sigma, FALSE)
})

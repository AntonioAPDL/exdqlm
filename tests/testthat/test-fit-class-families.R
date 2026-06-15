test_that("shared fit class predicates recognize dynamic and static families", {
  expect_true(is.exdqlmFit(structure(list(), class = c("exdqlmMCMC", "exdqlmFit"))))
  expect_true(is.exdqlmFit(structure(list(), class = c("exdqlmLDVB", "exdqlmFit"))))
  expect_true(is.exdqlmFit(structure(list(), class = c("exdqlmISVB", "exdqlmFit"))))
  expect_false(is.exdqlmFit(as.exdqlm(list(m0 = 0, C0 = matrix(1), FF = 1, GG = 1))))

  expect_true(is.exalStaticFit(structure(list(), class = c("exalStaticMCMC", "exalStaticFit"))))
  expect_true(is.exalStaticFit(structure(list(), class = c("exalStaticLDVB", "exalStaticFit"))))
  expect_false(is.exalStaticFit(structure(list(), class = "exdqlmFit")))
})

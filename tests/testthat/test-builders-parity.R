# Backend parity tests for R and C++ matrix builders.

test_that("polytrend builder parity (R vs C++)", {
  model_r <- polytrendMod(order = 2, backend = "R")
  model_cpp <- polytrendMod(order = 2, backend = "cpp")

  expect_equal(dim(model_r$FF), c(2L, 1L))
  expect_equal(dim(model_r$GG), c(2L, 2L))

  expect_true(isTRUE(all.equal(model_r$FF, model_cpp$FF, tolerance = 0)))
  expect_true(isTRUE(all.equal(model_r$GG, model_cpp$GG, tolerance = 0)))
  expect_true(isTRUE(all.equal(model_r$m0, model_cpp$m0, tolerance = 0)))
  expect_true(isTRUE(all.equal(model_r$C0, model_cpp$C0, tolerance = 0)))
})

test_that("seasonal builder parity (R vs C++)", {
  model_r <- seasMod(p = 12, h = 1, backend = "R")
  model_cpp <- seasMod(p = 12, h = 1, backend = "cpp")

  expect_equal(dim(model_r$FF), dim(model_cpp$FF))
  expect_equal(dim(model_r$GG), dim(model_cpp$GG))

  expect_true(isTRUE(all.equal(model_r$FF, model_cpp$FF, tolerance = 1e-12)))
  expect_true(isTRUE(all.equal(model_r$GG, model_cpp$GG, tolerance = 1e-12)))
  expect_true(isTRUE(all.equal(model_r$m0, model_cpp$m0, tolerance = 0)))
  expect_true(isTRUE(all.equal(model_r$C0, model_cpp$C0, tolerance = 0)))
})

test_that("composed builder parity (R vs C++)", {
  model_r <- polytrendMod(order = 2, backend = "R") + seasMod(p = 12, h = 1, backend = "R")
  model_cpp <- polytrendMod(order = 2, backend = "cpp") + seasMod(p = 12, h = 1, backend = "cpp")

  expect_equal(dim(model_r$FF), dim(model_cpp$FF))
  expect_equal(dim(model_r$GG), dim(model_cpp$GG))
  expect_equal(dim(model_r$C0), dim(model_cpp$C0))
  expect_equal(dim(model_r$m0), dim(model_cpp$m0))

  expect_true(isTRUE(all.equal(model_r$FF, model_cpp$FF, tolerance = 1e-12)))
  expect_true(isTRUE(all.equal(model_r$GG, model_cpp$GG, tolerance = 1e-12)))
  expect_true(isTRUE(all.equal(model_r$m0, model_cpp$m0, tolerance = 0)))
  expect_true(isTRUE(all.equal(model_r$C0, model_cpp$C0, tolerance = 0)))
})

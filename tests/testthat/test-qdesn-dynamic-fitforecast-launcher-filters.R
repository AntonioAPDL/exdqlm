test_that("fit+forecast phase plan separates MCMC TT500 and TT5000", {
  tt500 <- exdqlm:::qdesn_dynamic_fitforecast_phase_plan("mcmc_tt500")
  tt5000 <- exdqlm:::qdesn_dynamic_fitforecast_phase_plan("mcmc_tt5000")
  vb <- exdqlm:::qdesn_dynamic_fitforecast_phase_plan("vb_full")

  expect_identical(tt500$methods, "mcmc")
  expect_identical(tt500$fit_sizes, 500L)
  expect_identical(tt500$batch, "full")
  expect_true(isTRUE(tt500$allow_grid_subset_default))

  expect_identical(tt5000$methods, "mcmc")
  expect_identical(tt5000$fit_sizes, 5000L)
  expect_identical(tt5000$batch, "full")

  expect_identical(vb$methods, "vb")
  expect_length(vb$fit_sizes, 0L)
})

test_that("dynamic grid filters are generic and composable", {
  grid <- data.frame(
    root_id = paste0("r", 1:6),
    source_family = c("normal", "normal", "laplace", "laplace", "gausmix", "gausmix"),
    tau = c(0.25, 0.5, 0.25, 0.5, 0.25, 0.5),
    fit_size = c(500, 5000, 500, 5000, 500, 5000),
    beta_prior_type = c("ridge", "ridge", "rhs_ns", "rhs_ns", "ridge", "rhs_ns"),
    stringsAsFactors = FALSE
  )

  out <- exdqlm:::qdesn_validation_filter_dynamic_grid(
    grid,
    fit_sizes = 5000L,
    families = "laplace",
    taus = 0.5,
    priors = "rhs_ns"
  )

  expect_equal(nrow(out), 1L)
  expect_identical(out$root_id, "r4")
  expect_true(all(out$fit_size == 5000L))
  expect_true(all(out$source_family == "laplace"))
  expect_true(all(out$beta_prior_type == "rhs_ns"))
})

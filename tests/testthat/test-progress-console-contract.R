extract_progress_lines <- function(output) {
  grep("^(MCMC|LDVB) (start|progress|done) \\|", output, value = TRUE)
}

test_that("dynamic MCMC console progress is compact and omits sigma/gamma fields", {
  set.seed(123)
  y <- ts(rnorm(24))
  model <- polytrendMod(order = 1, m0 = mean(y), C0 = matrix(10, 1, 1))

  out <- capture.output(
    exdqlmMCMC(
      y = y,
      p0 = 0.50,
      model = model,
      df = 1,
      dim.df = 1,
      dqlm.ind = TRUE,
      n.burn = 3,
      n.mcmc = 4,
      init.from.vb = FALSE,
      verbose = TRUE,
      verbose.every = 1
    )
  )

  progress <- extract_progress_lines(out)
  expect_true(any(grepl("^MCMC progress \\|", progress)))
  expect_false(any(grepl("^MCMC progress \\|.*sigma=", progress)))
  expect_false(any(grepl("^MCMC progress \\|.*gamma=", progress)))
  expect_false(any(grepl("^MCMC done \\|.*sigma=", progress)))
  expect_false(any(grepl("^MCMC done \\|.*gamma=", progress)))
})

test_that("dynamic LDVB console progress is compact and omits sigma/gamma fields", {
  set.seed(124)
  y <- ts(rnorm(24))
  model <- polytrendMod(order = 1, m0 = mean(y), C0 = matrix(10, 1, 1))
  old <- options(exdqlm.max_iter = 8)
  on.exit(options(old), add = TRUE)

  out <- capture.output(
    exdqlmLDVB(
      y = y,
      p0 = 0.50,
      model = model,
      df = 1,
      dim.df = 1,
      dqlm.ind = TRUE,
      sig.init = 1,
      tol = 0.50,
      n.samp = 30,
      verbose = TRUE
    )
  )

  progress <- extract_progress_lines(out)
  expect_true(any(grepl("^LDVB progress \\|", progress)))
  expect_false(any(grepl("^LDVB progress \\|.*sigma=", progress)))
  expect_false(any(grepl("^LDVB progress \\|.*gamma=", progress)))
  expect_false(any(grepl("^LDVB done \\|.*sigma=", progress)))
  expect_false(any(grepl("^LDVB done \\|.*gamma=", progress)))
})

test_that("static MCMC console progress is compact and omits sigma/gamma fields", {
  set.seed(125)
  n <- 30
  x <- rnorm(n)
  X <- cbind(1, x)
  y <- 0.4 + 0.9 * x + rnorm(n, sd = 0.3)

  out <- capture.output(
    exalStaticMCMC(
      y = y,
      X = X,
      p0 = 0.50,
      dqlm.ind = FALSE,
      n.burn = 3,
      n.mcmc = 4,
      thin = 1,
      init.from.vb = FALSE,
      verbose = TRUE
    )
  )

  progress <- extract_progress_lines(out)
  expect_true(any(grepl("^MCMC progress \\|", progress)))
  expect_false(any(grepl("^MCMC progress \\|.*sigma=", progress)))
  expect_false(any(grepl("^MCMC progress \\|.*gamma=", progress)))
  expect_false(any(grepl("^MCMC done \\|.*sigma=", progress)))
  expect_false(any(grepl("^MCMC done \\|.*gamma=", progress)))
})

test_that("static LDVB console progress is compact and omits sigma/gamma fields", {
  set.seed(126)
  n <- 30
  x <- rnorm(n)
  X <- cbind(1, x)
  y <- 0.4 + 0.9 * x + rnorm(n, sd = 0.3)

  out <- capture.output(
    exalStaticLDVB(
      y = y,
      X = X,
      p0 = 0.50,
      dqlm.ind = TRUE,
      max_iter = 30,
      n.samp = 30,
      tol = 1e-12,
      verbose = TRUE
    )
  )

  progress <- extract_progress_lines(out)
  expect_true(any(grepl("^LDVB progress \\|", progress)))
  expect_false(any(grepl("^LDVB progress \\|.*sigma=", progress)))
  expect_false(any(grepl("^LDVB progress \\|.*gamma=", progress)))
  expect_false(any(grepl("^LDVB done \\|.*sigma=", progress)))
  expect_false(any(grepl("^LDVB done \\|.*gamma=", progress)))
})

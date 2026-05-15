test_that("exdqlmForecast accepts future evolution arrays with horizon depth", {
  p <- 2L
  TT <- 500L
  k <- 1000L
  fake_fit <- list(
    y = rep(0, TT),
    p0 = 0.5,
    dqlm.ind = TRUE,
    df = 1,
    dim.df = p,
    model = list(
      FF = matrix(1, p, TT),
      GG = array(diag(p), c(p, p, TT))
    ),
    theta.out = list(
      fm = matrix(0, p, TT),
      fC = array(diag(p), c(p, p, TT))
    ),
    samp.sigma = rep(1, 4),
    samp.gamma = rep(0, 4)
  )
  class(fake_fit) <- "exdqlmLDVB"

  future_FF <- matrix(1, p, k)
  future_GG <- array(diag(p), c(p, p, k))

  fc <- exdqlmForecast(
    start.t = TT,
    k = k,
    m1 = fake_fit,
    fFF = future_FF,
    fGG = future_GG,
    plot = FALSE
  )

  expect_s3_class(fc, "exdqlmForecast")
  expect_equal(fc$k, k)
  expect_equal(length(fc$ff), k)
  expect_equal(length(fc$fQ), k)
  expect_equal(dim(fc$fa), c(p, k))
  expect_equal(dim(fc$fR), c(p, p, k))
})

test_that("exdqlmForecast validates future evolution horizon depth", {
  p <- 2L
  TT <- 10L
  k <- 5L
  fake_fit <- list(
    y = rep(0, TT),
    p0 = 0.5,
    dqlm.ind = TRUE,
    df = 1,
    dim.df = p,
    model = list(
      FF = matrix(1, p, TT),
      GG = array(diag(p), c(p, p, TT))
    ),
    theta.out = list(
      fm = matrix(0, p, TT),
      fC = array(diag(p), c(p, p, TT))
    ),
    samp.sigma = rep(1, 4),
    samp.gamma = rep(0, 4)
  )
  class(fake_fit) <- "exdqlmLDVB"

  expect_error(
    exdqlmForecast(
      start.t = TT,
      k = k,
      m1 = fake_fit,
      fFF = matrix(1, p, k),
      fGG = array(diag(p), c(p, p, k - 1L)),
      plot = FALSE
    ),
    "depth k"
  )

  fc <- exdqlmForecast(
    start.t = TT,
    k = k,
    m1 = fake_fit,
    fFF = matrix(1, p, 1L),
    fGG = diag(p),
    plot = FALSE
  )
  expect_equal(length(fc$ff), k)
  expect_equal(dim(fc$fR), c(p, p, k))
})

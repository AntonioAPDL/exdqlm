test_that("RQR pseudo residual equals root residual product", {
  set.seed(7101)
  y <- rnorm(25)
  eta1 <- rnorm(25)
  eta2 <- rnorm(25)

  prod_res <- exdqlm::rqr_residual_product(y, eta1, eta2)
  pseudo_res <- exdqlm::rqr_pseudo_residual(y, eta1, eta2)

  expect_equal(pseudo_res, prod_res, tolerance = 1e-12)
  expect_equal(
    exdqlm::rqr_check_loss(prod_res, 0.8),
    prod_res * (0.8 - as.numeric(prod_res < 0)),
    tolerance = 1e-12
  )
})

test_that("RQR endpoints are invariant to root label swapping", {
  set.seed(7102)
  eta1 <- rnorm(30)
  eta2 <- rnorm(30)

  a <- exdqlm::rqr_order_endpoints(eta1, eta2)
  b <- exdqlm::rqr_order_endpoints(eta2, eta1)

  expect_equal(a$lower, b$lower)
  expect_equal(a$upper, b$upper)
  expect_true(all(a$lower <= a$upper))
  expect_equal(a$width, a$upper - a$lower)
})

test_that("RQR GIG parameters match direct conditional log-kernel ratios", {
  e <- c(-1.2, -0.3, 0.4, 1.1)
  alpha <- 0.82
  omega <- 1.7
  gp <- exdqlm::rqr_gig_params(e, coverage_level = alpha, learning_rate = omega)
  cc <- exdqlm::rqr_constants(alpha, omega)

  expect_equal(gp$p, 0.5)
  expect_equal(gp$a, 1 / (2 * cc$sigma * alpha * (1 - alpha)), tolerance = 1e-12)
  expect_equal(gp$b, alpha * (1 - alpha) * e^2 / (2 * cc$sigma), tolerance = 1e-12)

  x1 <- 0.7
  x2 <- 1.4
  j <- 3L
  direct_ratio <- (gp$p - 1) * (log(x1) - log(x2)) -
    0.5 * (gp$a * (x1 - x2) + gp$b[j] * (1 / x1 - 1 / x2))

  kernel <- function(x) {
    (gp$p - 1) * log(x) - 0.5 * (gp$a * x + gp$b[j] / x)
  }
  expect_equal(kernel(x1) - kernel(x2), direct_ratio, tolerance = 1e-12)
})

test_that("RQR conditional root design identity is exact", {
  set.seed(7103)
  n <- 18
  X <- cbind(1, rnorm(n), rnorm(n))
  y <- rnorm(n)
  beta1 <- c(0.2, -0.1, 0.3)
  beta2 <- c(-0.4, 0.5, 0.1)

  eta2 <- drop(X %*% beta2)
  A1 <- X * as.numeric(y - eta2)
  z1_without_v <- y^2 - y * eta2
  lhs <- z1_without_v - drop(A1 %*% beta1)
  rhs <- exdqlm::rqr_residual_product(y, drop(X %*% beta1), eta2)

  expect_equal(lhs, rhs, tolerance = 1e-12)
})

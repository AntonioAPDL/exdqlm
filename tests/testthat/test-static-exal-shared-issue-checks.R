test_that("exAL coefficient map reduces to AL at gamma = 0", {
  taus <- c(0.05, 0.50, 0.95)
  for (tau in taus) {
    expect_equal(exdqlm:::p.fn(tau, 0), tau, tolerance = 1e-10)
    expect_equal(exdqlm:::A.fn(tau, 0), (1 - 2 * tau) / (tau * (1 - tau)), tolerance = 1e-10)
    expect_equal(exdqlm:::B.fn(tau, 0), 2 / (tau * (1 - tau)), tolerance = 1e-10)
    expect_equal(exdqlm:::C.fn(tau, 0) * abs(0), 0, tolerance = 1e-12)
  }
})

test_that("implemented exAL family is quantile-fixed at p0", {
  taus <- c(0.05, 0.50, 0.95)
  mus <- c(-2, 0.5, 3)
  sigmas <- c(0.5, 1.5)

  for (tau in taus) {
    bounds <- exdqlm:::.gamma_bounds(tau)
    L <- as.numeric(bounds[[1]])
    U <- as.numeric(bounds[[2]])
    gammas <- c(0, 0.1 * U, 0.2 * U, 0.1 * L, 0.2 * L)
    gammas <- gammas[gammas > L & gammas < U]

    for (gamma in gammas) {
      for (mu in mus) {
        for (sigma in sigmas) {
          q_tau <- suppressWarnings(qexal(tau, p0 = tau, mu = mu, sigma = sigma, gamma = gamma))
          p_mu <- suppressWarnings(pexal(mu, p0 = tau, mu = mu, sigma = sigma, gamma = gamma))
          expect_equal(q_tau, mu, tolerance = 1e-8)
          expect_equal(p_mu, tau, tolerance = 1e-8)
        }
      }
    }
  }
})

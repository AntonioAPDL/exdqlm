test_that("ISVB R fallback matches C++ KF on time-varying GG", {
  if (!exists("update_theta_bridge", mode = "function")) {
    skip("C++ KF bridge not available in this build")
  }

  TT <- 10L
  GG <- array(0, dim = c(2L, 2L, TT))
  for (t in seq_len(TT)) {
    GG[, , t] <- matrix(
      c(1.00, 0.12 + 0.02 * t,
        -0.04 + 0.01 * t, 0.88),
      nrow = 2L, byrow = TRUE
    )
  }

  FF <- rbind(rep(1, TT), rep(0.25, TT))
  model <- as.exdqlm(list(m0 = c(0, 0), C0 = diag(2), FF = FF, GG = GG))
  y <- as.numeric(0.3 * sin(seq_len(TT) / 2) + seq_len(TT) / 20)

  run_isvb <- function(use_cpp) {
    old_opts <- options(
      exdqlm.use_cpp_kf = use_cpp,
      exdqlm.compute_elbo = FALSE,
      exdqlm.use_cpp_samplers = FALSE,
      exdqlm.use_cpp_postpred = FALSE
    )
    on.exit(options(old_opts), add = TRUE)

    set.seed(20260209)
    exdqlmISVB(
      y = y, p0 = 0.5, model = model, df = 0.98, dim.df = 2,
      fix.gamma = TRUE, gam.init = 0.15,
      fix.sigma = TRUE, sig.init = 1.0,
      tol = 1e6, n.IS = 2, n.samp = 2, verbose = FALSE
    )
  }

  fit_r <- run_isvb(FALSE)
  fit_cpp <- run_isvb(TRUE)

  expect_true(isTRUE(all.equal(fit_r$theta.out$sm, fit_cpp$theta.out$sm, tolerance = 1e-6)))

  diag_r <- vapply(seq_len(TT), function(t) fit_r$theta.out$sC[1, 1, t], numeric(1))
  diag_cpp <- vapply(seq_len(TT), function(t) fit_cpp$theta.out$sC[1, 1, t], numeric(1))
  expect_true(isTRUE(all.equal(diag_r, diag_cpp, tolerance = 1e-6)))
  expect_true(is.finite(fit_cpp$theta.out$elbo_theta))
  expect_false("elbo.part" %in% names(fit_cpp$theta.out))
})

map_quantile_draws <- function(fit) {
  TT <- ncol(fit$model$FF)
  ns <- dim(fit$samp.theta)[3]
  vapply(seq_len(ns), function(i) {
    colSums(fit$model$FF * fit$samp.theta[, , i])
  }, numeric(TT))
}

map_quantile_path <- function(fit) {
  colSums(fit$model$FF * fit$theta.out$sm)
}

expect_postwarmup_elbo_finite <- function(fit) {
  finite_elbo <- is.finite(fit$diagnostics$elbo)
  expect_true(any(finite_elbo))
  expect_true(is.finite(utils::tail(fit$diagnostics$elbo[finite_elbo], 1)))
}

rmse_vec <- function(a, b) sqrt(mean((a - b)^2))

gamma_midpoint <- function(p0) {
  mean(as.numeric(get_gamma_bounds(p0)))
}

test_that("dqlm coercion is respected when gamma is fixed at zero", {
  set.seed(20260304)
  model <- as.exdqlm(list(m0 = 0, C0 = matrix(1, 1, 1), FF = 1, GG = 1))
  y <- c(0.1, -0.15, 0.05, 0.2)

  old_opts <- options(
    exdqlm.use_cpp_kf = FALSE,
    exdqlm.compute_elbo = TRUE,
    exdqlm.use_cpp_samplers = FALSE,
    exdqlm.use_cpp_postpred = FALSE,
    exdqlm.max_iter = 200L,
    exdqlm.vb.min_iter = 10L,
    exdqlm.vb.patience = 3L,
    exdqlm.tol_sigma = NULL,
    exdqlm.tol_gamma = NULL,
    exdqlm.tol_elbo = NULL,
    exdqlm.vb.allow_elbo_drop = NULL,
    exdqlm.dynamic.ldvb.sigmagam = NULL,
    exdqlm.dynamic.ldvb.sts = NULL,
    exdqlm.static.ldvb.sigmagam = NULL
  )
  on.exit(options(old_opts), add = TRUE)

  fit <- exdqlmISVB(
    y = y, p0 = 0.5, model = model, df = 1, dim.df = 1,
    fix.gamma = TRUE, gam.init = 0, dqlm.ind = FALSE,
    fix.sigma = FALSE, n.samp = 8, tol = 1e-3, verbose = FALSE
  )

  expect_true(isTRUE(fit$dqlm.ind))
  expect_null(fit$samp.gamma)
  expect_null(fit$samp.sts)
  expect_true(is.list(fit$sig.out))
  expect_true(all(is.finite(fit$sig.out$E.sigma)))
})

test_that("LDVB smoke on synthetic dynamic quantiles (exDQLM vs DQLM) stays finite and sensible", {
  skip_on_cran()
  set.seed(20260304)
  TT <- 80L
  t_idx <- seq_len(TT)
  mu_t <- 0.45 * sin(t_idx / 8) + 0.02 * t_idx
  sigma_true <- 0.35
  y <- mu_t + stats::rnorm(TT, mean = 0, sd = sigma_true)
  model <- polytrendMod(1, mean(y), 10)

  old_opts <- options(
    exdqlm.use_cpp_kf = FALSE,
    exdqlm.compute_elbo = TRUE,
    exdqlm.use_cpp_samplers = FALSE,
    exdqlm.use_cpp_postpred = FALSE
  )
  on.exit(options(old_opts), add = TRUE)

  for (k in seq_along(c(0.05, 0.5, 0.95))) {
    tau <- c(0.05, 0.5, 0.95)[k]
    set.seed(20260304 + k)
    true_q <- mu_t + stats::qnorm(tau) * sigma_true
    base_q <- rep(stats::quantile(y, probs = tau), TT)
    rmse_base <- rmse_vec(base_q, true_q)

    fit_ex <- exdqlmLDVB(
      y = y, p0 = tau, model = model, df = 0.98, dim.df = 1,
      gam.init = gamma_midpoint(tau), sig.init = stats::sd(y),
      fix.sigma = FALSE, tol = 0.1, n.samp = 30, verbose = FALSE,
      vb_control = exal_make_vb_control(max_iter = 200L, tol = 0.1, verbose = FALSE)
    )
    fit_dq <- exdqlmLDVB(
      y = y, p0 = tau, model = model, df = 0.98, dim.df = 1,
      dqlm.ind = TRUE, sig.init = stats::sd(y),
      fix.sigma = FALSE, tol = 0.1, n.samp = 30, verbose = FALSE,
      vb_control = exal_make_vb_control(max_iter = 200L, tol = 0.1, verbose = FALSE)
    )

    q_ex <- map_quantile_draws(fit_ex)
    q_dq <- map_quantile_draws(fit_dq)
    map_ex <- map_quantile_path(fit_ex)
    map_dq <- map_quantile_path(fit_dq)
    rmse_ex <- rmse_vec(map_ex, true_q)
    rmse_dq <- rmse_vec(map_dq, true_q)

    expect_true(all(is.finite(q_ex)))
    expect_true(all(is.finite(q_dq)))
    expect_postwarmup_elbo_finite(fit_ex)
    expect_postwarmup_elbo_finite(fit_dq)
    expect_lt(rmse_ex, rmse_base + 2.0)
    expect_lt(rmse_dq, rmse_base + 2.0)
    expect_true(isTRUE(fit_dq$dqlm.ind))
  }
})

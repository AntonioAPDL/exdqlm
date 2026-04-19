tiny_static_truth_case <- function(n = 36L, p0 = 0.25) {
  x <- seq(-2, 2, length.out = n)
  X <- cbind(1, x)
  mu <- 0.5 * x
  sigma <- 1.2 + 0.35 * x
  y <- mu + sigma * stats::rnorm(n)
  ref <- mu + sigma * stats::qnorm(p0)
  list(X = X, y = y, ref = ref, p0 = p0)
}

test_that("exalDiagnostics compares LDVB and MCMC on a shared design", {
  set.seed(20260409)
  dat <- tiny_static_truth_case(n = 36L, p0 = 0.25)

  fit_ldvb <- exal_static_LDVB(
    y = dat$y,
    X = dat$X,
    p0 = dat$p0,
    max_iter = 180,
    tol = 1e-3,
    n_samp_xi = 80,
    verbose = FALSE
  )
  fit_mcmc <- exal_static_mcmc(
    y = dat$y,
    X = dat$X,
    p0 = dat$p0,
    n.burn = 80,
    n.mcmc = 60,
    thin = 1,
    mh.proposal = "slice",
    verbose = FALSE
  )

  x_eval <- seq(-2, 2, length.out = 50L)
  X_eval <- cbind(1, x_eval)
  ref_eval <- 0.5 * x_eval + (1.2 + 0.35 * x_eval) * stats::qnorm(dat$p0)
  expect_no_error(
    exalDiagnostics(
      fit_ldvb, fit_mcmc,
      X = X_eval,
      ref = ref_eval,
      plot = FALSE
    )
  )

  diags <- exalDiagnostics(
    fit_ldvb, fit_mcmc,
    X = dat$X,
    y = dat$y,
    ref = dat$ref,
    plot = FALSE
  )

  expect_s3_class(diags, "exalDiagnostic")
  expect_true(is.exalDiagnostic(diags))
  expect_true(all(c(
    "m1.check_loss", "m2.check_loss",
    "m1.ref_rmse", "m2.ref_rmse",
    "m1.beta.mean", "m2.beta.mean"
  ) %in% names(diags)))
  expect_true(all(is.finite(c(
    diags$m1.check_loss, diags$m2.check_loss,
    diags$m1.ref_rmse, diags$m2.ref_rmse,
    diags$m1.rt, diags$m2.rt
  ))))

  expect_output(print(diags), "Static exAL diagnostics")
  expect_output(summary(diags), "Quantile level")

  tf <- tempfile(fileext = ".pdf")
  grDevices::pdf(tf)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_no_error(plot(diags))
})

test_that("static MCMC default proposal is slice", {
  set.seed(20260410)
  dat <- tiny_static_truth_case(n = 24L, p0 = 0.25)

  fit <- exal_static_mcmc(
    y = dat$y,
    X = dat$X,
    p0 = dat$p0,
    n.burn = 30,
    n.mcmc = 24,
    thin = 1,
    verbose = FALSE
  )

  expect_identical(fit$mh.diagnostics$proposal, "slice")
  expect_true(isTRUE(fit$mh.diagnostics$kernel_exact))
  expect_true(isTRUE(fit$mh.diagnostics$signoff_ready))
  expect_true(is.na(fit$accept.rate))
})

test_that("static LDVB records sigmagam warmup scheduling", {
  set.seed(202604101)
  dat <- tiny_static_truth_case(n = 30L, p0 = 0.25)

  fit <- exal_static_LDVB(
    y = dat$y,
    X = dat$X,
    p0 = dat$p0,
    max_iter = 120,
    tol = 1e-3,
    n_samp_xi = 80,
    ld_controls = list(
      sigmagam = list(
        freeze_warmup_iters = 3L,
        force_after_warmup = TRUE,
        min_postwarmup_updates = 1L
      )
    ),
    verbose = FALSE
  )

  expect_identical(fit$misc$sigmagam$freeze_warmup_iters, 3L)
  expect_gte(length(fit$misc$sigmagam_frozen_trace), 3L)
  expect_true(all(fit$misc$sigmagam_frozen_trace[1:3]))
  expect_true(is.logical(fit$diagnostics$convergence$sigmagam_min_updates_ok))
  expect_gte(fit$diagnostics$ld_block$sigmagam$update_count, 1L)
})

test_that("static MCMC records sigmagam warmup diagnostics", {
  set.seed(202604102)
  dat <- tiny_static_truth_case(n = 28L, p0 = 0.25)

  fit <- exal_static_mcmc(
    y = dat$y,
    X = dat$X,
    p0 = dat$p0,
    n.burn = 12,
    n.mcmc = 10,
    thin = 1,
    init.from.vb = TRUE,
    vb_init_controls = list(
      max_iter = 30,
      tol = 1e-3,
      n_samp_xi = 80,
      verbose = FALSE,
      ld_controls = list(
        sigmagam = list(
          freeze_warmup_iters = 2L,
          force_after_warmup = TRUE,
          min_postwarmup_updates = 1L
        )
      )
    ),
    sigmagam_controls = list(
      freeze_burnin_iters = 4L,
      freeze_only_during_burn = TRUE,
      force_after_warmup = TRUE,
      delay_adapt_until_after_warmup = TRUE,
      delay_laplace_refresh_until_after_warmup = TRUE
    ),
    mh.proposal = "slice",
    trace.diagnostics = TRUE,
    trace.every = 1L,
    verbose = FALSE
  )

  expect_identical(fit$diagnostics$sigmagam$freeze_burnin_iters, 4L)
  expect_gte(length(fit$diagnostics$sigmagam_trace$frozen), 4L)
  expect_true(all(fit$diagnostics$sigmagam_trace$frozen[1:4]))
  expect_gte(fit$diagnostics$sigmagam$first_active_iter, 5L)
  expect_gt(fit$diagnostics$sigmagam$update_count, 0L)
  expect_true(all(c("sigmagam_frozen", "sigmagam_update_reason") %in% names(fit$mh.diagnostics$trace)))
})

tiny_static_sparse_rhs_case <- function(n = 80L, p0 = 0.25) {
  cov_mat <- 0.5 ^ as.matrix(stats::dist(seq_len(8L)))
  beta_slopes <- c(2, 1, 0, 0, 1.5, 0, 0, 0)
  X_raw <- MASS::mvrnorm(n, mu = rep(0, 8L), Sigma = cov_mat)
  X <- cbind(1, X_raw)
  y <- as.numeric(X_raw %*% beta_slopes) + 1.25 * (stats::rnorm(n) - stats::qnorm(p0))
  list(
    X = X,
    y = y,
    ref = as.numeric(X %*% c(0, beta_slopes)),
    p0 = p0
  )
}

test_that("static rhs_ns sparse benchmark is silent and finite with VB warm start", {
  set.seed(20260411)
  dat <- tiny_static_sparse_rhs_case(n = 80L, p0 = 0.25)
  rhs_ctrl <- list(
    tau0 = 0.15,
    a_zeta = 2,
    b_zeta = 9,
    zeta2_fixed = 9,
    shrink_intercept = FALSE
  )

  expect_silent(
    fit_ldvb <- exal_static_LDVB(
      y = dat$y,
      X = dat$X,
      p0 = dat$p0,
      beta_prior = "rhs_ns",
      beta_prior_controls = rhs_ctrl,
      max_iter = 220,
      tol = 1e-4,
      n_samp_xi = 120,
      verbose = FALSE
    )
  )
  expect_true(isTRUE(fit_ldvb$converged))
  expect_true(all(is.finite(fit_ldvb$qbeta$m)))
  expect_true(all(is.finite(fit_ldvb$qv$E_v)))
  expect_false(isTRUE(fit_ldvb$beta_prior$summary$collapse_flag))
  expect_true(isTRUE(fit_ldvb$diagnostics$ld_block$mode_quality$local_mode_pass))
  expect_true(isTRUE(fit_ldvb$diagnostics$convergence$ld_signoff_ready))
  expect_false(isTRUE(fit_ldvb$diagnostics$ld_block$stabilization$active_final))

  expect_silent(
    fit_mcmc <- exal_static_mcmc(
      y = dat$y,
      X = dat$X,
      p0 = dat$p0,
      beta_prior = "rhs_ns",
      beta_prior_controls = rhs_ctrl,
      n.burn = 60,
      n.mcmc = 40,
      thin = 1,
      init.from.vb = TRUE,
      verbose = FALSE
    )
  )
  expect_identical(fit_mcmc$mh.diagnostics$proposal, "slice")
  expect_true(all(is.finite(as.matrix(fit_mcmc$samp.beta))))
  expect_false(isTRUE(fit_mcmc$beta_prior$summary$collapse_flag))

  diag_out <- exalDiagnostics(
    fit_ldvb,
    fit_mcmc,
    X = dat$X,
    ref = dat$ref,
    plot = FALSE
  )
  expect_true(all(is.finite(c(diag_out$m1.ref_rmse, diag_out$m2.ref_rmse))))
})

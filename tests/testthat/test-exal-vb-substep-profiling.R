make_substep_profile_fixture <- function(n = 24L) {
  set.seed(20260601)
  x <- seq(-1, 1, length.out = n)
  X <- cbind(1, x, sin(seq_along(x) / 5))
  y <- as.numeric(X %*% c(0.05, 0.25, -0.10) + stats::rnorm(n, sd = 0.08))
  list(X = X, y = y)
}

make_substep_qdesn_series <- function(n = 28L) {
  t <- seq_len(n)
  as.numeric(0.2 * sin(t / 3) + 0.05 * cos(t / 5))
}

make_substep_qdesn_common_args <- function(seed = 20260601L) {
  list(
    p0 = 0.5,
    D = 1L,
    n = 4L,
    m = 1L,
    washout = 4L,
    add_bias = TRUE,
    seed = as.integer(seed),
    fit_readout = TRUE
  )
}

make_substep_qdesn_vb_args <- function(max_iter = 8L) {
  list(
    likelihood_family = "al",
    al_fixed_gamma = 0,
    max_iter = as.integer(max_iter),
    min_iter_elbo = 4L,
    tol = 0,
    tol_par = 0,
    n_samp_xi = 16L,
    verbose = FALSE,
    beta_prior_type = "ridge",
    beta_ridge_tau2 = 10
  )
}

test_that("VB control preserves opt-in substep profiling diagnostics", {
  ctrl <- exdqlm::exal_make_vb_control(
    max_iter = 5L,
    diagnostics = list(profile_substeps = TRUE)
  )

  expect_true(isTRUE(ctrl$diagnostics$profile_substeps))

  ctrl_default <- exdqlm::exal_make_vb_control(max_iter = 5L)
  expect_false(isTRUE(ctrl_default$diagnostics$profile_substeps))
})

test_that("substep profiling is opt-in and preserves exact VB fitted state", {
  dat <- make_substep_profile_fixture()
  prior <- exdqlm:::exal_make_beta_prior(type = "ridge", tau2 = 20)
  ctrl <- list(
    max_iter = 8L,
    min_iter_elbo = 4L,
    tol = 0,
    tol_par = 0,
    n_samp_xi = 16L,
    verbose = FALSE
  )
  ctrl_profile <- modifyList(
    ctrl,
    list(diagnostics = list(profile_substeps = TRUE))
  )

  fit_plain <- exdqlm:::exal_fit(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    gamma_bounds = c(-3, 3),
    method = "vb",
    likelihood_family = "al",
    al_fixed_gamma = 0,
    vb_control = ctrl,
    prior_gamma = list(mu0 = 0, s20 = 10),
    prior_sigma = list(a = 1, b = 1),
    beta_prior_obj = prior
  )
  fit_profile <- exdqlm:::exal_fit(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    gamma_bounds = c(-3, 3),
    method = "vb",
    likelihood_family = "al",
    al_fixed_gamma = 0,
    vb_control = ctrl_profile,
    prior_gamma = list(mu0 = 0, s20 = 10),
    prior_sigma = list(a = 1, b = 1),
    beta_prior_obj = prior
  )

  expect_false(isTRUE(fit_plain$misc$diagnostics$profile_substeps))
  expect_equal(nrow(fit_plain$misc$substep_timing), 0L)
  expect_true(isTRUE(fit_profile$misc$diagnostics$profile_substeps))
  expect_true(is.data.frame(fit_profile$misc$substep_timing))
  expect_gt(nrow(fit_profile$misc$substep_timing), 0L)
  expect_true(all(fit_profile$misc$substep_timing$elapsed_sec >= 0))
  expect_true(all(c(
    "beta_update",
    "local_v_update",
    "local_s_update",
    "sigmagam_stats",
    "xi_refresh",
    "beta_prior_update",
    "elbo_initial",
    "rhs_tau_gate"
  ) %in% fit_profile$misc$substep_timing$substep))

  expect_equal(fit_profile$qbeta$m, fit_plain$qbeta$m, tolerance = 1e-12)
  expect_equal(fit_profile$qbeta$V, fit_plain$qbeta$V, tolerance = 1e-12)
  expect_equal(fit_profile$qv$m, fit_plain$qv$m, tolerance = 1e-12)
  expect_equal(fit_profile$qs$m, fit_plain$qs$m, tolerance = 1e-12)
  expect_equal(fit_profile$misc$elbo_trace, fit_plain$misc$elbo_trace, tolerance = 1e-12)
})

test_that("qdesn_fit_vb routes top-level diagnostics into the readout engine", {
  y <- make_substep_qdesn_series(28L)
  vb_args <- make_substep_qdesn_vb_args(max_iter = 8L)
  vb_args$diagnostics <- list(profile_substeps = TRUE)

  fit <- do.call(
    exdqlm::qdesn_fit_vb,
    c(
      list(y = y),
      make_substep_qdesn_common_args(seed = 20260601L),
      list(vb_args = vb_args)
    )
  )

  expect_true(isTRUE(fit$fit$misc$diagnostics$profile_substeps))
  expect_true(is.data.frame(fit$fit$misc$substep_timing))
  expect_gt(nrow(fit$fit$misc$substep_timing), 0L)
})

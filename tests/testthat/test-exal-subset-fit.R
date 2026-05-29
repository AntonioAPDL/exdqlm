`%||%` <- function(a, b) if (is.null(a)) b else a

make_subset_fit_data <- function(n = 44L, seed = 20260640L) {
  set.seed(as.integer(seed))
  x <- seq(-1, 1, length.out = n)
  X <- cbind(`(Intercept)` = 1, x = x, z = sin(seq_len(n) / 4))
  beta <- c(0.05, 0.25, -0.08)
  y <- as.numeric(X %*% beta + stats::rnorm(n, sd = 0.05))
  list(X = X, y = y, beta = beta)
}

make_subset_fit_control <- function(subset_fit = NULL, chunking = NULL, max_iter = 10L) {
  ctrl <- list(
    max_iter = as.integer(max_iter),
    min_iter_elbo = 3L,
    tol = 0,
    tol_par = 0,
    n_samp_xi = 16L,
    verbose = FALSE
  )
  if (!is.null(subset_fit)) ctrl$subset_fit <- subset_fit
  if (!is.null(chunking)) ctrl$chunking <- chunking
  ctrl
}

fit_subset_al <- function(dat, ctrl, prior = NULL, family = "al") {
  prior <- prior %||% exdqlm:::exal_make_beta_prior(type = "ridge", tau2 = 20)
  exdqlm:::exal_fit(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    gamma_bounds = c(-3, 3),
    method = "vb",
    likelihood_family = family,
    al_fixed_gamma = 0,
    vb_control = ctrl,
    prior_gamma = list(mu0 = 0, s20 = 10),
    prior_sigma = list(a = 1, b = 1),
    beta_prior_obj = prior
  )
}

test_that("subset_fit controls normalize and validate fixed row IDs", {
  expect_false("subset_fit" %in% names(exdqlm::exal_make_vb_control()))
  ctrl <- exdqlm::exal_make_vb_control(
    subset_fit = list(enabled = TRUE, mode = "fixed", rows = c(5L, 2L, 5L))
  )
  expect_true(isTRUE(ctrl$subset_fit$enabled))
  expect_identical(ctrl$subset_fit$mode, "fixed")
  expect_equal(ctrl$subset_fit$rows, c(5L, 2L))
  expect_identical(ctrl$subset_fit$target_label, "subset_data_vb")

  expect_error(
    exdqlm::exal_make_vb_control(subset_fit = list(enabled = TRUE, mode = "random", rows = 1:3)),
    "mode must be 'fixed'"
  )
  expect_error(
    exdqlm::exal_make_vb_control(subset_fit = list(enabled = TRUE)),
    "rows is required"
  )
  expect_error(
    exdqlm::exal_make_vb_control(subset_fit = list(enabled = TRUE, rows = c(1L, NA_integer_))),
    "finite integer"
  )
  expect_error(
    exdqlm::exal_make_vb_control(subset_fit = list(enabled = TRUE, rows = c(1, 2.5))),
    "finite integer"
  )
  expect_error(
    exdqlm:::.exal_normalize_vb_subset_fit_cfg(
      list(enabled = TRUE, rows = c(1L, 99L)),
      n = 10L
    ),
    "within 1:nrow"
  )
})

test_that("stratified subset controls select reproducible time-block rows", {
  cfg <- list(
    enabled = TRUE,
    mode = "stratified",
    strata = "time_block",
    size = 12L,
    n_strata = 4L,
    seed = 20260644L
  )
  ctrl <- exdqlm:::.exal_normalize_vb_subset_fit_cfg(cfg, n = 40L)
  ctrl2 <- exdqlm:::.exal_normalize_vb_subset_fit_cfg(cfg, n = 40L)
  ctrl3 <- exdqlm:::.exal_normalize_vb_subset_fit_cfg(modifyList(cfg, list(seed = 20260645L)), n = 40L)

  expect_true(isTRUE(ctrl$enabled))
  expect_identical(ctrl$mode, "stratified")
  expect_identical(ctrl$strata, "time_block")
  expect_identical(ctrl$allocation, "proportional")
  expect_equal(length(ctrl$rows), 12L)
  expect_equal(ctrl$rows, sort(ctrl$rows))
  expect_equal(length(unique(ctrl$rows)), 12L)
  expect_equal(ctrl$rows, ctrl2$rows)
  expect_false(identical(ctrl$rows, ctrl3$rows))
  expect_equal(sum(ctrl$stratum_allocation$n_selected), 12L)
  expect_true(all(ctrl$stratum_allocation$n_selected > 0L))
  expect_equal(length(ctrl$stratum_id), 40L)

  equal_ctrl <- exdqlm:::.exal_normalize_vb_subset_fit_cfg(
    modifyList(cfg, list(size = 10L, allocation = "equal")),
    n = 40L
  )
  expect_identical(equal_ctrl$allocation, "equal")
  expect_equal(sum(equal_ctrl$stratum_allocation$n_selected), 10L)
  expect_equal(equal_ctrl$stratum_allocation$n_selected, c(3L, 3L, 2L, 2L))
  expect_true(all(equal_ctrl$stratum_allocation$n_selected > 0L))

  pending <- exdqlm::exal_make_vb_control(subset_fit = cfg)$subset_fit
  expect_true(isTRUE(pending$pending))
  expect_equal(pending$rows, integer(0))

  pending_response <- exdqlm::exal_make_vb_control(
    subset_fit = modifyList(cfg, list(strata = "response_quantile"))
  )$subset_fit
  expect_true(isTRUE(pending_response$pending))
  expect_identical(pending_response$strata, "response_quantile")

  dat <- make_subset_fit_data(n = 40L, seed = 20260650L)
  response_ctrl <- exdqlm:::.exal_normalize_vb_subset_fit_cfg(
    modifyList(cfg, list(strata = "response_quantile")),
    n = nrow(dat$X),
    y = dat$y
  )
  leverage_ctrl <- exdqlm:::.exal_normalize_vb_subset_fit_cfg(
    modifyList(cfg, list(strata = "design_leverage")),
    n = nrow(dat$X),
    X = dat$X
  )
  expect_equal(length(response_ctrl$rows), 12L)
  expect_equal(length(leverage_ctrl$rows), 12L)
  expect_identical(response_ctrl$strata, "response_quantile")
  expect_identical(leverage_ctrl$strata, "design_leverage")
  expect_equal(sum(response_ctrl$stratum_allocation$n_selected), 12L)
  expect_equal(sum(leverage_ctrl$stratum_allocation$n_selected), 12L)

  expect_error(
    exdqlm::exal_make_vb_control(subset_fit = modifyList(cfg, list(allocation = "custom"))),
    "supports only 'proportional' or 'equal'"
  )
  expect_error(
    exdqlm::exal_make_vb_control(subset_fit = within(cfg, rm(seed))),
    "seed is required"
  )
  expect_error(
    exdqlm:::.exal_normalize_vb_subset_fit_cfg(modifyList(cfg, list(size = 41L)), n = 40L),
    "<= nrow"
  )
})

test_that("fixed subset VB matches an explicit fit on selected rows", {
  dat <- make_subset_fit_data()
  rows <- c(2L, 4L, 6L, 8L, 10L, 12L, 14L, 16L, 18L, 20L)
  subset_ctrl <- make_subset_fit_control(
    subset_fit = list(enabled = TRUE, mode = "fixed", rows = rows),
    max_iter = 12L
  )
  subset_fit <- fit_subset_al(dat, subset_ctrl)
  direct_fit <- fit_subset_al(
    list(X = dat$X[rows, , drop = FALSE], y = dat$y[rows]),
    make_subset_fit_control(max_iter = 12L)
  )

  expect_identical(subset_fit$misc$target_label, "subset_data_vb")
  expect_false(isTRUE(subset_fit$misc$preserves_full_data_target))
  expect_equal(subset_fit$misc$subset_rows, rows)
  expect_equal(subset_fit$misc$original_n, nrow(dat$X))
  expect_equal(subset_fit$misc$n, length(rows))
  expect_equal(subset_fit$qbeta$m, direct_fit$qbeta$m, tolerance = 1e-8)
  expect_equal(subset_fit$qbeta$V, direct_fit$qbeta$V, tolerance = 1e-8)
  expect_equal(subset_fit$misc$elbo_trace, direct_fit$misc$elbo_trace, tolerance = 1e-8)
})

test_that("fixed subset exact chunking matches fixed subset unchunked", {
  dat <- make_subset_fit_data(seed = 20260641L)
  rows <- seq(1L, 31L, by = 2L)
  plain <- fit_subset_al(
    dat,
    make_subset_fit_control(subset_fit = list(enabled = TRUE, rows = rows), max_iter = 11L)
  )
  exact <- fit_subset_al(
    dat,
    make_subset_fit_control(
      subset_fit = list(enabled = TRUE, rows = rows),
      chunking = list(enabled = TRUE, mode = "exact", chunk_size = 5L),
      max_iter = 11L
    )
  )

  expect_equal(exact$qbeta$m, plain$qbeta$m, tolerance = 1e-8)
  expect_equal(exact$qbeta$V, plain$qbeta$V, tolerance = 1e-8)
  expect_equal(exact$misc$elbo_trace, plain$misc$elbo_trace, tolerance = 1e-8)
})

test_that("stratified subset VB matches explicit fit and exact chunking", {
  dat <- make_subset_fit_data(seed = 20260646L, n = 48L)
  cfg <- list(
    enabled = TRUE,
    mode = "stratified",
    strata = "time_block",
    size = 16L,
    n_strata = 4L,
    seed = 20260647L
  )
  plain <- fit_subset_al(
    dat,
    make_subset_fit_control(subset_fit = cfg, max_iter = 12L)
  )
  rows <- plain$misc$subset_rows
  direct <- fit_subset_al(
    list(X = dat$X[rows, , drop = FALSE], y = dat$y[rows]),
    make_subset_fit_control(max_iter = 12L)
  )
  exact <- fit_subset_al(
    dat,
    make_subset_fit_control(
      subset_fit = cfg,
      chunking = list(enabled = TRUE, mode = "exact", chunk_size = 5L),
      max_iter = 12L
    )
  )

  expect_identical(plain$misc$target_label, "subset_data_vb")
  expect_identical(plain$misc$subset_fit$mode, "stratified")
  expect_false(isTRUE(plain$misc$preserves_full_data_target))
  expect_equal(length(rows), 16L)
  expect_equal(sum(plain$misc$subset_allocation$n_selected), 16L)
  expect_true(all(plain$misc$subset_allocation$n_selected > 0L))
  expect_equal(length(plain$misc$subset_strata), 16L)
  expect_equal(plain$qbeta$m, direct$qbeta$m, tolerance = 1e-8)
  expect_equal(plain$qbeta$V, direct$qbeta$V, tolerance = 1e-8)
  expect_equal(exact$misc$subset_rows, rows)
  expect_equal(exact$qbeta$m, plain$qbeta$m, tolerance = 1e-8)
  expect_equal(exact$qbeta$V, plain$qbeta$V, tolerance = 1e-8)
})

test_that("equal-allocation stratified subset VB matches explicit fit and exact chunking", {
  dat <- make_subset_fit_data(seed = 20260648L, n = 48L)
  cfg <- list(
    enabled = TRUE,
    mode = "stratified",
    strata = "time_block",
    allocation = "equal",
    size = 14L,
    n_strata = 4L,
    seed = 20260649L
  )
  plain <- fit_subset_al(
    dat,
    make_subset_fit_control(subset_fit = cfg, max_iter = 10L)
  )
  rows <- plain$misc$subset_rows
  direct <- fit_subset_al(
    list(X = dat$X[rows, , drop = FALSE], y = dat$y[rows]),
    make_subset_fit_control(max_iter = 10L)
  )
  exact <- fit_subset_al(
    dat,
    make_subset_fit_control(
      subset_fit = cfg,
      chunking = list(enabled = TRUE, mode = "exact", chunk_size = 5L),
      max_iter = 10L
    )
  )

  expect_identical(plain$misc$subset_fit$allocation, "equal")
  expect_equal(length(rows), 14L)
  expect_equal(sum(plain$misc$subset_allocation$n_selected), 14L)
  expect_true(max(plain$misc$subset_allocation$n_selected) - min(plain$misc$subset_allocation$n_selected) <= 1L)
  expect_equal(plain$qbeta$m, direct$qbeta$m, tolerance = 1e-8)
  expect_equal(plain$qbeta$V, direct$qbeta$V, tolerance = 1e-8)
  expect_equal(exact$misc$subset_rows, rows)
  expect_equal(exact$qbeta$m, plain$qbeta$m, tolerance = 1e-8)
  expect_equal(exact$qbeta$V, plain$qbeta$V, tolerance = 1e-8)
})

test_that("response and leverage stratified subset VB match explicit fit and exact chunking", {
  dat <- make_subset_fit_data(seed = 20260651L, n = 54L)
  for (strata in c("response_quantile", "design_leverage")) {
    cfg <- list(
      enabled = TRUE,
      mode = "stratified",
      strata = strata,
      allocation = "proportional",
      size = 18L,
      n_strata = 6L,
      seed = 20260652L
    )
    plain <- fit_subset_al(
      dat,
      make_subset_fit_control(subset_fit = cfg, max_iter = 9L)
    )
    rows <- plain$misc$subset_rows
    direct <- fit_subset_al(
      list(X = dat$X[rows, , drop = FALSE], y = dat$y[rows]),
      make_subset_fit_control(max_iter = 9L)
    )
    exact <- fit_subset_al(
      dat,
      make_subset_fit_control(
        subset_fit = cfg,
        chunking = list(enabled = TRUE, mode = "exact", chunk_size = 6L),
        max_iter = 9L
      )
    )

    expect_identical(plain$misc$target_label, "subset_data_vb")
    expect_identical(plain$misc$subset_fit$strata, strata)
    expect_false(isTRUE(plain$misc$preserves_full_data_target))
    expect_equal(length(rows), 18L)
    expect_equal(sum(plain$misc$subset_allocation$n_selected), 18L)
    expect_true(all(plain$misc$subset_allocation$n_selected > 0L))
    expect_equal(plain$qbeta$m, direct$qbeta$m, tolerance = 1e-8)
    expect_equal(plain$qbeta$V, direct$qbeta$V, tolerance = 1e-8)
    expect_equal(exact$misc$subset_rows, rows)
    expect_equal(exact$qbeta$m, plain$qbeta$m, tolerance = 1e-8)
    expect_equal(exact$qbeta$V, plain$qbeta$V, tolerance = 1e-8)
  }
})

test_that("fixed subset mode fails early outside AL ridge full/exact scope", {
  dat <- make_subset_fit_data(seed = 20260642L, n = 30L)
  ctrl <- make_subset_fit_control(subset_fit = list(enabled = TRUE, rows = 1:12))
  expect_error(
    fit_subset_al(dat, ctrl, family = "exal"),
    "likelihood_family = 'al'"
  )

  rhs_prior <- exdqlm:::exal_make_beta_prior(
    type = "rhs_ns",
    rhs = list(tau0 = 0.5, s2 = 1, shrink_intercept = FALSE, n_inner = 1L)
  )
  expect_error(
    fit_subset_al(dat, ctrl, prior = rhs_prior),
    "ridge beta priors"
  )

  stoch_ctrl <- make_subset_fit_control(
    subset_fit = list(enabled = TRUE, rows = 1:12),
    chunking = list(enabled = TRUE, mode = "stochastic", chunk_size = 6L)
  )
  expect_error(
    fit_subset_al(dat, stoch_ctrl),
    "unchunked or exact chunked"
  )
})

test_that("qdesn_fit_vb routes fixed subset controls", {
  t <- seq_len(34L)
  y <- as.numeric(0.16 * sin(t / 4) + 0.03 * cos(t / 8))
  args <- list(
    likelihood_family = "al",
    al_fixed_gamma = 0,
    beta_prior_type = "ridge",
    beta_ridge_tau2 = 10,
    max_iter = 8L,
    min_iter_elbo = 2L,
    tol = 0,
    tol_par = 0,
    n_samp_xi = 16L,
    verbose = FALSE,
    subset_fit = list(enabled = TRUE, rows = 1:12)
  )
  fit <- exdqlm::qdesn_fit_vb(
    y = y,
    p0 = 0.5,
    D = 1L,
    n = 4L,
    m = 1L,
    washout = 4L,
    add_bias = TRUE,
    seed = 20260643L,
    fit_readout = TRUE,
    vb_args = args
  )

  expect_s3_class(fit$fit, "exal_vb")
  expect_identical(fit$fit$misc$target_label, "subset_data_vb")
  expect_equal(fit$fit$misc$subset_rows, 1:12)
  expect_equal(fit$fit$misc$n, 12L)
  expect_equal(length(fit$mu_hat), nrow(fit$X))
  expect_true(all(is.finite(fit$fit$qbeta$m)))
})

test_that("qdesn_fit_vb routes stratified subset controls", {
  t <- seq_len(42L)
  y <- as.numeric(0.12 * sin(t / 5) + 0.04 * cos(t / 9))
  args <- list(
    likelihood_family = "al",
    al_fixed_gamma = 0,
    beta_prior_type = "ridge",
    beta_ridge_tau2 = 10,
    max_iter = 8L,
    min_iter_elbo = 2L,
    tol = 0,
    tol_par = 0,
    n_samp_xi = 16L,
    verbose = FALSE,
    subset_fit = list(
      enabled = TRUE,
      mode = "stratified",
      strata = "time_block",
      size = 12L,
      n_strata = 3L,
      seed = 20260648L
    )
  )
  fit <- exdqlm::qdesn_fit_vb(
    y = y,
    p0 = 0.5,
    D = 1L,
    n = 4L,
    m = 1L,
    washout = 4L,
    add_bias = TRUE,
    seed = 20260649L,
    fit_readout = TRUE,
    vb_args = args
  )

  expect_s3_class(fit$fit, "exal_vb")
  expect_identical(fit$fit$misc$target_label, "subset_data_vb")
  expect_identical(fit$fit$misc$subset_fit$mode, "stratified")
  expect_equal(length(fit$fit$misc$subset_rows), 12L)
  expect_equal(sum(fit$fit$misc$subset_allocation$n_selected), 12L)
  expect_equal(length(fit$mu_hat), nrow(fit$X))
  expect_true(all(is.finite(fit$fit$qbeta$m)))
})

test_that("qdesn_fit_vb routes response and leverage stratified subset controls", {
  t <- seq_len(46L)
  y <- as.numeric(0.10 * sin(t / 4) + 0.03 * cos(t / 6))
  for (strata in c("response_quantile", "design_leverage")) {
    args <- list(
      likelihood_family = "al",
      al_fixed_gamma = 0,
      beta_prior_type = "ridge",
      beta_ridge_tau2 = 10,
      max_iter = 7L,
      min_iter_elbo = 2L,
      tol = 0,
      tol_par = 0,
      n_samp_xi = 16L,
      verbose = FALSE,
      subset_fit = list(
        enabled = TRUE,
        mode = "stratified",
        strata = strata,
        size = 12L,
        n_strata = 3L,
        seed = 20260653L
      )
    )
    fit <- exdqlm::qdesn_fit_vb(
      y = y,
      p0 = 0.5,
      D = 1L,
      n = 4L,
      m = 1L,
      washout = 4L,
      add_bias = TRUE,
      seed = 20260654L,
      fit_readout = TRUE,
      vb_args = args
    )

    expect_s3_class(fit$fit, "exal_vb")
    expect_identical(fit$fit$misc$target_label, "subset_data_vb")
    expect_identical(fit$fit$misc$subset_fit$strata, strata)
    expect_equal(length(fit$fit$misc$subset_rows), 12L)
    expect_equal(sum(fit$fit$misc$subset_allocation$n_selected), 12L)
    expect_true(all(is.finite(fit$fit$qbeta$m)))
  }
})

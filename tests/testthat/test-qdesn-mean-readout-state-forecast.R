make_mean_readout_state_fixture <- function() {
  withr::local_seed(17201)
  y <- as.numeric(arima.sim(list(ar = 0.55), n = 95, sd = 0.25))
  fit <- exdqlm:::qdesn_fit_vb(
    y = y,
    p0 = 0.25,
    D = 2L,
    n = c(7L, 5L),
    n_tilde = 4L,
    m = 2L,
    alpha = c(0.25, 0.35),
    rho = c(0.85, 0.80),
    pi_w = 1,
    pi_in = 1,
    washout = 5L,
    add_bias = TRUE,
    seed = 17202,
    fit_readout = TRUE,
    vb_args = list(
      max_iter = 8L,
      min_iter_elbo = 2L,
      tol = 1e-3,
      tol_par = 1e-3,
      verbose = FALSE
    )
  )
  list(y = y, fit = fit)
}

test_that("mean-readout-state recursion equals native recursion for one draw", {
  fixture <- make_mean_readout_state_fixture()
  draws <- exdqlm::exal_posterior_draws(fixture$fit$fit, nd = 1L)
  noise <- list(
    s = matrix(c(0.4, 0.7, 1.1, 0.2), ncol = 1L),
    v = matrix(c(0.3, 0.8, 0.5, 0.9), ncol = 1L),
    z = matrix(c(-0.2, 0.1, 0.4, -0.3), ncol = 1L)
  )
  args <- list(
    object = fixture$fit,
    H = 4L,
    y_hist = tail(fixture$y, 2L),
    draws = draws,
    noise_draws = noise
  )
  native <- do.call(
    exdqlm:::forecast_paths.qdesn_fit,
    c(args, list(recursion_mode = "posterior_predictive"))
  )
  mean_state <- do.call(
    exdqlm:::forecast_paths.qdesn_fit,
    c(args, list(recursion_mode = "posterior_predictive_mean_readout_state"))
  )

  expect_equal(mean_state$mu_draws, native$mu_draws, tolerance = 1e-12)
  expect_equal(mean_state$yrep, native$yrep, tolerance = 1e-12)
  expect_identical(attr(mean_state, "backend"), "r_mean_readout_state")
  expect_match(mean_state$feature_basis_hash, "^[0-9a-f]{64}$")
})

test_that("mean-readout-state recursion is invariant to draw permutation", {
  fixture <- make_mean_readout_state_fixture()
  draws <- exdqlm::exal_posterior_draws(fixture$fit$fit, nd = 12L)
  withr::local_seed(17203)
  noise <- list(
    s = matrix(abs(rnorm(60L)), nrow = 5L),
    v = matrix(rexp(60L), nrow = 5L),
    z = matrix(rnorm(60L), nrow = 5L)
  )
  perm <- c(12L, 3L, 7L, 1L, 9L, 5L, 10L, 2L, 11L, 4L, 8L, 6L)
  reorder_draws <- function(x, idx) {
    list(
      beta = x$beta[idx, , drop = FALSE],
      sigma = x$sigma[idx],
      gamma = x$gamma[idx],
      source_draw_index = x$source_draw_index[idx]
    )
  }
  reorder_noise <- function(x, idx) lapply(x, function(z) z[, idx, drop = FALSE])
  run <- function(draw_set, noise_set) {
    exdqlm:::forecast_paths.qdesn_fit(
      fixture$fit,
      H = 5L,
      y_hist = tail(fixture$y, 2L),
      draws = draw_set,
      noise_draws = noise_set,
      recursion_mode = "posterior_predictive_mean_readout_state"
    )
  }
  base <- run(draws, noise)
  shuffled <- run(reorder_draws(draws, perm), reorder_noise(noise, perm))

  expect_equal(shuffled$mu_draws, base$mu_draws[, perm, drop = FALSE], tolerance = 1e-12)
  expect_equal(shuffled$yrep, base$yrep[, perm, drop = FALSE], tolerance = 1e-12)
  expect_equal(shuffled$mean_readout_by_lead, base$mean_readout_by_lead, tolerance = 1e-12)
  expect_equal(shuffled$state_dispersion_by_lead, base$state_dispersion_by_lead, tolerance = 1e-12)
})

test_that("lead one agrees across estimators for multiple posterior draws", {
  fixture <- make_mean_readout_state_fixture()
  draws <- exdqlm::exal_posterior_draws(fixture$fit$fit, nd = 8L)
  withr::local_seed(17205)
  noise <- list(
    s = matrix(abs(rnorm(8L)), nrow = 1L),
    v = matrix(rexp(8L), nrow = 1L),
    z = matrix(rnorm(8L), nrow = 1L)
  )
  run <- function(mode) exdqlm:::forecast_paths.qdesn_fit(
    fixture$fit, H = 1L, y_hist = tail(fixture$y, 2L), draws = draws,
    noise_draws = noise, recursion_mode = mode
  )
  native <- run("posterior_predictive")
  candidate <- run("posterior_predictive_mean_readout_state")
  expect_equal(candidate$mu_draws, native$mu_draws, tolerance = 1e-12)
  expect_equal(candidate$yrep, native$yrep, tolerance = 1e-12)
})

test_that("mean-readout-state lattice records its estimator contract", {
  fixture <- make_mean_readout_state_fixture()
  draws <- exdqlm::exal_posterior_draws(fixture$fit$fit, nd = 10L)
  out <- exdqlm:::forecast_lattice.qdesn_fit(
    fixture$fit,
    y_all = fixture$y,
    origins = c(75L, 80L),
    H = 4L,
    nd = 10L,
    draws = draws,
    keep_origin_draws = TRUE,
    seed = 17204,
    recursion_mode = "posterior_predictive_mean_readout_state"
  )

  expect_identical(out$recursion_mode, "posterior_predictive_mean_readout_state")
  expect_match(out$feature_basis_hash, "^[0-9a-f]{64}$")
  expect_length(out$mean_readout_by_origin, 2L)
  expect_equal(dim(out$mu_by_origin[[1L]]), c(4L, 10L))
  expect_true(all(is.finite(out$mu_by_origin[[1L]])))
  expect_true(all(is.finite(out$state_dispersion_by_origin[[1L]])))
})

test_that("feature-basis hash detects reservoir changes", {
  fixture <- make_mean_readout_state_fixture()
  same <- fixture$fit
  changed <- fixture$fit
  changed$reservoir$W[[1L]][1L, 1L] <- changed$reservoir$W[[1L]][1L, 1L] + 1e-8

  expect_identical(
    exdqlm:::.qdesn_mean_readout_state_basis_hash(fixture$fit),
    exdqlm:::.qdesn_mean_readout_state_basis_hash(same)
  )
  expect_false(identical(
    exdqlm:::.qdesn_mean_readout_state_basis_hash(fixture$fit),
    exdqlm:::.qdesn_mean_readout_state_basis_hash(changed)
  ))

  transformed <- fixture$fit
  transformed$meta$readout_spec <- list(
    linear_transform = list(mode = "none", active = FALSE, audit_tag = "changed")
  )
  expect_false(identical(
    exdqlm:::.qdesn_mean_readout_state_basis_hash(fixture$fit),
    exdqlm:::.qdesn_mean_readout_state_basis_hash(transformed)
  ))
})

test_that("mean-readout-state mode rejects unsupported authority contracts", {
  fixture <- make_mean_readout_state_fixture()
  draws <- exdqlm::exal_posterior_draws(fixture$fit$fit, nd = 3L)
  lagged <- fixture$fit
  lagged$meta$readout_spec <- list(reservoir_lags = 1L)
  expect_error(
    exdqlm:::forecast_paths.qdesn_fit(
      lagged, H = 2L, y_hist = tail(fixture$y, 2L), draws = draws,
      recursion_mode = "posterior_predictive_mean_readout_state"
    ),
    "does not yet support reservoir-lag"
  )
  decomposed <- fixture$fit
  decomposed$meta$readout_spec <- list(
    input_mode = "dlm_decomp_lags", decomposition = list(enabled = TRUE)
  )
  expect_error(
    suppressWarnings(exdqlm:::forecast_paths.qdesn_fit(
      decomposed, H = 2L, y_hist = tail(fixture$y, 2L), draws = draws,
      recursion_mode = "posterior_predictive_mean_readout_state"
    )),
    "decomposition runtime|does not yet support decomposed"
  )
})

test_that("mean-readout-state recursion supports authority depths one and three", {
  withr::local_seed(17206)
  y <- as.numeric(arima.sim(list(ar = 0.45), n = 65, sd = 0.2))
  specs <- list(
    list(D = 1L, n = 6L, n_tilde = integer(0), alpha = 0.2, rho = 0.8),
    list(D = 3L, n = c(6L, 5L, 4L), n_tilde = c(4L, 3L),
         alpha = c(0.2, 0.3, 0.4), rho = c(0.8, 0.82, 0.84))
  )
  for (i in seq_along(specs)) {
    s <- specs[[i]]
    fit <- exdqlm:::qdesn_fit_vb(
      y = y, p0 = 0.25, D = s$D, n = s$n, n_tilde = s$n_tilde,
      m = 2L, alpha = s$alpha, rho = s$rho, pi_w = 1, pi_in = 1,
      washout = 4L, add_bias = TRUE, seed = 17206L + i,
      fit_readout = TRUE,
      vb_args = list(max_iter = 5L, min_iter_elbo = 2L, tol = 1e-3,
                     tol_par = 1e-3, verbose = FALSE)
    )
    draws <- exdqlm::exal_posterior_draws(fit$fit, nd = 4L)
    out <- exdqlm:::forecast_paths.qdesn_fit(
      fit, H = 2L, y_hist = tail(y, 2L), draws = draws,
      recursion_mode = "posterior_predictive_mean_readout_state", seed = 17220L + i
    )
    expect_equal(dim(out$mu_draws), c(2L, 4L))
    expect_equal(ncol(out$state_dispersion_by_lead), s$D)
    expect_true(all(is.finite(out$mu_draws)))
  }
})

test_that("nonoverlapping rolling-origin blocks tile the held-out window", {
  left <- matrix(1:12, nrow = 3L, ncol = 4L)
  right <- matrix(13:24, nrow = 3L, ncol = 4L)
  tiled <- exdqlm:::.qdesn_tile_origin_draws(
    list(left, right), origins = c(10L, 13L), targets = 11:16
  )
  expect_equal(tiled, rbind(left, right))
  expect_error(
    exdqlm:::.qdesn_tile_origin_draws(
      list(left, right), origins = c(10L, 12L), targets = 11:15
    ),
    "overlap"
  )
  expect_error(
    exdqlm:::.qdesn_tile_origin_draws(
      list(left, right), origins = c(10L, 14L), targets = 11:17
    ),
    "cover every requested target"
  )
})

test_that("analysis source coordinates preserve explicit simulation indices", {
  rows <- 2:4
  expect_identical(
    exdqlm:::.qdesn_resolve_analysis_source_index(
      data.frame(source_index = 8109:8113, t = 1:5), rows
    ),
    8110:8112
  )
  expect_identical(
    exdqlm:::.qdesn_resolve_analysis_source_index(
      data.frame(t = 910:914, y = 0), rows
    ),
    911:913
  )
  expect_identical(
    exdqlm:::.qdesn_resolve_analysis_source_index(
      data.frame(y = seq_len(5L)), rows
    ),
    rows
  )
  expect_identical(
    exdqlm:::.qdesn_resolve_analysis_source_index(
      data.frame(y = seq_len(5L)), rows,
      explicit_source_index = 8109:8113
    ),
    8110:8112
  )
})

test_that("analysis source coordinates reject ambiguous mappings", {
  expect_error(
    exdqlm:::.qdesn_resolve_analysis_source_index(
      data.frame(t = c(1, 2, 2, 4)), 1:4
    ),
    "unique, and strictly increasing"
  )
  expect_error(
    exdqlm:::.qdesn_resolve_analysis_source_index(
      data.frame(source_index = c(1, NA, 3)), 1:3
    ),
    "finite, integer-valued"
  )
  expect_error(
    exdqlm:::.qdesn_resolve_analysis_source_index(
      data.frame(y = 1:3), 1:3, explicit_source_index = 1:2
    ),
    "must match the data rows"
  )
})

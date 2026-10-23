# Independent tests of the normalized Gaussian/RHS target.  Numerical oracles
# below use dense observation-space covariance matrices, rather than the
# coefficient-space linear algebra used by the production implementation.

rhs_test_internal <- function(name) {
  get(name, envir = environment(autodesn_fit_bank), inherits = TRUE)
}

rhs_test_log_mvn <- function(y, C) {
  L <- t(chol(C))
  -.5 * (length(y) * log(2 * pi) + 2 * sum(log(diag(L))) +
         sum(forwardsolve(L, y)^2))
}

rhs_test_batch_se <- function(x) {
  n <- length(x)
  size <- max(2L, as.integer(floor(sqrt(n))))
  nb <- as.integer(n %/% size)
  sqrt(stats::var(colMeans(matrix(x[seq_len(size * nb)], size, nb))) / nb)
}

rhs_test_specs <- function() {
  list(shallow = list(D = 1L, n = 4L, m = 1L, alpha = .4, rho = .5,
                     pi_w = 1, pi_in = 1, washout = 3L, seed = 311L),
       deep = list(D = 2L, n = c(5L, 3L), n_tilde = 2L, m = 2L,
                   alpha = c(.3, .7), rho = c(.4, .7),
                   pi_w = 1, pi_in = 1, washout = 4L, seed = 329L,
                   standardize_inputs = TRUE, input_bound = "tanh"))
}

rhs_test_fixed_reference <- function(bank, local, global, slab, tau0) {
  a <- 3; b <- 1
  log_evidence <- vapply(seq_along(bank$models), function(j) {
    model <- bank$models[[j]]
    lambda <- rep_len(local, model$d)
    v <- 1 / (1 / slab + 1 / (tau0[j] * global * lambda)^2)
    D <- diag(c(10, v), model$d + 1L)
    prior_covariance <- model$X %*% D %*% t(model$X)
    log_density <- function(eta) vapply(eta, function(e) {
      rhs_test_log_mvn(bank$y, exp(e) * diag(bank$n) + prior_covariance) +
        a * log(b) - lgamma(a) - a * e - b * exp(-e)
    }, numeric(1))
    shift <- -stats::optimize(function(e) -log_density(e), c(-15, 15))$objective
    integral <- stats::integrate(function(e) exp(log_density(e) - shift),
                                lower = -25, upper = 25,
                                rel.tol = 1e-10, subdivisions = 500L)
    expect_lt(integral$abs.error / integral$value, 1e-7)
    shift + log(integral$value)
  }, numeric(1))
  w <- exp(log(bank$prior) + log_evidence - max(log(bank$prior) + log_evidence))
  w / sum(w)
}

test_that("RHS Gaussian integration agrees with dense covariance at unequal ranks", {
  withr::local_seed(7312)
  y <- stats::rnorm(9)
  H <- matrix(stats::rnorm(27), 9, 3)
  bank <- autodesn_prepare_bank(y, list(H, cbind(H, H[, 1], 1),
    matrix(stats::rnorm(9 * 13), 9, 13), matrix(numeric(), 9, 0)))
  evaluate <- rhs_test_internal(".autodesn_rhs_gaussian_R")
  for (model in bank$models) {
    lpv <- c(log(10), if (model$d) seq(-10, 5, length.out = model$d) else numeric())
    D <- diag(exp(lpv), model$d + 1L)
    for (sigma2 in c(.025, .7, 4)) {
      C <- sigma2 * diag(bank$n) + model$X %*% D %*% t(model$X)
      expected <- rhs_test_log_mvn(y, C)
      result <- evaluate(model, y, sigma2, lpv)
      expect_equal(result$log_evidence, expected, tolerance = 2e-8)
      expect_true(all(is.finite(result$mean)))
    }
  }
})

test_that("RHS coefficient sampler has the independently derived Gaussian covariance", {
  x <- seq(-1, 1, length.out = 13)
  y <- sin(2 * x) + .1 * cos(5 * x)
  bank <- autodesn_prepare_bank(y, list(cbind(x, x, x^2, 1)))
  model <- bank$models[[1L]]
  variance <- .6
  prior_variance <- c(10, .03, 2, .7, .2)
  P <- crossprod(model$X) / variance + diag(1 / prior_variance)
  V <- solve(P)
  target_mean <- as.vector(V %*% crossprod(model$X, y) / variance)
  gaussian <- rhs_test_internal(".autodesn_rhs_gaussian_R")(
    model, y, variance, log(prior_variance))
  draw <- rhs_test_internal(".autodesn_rhs_beta_draw")
  expect_equal(gaussian$mean, target_mean, tolerance = 1e-11)
  p <- length(prior_variance)
  transform <- vapply(seq_len(p), function(j) {
    z <- numeric(p); z[j] <- 1
    as.vector(draw(gaussian, z) - gaussian$mean)
  }, numeric(p))
  expect_equal(tcrossprod(transform), unname(V), tolerance = 1e-11)
  expect_equal(as.vector(draw(gaussian, numeric(p))), target_mean, tolerance = 1e-11)
})

test_that("RHS scale targets retain the variance normalizer and log-coordinate Jacobians", {
  variance <- rhs_test_internal(".autodesn_rhs_log_variance")
  target <- rhs_test_internal(".autodesn_rhs_log_scale_target")
  local <- c(.08, .7, 5)
  beta <- c(.03, -.6, 1.1)
  tau0 <- .45; df <- 4; scale <- 1.7
  points <- rbind(c(log(.2), log(.4)), c(log(.9), log(3)), c(log(2.4), log(8)))
  actual <- expected <- numeric(nrow(points))
  for (k in seq_len(nrow(points))) {
    logu <- points[k, 1]; logc2 <- points[k, 2]
    u <- exp(logu); c2 <- exp(logc2)
    v <- 1 / (1 / c2 + 1 / (tau0 * u * local)^2)
    expect_equal(variance(log(local), logu, logc2, tau0), log(v), tolerance = 1e-12)
    actual[k] <- target(log(local), logu, logc2, beta, tau0, df, scale)
    a <- df / 2; b <- df * scale^2 / 2
    expected[k] <- sum(stats::dnorm(beta, 0, sqrt(v), log = TRUE)) +
      log(2 / pi) - log1p(u^2) + logu +
      a * log(b) - lgamma(a) - (a + 1) * logc2 - b / c2 + logc2
  }
  expect_equal(actual - actual[1L], expected - expected[1L], tolerance = 1e-11)
  # Without the Gaussian normalizer this changes by a nonconstant amount.
  expect_gt(max(abs(diff(expected))), .1)
})

test_that("the local RHS rejection sampler matches normalized scalar quadrature", {
  withr::local_seed(8231)
  sample_local <- rhs_test_internal(".autodesn_rhs_local_R")
  beta <- .8; tau <- .45; c2 <- 1.7; nu <- .6
  A <- 1 / c2; B <- 1 / tau^2
  rate <- 1 / nu + beta^2 / (2 * tau^2)
  log_integrand <- function(eta) {
    .5 * log(A + B * exp(-2 * eta)) - eta - rate * exp(-2 * eta)
  }
  top <- -stats::optimize(function(eta) -log_integrand(eta), c(-10, 10))$objective
  density <- function(eta) exp(log_integrand(eta) - top)
  total <- stats::integrate(density, -20, 30, rel.tol = 1e-11)$value
  bounded <- function(eta) 2 / pi * atan(exp(eta))
  mu <- stats::integrate(function(e) bounded(e) * density(e), -20, 30,
                         rel.tol = 1e-11)$value / total
  second <- stats::integrate(function(e) bounded(e)^2 * density(e), -20, 30,
                             rel.tol = 1e-11)$value / total
  N <- 6000L
  values <- replicate(N, {
    result <- sample_local(0, log(nu), beta, log(tau), log(c2))
    bounded(result$log_local)
  })
  expect_lt(abs(mean(values) - mu), 6 * sqrt((second - mu^2) / N))
  expect_true(all(is.finite(values) & values > 0 & values < 1))
})

test_that("frozen RHS scales agree with independently integrated Gaussian model odds", {
  x <- seq(-1, 1, length.out = 9)
  y <- .6 * x + c(.2, -.1, .1, -.2, .15, .1, -.05, .2, -.15)
  bank <- autodesn_prepare_bank(y,
    list(matrix(numeric(), 9, 0), cbind(x), cbind(x, x^2)),
    model_prior = c(.25, .45, .3))
  tau0 <- c(.7, .9, 1.2)
  control <- list(tau0 = tau0, fixed_local_scales = c(.6, 1.4),
                  learn_global = FALSE, initial_global = .8,
                  learn_slab = FALSE, initial_slab = 2.5)
  reference <- rhs_test_fixed_reference(bank, c(.6, 1.4), .8, 2.5, tau0)
  for (method in c("categorical", "mh")) {
    fit <- autodesn_fit_bank(bank, beta_prior = "rhs", rhs_control = control,
      model_control = list(method = method, moves = 2L), backend = "r",
      n_burn = 400L, n_mcmc = 4500L, seed = if (method == "mh") 783L else 784L)
    for (j in seq_along(bank$models)) {
      indicator <- as.numeric(fit$draws$model == j)
      tolerance <- max(.018, 6 * rhs_test_batch_se(indicator))
      expect_lt(abs(mean(indicator) - reference[j]), tolerance)
      expect_lt(abs(fit$model_summary$posterior_probability[j] - reference[j]), tolerance)
    }
    expect_equal(fit$draws$global_scale, rep(.8, 4500L))
    expect_equal(fit$draws$slab_variance, rep(2.5, 4500L))
  }
})

test_that("uninformative slope designs preserve architecture prior mass across dimensions", {
  bank <- autodesn_prepare_bank(c(-.4, .1, .3, -.2, .2),
    list(matrix(numeric(), 5, 0), matrix(0, 5, 1), matrix(0, 5, 7)),
    model_prior = c(.15, .3, .55))
  fit <- autodesn_fit_bank(bank, beta_prior = "rhs",
    rhs_control = list(tau0 = c(.1, 1, 3)),
    model_control = list(method = "categorical"),
    n_burn = 100L, n_mcmc = 600L, seed = 338L, backend = "r")
  expected <- matrix(rep(bank$prior, each = nrow(fit$draws)), nrow(fit$draws))
  expect_equal(unname(fit$conditional_probabilities), expected, tolerance = 1e-11)
  expect_equal(fit$model_summary$posterior_probability, bank$prior, tolerance = 1e-11)
})

test_that("RHS fitting restores RNG, saves joint draws, and is reproducible", {
  bank <- autodesn_build_bank(sin(seq_len(55) / 5), rhs_test_specs(), conditioning = 9L)
  withr::local_seed(249)
  before <- .Random.seed
  args <- list(bank = bank, beta_prior = "rhs", n_burn = 20L, n_mcmc = 80L,
    thin = 2L, seed = 937L, rhs_control = list(save_local = TRUE), backend = "r")
  first <- do.call(autodesn_fit_bank, args)
  expect_identical(.Random.seed, before)
  again <- do.call(autodesn_fit_bank, args)
  expect_identical(first$draws, again$draws)
  expect_identical(first$beta, again$beta)
  expect_identical(first$local_scales, again$local_scales)
  d <- vapply(bank$models[first$draws$model], function(m) m$d, integer(1))
  expect_equal(vapply(first$beta, length, integer(1)), d + 1L)
  expect_equal(vapply(first$local_scales, length, integer(1)), d)
  expect_equal(first$meta$beta_prior_type, "independent_rhs")
  expect_equal(first$meta$prior_family, "regularized_horseshoe_pv")
  expect_true(all(is.finite(first$draws$variance)))
  expect_true(all(first$draws$variance > 0))
})

test_that("RHS recursive forecasts retain causal features and joint posterior paths", {
  y <- sin(seq_len(60) / 5) + .1 * cos(seq_len(60))
  specs <- rhs_test_specs()
  bank <- autodesn_build_bank(y, specs, conditioning = 9L)
  fit <- autodesn_fit_bank(bank, beta_prior = "rhs", n_burn = 20L, n_mcmc = 60L,
    seed = 600L, backend = "r")
  withr::local_seed(611)
  noise <- matrix(stats::rnorm(4 * 6), 4, 6)
  ids <- c(2L, 7L, 13L)
  serial <- forecast_paths.autodesn_fit(fit, H = 4L, draw_index = ids,
    inner_paths = 2L, innovations = noise, backend = "serial")
  batched <- forecast_paths.autodesn_fit(fit, H = 4L, draw_index = ids,
    inner_paths = 2L, innovations = noise, backend = "batched")
  expect_equal(serial$yrep, batched$yrep, tolerance = 1e-11)
  expect_equal(serial$mu_draws, batched$mu_draws, tolerance = 1e-11)
  expect_identical(serial$model, fit$draws$model[serial$draw_index])
  expect_identical(serial$draw_index, rep(ids, each = 2L))
  for (s in seq_len(ncol(serial$yrep))) {
    j <- serial$model[s]
    k <- serial$draw_index[s]
    history <- y
    for (h in 1:2) {
      extended <- autodesn_build_bank(c(history, 9999), specs[j], conditioning = 9L)
      row <- tail(extended$models[[1L]]$X, 1L)
      mu <- sum(row * fit$beta[[k]])
      expected <- bank$preprocessing$center + bank$preprocessing$scale * mu
      expect_equal(serial$mu_draws[h, s], expected, tolerance = 1e-10)
      history <- c(history, serial$yrep[h, s])
    }
  }
  expect_error(forecast_paths.autodesn_fit(fit, 2L, y_future_obs = c(0, 0)),
               "additional controls")
})

test_that("RHS diagnostics reject different prior targets and accept different proposal kernels", {
  x <- seq(-1, 1, length.out = 12)
  bank <- autodesn_prepare_bank(sin(x), list(cbind(x), cbind(x, x^2)))
  make <- function(seed, method = "mh", tau0 = .6) autodesn_fit_bank(bank,
    beta_prior = "rhs", rhs_control = list(tau0 = tau0),
    model_control = list(method = method), backend = "r",
    n_burn = 20L, n_mcmc = 80L, seed = seed)
  a <- make(101L)
  b <- make(102L, "categorical")
  expect_silent(autodesn_diagnostics(list(a, b)))
  changed <- make(103L, tau0 = .9)
  expect_error(autodesn_diagnostics(list(a, changed)), "same bank, prior and target")
  ridge <- autodesn_fit_bank(bank, n_burn = 20L, n_mcmc = 80L, seed = 104L)
  expect_error(autodesn_diagnostics(list(a, ridge)), "same bank, prior and target")
})

test_that("native and R implementations agree on Gaussian and local-scale targets", {
  x <- seq(-1, 1, length.out = 11)
  bank <- autodesn_prepare_bank(cos(x), list(cbind(x, x^2, x)))
  model <- bank$models[[1L]]
  lv <- log(c(10, .2, 1.1, .03))
  backend <- rhs_test_internal(".autodesn_rhs_backend")
  native <- try(backend("cpp", model, bank$y, .7, lv), silent = TRUE)
  if (inherits(native, "try-error")) skip("RHS native library is not loaded in this source-only run")
  reference <- rhs_test_internal(".autodesn_rhs_gaussian_R")(model, bank$y, .7, lv)
  compiled <- native$gaussian(model, bank$y, .7, lv)
  expect_equal(compiled$log_evidence, reference$log_evidence, tolerance = 1e-12)
  expect_equal(compiled$mean, reference$mean, tolerance = 1e-12)
  expect_equal(compiled$chol, reference$chol, tolerance = 1e-12)
  args <- list(log_local = log(c(.2, 1, 5)), log_aux = log(c(.7, 2, .4)),
               beta = c(.02, .5, -1), log_tau = log(.45), log_slab = log(2),
               max_attempts = 100000L)
  withr::local_seed(886)
  saved <- .Random.seed
  r <- do.call(rhs_test_internal(".autodesn_rhs_local_R"), args)
  rng_after <- .Random.seed
  assign(".Random.seed", saved, envir = .GlobalEnv)
  cpp <- do.call(native$local, args)
  expect_equal(cpp, r, tolerance = 1e-14)
  expect_identical(.Random.seed, rng_after)
  expect_equal(args$log_local, log(c(.2, 1, 5)))
  fixed <- list(learn_global = FALSE, initial_global = .7,
                learn_slab = FALSE, initial_slab = 2,
                fixed_local_scales = c(.5, 1, 2))
  run <- function(which) autodesn_fit_bank(bank, beta_prior = "rhs",
    rhs_control = fixed, n_burn = 10L, n_mcmc = 50L, seed = 899L, backend = which)
  r_fit <- run("r"); cpp_fit <- run("cpp")
  expect_equal(cpp_fit$draws, r_fit$draws, tolerance = 1e-10)
  expect_equal(cpp_fit$beta, r_fit$beta, tolerance = 1e-10)
  expect_identical(run("cpp")$draws, cpp_fit$draws)
})

test_that("RHS controls reject undefined scales, proposals, and ambiguous options", {
  bank <- autodesn_prepare_bank(seq(-1, 1, length.out = 8),
    list(matrix(1, 8, 1), matrix(1, 8, 3)))
  for (bad in list(list(tau0 = 0), list(slab_scale = NA_real_),
                  list(slab_df = -1), list(fixed_local_scales = c(1, Inf)),
                  list(learn_global = NA), list(unrecognized = 1))) {
    expect_error(autodesn_fit_bank(bank, beta_prior = "rhs", rhs_control = bad,
                                  n_burn = 0L, n_mcmc = 1L))
  }
  expect_error(autodesn_fit_bank(bank, beta_prior = "rhs",
    rhs_control = list(tau0 = 1:3)), "one value per model")
  expect_error(autodesn_fit_bank(bank, beta_prior = "rhs",
    rhs_control = list(fixed_local_scales = c(1, 2))), "largest slope count")
  expect_error(autodesn_fit_bank(bank, beta_prior = "rhs",
    model_control = list(proposal = c(1, 0))), "every model")
  expect_error(autodesn_fit_bank(bank, beta_prior = "rhs",
    model_control = list(initial_model = 3)), "outside the bank")
  expect_error(autodesn_fit_bank(bank, beta_prior = "rhs_ns"))
})

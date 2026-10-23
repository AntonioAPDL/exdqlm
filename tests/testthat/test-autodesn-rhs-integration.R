# Public-API contracts shared by the ridge and normalized RHS readouts.
# These small tests complement the independent posterior oracles in
# test-autodesn-rhs.R; they do not use long chains as an API test.

rhs_integration_internal <- function(name) {
  get(name, envir = environment(autodesn_fit_bank), inherits = TRUE)
}

rhs_integration_specs <- function() {
  list(shallow = list(D = 1L, n = 3L, m = 1L, alpha = .4, rho = .5,
                     pi_w = 1, pi_in = 1, washout = 2L, seed = 421L),
       deep = list(D = 2L, n = c(4L, 2L), n_tilde = 4L, m = 2L,
                   alpha = c(.3, .7), rho = c(.4, .7),
                   pi_w = 1, pi_in = 1, washout = 3L, seed = 429L))
}

rhs_integration_bank <- function() {
  x <- seq(-1, 1, length.out = 12)
  autodesn_prepare_bank(sin(2 * x) + .1 * cos(7 * x),
                       list(cbind(x), cbind(x, x^2)), model_prior = c(.4, .6))
}

test_that("the RHS series facade and direct bank fit share the same target and draws", {
  y <- sin(seq_len(38) / 4) + .03 * seq_len(38)
  specs <- rhs_integration_specs()
  bank <- autodesn_build_bank(y, specs, conditioning = 7L,
                             model_prior = c(.35, .65))
  rhs <- autodesn_rhs_control(tau0 = c(.4, .9), slab_scale = 1.6,
                             save_local = TRUE)
  model <- list(method = "mh", moves = 3L, proposal = c(.6, .4), rb_every = 3L)
  mcmc <- list(n_burn = 4L, n_mcmc = 18L, thin = 2L,
               intercept_variance = 10, a_sigma = 3, b_sigma = 1,
               initial_variance = .7, seed = 8501L)
  direct <- do.call(autodesn_fit_bank, c(list(bank = bank, beta_prior = "rhs",
    rhs_control = rhs, model_control = model, backend = "R"), mcmc))
  facade <- autodesn_fit(y, specs, conditioning = 7L, model_prior = c(.35, .65),
    beta_prior = "rhs", rhs_control = rhs, model_control = model, backend = "R",
    mcmc_args = mcmc)
  expect_identical(facade$draws, direct$draws)
  expect_identical(facade$beta, direct$beta)
  expect_identical(facade$local_log_scales, direct$local_log_scales)
  expect_identical(facade$controls$target, direct$controls$target)
  expect_identical(facade$model_summary, direct$model_summary)
  expect_null(facade$conditional_probabilities)
  expect_identical(facade$rb_iterations, facade$draws$iteration[c(3L, 6L, 9L)])
  expect_equal(rowSums(facade$rb_probabilities), rep(1, 3L))
})

test_that("RHS explicitly rejects ridge-only knobs and unsupported prior aliases", {
  bank <- rhs_integration_bank()
  legacy <- list(a_lambda = 2, b_lambda = 2, learn_ridge = TRUE, ridge_precision = 1)
  for (name in names(legacy)) {
    args <- c(list(bank = bank, beta_prior = "rhs", backend = "R",
                   n_burn = 0L, n_mcmc = 1L), legacy[name])
    expect_error(do.call(autodesn_fit_bank, args), "Ridge-specific controls")
    expect_error(autodesn_fit(sin(seq_len(25)), rhs_integration_specs()[1L],
      conditioning = 5L, beta_prior = "rhs", backend = "R",
      mcmc_args = c(list(n_burn = 0L, n_mcmc = 1L), legacy[name])),
      "Ridge-specific controls")
  }
  expect_error(autodesn_fit_bank(bank, beta_prior = "rhs_ns"), "arg.*one of")
  expect_error(autodesn_fit(sin(seq_len(25)), beta_prior = "rhs_ns"), "arg.*one of")
  expect_error(autodesn_fit_bank(bank, rhs_control = list(tau0 = 1)),
               "require beta_prior = 'rhs'")
  expect_error(autodesn_fit_bank(bank, model_control = list(method = "mh")),
               "require beta_prior = 'rhs'")
})

test_that("RHS and facade controls require unique nonempty names and reject unknowns", {
  bank <- rhs_integration_bank()
  fit <- function(...) autodesn_fit_bank(bank, beta_prior = "rhs", backend = "R",
                                        n_burn = 0L, n_mcmc = 1L, ...)
  expect_error(autodesn_rhs_control(tau_typo = 1), "Unknown RHS control")
  expect_error(fit(rhs_control = list(tau_typo = 1)), "Unknown RHS control")
  expect_error(fit(model_control = list(move_typo = 1)), "Unknown model_control")
  bad_rhs <- list(list(1), list(tau0 = 1, 2), list(tau0 = 1, tau0 = 2), 1)
  bad_model <- list(list("mh"), list(method = "mh", 2),
                    list(moves = 1L, moves = 2L), 1)
  for (control in bad_rhs) expect_error(fit(rhs_control = control),
    "rhs_control must be a list with unique nonempty argument names")
  for (control in bad_model) expect_error(fit(model_control = control),
    "model_control must be a list with unique nonempty argument names")
  expect_error(fit(rhs_control = list(tau0 = c(1, 2, 3))), "scalar or have one value per model")
  expect_error(fit(model_control = list(proposal = c(1, 0))), "positive finite mass on every model")

  y <- sin(seq_len(25))
  for (control in list(list(1), list(n_burn = 1L, 2L),
                        list(n_burn = 1L, n_burn = 2L), 1)) {
    expect_error(autodesn_fit(y, mcmc_args = control), "mcmc_args must be a uniquely named list")
  }
  expect_error(autodesn_fit(y, mcmc_args = list(bank = bank)), "cannot override bank")
  for (name in c("beta_prior", "rhs_control", "model_control", "backend")) {
    expect_error(autodesn_fit(y, mcmc_args = stats::setNames(list(1), name)),
                 "top-level arguments")
  }
  expect_error(autodesn_fit(y, rhs_integration_specs()[1L], conditioning = 5L,
    beta_prior = "rhs", backend = "R", mcmc_args = list(unknown_mcmc_control = 1)),
    "unused argument")
})

test_that("R and r aliases select the same RHS backend without changing the chain", {
  bank <- rhs_integration_bank()
  fit <- function(backend) autodesn_fit_bank(bank, beta_prior = "rhs", backend = backend,
    n_burn = 3L, n_mcmc = 12L, seed = 8520L)
  upper <- fit("R")
  lower <- fit("r")
  expect_identical(upper$draws, lower$draws)
  expect_identical(upper$beta, lower$beta)
  expect_identical(upper$controls$backend, "r")
  expect_error(fit("unavailable_backend"), "arg.*one of")

  args <- list(y = sin(seq_len(28) / 4), candidates = rhs_integration_specs()[1L],
    conditioning = 5L, beta_prior = "rhs",
    mcmc_args = list(n_burn = 2L, n_mcmc = 8L, seed = 8521L))
  a <- do.call(autodesn_fit, c(args, list(backend = "R")))
  b <- do.call(autodesn_fit, c(args, list(backend = "r")))
  expect_identical(a$draws, b$draws)
  expect_identical(a$beta, b$beta)
})

test_that("an explicitly requested unloaded native backend fails while auto uses R", {
  bank <- rhs_integration_bank()
  model <- bank$models[[1L]]
  native <- try(rhs_integration_internal(".autodesn_rhs_backend")(
    "cpp", model, bank$y, 1, log(c(10, rep(.8, model$d)))), silent = TRUE)
  if (!inherits(native, "try-error")) skip("Native library is loaded; unavailable-DLL contract is covered in source-only runs")
  args <- list(bank = bank, beta_prior = "rhs", n_burn = 2L, n_mcmc = 8L, seed = 8522L)
  expect_error(do.call(autodesn_fit_bank, c(args, list(backend = "cpp"))),
               "requested RHS C\\+\\+ backend is not loaded")
  automatic <- do.call(autodesn_fit_bank, c(args, list(backend = "auto")))
  reference <- do.call(autodesn_fit_bank, c(args, list(backend = "R")))
  expect_identical(automatic$draws, reference$draws)
  expect_identical(automatic$beta, reference$beta)
  expect_identical(automatic$controls$backend, "r")
})

test_that("the default and explicit ridge prior have identical historical draws", {
  bank <- rhs_integration_bank()
  args <- list(bank = bank, n_burn = 5L, n_mcmc = 20L, thin = 2L,
    a_lambda = 2, b_lambda = 2, ridge_precision = 1.3, seed = 8530L)
  implicit <- do.call(autodesn_fit_bank, args)
  explicit <- do.call(autodesn_fit_bank, c(args, list(beta_prior = "ridge")))
  expect_identical(implicit, explicit)
  reference <- do.call(autodesn_fit_bank, c(args, list(beta_prior = "ridge", backend = "r")))
  expect_identical(implicit, reference)
  expect_identical(implicit$meta$beta_prior_type, "independent_ridge")
  expect_identical(implicit$meta$inference_method, "blocked_gibbs")
})

test_that("RHS fitted means and predictive draws retain their joint posterior alignment", {
  y <- sin(seq_len(38) / 4) + .02 * seq_len(38)
  fit <- autodesn_fit(y, rhs_integration_specs(), conditioning = 7L,
    beta_prior = "rhs", backend = "R",
    mcmc_args = list(n_burn = 5L, n_mcmc = 24L, seed = 8540L))
  bank <- fit$bank
  original_scale <- function(x) bank$preprocessing$center + bank$preprocessing$scale * x
  expected <- vapply(seq_len(nrow(fit$draws)), function(k)
    as.vector(bank$models[[fit$draws$model[k]]]$X %*% fit$beta[[k]]), numeric(bank$n))
  expect_equal(predict_mu.autodesn_fit(fit), original_scale(rowMeans(expected)),
               tolerance = 1e-12)
  withr::local_seed(8541L)
  before <- .Random.seed
  pp <- posterior_predict.autodesn_fit(fit, nd = 9L, seed = 8542L)
  expect_identical(.Random.seed, before)
  set.seed(8542L)
  ids <- sample.int(nrow(fit$draws), 9L, replace = TRUE)
  eps <- matrix(stats::rnorm(bank$n * 9L), bank$n, 9L)
  expected_mu <- expected[, ids, drop = FALSE]
  expected_y <- expected_mu + sweep(eps, 2L, sqrt(fit$draws$variance[ids]), `*`)
  expect_identical(pp$draw_index, ids)
  expect_identical(pp$model, fit$draws$model[ids])
  expect_equal(pp$mu_draws, original_scale(expected_mu), tolerance = 1e-12)
  expect_equal(pp$yrep, original_scale(expected_y), tolerance = 1e-12)
  expect_true(all(is.finite(pp$yrep)))
  expect_output(print(fit), "independent_rhs readout; collapsed_mh")

  fc <- forecast_paths.autodesn_fit(fit, H = 3L, draw_index = c(2L, 8L),
    inner_paths = 2L, innovations = matrix(seq(-1, 1, length.out = 12), 3, 4))
  expect_identical(fc$beta_prior_type, "independent_rhs")
  expect_identical(fc$forecast_family, "normal_recursive_autodesn")
  expect_identical(fc$target, "conditional_mean")
  expect_identical(fc$recursion_mode, "posterior_predictive")
  expect_identical(fc$draw_index, c(2L, 2L, 8L, 8L))
  expect_identical(fc$model, fit$draws$model[fc$draw_index])
  expect_identical(dim(fc$yrep), c(3L, 4L))
  expect_true(all(is.finite(fc$yrep)))
  plugin <- forecast_paths.autodesn_fit(fit, H = 2L, draw_index = 2L,
    recursion_mode = "conditional_mean_plugin")
  expect_identical(plugin$beta_prior_type, "independent_rhs")
  expect_identical(plugin$recursion_mode, "conditional_mean_plugin")
  expect_equal(plugin$yrep, plugin$mu_draws, tolerance = 1e-13)
})

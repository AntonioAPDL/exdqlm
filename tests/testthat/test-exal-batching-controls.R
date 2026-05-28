test_that("stochastic chunking controls normalize without changing exact controls", {
  exact <- exdqlm::exal_make_vb_control(
    chunking = list(
      enabled = TRUE,
      mode = "exact",
      chunk_size = 128L,
      order = "sequential",
      trace = TRUE
    )
  )$chunking

  expect_identical(names(exact), c("enabled", "mode", "chunk_size", "order", "trace"))
  expect_true(isTRUE(exact$enabled))
  expect_identical(exact$mode, "exact")
  expect_equal(exact$chunk_size, 128L)
  expect_identical(exact$order, "sequential")
  expect_true(isTRUE(exact$trace))

  stoch <- exdqlm::exal_make_vb_control(
    chunking = list(
      enabled = TRUE,
      mode = "stochastic",
      chunk_size = 7L,
      order = "random",
      seed = 20260527L,
      learning_rate = list(t0 = 5, kappa = 0.8, rho_min = 0.02),
      refresh = list(full_every = 11L, sigma_every = 3L, rhs_every = 5L),
      diagnostics = list(trace = TRUE, store_batch_ids = TRUE, check_finite_every = 2L)
    )
  )$chunking

  expect_true(isTRUE(stoch$enabled))
  expect_identical(stoch$mode, "stochastic")
  expect_equal(stoch$chunk_size, 7L)
  expect_identical(stoch$order, "random")
  expect_equal(stoch$seed, 20260527L)
  expect_identical(stoch$learning_rate$schedule, "robbins_monro")
  expect_equal(stoch$learning_rate$t0, 5)
  expect_equal(stoch$learning_rate$kappa, 0.8)
  expect_equal(stoch$learning_rate$rho_min, 0.02)
  expect_equal(stoch$refresh$full_every, 11L)
  expect_equal(stoch$refresh$sigma_every, 3L)
  expect_equal(stoch$refresh$rhs_every, 5L)
  expect_equal(stoch$refresh$objective_every, 20L)
  expect_true(isTRUE(stoch$diagnostics$trace))
  expect_true(isTRUE(stoch$diagnostics$store_batch_ids))
  expect_equal(stoch$diagnostics$check_finite_every, 2L)

  expect_false("chunking" %in% names(exdqlm::exal_make_vb_control()))
})

test_that("stochastic chunking controls fail early for invalid values", {
  expect_error(
    exdqlm::exal_make_vb_control(chunking = list(enabled = TRUE, mode = "hybrid")),
    "must be 'exact' or 'stochastic'"
  )
  expect_error(
    exdqlm::exal_make_vb_control(chunking = list(enabled = TRUE, mode = "exact", order = "random")),
    "sequential"
  )
  expect_error(
    exdqlm::exal_make_vb_control(chunking = list(enabled = TRUE, mode = "stochastic", order = "bad")),
    "random.*shuffled.*sequential"
  )
  expect_error(
    exdqlm::exal_make_vb_control(chunking = list(
      enabled = TRUE,
      mode = "stochastic",
      learning_rate = list(kappa = 0.5)
    )),
    "kappa"
  )
  expect_error(
    exdqlm::exal_make_vb_control(chunking = list(
      enabled = TRUE,
      mode = "stochastic",
      refresh = list(rhs_every = 0L)
    )),
    "rhs_every"
  )
})

test_that("batch sampler is reproducible and validates inputs", {
  a <- exdqlm:::.exal_batch_sampler_init(10L, chunk_size = 4L, order = "random", seed = 99L)
  b <- exdqlm:::.exal_batch_sampler_init(10L, chunk_size = 4L, order = "random", seed = 99L)
  a1 <- exdqlm:::.exal_batch_sampler_next(a)
  b1 <- exdqlm:::.exal_batch_sampler_next(b)
  expect_equal(a1$idx, b1$idx)
  a2 <- exdqlm:::.exal_batch_sampler_next(a1$state)
  b2 <- exdqlm:::.exal_batch_sampler_next(b1$state)
  expect_equal(a2$idx, b2$idx)
  expect_false(identical(a1$idx, a2$idx))

  seq_state <- exdqlm:::.exal_batch_sampler_init(5L, chunk_size = 2L, order = "sequential")
  s1 <- exdqlm:::.exal_batch_sampler_next(seq_state)
  s2 <- exdqlm:::.exal_batch_sampler_next(s1$state)
  s3 <- exdqlm:::.exal_batch_sampler_next(s2$state)
  s4 <- exdqlm:::.exal_batch_sampler_next(s3$state)
  expect_equal(s1$idx, 1:2)
  expect_equal(s2$idx, 3:4)
  expect_equal(s3$idx, 5L)
  expect_equal(s4$idx, 1:2)
  expect_equal(s4$epoch, 2L)

  expect_error(exdqlm:::.exal_batch_sampler_init(0L), "positive integer")
  expect_error(exdqlm:::.exal_batch_sampler_init(5L, chunk_size = 0L), "positive integer")
})

test_that("learning rate follows Robbins-Monro schedule", {
  cfg <- list(schedule = "robbins_monro", t0 = 10, kappa = 0.75, rho_min = 0.01)
  rho <- vapply(1:20, exdqlm:::.exal_learning_rate, numeric(1), learning_rate = cfg)
  expect_true(all(is.finite(rho)))
  expect_true(all(diff(rho) <= 1e-15))
  expect_true(all(rho >= 0.01))
  expect_equal(rho[[1L]], max(0.01, 11^(-0.75)), tolerance = 1e-14)

  cfg_floor <- list(schedule = "robbins_monro", t0 = 1, kappa = 1, rho_min = 0.25)
  expect_equal(exdqlm:::.exal_learning_rate(100L, cfg_floor), 0.25)
  expect_error(exdqlm:::.exal_learning_rate(1L, list(kappa = 0.25)), "kappa")
  expect_error(exdqlm:::.exal_learning_rate(0L, cfg), "positive integer")
})

test_that("stochastic beta stats scale only data natural statistics", {
  set.seed(20260527)
  X <- cbind(1, seq(-1, 1, length.out = 8), cos(seq_len(8)))
  beta <- c(0.2, -0.1, 0.05)
  y <- as.numeric(X %*% beta + stats::rnorm(8, sd = 0.1))
  xis <- list(xi1 = 1.3, xi_lambda = 0.2, xi_A = -0.1)
  qv_inv <- seq(0.8, 1.2, length.out = 8)
  qs_m <- seq(0.5, 0.9, length.out = 8)
  idx <- c(2L, 4L, 7L, 8L)

  batch <- exdqlm:::.exal_stochastic_beta_stats(X, y, xis, qv_inv, qs_m, idx)
  raw <- exdqlm:::.exal_beta_data_stats(X[idx, , drop = FALSE], y[idx], xis, qv_inv[idx], qs_m[idx])
  scale <- nrow(X) / length(idx)

  expect_equal(batch$scale, scale)
  expect_equal(batch$S, scale * raw$S, tolerance = 1e-12)
  expect_equal(batch$g, scale * raw$g, tolerance = 1e-12)
  expect_error(exdqlm:::.exal_stochastic_beta_stats(X, y, xis, qv_inv, qs_m, integer(0)), "non-empty")
})

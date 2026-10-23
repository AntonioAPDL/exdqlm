source("validation/autodesn/rhs_comparison/helpers.R")
testthat::test_that("fork progress requires actual saved result checkpoints", {
  d<-tempfile();dir.create(d);p<-file.path(d,c("one.rds","two.rds"));writeLines("saved",p[1])
  testthat::expect_silent(rhs_require_checkpoints(list(NULL),p[1],"test"))
  testthat::expect_error(rhs_require_checkpoints(list(NULL,NULL),p,"test"),"did not save every")
  testthat::expect_error(rhs_require_checkpoints(list(structure("failed",class="try-error")),p[1],"test"),"worker returned an error")
  writeLines("saved",p[2]);testthat::expect_silent(rhs_require_checkpoints(list(NULL,NULL),p,"test"))
})
source("validation/autodesn/rhs_comparison/runner.R")
library(testthat)

test_that("frozen full protocol and common innovations match the original C1", {
  cfg <- rhs_configuration(rhs_options(character())); old <- c1_config()
  fields <- c("washout", "fit_start", "fit_end", "n_train", "test_start", "test_end", "n_test",
              "first_origin", "last_origin", "origins", "H", "outer_draws", "inner_paths", "checkpoint_draws")
  expect_equal(cfg[fields], old[fields])
  expect_equal(cfg$innovation_seed, old$desn_seed)
  a <- c1_noise(cfg$innovation_seed, 2500L, 4L, 192L, 30L)
  b <- c1_noise(cfg$innovation_seed, 2500L, 8L, 384L, 30L)
  cols <- as.vector(outer(seq_len(4L), (seq_len(192L) - 1L) * 8L, "+"))
  expect_identical(a, b[, cols, drop = FALSE])
})

test_that("gates require three chains, finite sampled diagnostics and model agreement", {
  cfg <- rhs_configuration(rhs_options(character()))
  dg <- list(chains = 3L, parameters = data.frame(rhat = 1, ess_spectral = 401, sampled = TRUE),
             models = data.frame(chain_range = .01))
  expect_true(rhs_diagnostic_gate(dg, cfg))
  bad <- dg; bad$chains <- 2L; expect_false(rhs_diagnostic_gate(bad, cfg))
  bad <- dg; bad$parameters$rhat <- NA_real_; expect_false(rhs_diagnostic_gate(bad, cfg))
  bad <- dg; bad$parameters$ess_spectral <- 399; expect_false(rhs_diagnostic_gate(bad, cfg))
  bad <- dg; bad$models$chain_range <- .051; expect_false(rhs_diagnostic_gate(bad, cfg))
  dg$parameters <- rbind(dg$parameters, data.frame(rhat = NA_real_, ess_spectral = NA_real_, sampled = FALSE))
  expect_true(rhs_diagnostic_gate(dg, cfg))
})

test_that("both priors preserve paired draws, causal state timing and production recursion", {
  set.seed(72); y <- rnorm(180)
  specs <- autodesn_candidates(D = 1:2, n = 5, m = 3, alpha = .6, rho = .4,
    seed = 11, washout = 30, act_k = "identity")
  specs <- lapply(specs, function(x) {x$n_tilde <- x$n[seq_len(x$D - 1L)]; x})
  bank <- autodesn_build_bank(y[1:150], specs, conditioning = 30, washout = 30)
  for (prior in c("ridge", "rhs")) {
    fit <- autodesn_fit_bank(bank, beta_prior = prior, n_burn = 10, n_mcmc = 50, seed = 5, backend = "R")
    cp <- c1_compact(fit, 1:20, list())
    states <- hr_origin_states(cp, y, 150:160)
    full <- autodesn_build_bank(y[1:160], specs, conditioning = 30, washout = 30)
    for (j in unique(cp$draws$model)) expect_equal(states$states[[11]][[j]],
      c1_lean_template(full$templates[[j]])$states$H_last, tolerance = 1e-11)
    noise <- matrix(rnorm(3 * 20 * 2), 3)
    fc <- hr_auto(cp, states$states[[1]], states$history_scaled[1:150], 3, 2, noise)
    direct <- forecast_paths.autodesn_fit(fit, 3, draw_index = 1:20,
      inner_paths = 2, innovations = noise, backend = "batched")
    expect_equal(fc$yrep, direct$yrep, tolerance = 1e-12)
    expect_equal(fc$yrep, fc$mu_draws + fc$sd_draws * noise, tolerance = 1e-12)
    changed <- y; changed[151:180] <- 1e6
    altered <- hr_origin_states(cp, changed, 150:160)
    future_changed <- hr_auto(cp, altered$states[[1]], altered$history_scaled[1:150], 3, 2, noise)
    expect_identical(fc$yrep, future_changed$yrep)
    score <- c1_desn_score(fc, y[151:153], 150L)
    expect_identical(score$target, 151:153)
    expect_equal(score$actual, y[151:153]); expect_true(all(score$target > score$origin))
    cfg <- list(checkpoint_draws = 12L)
    pooled <- rhs_compact(list(fit, fit, fit), bank, list(models = fit$model_summary), cfg, 91L)
    for (i in seq_len(nrow(pooled$draws))) {
      expect_identical(pooled$beta[[i]], fit$beta[[pooled$source_chain_row[i]]])
      expect_equal(pooled$draws$variance[i], fit$draws$variance[pooled$source_chain_row[i]])
    }
  }
})
cat("RHS COMPARISON R CONTRACTS PASSED\n")

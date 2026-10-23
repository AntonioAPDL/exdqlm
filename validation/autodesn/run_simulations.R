source("validation/autodesn/load_checkout.R")
out <- Sys.getenv("AUTODESN_OUT", "validation/autodesn/artifacts")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
write.csv(.autodesn_source_manifest, file.path(out, "simulation_source_manifest.csv"), row.names = FALSE)
repetitions <- as.integer(Sys.getenv("AUTODESN_REPS", "6"))
stopifnot(is.finite(repetitions), repetitions >= 1L)
origins <- c(180L, 240L)
H <- 12L
nd <- 1000L
specs <- autodesn_candidates(D = c(1L, 2L), n = c(8L, 12L), m = c(1L, 4L, 12L),
                             alpha = 0.5, rho = c(0.4, 0.85), seed = c(11L, 29L),
                             washout = 20L, pi_w = 0.3, pi_in = 0.7,
                             win_scale_global = 0.5)
fixed_spec <- list(fixed_shallow = list(D = 1L, n = 12L, m = 12L, alpha = 0.5,
                     rho = 0.85, seed = 11L, washout = 20L, pi_w = 0.3,
                     pi_in = 0.7, win_scale_global = 0.5))
configuration <- list(repetitions = repetitions, origins = origins, H = H, nd = nd,
  conditioning = 30L, candidates = specs, fixed_candidate = fixed_spec,
  n_burn = 1000L, n_mcmc = 2500L, chains = 2L,
  scope = "Implementation validation; no hyperparameter tuning on future outcomes.")
dput(configuration, file = file.path(out, "configuration.R"))

simulate <- function(kind, n, seed) {
  .autodesn_seed(seed, function() {
    burn <- 300L
    y <- numeric(n + burn)
    eps <- stats::rnorm(length(y), sd = 0.35)
    for (t in 13:length(y)) {
      y[t] <- switch(kind,
        linear = 0.7 * y[t - 1L] + eps[t],
        nonlinear = 0.35 * y[t - 1L] + 0.65 * sin(1.8 * y[t - 2L]) + eps[t],
        seasonal = 0.25 * y[t - 1L] + 0.6 * y[t - 12L] + eps[t])
    }
    utils::tail(y, n)
  })
}

pool_chains <- function(fits) {
  fit <- fits[[1L]]
  fit$draws <- do.call(rbind, lapply(fits, `[[`, "draws"))
  fit$beta <- unlist(lapply(fits, `[[`, "beta"), recursive = FALSE)
  fit$conditional_probabilities <- do.call(rbind, lapply(fits, `[[`, "conditional_probabilities"))
  fit$model_summary$posterior_probability <- colMeans(fit$conditional_probabilities)
  fit$model_summary$occupancy <- tabulate(fit$draws$model, nbins = length(fit$bank$models)) / nrow(fit$draws)
  fit
}

# Fixed-lag Gaussian AR uses the existing exact scaled-ridge backend and retains
# one posterior coefficient/variance draw per path, including feedback noise.
forecast_ar <- function(bank, p, seed) {
  z <- bank$history_scaled
  rows <- bank$keep_idx
  X <- cbind(1, vapply(seq_len(p), function(l) z[rows - l], numeric(length(rows))))
  readout <- normal_desn_fit(X, z[rows], prior = list(tau2 = 1, intercept_var = 10),
                             omega_prior = list(a = 3, b = 1))
  .autodesn_seed(seed, function() {
    draws <- normal_desn_posterior_draws(readout, nd = nd)
    paths <- matrix(NA_real_, H, nd)
    for (k in seq_len(nd)) {
      history <- z
      for (h in seq_len(H)) {
        mu <- sum(c(1, rev(utils::tail(history, p))) * draws$beta[k, ])
        paths[h, k] <- mu + stats::rnorm(1L, sd = sqrt(draws$omega2[k]))
        history <- c(history, paths[h, k])
      }
    }
    .autodesn_unscale(bank, paths)
  })
}

score_paths <- function(paths, actual, train) {
  stopifnot(identical(dim(paths), c(H, nd)), all(is.finite(paths)))
  point <- rowMeans(paths)
  qs <- t(apply(paths, 1L, stats::quantile, probs = c(0.05, 0.5, 0.95)))
  # Empirical predictive CRPS: E|X-y| - E|X-X'|/2, exact for the sample CDF.
  crps <- vapply(seq_len(H), function(h) {
    x <- sort(paths[h, ])
    mean(abs(x - actual[h])) - sum((2 * seq_len(nd) - nd - 1) * x) / nd^2
  }, numeric(1))
  scale <- mean(abs(diff(train)))
  data.frame(horizon = seq_len(H), actual = actual, mean = point,
    lower90 = qs[, 1L], median = qs[, 2L], upper90 = qs[, 3L],
    squared_error = (point - actual)^2, absolute_error = abs(point - actual),
    crps = crps, covered90 = actual >= qs[, 1L] & actual <= qs[, 3L],
    width90 = qs[, 3L] - qs[, 1L], naive_scale = scale,
    scaled_crps = crps / scale)
}

scores <- probability <- diagnostic <- observed <- list()
started <- proc.time()[[3L]]
counter <- 0L
for (kind in c("linear", "nonlinear", "seasonal")) for (r in seq_len(repetitions)) {
  dgp_seed <- 70000L + match(kind, c("linear", "nonlinear", "seasonal")) * 1000L + r
  y <- simulate(kind, max(origins) + H, dgp_seed)
  observed[[length(observed) + 1L]] <- data.frame(dgp = kind, repetition = r, time = seq_along(y), y = y)
  for (origin in origins) {
    counter <- counter + 1L
    cat(sprintf("%s repetition %d origin %d [%d/%d]\n", kind, r, origin, counter,
                 3L * repetitions * length(origins)))
    flush.console()
    train <- y[seq_len(origin)]
    bank <- autodesn_build_bank(train, specs, conditioning = configuration$conditioning)
    fits <- lapply(1:2, function(k) autodesn_fit_bank(bank, n_burn = configuration$n_burn,
      n_mcmc = configuration$n_mcmc, initial_variance = c(0.2, 2)[k],
      ridge_precision = c(0.3, 3)[k], seed = dgp_seed + origin * 10L + k))
    dg <- autodesn_diagnostics(fits)
    diagnostic[[length(diagnostic) + 1L]] <- cbind(dgp = kind, repetition = r, origin = origin,
       dg$parameters, max_model_chain_range = max(dg$models$chain_range))
    pooled <- pool_chains(fits)
    probability[[length(probability) + 1L]] <- cbind(dgp = kind, repetition = r, origin = origin,
                                                     dg$models)
    auto <- forecast_paths.autodesn_fit(pooled, H, nd, seed = dgp_seed + origin + 400L)$yrep
    # Same likelihood, independent ridge prior, common score rows and preprocessing.
    # The fixed specification is chosen before simulating any future outcomes.
    fixed_bank <- autodesn_build_bank(train, fixed_spec, conditioning = configuration$conditioning)
    stopifnot(identical(bank$keep_idx, fixed_bank$keep_idx))
    fixed <- autodesn_fit_bank(fixed_bank, n_burn = 1000L, n_mcmc = 2500L,
                               seed = dgp_seed + origin + 800L)
    fixed_fc <- forecast_paths.autodesn_fit(fixed, H, nd, seed = dgp_seed + origin + 900L)$yrep
    ar1 <- forecast_ar(bank, 1L, dgp_seed + origin + 1000L)
    ar12 <- forecast_ar(bank, 12L, dgp_seed + origin + 1100L)
    candidates <- list(AutoDESN = auto, Fixed_DESN = fixed_fc, Gaussian_AR1 = ar1, Gaussian_AR12 = ar12)
    for (method in names(candidates)) {
      score <- score_paths(candidates[[method]], y[origin + seq_len(H)], train)
      scores[[length(scores) + 1L]] <- cbind(dgp = kind, repetition = r, origin = origin, method = method, score)
    }
    # Incremental checkpoint: scores and diagnostics survive an interrupted run.
    write.csv(do.call(rbind, scores), file.path(out, "scores.csv"), row.names = FALSE)
    write.csv(do.call(rbind, probability), file.path(out, "model_probabilities.csv"), row.names = FALSE)
    write.csv(do.call(rbind, diagnostic), file.path(out, "diagnostics.csv"), row.names = FALSE)
    write.csv(do.call(rbind, observed), file.path(out, "observed.csv"), row.names = FALSE)
  }
}
all_scores <- do.call(rbind, scores)
aggregated <- stats::aggregate(cbind(squared_error, absolute_error, crps, covered90, width90, scaled_crps) ~ dgp + method,
                               data = all_scores, FUN = mean)
aggregated$rmse <- sqrt(aggregated$squared_error)
write.csv(aggregated, file.path(out, "summary.csv"), row.names = FALSE)
writeLines(c(sprintf("Elapsed seconds: %.3f", proc.time()[[3L]] - started),
              sprintf("Independent series per DGP: %d; origins per series: %d; horizons: %d", repetitions, length(origins), H),
              "Origins and horizons within a series are dependent; do not use them as independent replicates.",
              "Two chains pooled for AutoDESN after checking diagnostic screens. Fixed DESN uses one chain.",
              "No forced pass criterion for predictive superiority or realized interval coverage.",
              R.version.string, paste("Revision at launch:", .autodesn_checkout_revision),
              capture.output(sessionInfo())), file.path(out, "session.txt"))
print(aggregated, row.names = FALSE)

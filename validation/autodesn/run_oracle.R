source("validation/autodesn/load_checkout.R")
out <- Sys.getenv("AUTODESN_OUT", "validation/autodesn/artifacts")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
write.csv(.autodesn_source_manifest, file.path(out, "oracle_source_manifest.csv"), row.names = FALSE)
set.seed(20261021)
n <- 18L
t <- seq_len(n)
H1 <- matrix(sin(t / 2.3), ncol = 1L)
H2 <- cbind(sin(t / 2.3), cos(t / 3.1))
y <- 0.1 + 0.2 * H1[, 1] + 0.25 * H2[, 2] + stats::rnorm(n, sd = 0.8)
bank <- autodesn_prepare_bank(y, list(H1, H2), model_prior = c(0.55, 0.45))

# Independent oracle: dense observation covariance Cholesky at every point.
# Integrate on log variance / log precision scales with both Jacobians.
dense_oracle <- function(N, variance_bounds = c(-8, 3), ridge_bounds = c(-8, 7)) {
  lv <- seq(variance_bounds[1L], variance_bounds[2L], length.out = N)
  ll <- seq(ridge_bounds[1L], ridge_bounds[2L], length.out = N)
  grid <- expand.grid(lv = lv, ll = ll)
  edge <- rep(1, N)
  edge[c(1L, N)] <- 0.5
  log_edge <- log(as.vector(outer(edge, edge)))
  L <- matrix(NA_real_, nrow(grid), length(bank$models))
  means <- matrix(NA_real_, nrow(grid), length(bank$models))
  for (j in seq_along(bank$models)) {
    X <- bank$models[[j]]$X
    for (i in seq_len(nrow(grid))) {
      v <- exp(grid$lv[i])
      lambda <- exp(grid$ll[i])
      B <- diag(c(10, rep(1 / lambda, ncol(X) - 1L)), ncol(X))
      C <- v * diag(n) + X %*% B %*% t(X)
      R <- chol(C)
      q <- forwardsolve(t(R), y)
      ld <- 2 * sum(log(diag(R)))
      # IG(v)*v and Gamma(lambda)*lambda are densities in log coordinates.
      lp <- -lgamma(3) - 3 * log(v) - 1 / v +
        2 * log(2) - lgamma(2) + 2 * log(lambda) - 2 * lambda
      L[i, j] <- log(bank$prior[j]) - 0.5 * (n * log(2 * pi) + ld + sum(q^2)) + lp + log_edge[i]
      means[i, j] <- as.numeric((B %*% crossprod(X, backsolve(R, q)))[1L])
    }
  }
  W <- exp(L - max(L))
  W <- W / sum(W)
  c(p_model_1 = sum(W[, 1L]), variance = sum(rowSums(W) * exp(grid$lv)),
    ridge_precision = sum(rowSums(W) * exp(grid$ll)), intercept = sum(W * means))
}
coarse <- dense_oracle(81L)
oracle <- dense_oracle(121L)
expanded <- dense_oracle(161L, c(-10, 4), c(-10, 8))
stopifnot(max(abs(coarse - oracle)) < 5e-4, max(abs(expanded - oracle)) < 5e-4)
fits <- lapply(seq_along(c(101L, 507L, 901L)), function(k) {
  autodesn_fit_bank(bank, n_burn = 1500L, n_mcmc = 5500L,
                    initial_variance = c(0.2, 0.8, 2)[k],
                    ridge_precision = c(0.3, 1, 4)[k], seed = c(101L, 507L, 901L)[k])
})
series <- list(p_model_1 = lapply(fits, function(f) f$conditional_probabilities[, 1L]),
               variance = lapply(fits, function(f) f$draws$variance),
               ridge_precision = lapply(fits, function(f) f$draws$ridge_precision),
               intercept = lapply(fits, function(f) vapply(f$beta, `[`, numeric(1), 1L)))
check <- do.call(rbind, lapply(names(series), function(nm) {
  z <- series[[nm]]
  estimate <- mean(vapply(z, mean, numeric(1)))
  mcse <- .autodesn_batch_mcse(z)
  tolerance <- max(0.025, 5 * mcse)
  data.frame(quantity = nm, oracle = oracle[nm], gibbs = estimate,
              mcse = mcse, tolerance = tolerance,
              pass = abs(estimate - oracle[nm]) < tolerance, row.names = NULL)
}))
write.csv(check, file.path(out, "oracle.csv"), row.names = FALSE)
d <- autodesn_diagnostics(fits)
write.csv(d$parameters, file.path(out, "oracle_diagnostics.csv"), row.names = FALSE)
writeLines(c(sprintf("Dense quadrature 81 to 121 refinement difference: %.10g", max(abs(coarse - oracle))),
             sprintf("Expanded-bound difference: %.10g", max(abs(expanded - oracle))),
             "Integration bounds: log variance [-8,3], log precision [-8,7]; expanded to [-10,4],[-10,8].",
             "No SVD score is used by the quadrature oracle.", R.version.string), file.path(out, "oracle_notes.txt"))
print(check, row.names = FALSE)
print(d$parameters, row.names = FALSE)
stopifnot(all(check$pass))

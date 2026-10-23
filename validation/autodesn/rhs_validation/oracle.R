# Independent numerical references for Gaussian AutoDESN with the normalized
# Piironen--Vehtari regularized horseshoe.  Only base/recommended R is used.
#
# These references integrate the likelihood in observation space.  They do not
# call AutoDESN's Gram-matrix, Cholesky, scale-target, or MCMC implementations.
# Source this file after loading exdqlm to run the associated validation driver.

rhs_oracle_legendre <- function(order = 64L) {
  stopifnot(length(order) == 1L, order >= 2L, order == as.integer(order))
  j <- seq_len(order - 1L)
  off <- j / sqrt(4 * j * j - 1)
  jacobi <- matrix(0, order, order)
  jacobi[cbind(j, j + 1L)] <- off
  jacobi[cbind(j + 1L, j)] <- off
  eig <- eigen(jacobi, symmetric = TRUE)
  keep <- order(eig$values)
  # Mapping [-1, 1] to [0, 1] cancels the factor two in the weights.
  list(u = (eig$values[keep] + 1) / 2,
       w = eig$vectors[1L, keep]^2)
}

rhs_oracle_logsumexp <- function(x) {
  top <- max(x)
  if (!is.finite(top)) return(top)
  top + log(sum(exp(x - top)))
}

rhs_oracle_log_mvn <- function(y, covariance) {
  lower <- t(chol(covariance))
  -0.5 * (length(y) * log(2 * pi) +
          2 * sum(log(diag(lower))) +
          sum(forwardsolve(lower, y)^2))
}

rhs_oracle_variance <- function(local, global, slab, tau0 = 1) {
  # slab is c^2, global is the standardized half-Cauchy u.
  1 / (1 / slab + 1 / ((tau0 * global * local)^2))
}

rhs_oracle_gaussian <- function(y, X, variance, slope_variance,
                               intercept_variance = 10) {
  D <- diag(c(intercept_variance, slope_variance), ncol(X))
  covariance <- variance * diag(length(y)) + X %*% D %*% t(X)
  inv_cov_y <- solve(covariance, y)
  mean <- as.vector(D %*% crossprod(X, inv_cov_y))
  beta_cov <- D - D %*% crossprod(X, solve(covariance, X)) %*% D
  list(log_evidence = rhs_oracle_log_mvn(y, covariance),
       mean = mean, covariance = (beta_cov + t(beta_cov)) / 2)
}

rhs_oracle_fixed_scales <- function(bank, local = 1, global = 1, slab = 4,
                                    tau0 = 1, a_sigma = 3, b_sigma = 1,
                                    intercept_variance = 10, order = 96L) {
  quad <- rhs_oracle_legendre(order)
  M <- length(bank$models)
  dmax <- max(vapply(bank$models, function(m) m$d, integer(1)))
  local <- rep_len(local, dmax)
  tau0 <- rep_len(tau0, M)
  sigma2 <- b_sigma / stats::qgamma(quad$u, shape = a_sigma)
  details <- lapply(seq_len(M), function(m) {
    model <- bank$models[[m]]
    v <- rhs_oracle_variance(local[seq_len(model$d)], global, slab, tau0[m])
    values <- lapply(sigma2, function(s2) {
      rhs_oracle_gaussian(bank$y, model$X, s2, v, intercept_variance)
    })
    ll <- vapply(values, `[[`, numeric(1), "log_evidence")
    log_integral <- rhs_oracle_logsumexp(log(quad$w) + ll)
    weights <- exp(log(quad$w) + ll - log_integral)
    beta_mean <- Reduce(`+`, Map(function(a, w) w * a$mean, values, weights))
    beta_second <- Reduce(`+`, Map(function(a, w) {
      w * (a$covariance + tcrossprod(a$mean))
    }, values, weights))
    list(log_evidence = log_integral,
         variance_mean = sum(weights * sigma2),
         beta_mean = beta_mean,
         beta_covariance = beta_second - tcrossprod(beta_mean),
         quadrature_weight_sum = sum(weights))
  })
  evidence <- vapply(details, `[[`, numeric(1), "log_evidence")
  log_weights <- log(bank$prior) + evidence
  probability <- exp(log_weights - rhs_oracle_logsumexp(log_weights))
  list(model_probability = probability,
       variance_mean = sum(probability * vapply(details, `[[`, numeric(1), "variance_mean")),
       model_details = details, order = order,
       method = "dense observation-space Gaussian; inverse-gamma quantile quadrature")
}

rhs_oracle_one_local <- function(bank, global = 1, slab = 4, tau0 = 1,
                                 a_sigma = 3, b_sigma = 1,
                                 intercept_variance = 10, order = 80L) {
  # Each model has zero or one slope.  Integrate sigma^2 and the local scale;
  # global/slab are fixed.  Quantile transforms integrate against normalized
  # priors on a bounded square and avoid an arbitrary integration cutoff.
  stopifnot(all(vapply(bank$models, function(m) m$d <= 1L, logical(1))))
  quad <- rhs_oracle_legendre(order)
  M <- length(bank$models)
  tau0 <- rep_len(tau0, M)
  sigma2 <- b_sigma / stats::qgamma(quad$u, shape = a_sigma)
  lambda <- tan(pi * quad$u / 2)
  grid <- expand.grid(sigma = seq_len(order), local = seq_len(order))
  base_log_w <- log(quad$w[grid$sigma]) + log(quad$w[grid$local])
  details <- lapply(seq_len(M), function(m) {
    model <- bank$models[[m]]
    slope_v <- rhs_oracle_variance(lambda, global, slab, tau0[m])
    ll <- vapply(seq_len(nrow(grid)), function(k) {
      v <- if (model$d) slope_v[grid$local[k]] else numeric(0)
      covariance <- sigma2[grid$sigma[k]] * diag(length(bank$y)) +
        model$X %*% diag(c(intercept_variance, v), ncol(model$X)) %*% t(model$X)
      rhs_oracle_log_mvn(bank$y, covariance)
    }, numeric(1))
    log_evidence <- rhs_oracle_logsumexp(base_log_w + ll)
    weights <- exp(base_log_w + ll - log_evidence)
    # The transformed local CDF is bounded and has prior mean 1/2.
    list(log_evidence = log_evidence,
         variance_mean = sum(weights * sigma2[grid$sigma]),
         local_prior_cdf_mean = sum(weights * quad$u[grid$local]))
  })
  log_weights <- log(bank$prior) + vapply(details, `[[`, numeric(1), "log_evidence")
  probability <- exp(log_weights - rhs_oracle_logsumexp(log_weights))
  list(model_probability = probability,
       variance_mean = sum(probability * vapply(details, `[[`, numeric(1), "variance_mean")),
       local_prior_cdf_mean = sum(probability * vapply(details, `[[`, numeric(1), "local_prior_cdf_mean")),
       model_details = details, order = order,
       method = "dense observation-space Gaussian; normalized sigma/local quantile quadrature")
}

rhs_oracle_batch_mcse <- function(x) {
  x <- as.numeric(x)
  batch_size <- max(2L, as.integer(floor(sqrt(length(x)))))
  batches <- as.integer(length(x) %/% batch_size)
  if (batches < 3L) return(NA_real_)
  means <- colMeans(matrix(x[seq_len(batches * batch_size)], batch_size, batches))
  sqrt(stats::var(means) / batches)
}

rhs_oracle_compare <- function(samples, target, label, absolute_floor = 0.005,
                               quadrature_error = 0) {
  estimate <- mean(samples)
  mcse <- rhs_oracle_batch_mcse(samples)
  tolerance <- max(absolute_floor, 6 * mcse) + 3 * abs(quadrature_error)
  data.frame(check = label, estimate = estimate, reference = target,
             error = estimate - target, mcse = mcse,
             quadrature_error = abs(quadrature_error), tolerance = tolerance,
             pass = is.finite(estimate) && is.finite(mcse) &&
               abs(estimate - target) <= tolerance)
}

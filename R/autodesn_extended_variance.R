# Stable conditional log densities shared by the sampler and numerical references.
.ext_sv_loglik <- function(log_relative_variance, residual, s2) {
  if (any(!is.finite(log_relative_variance))) return(-Inf)
  active <- residual != 0
  quadratic <- sum(exp(2 * log(abs(residual[active])) - log(s2) - log_relative_variance[active]))
  -.5 * (sum(log_relative_variance) + quadratic)
}

.ext_sv_phi_logit_target <- function(z, u, shape) {
  pr <- stats::plogis(z)
  phi <- 2 * pr - 1
  .ext_ar1_log(u, phi) + stats::dbeta(pr, shape[1], shape[2], log = TRUE) +
    stats::plogis(z, log.p = TRUE) + stats::plogis(-z, log.p = TRUE)
}

.ext_sv_omega_log_target <- function(z, u, residual, s2, offset, prior_sd) {
  if (!is.finite(z) || z > log(.Machine$double.xmax)) return(-Inf)
  omega <- exp(z)
  .ext_sv_loglik(offset + omega * u, residual, s2) +
    stats::dnorm(omega, 0, prior_sd, log = TRUE) + log(2) + z
}

## R/qdesn_rhs_prior.R
##
## Regularized horseshoe (RHS) prior utilities for Q-DESN VB.
## This file implements:
##   - Transformations between unconstrained eta and (lambda, tau, c2)
##   - Prior log-densities for beta | (lambda, tau, c2) and for (lambda, tau, c2)
##   - Log-kernel on eta for Laplace–Delta
##   - Laplace–Delta update for eta
##   - Moments E_q[V_j], E_q[1 / V_j] used in the beta block and ELBO
##
## Notation:
##   lambda_j > 0, j = 1,...,k  (local scales)
##   tau      > 0               (global scale)
##   c2       > 0               (slab variance)
##   V_j(lambda_j, tau, c2)     RHS variance for beta_j
##
## Hyperpriors (as in your LaTeX):
##   lambda_j ~ C^+(0, 1)
##   tau      ~ C^+(0, tau0)
##   c2       ~ IG(nu/2, nu s2 / 2)     [shape = nu/2, "scale" = nu s2 / 2, IG parametrization: f(x) ∝ x^{-(a+1)} e^{-b/x}]
##
## Check the IG parametrization matches the rest of exdqlm (adjust b if needed).

`%||%` <- function(x, y) if (is.null(x)) y else x

#-----------------------------
# 3.1 Transformations & Jacobian
#-----------------------------

# eta = (log lambda_1, ..., log lambda_k, log tau, log c2)

rhs_eta_to_scales <- function(eta) {
  k <- length(eta) - 2L
  if (k <= 0L) stop("rhs_eta_to_scales: length(eta) must be >= 3")

  eta_lambda <- eta[seq_len(k)]
  eta_tau    <- eta[k + 1L]
  eta_c2     <- eta[k + 2L]

  lambda <- exp(eta_lambda)
  tau    <- exp(eta_tau)
  c2     <- exp(eta_c2)

  list(lambda = lambda, tau = tau, c2 = c2)
}

rhs_scales_to_eta <- function(lambda, tau, c2) {
  c(lambda = log(lambda), tau = log(tau), c2 = log(c2))
}

# log |det J| for the map eta -> (lambda, tau, c2)
# J is diagonal with entries exp(eta_i), so log |det J| = sum(eta_i)

rhs_log_jacobian <- function(eta) {
  sum(eta)
}

#-----------------------------
# 3.1 RHS variance V_j(lambda_j, tau, c2)
#-----------------------------

# Regularized horseshoe variance for beta_j:
#   V_j = tau^2 * \tilde{lambda}_j^2,
#   \tilde{lambda}_j^2 = c2 * lambda_j^2 / (c2 + tau^2 * lambda_j^2)
#
# => V_j = tau^2 * c2 * lambda_j^2 / (c2 + tau^2 * lambda_j^2)

rhs_V_vec <- function(lambda, tau, c2) {
  tau2 <- tau^2
  lam2 <- lambda^2

  num   <- tau2 * c2 * lam2
  denom <- c2 + tau2 * lam2

  num / denom
}

#-----------------------------
# 3.2 Expected log p(beta | lambda, tau, c2)
#-----------------------------

# beta_j | lambda_j, tau, c2 ~ N(0, V_j)
# For given beta_m2_j = E_q[beta_j^2], the contribution to the ELBO is:
#
# E_q[log p(beta | lambda, tau, c2)] =
#   -1/2 * sum_j [ log(2*pi) + log V_j + beta_m2_j / V_j ]

rhs_expected_log_prior_beta <- function(beta_m2, lambda, tau, c2) {
  V <- rhs_V_vec(lambda, tau, c2)
  k <- length(beta_m2)
  if (length(V) != k) stop("rhs_expected_log_prior_beta: length mismatch in beta_m2 and V")

  -0.5 * (k * log(2 * pi) + sum(log(V)) + sum(beta_m2 / V))
}

#-----------------------------
# 3.2 Log prior for (lambda, tau, c2)
#-----------------------------

# Log prior of local scales:
#   lambda_j ~ C^+(0, 1)
#   f(lambda_j) = (2 / pi) * 1 / (1 + lambda_j^2),  lambda_j > 0

rhs_log_prior_lambda <- function(lambda) {
  sum(log(2 / pi) - log(1 + lambda^2))
}

# Log prior of global scale:
#   tau ~ C^+(0, tau0)
#   f(tau) = (2 / (pi * tau0)) * 1 / (1 + (tau / tau0)^2),  tau > 0

rhs_log_prior_tau <- function(tau, tau0) {
  log(2 / (pi * tau0)) - log(1 + (tau / tau0)^2)
}

# Log prior of slab variance:
#   c2 ~ IG(a, b) with a = nu/2, b = nu s2 / 2
# IG parametrization: f(x) = b^a / Gamma(a) * x^{-(a+1)} * exp(-b/x)

rhs_log_prior_c2 <- function(c2, nu, s2) {
  a <- nu / 2
  b <- nu * s2 / 2

  a * log(b) - lgamma(a) - (a + 1) * log(c2) - b / c2
}

rhs_log_prior_scales <- function(lambda, tau, c2, hyper) {
  tau0 <- hyper$tau0
  nu   <- hyper$nu
  s2   <- hyper$s2

  log_p_lambda <- rhs_log_prior_lambda(lambda)
  log_p_tau    <- rhs_log_prior_tau(tau, tau0)
  log_p_c2     <- rhs_log_prior_c2(c2, nu, s2)

  log_p_lambda + log_p_tau + log_p_c2
}

#-----------------------------
# 3.3 Log-kernel on eta and Laplace–Delta update
#-----------------------------

# log-kernel on eta = expected log joint of (beta, lambda, tau, c2) + log-Jacobian
#
# Inputs:
#   eta      : vector of length k+2  (log lambdas, log tau, log c2)
#   beta_m2  : vector length k with E_q[beta_j^2]
#   hyper    : list(tau0, nu, s2)

rhs_log_kernel_eta <- function(eta, beta_m2, hyper) {
  scales  <- rhs_eta_to_scales(eta)
  lambda  <- scales$lambda
  tau     <- scales$tau
  c2      <- scales$c2

  log_prior_beta   <- rhs_expected_log_prior_beta(beta_m2, lambda, tau, c2)
  log_prior_scales <- rhs_log_prior_scales(lambda, tau, c2, hyper)
  log_jac          <- rhs_log_jacobian(eta)

  log_prior_beta + log_prior_scales + log_jac
}

# Laplace–Delta update for eta block (lambda, tau, c2)
#
# Assumes vb_state has:
#   vb_state$beta$mu    (length k)
#   vb_state$beta$Sigma (k x k)
#   vb_state$rhs$eta_mu (length k+2)
#
# config$vb$priors$beta$rhs$tau0, nu, s2 exist.

rhs_update_eta <- function(vb_state, X, y, config) {
  k <- length(vb_state$beta$mu)
  if (is.null(vb_state$rhs)) stop("rhs_update_eta: vb_state$rhs is NULL; did you initialize RHS state?")
  eta_init <- vb_state$rhs$eta_mu

  if (length(eta_init) != k + 2L) {
    stop("rhs_update_eta: length(eta_mu) must be k + 2")
  }

  # E_q[beta_j^2] = mu_j^2 + Sigma_jj
  beta_m2 <- vb_state$beta$mu^2 + diag(vb_state$beta$Sigma)

  hyper <- list(
    tau0 = config$vb$priors$beta$rhs$tau0,
    nu   = config$vb$priors$beta$rhs$nu,
    s2   = config$vb$priors$beta$rhs$s2
  )

  maxit  <- config$vb$rhs_maxit  %||% 200
  reltol <- config$vb$rhs_reltol %||% 1e-8

  opt <- optim(
    par     = eta_init,
    fn      = function(par) -rhs_log_kernel_eta(par, beta_m2, hyper),
    hessian = TRUE,
    control = list(maxit = maxit, reltol = reltol)
  )

  eta_hat <- opt$par
  H       <- opt$hessian

  # Invert Hessian with a small ridge if needed for numerical stability
  Sigma <- tryCatch(
    solve(H),
    error = function(e) {
      eig <- eigen(H, symmetric = TRUE)
      vals <- pmax(eig$values, 1e-8)
      eig$vectors %*% (t(eig$vectors) * (1 / vals))
    }
  )

  vb_state$rhs$eta_mu    <- eta_hat
  vb_state$rhs$eta_Sigma <- Sigma

  vb_state
}

#-----------------------------
# 3.4 Moments of V_j and 1 / V_j
#-----------------------------

# Zero-th order Laplace–Delta: just plug in eta_mu
# (You can add curvature-based corrections later if you want.)

rhs_compute_V_moments <- function(vb_state) {
  if (is.null(vb_state$rhs)) stop("rhs_compute_V_moments: vb_state$rhs is NULL")

  eta_mu <- vb_state$rhs$eta_mu
  scales <- rhs_eta_to_scales(eta_mu)

  lambda <- scales$lambda
  tau    <- scales$tau
  c2     <- scales$c2

  V_hat     <- rhs_V_vec(lambda, tau, c2)
  V_inv_hat <- 1 / V_hat

  list(
    V      = V_hat,
    V_inv  = V_inv_hat,
    lambda = lambda,
    tau    = tau,
    c2     = c2
  )
}

#-----------------------------------------------
# 4. RHS prior "module" for the exAL VB core
#-----------------------------------------------

#' Build an RHS prior module for the static exAL VB core.
#'
#' For now this is just a container for hyperparameters and the base
#' covariance V0. The VB core still implements all beta updates internally.
#' Once you move the beta-block behind a generic interface, you can extend
#' this object with methods such as `init_state()` and `update()`, and use
#' the helper functions in this file (rhs_log_kernel_eta, rhs_update_eta,
#' rhs_compute_V_moments, etc.).
#'
#' @export
qdesn_rhs_prior_module <- function(V0, rhs_hypers = NULL) {
  list(
    type       = "rhs",
    V0         = V0,
    hypers     = rhs_hypers
  )
}

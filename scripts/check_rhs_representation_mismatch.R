#!/usr/bin/env Rscript

# Rigorous validation for the RHS variational block representation:
#   q_{lambda,tau,c2} theory form vs implementation shape in R/qdesn_rhs_prior.R
#
# This script checks:
# 1) transformed-kernel objective equivalence
# 2) Hessian equivalence (closed form vs finite differences)
# 3) state shape + Laplace covariance consistency
# 4) ELBO decomposition identity
# 5) expected precision approximation gap (delta vs exact Gaussian moments)

options(stringsAsFactors = FALSE)

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg)) {
  script_path <- normalizePath(sub("^--file=", "", script_arg[1L]), mustWork = TRUE)
  repo <- normalizePath(file.path(dirname(script_path), ".."), mustWork = TRUE)
} else {
  repo <- normalizePath(getwd(), mustWork = TRUE)
}
setwd(repo)

source("R/00_utils.R")
source("R/qdesn_rhs_prior.R")
source("R/priors_beta.R")

if (!requireNamespace("numDeriv", quietly = TRUE)) {
  stop("Package 'numDeriv' is required for Hessian checks.", call. = FALSE)
}

set.seed(20260223)

logsumexp2_manual <- function(a, b) {
  m <- pmax(a, b)
  m + log(exp(a - m) + exp(b - m))
}

rhs_obj_eta_theory_manual <- function(eta_lambda, eta_tau, eta_c2, beta2,
                                      tau0, nu, s, shrink_intercept = TRUE) {
  if (!isTRUE(shrink_intercept)) {
    if (length(beta2) >= 2L) {
      eta_lambda <- eta_lambda[-1L]
      beta2 <- beta2[-1L]
    } else {
      eta_lambda <- numeric(0)
      beta2 <- numeric(0)
    }
  }

  u <- 2 * eta_tau + 2 * eta_lambda
  ld <- logsumexp2_manual(eta_c2, u)
  logV <- eta_c2 + u - ld
  invV <- exp(logsumexp2_manual(-eta_c2, -u))

  like <- -0.5 * sum(logV + beta2 * invV)
  lp_lam <- sum(eta_lambda - log1p(exp(2 * eta_lambda)))
  logtau0 <- log(tau0)
  lp_tau <- eta_tau - log1p(exp(2 * (eta_tau - logtau0)))
  lp_c2 <- -(nu / 2) * eta_c2 - (nu * s^2) / (2 * exp(eta_c2))

  like + lp_lam + lp_tau + lp_c2
}

check_objective_equivalence <- function(n_rep = 300L) {
  diffs <- numeric(n_rep)
  for (r in seq_len(n_rep)) {
    p <- sample(3:18, 1)
    shrink <- sample(c(TRUE, FALSE), 1)

    eta_lambda <- rnorm(p, sd = 1.1)
    eta_tau <- rnorm(1, sd = 0.9)
    eta_c2 <- rnorm(1, sd = 0.8)
    beta2 <- rgamma(p, shape = 2.0, rate = 1.2)

    tau0 <- runif(1, 0.2, 2.5)
    nu <- runif(1, 2.2, 12)
    s <- runif(1, 0.3, 2.0)

    f_code <- rhs_obj_eta(
      eta_lambda = eta_lambda,
      eta_tau = eta_tau,
      eta_c2 = eta_c2,
      beta2 = beta2,
      tau0 = tau0,
      nu = nu,
      s = s,
      shrink_intercept = shrink
    )

    f_theory <- rhs_obj_eta_theory_manual(
      eta_lambda = eta_lambda,
      eta_tau = eta_tau,
      eta_c2 = eta_c2,
      beta2 = beta2,
      tau0 = tau0,
      nu = nu,
      s = s,
      shrink_intercept = shrink
    )

    diffs[r] <- abs(f_code - f_theory)
  }
  list(max_abs = max(diffs), p95_abs = unname(quantile(diffs, 0.95)), median_abs = median(diffs))
}

check_hessian_equivalence <- function(n_rep = 80L) {
  diffs <- numeric(n_rep)
  for (r in seq_len(n_rep)) {
    p <- sample(4:12, 1)
    shrink <- sample(c(TRUE, FALSE), 1)

    eta_lambda <- runif(p, -1.2, 1.2)
    eta_tau <- runif(1, -1.0, 1.0)
    eta_c2 <- runif(1, -1.0, 1.0)
    S <- rgamma(p, shape = 2.0, rate = 1.0)

    tau0 <- runif(1, 0.4, 1.6)
    nu <- runif(1, 3.0, 8.0)
    s <- runif(1, 0.6, 1.4)

    h <- .rhs_hess_active(
      eta_lambda = eta_lambda,
      eta_tau = eta_tau,
      eta_c2 = eta_c2,
      S = S,
      tau0 = tau0,
      nu = nu,
      s = s,
      shrink_intercept = shrink
    )

    idx <- h$idx
    z0 <- c(eta_lambda[idx], eta_tau, eta_c2)

    f_act <- function(z) {
      k <- length(idx)
      eta_l <- eta_lambda
      if (k > 0L) eta_l[idx] <- z[seq_len(k)]
      rhs_obj_eta(
        eta_lambda = eta_l,
        eta_tau = z[k + 1L],
        eta_c2 = z[k + 2L],
        beta2 = S,
        tau0 = tau0,
        nu = nu,
        s = s,
        shrink_intercept = shrink
      )
    }

    H_fd <- numDeriv::hessian(func = f_act, x = z0, method = "Richardson")
    H_fd <- 0.5 * (H_fd + t(H_fd))
    H_code <- 0.5 * (h$H + t(h$H))
    diffs[r] <- max(abs(H_fd - H_code))
  }
  list(max_abs = max(diffs), p95_abs = unname(quantile(diffs, 0.95)), median_abs = median(diffs))
}

single_rhs_state <- function(p, shrink_intercept) {
  prior <- beta_prior(
    type = "rhs",
    rhs = list(
      tau0 = 1.0,
      nu = 4.0,
      s = 1.0,
      shrink_intercept = shrink_intercept,
      intercept_prec = 1e-16,
      n_inner = 2L,
      eta_bounds = list(lambda = c(-8, 8), tau = c(-8, 8), c2 = c(-8, 8)),
      var_floor = 1e-12
    )
  )

  state <- prior$init(p)

  A <- matrix(rnorm(p * p), p, p)
  V <- crossprod(A) / p + diag(runif(p, 0.02, 0.15), p)
  qbeta <- list(m = rnorm(p, sd = 0.35), V = V)

  state2 <- prior$update(state, qbeta)
  list(prior = prior, state = state2, qbeta = qbeta)
}

check_shape_and_elbo <- function(n_rep = 80L) {
  shape_ok <- logical(n_rep)
  inv_resid <- numeric(n_rep)
  elbo_diff <- numeric(n_rep)

  for (r in seq_len(n_rep)) {
    p <- sample(5:20, 1)
    shrink <- sample(c(TRUE, FALSE), 1)

    ss <- single_rhs_state(p = p, shrink_intercept = shrink)
    prior <- ss$prior
    st <- ss$state
    qb <- ss$qbeta

    shape_ok[r] <- (length(st$eta_lambda_hat) == p) &&
      all(dim(st$Sigma_full) == c(p + 2L, p + 2L)) &&
      (length(st$Sigma_diag) == (p + 2L))

    beta2 <- as.numeric(qb$m^2 + diag(qb$V))
    h <- .rhs_hess_active(
      eta_lambda = as.numeric(st$eta_lambda_hat),
      eta_tau = as.numeric(st$eta_tau_hat),
      eta_c2 = as.numeric(st$eta_c_hat),
      S = beta2,
      tau0 = as.numeric(prior$hypers$tau0),
      nu = as.numeric(prior$hypers$nu),
      s = as.numeric(prior$hypers$s),
      shrink_intercept = isTRUE(st$shrink_intercept)
    )

    idx <- if (isTRUE(st$shrink_intercept)) seq_len(p) else if (p >= 2L) 2L:p else integer(0)
    act <- c(idx, p + 1L, p + 2L)

    K <- -h$H
    Sact <- st$Sigma_full[act, act, drop = FALSE]
    Ierr <- K %*% Sact - diag(nrow(Sact))
    inv_resid[r] <- max(abs(Ierr))

    f0 <- rhs_obj_eta(
      eta_lambda = as.numeric(st$eta_lambda_hat),
      eta_tau = as.numeric(st$eta_tau_hat),
      eta_c2 = as.numeric(st$eta_c_hat),
      beta2 = beta2,
      tau0 = as.numeric(prior$hypers$tau0),
      nu = as.numeric(prior$hypers$nu),
      s = as.numeric(prior$hypers$s),
      shrink_intercept = isTRUE(st$shrink_intercept)
    )

    trHS <- sum(h$H * Sact)
    E_log_joint <- f0 + 0.5 * trHS

    ld <- as.numeric(determinant(Sact, logarithm = TRUE)$modulus)
    d_act <- nrow(Sact)
    H_qeta <- 0.5 * (d_act * (1 + log(2 * pi)) + ld)

    E_log_intercept <- 0
    if (!isTRUE(st$shrink_intercept) && p >= 1L) {
      prec0 <- as.numeric(st$intercept_prec)[1L]
      E_log_intercept <- 0.5 * (log(prec0) - log(2 * pi)) - 0.5 * prec0 * beta2[1L]
    }

    elbo_manual <- as.numeric(E_log_joint + H_qeta + E_log_intercept)
    elbo_code <- as.numeric(prior$elbo(st, qb)$elbo)
    elbo_diff[r] <- abs(elbo_manual - elbo_code)
  }

  list(
    shape_ok_all = all(shape_ok),
    inv_resid_max = max(inv_resid),
    inv_resid_p95 = unname(quantile(inv_resid, 0.95)),
    elbo_abs_max = max(elbo_diff),
    elbo_abs_p95 = unname(quantile(elbo_diff, 0.95)),
    elbo_abs_median = median(elbo_diff)
  )
}

check_expected_prec_gap <- function(n_rep = 80L) {
  rel_err_all <- numeric(0)
  rel_err_true <- numeric(0)
  rel_err_false <- numeric(0)

  for (r in seq_len(n_rep)) {
    for (shrink in c(TRUE, FALSE)) {
      p <- sample(6:24, 1)
      ss <- single_rhs_state(p = p, shrink_intercept = shrink)
      prior <- ss$prior
      st <- ss$state

      prec_code <- as.numeric(prior$expected_prec(st, p))
      mu_lam <- as.numeric(st$eta_lambda_hat)
      mu_tau <- as.numeric(st$eta_tau_hat)
      mu_c <- as.numeric(st$eta_c_hat)
      Sigma <- as.matrix(st$Sigma_full)

      var_k <- max(Sigma[p + 2L, p + 2L], 0)
      exact <- numeric(p)

      for (j in seq_len(p)) {
        if (!isTRUE(st$shrink_intercept) && j == 1L) {
          exact[j] <- as.numeric(st$intercept_prec)
          next
        }
        v_sum <- Sigma[j, j] + Sigma[p + 1L, p + 1L] + 2 * Sigma[j, p + 1L]
        v_sum <- max(v_sum, 0)

        exact[j] <- exp(-mu_c + 0.5 * var_k) + exp(-2 * (mu_lam[j] + mu_tau) + 2 * v_sum)
      }

      rel <- abs(prec_code - exact) / pmax(exact, 1e-300)
      rel_err_all <- c(rel_err_all, rel)
      if (shrink) rel_err_true <- c(rel_err_true, rel) else rel_err_false <- c(rel_err_false, rel)
    }
  }

  qfun <- function(x) {
    c(median = median(x), p90 = unname(quantile(x, 0.90)), p95 = unname(quantile(x, 0.95)), max = max(x))
  }

  list(all = qfun(rel_err_all), shrink_true = qfun(rel_err_true), shrink_false = qfun(rel_err_false))
}

cat("[1/4] Objective equivalence check...\n")
obj_res <- check_objective_equivalence()
print(obj_res)

cat("\n[2/4] Hessian equivalence check...\n")
hess_res <- check_hessian_equivalence()
print(hess_res)

cat("\n[3/4] Shape + ELBO identity check...\n")
shape_elbo_res <- check_shape_and_elbo()
print(shape_elbo_res)

cat("\n[4/4] Expected precision exact-moment check...\n")
prec_gap_res <- check_expected_prec_gap()
print(prec_gap_res)

verdict <- list(
  representation_shape_equivalent = isTRUE(shape_elbo_res$shape_ok_all) &&
    (obj_res$max_abs < 1e-9) &&
    (hess_res$p95_abs < 1e-4) &&
    (shape_elbo_res$elbo_abs_max < 1e-8),
  expected_prec_matches_exact_gaussian_moment = (prec_gap_res$all[["max"]] < 1e-10)
)

cat("\nVerdict:\n")
print(verdict)

# Internal helpers for static LDVB transformed (sigma, gamma) block.
.exal_static_ld_log_jacobian <- function(eta, ell, L, U) {
  s <- stats::plogis(eta)
  s <- pmin(pmax(s, 1e-12), 1 - 1e-12)
  log(pmax(U - L, 1e-12)) + log(s) + log1p(-s) + ell
}

.exal_static_ld_log_qsiggam <- function(par, state, include_jacobian = TRUE) {
  eta <- as.numeric(par[1])
  ell <- as.numeric(par[2])
  gamma <- state$g_from_eta(eta)
  sigma <- state$sig_from_ell(ell)

  A <- state$A_of(gamma)
  B <- state$B_of(gamma)
  lam <- state$lam_of(gamma)
  if (!is.finite(B) || B <= 0 || !is.finite(sigma) || sigma <= 0) {
    return(-Inf)
  }

  xb <- drop(state$X %*% state$m_beta)
  t_i <- state$y - xb
  q_i <- rowSums((state$X %*% state$V_beta) * state$X)

  term1 <- - (1 / (2 * B * sigma)) * sum(
    state$E_inv_v * (t_i^2 + q_i) - 2 * A * t_i + (A * A) * state$E_v
  )
  term2 <- - (sum(state$E_v) + state$b_sigma) / sigma
  term3 <- + (lam / B) * sum(state$E_s * state$E_inv_v * t_i - state$E_s * A)
  term4 <- - ((lam * lam) / (2 * B)) * sigma * sum(state$E_s2 * state$E_inv_v)

  log_prior <- state$log_prior_gamma(gamma)
  log_det <- - (state$n / 2) * log(B) - (((3 * state$n) / 2) + state$a_sigma + 1) * ell
  val <- log_prior + log_det + term1 + term2 + term3 + term4

  if (isTRUE(include_jacobian)) {
    val <- val + .exal_static_ld_log_jacobian(eta, ell, state$L, state$U)
  }

  val
}

.exal_static_ld_controls <- function(ld_controls = NULL) {
  defaults <- list(
    damping = getOption("exdqlm.static.ldvb.damping", 0.45),
    xi_damping = getOption("exdqlm.static.ldvb.xi_damping", 0.65),
    xi_mode = getOption("exdqlm.static.ldvb.xi_mode", "single"),
    xi_replicates = getOption("exdqlm.static.ldvb.xi_replicates", 1L),
    reuse_draws = getOption("exdqlm.static.ldvb.reuse_draws", TRUE),
    antithetic = getOption("exdqlm.static.ldvb.antithetic", TRUE),
    optimizer_maxit = getOption("exdqlm.static.ldvb.optimizer_maxit", 200L),
    eig_floor = getOption("exdqlm.static.ldvb.eig_floor", 1e-6),
    eig_cap = getOption("exdqlm.static.ldvb.eig_cap", 25),
    step_cap_eta = getOption("exdqlm.static.ldvb.step_cap_eta", 2.0),
    step_cap_ell = getOption("exdqlm.static.ldvb.step_cap_ell", 0.75),
    reuse_seed = getOption("exdqlm.static.ldvb.reuse_seed", NA_integer_),
    mode_grad_tol = getOption("exdqlm.static.ldvb.mode_grad_tol", 5e-3),
    mode_min_eig = getOption("exdqlm.static.ldvb.mode_min_eig", 1e-8),
    store_trace = getOption("exdqlm.static.ldvb.store_trace", TRUE)
  )
  if (!is.null(ld_controls)) {
    defaults <- utils::modifyList(defaults, ld_controls)
  }

  defaults$damping <- as.numeric(defaults$damping)[1]
  if (!is.finite(defaults$damping) || defaults$damping <= 0 || defaults$damping > 1) {
    defaults$damping <- 0.45
  }
  defaults$xi_damping <- as.numeric(defaults$xi_damping)[1]
  if (!is.finite(defaults$xi_damping) || defaults$xi_damping <= 0 || defaults$xi_damping > 1) {
    defaults$xi_damping <- defaults$damping
  }
  defaults$xi_mode <- match.arg(as.character(defaults$xi_mode)[1], c("single", "replicated"))
  defaults$xi_replicates <- suppressWarnings(as.integer(defaults$xi_replicates)[1])
  if (!is.finite(defaults$xi_replicates) || defaults$xi_replicates < 1L) defaults$xi_replicates <- 1L
  if (identical(defaults$xi_mode, "single")) defaults$xi_replicates <- 1L
  defaults$reuse_draws <- isTRUE(defaults$reuse_draws)
  defaults$antithetic <- isTRUE(defaults$antithetic)
  defaults$optimizer_maxit <- suppressWarnings(as.integer(defaults$optimizer_maxit)[1])
  if (!is.finite(defaults$optimizer_maxit) || defaults$optimizer_maxit < 20L) {
    defaults$optimizer_maxit <- 200L
  }
  defaults$eig_floor <- as.numeric(defaults$eig_floor)[1]
  if (!is.finite(defaults$eig_floor) || defaults$eig_floor <= 0) defaults$eig_floor <- 1e-6
  defaults$eig_cap <- as.numeric(defaults$eig_cap)[1]
  if (!is.finite(defaults$eig_cap) || defaults$eig_cap <= defaults$eig_floor) defaults$eig_cap <- 25
  defaults$step_cap_eta <- as.numeric(defaults$step_cap_eta)[1]
  if (!is.finite(defaults$step_cap_eta) || defaults$step_cap_eta <= 0) defaults$step_cap_eta <- 2.0
  defaults$step_cap_ell <- as.numeric(defaults$step_cap_ell)[1]
  if (!is.finite(defaults$step_cap_ell) || defaults$step_cap_ell <= 0) defaults$step_cap_ell <- 0.75
  defaults$reuse_seed <- suppressWarnings(as.integer(defaults$reuse_seed)[1])
  if (!is.finite(defaults$reuse_seed)) defaults$reuse_seed <- NA_integer_
  defaults$mode_grad_tol <- as.numeric(defaults$mode_grad_tol)[1]
  if (!is.finite(defaults$mode_grad_tol) || defaults$mode_grad_tol <= 0) defaults$mode_grad_tol <- 5e-3
  defaults$mode_min_eig <- as.numeric(defaults$mode_min_eig)[1]
  if (!is.finite(defaults$mode_min_eig) || defaults$mode_min_eig <= 0) defaults$mode_min_eig <- 1e-8
  defaults$store_trace <- isTRUE(defaults$store_trace)
  defaults
}

.exal_static_ld_make_base_draws <- function(ns, antithetic = TRUE, seed = NA_integer_) {
  ns <- max(1L, suppressWarnings(as.integer(ns)[1]))
  old_seed <- if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
    get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  } else {
    NULL
  }
  if (is.finite(seed)) set.seed(seed)
  on.exit({
    if (!is.null(old_seed)) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    }
  }, add = TRUE)

  if (isTRUE(antithetic) && ns > 1L) {
    half <- ceiling(ns / 2)
    z_half <- matrix(stats::rnorm(2L * half), nrow = 2L, ncol = half)
    z <- cbind(z_half, -z_half)[, seq_len(ns), drop = FALSE]
  } else {
    z <- matrix(stats::rnorm(2L * ns), nrow = 2L, ncol = ns)
  }
  z
}

.exal_static_ld_named_numeric <- function(x) {
  xx <- unlist(x, use.names = TRUE)
  out <- as.numeric(xx)
  names(out) <- names(xx)
  out
}

.exal_static_ld_make_base_draws_list <- function(ns, replicates = 1L, antithetic = TRUE, seed = NA_integer_) {
  replicates <- max(1L, suppressWarnings(as.integer(replicates)[1]))
  lapply(seq_len(replicates), function(i) {
    seed_i <- if (is.finite(seed)) seed + (i - 1L) else NA_integer_
    .exal_static_ld_make_base_draws(ns = ns, antithetic = antithetic, seed = seed_i)
  })
}

.exal_static_ld_regularize_cov <- function(Sigma, eig_floor = 1e-6, eig_cap = 25) {
  S <- suppressWarnings(as.matrix(Sigma))
  if (!all(dim(S) == c(2L, 2L))) S <- diag(c(1e-4, 1e-4))
  S[!is.finite(S)] <- 0
  S <- (S + t(S)) / 2
  eig <- eigen(S, symmetric = TRUE)
  vals_raw <- eig$values
  vals <- pmin(pmax(vals_raw, eig_floor), eig_cap)
  S_reg <- eig$vectors %*% diag(vals, 2L, 2L) %*% t(eig$vectors)
  S_reg <- (S_reg + t(S_reg)) / 2
  list(
    Sigma = S_reg,
    eig_raw = vals_raw,
    eig_reg = vals,
    condition_raw = if (all(is.finite(vals_raw)) && min(abs(vals_raw)) > 0) {
      max(abs(vals_raw)) / min(abs(vals_raw))
    } else {
      NA_real_
    },
    condition_reg = max(vals) / min(vals)
  )
}

.exal_static_ld_cov_from_precision <- function(H, eig_floor = 1e-6, eig_cap = 25) {
  precision_floor <- 1 / max(eig_cap, eig_floor)
  precision_cap <- 1 / min(eig_floor, eig_cap)

  P <- suppressWarnings(as.matrix(H))
  if (!all(dim(P) == c(2L, 2L))) P <- diag(precision_floor, 2L)
  P[!is.finite(P)] <- 0
  P <- (P + t(P)) / 2

  eig <- eigen(P, symmetric = TRUE)
  vals_raw <- eig$values
  vals_reg <- pmin(pmax(vals_raw, precision_floor), precision_cap)
  cov_vals <- 1 / vals_reg
  Sigma <- eig$vectors %*% diag(cov_vals, 2L, 2L) %*% t(eig$vectors)
  Sigma <- (Sigma + t(Sigma)) / 2

  cov_raw <- ifelse(is.finite(vals_raw) & vals_raw > 0, 1 / vals_raw, NA_real_)
  list(
    Sigma = Sigma,
    precision_eig_raw = vals_raw,
    precision_eig_reg = vals_reg,
    cov_eig_raw = cov_raw,
    cov_eig_reg = cov_vals,
    condition_raw = if (all(is.finite(vals_raw)) && min(vals_raw) > 0) {
      max(vals_raw) / min(vals_raw)
    } else {
      NA_real_
    },
    condition_reg = max(cov_vals) / min(cov_vals),
    used_floor = any(!is.finite(vals_raw)) || any(abs(vals_reg - vals_raw) > 0)
  )
}

.exal_static_ld_rel_change <- function(new, old) {
  new <- as.numeric(new)
  old <- as.numeric(old)
  keep <- is.finite(new) & is.finite(old)
  if (!any(keep)) return(NA_real_)
  max(abs(new[keep] - old[keep]) / pmax(1e-8, abs(new[keep]), abs(old[keep]), 1))
}

.exal_static_ld_mix_step <- function(old, new, damping, step_cap) {
  old <- as.numeric(old)[1]
  new <- as.numeric(new)[1]
  delta <- new - old
  if (is.finite(step_cap)) {
    delta <- min(max(delta, -step_cap), step_cap)
  }
  old + damping * delta
}

.exal_static_ld_mix_numeric_lists <- function(old, new, damping) {
  out <- old
  nm <- union(names(old), names(new))
  for (k in nm) {
    x_old <- old[[k]]
    x_new <- new[[k]]
    if (is.numeric(x_old) && is.numeric(x_new) && length(x_old) == length(x_new)) {
      out[[k]] <- x_old + damping * (x_new - x_old)
    } else if (!is.null(x_new)) {
      out[[k]] <- x_new
    }
  }
  out
}

.exal_static_ld_mode_quality <- function(log_q_fn, par, grad_tol = 5e-3, min_eig = 1e-8) {
  grad <- try(numDeriv::grad(log_q_fn, x = as.numeric(par)), silent = TRUE)
  grad <- if (inherits(grad, "try-error")) rep(NA_real_, length(par)) else as.numeric(grad)

  neg_hess <- try(-numDeriv::hessian(log_q_fn, x = as.numeric(par)), silent = TRUE)
  neg_hess <- if (inherits(neg_hess, "try-error")) {
    matrix(NA_real_, nrow = length(par), ncol = length(par))
  } else {
    hh <- as.matrix(neg_hess)
    (hh + t(hh)) / 2
  }

  eig <- try(eigen(neg_hess, symmetric = TRUE, only.values = TRUE)$values, silent = TRUE)
  eig <- if (inherits(eig, "try-error")) rep(NA_real_, length(par)) else as.numeric(eig)

  grad_inf_norm <- if (all(is.finite(grad))) max(abs(grad)) else NA_real_
  neg_hess_min_eig <- if (any(is.finite(eig))) min(eig, na.rm = TRUE) else NA_real_
  neg_hess_max_eig <- if (any(is.finite(eig))) max(eig, na.rm = TRUE) else NA_real_
  neg_hess_condition <- if (is.finite(neg_hess_min_eig) && is.finite(neg_hess_max_eig) && neg_hess_min_eig > 0) {
    neg_hess_max_eig / neg_hess_min_eig
  } else {
    NA_real_
  }

  list(
    gradient = grad,
    grad_inf_norm = grad_inf_norm,
    neg_hess = neg_hess,
    neg_hess_min_eig = neg_hess_min_eig,
    neg_hess_max_eig = neg_hess_max_eig,
    neg_hess_condition = neg_hess_condition,
    local_mode_pass = is.finite(grad_inf_norm) &&
      grad_inf_norm <= grad_tol &&
      is.finite(neg_hess_min_eig) &&
      neg_hess_min_eig > min_eig
  )
}

#' Static exAL Regression - CAVI with Laplace-Delta for (sigma, gamma)
#'
#' The function applies a coordinate-ascent variational inference (CAVI)
#' algorithm to static Extended Asymmetric Laplace (exAL) regression, using a
#' Laplace-Delta approximation for the joint \eqn{(\sigma,\gamma)} block.
#'
#' @param y Numeric vector (length n).
#' @param X Numeric matrix (n x p).
#' @param p0 Target quantile in (0,1).
#' @param max_iter Integer; maximum CAVI iterations (default 1000).
#' @param tol Numeric; convergence tolerance based on relative ELBO changes (default 1e-4).
#' @param b0,V0 Prior mean and covariance for \eqn{\beta \sim \mathcal{N}(b_0,V_0)}.
#' @param a_sigma,b_sigma Prior for \eqn{\sigma \sim IG(a_\sigma,b_\sigma)} with
#'   density \eqn{p(\sigma)\propto \sigma^{-(a_\sigma+1)} e^{-b_\sigma/\sigma}}.
#' @param gamma_bounds Two-vector (L, U) support for \code{gamma}.
#'   Defaults to \code{c(L.fn(p0), U.fn(p0))}.
#' @param log_prior_gamma Function \code{g -> log pi(gamma=g)} (default flat).
#' @param init Optional list with starting values: \code{beta}, \code{sigma},
#'   \code{gamma}; if missing, reasonable defaults are used.
#' @param dqlm.ind Logical; if \code{TRUE}, fit the reduced AL model (DQLM, \code{gamma=0})
#'   using conjugate CAVI updates for \code{q(beta)}, \code{q(v)} and \code{q(sigma)}.
#' @param n_samp_xi Integer; number of MC draws used to compute the xi expectations for
#'   \eqn{q(\sigma,\gamma)} (default 200).
#' @param ld_controls Optional list of controls for the Laplace-Delta block.
#'   Supported keys include \code{damping}, \code{xi_damping}, \code{xi_mode},
#'   \code{xi_replicates}, \code{reuse_draws}, \code{antithetic},
#'   \code{optimizer_maxit}, \code{eig_floor}, \code{eig_cap},
#'   \code{step_cap_eta}, \code{step_cap_ell}, \code{reuse_seed},
#'   \code{mode_grad_tol}, \code{mode_min_eig}, and \code{store_trace}.
#' @param verbose Logical; print progress.
#'
#' @return A object of class "\code{exal_ldvb}" containing:
#' \itemize{
#'   \item \code{qbeta}: list with \code{m}, \code{V}.
#'   \item \code{qv}: list with \code{chi} (length n), \code{psi} (scalar),
#'         \code{E_v} and \code{E_inv_v} (moments).
#'   \item \code{qs}: list with \code{mu} (length n), \code{tau2} (length n),
#'         \code{E_s}, \code{E_s2}.
#'   \item \code{qsiggam}: list with \code{eta_hat}, \code{ell_hat},
#'         \code{Sigma} (2x2), approximate means
#'         \code{gamma_mean}, \code{sigma_mean}, and the \code{xi} expectations.
#'   \item \code{converged}, \code{iter}, \code{run.time}, and
#'         \code{misc} (including \code{p0}, bounds \code{L,U}, dimensions, and ELBO trace).
#'   \item \code{diagnostics}: ELBO and joint-convergence diagnostics
#'         (state/sigma/gamma/ELBO deltas, stopping reason, and
#'         Laplace-Delta block trace diagnostics, including replicated-\code{xi}
#'         controls and final local-mode quality checks).
#' }
#'
#' @details
#' Mean-field factorization:
#' \deqn{q(\beta)\ \prod_{i=1}^n q(v_i)\ q(s_i)\ q(\sigma,\gamma).}
#' The LD block is parameterized in transformed coordinates
#' \eqn{\eta=\mathrm{logit}((\gamma-L)/(U-L))} and \eqn{\ell=\log\sigma}.
#' The \code{xi} expectations used in CAVI updates are approximated from a small
#' Gaussian Monte Carlo sample in \eqn{(\eta,\ell)}. The Laplace-Delta controls
#' can optionally use deterministic reused draws and replicated batches to reduce
#' Monte Carlo noise when auditing tail behavior.
#'
#' @examples
#' \donttest{
#' set.seed(123)
#' n <- 60
#' X <- cbind(1, seq(-1, 1, length.out = n))
#' y <- as.numeric(X %*% c(0.2, -0.1) + rnorm(n, sd = 0.15))
#' fit <- exal_static_LDVB(y = y, X = X, p0 = 0.5, max_iter = 100, tol = 1e-3, verbose = FALSE)
#' fit$converged
#' }
#' @export
exal_static_LDVB <- function(
  y, X, p0,
  max_iter = 1000, tol = 1e-4,
  b0 = NULL, V0 = NULL,
  a_sigma = 1, b_sigma = 1,
  gamma_bounds = c(L.fn(p0), U.fn(p0)),
  log_prior_gamma = function(g) 0,
  init = NULL,
  dqlm.ind = FALSE,
  n_samp_xi = 200,
  ld_controls = NULL,
  verbose = TRUE
){
  # --- checks ---------------------------------------------------------------
  y <- as.numeric(y)
  X <- as.matrix(X); storage.mode(X) <- "double"
  n <- length(y); p <- ncol(X)
  if (nrow(X) != n) stop("nrow(X) must match length(y).")
  if (!(p0 > 0 && p0 < 1)) stop("p0 must be in (0,1).")

  if (is.null(b0)) b0 <- rep(0, p)
  if (is.null(V0)) V0 <- diag(1e6, p)
  V0 <- as.matrix(V0)
  if (!all(dim(V0) == c(p, p))) stop("V0 must be p x p.")

  # Reduced AL / DQLM branch: no gamma, no s, no LD block.
  if (isTRUE(dqlm.ind)) {
    ret <- .run_static_dqlm_cavi(
      y = y,
      X = X,
      p0 = p0,
      max_iter = max_iter,
      tol = tol,
      b0 = b0,
      V0 = V0,
      a_sigma = a_sigma,
      b_sigma = b_sigma,
      init = init,
      verbose = verbose
    )
    class(ret) <- "exal_vb"
    return(ret)
  }

  L <- gamma_bounds[1]; U <- gamma_bounds[2]
  if (!(L < U)) stop("gamma_bounds must satisfy L < U.")

  # --- A,B,C,lambda helpers -------------------------------------------------
  A_of   <- function(g) A.fn(p0, g)
  B_of   <- function(g) B.fn(p0, g)
  C_of   <- function(g) C.fn(p0, g)
  lam_of <- function(g) C_of(g) * abs(g)

  # transform (eta,ell) <-> (gamma,sigma)
  g_from_eta <- function(eta) { s <- stats::plogis(eta); L + (U - L) * s }
  sig_from_ell <- function(ell) exp(ell)

  # --- initialize variational parameters ------------------------------------
  m_beta  <- if (is.null(init$beta)) rep(0, p) else as.numeric(init$beta)
  V_beta  <- V0
  sigma0  <- if (is.null(init$sigma)) 1 else as.numeric(init$sigma)[1]
  gamma0  <- if (is.null(init$gamma)) 0 else as.numeric(init$gamma)[1]
  gamma0  <- min(max(gamma0, L + 1e-6), U - 1e-6)

  # q(v): initialize moments (use 1 for both)
  E_inv_v <- rep(1, n)
  E_v     <- rep(1, n)

  # q(s): initialize moments (half-normal)
  qs_mu   <- rep(0, n)
  qs_tau2 <- rep(1, n)
  E_s     <- sqrt(2/pi) * rep(1, n)  # E[N^+(0,1)]
  E_s2    <- rep(1, n)               # Var + mean^2 = 1 + 2/pi (but ok to start at 1)

  # q(sigma,gamma): start at point mass to get xi's
  eta_hat <- stats::qlogis((gamma0 - L) / (U - L))
  ell_hat <- log(sigma0)
  Sig_eta_ell <- diag(c(1e-4, 1e-4))  # tiny to start; inflated after first LD update
  ld_ctrl <- .exal_static_ld_controls(ld_controls)
  ld_base_draws <- if (ld_ctrl$reuse_draws) {
    .exal_static_ld_make_base_draws_list(
      ns = max(50L, as.integer(n_samp_xi)),
      replicates = ld_ctrl$xi_replicates,
      antithetic = ld_ctrl$antithetic,
      seed = ld_ctrl$reuse_seed
    )
  } else {
    NULL
  }

  # --- numerics helpers ------------------------------------------------------
  V0_inv <- tryCatch(
    solve(V0),
    error = function(e) solve(V0 + 1e-8 * diag(p))
  )

    # E[log V] for V ~ GIG(k, chi, psi)
    gig_E_log <- function(k, chi, psi) {
    chi <- pmax(chi, 1e-14); psi <- pmax(psi, 1e-14)
    z   <- sqrt(chi * psi)
    eps <- 1e-6
    logK <- function(nu) {
        val <- besselK(z, nu = nu, expon.scaled = TRUE)
        log(pmax(val, 1e-300)) - z   # undo expon.scaled
    }
    dlogK <- (logK(k + eps) - logK(k - eps)) / (2 * eps)
    0.5 * (log(chi) - log(psi)) + dlogK
    }

  gig_moment <- function(k, chi, psi, r) {
    # E[v^r] = (sqrt(chi/psi))^r * K_{k+r}(sqrt(chi*psi))/K_k(sqrt(chi*psi))
    z <- sqrt(pmax(chi, 1e-14) * pmax(psi, 1e-14))
    num <- besselK(z, nu = k + r, expon.scaled = TRUE)
    den <- besselK(z, nu = k,     expon.scaled = TRUE)
    ratio <- num / den
    ratio[!is.finite(ratio)] <- 1
    pow   <- (sqrt(pmax(chi, 1e-14) / pmax(psi, 1e-14)))^r
    pmax(pow, 0) * pmax(ratio, 1e-300)
  }

  tn_moments <- function(mu, tau2) {
    tau <- sqrt(pmax(tau2, 1e-14))
    alpha <- mu / tau
    Phi <- stats::pnorm(alpha)
    Phi <- pmax(Phi, 1e-12)
    phi <- stats::dnorm(alpha)
    Lambda <- phi / Phi
    Es  <- mu + tau * Lambda
    Es2 <- tau2 + mu^2 + tau * mu * Lambda
    list(Es = Es, Es2 = Es2)
  }

  # compute xi's from Gaussian approx in (eta,ell)
  compute_xi_single <- function(eta_hat, ell_hat, Sigma, ns = n_samp_xi, base_Z = NULL) {
    ns <- max(1L, as.integer(ns))

    # draw (eta, ell) ~ N([eta_hat, ell_hat], Sigma)
    chol_U <- tryCatch(chol(Sigma), error = function(e) NULL)
    if (is.null(chol_U)) chol_U <- chol(Sigma + 1e-8 * diag(2))

    if (!is.null(base_Z)) {
      if (nrow(base_Z) != 2L) stop("base_Z must be a 2 x ns matrix.")
      if (ncol(base_Z) < ns) stop("base_Z does not contain enough draws.")
      Z <- base_Z[, seq_len(ns), drop = FALSE]
    } else {
      Z <- matrix(stats::rnorm(2 * ns), nrow = 2, ncol = ns)   # 2 x ns
    }
    pars <- sweep(chol_U %*% Z, 1, c(eta_hat, ell_hat), "+")  # 2 x ns
    eta  <- pars[1, ]
    ell  <- pars[2, ]

    gamma <- g_from_eta(eta)
    sigma <- sig_from_ell(ell)

    A   <- A_of(gamma)
    B   <- B_of(gamma)
    lam <- lam_of(gamma)

    xi1        <- mean(1 / (B * sigma))
    xi_lambda  <- mean(lam / B)
    xi_lambda2 <- mean((lam * lam) * sigma / B)
    xi_A       <- mean(A / (B * sigma))
    xi_A2      <- mean((A * A) / (B * sigma))
    xi_siginv  <- mean(exp(-ell))               # E[1/sigma]
    zeta_lam   <- mean((lam * A) / B)
    zeta_logJ     <- mean(.exal_static_ld_log_jacobian(eta, ell, L, U))
    zeta_logsigma <- mean(ell)
    zeta_logB     <- mean(log(pmax(B, 1e-300)))
    zeta_logpi    <- mean(vapply(gamma, log_prior_gamma, numeric(1)))

    list(
      xi1 = xi1,
      xi_lambda = xi_lambda,
      xi_lambda2 = xi_lambda2,
      xi_A = xi_A,
      xi_A2 = xi_A2,
      xi_siginv = xi_siginv,
      zeta_lam = zeta_lam,
      zeta_logJ = zeta_logJ,
      zeta_logsigma = zeta_logsigma,
      zeta_logB = zeta_logB,
      zeta_logpi = zeta_logpi
    )
  }

  compute_xi <- function(eta_hat, ell_hat, Sigma, ns = n_samp_xi, base_Z = NULL) {
    rep_count <- if (identical(ld_ctrl$xi_mode, "replicated")) {
      ld_ctrl$xi_replicates
    } else {
      1L
    }
    if (is.null(base_Z)) {
      base_list <- vector("list", rep_count)
    } else if (is.list(base_Z)) {
      base_list <- base_Z
    } else {
      base_list <- replicate(rep_count, base_Z, simplify = FALSE)
    }
    vals <- lapply(seq_len(rep_count), function(i) {
      compute_xi_single(
        eta_hat = eta_hat,
        ell_hat = ell_hat,
        Sigma = Sigma,
        ns = ns,
        base_Z = if (length(base_list) >= i) base_list[[i]] else NULL
      )
    })
    val_mat <- do.call(rbind, lapply(vals, .exal_static_ld_named_numeric))
    center <- colMeans(val_mat)
    mcse <- if (nrow(val_mat) >= 2L) {
      matrixStats::colSds(val_mat) / sqrt(nrow(val_mat))
    } else {
      rep(NA_real_, ncol(val_mat))
    }
    names(mcse) <- colnames(val_mat)
    list(
      value = as.list(center),
      mcse = as.list(mcse),
      replicate_count = nrow(val_mat),
      mcse_mean = if (all(is.na(mcse))) NA_real_ else mean(mcse, na.rm = TRUE),
      mcse_max = if (all(is.na(mcse))) NA_real_ else max(mcse, na.rm = TRUE)
    )
  }

  # log-kernel for q(sigma,gamma) as a function of (eta, ell)
  log_qsiggam <- function(par) {
    .exal_static_ld_log_qsiggam(
      par = par,
      state = list(
        y = y,
        X = X,
        n = n,
        m_beta = m_beta,
        V_beta = V_beta,
        E_inv_v = E_inv_v,
        E_v = E_v,
        E_s = E_s,
        E_s2 = E_s2,
        a_sigma = a_sigma,
        b_sigma = b_sigma,
        L = L,
        U = U,
        A_of = A_of,
        B_of = B_of,
        lam_of = lam_of,
        g_from_eta = g_from_eta,
        sig_from_ell = sig_from_ell,
        log_prior_gamma = log_prior_gamma
      ),
      include_jacobian = TRUE
    )
  }

  # find LD mode & covariance for (eta, ell)
  find_mode_ld <- function(eta0, ell0) {
    par0 <- c(eta0, ell0)
    fn_neg <- function(z) { val <- log_qsiggam(z); if (is.finite(val)) -val else 1e50 }
    cand <- rbind(
      par0,
      par0 + c(-1, 0), par0 + c(1, 0), par0 + c(0, -1), par0 + c(0, 1),
      par0 + c(-2, 0), par0 + c(2, 0), par0 + c(0, -2), par0 + c(0, 2)
    )
    vals <- apply(cand, 1, function(z) log_qsiggam(z))
    idx <- which(is.finite(vals))
    par_start <- if (length(idx)) cand[idx[which.max(vals[idx])], ] else par0
    used_fallback <- FALSE

    opt <- try(
      optim(
        par = par_start,
        fn = fn_neg,
        method = "BFGS",
        control = list(maxit = ld_ctrl$optimizer_maxit),
        hessian = TRUE
      ),
      silent = TRUE
    )
    if (inherits(opt, "try-error") || !is.finite(opt$value)) {
      used_fallback <- TRUE
      opt <- list(par = as.numeric(par_start), value = fn_neg(par_start), hessian = diag(2) * 1e-2, convergence = 1L)
    }
    H <- opt$hessian
    if (!all(is.finite(H)) || any(is.nan(H))) {
      # numeric Hessian as fallback
      H <- try(numDeriv::hessian(function(z) -log_qsiggam(z), x = opt$par), silent = TRUE)
      if (inherits(H, "try-error") || any(!is.finite(H))) {
        used_fallback <- TRUE
        H <- diag(2) * 1e-2
      }
    }
    H <- (H + t(H)) / 2
    reg <- .exal_static_ld_cov_from_precision(
      H,
      eig_floor = ld_ctrl$eig_floor,
      eig_cap = ld_ctrl$eig_cap
    )
    list(
      eta_hat = as.numeric(opt$par[1]),
      ell_hat = as.numeric(opt$par[2]),
      Sigma = reg$Sigma,
      objective = as.numeric(log_qsiggam(opt$par)),
      optim_convergence = if (!is.null(opt$convergence)) as.integer(opt$convergence)[1] else NA_integer_,
      used_fallback = used_fallback || isTRUE(reg$used_floor),
      hess_condition = reg$condition_raw,
      cov_condition = reg$condition_reg,
      cov_eig_min = min(reg$cov_eig_reg),
      cov_eig_max = max(reg$cov_eig_reg),
      cov_eig_raw_min = if (length(reg$cov_eig_raw)) min(reg$cov_eig_raw, na.rm = TRUE) else NA_real_,
      cov_eig_raw_max = if (length(reg$cov_eig_raw)) max(reg$cov_eig_raw, na.rm = TRUE) else NA_real_
    )
  }

  # --- main loop -------------------------------------------------------------
  t0 <- proc.time()[3]
  if (verbose) {
    cat(sprintf("Static exAL LDVB | n=%d, p=%d | max_iter=%d, tol=%.1e\n",
                n, p, max_iter, tol))
  }

  # initial xi from a tiny covariance (deterministic when base draws are reused)
  xis_eval <- compute_xi(
    eta_hat,
    ell_hat,
    Sig_eta_ell,
    ns = max(50L, floor(n_samp_xi / 2)),
    base_Z = ld_base_draws
  )
  xis <- xis_eval$value
  elbo_trace <- numeric(0)
  elbo_old   <- -Inf
  delta_beta <- numeric(0)
  delta_sigma <- numeric(0)
  delta_gamma <- numeric(0)
  delta_elbo <- numeric(0)
  ld_trace_rows <- vector("list", max_iter)
  stable_count <- 0L
  conv_ctrl <- .vb_joint_controls(tol_state = tol, has_gamma = TRUE)
  stop_reason <- "max_iter"
  converged <- FALSE
  for (iter in 1:max_iter) {
    prev_m_beta <- m_beta
    gamma_prev <- g_from_eta(eta_hat)
    sigma_prev <- exp(ell_hat)

    # ---- (1) q(beta) = N(m,V)
    # V = (V0^{-1} + xi1 * X^T diag(E[1/v]) X)^{-1}
    W <- xis$xi1 * E_inv_v
    Xw <- X * sqrt(W)
    V_inv <- crossprod(Xw) + V0_inv
    Uc <- tryCatch(chol(V_inv), error = function(e) NULL)
    if (is.null(Uc)) Uc <- chol(V_inv + 1e-10 * diag(p))
    V_beta_new <- chol2inv(Uc)

    # m = V ( V0^{-1} b0 + X^T [ xi1 diag(E[1/v]) y - xi_lambda (E[1/v] * E[s]) - xi_A 1 ] )
    rhs <- crossprod(X, W * y) -
           crossprod(X, (xis$xi_lambda * (E_inv_v * E_s))) 

    # Careful: The xi_A * 1_n term multiplies X^T * 1_n
    rhs <- rhs + (V0_inv %*% b0) - (xis$xi_A) * colSums(X)

    m_beta_new <- V_beta_new %*% rhs

    # ---- (2) q(v_i) = GIG(1/2, chi_i, psi)
    xb   <- drop(X %*% m_beta_new)
    t_i  <- y - xb
    q_i  <- rowSums((X %*% V_beta_new) * X)
    psi  <- xis$xi_A2 + 2 * xis$xi_siginv
    chi  <- xis$xi1 * (t_i^2 + q_i) -
            2 * xis$xi_lambda * (y * E_s) +
            xis$xi_lambda2 * E_s2 +
            2 * xis$xi_lambda * (xb * E_s)

    chi <- pmax(chi, 1e-12)
    psi <- max(psi, 1e-12)

    # moments
    E_v_new    <- gig_moment(k = 0.5, chi = chi, psi = psi, r = 1)
    E_inv_v_new<- gig_moment(k = 0.5, chi = chi, psi = psi, r = -1)

    # ---- (3) q(s_i) = TN(mu, tau^2) on (0, Inf)
    tau2  <- 1 / (1 + xis$xi_lambda2 * E_inv_v_new)
    mu_s  <- tau2 * ( xis$xi_lambda * (E_inv_v_new * (y - xb)) - xis$zeta_lam )
    s_mom <- tn_moments(mu_s, tau2)

    # ---- (4) q(sigma,gamma) via LD
    eta_prev <- eta_hat
    ell_prev <- ell_hat
    Sigma_prev <- Sig_eta_ell
    ld <- find_mode_ld(eta_hat, ell_hat)
    eta_hat <- .exal_static_ld_mix_step(
      old = eta_prev,
      new = ld$eta_hat,
      damping = ld_ctrl$damping,
      step_cap = ld_ctrl$step_cap_eta
    )
    ell_hat <- .exal_static_ld_mix_step(
      old = ell_prev,
      new = ld$ell_hat,
      damping = ld_ctrl$damping,
      step_cap = ld_ctrl$step_cap_ell
    )
    Sigma_mix <- (1 - ld_ctrl$damping) * Sigma_prev + ld_ctrl$damping * ld$Sigma
    Sig_eta_ell <- .exal_static_ld_regularize_cov(
      Sigma_mix,
      eig_floor = ld_ctrl$eig_floor,
      eig_cap = ld_ctrl$eig_cap
    )$Sigma

    # update xi via MC under Gaussian (eta,ell)
    xis_eval_raw <- compute_xi(
      eta_hat,
      ell_hat,
      Sig_eta_ell,
      ns = n_samp_xi,
      base_Z = ld_base_draws
    )
    xis_raw <- xis_eval_raw$value
    xis_new <- .exal_static_ld_mix_numeric_lists(xis, xis_raw, damping = ld_ctrl$xi_damping)

    # ---- check convergence
    rel_mb <- sqrt(sum((m_beta_new - m_beta)^2)) / (1e-8 + sqrt(sum(m_beta^2)))
    rel_xi <- .exal_static_ld_rel_change(
      .exal_static_ld_named_numeric(xis_raw),
      .exal_static_ld_named_numeric(xis)
    )
    eta_step_raw <- as.numeric(ld$eta_hat - eta_prev)
    ell_step_raw <- as.numeric(ld$ell_hat - ell_prev)
    eta_step_used <- as.numeric(eta_hat - eta_prev)
    ell_step_used <- as.numeric(ell_hat - ell_prev)

    if (verbose && (iter %% 50 == 0)) {
      ghat <- g_from_eta(eta_hat); shat <- exp(ell_hat)
      cat(sprintf(
        "iter %4d | rel(mb)=%.2e rel(xi)=%.2e | gamma~%.3f sigma~%.3f | ld(raw)=%.2e/%.2e used=%.2e/%.2e\n",
        iter, rel_mb, rel_xi, ghat, shat, eta_step_raw, ell_step_raw, eta_step_used, ell_step_used
      ))
    }

    # commit new values
    m_beta <- as.numeric(m_beta_new); V_beta <- V_beta_new
    E_v    <- as.numeric(E_v_new);    E_inv_v <- as.numeric(E_inv_v_new)
    qs_mu  <- as.numeric(mu_s);       qs_tau2 <- as.numeric(tau2)
    E_s    <- as.numeric(s_mom$Es);   E_s2    <- as.numeric(s_mom$Es2)
    xis    <- xis_new

    ## ---------- ELBO (term-by-term) ------------------------------------------
    # Precompute residual pieces
    xb  <- drop(X %*% m_beta)
    t_i <- y - xb
    q_i <- rowSums((X %*% V_beta) * X)

    # GIG bits
    k_gig <- 0.5
    mlogv <- gig_E_log(k_gig, chi, psi)

    # (1) Likelihood: normalizers
    lik_norm <- -(n/2) * log(2*pi) -
                (n/2) * xis$zeta_logB -
                (n/2) * xis$zeta_logsigma -
                0.5   * sum(mlogv)

    # (2) Likelihood: quadratic part 1
    lik_quad1 <- -0.5 * sum(
    xis$xi1     * E_inv_v * (t_i^2 + q_i) -
    2 * xis$xi_A          *  t_i           +
        xis$xi_A2 * E_v
    )

    # (3) Likelihood: cross & s^2 terms
    lik_cross <- sum(
    xis$xi_lambda  * (E_s * E_inv_v * t_i) -
    xis$zeta_lam   *  E_s                   -
    0.5 * xis$xi_lambda2 * (E_s2 * E_inv_v)
    )

    # (4) E[log p(v | sigma)] with v_i ~ Exp(rate = 1/sigma)
    E_log_pv <- - n * xis$zeta_logsigma - xis$xi_siginv * sum(E_v)

    # (5) E[log p(s)] for s_i ~ N^+(0,1)
    E_log_ps <- n * log(2) - (n/2) * log(2*pi) - 0.5 * sum(E_s2)

    # (6) E[log p(beta)] : Normal(b0, V0)
    logdetV0 <- as.numeric(determinant(V0, logarithm = TRUE)$modulus)
    E_log_pb <- - (p/2) * log(2*pi) - 0.5 * logdetV0 -
                0.5 * ( sum(V0_inv * V_beta) +
                        drop(crossprod(m_beta - b0, V0_inv %*% (m_beta - b0))) )

    # (7) E[log p(sigma)] : IG(a_sigma, b_sigma)
    E_log_psig <- a_sigma * log(b_sigma) - lgamma(a_sigma) -
                (a_sigma + 1) * xis$zeta_logsigma - b_sigma * xis$xi_siginv

    # (8) E[log p(gamma)]
    E_log_pgam <- xis$zeta_logpi

    # (9) Entropy H(q(beta))
    logdetVb <- as.numeric(determinant(V_beta, logarithm = TRUE)$modulus)
    H_qb <- 0.5 * ( p * (1 + log(2*pi)) + logdetVb )

    # (10) Entropy H(q(v))
    z      <- sqrt(pmax(chi, 1e-14) * pmax(psi, 1e-14))
    logKk  <- log(pmax(besselK(z, nu = k_gig, expon.scaled = TRUE), 1e-300)) - z
    logC   <- (k_gig/2) * (log(pmax(psi,1e-14)) - log(pmax(chi,1e-14))) - log(2) - logKk
    H_qv   <- sum( -logC - (k_gig - 1) * mlogv + 0.5 * (chi * E_inv_v + psi * E_v) )

    # (11) Entropy H(q(s)) for TN(mu, tau^2) on (0, Inf)
    tau    <- sqrt(pmax(qs_tau2, 1e-14))
    alpha  <- qs_mu / tau
    Phi    <- pmax(stats::pnorm(alpha), 1e-12)
    Lambda <- stats::dnorm(alpha) / Phi
    H_qs   <- sum( 0.5 * log(2*pi * qs_tau2) + log(Phi) + 0.5 * (1 + alpha * Lambda) )

    # (12) H(q(sigma,gamma)) = H(q(eta,ell)) + E_q[log|J(eta,ell)|]
    # for sigma=exp(ell), gamma=L+(U-L)logit^{-1}(eta).
    logdetSig <- as.numeric(determinant(Sig_eta_ell, logarithm = TRUE)$modulus)
    H_qsg     <- 0.5 * ( 2 * (1 + log(2*pi)) + logdetSig ) + xis$zeta_logJ

    # Put it together
    elbo_new <- lik_norm + lik_quad1 + lik_cross +
                E_log_pv + E_log_ps + E_log_pb + E_log_psig + E_log_pgam +
                H_qb + H_qv + H_qs + H_qsg
    elbo_trace <- c(elbo_trace, elbo_new)

    gamma_cur <- g_from_eta(eta_hat)
    sigma_cur <- exp(ell_hat)
    d_beta <- max(abs(m_beta_new - prev_m_beta))
    d_sigma <- abs(sigma_cur - sigma_prev)
    d_gamma <- abs(gamma_cur - gamma_prev)
    d_elbo <- if (iter >= 2L) elbo_new - elbo_old else NA_real_
    step <- .vb_joint_step(
      iter = iter,
      d_state = d_beta,
      d_sigma = d_sigma,
      d_gamma = d_gamma,
      d_elbo = d_elbo,
      controls = conv_ctrl,
      compute_elbo = TRUE,
      stable_count = stable_count
    )
    stable_count <- step$stable_count
    delta_beta <- c(delta_beta, d_beta)
    delta_sigma <- c(delta_sigma, d_sigma)
    delta_gamma <- c(delta_gamma, d_gamma)
    delta_elbo <- c(delta_elbo, d_elbo)
    if (isTRUE(ld_ctrl$store_trace)) {
      ld_trace_rows[[iter]] <- data.frame(
        iter = iter,
        eta = eta_hat,
        ell = ell_hat,
        gamma = gamma_cur,
        sigma = sigma_cur,
        eta_raw = ld$eta_hat,
        ell_raw = ld$ell_hat,
        eta_step_raw = eta_step_raw,
        ell_step_raw = ell_step_raw,
        eta_step_used = eta_step_used,
        ell_step_used = ell_step_used,
        xi_rel_drift = rel_xi,
        xi_mcse_mean = as.numeric(xis_eval_raw$mcse_mean)[1],
        xi_mcse_max = as.numeric(xis_eval_raw$mcse_max)[1],
        xi_replicates = as.integer(xis_eval_raw$replicate_count)[1],
        ld_objective = ld$objective,
        ld_optim_convergence = ld$optim_convergence,
        ld_used_fallback = isTRUE(ld$used_fallback),
        ld_hess_condition = ld$hess_condition,
        ld_cov_condition = ld$cov_condition,
        ld_cov_eig_min = ld$cov_eig_min,
        ld_cov_eig_max = ld$cov_eig_max,
        delta_state = d_beta,
        delta_sigma = d_sigma,
        delta_gamma = d_gamma,
        delta_elbo = d_elbo,
        stringsAsFactors = FALSE
      )
    }

    if (verbose && (iter %% 50 == 0)) {
      cat(sprintf(
        "    ELBO=%.6f | d_beta=%.3e d_sigma=%.3e d_gamma=%.3e d_elbo=%.3e | cond=%.3e stable=%d/%d\n",
        elbo_new, d_beta, d_sigma, d_gamma, d_elbo, ld$cov_condition, stable_count, conv_ctrl$patience
      ))
    }

    if (step$stop_now) {
      converged <- TRUE
      stop_reason <- "joint_converged"
      break
    }

    elbo_old <- elbo_new

  }

  t1 <- proc.time()[3]

  # approximate means for gamma, sigma from LD mode
  gamma_mean <- g_from_eta(eta_hat)
  sigma_mean <- exp(ell_hat)
  mode_quality <- .exal_static_ld_mode_quality(
    log_q_fn = log_qsiggam,
    par = c(eta_hat, ell_hat),
    grad_tol = ld_ctrl$mode_grad_tol,
    min_eig = ld_ctrl$mode_min_eig
  )
  ld_trace_df <- if (isTRUE(ld_ctrl$store_trace)) {
    keep <- Filter(Negate(is.null), ld_trace_rows[seq_len(iter)])
    if (length(keep)) do.call(rbind, keep) else data.frame()
  } else {
    data.frame()
  }

  ret <- list(
    qbeta = list(m = m_beta, V = V_beta),
    qv    = list(chi = chi, psi = psi, E_v = E_v, E_inv_v = E_inv_v),
    qs    = list(mu = qs_mu, tau2 = qs_tau2, E_s = E_s, E_s2 = E_s2),
    qsiggam = list(
      eta_hat = eta_hat, ell_hat = ell_hat, Sigma = Sig_eta_ell,
      gamma_mean = gamma_mean, sigma_mean = sigma_mean,
      xi = xis
    ),
    converged = converged,
    iter = iter,
    run.time = as.numeric(t1 - t0),
    misc = list(p0 = p0, bounds = c(L = L, U = U), n = n, p = p, elbo = elbo_trace),
    diagnostics = list(
      elbo = elbo_trace,
      convergence = list(
        converged = converged,
        stop_reason = stop_reason,
        iter = iter,
        stable_count = stable_count,
        criteria = conv_ctrl,
        final = list(
          delta_state = if (length(delta_beta)) utils::tail(delta_beta, 1L) else NA_real_,
          delta_sigma = if (length(delta_sigma)) utils::tail(delta_sigma, 1L) else NA_real_,
          delta_gamma = if (length(delta_gamma)) utils::tail(delta_gamma, 1L) else NA_real_,
          delta_elbo = if (length(delta_elbo)) utils::tail(delta_elbo, 1L) else NA_real_
        )
      ),
      deltas = list(
        state = delta_beta,
        sigma = delta_sigma,
        gamma = delta_gamma,
        elbo = delta_elbo
      ),
      ld_block = list(
        controls = ld_ctrl,
        trace = ld_trace_df,
        xi = list(
          mode = ld_ctrl$xi_mode,
          replicates = ld_ctrl$xi_replicates,
          reuse_draws = ld_ctrl$reuse_draws,
          reuse_seed = ld_ctrl$reuse_seed
        ),
        mode_quality = mode_quality
      )
    )
  )
  class(ret) <- "exal_ldvb"
  if (verbose) {
    cat(sprintf("LDVB %s in %d iters (%.2fs): gamma~%.3f, sigma~%.3f\n",
                ifelse(converged, "converged", "stopped"),
                iter, ret$run.time, ret$qsiggam$gamma_mean, ret$qsiggam$sigma_mean))
  }
  ret
}

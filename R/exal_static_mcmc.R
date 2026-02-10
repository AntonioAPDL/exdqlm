# R/exal_static_mcmc.R
#
# GIG parameterization used here:
#   Math:  GIG(k, chi, psi) proportional to z^{k-1} exp( - (chi/z + psi z)/2 )
#   C++ :  sample_gig_devroye(p, a, b) has density proportional to x^{p-1} exp( - (a x + b/x)/2 )
#   Map :  p = k, a = psi, b = chi
#
#' exAL (static) - MCMC algorithm
#'
#' Applies a Gibbs sampler for the static Extended Asymmetric Laplace regression
#' (exAL). We update \eqn{\beta, v, s, \sigma} from their full conditionals and
#' draw \eqn{\gamma} via a Laplace-Delta step on a logit transform of (L, U).
#'
#' @param y Numeric vector of length \eqn{n}.
#' @param X Numeric matrix \eqn{n \times p} (design).
#' @param p0 Quantile level in \((0,1)\).
#' @param b0,V0 Prior mean and covariance for \eqn{\beta} (Normal). Defaults:
#'   \eqn{b_0=\mathbf{0}_p}, \eqn{V_0=10^6 I_p}.
#' @param a_sigma,b_sigma Hyperparameters for \(\sigma \sim \mathrm{IG}(a_\sigma,b_\sigma)\)
#'   with density \(p(\sigma)\propto \sigma^{-(a_\sigma+1)}\exp(-b_\sigma/\sigma)\).
#' @param gamma_bounds Numeric length-2 vector \((L,U)\) for \(\gamma\).
#'   Defaults to \code{c(L.fn(p0), U.fn(p0))}.
#' @param log_prior_gamma Function \code{function(g) log pi(g)} for \(\gamma\) on \((L,U)\).
#'   Default is flat (returns 0).
#' @param init Optional list with starting values: \code{beta}, \code{sigma}, \code{gamma},
#'   \code{v} (length \eqn{n}), \code{s} (length \eqn{n}). Missing pieces are filled sensibly.
#' @param n.burn Number of burn-in iterations. Default \code{2000}.
#' @param n.mcmc Number of kept MCMC iterations (after burn). Default \code{1500}.
#' @param thin Save every \code{thin}-th iteration after burn. We internally run
#'   \code{n.burn + n.mcmc * thin} iterations to return exactly \code{n.mcmc} saved draws.
#' @param verbose Print progress every 500 iters.
#'
#' @return A list with:
#' \itemize{
#'   \item \code{run.time} - total wall time in seconds.
#'   \item \code{X}, \code{p0}, \code{bounds} - design, quantile, and (L, U).
#'   \item \code{samp.beta} - posterior sample of \code{beta} as \code{coda::mcmc} (n.mcmc x p).
#'   \item \code{samp.sigma} - posterior sample of \code{sigma} as \code{coda::mcmc}.
#'   \item \code{samp.gamma} - posterior sample of \code{gamma} as \code{coda::mcmc}.
#'   \item \code{samp.v} - latent \code{v} draws (n x n.mcmc) as \code{coda::mcmc}.
#'   \item \code{samp.s} - latent \code{s} draws (n x n.mcmc) as \code{coda::mcmc}.
#'   \item \code{last} - last state of the chain (useful for restarts).
#' }
#' @export
#'
#' @examples
#' \donttest{
#' set.seed(123)
#' n <- 200; p <- 3
#' X <- cbind(1, rnorm(n), rnorm(n))
#' beta0 <- c(0.5, -1, 0.8); sigma0 <- 1.2
#' y <- as.numeric(X %*% beta0 + rnorm(n, 0, sigma0))
#' fit <- exal_static_mcmc(
#'   y, X, p0 = 0.5, n.burn = 1000, n.mcmc = 1000, thin = 1, verbose = TRUE
#' )
#' summary(fit$samp.beta)
#' }
exal_static_mcmc <- function(
  y, X, p0,
  b0 = NULL, V0 = NULL,
  a_sigma = 1, b_sigma = 1,
  gamma_bounds = c(L.fn(p0), U.fn(p0)),
  log_prior_gamma = function(g) 0,
  init = NULL,
  n.burn = 2000, n.mcmc = 1500, thin = 1,
  verbose = TRUE
){
  ## --- checks (mirror exdqlmMCMC style) ------------------------------------
  y <- as.numeric(y)
  X <- as.matrix(X); storage.mode(X) <- "double"
  n <- length(y); p <- ncol(X)
  if (nrow(X) != n) stop("nrow(X) must match length(y).")
  if (!(p0 > 0 && p0 < 1)) stop("p0 must be in (0,1).")
  if (n.burn < 0 || n.mcmc <= 0 || thin < 1) stop("n.burn>=0, n.mcmc>0, thin>=1 required.")

  if (is.null(b0)) b0 <- rep(0, p)
  if (is.null(V0)) V0 <- diag(1e6, p)
  V0 <- as.matrix(V0)
  if (!all(dim(V0) == c(p, p))) stop("V0 must be p x p.")

  L <- gamma_bounds[1]; U <- gamma_bounds[2]
  if (!(L < U)) stop("gamma_bounds must satisfy L < U.")

  ## --- shorthands for A,B,C,lambda -----------------------------------------
  A_of   <- function(g) A.fn(p0, g)
  B_of   <- function(g) B.fn(p0, g)
  C_of   <- function(g) C.fn(p0, g)
  lam_of <- function(g) C_of(g) * abs(g)

  ## --- storage (post-burn) --------------------------------------------------
  n_save <- n.mcmc
  save.beta  <- matrix(NA_real_, n_save, p)
  save.sigma <- numeric(n_save)
  save.gamma <- numeric(n_save)
  save.v     <- matrix(NA_real_, n, n_save)
  save.s     <- matrix(NA_real_, n, n_save)

  ## --- initialize -----------------------------------------------------------
  beta  <- if (is.null(init$beta))  rep(0, p) else as.numeric(init$beta)
  sigma <- if (is.null(init$sigma)) 1        else as.numeric(init$sigma)[1]
  gamma <- if (is.null(init$gamma)) 0        else as.numeric(init$gamma)[1]
  gamma <- min(max(gamma, L + 1e-6), U - 1e-6)

  A <- A_of(gamma); B <- B_of(gamma); lambda <- lam_of(gamma)

  v <- if (is.null(init$v)) rep(1, n) else as.numeric(init$v)
  if (length(v) != n) v <- rep(v[1], n)
  s <- if (is.null(init$s)) abs(stats::rnorm(n)) else pmax(0, as.numeric(init$s))

  V0_inv <- tryCatch(
    solve(V0),
    error = function(e) solve(V0 + 1e-8 * diag(p))
  )

  ## --- helpers (keep names tidy like exdqlmMCMC) ---------------------------
  rnorm_mv <- function(mu, Sigma) {
    mu <- as.numeric(mu)
    U  <- tryCatch(chol(Sigma), error = function(e) NULL)
    if (is.null(U)) U <- chol(Sigma + 1e-10 * diag(nrow(Sigma)))
    as.numeric(mu + t(U) %*% stats::rnorm(length(mu)))
  }

  # eta <-> gamma transform on (L,U)
  g_from_eta <- function(eta) {
    s <- stats::plogis(eta); s <- pmin(pmax(s, 1e-12), 1 - 1e-12)
    L + (U - L) * s
  }
  logJ <- function(eta) {
    s <- stats::plogis(eta); s <- pmin(pmax(s, 1e-12), 1 - 1e-12)
    log(U - L) + log(s) + log1p(-s)
  }

  # log posterior in eta (gamma) kernel
  logpost_eta <- function(eta, beta, sigma, v, s_vec) {
    eta   <- as.numeric(eta)[1L]
    beta  <- as.numeric(beta); v <- as.numeric(v); s_vec <- as.numeric(s_vec)
    if (!all(is.finite(c(beta, sigma, v, s_vec)))) return(-Inf)
    if (sigma <= 0 || any(v <= 0)) return(-Inf)

    xb <- drop(X %*% beta); if (!all(is.finite(xb))) return(-Inf)
    g   <- g_from_eta(eta)
    A   <- as.numeric(A_of(g))[1L]
    B   <- as.numeric(B_of(g))[1L]
    lam <- as.numeric(lam_of(g))[1L]
    if (!is.finite(B) || B <= 0) return(-Inf)

    mu   <- xb + lam * sigma * s_vec + A * v
    res  <- y - mu
    quad <- sum((res * res) / (B * sigma * v))
    if (!is.finite(quad)) return(-Inf)

    -(n / 2) * log(B) - 0.5 * quad + log_prior_gamma(g) + logJ(eta)
  }

  # robust mode finder in eta (matches dynamic style of small utilities)
  find_mode_eta <- function(eta0, beta, sigma, v, s_vec) {
    fn_log <- function(e) {
      val <- logpost_eta(e, beta, sigma, v, s_vec)
      if (!is.finite(val)) -Inf else val
    }
    fn_neg <- function(e) {
      val <- fn_log(e)
      if (!is.finite(val)) 1e50 else -val
    }
    base   <- as.numeric(eta0)[1L]
    starts <- c(base, base + c(-1,1,-2,2,-4,4,-8,8), 0)
    starts <- pmin(pmax(starts, -20), 20)
    cand   <- unique(starts)
    vals   <- sapply(cand, fn_log)
    idx    <- which(is.finite(vals))
    eta_start <- if (length(idx)) cand[idx[which.max(vals[idx])]] else 0

    opt <- try(
      optim(par = eta_start, fn = fn_neg, method = "BFGS",
            control = list(maxit = 200), hessian = TRUE),
      silent = TRUE
    )
    if (inherits(opt, "try-error") || !is.finite(opt$value)) {
      return(list(eta_hat = eta_start, info = 1e-4))
    }
    eta_hat <- as.numeric(opt$par)

    info_try <- try(-as.numeric(numDeriv::hessian(fn_log, x = eta_hat)),
                    silent = TRUE)
    info <- if (is.finite(info_try) && info_try > 0) info_try
            else if (!is.null(opt$hessian)) as.numeric(opt$hessian)
            else 1e-4
    if (!is.finite(info) || info <= 0) info <- 1e-4
    list(eta_hat = eta_hat, info = info)
  }

  # initialize eta from current gamma
  eta <- stats::qlogis((gamma - L) / (U - L))

  ## --- main loop (burn + mcmc, prints like exdqlmMCMC) ---------------------
  I <- n.burn + n.mcmc * thin
  if (verbose) {
    cat(sprintf("Static exAL MCMC | n=%d, p=%d | burn=%d, keep=%d, thin=%d\n",
                n, p, n.burn, n.mcmc, thin))
  }

  tictoc::tic()
  ksave <- 0L
  for (i in 1:I) {

    ## (1) v | rest ~ GIG(1/2, chi_i, psi)
    z     <- y - drop(X %*% beta) - lambda * sigma * s
    chi_i <- (z * z) / (B * sigma)
    psi_i <- (A * A) / (B * sigma) + (2 / sigma)
    v     <- as.numeric(sample_gig_devroye_vector(
               1L, p = 0.5, a = psi_i, b_vec = chi_i
             )[1, ])
    v <- pmax(v, 1e-12)

    ## (2) s | rest ~ N^+(mu, tau^2), truncated to (0, Inf)
    r     <- y - drop(X %*% beta) - A * v
    tau2  <- 1 / (1 + (lambda * lambda) * sigma / (B * v))    # correct form
    tau2  <- pmax(tau2, 1e-12)
    mu_s  <- tau2 * (lambda * r) / (B * v)
    s     <- as.numeric(sample_truncnorm(1L, n, sts_mu = mu_s, sts_sig2 = tau2)[1, ])

    ## (3) beta | rest ~ N(m, V) with W = diag(1/(B sigma v))
    W_diag <- 1 / (B * sigma * v)
    Xw     <- X * sqrt(W_diag)
    V_inv  <- crossprod(Xw) + V0_inv
    y_star <- y - lambda * sigma * s - A * v
    rhs    <- crossprod(X, W_diag * y_star) + V0_inv %*% b0

    Uc    <- tryCatch(chol(V_inv), error = function(e) NULL)
    if (is.null(Uc)) Uc <- chol(V_inv + 1e-10 * diag(p))
    m_beta <- backsolve(Uc, forwardsolve(t(Uc), rhs))
    beta   <- as.numeric(m_beta + backsolve(Uc, stats::rnorm(p)))

    ## (4) sigma | rest ~ GIG(k_sigma, chi_sigma, psi_sigma)
    r          <- y - drop(X %*% beta) - A * v
    chi_sigma  <- sum((r * r) / (B * v)) + 2 * sum(v) + 2 * b_sigma
    psi_sigma  <- (lambda * lambda / B) * sum((s * s) / v)
    k_sigma    <- -(a_sigma + 1.5 * n)
    sigma_new  <- as.numeric(sample_gig_devroye_vector(
                     1L, p = k_sigma, a = psi_sigma, b_vec = chi_sigma
                   )[1, 1])
    if (is.finite(sigma_new) && sigma_new > 0) sigma <- sigma_new

    ## (5) gamma | rest via Laplace-Delta in eta
    mode_out <- find_mode_eta(eta, beta, sigma, v, s)
    eta      <- stats::rnorm(1, mean = mode_out$eta_hat, sd = sqrt(1 / mode_out$info))
    gamma    <- g_from_eta(eta)
    A <- A_of(gamma); B <- B_of(gamma); lambda <- lam_of(gamma)

    ## save after burn every 'thin' iterations
    if (i > n.burn && ((i - n.burn) %% thin == 0)) {
      ksave <- ksave + 1L
      save.beta[ksave, ] <- beta
      save.sigma[ksave]  <- sigma
      save.gamma[ksave]  <- gamma
      save.v[, ksave]    <- v
      save.s[, ksave]    <- s
    }

    if (verbose && (i %% 500 == 0)) {
      cat(sprintf("%s iteration %d | sigma=%.3f | gamma=%.3f\n",
                  ifelse(i <= n.burn, "burn-in", "MCMC"), i, sigma, gamma))
    }
  }
  run.time <- tictoc::toc(quiet = TRUE)
  if (verbose) {
    cat(sprintf("MCMC complete: %d iterations, %.3f seconds\n",
                I, run.time$toc - run.time$tic))
  }

  ## --- return (match exdqlmMCMC style) -------------------------------------
  ret <- list(
    run.time   = (run.time$toc - run.time$tic),
    X          = X,
    p0         = p0,
    bounds     = c(L = L, U = U),
    samp.beta  = coda::as.mcmc(save.beta),
    samp.sigma = coda::as.mcmc(save.sigma),
    samp.gamma = coda::as.mcmc(save.gamma),
    samp.v     = coda::as.mcmc(t(save.v)),  # coda expects iterations in rows
    samp.s     = coda::as.mcmc(t(save.s)),
    last = list(beta = beta, sigma = sigma, gamma = gamma, v = v, s = s)
  )
  class(ret) <- "exal_static_mcmc"
  ret
}

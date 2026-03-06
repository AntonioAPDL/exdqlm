# R/exal_static_mcmc.R
#
# GIG parameterization used here:
#   Math:  GIG(k, chi, psi) proportional to z^{k-1} exp( - (chi/z + psi z)/2 )
#   C++ :  sample_gig_devroye(p, a, b) has density proportional to x^{p-1} exp( - (a x + b/x)/2 )
#   Map :  p = k, a = psi, b = chi
#
#' exAL (static) - MCMC algorithm
#'
#' The function applies a Gibbs sampler for static Extended Asymmetric Laplace regression
#' (exAL). We update \eqn{\beta, v, s, \sigma} from their full conditionals and
#' update \eqn{\gamma} on the transformed logit scale using either the legacy
#' Laplace-local draw or an adaptive random-walk MH kernel.
#'
#' @param y Numeric vector of length \eqn{n}.
#' @param X Numeric matrix \eqn{n \times p} (design).
#' @param p0 Quantile level in \eqn{(0,1)}.
#' @param b0,V0 Prior mean and covariance for \eqn{\beta} (Normal). Defaults:
#'   \eqn{b_0=\mathbf{0}_p}, \eqn{V_0=10^6 I_p}.
#' @param a_sigma,b_sigma Hyperparameters for an inverse-gamma prior on
#'   \code{sigma}, with density proportional to
#'   \code{sigma^{-(a_sigma+1)} exp(-b_sigma/sigma)}.
#' @param gamma_bounds Numeric length-2 vector (L, U) for \code{gamma}.
#'   Defaults to \code{c(L.fn(p0), U.fn(p0))}.
#' @param log_prior_gamma Function \code{function(g) log pi(g)} for \code{gamma}
#'   on (L, U).
#'   Default is flat (returns 0).
#' @param init Optional list with starting values: \code{beta}, \code{sigma}, \code{gamma},
#'   \code{v} (length \eqn{n}), \code{s} (length \eqn{n}). Missing pieces are filled sensibly.
#' @param dqlm.ind Logical; if \code{TRUE}, fit the reduced AL model (DQLM, \code{gamma=0})
#'   with conjugate Gibbs updates for \code{beta}, \code{sigma}, and \code{v} only.
#' @param n.burn Number of burn-in iterations. Default \code{2000}.
#' @param n.mcmc Number of kept MCMC iterations (after burn). Default \code{1500}.
#' @param thin Integer; save every \code{thin}-th iteration after burn. We internally run
#'   \code{n.burn + n.mcmc * thin} iterations to return exactly \code{n.mcmc} saved draws.
#' @param init.from.vb Logical; if \code{TRUE}, run static VB first and use its
#'   posterior moments as MCMC initialization.
#' @param vb_init_controls Optional list controlling VB warm start. Supported keys:
#'   \code{max_iter}, \code{tol}, \code{n_samp_xi}, \code{verbose}.
#' @param mh.proposal Character string controlling the exAL gamma update kernel.
#'   \code{"laplace_local"} reproduces the previous Laplace-local draw.
#'   \code{"laplace_rw"} initializes a random-walk MH scale from local curvature
#'   and adapts it during burn-in. \code{"rw"} uses adaptive random-walk MH
#'   without Laplace scaling. Only \code{"rw"} and \code{"laplace_rw"} are
#'   exact posterior kernels for the \code{gamma} update; \code{"laplace_local"}
#'   is approximate and should not be treated as signoff-ready.
#' @param mh.adapt Logical; adapt the random-walk proposal scale during burn-in.
#'   Ignored for \code{"laplace_local"}.
#' @param mh.adapt.interval Integer adaptation window for RW-based kernels.
#' @param mh.target.accept Numeric length-2 target acceptance band.
#' @param mh.scale.bounds Numeric length-2 lower/upper bounds for RW proposal scale.
#' @param mh.max_scale.step Numeric multiplicative adaptation cap in \code{(0,1)}.
#' @param mh.min_burn_adapt Integer minimum burn-in before adaptation starts.
#' @param verbose Print progress every 500 iters.
#'
#' @return A object of class "\code{exal_mcmc}" containing:
#' \itemize{
#'   \item \code{run.time} - total wall time in seconds.
#'   \item \code{X}, \code{p0}, \code{bounds} - design, quantile, and (L, U).
#'   \item \code{samp.beta} - posterior sample of \code{beta} as \code{coda::mcmc} (n.mcmc x p).
#'   \item \code{samp.sigma} - posterior sample of \code{sigma} as \code{coda::mcmc}.
#'   \item \code{samp.gamma} - posterior sample of \code{gamma} as \code{coda::mcmc}.
#'   \item \code{samp.v} - latent \code{v} draws as \code{coda::mcmc} (\code{n.mcmc x n}).
#'   \item \code{samp.s} - latent \code{s} draws as \code{coda::mcmc} (\code{n.mcmc x n}).
#'   \item \code{mh.diagnostics} - proposal kernel diagnostics for the exAL gamma update,
#'         including whether the saved kernel is exact/signoff-ready.
#'   \item \code{last} - last state of the chain (useful for restarts).
#' }
#' @export
#'
#' @examples
#' \donttest{
#' set.seed(123)
#' n <- 80; p <- 3
#' X <- cbind(1, rnorm(n), rnorm(n))
#' beta0 <- c(0.5, -1, 0.8); sigma0 <- 1.2
#' y <- as.numeric(X %*% beta0 + rnorm(n, 0, sigma0))
#' fit <- exal_static_mcmc(
#'   y, X, p0 = 0.5, n.burn = 200, n.mcmc = 200, thin = 1, verbose = FALSE
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
  dqlm.ind = FALSE,
  n.burn = 2000, n.mcmc = 1500, thin = 1,
  init.from.vb = FALSE,
  vb_init_controls = NULL,
  mh.proposal = c("laplace_local", "laplace_rw", "rw"),
  mh.adapt = TRUE,
  mh.adapt.interval = 50L,
  mh.target.accept = c(0.20, 0.45),
  mh.scale.bounds = c(0.1, 10),
  mh.max_scale.step = 0.35,
  mh.min_burn_adapt = 50L,
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
  mh.proposal <- match.arg(mh.proposal)
  mh.adapt <- isTRUE(mh.adapt)
  mh.adapt.interval <- suppressWarnings(as.integer(mh.adapt.interval)[1])
  if (!is.finite(mh.adapt.interval) || mh.adapt.interval < 5L) mh.adapt.interval <- 50L
  mh.min_burn_adapt <- suppressWarnings(as.integer(mh.min_burn_adapt)[1])
  if (!is.finite(mh.min_burn_adapt) || mh.min_burn_adapt < 20L) mh.min_burn_adapt <- 50L
  if (length(mh.target.accept) != 2L) mh.target.accept <- c(0.20, 0.45)
  mh.target.accept <- sort(pmin(pmax(as.numeric(mh.target.accept), 0.01), 0.99))
  if (length(mh.scale.bounds) != 2L) mh.scale.bounds <- c(0.1, 10)
  mh.scale.bounds <- sort(as.numeric(mh.scale.bounds))
  if (!all(is.finite(mh.scale.bounds)) || mh.scale.bounds[1] <= 0 || mh.scale.bounds[2] <= mh.scale.bounds[1]) {
    mh.scale.bounds <- c(0.1, 10)
  }
  mh_max_scale_step <- as.numeric(mh.max_scale.step)[1]
  if (!is.finite(mh_max_scale_step) || mh_max_scale_step <= 0 || mh_max_scale_step >= 1) {
    mh_max_scale_step <- 0.35
  }
  if (n.burn < mh.min_burn_adapt) mh.adapt <- FALSE

  if (is.null(init)) init <- list()
  if (isTRUE(init.from.vb)) {
    vb.ctrl.default <- list(
      max_iter = 500L,
      tol = 1e-4,
      n_samp_xi = 200L,
      verbose = FALSE
    )
    if (is.null(vb_init_controls)) vb_init_controls <- list()
    vb.ctrl <- utils::modifyList(vb.ctrl.default, vb_init_controls)
    vb.ctrl$max_iter <- suppressWarnings(as.integer(vb.ctrl$max_iter)[1])
    if (!is.finite(vb.ctrl$max_iter) || vb.ctrl$max_iter < 10L) vb.ctrl$max_iter <- 500L
    vb.ctrl$tol <- as.numeric(vb.ctrl$tol)[1]
    if (!is.finite(vb.ctrl$tol) || vb.ctrl$tol <= 0) vb.ctrl$tol <- 1e-4
    vb.ctrl$n_samp_xi <- suppressWarnings(as.integer(vb.ctrl$n_samp_xi)[1])
    if (!is.finite(vb.ctrl$n_samp_xi) || vb.ctrl$n_samp_xi < 50L) vb.ctrl$n_samp_xi <- 200L
    vb.ctrl$verbose <- isTRUE(vb.ctrl$verbose)

    vb.fit <- exal_static_LDVB(
      y = y, X = X, p0 = p0,
      max_iter = vb.ctrl$max_iter,
      tol = vb.ctrl$tol,
      b0 = b0, V0 = V0,
      a_sigma = a_sigma, b_sigma = b_sigma,
      gamma_bounds = gamma_bounds,
      log_prior_gamma = log_prior_gamma,
      init = init,
      dqlm.ind = dqlm.ind,
      n_samp_xi = vb.ctrl$n_samp_xi,
      verbose = vb.ctrl$verbose
    )

    if (isTRUE(dqlm.ind)) {
      if (is.null(init$beta)) init$beta <- as.numeric(vb.fit$qbeta$m)
      if (is.null(init$sigma)) init$sigma <- as.numeric(vb.fit$qsig$E_sigma)
      if (is.null(init$v)) init$v <- as.numeric(vb.fit$qv$E_v)
    } else {
      if (is.null(init$beta)) init$beta <- as.numeric(vb.fit$qbeta$m)
      if (is.null(init$sigma)) init$sigma <- as.numeric(vb.fit$qsiggam$sigma_mean)
      if (is.null(init$gamma)) init$gamma <- as.numeric(vb.fit$qsiggam$gamma_mean)
      if (is.null(init$v)) init$v <- as.numeric(vb.fit$qv$E_v)
      if (is.null(init$s)) init$s <- as.numeric(vb.fit$qs$E_s)
    }
  }

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

  # --- reduced AL / DQLM Gibbs path (no gamma, no s) ------------------------
  if (isTRUE(dqlm.ind)) {
    A <- (1 - 2 * p0) / (p0 * (1 - p0))
    B <- 2 / (p0 * (1 - p0))

    n_save <- n.mcmc
    save.beta  <- matrix(NA_real_, n_save, p)
    save.sigma <- numeric(n_save)
    save.v     <- matrix(NA_real_, n, n_save)

    beta  <- if (is.null(init$beta))  rep(0, p) else as.numeric(init$beta)
    sigma <- if (is.null(init$sigma)) 1        else as.numeric(init$sigma)[1]
    if (!is.finite(sigma) || sigma <= 0) sigma <- 1

    v <- if (is.null(init$v)) rep(1, n) else as.numeric(init$v)
    if (length(v) != n) v <- rep(v[1], n)
    v <- pmax(v, 1e-12)

    I <- n.burn + n.mcmc * thin
    if (verbose) {
      cat(sprintf("Static DQLM MCMC | n=%d, p=%d | burn=%d, keep=%d, thin=%d\n",
                  n, p, n.burn, n.mcmc, thin))
    }

    tictoc::tic()
    ksave <- 0L
    for (i in 1:I) {
      # (1) beta | sigma, v, y
      W_diag <- 1 / (B * sigma * v)
      Xw     <- X * sqrt(W_diag)
      V_inv  <- crossprod(Xw) + V0_inv
      rhs    <- crossprod(X, W_diag * (y - A * v)) + V0_inv %*% b0

      Uc <- tryCatch(chol(V_inv), error = function(e) NULL)
      if (is.null(Uc)) Uc <- chol(V_inv + 1e-10 * diag(p))
      m_beta <- backsolve(Uc, forwardsolve(t(Uc), rhs))
      beta   <- as.numeric(m_beta + backsolve(Uc, stats::rnorm(p)))

      # (2) sigma | beta, v, y (inverse-gamma)
      r <- y - drop(X %*% beta) - A * v
      shape_sigma <- a_sigma + 1.5 * n
      rate_sigma  <- b_sigma + sum(v) + sum((r * r) / (2 * B * v))
      sigma <- 1 / stats::rgamma(1, shape = shape_sigma, rate = pmax(rate_sigma, 1e-12))

      # (3) v_i | beta, sigma, y_i (GIG with lambda = 1/2)
      r0 <- y - drop(X %*% beta)
      chi_i <- (r0 * r0) / (B * sigma)
      psi_i <- (A * A / B + 2) / sigma
      v <- as.numeric(sample_gig_devroye_vector(
        1L, p = 0.5, a = psi_i, b_vec = chi_i
      )[1, ])
      v <- pmax(v, 1e-12)

      if (i > n.burn && ((i - n.burn) %% thin == 0)) {
        ksave <- ksave + 1L
        save.beta[ksave, ] <- beta
        save.sigma[ksave]  <- sigma
        save.v[, ksave]    <- v
      }

      if (verbose && (i %% 500 == 0)) {
        cat(sprintf("%s iteration %d | sigma=%.3f\n",
                    ifelse(i <= n.burn, "burn-in", "MCMC"), i, sigma))
      }
    }
    run.time <- tictoc::toc(quiet = TRUE)
    if (verbose) {
      cat(sprintf("MCMC complete: %d iterations, %.3f seconds\n",
                  I, run.time$toc - run.time$tic))
    }

    ret <- list(
      run.time   = (run.time$toc - run.time$tic),
      X          = X,
      p0         = p0,
      dqlm.ind   = TRUE,
      bounds     = c(L = NA_real_, U = NA_real_),
      samp.beta  = coda::as.mcmc(save.beta),
      samp.sigma = coda::as.mcmc(save.sigma),
      samp.v     = coda::as.mcmc(t(save.v)),
      init.from.vb = isTRUE(init.from.vb),
      n.burn = n.burn,
      n.mcmc = n.mcmc,
      accept.rate = NA_real_,
      accept.rate.burn = NA_real_,
      accept.rate.keep = NA_real_,
      mh.diagnostics = list(
        proposal = NA_character_,
        adapt = FALSE,
        kernel_exact = TRUE,
        signoff_ready = TRUE,
        approximation_note = NA_character_,
        accept = list(total = NA_real_, burn = NA_real_, keep = NA_real_),
        adaptation = data.frame()
      ),
      diagnostics = list(
        ess = list(
          sigma = tryCatch(as.numeric(coda::effectiveSize(coda::as.mcmc(save.sigma))), error = function(e) NA_real_),
          gamma = NA_real_
        ),
        acceptance = list(total = NA_real_, burn = NA_real_, keep = NA_real_)
      ),
      last = list(beta = beta, sigma = sigma, v = v)
    )
    class(ret) <- "exal_static_mcmc"
    return(ret)
  }

  ## --- helpers (keep names tidy like exdqlmMCMC) ---------------------------
  clamp_scale <- function(x) {
    x <- as.numeric(x)[1]
    if (!is.finite(x) || x <= 0) x <- mean(mh.scale.bounds)
    min(max(x, mh.scale.bounds[1]), mh.scale.bounds[2])
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
    starts <- c(base, base + c(-1, 1, -2, 2, -4, 4, -8, 8), 0)
    starts <- pmin(pmax(starts, -20), 20)
    cand   <- unique(starts)
    vals   <- sapply(cand, fn_log)
    idx    <- which(is.finite(vals))
    eta_start <- if (length(idx)) cand[idx[which.max(vals[idx])]] else 0
    used_fallback <- FALSE

    opt <- try(
      optim(par = eta_start, fn = fn_neg, method = "BFGS",
            control = list(maxit = 200), hessian = TRUE),
      silent = TRUE
    )
    if (inherits(opt, "try-error") || !is.finite(opt$value)) {
      used_fallback <- TRUE
      opt <- list(par = eta_start, value = fn_neg(eta_start), hessian = matrix(1e-4, 1, 1), convergence = 1L)
    }
    eta_hat <- as.numeric(opt$par)[1L]

    info_try <- try(-as.numeric(numDeriv::hessian(fn_log, x = eta_hat)),
                    silent = TRUE)
    info <- if (is.finite(info_try) && info_try > 0) info_try
            else if (!is.null(opt$hessian)) as.numeric(opt$hessian)
            else 1e-4
    if (!is.finite(info) || info <= 0) {
      used_fallback <- TRUE
      info <- 1e-4
    }
    list(
      eta_hat = eta_hat,
      info = info,
      objective = fn_log(eta_hat),
      optim_convergence = if (!is.null(opt$convergence)) as.integer(opt$convergence)[1] else NA_integer_,
      used_fallback = used_fallback
    )
  }
  sample_sigma_conditional <- function(k, chi, psi) {
    k <- as.numeric(k)[1]
    chi <- as.numeric(chi)[1]
    psi <- as.numeric(psi)[1]

    if (!is.finite(k) || !is.finite(chi) || chi <= 0 || !is.finite(psi) || psi < 0) {
      return(NA_real_)
    }

    if (psi <= 1e-12) {
      if (k >= 0) return(NA_real_)
      # GIG(k, chi, 0) with k < 0 reduces to inverse-gamma(shape=-k, rate=chi/2).
      return(1 / stats::rgamma(1L, shape = -k, rate = pmax(0.5 * chi, 1e-12)))
    }

    as.numeric(sample_gig_devroye_vector(
      1L, p = k, a = psi, b_vec = chi
    )[1, 1])
  }

  # initialize eta from current gamma
  eta <- stats::qlogis((gamma - L) / (U - L))

  I <- n.burn + n.mcmc * thin
  proposal_sd <- NA_real_
  proposal_sd_init <- NA_real_
  n.accept <- 0L
  n.accept.burn <- 0L
  n.accept.keep <- 0L
  n.trial.burn <- 0L
  n.trial.keep <- 0L
  window.accept <- 0L
  window.total <- 0L
  adapt.history <- data.frame(
    iter = integer(0),
    window_accept = numeric(0),
    proposal_sd = numeric(0),
    mode_info = numeric(0),
    stringsAsFactors = FALSE
  )
  trace_rows <- vector("list", I)

  if (mh.proposal %in% c("rw", "laplace_rw")) {
    mode0 <- find_mode_eta(eta, beta, sigma, v, s)
    proposal_sd <- if (identical(mh.proposal, "laplace_rw")) {
      clamp_scale(sqrt(1 / pmax(mode0$info, 1e-8)))
    } else {
      clamp_scale(0.5)
    }
    proposal_sd_init <- proposal_sd
  }

  ## --- main loop (burn + mcmc, prints like exdqlmMCMC) ---------------------
  if (verbose) {
    cat(sprintf("Static exAL MCMC | n=%d, p=%d | burn=%d, keep=%d, thin=%d | mh=%s\n",
                n, p, n.burn, n.mcmc, thin, mh.proposal))
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
    tau2  <- 1 / (1 + (lambda * lambda) * sigma / (B * v))
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
    sigma_new  <- sample_sigma_conditional(k = k_sigma, chi = chi_sigma, psi = psi_sigma)
    if (is.finite(sigma_new) && sigma_new > 0) sigma <- sigma_new

    ## (5) gamma | rest on eta scale
    mode_out <- find_mode_eta(eta, beta, sigma, v, s)
    current_lp <- logpost_eta(eta, beta, sigma, v, s)
    if (!is.finite(current_lp)) {
      eta <- mode_out$eta_hat
      current_lp <- logpost_eta(eta, beta, sigma, v, s)
    }

    accepted <- NA
    proposal_sd_used <- if (identical(mh.proposal, "laplace_local")) {
      clamp_scale(sqrt(1 / pmax(mode_out$info, 1e-8)))
    } else {
      proposal_sd
    }

    if (identical(mh.proposal, "laplace_local")) {
      eta <- stats::rnorm(1, mean = mode_out$eta_hat, sd = proposal_sd_used)
    } else {
      eta_prop <- eta + proposal_sd_used * stats::rnorm(1)
      prop_lp <- logpost_eta(eta_prop, beta, sigma, v, s)
      accepted <- is.finite(prop_lp) && (log(stats::runif(1)) < (prop_lp - current_lp))
      if (isTRUE(accepted)) eta <- eta_prop

      if (i <= n.burn) {
        n.trial.burn <- n.trial.burn + 1L
        n.accept.burn <- n.accept.burn + as.integer(isTRUE(accepted))
        window.accept <- window.accept + as.integer(isTRUE(accepted))
        window.total <- window.total + 1L
        if (mh.adapt && i >= mh.min_burn_adapt && i < n.burn && (i %% mh.adapt.interval == 0)) {
          acc_win <- window.accept / pmax(window.total, 1L)
          if (acc_win < mh.target.accept[1]) {
            proposal_sd <- proposal_sd * (1 - mh_max_scale_step)
          } else if (acc_win > mh.target.accept[2]) {
            proposal_sd <- proposal_sd * (1 + mh_max_scale_step)
          }
          proposal_sd <- clamp_scale(proposal_sd)
          adapt.history <- rbind(
            adapt.history,
            data.frame(
              iter = i,
              window_accept = acc_win,
              proposal_sd = proposal_sd,
              mode_info = mode_out$info,
              stringsAsFactors = FALSE
            )
          )
          window.accept <- 0L
          window.total <- 0L
        }
      } else {
        n.trial.keep <- n.trial.keep + 1L
        n.accept.keep <- n.accept.keep + as.integer(isTRUE(accepted))
      }
      n.accept <- n.accept + as.integer(isTRUE(accepted))
    }

    gamma <- g_from_eta(eta)
    A <- A_of(gamma); B <- B_of(gamma); lambda <- lam_of(gamma)

    trace_rows[[i]] <- data.frame(
      iter = i,
      phase = if (i <= n.burn) "burn" else "keep",
      eta = eta,
      gamma = gamma,
      sigma = sigma,
      mode_eta = mode_out$eta_hat,
      mode_info = mode_out$info,
      mode_objective = mode_out$objective,
      mode_optim_convergence = mode_out$optim_convergence,
      mode_used_fallback = isTRUE(mode_out$used_fallback),
      proposal_sd = proposal_sd_used,
      accepted = if (identical(mh.proposal, "laplace_local")) NA else isTRUE(accepted),
      kernel = mh.proposal,
      stringsAsFactors = FALSE
    )

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
      acc_msg <- if (identical(mh.proposal, "laplace_local")) {
        "NA"
      } else {
        format(round(n.accept / pmax(n.trial.burn + n.trial.keep, 1L), 4), nsmall = 4)
      }
      cat(sprintf(
        "%s iteration %d | sigma=%.3f | gamma=%.3f | kernel=%s | acc=%s\n",
        ifelse(i <= n.burn, "burn-in", "MCMC"), i, sigma, gamma, mh.proposal, acc_msg
      ))
    }
  }
  run.time <- tictoc::toc(quiet = TRUE)
  if (verbose) {
    cat(sprintf("MCMC complete: %d iterations, %.3f seconds\n",
                I, run.time$toc - run.time$tic))
  }

  accept_total <- if (identical(mh.proposal, "laplace_local")) NA_real_ else n.accept / pmax(n.trial.burn + n.trial.keep, 1L)
  accept_burn <- if (identical(mh.proposal, "laplace_local")) NA_real_ else if (n.trial.burn > 0) n.accept.burn / n.trial.burn else NA_real_
  accept_keep <- if (identical(mh.proposal, "laplace_local")) NA_real_ else if (n.trial.keep > 0) n.accept.keep / n.trial.keep else NA_real_
  ess_sigma <- tryCatch(as.numeric(coda::effectiveSize(coda::as.mcmc(save.sigma))), error = function(e) NA_real_)
  ess_gamma <- tryCatch(as.numeric(coda::effectiveSize(coda::as.mcmc(save.gamma))), error = function(e) NA_real_)
  kernel_exact <- mh.proposal %in% c("rw", "laplace_rw")
  mh_diag <- list(
    proposal = mh.proposal,
    adapt = if (identical(mh.proposal, "laplace_local")) FALSE else mh.adapt,
    adapt_interval = if (identical(mh.proposal, "laplace_local")) NA_integer_ else mh.adapt.interval,
    target_accept = if (identical(mh.proposal, "laplace_local")) c(NA_real_, NA_real_) else mh.target.accept,
    scale_bounds = if (identical(mh.proposal, "laplace_local")) c(NA_real_, NA_real_) else mh.scale.bounds,
    scale_initial = if (identical(mh.proposal, "laplace_local")) NA_real_ else proposal_sd_init,
    scale_final = if (identical(mh.proposal, "laplace_local")) NA_real_ else proposal_sd,
    kernel_exact = kernel_exact,
    signoff_ready = kernel_exact,
    approximation_note = if (kernel_exact) {
      NA_character_
    } else {
      "laplace_local draws gamma from a local Gaussian approximation without MH correction"
    },
    accept = list(total = accept_total, burn = accept_burn, keep = accept_keep),
    adaptation = adapt.history,
    trace = do.call(rbind, trace_rows)
  )

  ## --- return (match exdqlmMCMC style) -------------------------------------
  ret <- list(
    run.time   = (run.time$toc - run.time$tic),
    X          = X,
    p0         = p0,
    dqlm.ind   = FALSE,
    bounds     = c(L = L, U = U),
    samp.beta  = coda::as.mcmc(save.beta),
    samp.sigma = coda::as.mcmc(save.sigma),
    samp.gamma = coda::as.mcmc(save.gamma),
    samp.v     = coda::as.mcmc(t(save.v)),
    samp.s     = coda::as.mcmc(t(save.s)),
    accept.rate = accept_total,
    accept.rate.burn = accept_burn,
    accept.rate.keep = accept_keep,
    mh.diagnostics = mh_diag,
    diagnostics = list(
      mh = mh_diag,
      ess = list(sigma = ess_sigma, gamma = ess_gamma),
      acceptance = list(total = accept_total, burn = accept_burn, keep = accept_keep),
      rhat_ready = list(sigma = as.numeric(save.sigma), gamma = as.numeric(save.gamma))
    ),
    init.from.vb = isTRUE(init.from.vb),
    n.burn = n.burn,
    n.mcmc = n.mcmc,
    last = list(beta = beta, sigma = sigma, gamma = gamma, v = v, s = s)
  )
  class(ret) <- "exal_mcmc"
  ret
}

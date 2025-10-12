#' Q-DESN (Quantile Deep Echo State Network) via exAL-LDVB Readout
#'
#' Implements the model in your LaTeX: a deep, leaky reservoir with spectral
#' normalization produces features X_t; a linear readout \eqn{\mu_t = x_t' \beta}
#' is fitted under exAL_{p0} noise using your \code{exal_static_LDVB()}.
#'
#' @section Pipeline:
#' 1) Build (or accept) a DESN reservoir with fixed random sparse weights.\cr
#' 2) Roll deterministic states \eqn{h_{t,d}} from the observed series.\cr
#' 3) Stack features \eqn{x_t = [h_{t,D}; k(\tilde h_{t,1}); ...; k(\tilde h_{t,D-1})]}\cr
#' 4) Drop the first \code{max(m, washout)} points (lags and state transient).\cr
#' 5) Fit \eqn{\beta,\sigma,\gamma} with \code{exal_static_LDVB()} for a single p0.\cr
#'
#' @param y Numeric vector, length T (univariate series).
#' @param p0 Target quantile in (0,1).
#' @param D Integer depth (\eqn{D \ge 1}).
#' @param n Integer vector of length D with reservoir sizes \eqn{n_d}.
#' @param n_tilde Integer vector of length D-1 with reducers \eqn{\tilde n_d} (ignored if D=1).
#' @param m Integer number of lags in \eqn{u_t=(1, y_{t-1},..., y_{t-m})}.
#' @param alpha Leak in [0,1].
#' @param rho Numeric vector length D, spectral scales \eqn{\rho_d \in (0,1)}.
#' @param act_f Activation for reservoir pre-activations (string or function): "tanh","relu","identity" or function.
#' @param act_k Activation applied elementwise to reduced lower-layer states in the stack (same choices).
#' @param pi_w,pi_in Sparsity probs in (0,1) for internal and input matrices.
#' @param w_dist,in_dist Functions that generate weight entries (default \code{rnorm}).
#' @param washout Integer >=0; additional initial samples to drop after lag m to allow state settling.
#' @param add_bias Logical; if TRUE, appends a constant 1 column to the readout design X.
#' @param seed Optional integer to make the reservoir repeatable.
#' @param vb_args Named list forwarded to \code{exal_static_LDVB} (e.g. b0, V0, a_sigma, b_sigma, max_iter, tol, n_samp_xi, ...).
#'
#' @return A list with:
#' \itemize{
#'   \item \code{fit}: return of \code{exal_static_LDVB}.
#'   \item \code{X}: design matrix used in the VB fit (post-washout).
#'   \item \code{y_fit}: response vector aligned with \code{X}.
#'   \item \code{mu_hat}: fitted \eqn{\hat \mu_t = x_t' \hat \beta} (in-sample, post-washout).
#'   \item \code{reservoir}: the fixed reservoir (weights, reducers, hyperparams).
#'   \item \code{states}: a compact list with \code{h} (last-layer states) and \code{h_all} (optional) per layer.
#'   \item \code{meta}: indices kept, p0, sizes, etc.
#' }
#' @export
qdesn_fit_vb <- function(
  y, p0,
  D = 3L,
  n = c(200L, 100L, 50L),
  n_tilde = c(50L, 25L),
  m = 12L,
  alpha = 0.3,
  rho = rep(0.9, length.out = D),
  act_f = "tanh",
  act_k = "identity",
  pi_w = 0.1, pi_in = 0.1,
  w_dist = function(n) rnorm(n, 0, 1),
  in_dist = function(n) rnorm(n, 0, 1),
  washout = 100L,
  add_bias = FALSE,
  seed = NULL,
  vb_args = list()
){
  ## ---- checks ----
  y <- as.numeric(y); T <- length(y)
  stopifnot(length(p0) == 1, p0 > 0, p0 < 1)
  D <- as.integer(D); stopifnot(D >= 1, length(n) == D)
  if (D == 1L) { n_tilde <- integer(0) } else {
    stopifnot(length(n_tilde) == D - 1)
  }
  m <- as.integer(m); stopifnot(m >= 0)
  washout <- as.integer(washout); stopifnot(washout >= 0)
  rho <- as.numeric(rho); stopifnot(length(rho) == D, all(rho > 0), all(rho < 1))
  if (!is.null(seed)) set.seed(seed)

  ## ---- activations ----
  get_act <- function(a) {
    if (is.function(a)) return(a)
    switch(tolower(a),
      "tanh"    = base::tanh,
      "relu"    = function(x) pmax(0, x),
      "identity"= function(x) x,
      stop("Unknown activation: ", a)
    )
  }
  f_act <- get_act(act_f)
  k_act <- get_act(act_k)

  ## ---- helpers ----
  spectral_radius <- function(A) {
    # robust: try RSpectra for large, else dense eigen
    nr <- nrow(A); nc <- ncol(A)
    if (nr != nc) stop("spectral_radius requires square matrix.")
    if (nr >= 256 && requireNamespace("RSpectra", quietly = TRUE)) {
      # largest magnitude eigenvalue via eigs
      ev <- try(RSpectra::eigs(A, k = 1, which = "LM")$values, silent = TRUE)
      if (!inherits(ev, "try-error") && length(ev)) return(max(Mod(ev)))
    }
    max(Mod(eigen(A, only.values = TRUE)$values))
  }

  bern_mask <- function(nr, nc, prob) {
    M <- matrix(runif(nr * nc) < prob, nrow = nr, ncol = nc)
    storage.mode(M) <- "double"
    M
  }

  make_sparse_weights <- function(nr, nc, pi, rfun) {
    Phi <- bern_mask(nr, nc, pi)
    Z   <- matrix(rfun(nr * nc), nr, nc)
    Phi * Z
  }

  # Random reducer Q: (tilde x n_from). Row-normalized for stability.
  make_reducer <- function(n_from, n_to) {
    if (n_to <= 0) return(matrix(0, 0, n_from))
    Q <- matrix(rnorm(n_to * n_from), n_to, n_from)
    rs <- sqrt(rowSums(Q^2)); rs[rs < 1e-8] <- 1
    Q / rs
  }

  ## ---- build reservoir ----
  Win <- vector("list", D)
  W   <- vector("list", D)
  Qred<- vector("list", max(0, D - 1))

  # Layer 1: input size m+1 (includes constant)
  in1 <- m + 1L
  Win[[1]] <- make_sparse_weights(n[1], in1, pi_in, in_dist)
  W[[1]]   <- make_sparse_weights(n[1], n[1], pi_w,  w_dist)

  if (D >= 2L) {
    for (d in 2:D) {
      Win[[d]] <- make_sparse_weights(n[d], n_tilde[d - 1], pi_in, in_dist)
      W[[d]]   <- make_sparse_weights(n[d], n[d], pi_w,  w_dist)
      Qred[[d - 1]] <- make_reducer(n[d - 1], n_tilde[d - 1])
    }
  }

  # Spectral normalization per layer
  for (d in 1:D) {
    sr <- suppressWarnings(try(spectral_radius(W[[d]]), silent = TRUE))
    if (inherits(sr, "try-error") || !is.finite(sr) || sr <= 0) sr <- 1
    W[[d]] <- (rho[d] / sr) * W[[d]]
  }

  reservoir <- list(
    D = D, n = n, n_tilde = n_tilde, m = m, alpha = alpha, rho = rho,
    W = W, Win = Win, Q = Qred, act_f = act_f, act_k = act_k,
    pi_w = pi_w, pi_in = pi_in, w_dist = substitute(w_dist), in_dist = substitute(in_dist),
    seed = seed
  )

  ## ---- roll states and stack features ----
  # inputs u_t = (1, y_{t-1}, ..., y_{t-m})
  make_u <- function(y, t, m) {
    if (m == 0L) return(c(1))
    # pad with zeros if not enough lags (we drop early times later anyway)
    lags <- y[pmax(1, t - (1:m))]
    c(1, lags)
  }

  H <- lapply(seq_len(D), function(d) matrix(0, nrow = T, ncol = n[d])) # store states per layer
  H_tilde <- if (D >= 2L) lapply(seq_len(D - 1L), function(d) matrix(0, nrow = T, ncol = n_tilde[d])) else list()

  # initial states = 0
  h_prev <- lapply(seq_len(D), function(d) rep(0, n[d]))

  for (t in 1:T) {
    u_t <- make_u(y, t, m)
    # layer 1
    pre1 <- reservoir$W[[1]] %*% h_prev[[1]] + reservoir$Win[[1]] %*% u_t
    omega1 <- f_act(pre1)
    h1 <- (1 - alpha) * h_prev[[1]] + alpha * omega1
    H[[1]][t, ] <- h1
    h_prev[[1]] <- h1

    if (D >= 2L) {
      for (d in 2:D) {
        htilde <- reservoir$Q[[d - 1]] %*% h_prev[[d - 1]]
        H_tilde[[d - 1]][t, ] <- htilde
        pred <- reservoir$W[[d]] %*% h_prev[[d]] + reservoir$Win[[d]] %*% htilde
        omegad <- f_act(pred)
        hd <- (1 - alpha) * h_prev[[d]] + alpha * omegad
        H[[d]][t, ] <- hd
        h_prev[[d]] <- hd
      }
    }
  }

  # build feature vector x_t = [ h_{t,D} ; k(tilde h_{t,1}); ... ; k(tilde h_{t,D-1}) ]
  build_xrow <- function(t) {
    if (D == 1L) {
      as.numeric(H[[1]][t, ])
    } else {
      lower <- do.call(c, lapply(seq_len(D - 1L), function(d) k_act(as.numeric(H_tilde[[d]][t, ]))))
      c(as.numeric(H[[D]][t, ]), lower)
    }
  }
  X_all <- t(vapply(seq_len(T), build_xrow, numeric(n[D] + if (D == 1L) 0 else sum(n_tilde))))
  if (add_bias) X_all <- cbind(1, X_all)

  # indices to keep: drop lags (m) and washout
  drop <- max(m, washout)
  keep_idx <- seq.int(from = drop + 1L, to = T)
  X <- X_all[keep_idx, , drop = FALSE]
  y_fit <- y[keep_idx]

  ## ---- fit exAL static VB ----
  # Defaults that play nicely with large X
  p <- ncol(X)
  defaults <- list(
    b0 = rep(0, p),
    V0 = diag(1e4, p),
    a_sigma = 1, b_sigma = 1,
    max_iter = 1500,
    tol = 1e-4,
    n_samp_xi = 250,
    verbose = TRUE,
    p0 = p0 # ignored by exal_static_LDVB signature; we pass separately below
  )
  vb_call <- utils::modifyList(defaults, vb_args, keep.null = TRUE)

  fit <- exal_static_LDVB(
    y = y_fit,
    X = X,
    p0 = p0,
    max_iter     = vb_call$max_iter,
    tol          = vb_call$tol,
    b0           = vb_call$b0,
    V0           = vb_call$V0,
    a_sigma      = vb_call$a_sigma,
    b_sigma      = vb_call$b_sigma,
    gamma_bounds = if (!is.null(vb_call$gamma_bounds)) vb_call$gamma_bounds else c(L.fn(p0), U.fn(p0)),
    log_prior_gamma = if (!is.null(vb_call$log_prior_gamma)) vb_call$log_prior_gamma else function(g) 0,
    init         = vb_call$init,
    n_samp_xi    = vb_call$n_samp_xi,
    verbose      = isTRUE(vb_call$verbose)
  )

  mu_hat <- as.numeric(X %*% fit$qbeta$m)

  ret <- list(
    fit = fit,
    X = X,
    y_fit = y_fit,
    mu_hat = mu_hat,
    reservoir = reservoir,
    states = list(H_last = H[[D]], H_all = H, H_tilde = H_tilde),
    meta = list(
      keep_idx = keep_idx, drop = drop, T = T, p0 = p0,
      D = D, n = n, n_tilde = n_tilde, m = m, alpha = alpha, rho = rho,
      add_bias = add_bias
    )
  )
  class(ret) <- "qdesn_fit"
  ret
}

#' Predict in-sample p0-quantiles (mu_t) for a fitted Q-DESN
#' @param object A \code{qdesn_fit} object.
#' @return A numeric vector \eqn{\hat\mu_t} aligned with \code{object$y_fit}.
#' @export
predict_mu.qdesn_fit <- function(object) {
  as.numeric(object$X %*% object$fit$qbeta$m)
}

# ================================================================
# Posterior & Posterior-Predictive helpers for exAL-LDVB readout
# (works for qdesn_fit_vb objects via S3 wrapper below)
# ================================================================

#' @keywords internal
.chol_psd <- function(M) {
  U <- tryCatch(chol(M), error = function(e) NULL)
  if (!is.null(U)) return(U)
  E <- eigen((M + t(M))/2, symmetric = TRUE)
  vals <- pmax(E$values, .Machine$double.eps)
  E$vectors %*% diag(sqrt(vals), nrow(M)) %*% t(E$vectors)
}

#' Draw posterior samples of (beta, sigma, gamma) from an exal_vb fit
#' @param fit_exal Object returned by exal_static_LDVB()
#' @param nd Number of draws
#' @return list(beta=nd x p, sigma=nd, gamma=nd)
#' @export
exal_vb_posterior_draws <- function(fit_exal, nd = 1000L) {
  stopifnot(inherits(fit_exal, "exal_vb"))

  # beta ~ N(m, V)
  m  <- as.numeric(fit_exal$qbeta$m)
  V  <- as.matrix(fit_exal$qbeta$V)
  p  <- length(m)
  Uc <- .chol_psd(V)
  Zb <- matrix(rnorm(nd * p), nd, p)
  B  <- sweep(Zb %*% Uc, 2, m, `+`)  # nd x p

  # (eta, ell) ~ N([eta_hat, ell_hat], Sigma) -> (gamma, sigma)
  mu2  <- c(fit_exal$qsiggam$eta_hat, fit_exal$qsiggam$ell_hat)
  Sig2 <- as.matrix(fit_exal$qsiggam$Sigma)
  U2   <- .chol_psd(Sig2)
  Z2   <- matrix(rnorm(nd * 2), 2, nd)
  pars <- sweep(U2 %*% Z2, 1, mu2, `+`)  # 2 x nd
  eta  <- pars[1, ]; ell <- pars[2, ]

  L <- as.numeric(fit_exal$misc$bounds["L"])
  U <- as.numeric(fit_exal$misc$bounds["U"])
  gamma <- L + (U - L) * plogis(eta)
  sigma <- exp(ell)

  list(beta = B, sigma = sigma, gamma = gamma, nd = nd)
}

#' Posterior predictive samples for an exAL-LDVB regression
#' @param fit_exal exal_vb object
#' @param X_new n x p design (defaults to the design you pass via the Q-DESN wrapper)
#' @param nd number of draws; @param chunk split draws to cap memory
#' @return list(yrep=n x nd, mu_draws=n x nd, beta, sigma, gamma)
#' @export
exal_vb_posterior_predict <- function(fit_exal, X_new, nd = 1000L, chunk = 200L) {
  stopifnot(inherits(fit_exal, "exal_vb"))
  X_new <- as.matrix(X_new)
  n <- nrow(X_new); p <- ncol(X_new)

  draws <- exal_vb_posterior_draws(fit_exal, nd = nd)
  Bdraw <- draws$beta      # nd x p
  sdraw <- draws$sigma     # length nd
  gdraw <- draws$gamma     # length nd

  p0 <- fit_exal$misc$p0
  A_d   <- vapply(gdraw, function(g) A.fn(p0, g), numeric(1))
  B_d   <- vapply(gdraw, function(g) B.fn(p0, g), numeric(1))
  lam_d <- vapply(gdraw, function(g) C.fn(p0, g) * abs(g), numeric(1))

  yrep     <- matrix(NA_real_, n, nd)
  mu_draws <- matrix(NA_real_, n, nd)

  ids_list <- split(seq_len(nd), ceiling(seq_len(nd) / as.integer(chunk)))
  for (ids in ids_list) {
    m  <- length(ids)
    Bc <- t(Bdraw[ids, , drop = FALSE])            # p x m
    mu <- X_new %*% Bc                              # n x m
    mu_draws[, ids] <- mu

    s_mat <- matrix(abs(rnorm(n * m)), n, m)                              # N^+(0,1)
    v_mat <- matrix(rexp(n * m, rate = rep(1 / sdraw[ids], each = n)), n, m)
    z_mat <- matrix(rnorm(n * m), n, m)

    term_s <- sweep(s_mat, 2L, lam_d[ids] * sdraw[ids], `*`)
    term_v <- sweep(v_mat, 2L, A_d[ids],                   `*`)
    sd_mat <- sqrt(sweep(v_mat, 2L, B_d[ids] * sdraw[ids], `*`))

    yrep[, ids] <- mu + term_s + term_v + sd_mat * z_mat
  }

  list(yrep = yrep, mu_draws = mu_draws,
       beta = Bdraw, sigma = sdraw, gamma = gdraw)
}

#' Posterior predictive for a Q-DESN fit (uses its in-sample design by default)
#' @param object qdesn_fit object from qdesn_fit_vb()
#' @param nd draws; @param X_new optional n x p design; @param chunk memory chunk
#' @return same structure as exal_vb_posterior_predict()
#' @export
posterior_predict.qdesn_fit <- function(object, nd = 1000L, X_new = NULL, chunk = 200L) {
  stopifnot(is.list(object), !is.null(object$fit), !is.null(object$X))
  X_use <- if (is.null(X_new)) object$X else as.matrix(X_new)
  exal_vb_posterior_predict(object$fit, X_new = X_use, nd = nd, chunk = chunk)
}


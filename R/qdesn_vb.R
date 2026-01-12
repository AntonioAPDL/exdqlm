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
#' @param alpha Leak in \eqn{(0,1)}.
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

  # --- NEW: input preprocessing & scaling ---
  standardize_inputs = FALSE,        # z-score the lag inputs (not y target)
  input_bound = c("none","tanh"),    # optional bounding of inputs
  win_scale_global = 1.0,            # global scale for inputs
  win_scale_bias   = 1.0,            # separate scale for the bias column (u_0)
  win_scale_lags   = NULL,           # optional length-m vector for per-lag scales

  # --- leak can be scalar or length-D vector now ---
  alpha = 0.3,                       

  rho = rep(0.9, length.out = D),
  act_f = "tanh",
  act_k = "identity",
  pi_w = 0.1, pi_in = 0.1,
  w_dist = function(n) rnorm(n, 0, 1),
  in_dist = function(n) rnorm(n, 0, 1),
  washout = 100L,
  add_bias = FALSE,

  # --- NEW: weights & robustness ---
  weights = NULL,                    # optional time weights s_t (pre-VB)
  state_noise_sd = 0.0,              # N(0, sd^2) noise on features X
  segments = NULL,                   # list of integer vectors (start:end) for short sequences

  seed = NULL,
  vb_args = list(),
  fit_readout = TRUE
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

  input_bound <- match.arg(input_bound)

  # alpha: scalar or length-D vector
  alpha_vec <- if (length(alpha) == 1L) rep(as.numeric(alpha), D) else as.numeric(alpha)
  stopifnot(length(alpha_vec) == D, all(alpha_vec > 0), all(alpha_vec < 1))

  # sparsity: scalar or length-D vector
  pi_w  <- as.numeric(pi_w)
  pi_in <- as.numeric(pi_in)
  if (length(pi_w) == 1L)  pi_w  <- rep(pi_w,  D)
  if (length(pi_in) == 1L) pi_in <- rep(pi_in, D)
  if (length(pi_w) != D || length(pi_in) != D) {
    stop("pi_w and pi_in must be length 1 or length D.", call. = FALSE)
  }
  if (any(!is.finite(pi_w))  || any(pi_w  <= 0 | pi_w  > 1)) {
    stop("pi_w must be in (0,1].", call. = FALSE)
  }
  if (any(!is.finite(pi_in)) || any(pi_in <= 0 | pi_in > 1)) {
    stop("pi_in must be in (0,1].", call. = FALSE)
  }

  # per-lag scaling
  if (!is.null(win_scale_lags)) {
    stopifnot(length(win_scale_lags) == m)
  }

  # segments: either NULL or list of integer vectors
  if (!is.null(segments)) {
    stopifnot(is.list(segments), length(segments) > 0)
    stopifnot(all(vapply(segments, function(r) all(r >= 1 & r <= T), TRUE)))
  }

  # --- optional standardization stats for lag inputs (not target y) ---
  lag_center <- 0; lag_scale <- 1
  if (isTRUE(standardize_inputs) && m > 0L) {
    lag_center <- mean(y, na.rm = TRUE)
    lag_scale  <- stats::sd(y, na.rm = TRUE); if (!is.finite(lag_scale) || lag_scale <= 1e-12) lag_scale <- 1
  }

  # helper to post-process inputs (excluding bias)
  process_inputs <- function(v_no_bias) {
    z <- v_no_bias
    if (isTRUE(standardize_inputs)) z <- (z - lag_center) / lag_scale
    if (!is.null(win_scale_lags)) z <- z * as.numeric(win_scale_lags)
    if (input_bound == "tanh") z <- base::tanh(z)
    z
  }

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

  enforce_leaky_radius <- function(Wd, alpha) {
    # Largest eigenvalue magnitude of J = (1-alpha)I + alpha*Wd
    # For large matrices, use RSpectra if available.
    nr <- nrow(Wd)
    if (nr >= 256 && requireNamespace("RSpectra", quietly = TRUE)) {
      ev <- RSpectra::eigs((1-alpha)*diag(nr) + alpha*Wd, k = 1, which = "LM")$values
      rJ <- max(Mod(ev))
    } else {
      rJ <- max(Mod(eigen((1-alpha)*diag(nr) + alpha*Wd, only.values=TRUE)$values))
    }
    if (rJ < 1 - 1e-6) return(Wd)
    # Rescale Wd so that rho(J) = 0.99
    s <- 0.99 / rJ
    (1/alpha) * ( s*((1-alpha)*diag(nr) + alpha*Wd) - (1-alpha)*diag(nr) )
  }

  ## ---- build reservoir ----
  Win <- vector("list", D)
  W   <- vector("list", D)
  Qred<- vector("list", max(0, D - 1))

  # Layer 1: input size m+1 (includes constant)
  Win[[1]] <- make_sparse_weights(n[1], m + 1L, pi_in[1], in_dist)
  W[[1]]   <- make_sparse_weights(n[1], n[1], pi_w[1],  w_dist)

  if (D >= 2L) {
    for (d in 2:D) {
      Win[[d]] <- make_sparse_weights(n[d], n_tilde[d - 1], pi_in[d], in_dist)
      W[[d]]   <- make_sparse_weights(n[d], n[d], pi_w[d],  w_dist)
      Qred[[d - 1]] <- make_reducer(n[d - 1], n_tilde[d - 1])
    }
  }

  # Spectral normalization per layer
  for (d in 1:D) {
    sr <- suppressWarnings(try(spectral_radius(W[[d]]), silent = TRUE))
    if (inherits(sr, "try-error") || !is.finite(sr) || sr <= 0) sr <- 1
    W[[d]] <- (rho[d] / sr) * W[[d]]
    # extra safety for the leaky map (use layerwise alpha)
    W[[d]] <- enforce_leaky_radius(W[[d]], alpha_vec[d])
  }

  reservoir <- list(
    D = D, n = n, n_tilde = n_tilde, m = m, alpha = alpha_vec, rho = rho,
    W = W, Win = Win, Q = Qred, act_f = act_f, act_k = act_k,
    pi_w = pi_w, pi_in = pi_in, w_dist = substitute(w_dist), in_dist = substitute(in_dist),
    seed = seed
  )

  ## ---- roll states and stack features ----
  # inputs u_t = (bias, y_{t-1}, ..., y_{t-m}), then apply scaling
  # Segment-safe lag buffer: stores [y_{t-1}, y_{t-2}, ..., y_{t-m}] (most-recent-first)
  make_u_from_lagbuf <- function(lag_buf) {
    if (m == 0L) {
      u <- c(1)
    } else {
      lags <- process_inputs(lag_buf)  # standardize/bound/per-lag scale
      u <- c(1, lags)
    }
    u[1] <- u[1] * win_scale_bias
    if (length(u) > 1L) u[-1] <- u[-1] * win_scale_global
    u
  }

  # helper to reset states to zero (or could be a learned x_init later)
  reset_states <- function() lapply(seq_len(D), function(d) rep(0, n[d]))

  H <- lapply(seq_len(D), function(d) matrix(0, nrow = T, ncol = n[d]))
  H_tilde <- if (D >= 2L) lapply(seq_len(D - 1L), function(d) matrix(0, nrow = T, ncol = n_tilde[d])) else list()

  if (is.null(segments)) {
    segs <- list(1:T)
  } else {
    segs <- segments
  }

  for (seg in segs) {
    h_prev <- reset_states()

    # reset lag buffer at each segment boundary
    lag_buf <- if (m > 0L) rep(0, m) else numeric(0)

    for (t in seg) {
      u_t <- make_u_from_lagbuf(lag_buf)

      # layer 1
      pre1   <- reservoir$W[[1]] %*% h_prev[[1]] + reservoir$Win[[1]] %*% u_t
      omega1 <- as.numeric(f_act(pre1))
      h1     <- (1 - alpha_vec[1]) * h_prev[[1]] + alpha_vec[1] * omega1

      H[[1]][t, ] <- h1
      h_prev[[1]] <- h1

      if (D >= 2L) {
        for (d in 2:D) {
          htilde <- as.numeric(reservoir$Q[[d - 1]] %*% h_prev[[d - 1]])
          H_tilde[[d - 1]][t, ] <- htilde

          pred   <- reservoir$W[[d]] %*% h_prev[[d]] + reservoir$Win[[d]] %*% htilde
          omegad <- as.numeric(f_act(pred))
          hd     <- (1 - alpha_vec[d]) * h_prev[[d]] + alpha_vec[d] * omegad

          H[[d]][t, ] <- hd
          h_prev[[d]] <- hd
        }
      }

      # update lag buffer AFTER using it (so it remains y_{t-1},...,y_{t-m})
      if (m > 0L) lag_buf <- c(y[t], lag_buf[seq_len(m - 1L)])
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

  # --- optional row weights s_t (pre-multiply by sqrt(s_t)) ---
  if (!is.null(weights)) {
    stopifnot(length(weights) == T)
    w_keep <- weights[keep_idx]
    stopifnot(all(w_keep >= 0))
    s <- sqrt(w_keep)
    X <- X * s
    y_fit <- y_fit * s
  }

  # --- optional state-noise immunization on features (ridge-like robustness) ---
  if (state_noise_sd > 0) {
    X <- X + matrix(rnorm(length(X), 0, state_noise_sd), nrow(X), ncol(X))
  }

  ## ---- fit exAL static VB ----
    fit <- NULL
  if (isTRUE(fit_readout)) {

    `%||%` <- function(a, b) if (!is.null(a)) a else b

    # --- VB controls expected by exal_ldvb_fit/exal_ldvb_engine ---
    vb_control <- list(
      max_iter = as.integer(vb_args$max_iter %||% 150L),
      tol      = as.numeric(vb_args$tol %||% 1e-4),
      tol_par  = as.numeric(vb_args$tol_par %||% (vb_args$tol %||% 1e-4)),
      verbose  = isTRUE(vb_args$verbose %||% TRUE)
    )

    # --- gamma bounds ---
    gamma_bounds <- vb_args$gamma_bounds %||% c(L.fn(p0), U.fn(p0))

    # --- priors on gamma, sigma (natural scale) ---
    prior_gamma <- vb_args$prior_gamma %||% list(
      mu0 = vb_args$prior_gamma_mu0 %||% 0,
      s20 = vb_args$prior_gamma_s20 %||% 10
    )
    prior_sigma <- vb_args$prior_sigma %||% list(
      a = vb_args$a_sigma %||% 1,
      b = vb_args$b_sigma %||% 1
    )

    # --- init (natural scale) ---
    init <- vb_args$init %||% list()

    # --- beta prior: ridge or rhs (NEW MODEL HOOK) ---
    if (!is.null(vb_args$beta_prior_obj)) {
      beta_prior_obj <- vb_args$beta_prior_obj
    } else {
      beta_type <- tolower(vb_args$beta_prior_type %||% "ridge")

      if (beta_type == "rhs") {
        rhs_list <- vb_args$beta_rhs %||% list()
        beta_prior_obj <- beta_prior("rhs", rhs = rhs_list)
      } else {
        tau2 <- vb_args$beta_ridge_tau2 %||% vb_args$tau2 %||% 1e4
        beta_prior_obj <- beta_prior("ridge", ridge = list(tau2 = tau2))
      }
    }

    vb_control <- vb_args$vb_control %||% list(
      max_iter = vb_args$max_iter %||% 1000L,
      tol      = vb_args$tol      %||% 1e-4,
      tol_par  = vb_args$tol_par  %||% (vb_args$tol %||% 1e-4),
      verbose  = isTRUE(vb_args$verbose %||% FALSE)
    )

    fit <- exal_ldvb_fit(
      y = y_fit, X = X,
      p0 = p0,
      gamma_bounds = vb_args$gamma_bounds %||% c(L.fn(p0), U.fn(p0)),
      vb_control = vb_control,
      init = vb_args$init %||% list(),
      prior_gamma = vb_args$prior_gamma %||% list(mu0 = 0, s20 = 10),
      prior_sigma = vb_args$prior_sigma %||% list(a = 1, b = 1),
      beta_prior_obj = beta_prior_obj
      # beta_prior_obj = vb_args$beta_prior_obj %||% beta_prior("ridge", ridge = list(tau2 = 1e4))
    )

  }

  mu_hat <- if (!is.null(fit)) as.numeric(X %*% fit$qbeta$m) else rep(NA_real_, nrow(X))

ret <- list(
    fit = fit,
    X = X,
    y_fit = y_fit,
    mu_hat = mu_hat,
    reservoir = reservoir,
    states = list(H_last = H[[D]], H_all = H, H_tilde = H_tilde),
    meta = list(
        keep_idx = keep_idx, drop = drop, T = T, p0 = p0,
        D = D, n = n, n_tilde = n_tilde, m = m, alpha = alpha_vec, rho = rho,
        add_bias = add_bias,
        # NEW: store number of readout columns used in training (bias+reservoir features only)
        p_res = ncol(X),

        # Input preprocessing carried into forecasting so it reproduces training exactly
        standardize_inputs = standardize_inputs,
        input_bound = input_bound,
        win_scale_global = win_scale_global,
        win_scale_bias = win_scale_bias,
        win_scale_lags = win_scale_lags,

        # NEW: store the z-score stats for lag inputs (only if used)
        lag_center = if (isTRUE(standardize_inputs)) lag_center else 0,
        lag_scale  = if (isTRUE(standardize_inputs)) lag_scale  else 1,

        # Optional fit-time extras (kept for completeness)
        weights = if (!is.null(weights)) weights[keep_idx] else NULL,
        segments = segments
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
  if (is.null(object$fit)) stop("predict_mu(): object has no fitted readout (fit_readout=FALSE).", call. = FALSE)
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

  # (eta, ell) ~ N(mu2, Sig2) in ROW form so right-multiply works with chol()
  mu2  <- c(fit_exal$qsiggam$eta_hat, fit_exal$qsiggam$ell_hat)
  Sig2 <- as.matrix(fit_exal$qsiggam$Sigma)
  U2   <- .chol_psd(Sig2)

  Z2   <- matrix(rnorm(nd * 2), nd, 2)
  pars <- sweep(Z2 %*% U2, 2, mu2, `+`)  # nd x 2
  eta  <- pars[, 1L]
  ell  <- pars[, 2L]

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
  A_d <- vapply(gdraw, function(g) exal_get_ABC(p0 = p0, gamma = g)$A, numeric(1))
  B_d <- vapply(gdraw, function(g) exal_get_ABC(p0 = p0, gamma = g)$B, numeric(1))
  lam_d <- vapply(gdraw, function(g) {
    abc <- exal_get_ABC(p0 = p0, gamma = g)
    abc$C * abs(g)
  }, numeric(1))

  yrep     <- matrix(NA_real_, n, nd)
  mu_draws <- matrix(NA_real_, n, nd)

  ids_list <- split(seq_len(nd), ceiling(seq_len(nd) / as.integer(chunk)))
  for (ids in ids_list) {
    mm <- length(ids)
    Bc <- t(Bdraw[ids, , drop = FALSE])        # p x mm
    mu <- X_new %*% Bc                          # n x mm
    mu_draws[, ids] <- mu

    s_mat <- matrix(abs(rnorm(n * mm)), n, mm)
    v_mat <- matrix(rexp(n * mm, rate = rep(1 / sdraw[ids], each = n)), n, mm)
    z_mat <- matrix(rnorm(n * mm), n, mm)

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
#' Multi-horizon posterior predictive paths for a Q-DESN fit
#'
#' Generates per-draw recursive paths using exAL posterior predictive sampling.
#' The readout design can include reservoir features, y-lags, and exogenous lags
#' described by `readout_spec`. This is the core primitive used by the lattice
#' forecaster.
#'
#' Note: `method`, `anchor`, `anchor_path`, and `return_design` are retained for
#' backward compatibility but are ignored; only recursive sampling is used.
#'
#' @param object   qdesn_fit (from qdesn_fit_vb)
#' @param H        integer forecast horizon (>0)
#' @param nd       number of posterior-predictive draws (ignored if `draws` is supplied)
#' @param method   deprecated; ignored (kept for compatibility)
#' @param anchor   deprecated; ignored
#' @param y_hist   optional last m observed y's (chronological, oldest->newest);
#'                 if NULL and m>0 uses last m of object$y_fit
#' @param anchor_path deprecated; ignored
#' @param xreg_hist,xreg_future optional named lists of exogenous histories/futures
#' @param y_future_obs optional numeric length H with realized values (non-NA values are treated as observed)
#' @param chunk    process draws in chunks to cap memory (defaults 256)
#' @param seed     RNG seed for predictive noise (optional)
#' @param return_design deprecated; ignored
#' @param origin_state optional list of reservoir states at the forecast origin
#' @param readout_spec list with y_lags, x_names, x_lags, p_res, scale_info
#' @param draws optional posterior draws list from exal_vb_posterior_draws()
#' @return list with yrep (H x nd) and mu_draws (H x nd)
#' @export
forecast_paths.qdesn_fit <- function(
  object, H,
  nd = 1000L,
  method = c("recursive","shared"),
  anchor = c("vb-mean", "user"),
  y_hist = NULL,
  anchor_path = NULL,
  xreg_hist = NULL,
  xreg_future = NULL,
  y_future_obs = NULL,
  chunk = 256L,
  seed = NULL,
  return_design = FALSE,
  origin_state = NULL,
  readout_spec = NULL,
  draws = NULL
) {
  stopifnot(is.list(object), !is.null(object$fit), H >= 1L)
  method <- match.arg(method)
  anchor <- match.arg(anchor)
  if (!identical(method, "recursive")) {
    warning("forecast_paths.qdesn_fit: 'method' is deprecated; using recursive sampling.")
  }

  `%||%` <- function(a, b) if (is.null(a)) b else a

  if (!is.null(seed)) set.seed(as.integer(seed))

  # --- observed future y (teacher-forcing mask) ---
  if (is.null(y_future_obs)) {
    y_obs_vec <- rep(NA_real_, H)
  } else {
    stopifnot(is.numeric(y_future_obs), length(y_future_obs) == H)
    y_obs_vec <- as.numeric(y_future_obs)
  }

  # ---------- pull metadata & reservoir ----------
  meta <- object$meta %||% list()
  res  <- object$reservoir
  D    <- as.integer(meta$D)
  m_res <- as.integer(meta$m %||% 0L)
  add_bias <- isTRUE(meta$add_bias)

  # ---------- readout spec ----------
  spec <- readout_spec %||% meta$readout_spec %||% list()
  y_lags <- as.integer(spec$y_lags %||% integer(0))
  x_names <- as.character(spec$x_names %||% character(0))
  x_lags  <- spec$x_lags %||% list()
  p_res <- as.integer(spec$p_res %||% meta$p_res %||% ncol(object$X))
  scale_info <- spec$scale_info %||% meta$readout_scale %||% object$fit$misc$readout_scale

  if (!length(x_names)) {
    x_lags <- list()
  } else if (!is.list(x_lags)) {
    x_lags <- rep(list(as.integer(x_lags)), length(x_names))
    names(x_lags) <- x_names
  } else {
    if (is.null(names(x_lags)) && length(x_lags) == length(x_names)) {
      names(x_lags) <- x_names
    }
    for (nm in x_names) {
      if (is.null(x_lags[[nm]])) x_lags[[nm]] <- integer(0)
      x_lags[[nm]] <- as.integer(x_lags[[nm]])
    }
  }

  max_y_lag <- max(c(0L, m_res, y_lags))

  if (is.null(y_hist)) y_hist <- object$y_fit
  y_hist <- as.numeric(y_hist)
  if (length(y_hist) < max_y_lag) {
    stop(sprintf("forecast_paths: need at least %d y values before origin, got %d.",
                 max_y_lag, length(y_hist)))
  }
  y_hist0 <- if (max_y_lag > 0L) tail(y_hist, max_y_lag) else numeric(0)

  lag_vals <- function(hist, lags) {
    if (!length(lags)) return(numeric(0))
    n <- length(hist)
    if (max(lags) > n) stop("lag_vals: history too short for requested lags.")
    vapply(lags, function(L) hist[n - L + 1L], numeric(1))
  }

  # ---------- exogenous history/future (readout only) ----------
  if (length(x_names)) {
    stopifnot(is.list(xreg_hist), is.list(xreg_future))
    x_hist <- list()
    x_future <- list()
    for (nm in x_names) {
      lags_nm <- x_lags[[nm]]
      max_lag <- if (length(lags_nm)) max(lags_nm) else 0L
      xh <- xreg_hist[[nm]]
      xf <- xreg_future[[nm]]
      if (is.null(xh) || is.null(xf)) stop("forecast_paths: missing xreg_hist/future for ", nm)
      if (max_lag > 0L && length(xh) < max_lag) stop("forecast_paths: not enough xreg_hist for ", nm)
      if (length(xf) < H) stop("forecast_paths: xreg_future for ", nm, " must have length >= H.")
      x_hist[[nm]] <- if (max_lag > 0L) tail(as.numeric(xh), max_lag) else numeric(0)
      x_future[[nm]] <- as.numeric(xf)
    }

    x_blocks <- vector("list", H)
    for (h in seq_len(H)) {
      block <- numeric(0)
      for (nm in x_names) {
        lags_nm <- x_lags[[nm]]
        if (!length(lags_nm)) next
        vec <- c(x_hist[[nm]], x_future[[nm]][seq_len(h)])
        n <- length(vec)
        vals <- vapply(lags_nm, function(L) vec[n - L], numeric(1))
        block <- c(block, vals)
      }
      x_blocks[[h]] <- block
    }
  } else {
    x_blocks <- rep(list(numeric(0)), H)
  }

  # activations
  get_act <- function(a) {
    if (is.function(a)) return(a)
    switch(tolower(a),
      "tanh"     = base::tanh,
      "relu"     = function(x) pmax(0, x),
      "identity" = function(x) x,
      stop("Unknown activation: ", a))
  }
  act_code <- function(a) {
    if (is.function(a)) return(NA_integer_)
    switch(tolower(a),
      "identity" = 0L,
      "tanh"     = 1L,
      "relu"     = 2L,
      NA_integer_)
  }
  f_act <- get_act(res$act_f)
  k_act <- get_act(res$act_k)

  # training-time input preprocessing (reservoir only)
  lag_center <- meta$lag_center %||% 0
  lag_scale  <- meta$lag_scale  %||% 1
  standardize_inputs <- isTRUE(meta$standardize_inputs)
  input_bound        <- meta$input_bound %||% "none"
  win_scale_global   <- meta$win_scale_global %||% 1
  win_scale_bias     <- meta$win_scale_bias   %||% 1
  win_scale_lags     <- meta$win_scale_lags

  process_lags <- function(lags_vec) {
    z <- lags_vec
    if (isTRUE(standardize_inputs)) z <- (z - lag_center) / lag_scale
    if (!is.null(win_scale_lags))   z <- z * as.numeric(win_scale_lags)
    z
  }

  make_u <- function(y_hist_vec) {
    if (m_res > 0L) {
      lags <- process_lags(rev(tail(y_hist_vec, m_res)))
      nb   <- lags
    } else {
      nb   <- numeric(0)
    }
    if (identical(input_bound, "tanh") && length(nb)) nb <- base::tanh(nb)
    u <- c(1, nb)
    u[1] <- u[1] * win_scale_bias
    if (length(u) > 1L) u[-1] <- u[-1] * win_scale_global
    u
  }

  forward_one <- function(h_prev, u_vec) {
    h_new <- vector("list", D)
    htil  <- if (D >= 2L) vector("list", D - 1L) else list()

    # layer 1
    pre1   <- res$W[[1]]  %*% h_prev[[1]] + res$Win[[1]] %*% u_vec
    omega1 <- f_act(pre1)
    h1     <- (1 - res$alpha[1]) * h_prev[[1]] + res$alpha[1] * omega1
    h_new[[1]] <- h1
    if (D >= 2L) htil[[1]] <- res$Q[[1]] %*% h1

    # layers 2..D
    if (D >= 2L) {
      for (d in 2:D) {
        pre   <- res$W[[d]]  %*% h_prev[[d]] + res$Win[[d]] %*% htil[[d - 1]]
        omega <- f_act(pre)
        hd    <- (1 - res$alpha[d]) * h_prev[[d]] + res$alpha[d] * omega
        h_new[[d]] <- hd
        if (d < D) htil[[d]] <- res$Q[[d]] %*% hd
      }
    }

    # readout feature row
    if (D == 1L) {
      x_res <- as.numeric(h_new[[1]])
    } else {
      lower <- do.call(c, lapply(seq_len(D - 1L), function(d) k_act(as.numeric(htil[[d]]))))
      x_res <- c(as.numeric(h_new[[D]]), lower)
    }
    if (add_bias) x_res <- c(1, x_res)

    list(h = h_new, x_res = x_res)
  }

  if (is.null(origin_state)) {
    if (!is.null(object$states$H_all)) {
      origin_state <- lapply(seq_len(D), function(d) { Hd <- object$states$H_all[[d]]; Hd[nrow(Hd), ] })
    } else if (!is.null(object$states$H_last)) {
      origin_state <- object$states$H_last
    } else {
      stop("forecast_paths: origin_state missing and no states in object.")
    }
  }

  if (is.null(draws)) {
    draws <- exal_vb_posterior_draws(object$fit, nd = nd)
  }
  Bdraw <- draws$beta
  sdraw <- draws$sigma
  gdraw <- draws$gamma
  if (is.null(Bdraw) || !is.matrix(Bdraw)) stop("forecast_paths: missing beta draws.")

  nd_eff <- nrow(Bdraw)
  if (length(sdraw) != nd_eff || length(gdraw) != nd_eff) {
    stop("forecast_paths: draw lengths do not match beta draws.")
  }

  p0    <- object$fit$misc$p0
  A_d <- vapply(gdraw, function(g) exal_get_ABC(p0 = p0, gamma = g)$A, numeric(1))
  B_d <- vapply(gdraw, function(g) exal_get_ABC(p0 = p0, gamma = g)$B, numeric(1))
  lam_d <- vapply(gdraw, function(g) {
    abc <- exal_get_ABC(p0 = p0, gamma = g)
    abc$C * abs(g)
  }, numeric(1))

  use_cpp <- isTRUE(getOption("exdqlm.use_cpp_postpred", FALSE))
  use_cpp_omp <- isTRUE(getOption("exdqlm.use_cpp_postpred_omp", FALSE))
  precompute_noise <- isTRUE(getOption("exdqlm.use_cpp_postpred_precompute", FALSE)) || isTRUE(use_cpp_omp)

  if (isTRUE(use_cpp)) {
    if (!exists("forecast_paths_cpp", mode = "function", inherits = TRUE)) {
      stop("exdqlm.use_cpp_postpred=TRUE but forecast_paths_cpp not found.")
    }

    act_f_code <- act_code(res$act_f)
    act_k_code <- act_code(res$act_k)
    if (!is.finite(act_f_code) || !is.finite(act_k_code)) {
      message("[forecast_paths] C++ disabled: custom activation functions not supported.")
      use_cpp <- FALSE
    }
    if (!input_bound %in% c("none", "tanh")) {
      message("[forecast_paths] C++ disabled: input_bound must be 'none' or 'tanh'.")
      use_cpp <- FALSE
    }

    if (isTRUE(use_cpp)) {
      scale_info_cpp <- scale_info
      if (is.null(scale_info_cpp) || !isTRUE(scale_info_cpp$scaled)) {
        scale_info_cpp <- list(scaled = FALSE)
      }
      win_scale_lags_cpp <- if (is.null(win_scale_lags)) numeric(0) else as.numeric(win_scale_lags)

      s_draws <- v_draws <- z_draws <- NULL
      if (isTRUE(precompute_noise)) {
        s_draws <- matrix(abs(rnorm(H * nd_eff)), nrow = H, ncol = nd_eff)
        z_draws <- matrix(rnorm(H * nd_eff), nrow = H, ncol = nd_eff)
        v_draws <- matrix(NA_real_, nrow = H, ncol = nd_eff)
        for (j in seq_len(nd_eff)) {
          v_draws[, j] <- rexp(H, rate = 1 / sdraw[j])
        }
      }

      Q_list_cpp <- if (is.null(res$Q)) list() else res$Q
      out <- forecast_paths_cpp(
        W_list = res$W,
        Win_list = res$Win,
        Q_list = Q_list_cpp,
        alpha = res$alpha,
        D = D,
        add_bias = add_bias,
        y_hist0 = y_hist0,
        y_lags = y_lags,
        x_blocks = x_blocks,
        beta = Bdraw,
        sigma = sdraw,
        A_d = A_d,
        B_d = B_d,
        lam_d = lam_d,
        y_obs_vec = y_obs_vec,
        H = H,
        m_res = m_res,
        p_res = p_res,
        standardize_inputs = standardize_inputs,
        lag_center = lag_center,
        lag_scale = lag_scale,
        win_scale_lags = win_scale_lags_cpp,
        input_bound = input_bound,
        win_scale_global = win_scale_global,
        win_scale_bias = win_scale_bias,
        scale_info = scale_info_cpp,
        act_f_code = act_f_code,
        act_k_code = act_k_code,
        origin_state = origin_state,
        s_draws = s_draws,
        v_draws = v_draws,
        z_draws = z_draws,
        use_omp = isTRUE(use_cpp_omp)
      )
      return(out)
    }
  }

  yrep     <- matrix(NA_real_, H, nd_eff)
  mu_draws <- matrix(NA_real_, H, nd_eff)

  ids_list <- split(seq_len(nd_eff), ceiling(seq_len(nd_eff) / as.integer(chunk)))
  for (ids in ids_list) {
    for (j in ids) {
      h_now        <- origin_state
      y_hist_work  <- y_hist0

      s_vec <- abs(rnorm(H))
      v_vec <- rexp(H, rate = 1 / sdraw[j])
      z_vec <- rnorm(H)

      for (h in seq_len(H)) {
        u_h   <- make_u(y_hist_work)
        step  <- forward_one(h_now, u_h)
        h_now <- step$h
        x_res <- step$x_res

        if (h == 1L && length(x_res) != p_res) {
          stop("Readout feature length mismatch: got ", length(x_res),
               " but expected p_res=", p_res, ".")
        }

        y_lag_vec <- lag_vals(y_hist_work, y_lags)
        x_row <- c(x_res, y_lag_vec, x_blocks[[h]])
        if (!is.null(scale_info)) {
          x_row <- readout_scale_apply(matrix(x_row, nrow = 1), scale_info)[1, ]
        }

        if (h == 1L && length(x_row) != ncol(Bdraw)) {
          stop("Readout length mismatch: got ", length(x_row),
               " but beta has ", ncol(Bdraw), " columns.")
        }

        mu_h <- sum(x_row * Bdraw[j, ])
        mu_draws[h, j] <- mu_h

        y_h <- if (!is.na(y_obs_vec[h])) {
          y_obs_vec[h]
        } else {
          mu_h + (lam_d[j] * sdraw[j]) * s_vec[h] +
            A_d[j] * v_vec[h] + sqrt(B_d[j] * sdraw[j] * v_vec[h]) * z_vec[h]
        }

        yrep[h, j] <- y_h
        if (max_y_lag > 0L) {
          y_hist_work <- c(y_hist_work, y_h)
          if (length(y_hist_work) > max_y_lag) y_hist_work <- tail(y_hist_work, max_y_lag)
        }
      }
    }
  }

  list(yrep = yrep, mu_draws = mu_draws)
}

#' Lattice multi-step forecasts for a Q-DESN fit using posterior predictive draws
#' @param object qdesn_fit (from qdesn_fit_vb or compatible structure)
#' @param y_all numeric vector of observed y values (length >= max(origins))
#' @param origins integer vector of forecast origins (absolute indices into y_all)
#' @param H forecast horizon (steps ahead)
#' @param nd number of posterior draws per origin
#' @param xreg_all optional named list of exogenous series (length >= max(origins)+H)
#' @param y_obs_last last observed y index (defaults to length(y_all))
#' @param lead_weights optional numeric vector length H (base weights by lead)
#' @param mix_nd number of mixture draws per target (defaults to nd)
#' @param keep_origin_draws if FALSE, drop per-origin draws after mixture
#' @return list with per-origin draws (optional) and mixture draws per target
#' @export
forecast_lattice.qdesn_fit <- function(
  object, y_all, origins, H,
  nd = 1000L,
  xreg_all = NULL,
  y_obs_last = NULL,
  lead_weights = NULL,
  mix_nd = NULL,
  chunk = 256L,
  seed = NULL,
  keep_origin_draws = TRUE
) {
  `%||%` <- function(a, b) if (is.null(a)) b else a

  stopifnot(is.list(object), !is.null(object$fit), H >= 1L)
  origins <- as.integer(origins)
  y_all <- as.numeric(y_all)

  if (is.null(y_obs_last)) y_obs_last <- length(y_all)
  y_obs_last <- as.integer(y_obs_last)
  if (max(origins) > y_obs_last) {
    stop("forecast_lattice: origins exceed last observed y index.")
  }

  meta <- object$meta %||% list()
  D <- as.integer(meta$D)

  spec <- meta$readout_spec %||% list()
  y_lags <- as.integer(spec$y_lags %||% integer(0))
  x_names <- as.character(spec$x_names %||% character(0))
  x_lags  <- spec$x_lags %||% list()

  if (!length(x_names)) {
    x_lags <- list()
  } else if (!is.list(x_lags)) {
    x_lags <- rep(list(as.integer(x_lags)), length(x_names))
    names(x_lags) <- x_names
  } else {
    if (is.null(names(x_lags)) && length(x_lags) == length(x_names)) {
      names(x_lags) <- x_names
    }
    for (nm in x_names) {
      if (is.null(x_lags[[nm]])) x_lags[[nm]] <- integer(0)
      x_lags[[nm]] <- as.integer(x_lags[[nm]])
    }
  }

  max_y_lag <- max(c(0L, as.integer(meta$m %||% 0L), y_lags))

  if (!length(x_names)) {
    xreg_all <- NULL
  } else {
    if (is.null(xreg_all) || !is.list(xreg_all)) {
      stop("forecast_lattice: xreg_all is required when exogenous variables are present.")
    }
    for (nm in x_names) {
      if (is.null(xreg_all[[nm]])) stop("forecast_lattice: missing xreg_all for ", nm)
      if (length(xreg_all[[nm]]) < max(origins) + H) {
        stop("forecast_lattice: xreg_all for ", nm, " must have length >= max(origin)+H.")
      }
    }
  }

  base_w <- if (!is.null(lead_weights)) as.numeric(lead_weights) else rep(1, H)
  if (length(base_w) == 1L && H > 1L) base_w <- rep(base_w, H)
  if (length(base_w) != H) stop("forecast_lattice: lead_weights must have length H.")
  if (any(!is.finite(base_w)) || any(base_w < 0)) stop("forecast_lattice: lead_weights must be nonnegative.")

  if (is.null(mix_nd)) mix_nd <- nd
  mix_nd <- as.integer(mix_nd)
  if (mix_nd < 1L) stop("forecast_lattice: mix_nd must be >= 1.")

  if (!is.null(seed)) set.seed(as.integer(seed))
  draws <- exal_vb_posterior_draws(object$fit, nd = nd)
  nd_eff <- nrow(draws$beta)

  yrep_list <- vector("list", length(origins))
  mu_list   <- vector("list", length(origins))

  for (i in seq_along(origins)) {
    tau <- origins[i]

    if (length(y_all) < tau) stop("forecast_lattice: y_all too short for origin.")
    if (max_y_lag > 0L && tau < max_y_lag) stop("forecast_lattice: origin too early for lag requirements.")

    y_hist <- if (max_y_lag > 0L) tail(y_all[seq_len(tau)], max_y_lag) else numeric(0)

    xreg_hist <- NULL
    xreg_future <- NULL
    if (length(x_names)) {
      xreg_hist <- list()
      xreg_future <- list()
      for (nm in x_names) {
        lags_nm <- x_lags[[nm]]
        max_lag <- if (length(lags_nm)) max(lags_nm) else 0L
        xvec <- as.numeric(xreg_all[[nm]])
        xreg_hist[[nm]] <- if (max_lag > 0L) tail(xvec[seq_len(tau)], max_lag) else numeric(0)
        xreg_future[[nm]] <- xvec[(tau + 1L):(tau + H)]
      }
    }

    origin_state <- if (!is.null(object$states$H_all)) {
      lapply(seq_len(D), function(d) { Hd <- object$states$H_all[[d]]; Hd[tau, ] })
    } else {
      stop("forecast_lattice: object$states$H_all is required for origin states.")
    }

    out <- forecast_paths.qdesn_fit(
      object, H = H, nd = nd_eff,
      y_hist = y_hist,
      xreg_hist = xreg_hist,
      xreg_future = xreg_future,
      y_future_obs = rep(NA_real_, H),
      chunk = chunk,
      origin_state = origin_state,
      readout_spec = spec,
      draws = draws
    )

    yrep_list[[i]] <- out$yrep
    mu_list[[i]]   <- out$mu_draws
  }

  targets <- seq.int(min(origins) + 1L, max(origins) + H)
  mix_y  <- matrix(NA_real_, nrow = length(targets), ncol = mix_nd)
  mix_mu <- matrix(NA_real_, nrow = length(targets), ncol = mix_nd)

  for (ti in seq_along(targets)) {
    t <- targets[ti]
    lead_vals <- t - origins
    ok <- which(lead_vals >= 1L & lead_vals <= H)
    if (!length(ok)) next

    leads <- as.integer(lead_vals[ok])
    leads <- leads[is.finite(leads) & leads >= 1L & leads <= H]
    if (!length(leads)) next
    w <- base_w[leads]
    if (length(w) != length(leads)) {
      message(sprintf(
        "[forecast_lattice] lead weight length mismatch (leads=%d, weights=%d); using uniform weights.",
        length(leads), length(w)
      ))
      w <- rep(1, length(leads))
    }
    if (sum(w) <= 0 || any(!is.finite(w))) {
      stop("forecast_lattice: lead_weights must be positive for available leads.")
    }
    w <- w / sum(w)

    # sample.int avoids sample(x) special-case when length(leads)==1L and lead>1
    lead_idx <- if (length(leads) == 1L) {
      rep(1L, mix_nd)
    } else {
      sample.int(length(leads), size = mix_nd, replace = TRUE, prob = w)
    }
    lead_draw <- leads[lead_idx]
    draw_idx  <- sample(seq_len(nd_eff), size = mix_nd, replace = TRUE)

    for (ell in unique(lead_draw)) {
      idx <- which(lead_draw == ell)
      tau <- t - ell
      origin_idx <- match(tau, origins)
      if (is.na(origin_idx)) next
      mix_y[ti, idx]  <- yrep_list[[origin_idx]][ell, draw_idx[idx]]
      mix_mu[ti, idx] <- mu_list[[origin_idx]][ell, draw_idx[idx]]
    }
  }

  if (!isTRUE(keep_origin_draws)) {
    yrep_list <- NULL
    mu_list <- NULL
  }

  list(
    origins = origins,
    targets = targets,
    horizon = H,
    nd_draws = nd_eff,
    mix_nd = mix_nd,
    yrep_by_origin = yrep_list,
    mu_by_origin = mu_list,
    mix = list(y = mix_y, mu = mix_mu),
    lead_weights = base_w
  )
}

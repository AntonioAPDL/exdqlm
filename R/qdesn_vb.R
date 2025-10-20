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

  input_bound <- match.arg(input_bound)

  # alpha: scalar or length-D vector
  alpha_vec <- if (length(alpha) == 1L) rep(as.numeric(alpha), D) else as.numeric(alpha)
  stopifnot(length(alpha_vec) == D, all(alpha_vec > 0), all(alpha_vec < 1))

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
  Win[[1]] <- make_sparse_weights(n[1], m + 1L, pi_in, in_dist)
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
  make_u <- function(y, t, m) {
    if (m == 0L) {
      u <- c(1)
    } else if (t <= m) {
      u <- c(1, rep(0, m))
    } else {
      lags <- y[seq.int(t-1, t-m, by = -1)]
      lags <- process_inputs(lags)   # standardize/bound/per-lag scale
      u <- c(1, lags)
    }
    # separate bias & global scales last (bias is index 1)
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
    for (t in seg) {
      u_t <- make_u(y, t, m)
      # layer 1
      pre1 <- reservoir$W[[1]] %*% h_prev[[1]] + reservoir$Win[[1]] %*% u_t
      omega1 <- f_act(pre1)
      h1 <- (1 - alpha_vec[1]) * h_prev[[1]] + alpha_vec[1] * omega1
      H[[1]][t, ] <- h1
      h_prev[[1]] <- h1
      if (D >= 2L) {
        for (d in 2:D) {
          htilde <- reservoir$Q[[d - 1]] %*% h_prev[[d - 1]]
          H_tilde[[d - 1]][t, ] <- htilde
          pred <- reservoir$W[[d]] %*% h_prev[[d]] + reservoir$Win[[d]] %*% htilde
          omegad <- f_act(pred)
          hd <- (1 - alpha_vec[d]) * h_prev[[d]] + alpha_vec[d] * omegad
          H[[d]][t, ] <- hd
          h_prev[[d]] <- hd
        }
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
    stream = FALSE,        
    p0 = p0
  )
  vb_call <- utils::modifyList(defaults, vb_args, keep.null = TRUE)

  # Prepare argument list once
  .exal_args <- list(
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

  if (!isTRUE(vb_call$stream)) {
    # regular in-process call (may buffer prints in Jupyter)
    fit <- do.call(exal_static_LDVB, .exal_args)
  } else {
    # live streaming via a background R process
    if (!requireNamespace("callr", quietly = TRUE)) {
      stop("To stream progress, install.packages('callr') or set vb_args$stream = FALSE.")
    }
    # run in a clean R session that has the package available
    p_bg <- callr::r_bg(
      function(args) {
        # make sure the package namespace is loaded in the child
        if (!"exdqlm" %in% loadedNamespaces()) library(exdqlm)
        do.call(exal_static_LDVB, args)
      },
      args = list(.exal_args),
      stdout = "|", stderr = "|"
    )

    # tail the child’s output until it finishes
    repeat {
      # stream any new lines
      out <- p_bg$read_output_lines()
      err <- p_bg$read_error_lines()
      if (length(out)) { cat(paste0(out, collapse = "\n"), "\n"); utils::flush.console() }
      if (length(err)) { cat(paste0(err, collapse = "\n"), "\n"); utils::flush.console() }
      if (!p_bg$is_alive()) break
      Sys.sleep(0.2)
    }
    # flush remaining
    out <- p_bg$read_output_lines(); if (length(out)) cat(paste0(out, collapse="\n"), "\n")
    err <- p_bg$read_error_lines(); if (length(err)) cat(paste0(err, collapse="\n"), "\n")

    # retrieve result (errors propagate)
    fit <- p_bg$get_result()
  }

  # --- simple activation diagnostics at the last kept time step ---
  t_last <- NULL
  if (length(keep_idx) > 0L) t_last <- keep_idx[length(keep_idx)]
  diag_list <- list()
  if (!is.null(t_last)) {
    for (d in 1:D) {
      post <- as.numeric(H[[d]][t_last, ])
      diag_list[[paste0("layer", d)]] <- list(
        post_mean = mean(post), post_sd = stats::sd(post),
        post_q = stats::quantile(post, c(.01,.05,.5,.95,.99), na.rm=TRUE)
      )
    }
  }
  diagnostics <- list(
    alpha = alpha_vec,
    win_scale_global = win_scale_global,
    win_scale_bias = win_scale_bias,
    win_scale_lags = win_scale_lags,
    state_noise_sd = state_noise_sd,
    act_summary = diag_list
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
        D = D, n = n, n_tilde = n_tilde, m = m, alpha = alpha_vec, rho = rho,
        add_bias = add_bias,
        standardize_inputs = standardize_inputs,
        input_bound = input_bound,
        win_scale_global = win_scale_global,
        win_scale_bias = win_scale_bias,
        win_scale_lags = win_scale_lags,
        # NEW: store the z-score stats for lag inputs
        lag_center = if (isTRUE(standardize_inputs)) lag_center else 0,
        lag_scale  = if (isTRUE(standardize_inputs)) lag_scale  else 1,
        weights = if (!is.null(weights)) weights[keep_idx] else NULL,
        segments = segments,
        diagnostics = diagnostics
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

#' Multi-horizon posterior predictive for a Q-DESN fit
#'
#' Two modes:
#' - method="recursive" (default): per-draw, per-quantile **recursive** simulation.
#'   Each draw has its own path; future lags use the already simulated y for that draw.
#'   This is the statistically correct multi-step forecaster for selection & testing.
#' - method="shared": cheap plug-in (your previous implementation) that rolls a
#'   single deterministic design path (anchor) and samples only the readout noise.
#'
#' @param object   qdesn_fit (from qdesn_fit_vb or your exog-augmented wrapper)
#' @param H        integer forecast horizon (>0)
#' @param nd       number of posterior-predictive draws
#' @param method   c("recursive","shared")
#' @param anchor   ("vb-mean"|"user") only used when method="shared"
#' @param y_hist   optional last m observed y's (chronological, oldest->newest);
#'                 if NULL and m>0 uses last m of object$y_fit
#' @param anchor_path optional length>=H numeric, when method="shared" & anchor="user"
#' @param xreg_hist, xreg_future  optional named lists of exog lag histories and
#'                 known futures (e.g. list(ppt=.., soil=..)). See details below.
#' @param chunk    process draws in chunks to cap memory
#' @param seed     RNG seed for predictive noise (optional)
#' @param return_design logical; for method="shared" returns X_future (H x p).
#'                 For method="recursive" the design is draw-specific and thus
#'                 not returned (ignored).
#' @return list with yrep (H x nd), mu_draws (H x nd),
#'         plus anchor_path and/or X_future in shared mode.
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
  chunk = 256L,
  seed = NULL,
  return_design = FALSE
) {
  stopifnot(is.list(object), !is.null(object$fit), H >= 1L)
  method <- match.arg(method)
  anchor <- match.arg(anchor)

  `%||%` <- function(a, b) if (is.null(a)) b else a

  # ---------- pull metadata & reservoir ----------
  meta <- object$meta
  res  <- object$reservoir
  D    <- as.integer(meta$D)
  n    <- res$n
  m    <- as.integer(meta$m)
  add_bias <- isTRUE(meta$add_bias)

  # activations
  get_act <- function(a) {
    if (is.function(a)) return(a)
    switch(tolower(a),
      "tanh"     = base::tanh,
      "relu"     = function(x) pmax(0, x),
      "identity" = function(x) x,
      stop("Unknown activation: ", a))
  }
  f_act <- get_act(res$act_f)
  k_act <- get_act(res$act_k)

  # training-time input preprocessing
  lag_center <- meta$lag_center %||% 0
  lag_scale  <- meta$lag_scale  %||% 1
  standardize_inputs <- isTRUE(meta$standardize_inputs)
  input_bound        <- meta$input_bound %||% "none"
  win_scale_global   <- meta$win_scale_global %||% 1
  win_scale_bias     <- meta$win_scale_bias   %||% 1
  win_scale_lags     <- meta$win_scale_lags
  process_inputs <- function(v_no_bias) {
    z <- v_no_bias
    if (isTRUE(standardize_inputs)) z <- (z - lag_center) / lag_scale
    if (!is.null(win_scale_lags))   z <- z * as.numeric(win_scale_lags)
    if (identical(input_bound, "tanh")) z <- base::tanh(z)
    z
  }

  # readout column counts: reservoir-derived + exog lags (if any)
  p_res <- meta$p_res %||% {
    pr <- res$n[D] + if (D == 1L) 0L else sum(res$n_tilde)
    if (add_bias) pr <- pr + 1L
    pr
  }
  l_ppt  <- as.integer(meta$lags_ppt  %||% 0L)
  l_soil <- as.integer(meta$lags_soil %||% 0L)
  covar_order <- meta$covar_order %||% c("ppt","soil")

  # histories
  if (m > 0L) {
    if (is.null(y_hist)) {
      stopifnot(length(object$y_fit) >= m)
      y_hist <- tail(object$y_fit, m)
    } else {
      stopifnot(length(y_hist) >= m)
      y_hist <- tail(y_hist, m)
    }
  } else {
    y_hist <- numeric(0)
  }

  need <- list()
  if (l_ppt  > 0) need[["ppt"]]  <- l_ppt
  if (l_soil > 0) need[["soil"]] <- l_soil
  if (length(need)) {
    stopifnot(is.list(xreg_hist), is.list(xreg_future))
    for (nm in names(need)) {
      stopifnot(is.numeric(xreg_hist[[nm]]),  length(xreg_hist[[nm]])  >= need[[nm]])
      stopifnot(is.numeric(xreg_future[[nm]]), length(xreg_future[[nm]]) >= H)
      xreg_hist[[nm]] <- tail(xreg_hist[[nm]], need[[nm]])
    }
  } else {
    xreg_hist   <- list()
    xreg_future <- list()
  }

  # states at forecast origin = last training states
  H_all  <- object$states$H_all
  Qred   <- res$Q
  h_last <- lapply(seq_len(D), function(d) {
    Hd <- H_all[[d]]; Hd[nrow(Hd), ]
  })

  # ----- helpers -----
  make_u <- function(y_hist_vec) {
    if (m == 0L) {
      u <- c(1)
    } else {
      lags <- rev(tail(y_hist_vec, m))
      lags <- process_inputs(lags)
      u <- c(1, lags)
    }
    u[1] <- u[1] * win_scale_bias
    if (length(u) > 1L) u[-1] <- u[-1] * win_scale_global
    u
  }

  # forward-one-step: returns new states and the readout feature row
  # NOTE: to match training exactly, the lower block uses k_act(Q_d * h_{t,d})
  forward_one <- function(h_prev, u_vec) {
    h_new <- vector("list", D)
    htil  <- vector("list", max(0, D - 1L))

    # layer 1
    pre1   <- res$W[[1]]  %*% h_prev[[1]] + res$Win[[1]] %*% u_vec
    omega1 <- f_act(pre1)
    h1     <- (1 - res$alpha[1]) * h_prev[[1]] + res$alpha[1] * omega1
    h_new[[1]] <- h1
    if (D >= 2L) htil[[1]] <- Qred[[1]] %*% h1

    # layers 2..D
    if (D >= 2L) {
      for (d in 2:D) {
        pre   <- res$W[[d]]  %*% h_prev[[d]] + res$Win[[d]] %*% htil[[d - 1]]
        omega <- f_act(pre)
        hd    <- (1 - res$alpha[d]) * h_prev[[d]] + res$alpha[d] * omega
        h_new[[d]] <- hd
        if (d < D) htil[[d]] <- Qred[[d]] %*% hd
      }
    }

    # readout feature row: [ h_{t,D} ; k(Q_1 h_{t,1}); ... ; k(Q_{D-1} h_{t,D-1}) ]
    if (D == 1L) {
      x_res <- as.numeric(h_new[[1]])
    } else {
      lower <- do.call(c, lapply(seq_len(D - 1L), function(d) k_act(as.numeric(htil[[d]]))))
      x_res <- c(as.numeric(h_new[[D]]), lower)
    }
    if (add_bias) x_res <- c(1, x_res)

    list(h = h_new, x_res = x_res)
  }

  build_xcov_row <- function(h) {
    out <- numeric(0)
    for (nm in covar_order) {
      L <- switch(nm, ppt = l_ppt, soil = l_soil, 0L)
      if (L <= 0L) next
      hist <- xreg_hist[[nm]]
      fut  <- xreg_future[[nm]]
      vec  <- c(hist, fut[seq_len(h - 1L)])  # extend with known futures up to h-1
      out  <- c(out, rev(tail(vec, L)))     # most-recent-first
    }
    out
  }

  # ============ SHARED mode (backwards-compatible fast path) ============
  if (identical(method, "shared")) {
    # build once: X_future on a deterministic anchor path
    X_future <- matrix(NA_real_, nrow = H, ncol = p_res + l_ppt + l_soil)
    y_anchor <- numeric(H)
    y_hist_work <- y_hist
    h_now <- h_last
    beta_mean <- as.numeric(object$fit$qbeta$m)

    for (h in seq_len(H)) {
      u_h   <- make_u(y_hist_work)
      step  <- forward_one(h_now, u_h)
      h_now <- step$h
      x_res_row <- step$x_res
      x_cov_row <- build_xcov_row(h)
      x_row     <- c(x_res_row, x_cov_row)
      X_future[h, ] <- x_row

      if (anchor == "vb-mean") {
        y_hat <- sum(x_row * beta_mean)
      } else {
        stopifnot(!is.null(anchor_path), length(anchor_path) >= H)
        y_hat <- anchor_path[h]
      }
      y_anchor[h] <- y_hat
      if (m > 0L) y_hist_work <- c(y_hist_work, y_hat)
    }

    if (!is.null(seed)) set.seed(as.integer(seed))
    draws <- exal_vb_posterior_draws(object$fit, nd = nd)
    Bdraw <- draws$beta
    sdraw <- draws$sigma
    gdraw <- draws$gamma
    p0    <- object$fit$misc$p0
    A_d   <- vapply(gdraw, function(g) A.fn(p0, g), 1.0)
    B_d   <- vapply(gdraw, function(g) B.fn(p0, g), 1.0)
    lam_d <- vapply(gdraw, function(g) C.fn(p0, g) * abs(g), 1.0)

    Hh <- nrow(X_future)
    yrep     <- matrix(NA_real_, Hh, nd)
    mu_draws <- matrix(NA_real_, Hh, nd)

    ids_list <- split(seq_len(nd), ceiling(seq_len(nd) / as.integer(chunk)))
    for (ids in ids_list) {
      mm  <- length(ids)
      Bc  <- t(Bdraw[ids, , drop = FALSE])  # p x mm
      mu  <- X_future %*% Bc                # H x mm
      mu_draws[, ids] <- mu

      s_mat <- matrix(abs(rnorm(Hh * mm)), Hh, mm)
      v_mat <- matrix(rexp(Hh * mm, rate = rep(1 / sdraw[ids], each = Hh)), Hh, mm)
      z_mat <- matrix(rnorm(Hh * mm), Hh, mm)

      term_s <- sweep(s_mat, 2L, lam_d[ids] * sdraw[ids], `*`)
      term_v <- sweep(v_mat, 2L, A_d[ids],                   `*`)
      sd_mat <- sqrt(sweep(v_mat, 2L, B_d[ids] * sdraw[ids], `*`))
      yrep[, ids] <- mu + term_s + term_v + sd_mat * z_mat
    }

    out <- list(yrep = yrep, mu_draws = mu_draws, anchor_path = y_anchor)
    if (isTRUE(return_design)) out$X_future <- X_future
    return(out)
  }

  # ============ RECURSIVE mode (default; per-draw paths) ============
  if (!is.null(seed)) set.seed(as.integer(seed))
  draws <- exal_vb_posterior_draws(object$fit, nd = nd)
  Bdraw <- draws$beta  # nd x p
  sdraw <- draws$sigma
  gdraw <- draws$gamma
  p0    <- object$fit$misc$p0

  # precompute A,B,lambda per draw
  A_d   <- vapply(gdraw, function(g) A.fn(p0, g), 1.0)
  B_d   <- vapply(gdraw, function(g) B.fn(p0, g), 1.0)
  lam_d <- vapply(gdraw, function(g) C.fn(p0, g) * abs(g), 1.0)

  yrep     <- matrix(NA_real_, H, nd)
  mu_draws <- matrix(NA_real_, H, nd)

  ids_list <- split(seq_len(nd), ceiling(seq_len(nd) / as.integer(chunk)))
  for (ids in ids_list) {
    for (j in ids) {
      # per-draw state & history
      h_now        <- h_last
      y_hist_work  <- y_hist

      for (h in seq_len(H)) {
        # 1) forward reservoir with CURRENT lag history
        u_h   <- make_u(y_hist_work)
        step  <- forward_one(h_now, u_h)
        h_now <- step$h
        x_res_row <- step$x_res

        # 2) exog for this horizon
        x_cov_row <- build_xcov_row(h)

        # 3) readout design row & linear predictor for this draw
        x_row <- c(x_res_row, x_cov_row)
        mu    <- sum(x_row * Bdraw[j, ])
        mu_draws[h, j] <- mu

        # 4) draw exAL noise with (sigma_j, gamma_j)
        s  <- abs(rnorm(1))
        v  <- rexp(1, rate = 1 / sdraw[j])
        z  <- rnorm(1)
        y_h <- mu + (lam_d[j] * sdraw[j]) * s + A_d[j] * v + sqrt(B_d[j] * sdraw[j] * v) * z

        yrep[h, j] <- y_h

        # 5) append to history for next step
        if (m > 0L) y_hist_work <- c(y_hist_work, y_h)
      }
    }
  }

  # In recursive mode, there is no single anchor path and the design is draw-specific.
  list(yrep = yrep, mu_draws = mu_draws)
}

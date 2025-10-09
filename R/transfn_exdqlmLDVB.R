# R/transfn_exdqlmLDVB.R

#' Transfer Function exDQLM — LDVB algorithm
#'
#' Fits an Extended Dynamic Quantile Linear Model (exDQLM) **with an exponential
#' transfer-function regression block** using the Laplace–Delta VB (LDVB) approximation.
#' This is a modern replacement for \code{transfn_exdqlmISVB()} and relies on
#' \code{\link{tfRegMod}} to build the TF block, then calls \code{\link{exdqlmLDVB}}.
#'
#' @inheritParams exdqlmLDVB
#' @param X Numeric matrix (T x n): regressors at each time t (rows are time).
#' @param lambda Numeric scalar or length-T vector in (0,1): TF decay rate(s).
#'   If scalar, it is recycled across t.
#' @param df Vector of discount factors for the **existing** blocks in \code{model}.
#' @param dim.df Integer vector: dimensions per block for the **existing** blocks in \code{model}.
#'   (These must sum to \code{length(model$m0)}.)
#' @param tf.df Discount factors for the **TF block**. Accepted shapes:
#'   \itemize{
#'     \item length 1: one block for all TF states (size n+1).
#'     \item length 2: two blocks \eqn{(1, n)} → accumulator and all n coefficients.
#'     \item length n+1: per-state (n+1) blocks of size 1 (fine-grained control).
#'   }
#'   Defaults to \code{c(0.97, 0.97)} (two-block scheme).
#' @param tf.m0 Optional prior mean for TF block (length n+1).
#'   Defaults to zeros of length n+1.
#' @param tf.C0 Optional prior covariance for TF block ((n+1) x (n+1)).
#'   Defaults to \eqn{10^3 I_{n+1}}.
#' @param lam Deprecated alias for \code{lambda} (kept for migration). If provided
#'   and \code{lambda} missing, \code{lambda <- lam}.
#'
#' @return The result of \code{\link{exdqlmLDVB}} with two extras:
#' \itemize{
#'   \item \code{$lam} — the \code{lambda} used (scalar or vector).
#'   \item \code{$median.kt} — median time (in steps) for the TF contribution
#'         \eqn{\lambda^k |X_t^\top \hat{\beta}|} to drop below 1e-3, computed
#'         using the smoothed posterior mean \eqn{\hat{\beta}} at time T.
#' }
#' @export
#'
#' @examples
#' \donttest{
#' data("BTflow", package = "exdqlm")
#' data("nino34", package = "exdqlm")
#'
#' # Base model
#' trend.comp <- polytrendMod(order = 1, m0 = mean(BTflow), C0 = 10)
#' seas.comp  <- seasMod(p = 12, h = 1, C0 = diag(1, 2))
#' base.mod   <- combineMods(trend.comp, seas.comp)
#'
#' # TF regressors
#' X <- cbind(nino34, nino34^2)
#'
#' fit <- transfn_exdqlmLDVB(
#'   y = BTflow, p0 = 0.85, model = base.mod,
#'   X = X, df = c(1, 1), dim.df = c(1, 2),
#'   lambda = 0.9, tf.df = c(0.97, 0.97),
#'   gam.init = -3.5, sig.init = 15, tol = 0.05, n.samp = 300
#' )
#'
#' fit$lam
#' fit$median.kt
#' }
transfn_exdqlmLDVB <- function(
  y, p0, model, X,
  df, dim.df,
  lambda, tf.df = c(0.97, 0.97),
  fix.gamma = FALSE, gam.init = NA,
  fix.sigma = TRUE,  sig.init = NA,
  dqlm.ind  = FALSE,
  exps0,
  tol = 0.1,
  n.samp = 300,
  PriorSigma = NULL,
  PriorGamma = NULL,
  tf.m0, tf.C0,
  verbose = TRUE,
  debug_shapes = FALSE,
  debug_every = 5,
  lam # deprecated alias
) {
  # --- Migration nicety -------------------------------------------------------
  if (!missing(lam) && missing(lambda)) lambda <- lam

  # --- Basic checks (reuse package helpers) -----------------------------------
  y     <- check_ts(y)
  X     <- check_X(X, Tlen = length(y))
  model <- check_mod(model)

  TT <- length(y)
  n  <- ncol(X)

  if (missing(lambda)) stop("`lambda` must be provided (scalar or length T) and be in (0,1).")
  lam_vec <- as.numeric(lambda)
  if (length(lam_vec) == 1L) lam_vec <- rep(lam_vec, TT)
  if (length(lam_vec) != TT || any(!is.finite(lam_vec) | lam_vec <= 0 | lam_vec >= 1))
    stop("`lambda` values must lie strictly in (0,1).")


  if (missing(lambda)) stop("`lambda` must be provided (scalar or length T) and be in (0,1).")
  lam_vec <- as.numeric(lambda)
  if (length(lam_vec) == 1L) lam_vec <- rep(lam_vec, TT)
  if (length(lam_vec) != TT) stop("`lambda` must be scalar or length T (nrow(X)).")
  if (any(lam_vec <= 0 | lam_vec >= 1 | !is.finite(lam_vec)))
    stop("`lambda` values must lie strictly in (0,1).")

  # Defaults for TF priors
  if (missing(tf.m0)) tf.m0 <- rep(0, n + 1L) else {
    if (length(tf.m0) != (n + 1L)) stop("tf.m0 must have length n+1.")
  }
  if (missing(tf.C0)) {
    tf.C0 <- diag(1e3, n + 1L)
  } else {
    tf.C0 <- as.matrix(tf.C0)
    if (!all(dim(tf.C0) == c(n + 1L, n + 1L))) stop("tf.C0 must be (n+1) x (n+1).")
  }

  # --- Build TF block and combine with base model -----------------------------
  tf.comp   <- tfRegMod(X, lambda = lam_vec, m0 = tf.m0, C0 = tf.C0)
  aug.model <- combineMods(model, tf.comp)

  # --- Discount factor bookkeeping for TF block -------------------------------
  # Map tf.df (user) -> (df entries, block sizes) for the TF chunk.
  tf.df <- as.numeric(tf.df)

  if (length(tf.df) == 1L) {
    tf_dim_df <- n + 1L        # one block for the whole TF state
  } else if (length(tf.df) == 2L) {
    tf_dim_df <- c(1L, n)      # (accumulator, all coefficients)
  } else if (length(tf.df) == (n + 1L)) {
    tf_dim_df <- rep(1L, n + 1L) # per-state blocks
  } else {
    stop("tf.df must have length 1, 2, or n+1.")
  }

  df_all     <- c(df,   tf.df)
  dim.df_all <- c(dim.df, tf_dim_df)

  # --- Fit LDVB on the augmented model ---------------------------------------
  fit <- exdqlmLDVB(
    y = y, p0 = p0, model = aug.model,
    df = df_all, dim.df = dim.df_all,
    fix.gamma = fix.gamma, gam.init = gam.init,
    fix.sigma = fix.sigma, sig.init = sig.init,
    dqlm.ind = dqlm.ind,
    exps0 = exps0,
    tol = tol,
    n.samp = n.samp,
    PriorSigma = PriorSigma,
    PriorGamma = PriorGamma,
    verbose = verbose,
    debug_shapes = debug_shapes,
    debug_every = debug_every
  )

  # --- Extras: echo lambda & compute median k_t decay horizon -----------------
  fit$lam <- lambda

  # indices of TF block inside the combined state:
  p_base    <- length(model$m0)
  idx_acc   <- p_base + 1L            # accumulator state
  idx_beta  <- (p_base + 2L):(p_base + 1L + n)

  # posterior mean of beta at final time (smoothed):
  sm <- fit$theta.out$sm
  if (is.null(dim(sm)) || nrow(sm) < (p_base + 1L + n))
    warning("Could not locate TF block in theta.out$sm; skipping median.kt.")
  else {
    beta_hat_T <- as.numeric(sm[idx_beta, TT])   # length n
    x_dot_beta <- as.numeric(X %*% beta_hat_T)   # length T

    # For each t, solve lambda_t^k * |x_t' beta| <= 1e-3  ⇒
    # k >= (log(1e-3) - log|x_t' beta|) / log(lambda_t)
    # Guard small magnitudes and non-finite cases.
    mag   <- pmax(abs(x_dot_beta), 1e-12)
    numer <- log(1e-3) - log(mag)
    denom <- log(lam_vec) # negative (since 0<lambda<1)
    k_raw <- numer / denom
    k_raw[!is.finite(k_raw)] <- 0
    k_ce  <- pmax(0, ceiling(k_raw))

    fit$median.kt <- stats::median(k_ce[is.finite(k_ce)])
  }

  fit
}

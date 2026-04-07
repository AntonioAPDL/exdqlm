#' Transfer Function exDQLM - LDVB algorithm
#'
#' The function applies a Laplace-Delta Variational Bayes (LDVB) algorithm to
#' estimate the posterior of an exDQLM with an exponential-decay transfer
#' function component.
#'
#' @inheritParams exdqlmLDVB
#' @param X A univariate time-series which will be the input of the transfer
#'   function component.
#' @param lam Transfer function rate parameter lambda, a value between 0 and 1.
#' @param tf.df Discount factor(s) used for the transfer function component.
#' @param tf.m0 Prior mean of the transfer function component.
#' @param tf.C0 Prior covariance of the transfer function component.
#'
#' @return A object of class "\code{exdqlmLDVB}" containing the exdqlmLDVB
#'   output for the transfer-function-augmented model, plus:
#' \itemize{
#'   \item `lam` - Transfer function rate parameter lambda.
#'   \item `median.kt` - Median number of time steps until the effect of `X_t`
#'   is less than or equal to `1e-3`.
#' }
#'
#' @export
#'
#' @importFrom stats median
#'
#' @examples
#' \donttest{
#' data("scIVTmag", package = "exdqlm")
#' data("ELIanoms", package = "exdqlm")
#' y = scIVTmag[1:365]
#' X = ELIanoms[1:365]
#' trend.comp = polytrendMod(1, stats::quantile(y, 0.85), 10)
#' seas.comp = seasMod(365, c(1,2,4), C0 = 10*diag(6))
#' model = trend.comp + seas.comp
#' M1 = transfn_exdqlmLDVB(
#'   y, p0 = 0.85, model = model, X = X,
#'   df = c(1,1), dim.df = c(1,6),
#'   gam.init = -3.5, sig.init = 15,
#'   lam = 0.38, tf.df = c(0.97,0.97)
#' )
#' }
transfn_exdqlmLDVB <- function(y, p0, model, X, df, dim.df, lam, tf.df,
                               fix.gamma = FALSE, gam.init = NA,
                               fix.sigma = FALSE, sig.init = NA,
                               dqlm.ind = FALSE, exps0, tol = 0.1, n.samp = 200,
                               PriorSigma = NULL, PriorGamma = NULL,
                               tf.m0 = rep(0, 2), tf.C0 = diag(1, 2),
                               verbose = TRUE,
                               debug_shapes = FALSE, debug_every = 5) {
  # check inputs
  y = check_ts(y)
  X = check_ts(X)
  if (length(X) != length(y)) stop("y and X must be time-series of the same length")
  model = check_mod(model)
  p = length(model$m0)
  if (length(lam) != 1 || lam >= 1 || lam <= 0) stop("lam must be a single value between 0 and 1")
  if (!methods::hasArg(dim.df)) {
    if (length(df) != 1) {
      stop("length of component discount factors does not match length of component dimensions")
    }
    dim.df = p
  }
  if (length(tf.m0) != 2) stop("tf.m0 should have length 2")
  tf.C0 = as.matrix(tf.C0)
  if (any(dim(tf.C0) != 2)) stop("tf.C0 should be a 2 by 2 covariance matrix")

  # initialize quantile
  if (methods::hasArg(exps0)) {
    TT = length(y)
    if (length(exps0) != TT) stop("exp0 must have same length as y")
  } else {
    TT = length(y)
    if (!is.na(dim(model$GG)[3])) {
      if (dim(model$GG)[3] != TT) stop("time-varying dimension of GG does not match length of y")
    }
    GG = array(model$GG, c(p, p, TT)); model$GG = GG
    if (ncol(model$FF) > 1) {
      if (ncol(model$FF) != TT) stop("time-varying dimension of FF does not match length of y")
    }
    FF = matrix(model$FF, p, TT); model$FF = FF
    init.dlm = dlm_df(y, model, df, dim.df, s.priors = list(l0 = 1, S0 = 1), just.lik = FALSE)
    exps0 = apply(FF * t(init.dlm$m), 2, sum) + stats::qnorm(p0, 0, sqrt(init.dlm$s[TT]))
  }

  # augment state-space model
  temp.p = length(model$m0)
  p_aug = temp.p + 2
  FF = matrix(0, p_aug, TT)
  FF[1:temp.p, ] = model$FF
  FF[seq(temp.p + 1, temp.p + 2, 2), ] = 1
  GG = array(0, c(p_aug, p_aug, TT))
  GG[1:temp.p, 1:temp.p, ] = model$GG
  GG[(temp.p + 1):(temp.p + 2), (temp.p + 1):(temp.p + 2), ] = matrix(c(lam, 0, NA, 1), 2, 2)
  GG[(temp.p + 1), (temp.p + 2), ] = X

  # update model and dfs with transfer-function component
  tf.model <- list()
  tf.model$GG = GG
  tf.model$FF = FF
  tf.model$m0 = c(model$m0, tf.m0)
  tf.model$C0 = magic::adiag(model$C0, tf.C0)
  tf.model = as.exdqlm(tf.model)
  tf.model.df = c(df, matrix(tf.df, 1, 2))
  tf.model.dim.df = c(dim.df, rep(1, 2))

  # fit transfer-function exdqlm
  tf.return = exdqlmLDVB(
    y = y, p0 = p0, model = tf.model,
    df = tf.model.df, dim.df = tf.model.dim.df,
    fix.gamma = fix.gamma, gam.init = gam.init,
    fix.sigma = fix.sigma, sig.init = sig.init,
    dqlm.ind = dqlm.ind, exps0 = exps0, tol = tol,
    n.samp = n.samp,
    PriorSigma = PriorSigma, PriorGamma = PriorGamma,
    verbose = verbose,
    debug_shapes = debug_shapes, debug_every = debug_every
  )
  tf.return$lam = lam

  k_seq = (log(1e-3) - log(abs(c(tf.model$m0[1], tf.return$theta.out$sm[(dim(tf.return$theta.out$sm)[1] - 1), -TT]) * c(X)))) / (log(lam))
  tf.return$median.kt = stats::median(k_seq)

  # return results
  return(tf.return)
}

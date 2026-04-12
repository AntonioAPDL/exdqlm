#' Transfer Function exDQLM - LDVB algorithm
#'
#' The function applies a Laplace-Delta Variational Bayes (LDVB) algorithm to
#' estimate the posterior of an exDQLM with an exponential-decay transfer
#' function component.
#'
#' @inheritParams exdqlmLDVB
#' @param X A numeric vector or matrix of transfer-function inputs. Vectors are
#'   treated as a univariate input series. Matrices should have one row per time
#'   point and one column per covariate.
#' @param lam Transfer function rate parameter lambda, a value between 0 and 1.
#' @param tf.df Discount factor specification for the transfer function
#'   component. If \code{length(tf.df) = 1}, the value is shared by the
#'   \eqn{\zeta_t} state and the whole \eqn{\psi_t} block. If
#'   \code{length(tf.df) = 2}, it is interpreted as
#'   \code{c(df_zeta, df_psi_shared)}. If \code{length(tf.df) = k + 1}, where
#'   \eqn{k = ncol(X)}, the values are applied componentwise to
#'   \eqn{(\zeta_t, \psi_{1,t}, \dots, \psi_{k,t})}.
#' @param tf.m0 Prior mean of the transfer function component. Defaults to a
#'   zero vector of length \eqn{k+1}, where \eqn{k = ncol(X)}.
#' @param tf.C0 Prior covariance of the transfer function component. Defaults to
#'   the \eqn{(k+1)\times(k+1)} identity matrix.
#'
#' @return A object of class "\code{exdqlmLDVB}" containing the exdqlmLDVB
#'   output for the transfer-function-augmented model, plus:
#' \itemize{
#'   \item `lam` - Transfer function rate parameter lambda.
#'   \item `median.kt` - Median number of time steps until the aggregated
#'   transfer effect \eqn{|x_t^\top \psi_{t-1}|} is less than or equal to
#'   `1e-3`.
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
#' X_multi = cbind(ELIanoms[1:365], scale(scIVTmag[1:365])[, 1])
#' M2 = transfn_exdqlmLDVB(
#'   y, p0 = 0.85, model = model, X = X_multi,
#'   df = c(1,1), dim.df = c(1,6),
#'   gam.init = -3.5, sig.init = 15,
#'   lam = 0.38, tf.df = c(0.97, 0.99)
#' )
#' }
transfn_exdqlmLDVB <- function(y, p0, model, X, df, dim.df, lam, tf.df,
                               fix.gamma = FALSE, gam.init = NA,
                               fix.sigma = FALSE, sig.init = NA,
                               dqlm.ind = FALSE, exps0, tol = 0.1, n.samp = 200,
                               PriorSigma = NULL, PriorGamma = NULL,
                               tf.m0 = NULL, tf.C0 = NULL,
                               verbose = TRUE,
                               debug_shapes = FALSE, debug_every = 5) {
  prep <- .prepare_transfer_inputs(
    y = y, X = X, model = model, df = df, dim.df = dim.df,
    lam = lam, tf.df = tf.df, tf.m0 = tf.m0, tf.C0 = tf.C0,
    dim.df_missing = !methods::hasArg(dim.df)
  )
  y <- prep$y
  X <- prep$X
  model <- prep$model
  df <- prep$df
  dim.df <- prep$dim.df
  tf.model <- prep$tf.model
  tf.model.df <- prep$tf.model.df
  tf.model.dim.df <- prep$tf.model.dim.df
  TT <- prep$TT
  p <- length(model$m0)

  # initialize quantile
  if (methods::hasArg(exps0)) {
    if (length(exps0) != TT) stop("exp0 must have same length as y")
  } else {
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
  tf.return$lam = prep$lam
  tf.return$median.kt = .transfer_median_kt(tf.model = tf.model, theta.out = tf.return$theta.out, X = X, lam = prep$lam)
  tf.return$transfer_input_names = prep$transfer_input_names

  # return results
  return(tf.return)
}

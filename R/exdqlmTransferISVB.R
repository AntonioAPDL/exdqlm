#' Transfer Function exDQLM - ISVB algorithm
#'
#' The function applies an Importance Sampling Variational Bayes (ISVB) algorithm to estimate the posterior of an exDQLM with exponential decay transfer function component.
#'
#' @inheritParams exdqlmISVB
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
#' @param ... Deprecated compatibility arguments passed through to
#'   \code{exdqlmTransferISVB()}.
#'
#' @return A object of class "\code{exdqlmISVB}" containing the following:
#' \itemize{
#'   \item `run.time` - Algorithm run time in seconds.
#'   \item `iter` - Number of iterations until convergence was reached.
#'   \item `dqlm.ind` - Logical value indicating whether gamma was fixed at `0`, reducing the exDQLM to the special case of the DQLM.
#'   \item `model` - List of the augmented state-space model including `GG`, `FF`, prior parameters `m0` and `C0`.
#'   \item `p0` - The quantile which was estimated.
#'   \item `df` - Discount factors used for each block, including transfer function component.
#'   \item `dim.df` - Dimension used for each block of discount factors, including transfer function component.
#'   \item `lam` - Transfer function rate parameter lambda.
#'   \item `sig.init` - Initial value for sigma, or value at which sigma was fixed if `fix.sigma=TRUE`.
#'   \item `seq.sigma` - Sequence of sigma estimated by the algorithm until convergence.
#'   \item `samp.theta` - Posterior sample of the state vector variational distribution.
#'   \item `samp.post.pred` - Sample of the posterior predictive distributions.
#'   \item `map.standard.forecast.errors` - MAP standardized one-step-ahead forecast errors.
#'   \item `samp.sigma` - Posterior sample of scale parameter sigma variational distribution.
#'   \item `samp.vts` - Posterior sample of latent parameters, v_t, variational distributions.
#'   \item `theta.out` - List containing the variational distribution of the state vector including filtered distribution parameters (`fm` and `fC`) and smoothed distribution parameters (`sm` and `sC`).
#'   \item `vts.out` - List containing the variational distributions of latent parameters v_t.
#'   \item `median.kt` - Median number of time steps until the aggregated
#'   transfer effect \eqn{|x_t^\top \psi_{t-1}|} is less than or equal to 1e-3.
#' }
#' If `dqlm.ind=FALSE`, the object also contains:
#' \itemize{
#'   \item `gam.init` - Initial value for gamma, or value at which gamma was fixed if `fix.gamma=TRUE`.
#'   \item `seq.gamma` - Sequence of gamma estimated by the algorithm until convergence.
#'   \item `samp.gamma` - Posterior sample of skewness parameter gamma variational distribution.
#'   \item `samp.sts` - Posterior sample of latent parameters, s_t, variational distributions.
#'   \item `gammasig.out` - List containing the IS estimate of the variational distribution of `sigma` and `gamma`.
#'   \item `sts.out` - List containing the variational distributions of latent parameters s_t.
#' }
#' Or if `dqlm.ind=TRUE`, the object also contains:
#' \itemize{
#'   \item `sig.out` - As above but for the DQLM case (`gamma = 0`); list containing the IS estimate of the variational distribution of sigma.
#'  }
#' @export
#' 
#' @importFrom stats median
#'
#' @details
#' Advanced options (set via \code{options()}):
#' \itemize{
#'   \item \code{exdqlm.use_cpp_kf}: use the C++ Kalman filter bridge (default TRUE).
#'   \item \code{exdqlm.compute_elbo}: compute ELBO every iteration (default TRUE).
#'   \item \code{exdqlm.tol_elbo}: ELBO convergence tolerance (default 1e-6).
#'   \item \code{exdqlm.use_cpp_samplers}: use C++ samplers for s_t, u_t, theta (default FALSE).
#'         The GIG-based u_t sampler always uses the package C++ Devroye implementation;
#'         when FALSE, the remaining samplers fall back to R implementations.
#'   \item \code{exdqlm.use_cpp_postpred}: use C++ posterior predictive sampler (default FALSE).
#' }
#'
#' @examples
#' \donttest{
#' data("scIVTmag", package = "exdqlm")
#' data("ELIanoms", package = "exdqlm")
#' y = scIVTmag[1:1095]
#' X = ELIanoms[1:1095]
#' trend.comp = polytrendMod(1, stats::quantile(y, 0.85), 10)
#' seas.comp = seasMod(365, c(1,2,4), C0 = 10*diag(6))
#' model = trend.comp + seas.comp
#' M1 = exdqlmTransferISVB(y, p0 = 0.85, model = model,
#'                           X, df = c(1,1), dim.df = c(1,6),
#'                           gam.init = -3.5, sig.init = 15,
#'                           lam = 0.38, tf.df = c(0.97,0.97))
#' X_multi = cbind(ELIanoms[1:365], scale(scIVTmag[1:365])[, 1])
#' M2 = exdqlmTransferISVB(y, p0 = 0.85, model = model,
#'                           X_multi, df = c(1,1), dim.df = c(1,6),
#'                           gam.init = -3.5, sig.init = 15,
#'                           lam = 0.38, tf.df = c(0.97, 0.99))
#' }
#'
exdqlmTransferISVB<-function(y,p0,model,X,df,dim.df,lam,tf.df,fix.gamma=FALSE,gam.init=NA,fix.sigma=TRUE,sig.init=NA,dqlm.ind=FALSE,
                             exps0,tol=0.1,n.IS=500,n.samp=200,PriorSigma=NULL,PriorGamma=NULL,tf.m0=NULL,tf.C0=NULL,verbose=TRUE){
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
  if(methods::hasArg(exps0)){
    if(length(exps0) != TT){stop("exp0 must have same length as y")}
  }else{
    if(!is.na(dim(model$GG)[3])){
      if(dim(model$GG)[3] != TT){stop("time-varying dimension of GG does not match length of y")}
    }
    GG = array(model$GG,c(p,p,TT)); model$GG = GG
    if(ncol(model$FF)>1){
      if(ncol(model$FF) != TT){stop("time-varying dimension of FF does not match length of y")}
    }
    FF = matrix(model$FF,p,TT); model$FF = FF
    init.dlm = dlm_df(y,model,df,dim.df,s.priors=list(l0=1,S0=1),just.lik=FALSE)
    exps0 = apply(FF*t(init.dlm$m),2,sum) + stats::qnorm(p0,0,sqrt(init.dlm$s[TT]))
  }

  # fit transfer function exdqlm
  tf.return = exdqlmISVB(
    y = y, p0 = p0, model = tf.model,
    df = tf.model.df, dim.df = tf.model.dim.df,
    fix.gamma = fix.gamma, gam.init = gam.init,
    fix.sigma = fix.sigma, sig.init = sig.init,
    dqlm.ind = dqlm.ind, exps0 = exps0, tol = tol,
    n.IS = n.IS, n.samp = n.samp,
    PriorSigma = PriorSigma, PriorGamma = PriorGamma,
    verbose = verbose
  )
  tf.return$lam = prep$lam
  tf.return$median.kt = .transfer_median_kt(tf.model = tf.model, theta.out = tf.return$theta.out, X = X, lam = prep$lam)
  tf.return$transfer_input_names = prep$transfer_input_names

  # return results
  return(tf.return)
}

#' @rdname exdqlmTransferISVB
#' @export
transfn_exdqlmISVB <- function(...) {
  .Deprecated("exdqlmTransferISVB")
  exdqlmTransferISVB(...)
}

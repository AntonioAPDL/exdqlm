#' Transfer Function exDQLM - MCMC algorithm
#'
#' The function applies a Markov chain Monte Carlo (MCMC) algorithm to sample
#' the posterior of an exDQLM with an exponential-decay transfer function
#' component for a fixed transfer rate parameter `lam`.
#'
#' @inheritParams exdqlmMCMC
#' @param X A univariate time-series which will be the input of the transfer
#'   function component.
#' @param lam Transfer function rate parameter lambda, a value between 0 and 1.
#' @param tf.df Discount factor(s) used for the transfer function component.
#' @param tf.m0 Prior mean of the transfer function component.
#' @param tf.C0 Prior covariance of the transfer function component.
#'
#' @return A object of class "\code{exdqlmMCMC}" containing the
#'   \code{exdqlmMCMC()} output for the transfer-function-augmented model, plus:
#' \itemize{
#'   \item `lam` - Transfer function rate parameter lambda.
#'   \item `median.kt` - Median number of time steps until the effect of `X_t`
#'   is less than or equal to `1e-3`.
#' }
#' @export
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
#' M1 = transfn_exdqlmMCMC(
#'   y, p0 = 0.85, model = model, X = X,
#'   df = c(1,1), dim.df = c(1,6),
#'   gam.init = -3.5, sig.init = 15,
#'   lam = 0.38, tf.df = c(0.97,0.97),
#'   n.burn = 100, n.mcmc = 150
#' )
#' }
transfn_exdqlmMCMC <- function(y, p0, model, X, df, dim.df, lam, tf.df,
                               fix.gamma = FALSE, gam.init = NA,
                               fix.sigma = FALSE, sig.init = NA,
                               dqlm.ind = FALSE,
                               Sig.mh, joint.sample = FALSE,
                               n.burn = 2000, n.mcmc = 1500,
                               init.from.isvb = FALSE,
                               PriorSigma = NULL, PriorGamma = NULL,
                               verbose = TRUE,
                               init.from.vb = TRUE, vb_init_controls = NULL, vb_init_fit = NULL,
                               mh.proposal = c("slice", "laplace_rw", "rw"),
                               mh.adapt = TRUE, mh.adapt.interval = 50L,
                               mh.target.accept = c(0.20, 0.45),
                               mh.scale.bounds = c(0.1, 10),
                               mh.max_scale.step = 0.35, mh.min_burn_adapt = 50L,
                               slice.width = 0.1, slice.max.steps = Inf,
                               trace.diagnostics = TRUE, trace.every = 1L,
                               verbose.every = 500L, progress_callback = NULL,
                               tf.m0 = rep(0, 2), tf.C0 = diag(1, 2)) {
  prep <- .prepare_transfer_inputs(
    y = y, X = X, model = model, df = df, dim.df = dim.df,
    lam = lam, tf.df = tf.df, tf.m0 = tf.m0, tf.C0 = tf.C0,
    dim.df_missing = !methods::hasArg(dim.df)
  )

  tf.return <- exdqlmMCMC(
    y = prep$y, p0 = p0, model = prep$tf.model,
    df = prep$tf.model.df, dim.df = prep$tf.model.dim.df,
    fix.gamma = fix.gamma, gam.init = gam.init,
    fix.sigma = fix.sigma, sig.init = sig.init,
    dqlm.ind = dqlm.ind,
    Sig.mh = Sig.mh, joint.sample = joint.sample,
    n.burn = n.burn, n.mcmc = n.mcmc,
    init.from.isvb = init.from.isvb,
    PriorSigma = PriorSigma, PriorGamma = PriorGamma,
    verbose = verbose,
    init.from.vb = init.from.vb,
    vb_init_controls = vb_init_controls, vb_init_fit = vb_init_fit,
    mh.proposal = mh.proposal,
    mh.adapt = mh.adapt, mh.adapt.interval = mh.adapt.interval,
    mh.target.accept = mh.target.accept,
    mh.scale.bounds = mh.scale.bounds,
    mh.max_scale.step = mh.max_scale.step,
    mh.min_burn_adapt = mh.min_burn_adapt,
    slice.width = slice.width, slice.max.steps = slice.max.steps,
    trace.diagnostics = trace.diagnostics, trace.every = trace.every,
    verbose.every = verbose.every, progress_callback = progress_callback
  )

  tf.return$lam <- prep$lam
  tf.return$median.kt <- .transfer_median_kt(
    tf.model = prep$tf.model,
    theta.out = tf.return$theta.out,
    X = prep$X,
    lam = prep$lam
  )

  tf.return
}

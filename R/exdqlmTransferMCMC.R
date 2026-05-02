#' Transfer Function exDQLM - MCMC algorithm
#'
#' The function applies a Markov chain Monte Carlo (MCMC) algorithm to sample
#' the posterior of an exDQLM with an exponential-decay transfer function
#' component for a fixed transfer rate parameter \code{lam}. For multivariate
#' transfer inputs, each column of \code{X} has its own instantaneous coefficient
#' state in \eqn{\psi_t}, while a single scalar decay rate \code{lam} controls
#' persistence of the accumulated transfer effect \eqn{\zeta_t}.
#'
#' @inheritParams exdqlmMCMC
#' @param X A numeric vector or matrix of transfer-function inputs. Vectors are
#'   treated as a univariate input series. Matrices should have one row per time
#'   point and one column per covariate.
#' @param lam Single transfer-function decay-rate parameter \eqn{\lambda}, a
#'   value between 0 and 1. This scalar is shared across all transfer inputs and
#'   controls propagation of the accumulated transfer effect \eqn{\zeta_t}.
#' @param tf.df Discount factor specification for the transfer function
#'   component. These discount factors control the evolution variances of the
#'   transfer states, separately from the deterministic decay rate
#'   \code{lam}. If \code{length(tf.df) = 1}, the value is shared by the
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
#' @inherit exdqlmMCMC return
#'
#' @section Transfer-function return fields:
#' In addition to the standard \code{exdqlmMCMC()} return values, the returned
#' \code{model}, \code{df}, and \code{dim.df} entries correspond to the
#' transfer-function-augmented state-space model, with appended \eqn{\zeta_t}
#' and \eqn{\psi_t} states. The object also contains:
#' \itemize{
#'   \item \code{lam} - Single transfer-function decay-rate parameter
#'   \eqn{\lambda}.
#'   \item \code{median.kt} - Median number of time steps until the aggregated
#'   transfer effect \eqn{|x_t^\top \psi_{t-1}|} is less than or equal to
#'   \code{1e-3}.
#'   \item \code{transfer_input_names} - Column names of the transfer inputs
#'   after normalization of \code{X}.
#' }
#' @export
#'
#' @examples
#' \donttest{
#' data("scIVTmag", package = "exdqlm")
#' data("ELIanoms", package = "exdqlm")
#' y = scIVTmag[1:120]
#' X = ELIanoms[1:120]
#' trend.comp = polytrendMod(1, stats::quantile(y, 0.85), 10)
#' seas.comp = seasMod(365, c(1,2), C0 = 10*diag(4))
#' model = trend.comp + seas.comp
#' M1 = exdqlmTransferMCMC(
#'   y, p0 = 0.85, model = model, X = X,
#'   df = c(1,1), dim.df = c(1,4),
#'   gam.init = -3.5, sig.init = 15,
#'   lam = 0.38, tf.df = c(0.97,0.97),
#'   n.burn = 40, n.mcmc = 40,
#'   init.from.vb = FALSE, verbose = FALSE
#' )
#' X_multi = cbind(ELIanoms[1:120], scale(scIVTmag[1:120])[, 1])
#' M2 = exdqlmTransferMCMC(
#'   y, p0 = 0.85, model = model, X = X_multi,
#'   df = c(1,1), dim.df = c(1,4),
#'   gam.init = -3.5, sig.init = 15,
#'   lam = 0.38, tf.df = c(0.97, 0.99),
#'   n.burn = 40, n.mcmc = 40,
#'   init.from.vb = FALSE, verbose = FALSE
#' )
#' }
exdqlmTransferMCMC <- function(y, p0, model, X, df, dim.df, lam, tf.df,
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
                               tf.m0 = NULL, tf.C0 = NULL) {
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
  tf.return$transfer_input_names <- prep$transfer_input_names

  tf.return
}

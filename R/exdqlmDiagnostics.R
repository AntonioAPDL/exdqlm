#' exDQLM Diagnostics
#'
#' The function computes the following for the model(s) provided: the posterior
#' predictive loss criterion based off the check loss, the CRPS approximated as
#' a finite integrated quantile score over posterior predictive empirical
#' quantiles, the one-step-ahead distribution sequence, and both the forward and
#' reversed KL divergences from normality. The function also plots
#' the following: the qq-plot and ACF plot corresponding to the one-step-ahead
#' distribution sequence, and a time series plot of the MAP standard forecast
#' errors.
#'
#' @inheritParams exdqlmPlot
#' @param m2 An optional additional object of class "\code{exdqlmLDVB}",
#'   "\code{exdqlmMCMC}", or legacy "\code{exdqlmISVB}" to compare with `m1`.
#' @param plot Logical value indicating whether the following will be plotted for `m1` and `m2` (if provided): a qq-plot and ACF plot of the MAP one-step-ahead distribution sequence, and a time series plot of the standardized forecast errors. Default is `TRUE`.
#' @param cols Character vector of length 1 or 2 giving color(s) used to plot diagnostics. Default \code{c("red","blue")}.
#' @param ref Optional reference sample of size `length(m1$y)` from a standard
#'   normal distribution. Used to compute the KL divergences.
#' @param crps_probs Numeric vector of quantile levels used to approximate CRPS
#'   through the integrated quantile-score identity. Values must be strictly
#'   between 0 and 1. Default is `seq(0.01, 0.99, by = 0.01)`.
#' @param crps_weights Optional non-negative numeric weights for `crps_probs`.
#'   When `NULL`, equal weights are used. When provided, weights are normalized
#'   to sum to 1.
#'
#' @return An object of class "\code{exdqlmDiagnostic}" containing the following:
#'  \itemize{
#'  \item `m1.uts` - The one-step-ahead distribution sequence of `m1`.
#'  \item `m1.KL` - The KL divergence of `m1.uts` and a standard normal.
#'  \item `m1.KL.flip` - The reversed ("flipped") KL divergence of `m1.uts`
#'  and a standard normal.
#'  \item `m1.CRPS` - The mean CRPS approximated by a finite integrated
#'  quantile score over posterior predictive empirical quantiles.
#'  \item `m1.pplc` - The posterior predictive loss criterion of `m1` based off the check loss function.
#'  \item `m1.qq` - The ordered pairs of the qq-plot comparing `m1.uts` with a standard normal distribution.
#'  \item `m1.acf` - The autocorrelations of `m1.uts` by lag.
#'  \item `m1.rt` - Run-time of the original model `m1` in seconds.
#'  \item `m1.msfe` - MAP standardized one-step-ahead forecast errors from the original model `m1`.
#'  \item `y` - The original time-series used to fit `m1`.
#'  \item `crps.method` - The CRPS approximation method.
#'  \item `crps.probs` - The quantile levels used for the CRPS approximation.
#'  \item `crps.weights` - The normalized weights used for the CRPS approximation.
#'  }
#'  If `m2` is provided, analogous results for `m2` are also included in the list.
#' @export
#'
#' @examples
#' \donttest{
#' data("scIVTmag", package = "exdqlm")
#' old = options(exdqlm.max_iter = 15L)
#' y = scIVTmag[1:60]
#' model = polytrendMod(1, stats::quantile(y, 0.85), 10)
#' M0 = exdqlmLDVB(y, p0 = 0.85, model, df = c(0.95), dim.df = c(1),
#'                   gam.init = -3.5, sig.init = 15,
#'                   n.samp = 20, tol = 0.2, verbose = FALSE)
#' M0.diags = exdqlmDiagnostics(M0, plot = FALSE)
#' options(old)
#' }
#'
exdqlmDiagnostics <- function(m1,m2=NULL,plot=TRUE,cols=c("red","blue"),ref=NULL,
                              crps_probs = seq(0.01, 0.99, by = 0.01),
                              crps_weights = NULL){
  safe_metric_mean <- function(x) {
    x <- as.numeric(x)
    x <- x[is.finite(x)]
    if (!length(x)) NA_real_ else mean(x)
  }
  crps_probs <- .exdqlm_validate_crps_probs(crps_probs)
  crps_weights <- .exdqlm_validate_crps_weights(crps_weights, length(crps_probs))

  # check inputs
  y = m1$y
  TT = length(y)
  if(!is.exdqlmMCMC(m1) && !is.exdqlmISVB(m1) && !is.exdqlmLDVB(m1)){
    stop("m1 must be an output from 'exdqlmLDVB()', 'exdqlmMCMC()', or legacy 'exdqlmISVB()'")
  }
  cols = c(matrix(cols,2,1))

  ### m1
  # m1 seq.uts
  m1.uts = stats::pnorm(m1$map.standard.forecast.errors)
  # m1 KL divergence
  TT = length(m1$map.standard.forecast.errors)
  if(is.null(ref)){
    ref = stats::rnorm(TT)
  }else{
    ref = c(ref)
    if(length(ref)!=TT){
      stop("ref should be a sample of size 'length(y)' from a standard normal distribution")
    }
  }
  m1.KL = safe_metric_mean(FNN::KL.divergence(ref,m1$map.standard.forecast.errors))
  m1.KL.flip = safe_metric_mean(FNN::KL.divergence(m1$map.standard.forecast.errors, ref))
  # m1 pplc
  m1.loss = matrix(NA,TT,dim(m1$samp.post.pred)[2])
  for(t in 1:TT){m1.loss[t,] = CheckLossFn(m1$p0,y[t]-m1$samp.post.pred[t,])}
  m1.pplc = sum(rowMeans(m1.loss))
  m1.CRPS = safe_metric_mean(.exdqlm_crps_vec(y, m1$samp.post.pred, probs = crps_probs, weights = crps_weights))
  # m1 qqplot
  m1.qq = stats::qqnorm(m1$map.standard.forecast.errors,plot=FALSE)
  # m1 acf
  m1.acf = stats::acf(m1.uts,plot=FALSE)
  #
  retlist = list(m1.uts=m1.uts,m1.KL=m1.KL,m1.KL.flip=m1.KL.flip,m1.CRPS=m1.CRPS,m1.pplc=m1.pplc,m1.qq=m1.qq,m1.acf=m1.acf,
                 m1.rt=m1$run.time,m1.msfe=m1$map.standard.forecast.errors,y=y,
                 crps.method = "integrated_quantile_score",
                 crps.probs = crps_probs,
                 crps.weights = crps_weights)

  ### m2
  if(!is.null(m2)){
    # check inputs
    if(!is.exdqlmMCMC(m2) && !is.exdqlmISVB(m2) && !is.exdqlmLDVB(m2)){
      stop("m2 must be an output from 'exdqlmLDVB()', 'exdqlmMCMC()', or legacy 'exdqlmISVB()'")
    }
    if(dim(m1$samp.theta)[2] != TT){
      stop("length of dynamic quantile in m2 does not match data")
    }
    if(TT != length(m2$map.standard.forecast.errors)){
      stop("length of m1 quantile does not match length of m2 quantile")
    }
    if(m1$p0 != m2$p0){
      stop("quantiles estimated in m1 and m2 do not match")
    }
    # m2 seq.uts
    m2.uts = stats::pnorm(m2$map.standard.forecast.errors)
    retlist[["m2.msfe"]] = m2$map.standard.forecast.errors
    retlist[["m2.uts"]] = m2.uts
    # m2 KL divergence
    retlist[["m2.KL"]] = safe_metric_mean(FNN::KL.divergence(ref,m2$map.standard.forecast.errors))
    retlist[["m2.KL.flip"]] = safe_metric_mean(FNN::KL.divergence(m2$map.standard.forecast.errors, ref))
    # m2 pplc
    m2.loss = matrix(NA,TT,dim(m2$samp.post.pred)[2])
    for(t in 1:TT){m2.loss[t,] = CheckLossFn(m2$p0,y[t]-m2$samp.post.pred[t,])}
    retlist[["m2.pplc"]] = sum(rowMeans(m2.loss))
    retlist[["m2.CRPS"]] = safe_metric_mean(.exdqlm_crps_vec(y, m2$samp.post.pred, probs = crps_probs, weights = crps_weights))
    # m2 qqplot
    retlist[["m2.qq"]] = stats::qqnorm(m2$map.standard.forecast.errors,plot=FALSE)
    # m2 acf
    retlist[["m2.acf"]] = stats::acf(m2.uts,plot=FALSE)
    # m2 run-time
    retlist[["m2.rt"]] = m2$run.time
  }
  class(retlist) <- "exdqlmDiagnostic"
  
  if(plot){
    plot(retlist, cols = cols)
  }

  # return model checks
  return(invisible(retlist))
}

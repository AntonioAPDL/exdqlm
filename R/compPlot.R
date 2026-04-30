#' Plot a component of an exDQLM
#'
#' The function plots the dynamic MAP estimates and 95% credible intervals (CrIs) of a specified component of an exDQLM. Alternatively, if `just.theta=TRUE` the MAP estimates and 95% credible intervals (CrIs) of a single element of the dynamic state vector are plotted.
#'
#' @inheritParams exdqlmPlot
#' @param index Vector of consecutive integers in \eqn{\{1,\dots,q\}} indicating the component or element of the state vector to be plotted.
#' @param add Logical value indicating whether the dynamic component will be added to existing plot. Default is \code{FALSE}.
#' @param col Character vector of length 1 giving color of the dynamic component to be plotted. Default is `purple`.
#' @param just.theta Logical; if `TRUE`, the function plots the dynamic distribution of the `index` element of the state vector. If `just.theta=TRUE`, `index` must have length 1.
#'
#' @return A list of the following is returned:
#'  \itemize{
#'   \item `map.comp` - MAP estimate of the dynamic component (or element of the state vector).
#'   \item `lb.comp` - Lower bound of the 95% CrIs of the dynamic component (or element of the state vector).
#'   \item `ub.comp` - Upper bound of the 95% CrIs of the dynamic component (or element of the state vector).
#' }
#' @export
#'
#' @examples
#' \donttest{
#' data("scIVTmag", package = "exdqlm")
#' old = options(exdqlm.max_iter = 15L)
#' y = scIVTmag[1:80]
#' trend.comp = polytrendMod(2, rep(0, 2), 10*diag(2))
#' seas.comp = seasMod(365, c(1, 2), C0 = 10*diag(4))
#' model = trend.comp + seas.comp
#' M0 = exdqlmLDVB(y, p0 = 0.85, model, df = c(0.98, 1), dim.df = c(2, 4),
#'                    gam.init = -3.5, sig.init = 15,
#'                    n.samp = 20, tol = 0.2, verbose = FALSE)
#' # plot first harmonic component
#' compPlot(M0, index = c(3, 4), col = "blue")
#' options(old)
#' }
#'
compPlot <- function(m1, index, add = FALSE, col="purple", just.theta = FALSE, cr.percent = 0.95){

  # check input
  if(!is.exdqlmMCMC(m1) && !is.exdqlmISVB(m1) && !is.exdqlmLDVB(m1)){
    stop("m1 must be an output from 'exdqlmLDVB()', 'exdqlmMCMC()', or legacy 'exdqlmISVB()'")
  }
  y = m1$y
  TT = length(y)
  p = length(index)
  theta_samps = m1$samp.theta
  if (methods::is(theta_samps, "mcmc")) {
    theta_samps = array(as.numeric(theta_samps), dim = dim(m1$samp.theta))
  }
  n.samp = dim(theta_samps)[3]
  if(just.theta & p != 1){
    stop("when 'just.theta = TRUE', 'index' should have length 1")
  }
  if(cr.percent<=0 | cr.percent>=1){
    stop("cr.percent must be between 0 and 1")
  }
  half.alpha = (1 - cr.percent)/2

  # 95% CrIs
  if(!just.theta){
      big_FF = array(m1$model$FF[index,],c(p,TT,n.samp))
      quant.samps = colSums(big_FF*array(theta_samps[index,,],c(p,TT,n.samp)))
  }else{
      quant.samps = matrix(theta_samps[index,,],TT,n.samp)
  }
  map.quant = rowMeans(quant.samps)
  lb.quant = matrixStats::rowQuantiles(quant.samps, probs = half.alpha)
  ub.quant = matrixStats::rowQuantiles(quant.samps, probs = cr.percent + half.alpha)

  # plot
  if(!add){
    stats::plot.ts(y,xlab="time",ylab=sprintf("%s%% CrIs",100*cr.percent),ylim=range(c(lb.quant,ub.quant)),col="white")
  }
  ts.xy = grDevices::xy.coords(y)
  graphics::lines(ts.xy$x,map.quant,col=col,lwd=1.5)
  graphics::lines(ts.xy$x,lb.quant,col=col,lwd=0.75,lty=2)
  graphics::lines(ts.xy$x,ub.quant,col=col,lwd=0.75,lty=2)

  ret = list(map.comp=map.quant,lb.comp=lb.quant,ub.comp=ub.quant)
  return(invisible(ret))
}

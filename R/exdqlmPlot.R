#' Plot exDQLM
#'
#' The function plots the MAP estimates and 95% credible intervals (CrIs) of the dynamic quantile of an exDQLM.
#'
#' @param m1 A fitted dynamic \code{exdqlmFit} object, such as an object
#'   returned by \code{\link{exdqlmLDVB}}, \code{\link{exdqlmMCMC}}, or
#'   legacy \code{\link{exdqlmISVB}}.
#' @param add Logical value indicating whether the dynamic quantile will be added to existing plot. Default is \code{FALSE}.
#' @param col Character vector of length 1 giving color of the dynamic quantile to be plotted. Default is `purple`.
#' @param cr.percent Numeric in \code{(0, 1)} indicating the probability mass for the credible
#'   intervals (e.g., \code{0.95}). Default \code{0.95}.
#' @param plot Logical value indicating whether to draw the plot. If \code{FALSE}, the
#'   function only returns the plotted summaries. Default is \code{TRUE}.
#' @param xlim,ylim Optional limits passed to the base plotting call when \code{plot = TRUE}.
#' @param xlab,ylab Optional axis labels passed to the base plotting call when \code{plot = TRUE}.
#' @param lwd,lwd.interval Line widths for the dynamic quantile and credible interval
#'   bounds, respectively.
#' @param lty.interval Line type for the credible interval bounds.
#'
#' @return A list of the following is returned:
#'  \itemize{
#'   \item `map.quant` - MAP estimate of the dynamic quantile.
#'   \item `lb.quant` - Lower bound of the 95% CrIs of the dynamic quantile.
#'   \item `ub.quant` - Upper bound of the 95% CrIs of the dynamic quantile.
#'   \item `x` - Time/index values used for plotting.
#' }
#' @export
#'
#' @examples
#' \donttest{
#' data("scIVTmag", package = "exdqlm")
#' old = options(exdqlm.max_iter = 15L)
#' y = scIVTmag[1:60]
#' model = polytrendMod(1, stats::quantile(y, 0.85), 10)
#' M0 = exdqlmLDVB(y, p0 = 0.85, model, df = c(0.98), dim.df = c(1),
#'                    gam.init = -3.5, sig.init = 15,
#'                    n.samp = 20, tol = 0.2, verbose = FALSE)
#' exdqlmPlot(M0, col = "blue")
#' q.summary = exdqlmPlot(M0, plot = FALSE)
#' options(old)
#' }
#'
exdqlmPlot <- function(m1,add=FALSE,col="purple",cr.percent=0.95,
                       plot = TRUE, xlim = NULL, ylim = NULL, xlab = "time",
                       ylab = NULL, lwd = 1.5, lwd.interval = 0.75,
                       lty.interval = 2){

  # check inputs
  if(!is.exdqlmFit(m1)){
    stop("m1 must be a fitted dynamic exdqlmFit object from 'exdqlmLDVB()', 'exdqlmMCMC()', or legacy 'exdqlmISVB()'")
  }
  y = m1$y
  TT = length(y)
  p = dim(m1$samp.theta)[1]
  n.samp = dim(m1$samp.theta)[3]
  if(cr.percent<=0 | cr.percent>=1){
    stop("cr.percent must be between 0 and 1")
  }
  half.alpha = (1 - cr.percent)/2

  # 95% CrIs
  big_FF = array(m1$model$FF,c(p,TT,n.samp))
  quant.samps = colSums(big_FF*m1$samp.theta)
  map.quant = rowMeans(quant.samps)
  lb.quant = matrixStats::rowQuantiles(quant.samps, probs = half.alpha)
  ub.quant = matrixStats::rowQuantiles(quant.samps, probs = cr.percent + half.alpha)

  ts.xy = grDevices::xy.coords(y)
  if(is.null(ylab)){
    ylab = sprintf("quantile %s%% CrIs",100*cr.percent)
  }
  if(is.null(ylim)){
    ylim = range(c(y,lb.quant,ub.quant))
  }

  # plot
  if(plot){
    if(!add){
      plot.args = list(x = y, xlab = xlab, ylab = ylab, ylim = ylim, col = "dark grey")
      if(!is.null(xlim)){
        plot.args$xlim = xlim
      }
      do.call(stats::plot.ts, plot.args)
    }
    graphics::lines(ts.xy$x,map.quant,col=col,lwd=lwd)
    graphics::lines(ts.xy$x,lb.quant,col=col,lwd=lwd.interval,lty=lty.interval)
    graphics::lines(ts.xy$x,ub.quant,col=col,lwd=lwd.interval,lty=lty.interval)
  }

  ret = list(map.quant=map.quant,lb.quant=lb.quant,ub.quant=ub.quant,x=ts.xy$x)
  return(invisible(ret))
}

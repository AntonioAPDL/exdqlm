.exdqlm_primary_class <- function(x) {
  class(x)[1L]
}

##################################
#### "exdqlmForecast" objects ####
##################################
# included: is(), print(), summary(), plot()

#' \code{exdqlmForecast} objects
#'
#' \code{is.exdqlmForecast} tests if its argument is a \code{exdqlmForecast} object. 
#' 
#' @usage is.exdqlmForecast(x)
#'
#' @param x an \strong{R} object
#'
#' @export
is.exdqlmForecast = function(x){ return(methods::is(x,"exdqlmForecast")) }

#' Print Method for \code{exdqlmForecast} Objects
#'
#' @param x An \code{exdqlmForecast} object.
#' @param ... Additional arguments (unused).
#' 
#' @export
#' 
#' @examples
#' \donttest{
#'  data("scIVTmag", package = "exdqlm")
#'  old = options(exdqlm.max_iter = 15L)
#'  y = scIVTmag[1:60]
#'  model = polytrendMod(1, stats::quantile(y, 0.85), 10)
#'  M0 = exdqlmLDVB(y, p0 = 0.85, model, df = c(0.98), dim.df = c(1),
#'                   gam.init = -3.5, sig.init = 15,
#'                   n.samp = 20, tol = 0.2, verbose = FALSE)
#'  M0.forecast = exdqlmForecast(start.t = 50, k = 5, m1 = M0)
#'  print(M0.forecast)
#'  options(old)
#' }
#'
print.exdqlmForecast <- function(x, ...) {
  cat("Dynamic quantile forecast\n")
  cat("Class:", paste(class(x), collapse = ", "), "\n")
  cat("Fitted model class:", .exdqlm_primary_class(x$m1), "\n")
  cat("Quantile level (p0):", .exdqlm_format_number(.exdqlm_safe_p0(x$m1)), "\n")
  cat("Observations in fitted model:", length(x$m1$y), "\n")
  cat("State dimension:", length(x$m1$model$m0), "\n")
  cat("Forecast start index:", x$start.t, "\n")
  cat("Forecast horizon:", x$k, "\n")
  cat("Credible interval mass:", .exdqlm_format_number(x$cr.percent), "\n")
  cat("Posterior forecast draws:", if (is.null(x$samp.fore)) "not stored" else ncol(as.matrix(x$samp.fore)), "\n")
  cat("Use with: summary(), plot(), diagnostics()\n")
  invisible(x)
}

#' Summary Method for \code{exdqlmForecast} Objects
#'
#' @param object An \code{exdqlmForecast} object.
#' @param ... Additional arguments (unused).
#' 
#' @export
#' 
#' @examples
#' \donttest{
#'  data("scIVTmag", package = "exdqlm")
#'  old = options(exdqlm.max_iter = 15L)
#'  y = scIVTmag[1:60]
#'  model = polytrendMod(1, stats::quantile(y, 0.85), 10)
#'  M0 = exdqlmLDVB(y, p0 = 0.85, model, df = c(0.98), dim.df = c(1),
#'                   gam.init = -3.5, sig.init = 15,
#'                   n.samp = 20, tol = 0.2, verbose = FALSE)
#'  M0.forecast = exdqlmForecast(start.t = 50, k = 5, m1 = M0)
#'  summary(M0.forecast)
#'  options(old)
#' }
#'
summary.exdqlmForecast <- function(object, ...) {
  half.alpha <- (1 - object$cr.percent) / 2
  zlb <- stats::qnorm(half.alpha)
  zub <- stats::qnorm(object$cr.percent + half.alpha)
  out <- data.frame(
    step = seq_len(object$k),
    forecast_quantile = as.numeric(object$ff),
    forecast_variance = as.numeric(object$fQ),
    lower = as.numeric(object$ff + zlb * sqrt(pmax(object$fQ, 0))),
    upper = as.numeric(object$ff + zub * sqrt(pmax(object$fQ, 0))),
    check.names = FALSE
  )
  print.exdqlmForecast(object, ...)
  cat("\nForecast summary:\n")
  print(out, row.names = FALSE, digits = 4)
  invisible(out)
}

#' Plot Method for \code{exdqlmForecast} Objects
#'
#' @param x An \code{exdqlmForecast} object.
#' @param ... Additional graphical arguments. The optional \code{cols} element
#'   controls fitted/forecast colors, and \code{add} controls whether the
#'   forecast is added to an existing plot.
#'
#' @return Invisibly returns \code{x}.
#' 
#' @export
#' 
#' @examples
#' \donttest{
#'  data("scIVTmag", package = "exdqlm")
#'  old = options(exdqlm.max_iter = 15L)
#'  y = scIVTmag[1:60]
#'  model = polytrendMod(1, stats::quantile(y, 0.85), 10)
#'  M0 = exdqlmLDVB(y, p0 = 0.85, model, df = c(0.98), dim.df = c(1),
#'                   gam.init = -3.5, sig.init = 15,
#'                   n.samp = 20, tol = 0.2, verbose = FALSE)
#'  M0.forecast = exdqlmForecast(start.t = 50, k = 5, m1 = M0)
#'  plot(M0.forecast)
#'  options(old)
#' }
#'
plot.exdqlmForecast <- function(x, ...) {
  aa = list(...)
  if(is.null(aa$cols)){cols=c("purple","magenta")}else{cols = aa$cols}
  if(is.null(aa$add)){add=FALSE}else{add=aa$add}
  
  y = x$m1$y
  p = dim(x$m1$model$GG)[1]
  TT = dim(x$m1$model$GG)[3]
  half.alpha = (1 - x$cr.percent)/2
  
  # filtered estimate for reference
  FF.start.t = matrix(x$m1$model$FF[,1:x$start.t], p, x$start.t)
  fm.start.t = matrix(x$m1$theta.out$fm[,1:x$start.t], p, x$start.t)
  qmap = colSums(matrix(FF.start.t*fm.start.t,p,x$start.t))
  fC.start.t = array(x$m1$theta.out$fC[,,1:x$start.t], c(p,p,x$start.t))
  temp.var = matrix(NA,p,x$start.t)
  for(t in 1:x$start.t){ temp.var[,t] = fC.start.t[,,t] %*% FF.start.t[,t] }
  qvar = colSums(FF.start.t * temp.var)
  qsd = sqrt(qvar)
  zlb = stats::qnorm(half.alpha)
  zub = stats::qnorm(x$cr.percent + half.alpha)
  qlb = qmap + zlb * qsd
  qub = qmap + zub * qsd
  # forecast estimates
  fqlb = x$ff + zlb * sqrt(x$fQ)
  fqub = x$ff + zub * sqrt(x$fQ)
  # filtered and forecasted quantiles & CrIs
  ts.xy = grDevices::xy.coords(y)
  if(!add){
    stats::plot.ts(y,xlim=c(ts.xy$x[x$start.t]-2*x$k*diff(ts.xy$x)[1],ts.xy$x[x$start.t]+x$k*diff(ts.xy$x)[1]),ylim=range(c(y,qlb,qub,fqlb,fqub)),type="l",ylab="quantile forecast",col="dark grey",xlab="time")
  }
  graphics::lines(ts.xy$x[1:x$start.t],qlb,col=cols[1],lty=3)
  graphics::lines(ts.xy$x[1:x$start.t],qub,col=cols[1],lty=3)
  graphics::lines(ts.xy$x[1:x$start.t],qmap,col=cols[1],lwd=1.5)
  graphics::lines(seq(from = ts.xy$x[x$start.t], by = diff(ts.xy$x)[1], length.out = x$k+1),c(qmap[x$start.t],x$ff),col=cols[2])
  graphics::lines(seq(from = ts.xy$x[x$start.t], by = diff(ts.xy$x)[1], length.out = x$k+1),c(qub[x$start.t],fqub),col=cols[2],lty=3)
  graphics::lines(seq(from = ts.xy$x[x$start.t], by = diff(ts.xy$x)[1], length.out = x$k+1),c(qlb[x$start.t],fqlb),col=cols[2],lty=3)
  invisible(x)
  
}


#' Diagnostics Method for \code{exdqlmForecast} Objects
#' 
#' Computes held-out forecast scores from one or two \code{exdqlmForecast}
#' objects returned by [exdqlmForecast()]. This function evaluates posterior 
#' predictive forecast draws against observations reserved outside the fitted sample.
#'
#' @param object An \code{exdqlmForecast} object, returned by
#'   [exdqlmForecast()] with \code{return.draws = TRUE}.
#' @param y Required numeric vector or time series of held-out observations. Its length
#'   must equal the forecast horizon.
#' @param m2 An optional second object of class "\code{exdqlmForecast}" to
#'   compare with \code{object}.
#' @param p0 Optional quantile level used for the check-loss calculation. When
#'   \code{NULL}, the value is taken from \code{object$m1$p0}. If \code{m2} is
#'   supplied, its fitted quantile level must agree with the resolved value.
#' @param crps_probs Optional numeric vector of quantile levels used to approximate CRPS
#'   through the integrated quantile-score identity. Values must be strictly
#'   between 0 and 1. Default is \code{seq(0.01, 0.99, by = 0.01)}.
#' @param crps_weights Optional non-negative numeric weights for
#'   \code{crps_probs}. When \code{NULL}, equal weights are used. When provided,
#'   weights are normalized to sum to 1.
#' @param ... Additional arguments (unused).
#'
#' @return An object of class "\code{exdqlmForecastDiagnostic}" containing:
#' \itemize{
#'   \item \code{y} - Held-out observations used for scoring.
#'   \item \code{p0} - Quantile level used for check loss.
#'   \item \code{horizon} - Forecast horizon.
#'   \item \code{m1.check_loss} - Mean target-quantile check loss for
#'   \code{m1}.
#'   \item \code{m1.CRPS} - Mean CRPS approximation for \code{m1}.
#'   \item \code{m1.pointwise} - Pointwise held-out scores for \code{m1}.
#'   \item \code{crps.method}, \code{crps.probs}, and \code{crps.weights} -
#'   CRPS approximation metadata.
#' }
#' If \code{m2} is supplied, analogous \code{m2.*} fields are included.
#'
#' @details
#' The check loss is computed at the target quantile level \code{p0} using the
#' forecast quantile means \code{ff} stored in each forecast object. CRPS is
#' computed from \code{samp.fore} using the same finite integrated quantile-score
#' approximation used by [exdqlmDiagnostics()]. This function does not compute
#' KL diagnostics because KL in \pkg{exdqlm} is defined for fitted
#' one-step-ahead MAP standardized forecast errors, not for arbitrary held-out
#' forecast draws.
#'
#' @export
#' 
#' @examples
#' \donttest{
#' data("scIVTmag", package = "exdqlm")
#' old = options(exdqlm.max_iter = 15L)
#' y = scIVTmag[1:65]
#' y_train = y[1:60]
#' y_holdout = y[61:65]
#' model = polytrendMod(1, stats::quantile(y_train, 0.85), 10)
#' M0 = exdqlmLDVB(y_train, p0 = 0.85, model, df = c(0.98), dim.df = c(1),
#'                  gam.init = -3.5, sig.init = 15,
#'                  n.samp = 20, tol = 0.2, verbose = FALSE)
#' fFF = model$FF[, 1, drop = FALSE]
#' fGG = model$GG
#' M0.forecast = exdqlmForecast(start.t = 60, k = 5, m1 = M0,
#'                              fFF = fFF, fGG = fGG,
#'                              return.draws = TRUE, n.samp = 20, seed = 123,
#'                              plot = FALSE)
#' score = diagnostics(M0.forecast, y = y_holdout)
#' score
#' }
#'
diagnostics.exdqlmForecast <- function(object, y, m2 = NULL, p0 = NULL,
                                       crps_probs = seq(0.01, 0.99, by = 0.01),
                                       crps_weights = NULL, ...) {
  
    exdqlmForecastDiagnostics(m1 = object, m2 = m2, y = y, p0 = p0,
                              crps_probs = crps_probs, crps_weights = crps_weights)
}
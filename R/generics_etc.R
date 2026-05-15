##################################
######## "exdqlm" objects ########
##################################

#' \code{exdqlm} objects
#'
#' \code{is.exdqlm} tests if its argument is a \code{exdqlm} object.
#'
#' @usage is.exdqlm(m)
#'
#' @param m an \strong{R} object
#'
#' @export
is.exdqlm = function(m){ return(methods::is(m,"exdqlm")) }

#' \code{exdqlm} objects
#'
#' \code{as.exdqlm} attempts to turn a list into an \code{exdqlm} object. Works for time-invariant \code{dlm} objects created using the \pkg{dlm} package.
#'
#' @usage as.exdqlm(m)
#'
#' @param m a list containing named elements m0, C0, FF and GG.
#'
#' @return An object of class "\code{exdqlm}" containing the state space model components:
#' \itemize{
#'   \item FF - Observational vector.
#'   \item GG - Evolution matrix.
#'   \item m0 - Prior mean of the state vector.
#'   \item C0 - Prior covariance of the state vector.
#' }
#' @export
as.exdqlm <- function(m){
  if(is.exdqlm(m)){
    return(m)
  }
  if(!is.list(m)){
    stop("Input must be a list with named elements m0, C0, FF and GG.")
  }
  if(methods::is(m,"dlm")){
    if(!is.null(m$JFF) | !is.null(m$JGG) |
       !is.null(m$JV) | !is.null(m$JW)){
      stop("'dlm' object input must be a time-invariant")
    }
    m$FF = t(m$FF)
  }

  # check for required components & remove extras
  refnn <- c("m0","C0","FF","GG")
  nn <- names(m)
  check <- !sapply(m, is.null)
  ind <- match(refnn,nn)
  if(anyNA(ind)){
    stop(paste("Component(s)",paste(refnn[is.na(ind)], collapse = ", "), "is (are) missing."))
  }
  final.ind = match(nn[ind][check[ind]],nn)
  model = m[final.ind]

  class(model) <- "exdqlm"
  model = check_mod(model)

  return(model)
}

#' Addition for \code{exdqlm} objects
#'
#' Combines two state space blocks into a single state space model for an exDQLM.
#'
#' @method + exdqlm
#' @rdname plus-exdqlm
#'
#' @param m1 object of class "\code{exdqlm}" containing the first model to be combined.
#' @param m2 object of class "\code{exdqlm}" containing the second model to be combined.
#'
#' @return An object of class "\code{exdqlm}" containing the new combined state space model components:
#' \itemize{
#'   \item FF - Observational vector.
#'   \item GG - Evolution matrix.
#'   \item m0 - Prior mean of the state vector.
#'   \item C0 - Prior covariance of the state vector.
#' }
#'
#' @examples
#' trend.comp = polytrendMod(2, rep(0, 2), 10*diag(2))
#' seas.comp = seasMod(365, c(1,2,4), C0 = 10*diag(6))
#' model = trend.comp + seas.comp
#'
#' @export
"+.exdqlm" <- function(m1, m2){
  m1 = check_mod(m1)
  m2 = check_mod(m2)
  n = length(m1$m0) + length(m2$m0)
  model<- NULL
  if(ncol(m1$FF)>1 | ncol(m2$FF)>1){
    if(ncol(m1$FF)>1 & ncol(m2$FF)>1 & ncol(m1$FF) != ncol(m2$FF)){
      stop("incompatible number of columns in m1$FF and m2$FF")
    }
    model$FF = matrix(0,n,max(ncol(m1$FF),ncol(m2$FF)))
    model$FF[1:nrow(m1$FF),] = m1$FF
    model$FF[(nrow(m1$FF)+1):n,] = m2$FF
  }else{
    model$FF = matrix(c(m1$FF,m2$FF),n,1)
  }
  if(!is.na(dim(m1$GG)[3]) | !is.na(dim(m2$GG)[3])){
    if(!is.na(dim(m1$GG)[3]) & !is.na(dim(m2$GG)[3]) & dim(m1$GG)[3] != dim(m2$GG)[3]){
      stop("incompatible third dimensions of m1$GG and m2$GG")
    }
    model$GG = array(0,c(n,n,max(dim(m1$GG)[3],dim(m2$GG)[3],na.rm = TRUE)))
    model$GG[1:dim(m1$GG)[1],1:dim(m1$GG)[1],] = m1$GG
    model$GG[(dim(m1$GG)[1]+1):n,(dim(m1$GG)[1]+1):n,] = m2$GG
  }else{
    model$GG = magic::adiag(m1$GG,m2$GG)
  }
  model$m0 = matrix(c(m1$m0,m2$m0),n,1)
  model$C0 = magic::adiag(m1$C0,m2$C0)

  class(model) <- "exdqlm"
  return(model)
}

#' Print exDQLM model details
#'
#' Print the details of the exDQLM model.
#' @param x a \code{exdqlm} object.
#' @param ... further arguments (unused).
#'
#' @export
print.exdqlm <- function(x,...){
  refnn <- c("m0","C0","FF","GG")
  descrip = c("Prior mean of the state vector:",
              "Prior covariance of the state vector:",
              "Observational vector:",
              "Evolution matrix:")
  nn <- names(x)
  check <- !sapply(x, is.null)
  ind <- match(refnn,nn)
  ind <- ind[!is.na(ind)]
  final.ind = match(nn[ind][check[ind]],nn)
  # print
  for (i in 1:4){
    cat(descrip[i],"\n")
    print(x[final.ind[i]])
    cat("\n")
  }
}

#' Summary exDQLM model details
#'
#' Print the details of the exDQLM model.
#' @param object a \code{exdqlm} object.
#' @param ... further arguments (unused).
#'
#' @export
summary.exdqlm <- function(object,...){
  refnn <- c("m0","C0","FF","GG")
  descrip = c("Prior mean of the state vector:",
              "Prior covariance of the state vector:",
              "Observational vector:",
              "Evolution matrix:")
  nn <- names(object)
  check <- !sapply(object, is.null)
  ind <- match(refnn,nn)
  ind <- ind[!is.na(ind)]
  final.ind = match(nn[ind][check[ind]],nn)
  # print
  for (i in 1:4){
    cat(descrip[i],"\n")
    print(object[final.ind[i]])
    cat("\n")
  }
}



##################################
###### "exdqlmMCMC" objects ######
##################################

#' \code{exdqlmMCMC} objects
#'
#' \code{is.exdqlmMCMC} tests if its argument is a \code{exdqlmMCMC} object.
#'
#' @usage is.exdqlmMCMC(m)
#'
#' @param m an \strong{R} object
#'
#' @export
is.exdqlmMCMC = function(m){ return(methods::is(m,"exdqlmMCMC")) }


#' Print Method for \code{exdqlmMCMC} Objects
#'
#' @param x An \code{exdqlmMCMC} object.
#' @param ... Additional arguments (unused).
#'
#' @export
#'
#' @examples
#' \donttest{
#' data("scIVTmag", package = "exdqlm")
#' y = scIVTmag[1:60]
#' model = polytrendMod(1, stats::quantile(y, 0.85), 10)
#' M2 = exdqlmMCMC(y, p0 = 0.85, model, df = c(0.98), dim.df = c(1),
#'                 gam.init = -3.5, sig.init = 15,
#'                 n.burn = 20, n.mcmc = 20,
#'                 init.from.vb = FALSE, verbose = FALSE)
#' print(M2)
#' }
#'
print.exdqlmMCMC <- function(x, ...) {
  if(!x$dqlm.ind){
    cat("Bayesian Dynamic Quantile Regression Model (exDQLM)\n")
  }else{
    cat("Bayesian Dynamic Quantile Regression Model (DQLM)\n")
  }
  cat("Number of Observations:", length(x$y), "\n")
  cat("State Dimension:", length(x$model$m0), "\n")
  cat("Discount factors ( dimensions ):", paste(x$df,"(", x$dim.df, ")",collapse = ", "),"\n \n")
  #
  if(!x$dqlm.ind){
    cat("exDQLM fitted using MCMC\n")
  }else{
    cat("DQLM fitted using MCMC\n")
  }
  cat("Burn-in:", x$n.burn, ", MCMC samples:", x$n.mcmc , "\n")
  cat("Run-time:", x$run.time, "seconds\n")
}

#' Summary Method for \code{exdqlmMCMC} Objects
#'
#' @param object An \code{exdqlmMCMC} object.
#' @param ... Additional arguments (unused).
#'
#' @export
#'
#' @examples
#' \donttest{
#' data("scIVTmag", package = "exdqlm")
#' y = scIVTmag[1:60]
#' model = polytrendMod(1, stats::quantile(y, 0.85), 10)
#' M2 = exdqlmMCMC(y, p0 = 0.85, model, df = c(0.98), dim.df = c(1),
#'                 gam.init = -3.5, sig.init = 15,
#'                 n.burn = 20, n.mcmc = 20,
#'                 init.from.vb = FALSE, verbose = FALSE)
#' summary(M2)
#' }
#'
summary.exdqlmMCMC <- function(object, ...) {
  if(!object$dqlm.ind){
    cat("Bayesian Dynamic Quantile Regression Model (exDQLM)\n")
  }else{
    cat("Bayesian Dynamic Quantile Regression Model (DQLM)\n")
  }
  cat("Number of Observations:", length(object$y), "\n")
  cat("State Dimension:", length(object$model$m0), "\n")
  cat("Discount factors ( dimensions ):", paste(object$df,"(", object$dim.df, ")",collapse = ", "),"\n \n")
  #
  if(!object$dqlm.ind){
    cat("exDQLM fitted using MCMC\n")
  }else{
    cat("DQLM fitted using MCMC\n")
  }
  cat("Burn-in:", object$n.burn, ", MCMC samples:", object$n.mcmc , "\n")
  cat("Run-time:", object$run.time, "seconds\n")
}

#' Plot Method for \code{exdqlmMCMC} Objects
#'
#' @param x An \code{exdqlmMCMC} object.
#' @param ... Additional arguments.
#'
#' @export
#'
#' @examples
#' \donttest{
#' data("scIVTmag", package = "exdqlm")
#' y = scIVTmag[1:60]
#' model = polytrendMod(1, stats::quantile(y, 0.85), 10)
#' M2 = exdqlmMCMC(y, p0=0.85, model, df = c(0.98), dim.df = c(1),
#'                 gam.init = -3.5, sig.init = 15,
#'                 n.burn = 20, n.mcmc = 20,
#'                 init.from.vb = FALSE, verbose = FALSE)
#' plot(M2)
#' }
#'
plot.exdqlmMCMC<- function(x, ...) {
  exdqlmPlot(x,...)
}



##################################
###### "exdqlmISVB" objects ######
##################################

#' \code{exdqlmISVB} objects
#'
#' \code{is.exdqlmISVB} tests if its argument is a \code{exdqlmISVB} object.
#'
#' @usage is.exdqlmISVB(m)
#'
#' @param m an \strong{R} object
#'
#' @export
#'
#'
is.exdqlmISVB = function(m){ return(methods::is(m,"exdqlmISVB")) }

#' Print Method for \code{exdqlmISVB} Objects
#'
#' @param x An \code{exdqlmISVB} object.
#' @param ... Additional arguments (unused).
#'
#' @export
#'
#' @examples
#' \donttest{
#' data("scIVTmag", package = "exdqlm")
#' old = options(exdqlm.max_iter = 15L)
#' y = scIVTmag[1:60]
#' model = polytrendMod(1, stats::quantile(y, 0.85), 10)
#' # Legacy ISVB object retained for backward-compatible inspection methods
#' M0 = exdqlmISVB(y, p0 = 0.85, model, df = c(0.98), dim.df = c(1),
#'                    gam.init = -3.5, sig.init = 15,
#'                    n.IS = 20, n.samp = 20, tol = 0.2,
#'                    verbose = FALSE)
#' print(M0)
#' options(old)
#' }
#'
print.exdqlmISVB <- function(x, ...) {
  if(!x$dqlm.ind){
    cat("Bayesian Dynamic Quantile Regression Model (exDQLM)\n")
  }else{
    cat("Bayesian Dynamic Quantile Regression Model (DQLM)\n")
  }
  cat("Number of Observations:", length(x$y), "\n")
  cat("State Dimension:", length(x$model$m0), "\n")
  cat("Discount factors ( dimensions ):", paste(x$df,"(", x$dim.df, ")",collapse = ", "),"\n \n")
  #
  if(!x$dqlm.ind){
    cat("exDQLM fitted using legacy ISVB\n")
    cat("Parameters estimated with IS:", paste(if(!x$fix.gamma){"gamma"}, if(!x$fix.sigma){"sigma"}, if(x$fix.sigma && x$fix.gamma){"none"}, collapse=", ") , "\n")
  }else{
    cat("DQLM fitted using legacy ISVB\n")
  }
  cat("Iterations until convergence:", x$iter, "\n")
  cat("Run-time:", x$run.time, "seconds\n")
}

#' Summary Method for \code{exdqlmISVB} Objects
#'
#' @param object An \code{exdqlmISVB} object.
#' @param ... Additional arguments (unused).
#'
#' @export
#'
#' @examples
#' \donttest{
#' data("scIVTmag", package = "exdqlm")
#' old = options(exdqlm.max_iter = 15L)
#' y = scIVTmag[1:60]
#' model = polytrendMod(1, stats::quantile(y, 0.85), 10)
#' # Legacy ISVB object retained for backward-compatible inspection methods
#' M0 = exdqlmISVB(y, p0 = 0.85, model, df = c(0.98), dim.df = c(1),
#'                    gam.init = -3.5, sig.init = 15,
#'                    n.IS = 20, n.samp = 20, tol = 0.2,
#'                    verbose = FALSE)
#' summary(M0)
#' options(old)
#' }
#'
summary.exdqlmISVB <- function(object, ...) {
  if(!object$dqlm.ind){
    cat("Bayesian Dynamic Quantile Regression Model (exDQLM)\n")
  }else{
    cat("Bayesian Dynamic Quantile Regression Model (DQLM)\n")
  }
  cat("Number of Observations:", length(object$y), "\n")
  cat("State Dimension:", length(object$model$m0), "\n")
  cat("Discount factors ( dimensions ):", paste(object$df,"(", object$dim.df, ")",collapse = ", "),"\n \n")
  #
  if(!object$dqlm.ind){
    cat("exDQLM fitted using legacy ISVB\n")
    cat("Parameters estimated with IS:", paste(if(!object$fix.gamma){"gamma"}, if(!object$fix.sigma){"sigma"}, if(object$fix.sigma && object$fix.gamma){"none"}, collapse=", ") , "\n")
  }else{
    cat("DQLM fitted using legacy ISVB\n")
  }
  cat("Iterations until convergence:", object$iter, "\n")
  cat("Run-time:", object$run.time, "seconds\n")
}

#' Plot Method for \code{exdqlmISVB} Objects
#'
#' @param x An \code{exdqlmISVB} object.
#' @param ... Additional arguments.
#'
#' @export
#'
#' @examples
#' \donttest{
#' data("scIVTmag", package = "exdqlm")
#' old = options(exdqlm.max_iter = 15L)
#' y = scIVTmag[1:60]
#' model = polytrendMod(1, stats::quantile(y, 0.85), 10)
#' # Legacy ISVB object retained for backward-compatible plotting methods
#' M0 = exdqlmISVB(y, p0 = 0.85, model, df = c(0.98), dim.df = c(1),
#'                    gam.init = -3.5, sig.init = 15,
#'                    n.IS = 20, n.samp = 20, tol = 0.2,
#'                    verbose = FALSE)
#' plot(M0)
#' options(old)
#' }
#'
plot.exdqlmISVB <- function(x, ...) {
  exdqlmPlot(x,...)
}



##################################
###### "exdqlmLDVB" objects ######
##################################

#' \code{exdqlmLDVB} objects
#'
#' \code{is.exdqlmLDVB} tests if its argument is a \code{exdqlmLDVB} object.
#'
#' @usage is.exdqlmLDVB(m)
#'
#' @param m an \strong{R} object
#'
#' @export
#'
#'
is.exdqlmLDVB = function(m){ return(methods::is(m,"exdqlmLDVB")) }

#' Print Method for \code{exdqlmLDVB} Objects
#'
#' @param x An \code{exdqlmLDVB} object.
#' @param ... Additional arguments (unused).
#'
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
#' print(M0)
#' options(old)
#' }
#'
print.exdqlmLDVB <- function(x, ...) {
  if(!x$dqlm.ind){
    cat("Bayesian Dynamic Quantile Regression Model (exDQLM)\n")
  }else{
    cat("Bayesian Dynamic Quantile Regression Model (DQLM)\n")
  }
  cat("Number of Observations:", length(x$y), "\n")
  cat("State Dimension:", length(x$model$m0), "\n")
  cat("Discount factors ( dimensions ):", paste(x$df,"(", x$dim.df, ")",collapse = ", "),"\n \n")
  #
  if(!x$dqlm.ind){
    cat("exDQLM fitted using LDVB\n")
    cat("Parameters estimated with LD:", paste(if(!x$fix.gamma){"gamma"}, if(!x$fix.sigma){"sigma"}, if(x$fix.sigma && x$fix.gamma){"none"}, collapse=", ") , "\n")
  }else{
    cat("DQLM fitted using VB\n")
  }
  cat("Iterations until convergence:", x$iter, "\n")
  cat("Run-time:", x$run.time, "seconds\n")
}

#' Summary Method for \code{exdqlmLDVB} Objects
#'
#' @param object An \code{exdqlmLDVB} object.
#' @param ... Additional arguments (unused).
#'
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
#' summary(M0)
#' options(old)
#' }
#'
summary.exdqlmLDVB <- function(object, ...) {
  if(!object$dqlm.ind){
    cat("Bayesian Dynamic Quantile Regression Model (exDQLM)\n")
  }else{
    cat("Bayesian Dynamic Quantile Regression Model (DQLM)\n")
  }
  cat("Number of Observations:", length(object$y), "\n")
  cat("State Dimension:", length(object$model$m0), "\n")
  cat("Discount factors ( dimensions ):", paste(object$df,"(", object$dim.df, ")",collapse = ", "),"\n \n")
  #
  if(!object$dqlm.ind){
    cat("exDQLM fitted using LDVB\n")
    cat("Parameters estimated with LD:", paste(if(!object$fix.gamma){"gamma"}, if(!object$fix.sigma){"sigma"}, if(object$fix.sigma && object$fix.gamma){"none"}, collapse=", ") , "\n")
  }else{
    cat("DQLM fitted using VB\n")
  }
  cat("Iterations until convergence:", object$iter, "\n")
  cat("Run-time:", object$run.time, "seconds\n")
}

#' Plot Method for \code{exdqlmLDVB} Objects
#'
#' @param x An \code{exdqlmLDVB} object.
#' @param ... Additional arguments.
#'
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
#' plot(M0)
#' options(old)
#' }
#'
plot.exdqlmLDVB <- function(x, ...) {
  exdqlmPlot(x,...)
}


##################################
#### "exalStaticMCMC" / "exalStaticLDVB" ###
##################################

.plot_exal_static_quantiles <- function(map.quant, lb.quant, ub.quant, add = FALSE, col = "purple",
                                        cr.percent = 0.95, ...) {
  idx <- seq_along(map.quant)
  if (!isTRUE(add)) {
    yr <- range(c(map.quant, lb.quant, ub.quant), finite = TRUE)
    if (!all(is.finite(yr))) yr <- range(map.quant, finite = TRUE)
    if (!all(is.finite(yr))) yr <- c(-1, 1)
    if (diff(yr) == 0) yr <- yr + c(-1, 1) * 1e-6
    graphics::plot(idx, map.quant, type = "n",
                   xlab = "index",
                   ylab = sprintf("fitted quantile %.0f%% CrIs", 100 * cr.percent),
                   ylim = yr, ...)
  }
  graphics::lines(idx, map.quant, col = col, lwd = 1.5)
  if (all(is.finite(lb.quant))) graphics::lines(idx, lb.quant, col = col, lwd = 0.75, lty = 2)
  if (all(is.finite(ub.quant))) graphics::lines(idx, ub.quant, col = col, lwd = 0.75, lty = 2)
  invisible(list(map.quant = map.quant, lb.quant = lb.quant, ub.quant = ub.quant))
}

#' \code{exalStaticMCMC} objects
#'
#' \code{is.exalStaticMCMC} tests if its argument is an \code{exalStaticMCMC} object.
#'
#' @usage is.exalStaticMCMC(m)
#'
#' @param m an \strong{R} object
#'
#' @export
is.exalStaticMCMC <- function(m){ return(methods::is(m,"exalStaticMCMC")) }

#' Print Method for \code{exalStaticMCMC} Objects
#'
#' @param x An \code{exalStaticMCMC} object.
#' @param ... Additional arguments (unused).
#'
#' @export
print.exalStaticMCMC <- function(x, ...) {
  model_lab <- .exdqlm_static_model_label(x$dqlm.ind)
  n <- if (!is.null(x$X)) nrow(as.matrix(x$X)) else NA_integer_
  p <- if (!is.null(x$X)) ncol(as.matrix(x$X)) else NA_integer_

  cat("Bayesian Linear Quantile Regression (exAL family)\n")
  cat("Model:", model_lab, "\n")
  cat("Method: MCMC\n")
  cat("Observations:", n, "\n")
  cat("Predictors:", p, "\n")
  cat("Quantile level (p0):", x$p0, "\n")
  cat("Burn-in:", x$n.burn, ", MCMC samples:", x$n.mcmc, "\n")
  cat("Run-time:", x$run.time, "seconds\n")
}

#' Summary Method for \code{exalStaticMCMC} Objects
#'
#' @param object An \code{exalStaticMCMC} object.
#' @param ... Additional arguments (unused).
#'
#' @export
summary.exalStaticMCMC <- function(object, ...) {
  print.exalStaticMCMC(object, ...)
  sigma_mean <- tryCatch(mean(as.numeric(object$samp.sigma)), error = function(e) NA_real_)
  cat("Posterior mean sigma:", sigma_mean, "\n")
  if (!isTRUE(object$dqlm.ind)) {
    gamma_mean <- tryCatch(mean(as.numeric(object$samp.gamma)), error = function(e) NA_real_)
    cat("Posterior mean gamma:", gamma_mean, "\n")
  }
}

#' Plot Method for \code{exalStaticMCMC} Objects
#'
#' @param x An \code{exalStaticMCMC} object.
#' @param add Logical; add to an existing plot.
#' @param col Character vector of length 1 giving color for fitted quantiles.
#' @param cr.percent Numeric in \code{(0, 1)} for credible-interval mass.
#' @param ... Additional arguments passed to \code{\link[graphics]{plot}} when
#'   \code{add = FALSE}.
#'
#' @return A list with \code{map.quant}, \code{lb.quant}, and \code{ub.quant}.
#'
#' @export
plot.exalStaticMCMC <- function(x, add = FALSE, col = "purple", cr.percent = 0.95, ...) {
  if (cr.percent <= 0 || cr.percent >= 1) stop("cr.percent must be between 0 and 1")
  X <- as.matrix(x$X)
  beta_draws <- as.matrix(x$samp.beta)
  q_draws <- beta_draws %*% t(X)
  half.alpha <- (1 - cr.percent) / 2
  map.quant <- as.numeric(colMeans(q_draws))
  lb.quant <- as.numeric(apply(q_draws, 2, stats::quantile, probs = half.alpha, na.rm = TRUE))
  ub.quant <- as.numeric(apply(q_draws, 2, stats::quantile, probs = cr.percent + half.alpha, na.rm = TRUE))
  .plot_exal_static_quantiles(map.quant, lb.quant, ub.quant, add = add, col = col, cr.percent = cr.percent, ...)
}

#' \code{exalStaticLDVB} objects
#'
#' \code{is.exalStaticLDVB} tests if its argument is an \code{exalStaticLDVB} object.
#'
#' @usage is.exalStaticLDVB(m)
#'
#' @param m an \strong{R} object
#'
#' @export
is.exalStaticLDVB <- function(m){ return(methods::is(m,"exalStaticLDVB")) }

#' Print Method for \code{exalStaticLDVB} Objects
#'
#' @param x An \code{exalStaticLDVB} object.
#' @param ... Additional arguments (unused).
#'
#' @export
print.exalStaticLDVB <- function(x, ...) {
  model_lab <- .exdqlm_static_model_label(x$dqlm.ind)
  n <- if (!is.null(x$misc$n)) as.integer(x$misc$n) else if (!is.null(x$X)) nrow(as.matrix(x$X)) else NA_integer_
  p <- if (!is.null(x$misc$p)) as.integer(x$misc$p) else if (!is.null(x$X)) ncol(as.matrix(x$X)) else NA_integer_
  p0 <- if (!is.null(x$p0)) as.numeric(x$p0)[1] else if (!is.null(x$misc$p0)) as.numeric(x$misc$p0)[1] else NA_real_

  cat("Bayesian Linear Quantile Regression (exAL family)\n")
  cat("Model:", model_lab, "\n")
  cat("Method: LDVB\n")
  cat("Observations:", n, "\n")
  cat("Predictors:", p, "\n")
  cat("Quantile level (p0):", p0, "\n")
  cat("Converged:", isTRUE(x$converged), "\n")
  cat("Iterations:", x$iter, "\n")
  cat("Run-time:", x$run.time, "seconds\n")
}

#' Summary Method for \code{exalStaticLDVB} Objects
#'
#' @param object An \code{exalStaticLDVB} object.
#' @param ... Additional arguments (unused).
#'
#' @export
summary.exalStaticLDVB <- function(object, ...) {
  print.exalStaticLDVB(object, ...)
  sigma_mean <- if (isTRUE(object$dqlm.ind)) {
    if (!is.null(object$qsig$E_sigma)) as.numeric(object$qsig$E_sigma)[1] else NA_real_
  } else {
    if (!is.null(object$qsiggam$sigma_mean)) as.numeric(object$qsiggam$sigma_mean)[1] else NA_real_
  }
  cat("Posterior mean sigma:", sigma_mean, "\n")
  if (!isTRUE(object$dqlm.ind)) {
    gamma_mean <- if (!is.null(object$qsiggam$gamma_mean)) as.numeric(object$qsiggam$gamma_mean)[1] else NA_real_
    cat("Posterior mean gamma:", gamma_mean, "\n")
  }
}

#' Plot Method for \code{exalStaticLDVB} Objects
#'
#' @param x An \code{exalStaticLDVB} object.
#' @param X Optional design matrix used to compute fitted quantiles. If omitted,
#'   the method uses \code{x$X} when available.
#' @param add Logical; add to an existing plot.
#' @param col Character vector of length 1 giving color for fitted quantiles.
#' @param cr.percent Numeric in \code{(0, 1)} for credible-interval mass.
#' @param ... Additional arguments passed to \code{\link[graphics]{plot}} when
#'   \code{add = FALSE}.
#'
#' @return A list with \code{map.quant}, \code{lb.quant}, and \code{ub.quant}.
#'
#' @export
plot.exalStaticLDVB <- function(x, X = NULL, add = FALSE, col = "purple", cr.percent = 0.95, ...) {
  if (cr.percent <= 0 || cr.percent >= 1) stop("cr.percent must be between 0 and 1")
  if (is.null(X)) X <- x$X
  if (is.null(X)) stop("plot.exalStaticLDVB requires design matrix X (missing in object and argument).")
  X <- as.matrix(X)
  beta_mean <- as.numeric(x$qbeta$m)
  map.quant <- as.numeric(drop(X %*% beta_mean))
  if (!is.null(x$qbeta$V)) {
    Vb <- as.matrix(x$qbeta$V)
    z <- stats::qnorm((1 + cr.percent) / 2)
    sd_path <- sqrt(pmax(rowSums((X %*% Vb) * X), 0))
    lb.quant <- map.quant - z * sd_path
    ub.quant <- map.quant + z * sd_path
  } else {
    lb.quant <- rep(NA_real_, length(map.quant))
    ub.quant <- rep(NA_real_, length(map.quant))
  }
  .plot_exal_static_quantiles(map.quant, lb.quant, ub.quant, add = add, col = col, cr.percent = cr.percent, ...)
}

#' \code{exal_mcmc} objects
#'
#' \code{is.exal_mcmc} tests if its argument is an \code{exal_mcmc} object.
#'
#' @usage is.exal_mcmc(m)
#'
#' @param m an \strong{R} object
#'
#' @export
is.exal_mcmc <- function(m){ return(methods::is(m,"exal_mcmc")) }

#' Print Method for \code{exal_mcmc} Objects
#'
#' @param x An \code{exal_mcmc} object.
#' @param ... Additional arguments (unused).
#'
#' @export
print.exal_mcmc <- function(x, ...) {
  print.exalStaticMCMC(x, ...)
}

#' Summary Method for \code{exal_mcmc} Objects
#'
#' @param object An \code{exal_mcmc} object.
#' @param ... Additional arguments (unused).
#'
#' @export
summary.exal_mcmc <- function(object, ...) {
  summary.exalStaticMCMC(object, ...)
}

#' Plot Method for \code{exal_mcmc} Objects
#'
#' @param x An \code{exal_mcmc} object.
#' @param add Logical; add to an existing plot.
#' @param col Character vector of length 1 giving color for fitted quantiles.
#' @param cr.percent Numeric in \code{(0, 1)} for credible-interval mass.
#' @param ... Additional arguments passed to \code{\link[graphics]{plot}} when
#'   \code{add = FALSE}.
#'
#' @return A list with \code{map.quant}, \code{lb.quant}, and \code{ub.quant}.
#'
#' @export
plot.exal_mcmc <- function(x, add = FALSE, col = "purple", cr.percent = 0.95, ...) {
  plot.exalStaticMCMC(x, add = add, col = col, cr.percent = cr.percent, ...)
}

#' \code{exal_ldvb} objects
#'
#' \code{is.exal_ldvb} tests if its argument is an \code{exal_ldvb} object.
#'
#' @usage is.exal_ldvb(m)
#'
#' @param m an \strong{R} object
#'
#' @export
is.exal_ldvb <- function(m){ return(methods::is(m,"exal_ldvb")) }

#' Print Method for \code{exal_ldvb} Objects
#'
#' @param x An \code{exal_ldvb} object.
#' @param ... Additional arguments (unused).
#'
#' @export
print.exal_ldvb <- function(x, ...) {
  print.exalStaticLDVB(x, ...)
}

#' Summary Method for \code{exal_ldvb} Objects
#'
#' @param object An \code{exal_ldvb} object.
#' @param ... Additional arguments (unused).
#'
#' @export
summary.exal_ldvb <- function(object, ...) {
  summary.exalStaticLDVB(object, ...)
}

#' Plot Method for \code{exal_ldvb} Objects
#'
#' @param x An \code{exal_ldvb} object.
#' @param X Optional design matrix used to compute fitted quantiles. If omitted,
#'   the method uses \code{x$X} when available.
#' @param add Logical; add to an existing plot.
#' @param col Character vector of length 1 giving color for fitted quantiles.
#' @param cr.percent Numeric in \code{(0, 1)} for credible-interval mass.
#' @param ... Additional arguments passed to \code{\link[graphics]{plot}} when
#'   \code{add = FALSE}.
#'
#' @return A list with \code{map.quant}, \code{lb.quant}, and \code{ub.quant}.
#'
#' @export
plot.exal_ldvb <- function(x, X = NULL, add = FALSE, col = "purple", cr.percent = 0.95, ...) {
  plot.exalStaticLDVB(x, X = X, add = add, col = col, cr.percent = cr.percent, ...)
}

##################################
### "exdqlmDiagnostic" objects ###
##################################

#' \code{exdqlmDiagnostic} objects
#'
#' \code{is.exdqlmDiagnostic} tests if its argument is a \code{exdqlmDiagnostic} object.
#'
#' @usage is.exdqlmDiagnostic(x)
#'
#' @param x an \strong{R} object
#'
#' @export
is.exdqlmDiagnostic = function(x){ return(methods::is(x,"exdqlmDiagnostic")) }

.exdqlm_diagnostic_vector <- function(x, prefix) {
  c(
    "KL" = as.numeric(x[[paste0(prefix, "KL")]]),
    "KL (flipped)" = if (!is.null(x[[paste0(prefix, "KL.flip")]])) as.numeric(x[[paste0(prefix, "KL.flip")]]) else NA_real_,
    "CRPS" = if (!is.null(x[[paste0(prefix, "CRPS")]])) as.numeric(x[[paste0(prefix, "CRPS")]]) else NA_real_,
    "pplc" = as.numeric(x[[paste0(prefix, "pplc")]]),
    "run-time (s)" = as.numeric(x[[paste0(prefix, "rt")]])
  )
}

.exdqlm_diagnostic_table <- function(x) {
  M1 <- .exdqlm_diagnostic_vector(x, "m1.")
  if (is.null(x$m2.KL)) {
    data.frame(Diagnostic = names(M1), M1 = unname(M1), check.names = FALSE)
  } else {
    M2 <- .exdqlm_diagnostic_vector(x, "m2.")
    data.frame(Diagnostic = names(M1), M1 = unname(M1), M2 = unname(M2), check.names = FALSE)
  }
}

#' Print Method for \code{exdqlmDiagnostic} Objects
#'
#' @param x An \code{exdqlmDiagnostic} object.
#' @param ... Additional arguments (unused).
#'
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
#' M0.diags = exdqlmDiagnostics(M0, plot=FALSE)
#' print(M0.diags)
#' options(old)
#' }
#'
print.exdqlmDiagnostic <- function(x, ...) {
  old_opts <- options(scipen = 999)
  on.exit(options(old_opts), add = TRUE)
  print(.exdqlm_diagnostic_table(x), row.names = FALSE, digits = 3)
  invisible(x)
}

#' Summary Method for \code{exdqlmDiagnostic} Objects
#'
#' @param object An \code{exdqlmDiagnostic} object.
#' @param ... Additional arguments (unused).
#'
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
#' summary(M0.diags)
#' options(old)
#' }
#'
summary.exdqlmDiagnostic <- function(object, ...) {
  out <- .exdqlm_diagnostic_table(object)
  print(out, row.names = FALSE, digits = 3)
  invisible(out)
}

#' Plot Method for \code{exdqlmDiagnostic} Objects
#'
#' @param x An \code{exdqlmDiagnostic} object.
#' @param ... Additional arguments (unused).
#'
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
#' plot(M0.diags)
#' options(old)
#' }
#'
plot.exdqlmDiagnostic <- function(x, ...) {
  aa = list(...)
  if(is.null(aa$cols)){cols=c("red","blue")}else{cols = aa$cols}

  # get ranges
  if(is.null(x$m2.KL)){
    qq.x.range = range(x$m1.qq$x)
    qq.y.range = range(x$m1.qq$y)
    acf.y.range = range(x$m1.acf$acf)
    fe.y.range = range(x$m1.msfe)
  }else{
    qq.x.range = range(c(x$m1.qq$x,x$m2.qq$x))
    qq.y.range = range(c(x$m1.qq$y,x$m2.qq$y))
    acf.y.range = range(c(x$m1.acf$acf,x$m2.acf$acf))
    fe.y.range = range(c(x$m1.msfe,x$m2.msfe))
  }
  # m1 qqplot
  plot(x$m1.qq,main="",col=cols[1],pch=20,xlab="Theoretical Quantiles",ylab="M1 Sample Quantiles",xlim=qq.x.range,ylim=qq.y.range)
  graphics::abline(a=0,b=1)
  # m1 acf
  plot(x$m1.acf,ylab="M1 ACF",col=cols[1],main="",ylim=acf.y.range)
  # m1 forecast errors
  ts.xy = grDevices::xy.coords(x$y)
  graphics::plot(ts.xy$x,x$m1.msfe,ylab="M1 standard forecast errors",xlab="time",col=cols[1],pch=20,type="l",ylim=fe.y.range)
  graphics::abline(h=0,lty=2)
  ### m2
  if(!is.null(x$m2.KL)){
    # m2 qqplot
    plot(x$m2.qq,main="",col=cols[2],pch=20,xlab="Theoretical Quantiles",ylab="M2 Sample Quantiles",xlim=qq.x.range,ylim=qq.y.range)
    graphics::abline(a=0,b=1)
    # m2 acf
    plot(x$m2.acf,ylab="M2 ACF",col=cols[2],main="",ylim=acf.y.range)
    # m2 forecast errors
    graphics::plot(ts.xy$x,x$m2.msfe,ylab="M2 standard forecast errors", xlab="time",col=cols[2],pch=20,type="l",ylim=fe.y.range)
    graphics::abline(h=0,lty=2)
  }
}




##################################
#### "exdqlmForecast" objects ####
##################################

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
  #
  cat("k-step-ahead Quantile Forecasts of an exDQLM\n")
  cat("Number of Observations:", length(x$m1$y), "\n")
  cat("State Dimension:", length(x$m1$model$m0), "\n")
  cat("Forecasts start at time index", x$start.t, "and forecast k =", x$k, "steps ahead\n")
  if(!is.null(x$samp.fore)){
    cat("Posterior forecast draws stored:", ncol(as.matrix(x$samp.fore)), "\n")
  }
  #
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
  #
  cat("k-step-ahead Quantile Forecasts of an exDQLM\n")
  cat("Number of Observations:", length(object$m1$y), "\n")
  cat("State Dimension:", length(object$m1$model$m0), "\n")
  cat("Forecasts start at time index", object$start.t, "and forecast k =", object$k, "steps ahead\n")
  if(!is.null(object$samp.fore)){
    cat("Posterior forecast draws stored:", ncol(as.matrix(object$samp.fore)), "\n")
  }
  #
}

#' Plot Method for \code{exdqlmForecast} Objects
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

}

#### "exdqlmSynthesis" objects ####
####################################

#' \code{exdqlmSynthesis} objects
#'
#' \code{is.exdqlmSynthesis} tests if its argument is an
#' \code{exdqlmSynthesis} object returned by \code{\link{quantileSynthesis}}.
#'
#' @usage is.exdqlmSynthesis(x)
#'
#' @param x an \strong{R} object
#'
#' @export
is.exdqlmSynthesis <- function(x) {
  return(methods::is(x, "exdqlmSynthesis"))
}

#' Print Method for \code{exdqlmSynthesis} Objects
#'
#' @param x An \code{exdqlmSynthesis} object.
#' @param ... Additional arguments (unused).
#'
#' @export
print.exdqlmSynthesis <- function(x, ...) {
  cat("Posterior predictive synthesis from separately fitted quantiles\n")
  cat("Time points:", nrow(as.matrix(x$draws)), "\n")
  cat("Synthesized draws per time:", ncol(as.matrix(x$draws)), "\n")
  cat("Input quantile levels:", paste(format(x$levels), collapse = ", "), "\n")
  if (!is.null(x$method)) {
    cat("Isotonic correction:", isTRUE(x$method$isotonic), "\n")
    cat("Monotone rearrangement:", isTRUE(x$method$rearrange), "\n")
  }
  invisible(x)
}

#' Summary Method for \code{exdqlmSynthesis} Objects
#'
#' @param object An \code{exdqlmSynthesis} object.
#' @param time Optional vector of time values. If supplied, it must have length
#'   equal to the number of rows in \code{object$draws}.
#' @param ... Additional arguments (unused).
#'
#' @return A data frame containing pointwise summaries of the synthesized
#'   posterior predictive draws.
#'
#' @export
summary.exdqlmSynthesis <- function(object, time = NULL, ...) {
  TT <- nrow(as.matrix(object$draws))
  if (is.null(time)) {
    time <- seq_len(TT)
  } else if (length(time) != TT) {
    stop("time must have length equal to the number of synthesized time points")
  }
  data.frame(
    time = time,
    mean = as.numeric(object$summary$mean),
    q025 = as.numeric(object$summary$q025),
    q250 = as.numeric(object$summary$q250),
    q500 = as.numeric(object$summary$q500),
    q750 = as.numeric(object$summary$q750),
    q975 = as.numeric(object$summary$q975)
  )
}

#' Plot Method for \code{exdqlmSynthesis} Objects
#'
#' Plot the pointwise posterior predictive interval produced by
#' \code{\link{quantileSynthesis}}. The method is intentionally separate from
#' \code{quantileSynthesis()} so the synthesis step remains a computation,
#' while the returned object still has a standard plotting interface.
#'
#' @param x An \code{exdqlmSynthesis} object.
#' @param y Optional observed series to overlay.
#' @param time Optional time vector for the synthesized summaries. If omitted,
#'   \code{seq_len(T)} is used, where \code{T} is the number of synthesized time
#'   points.
#' @param add Logical; add the synthesis interval to an existing plot.
#' @param interval Numeric in \code{(0, 1)} giving the plotted central interval.
#'   Currently \code{0.50} and \code{0.95} are supported from stored summaries.
#' @param show.median Logical; draw the synthesized posterior median.
#' @param show.mean Logical; draw the synthesized posterior mean.
#' @param band.col Fill color for the predictive interval.
#' @param median.col Color for the posterior median line.
#' @param mean.col Color for the posterior mean line.
#' @param y.col Color for the optional observed series.
#' @param border Border color for the predictive interval polygon.
#' @param xlab,ylab,main Graphical labels.
#' @param xlim,ylim Optional axis limits.
#' @param ... Additional graphical arguments passed to the initial
#'   \code{plot()} call when \code{add = FALSE}.
#'
#' @export
plot.exdqlmSynthesis <- function(x, y = NULL, time = NULL, add = FALSE,
                                 interval = 0.95, show.median = TRUE,
                                 show.mean = FALSE,
                                 band.col = grDevices::adjustcolor("lightblue", alpha.f = 0.35),
                                 median.col = "blue",
                                 mean.col = "darkblue",
                                 y.col = "dark grey",
                                 border = NA,
                                 xlab = "time",
                                 ylab = "posterior predictive synthesis",
                                 main = NULL,
                                 xlim = NULL,
                                 ylim = NULL,
                                 ...) {
  if (!is.exdqlmSynthesis(x)) {
    stop("x must be an exdqlmSynthesis object")
  }

  TT <- nrow(as.matrix(x$draws))
  if (is.null(time)) {
    time <- seq_len(TT)
  } else if (length(time) != TT) {
    stop("time must have length equal to the number of synthesized time points")
  }

  interval <- as.numeric(interval)[1]
  if (!is.finite(interval) || !interval %in% c(0.50, 0.95)) {
    stop("interval must be either 0.50 or 0.95")
  }

  if (identical(interval, 0.50)) {
    lower <- as.numeric(x$summary$q250)
    upper <- as.numeric(x$summary$q750)
  } else {
    lower <- as.numeric(x$summary$q025)
    upper <- as.numeric(x$summary$q975)
  }
  median <- as.numeric(x$summary$q500)
  mean <- as.numeric(x$summary$mean)

  y_xy <- NULL
  if (!is.null(y)) {
    y_xy <- grDevices::xy.coords(y)
  }

  if (is.null(xlim)) {
    xlim <- range(time, if (!is.null(y_xy)) y_xy$x else time, finite = TRUE)
  }
  if (is.null(ylim)) {
    ylim <- range(lower, upper,
                  if (show.median) median else NULL,
                  if (show.mean) mean else NULL,
                  if (!is.null(y_xy)) y_xy$y else NULL,
                  finite = TRUE)
  }

  if (!isTRUE(add)) {
    graphics::plot(
      time, median,
      type = "n",
      xlim = xlim,
      ylim = ylim,
      xlab = xlab,
      ylab = ylab,
      main = main,
      ...
    )
  }

  graphics::polygon(c(time, rev(time)), c(lower, rev(upper)),
                    col = band.col, border = border)
  if (!is.null(y_xy)) {
    graphics::lines(y_xy$x, y_xy$y, col = y.col)
  }
  if (isTRUE(show.mean)) {
    graphics::lines(time, mean, col = mean.col, lwd = 1.25)
  }
  if (isTRUE(show.median)) {
    graphics::lines(time, median, col = median.col, lwd = 1.25)
  }

  invisible(x)
}

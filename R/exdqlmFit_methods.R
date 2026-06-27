.exdqlm_fit_class <- function(primary) {
  c(primary, "exdqlmFit")
}

.exdqlm_format_number <- function(x, digits = 4) {
  x <- suppressWarnings(as.numeric(x)[1L])
  if (!is.finite(x)) return("NA")
  format(signif(x, digits = digits), trim = TRUE)
}

.exdqlm_runtime_label <- function(x) {
  x <- suppressWarnings(as.numeric(x)[1L])
  if (!is.finite(x)) return("NA")
  paste0(format(round(x, 3), trim = TRUE), " seconds")
}

.exdqlm_model_family <- function(x) {
  if (isTRUE(x$dqlm.ind)) "DQLM (AL special case)" else "exDQLM (exAL)"
}

.exdqlm_dynamic_engine <- function(x) {
  if (is.exdqlmMCMC(x)) return("MCMC")
  if (is.exdqlmLDVB(x)) return("LDVB")
  if (is.exdqlmISVB(x)) return("legacy ISVB")
  "unknown"
}

.exdqlm_discount_label <- function(df, dim.df) {
  if (is.null(df)) return("not stored")
  if (is.null(dim.df)) return(paste(df, collapse = ", "))
  paste(df, "(", dim.df, ")", collapse = ", ")
}

.exdqlm_draw_dim <- function(x) {
  if (is.null(x)) return("not stored")
  .exdqlm_dim_label(as.matrix(x))
}

.exdqlm_array_dim <- function(x) {
  if (is.null(x)) return("not stored")
  .exdqlm_dim_label(x)
}

.exdqlm_safe_p0 <- function(x) {
  if (!is.null(x$p0)) return(as.numeric(x$p0)[1L])
  if (!is.null(x$misc$p0)) return(as.numeric(x$misc$p0)[1L])
  if (!is.null(x$m1$p0)) return(as.numeric(x$m1$p0)[1L])
  NA_real_
}

.exdqlm_scalar_summary <- function(x) {
  out <- list()
  if (!is.null(x$samp.sigma)) {
    sig <- as.numeric(x$samp.sigma)
    sig <- sig[is.finite(sig)]
    if (length(sig)) {
      out[["sigma"]] <- c(mean = mean(sig), sd = stats::sd(sig))
    }
  } else if (!is.null(x$qsig$E_sigma)) {
    out[["sigma"]] <- c(mean = as.numeric(x$qsig$E_sigma)[1L], sd = NA_real_)
  } else if (!is.null(x$qsiggam$sigma_mean)) {
    out[["sigma"]] <- c(mean = as.numeric(x$qsiggam$sigma_mean)[1L], sd = NA_real_)
  }
  if (!is.null(x$samp.gamma)) {
    gam <- as.numeric(x$samp.gamma)
    gam <- gam[is.finite(gam)]
    if (length(gam)) {
      out[["gamma"]] <- c(mean = mean(gam), sd = stats::sd(gam))
    }
  } else if (!isTRUE(x$dqlm.ind) && !is.null(x$qsiggam$gamma_mean)) {
    out[["gamma"]] <- c(mean = as.numeric(x$qsiggam$gamma_mean)[1L], sd = NA_real_)
  }
  if (!length(out)) {
    return(data.frame(Parameter = character(), Mean = numeric(), SD = numeric()))
  }
  data.frame(
    Parameter = names(out),
    Mean = vapply(out, function(z) z[["mean"]], numeric(1)),
    SD = vapply(out, function(z) z[["sd"]], numeric(1)),
    row.names = NULL,
    check.names = FALSE
  )
}

.exdqlm_fit_print <- function(x) {
  conv <- .exdqlm_convergence_info(x)
  cat("Dynamic quantile state-space fit\n")
  cat("Class:", paste(class(x), collapse = ", "), "\n")
  cat("Model:", .exdqlm_model_family(x), "\n")
  cat("Inference engine:", .exdqlm_dynamic_engine(x), "\n")
  cat("Quantile level (p0):", .exdqlm_format_number(.exdqlm_safe_p0(x)), "\n")
  cat("Observations:", length(x$y), "\n")
  cat("State dimension:", length(x$model$m0), "\n")
  cat("Discount factors (dimensions):", .exdqlm_discount_label(x$df, x$dim.df), "\n")
  if (is.exdqlmMCMC(x)) {
    cat("Burn-in:", x$n.burn, "\n")
    cat("Posterior draws:", x$n.mcmc, "\n")
  } else {
    cat("Converged:", if (is.na(conv$converged)) "NA" else .exdqlm_yes_no(conv$converged), "\n")
    cat("Iterations:", if (is.null(conv$iter)) "NA" else conv$iter, "\n")
  }
  cat("State draws:", .exdqlm_array_dim(x$samp.theta), "\n")
  cat("Posterior predictive draws:", .exdqlm_draw_dim(x$samp.post.pred), "\n")
  cat("Run-time:", .exdqlm_runtime_label(x$run.time), "\n")
  cat("Use with: summary(), plot(), predict(), diagnostics()\n")
  cat("Plot types: quantile, component, state\n")
  invisible(x)
}

.exdqlm_fit_summary <- function(x) {
  draw_info <- data.frame(
    Quantity = c("state draws", "posterior predictive draws", "sigma draws", "gamma draws"),
    Dimension = c(
      .exdqlm_array_dim(x$samp.theta),
      .exdqlm_draw_dim(x$samp.post.pred),
      .exdqlm_draw_dim(x$samp.sigma),
      if (is.null(x$samp.gamma)) "not stored" else .exdqlm_draw_dim(x$samp.gamma)
    ),
    check.names = FALSE
  )
  conv <- .exdqlm_convergence_info(x)
  conv_info <- data.frame(
    Quantity = c("converged", "stop reason", "iterations"),
    Value = c(
      if (is.na(conv$converged)) "NA" else .exdqlm_yes_no(conv$converged),
      if (is.null(conv$stop_reason) || is.na(conv$stop_reason)) "not stored" else as.character(conv$stop_reason),
      if (is.null(conv$iter)) "NA" else as.character(conv$iter)
    ),
    check.names = FALSE
  )
  scalar_info <- .exdqlm_scalar_summary(x)
  
  .exdqlm_fit_print(x)
  cat("\nStored draws:\n")
  print(draw_info, row.names = FALSE)
  if (nrow(scalar_info)) {
    cat("\nScalar posterior summaries:\n")
    print(scalar_info, row.names = FALSE, digits = 4)
  }
  if (!is.exdqlmMCMC(x)) {
    cat("\nConvergence summary:\n")
    print(conv_info, row.names = FALSE)
  }
  
  invisible(list(draws = draw_info, scalar = scalar_info, convergence = conv_info))
}

.plot_exdqlm_fit <- function(x, type = c("quantile", "component", "state"),
                             index = NULL, ...) {
  type <- match.arg(type)
  if (identical(type, "quantile")) {
    return(exdqlmPlot(x, ...))
  }
  if (is.null(index)) {
    stop("index is required when type is 'component' or 'state'.", call. = FALSE)
  }
  dots <- list(...)
  if ("just.theta" %in% names(dots)) {
    stop("use type = 'state' instead of passing just.theta to plot().", call. = FALSE)
  }
  dots$m1 <- x
  dots$index <- index
  dots$just.theta <- identical(type, "state")
  do.call(compPlot, dots)
}


##################################
###### "exdqlmFit" objects #######
##################################
# included: is(), print(), summary(), 
#     plot() -- exdqlmPlot(), compPlot(),
#     predict() -- exdqlmForecast(),
#     diagnostic() -- exdqlmDiagnostics()

#' \code{exdqlmFit} objects
#'
#' \code{is.exdqlmFit} tests if its argument is a fitted dynamic
#' \code{exdqlm} object, including MCMC, LDVB, and legacy ISVB fits.
#'
#' @usage is.exdqlmFit(m)
#'
#' @param m an \strong{R} object
#'
#' @export
is.exdqlmFit <- function(m){ return(methods::is(m, "exdqlmFit")) }

#' Print Method for \code{exdqlmFit} Objects
#'
#' @param x A fitted dynamic \code{exdqlmFit} object.
#' @param ... Additional arguments (unused).
#'
#' @export
print.exdqlmFit <- function(x, ...) {
  .exdqlm_fit_print(x)
}

#' Summary Method for \code{exdqlmFit} Objects
#'
#' @param object A fitted dynamic \code{exdqlmFit} object.
#' @param ... Additional arguments (unused).
#'
#' @return Invisibly returns a list with data frames describing stored draws,
#'   scalar posterior summaries, and convergence information.
#'
#' @description
#' Prints a compact summary of a fitted dynamic quantile state-space model and
#' returns the displayed summary tables for programmatic inspection.
#'
#' @export
summary.exdqlmFit <- function(object, ...) {
  .exdqlm_fit_summary(object)
}

#' Plot Method for Dynamic \code{exdqlmFit} Objects
#'
#' Plot fitted dynamic quantiles, fitted component contributions, or individual
#' state elements from a dynamic fit. The default \code{type = "quantile"}
#' delegates to \code{\link{exdqlmPlot}}. Component and state views delegate to
#' \code{\link{compPlot}}.
#'
#' @param x A fitted dynamic \code{exdqlmFit} object.
#' @param type Character string specifying the plot type. Use
#'   \code{"quantile"} for the fitted dynamic quantile, \code{"component"} for
#'   the contribution of a block of state elements, or \code{"state"} for a
#'   single state element.
#' @param index Required for \code{type = "component"} or \code{type = "state"}.
#'   For \code{type = "state"}, \code{index} much have length 1 indicating a 
#'   single element of the state vector to be plot. For \code{type = "component"},
#'   \code{index} should be consecutive state indices in \eqn{\{1,\dots,q\}} 
#'   indicating the component to be plot. 
#' @param cr.percent Optional numeric in \code{(0, 1)} indicating the 
#'  probability mass for the credible intervals (e.g., \code{0.95}). Default \code{0.95}.
#' @param add Optional logical value indicating whether the estimate will be 
#'  added to existing plot. Default is \code{FALSE}.
#' @param col Optional character vector of length 1 giving color of the 
#'  estimate to be plotted. Default is `purple`.
#' @param xlim,ylim Optional limits passed to the base plotting call.
#' @param xlab,ylab Optional axis labels passed to the base plotting call.
#' @param lwd,lwd.interval Line widths for the estimate and credible interval
#'   bounds, respectively.
#' @param lty.interval Line type for the credible interval bounds.
#' @param ... Additional arguments.
#'
#' @return Invisibly returns a list of the following:
#'  \itemize{
#'   \item `map.quant` - MAP estimate of the dynamic estimate.
#'   \item `lb.quant` - Lower bound of the 95% CrIs of the dynamic estimate.
#'   \item `ub.quant` - Upper bound of the 95% CrIs of the dynamic estimate.
#'   \item `x` - Time/index values used for plotting.
#' }
#'
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
#' # plot quantile
#' plot(M0)
#' # plot first harmonic component
#' plot(M0, type="component", index = c(3, 4), col = "blue")
#' options(old)
#' }
plot.exdqlmFit <- function(x, type = c("quantile", "component", "state"), index = NULL, 
                           add = FALSE, col = "purple", cr.percent = 0.95,
                           xlim = NULL, ylim = NULL, xlab = "time",
                           ylab = NULL, lwd = 1.5, lwd.interval = 0.75,
                           lty.interval = 2, ...) {
  .plot_exdqlm_fit(x, type = type, index = index, 
                   add = add, col = col, cr.percent = cr.percent,
                   xlim = xlim, ylim = ylim, xlab = xlab,
                   ylab = ylab, lwd = lwd, lwd.interval = lwd.interval,
                   lty.interval = lty.interval, ...)
}

#' Forecast Method for Dynamic \code{exdqlmFit} Objects
#'
#' Forecast from a fitted dynamic quantile model. This is an S3 method wrapper
#' around \code{\link{exdqlmForecast}}; use \code{plot()} on the returned
#' \code{exdqlmForecast} object to visualize the result.
#'
#' @param object A fitted dynamic \code{exdqlmFit} object.
#' @param start.t Integer index at which forecasts start.
#' @param k Integer number of steps ahead to forecast.
#' @param fFF Optional future observation vector(s), passed to
#'   \code{\link{exdqlmForecast}}.
#' @param fGG Optional future evolution matrix/matrices, passed to
#'   \code{\link{exdqlmForecast}}.
#' @param plot Logical; if \code{TRUE}, immediately plot the returned forecast
#'   object as a convenience shortcut. Default is \code{FALSE}.
#' @param ... Additional arguments passed to \code{\link{exdqlmForecast}}.
#'
#' @return An object of class \code{exdqlmForecast}.
#'
#' @export
predict.exdqlmFit <- function(object, start.t, k, fFF = NULL, fGG = NULL,
                              plot = FALSE, ...) {
  exdqlmForecast(
    start.t = start.t, k = k, m1 = object,
    fFF = fFF, fGG = fGG, plot = plot, ...
  )
}

#' Diagnostics Method for Dynamic \code{exdqlmFit} Objects
#'
#' Diagnostics for a fitted dynamic quantile model. This is an S3 method wrapper
#' around \code{\link{exdqlmDiagnostics}}; use \code{plot()} on the returned
#' \code{exdqlmDiagnostic} object to visualize the result.
#'
#' @param object A fitted dynamic \code{exdqlmFit} object.
#' @param ... Additional arguments passed to \code{\link{exdqlmDiagnostics}}.
#'
#' @return An object of class \code{exdqlmDiagnostic}.
#'
#' @export
diagnostics.exdqlmFit <- function(object, ...) {
  
  exdqlmDiagnostics(object, ...)
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
  print.exdqlmFit(x, ...)
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
  summary.exdqlmFit(object, ...)
}

#' Plot Method for \code{exdqlmMCMC} Objects
#'
#' @param x An \code{exdqlmMCMC} object.
#' @param type Character string specifying \code{"quantile"}, \code{"component"},
#'   or \code{"state"}.
#' @param index Required for \code{type = "component"} or \code{type = "state"}.
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
plot.exdqlmMCMC<- function(x, type = c("quantile", "component", "state"),
                           index = NULL, ...) {
  plot.exdqlmFit(x, type = type, index = index, ...)
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
  print.exdqlmFit(x, ...)
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
  summary.exdqlmFit(object, ...)
}

#' Plot Method for \code{exdqlmISVB} Objects
#'
#' @param x An \code{exdqlmISVB} object.
#' @param type Character string specifying \code{"quantile"}, \code{"component"},
#'   or \code{"state"}.
#' @param index Required for \code{type = "component"} or \code{type = "state"}.
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
plot.exdqlmISVB <- function(x, type = c("quantile", "component", "state"),
                            index = NULL, ...) {
  plot.exdqlmFit(x, type = type, index = index, ...)
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
  print.exdqlmFit(x, ...)
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
  summary.exdqlmFit(object, ...)
}

#' Plot Method for \code{exdqlmLDVB} Objects
#'
#' @param x An \code{exdqlmLDVB} object.
#' @param type Character string specifying \code{"quantile"}, \code{"component"},
#'   or \code{"state"}.
#' @param index Required for \code{type = "component"} or \code{type = "state"}.
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
plot.exdqlmLDVB <- function(x, type = c("quantile", "component", "state"),
                            index = NULL, ...) {
  plot.exdqlmFit(x, type = type, index = index, ...)
}
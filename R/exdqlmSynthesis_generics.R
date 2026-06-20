####################################
##### "exdqlmSynthesis" objects ####
####################################
# included: is(), print(), summary(), plot()

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
  cat("Class:", paste(class(x), collapse = ", "), "\n")
  cat("Time points:", nrow(as.matrix(x$draws)), "\n")
  cat("Synthesized draws per time:", ncol(as.matrix(x$draws)), "\n")
  cat("Number of input quantile levels:", length(x$levels), "\n")
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

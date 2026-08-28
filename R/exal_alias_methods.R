# Compatibility methods for the validation-facing exAL aliases.

#' Test for an `exal_mcmc` object
#'
#' @param m An R object.
#' @export
is.exal_mcmc <- function(m) {
  methods::is(m, "exal_mcmc")
}

#' Print an `exal_mcmc` object
#'
#' @param x An `exal_mcmc` object.
#' @param ... Additional arguments.
#' @export
print.exal_mcmc <- function(x, ...) {
  print.exalStaticMCMC(x, ...)
}

#' Summarize an `exal_mcmc` object
#'
#' @param object An `exal_mcmc` object.
#' @param ... Additional arguments.
#' @export
summary.exal_mcmc <- function(object, ...) {
  summary.exalStaticMCMC(object, ...)
}

#' Plot an `exal_mcmc` object
#'
#' @param x An `exal_mcmc` object.
#' @param add Logical; add to an existing plot.
#' @param col Color for fitted quantiles.
#' @param cr.percent Credible-interval mass.
#' @param ... Additional plotting arguments.
#' @return The static exAL MCMC plot result.
#' @export
plot.exal_mcmc <- function(x, add = FALSE, col = "purple", cr.percent = 0.95, ...) {
  plot.exalStaticMCMC(x, add = add, col = col, cr.percent = cr.percent, ...)
}

#' Test for an `exal_ldvb` object
#'
#' @param m An R object.
#' @export
is.exal_ldvb <- function(m) {
  methods::is(m, "exal_ldvb")
}

#' Print an `exal_ldvb` object
#'
#' @param x An `exal_ldvb` object.
#' @param ... Additional arguments.
#' @export
print.exal_ldvb <- function(x, ...) {
  print.exalStaticLDVB(x, ...)
}

#' Summarize an `exal_ldvb` object
#'
#' @param object An `exal_ldvb` object.
#' @param ... Additional arguments.
#' @export
summary.exal_ldvb <- function(object, ...) {
  summary.exalStaticLDVB(object, ...)
}

#' Plot an `exal_ldvb` object
#'
#' @param x An `exal_ldvb` object.
#' @param X Optional design matrix.
#' @param add Logical; add to an existing plot.
#' @param col Color for fitted quantiles.
#' @param cr.percent Credible-interval mass.
#' @param ... Additional plotting arguments.
#' @return The static exAL LDVB plot result.
#' @export
plot.exal_ldvb <- function(x, X = NULL, add = FALSE, col = "purple", cr.percent = 0.95, ...) {
  plot.exalStaticLDVB(x, X = X, add = add, col = col, cr.percent = cr.percent, ...)
}

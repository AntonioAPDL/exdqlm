#' Diagnostics Generic
#'
#' Compute diagnostic summaries for fitted and post-processing objects.
#'
#' \code{diagnostics()} is the standard diagnostic entry point for the main
#' fitted-object families in \pkg{exdqlm}. Methods are currently provided for
#' dynamic fitted models, dynamic forecast objects, and static AL/exAL fitted
#' models. The returned objects can be inspected with \code{print()} or
#' \code{summary()}, and plotted with \code{plot()} when a diagnostic display is
#' defined.
#'
#' @param object An object of class \code{exdqlmFit}, \code{exdqlmForecast}, or
#' \code{exalStaticFit}.
#' @param ... Additional arguments passed to specific methods.
#'
#' @return The output depends on the method: \code{diagnostics.exdqlmFit()}
#'   returns an \code{exdqlmDiagnostic} object,
#'   \code{diagnostics.exdqlmForecast()} returns an
#'   \code{exdqlmForecastDiagnostic} object, and
#'   \code{diagnostics.exalStaticFit()} returns an
#'   \code{exalStaticDiagnostic} object.
#' @export
diagnostics <- function(object, ...) { UseMethod("diagnostics") }

.exdqlm_validate_plot_flag <- function(plot) {
  if (!is.logical(plot) || length(plot) != 1L || is.na(plot)) {
    stop("plot must be TRUE or FALSE.", call. = FALSE)
  }
  plot
}

.exdqlm_convergence_info <- function(x) {
  conv <- x$diagnostics$convergence
  if (is.null(conv)) {
    return(list(converged = NA, stop_reason = NA_character_, iter = x$iter))
  }
  list(
    converged = conv$converged,
    stop_reason = conv$stop_reason,
    iter = conv$iter
  )
}

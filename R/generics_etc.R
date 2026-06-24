#' Diagnostics Generic
#'
#' Calculates diagnostic metrics for a variety of objects.
#'
#' @param object An object of class \code{exdqlmFit}, \code{exdqlmForecast}, or 
#' \code{exalStaticFit}.
#' @param ... Additional arguments passed to specific methods.
#'
#' @return The output depends on the underlying method.
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

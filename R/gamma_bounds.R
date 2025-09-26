#' Bounds for the exAL shape parameter gamma
#'
#' Returns valid lower/upper bounds \code{(L, U)} for the shape parameter \code{gamma}
#' of the standardized extended Asymmetric Laplace (exAL), given \code{p0} in (0,1).
#'
#' This is a user-facing convenience wrapper around the C++ routine
#' \code{get_gamma_bounds_cpp()}, which performs the actual computation.
#'
#' @param p0 Numeric scalar in (0, 1); typically the target quantile level.
#' @return A numeric vector of length 2 named \code{c("L","U")}.
#' @examples
#' get_gamma_bounds(0.5)
#' get_gamma_bounds(0.9)
#' @export
get_gamma_bounds <- function(p0) {
  stopifnot(is.numeric(p0), length(p0) == 1L, is.finite(p0), p0 > 0, p0 < 1)
  out <- get_gamma_bounds_cpp(p0)
  # ensure names for clarity
  if (length(out) == 2L && is.null(names(out))) names(out) <- c("L","U")
  out
}

# R/regMod.R

#' Create a standard regression component for an exDQLM
#'
#' The function constructs a regression block where the observation vector at time \eqn{t} is
#' \eqn{F_t = X_t} (row of the design matrix), and the state evolves as
#' \eqn{\theta_t = \theta_{t-1}} (i.e., \eqn{G_t = I_n}).
#'
#' Input \code{X} is a \eqn{T \times n} matrix of regressors; the returned \code{FF} is an \eqn{n \times T}
#' matrix (i.e., \code{t(X)}), consistent with component composition via
#' \code{+.exdqlm}.
#'
#' @param X A numeric matrix of dimension \eqn{T \times n} (T time points, n regressors).
#'          Vectors are accepted and treated as \eqn{T \times 1}.
#' @param m0 Optional numeric prior mean (length n). Defaults to zeros.
#' @param C0 Optional numeric prior covariance (\eqn{n \times n}). Defaults to \eqn{10^3 I_n}.
#'
#' @return An object of class \code{"exdqlm"} with elements:
#' \itemize{
#'   \item \code{FF} - \eqn{n \times T} matrix with column \eqn{t} equal to \eqn{F_t = X_t}.
#'   \item \code{GG} - \eqn{n \times n} identity matrix (static coefficients).
#'   \item \code{m0}, \code{C0} - Prior mean/covariance for regression coefficients.
#' }
#' @export
#'
#' @examples
#' data("climateIndices", package = "exdqlm")
#'
#' T <- 150
#' bt_dates <- seq(as.Date("1987-01-01"), by = "month", length.out = T)
#' idx <- match(bt_dates, climateIndices$date)
#' X <- scale(climateIndices[idx, c("noi", "amo")])
#'
#' # Single regressor (T x 1)
#' reg1 = regMod(X[, "noi"])
#' # Multiple regressors (T x n)
#' reg2 = regMod(X)
#'
#' # Combine with trend/seasonal components
#' trend.comp = polytrendMod(order = 3, m0 = rep(0,3), C0 = diag(3))
#' seas.comp  = seasMod(p = 12, h = 1, C0 = diag(1, 2))
#' base.mod   = trend.comp + seas.comp
#' model.std  = base.mod + reg2
regMod <- function(X, m0, C0) {
  X <- as.matrix(X)
  if (!is.numeric(X)) stop("X must be numeric.")
  if (any(!is.finite(X))) stop("X contains non-finite values.")
  Tlen <- nrow(X); n <- ncol(X)
  if (is.null(Tlen) || is.null(n) || Tlen < 1L || n < 1L)
    stop("X must have dimensions T x n with T>=1 and n>=1.")

  FF <- t(X)                 # n x T  (each column is F_t)
  GG <- diag(n)              # static coefficients

  if (missing(m0)) m0 <- matrix(0, n, 1) else {
    if (length(m0) != n) stop("length(m0) must be ncol(X).")
  }
  if (missing(C0)) {
    C0 <- diag(1e3, n)
  } else {
    C0 <- as.matrix(C0)
    if (!all(dim(C0) == c(n, n))) stop("C0 must be an n x n matrix.")
  }

  mod <- list(FF = FF, GG = GG, m0 = m0, C0 = C0)
  class(mod) <- "exdqlm"
  mod
}

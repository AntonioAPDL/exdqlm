# R/regMod.R

#' Create a standard regression component for an exDQLM
#'
#' Constructs a regression block where the observation vector at time t is
#' \eqn{F_t = X_t} (row of the design matrix), and the state evolves as
#' \eqn{\theta_t = \theta_{t-1}} (i.e., \eqn{G_t = I_n}).
#'
#' Input X is a T x n matrix of regressors; the returned \code{FF} is an n x T
#' matrix (i.e., \code{t(X)}), consistent with \code{combineMods()} semantics.
#'
#' @param X A numeric matrix of dimension T x n (T time points, n regressors).
#'          Vectors are accepted and treated as T x 1.
#' @param m0 Optional numeric prior mean (length n). Defaults to zeros.
#' @param C0 Optional numeric prior covariance (n x n). Defaults to \eqn{10^3 I_n}.
#'
#' @return An object of class \code{"exdqlm"} with elements:
#' \itemize{
#'   \item \code{FF} — n x T matrix with column \eqn{t} equal to \eqn{F_t = X_t}.
#'   \item \code{GG} — n x n identity (static coefficients).
#'   \item \code{m0}, \code{C0} — prior mean/covariance for regression coefficients.
#' }
#' @export
#'
#' @examples
#' data("BTflow", package = "exdqlm")
#' data("nino34", package = "exdqlm")
#' # Single regressor (T x 1)
#' reg1 <- regMod(nino34)
#' # Multiple regressors (T x n)
#' X <- cbind(nino34, scale(BTflow)[,1])
#' reg2 <- regMod(X)
#'
#' # Combine with trend/seasonal components
#' trend.comp <- polytrendMod(order = 3, m0 = rep(0,3), C0 = diag(3))
#' seas.comp  <- seasMod(p = 12, h = 1, C0 = diag(1, 2))
#' base.mod   <- combineMods(trend.comp, seas.comp)
#' model.std  <- combineMods(base.mod, reg2)
regMod <- function(X, m0, C0) {
  X <- as.matrix(X)
  if (!is.numeric(X)) stop("X must be numeric.")
  if (any(!is.finite(X))) stop("X contains non-finite values.")
  Tlen <- nrow(X); n <- ncol(X)
  if (is.null(Tlen) || is.null(n) || Tlen < 1L || n < 1L)
    stop("X must have dimensions T x n with T>=1 and n>=1.")

  FF <- t(X)                 # n x T  (each column is F_t)
  GG <- diag(n)              # static coefficients

  if (missing(m0)) m0 <- rep(0, n) else {
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

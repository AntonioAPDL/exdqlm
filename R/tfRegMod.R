# R/tfRegMod.R

#' Create a transfer-function regression component for an exDQLM
#'
#' Builds a block with state dimension \eqn{n+1} (first element is the
#' transfer/accumulator; the remaining n are regression coefficients).
#' The observation vector is \eqn{F_t = e_1} (canonical basis vector),
#' and the evolution is time-varying:
#'
#' \deqn{
#'   G_t =
#'   \begin{bmatrix}
#'     \lambda_t & X_t^\top \\
#'     0_{n\times 1} & I_n
#'   \end{bmatrix},
#' }
#'
#' where \eqn{X_t} is the 1 x n row of the T x n regressor matrix at time t,
#' and \eqn{\lambda_t} is either a scalar \eqn{\lambda} (recycled) or a T-vector.
#'
#' @param X A numeric matrix of dimension T x n (T time points, n regressors).
#' @param lambda Numeric scalar or length-T vector. If scalar, it is recycled across t.
#' @param m0 Optional prior mean (length n+1). Defaults to zeros.
#' @param C0 Optional prior covariance ((n+1) x (n+1)). Defaults to \eqn{10^3 I_{n+1}}.
#'
#' @return An object of class \code{"exdqlm"} with:
#' \itemize{
#'   \item \code{FF} — (n+1) x T matrix with first row all ones and others zero (i.e., \eqn{F_t=e_1}).
#'   \item \code{GG} — (n+1) x (n+1) x T array with the block form shown above.
#'   \item \code{m0}, \code{C0} — prior mean/covariance for the augmented state.
#' }
#' @details
#' Ensure other components you combine with have compatible time length T.
#' \code{combineMods()} will broadcast constant \code{GG} blocks across T slices
#' and recycle constant \code{FF} columns as needed.
#' @export
#'
#' @examples
#' data("BTflow", package = "exdqlm")
#' data("nino34", package = "exdqlm")
#' X <- cbind(nino34, scale(BTflow)[,1])  # T x n
#' tfc <- tfRegMod(X, lambda = 0.9)
#'
#' trend.comp <- polytrendMod(order = 3, m0 = rep(0,3), C0 = diag(3))
#' model.tf   <- combineMods(trend.comp, tfc)
tfRegMod <- function(X, lambda, m0, C0) {
  X <- as.matrix(X)
  if (!is.numeric(X)) stop("X must be numeric.")
  if (any(!is.finite(X))) stop("X contains non-finite values.")
  Tlen <- nrow(X); n <- ncol(X)
  if (is.null(Tlen) || is.null(n) || Tlen < 1L || n < 1L)
    stop("X must have dimensions T x n with T>=1 and n>=1.")

  if (missing(lambda)) stop("lambda must be provided (scalar or length T).")
  lam <- as.numeric(lambda)
  if (length(lam) == 1L) lam <- rep(lam, Tlen)
  if (length(lam) != Tlen) stop("lambda must be scalar or length T (nrow(X)).")
  if (any(!is.finite(lam))) stop("lambda contains non-finite values.")

  # FF: (n+1) x T with e1 in every column
  FF <- rbind(rep(1, Tlen), matrix(0, nrow = n, ncol = Tlen))

  # GG: (n+1) x (n+1) x T
  GG <- array(0, dim = c(n + 1L, n + 1L, Tlen))
  idx <- 2:(n + 1L)
  for (t in seq_len(Tlen)) {
    Gt <- matrix(0, n + 1L, n + 1L)
    Gt[1, 1] <- lam[t]
    Gt[1, idx] <- X[t, ]            # 1 x n
    Gt[idx, idx] <- diag(n)         # I_n
    GG[, , t] <- Gt
  }

  if (missing(m0)) m0 <- rep(0, n + 1L) else {
    if (length(m0) != (n + 1L)) stop("length(m0) must be ncol(X)+1.")
  }
  if (missing(C0)) {
    C0 <- diag(1e3, n + 1L)
  } else {
    C0 <- as.matrix(C0)
    if (!all(dim(C0) == c(n + 1L, n + 1L))) stop("C0 must be (n+1) x (n+1).")
  }

  mod <- list(FF = FF, GG = GG, m0 = m0, C0 = C0)
  class(mod) <- "exdqlm"
  mod
}

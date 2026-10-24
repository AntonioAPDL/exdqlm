#' Frozen full-support joint proposal for augmented RHS
#' @param center Matrix of architecture-specific centers. Columns are log variance,
#'   log global scale(s), and log slab variance.
#' @param scale Positive-definite common Student-t scale matrix.
#' @param df Student-t degrees of freedom.
#' @param wide_weight Weight of a broad common component, strictly between zero and one.
#' @param wide_center,wide_scale Center and scale of the common component.
#' @return A proposal distribution, never a prior. Freeze before production sampling.
#' @export
autodesn_extended_proposal <- function(center, scale, df = 5, wide_weight = .2, wide_center = colMeans(center), wide_scale = 9 * scale) {
  if (!is.matrix(center) || !is.numeric(center) || nrow(center) < 1 || ncol(center) < 3 || any(!is.finite(center))) stop("center must be a finite M by D matrix, D>=3.", call. = FALSE)
  D <- ncol(center)
  .autodesn_positive(df, "df")
  if (length(wide_weight) != 1 || !is.finite(wide_weight) || wide_weight <= 0 || wide_weight >= 1) stop("wide_weight must be inside (0,1).", call. = FALSE)
  check <- function(x) {
    if (!is.matrix(x) || !identical(dim(x), c(D, D)) || any(!is.finite(x)) || max(abs(x - t(x))) > 1e-10) stop("Proposal scale must be finite symmetric D by D.", call. = FALSE)
    chol(x)
  }

  if (length(wide_center) != D || any(!is.finite(wide_center))) stop("wide_center has inconsistent dimensions.", call. = FALSE)
  list(center = center, scale = scale, df = df, wide_weight = wide_weight, wide_center = wide_center, wide_scale = wide_scale, chol = check(scale), wide_chol = check(wide_scale))
}

.ext_joint_draw <- function(m, proposal) {
  wide <- stats::runif(1) < proposal$wide_weight
  center <- if (wide) proposal$wide_center else proposal$center[m, ]
  R <- if (wide) proposal$wide_chol else proposal$chol
  as.vector(center + t(R) %*% stats::rnorm(length(center)) / sqrt(stats::rchisq(1, proposal$df) / proposal$df))
}

.ext_joint_logq <- function(z, m, proposal) {
  D <- length(z)
  df <- proposal$df
  density <- function(center, R) {
    a <- forwardsolve(t(R), z - center)
    lgamma((df + D) / 2) - lgamma(df / 2) - D / 2 * log(df * pi) - sum(log(diag(R))) - (df + D) / 2 * log1p(sum(a * a) / df)
  }

  .autodesn_rhs_logadd(log1p( - proposal$wide_weight) + density(proposal$center[m, ], proposal$chol), log(proposal$wide_weight) + density(proposal$wide_center, proposal$wide_chol))
}

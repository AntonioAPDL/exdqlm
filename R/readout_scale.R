readout_scale_fit <- function(X, has_intercept = FALSE, center = TRUE, scale = TRUE,
                              eps = 1e-12) {
  stopifnot(is.matrix(X))
  p <- ncol(X)

  idx <- if (isTRUE(has_intercept) && p >= 2L) 2L:p else seq_len(p)
  if (!length(idx)) {
    scale_info <- list(
      center = numeric(0),
      scale = numeric(0),
      idx = integer(0),
      has_intercept = isTRUE(has_intercept),
      scaled = FALSE,
      center_applied = FALSE,
      scale_applied = FALSE,
      colnames = colnames(X)
    )
    return(list(X = X, scale_info = scale_info))
  }

  X_sub <- X[, idx, drop = FALSE]
  mu <- if (isTRUE(center)) colMeans(X_sub, na.rm = TRUE) else rep(0, ncol(X_sub))
  sd <- if (isTRUE(scale)) apply(X_sub, 2L, stats::sd, na.rm = TRUE) else rep(1, ncol(X_sub))
  sd[!is.finite(sd) | sd < eps] <- 1

  X_scaled <- X
  if (isTRUE(center)) X_scaled[, idx] <- sweep(X_scaled[, idx, drop = FALSE], 2L, mu, "-")
  if (isTRUE(scale))  X_scaled[, idx] <- sweep(X_scaled[, idx, drop = FALSE], 2L, sd, "/")

  scale_info <- list(
    center = as.numeric(mu),
    scale = as.numeric(sd),
    idx = as.integer(idx),
    has_intercept = isTRUE(has_intercept),
    scaled = TRUE,
    center_applied = isTRUE(center),
    scale_applied = isTRUE(scale),
    colnames = colnames(X)
  )

  list(X = X_scaled, scale_info = scale_info)
}

readout_scale_apply <- function(X, scale_info) {
  stopifnot(is.matrix(X))
  if (is.null(scale_info) || !isTRUE(scale_info$scaled)) return(X)

  idx <- if (!is.null(scale_info$idx)) as.integer(scale_info$idx) else integer(0)
  if (!length(idx)) return(X)

  mu <- if (!is.null(scale_info$center)) as.numeric(scale_info$center) else rep(0, length(idx))
  sd <- if (!is.null(scale_info$scale)) as.numeric(scale_info$scale) else rep(1, length(idx))

  X_scaled <- X
  if (isTRUE(scale_info$center_applied)) {
    X_scaled[, idx] <- sweep(X_scaled[, idx, drop = FALSE], 2L, mu, "-")
  }
  if (isTRUE(scale_info$scale_applied)) {
    X_scaled[, idx] <- sweep(X_scaled[, idx, drop = FALSE], 2L, sd, "/")
  }
  X_scaled
}

readout_unscale_beta <- function(beta, scale_info) {
  if (is.null(scale_info) || !isTRUE(scale_info$scaled)) return(beta)

  idx <- if (!is.null(scale_info$idx)) as.integer(scale_info$idx) else integer(0)
  if (!length(idx)) return(beta)

  mu <- if (!is.null(scale_info$center)) as.numeric(scale_info$center) else rep(0, length(idx))
  sd <- if (!is.null(scale_info$scale)) as.numeric(scale_info$scale) else rep(1, length(idx))
  has_intercept <- isTRUE(scale_info$has_intercept)

  if (is.matrix(beta)) {
    p <- ncol(beta)
    if (max(idx) > p) stop("readout_unscale_beta(): idx exceeds beta columns.")
    b <- beta
    b[, idx] <- sweep(b[, idx, drop = FALSE], 2L, sd, "/")
    if (has_intercept && isTRUE(scale_info$center_applied)) {
      adj <- as.numeric(b[, idx, drop = FALSE] %*% mu)
      b[, 1L] <- beta[, 1L] - adj
    }
    return(b)
  }

  if (is.vector(beta)) {
    p <- length(beta)
    if (max(idx) > p) stop("readout_unscale_beta(): idx exceeds beta length.")
    b <- beta
    b[idx] <- b[idx] / sd
    if (has_intercept && isTRUE(scale_info$center_applied)) {
      b[1L] <- beta[1L] - sum(mu * b[idx])
    }
    return(b)
  }

  stop("readout_unscale_beta(): beta must be a numeric vector or matrix.")
}

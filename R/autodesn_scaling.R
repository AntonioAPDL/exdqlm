# Frozen, per-column readout scaling. This is distinct from response/input
# scaling and the optional 1/sqrt(d) dimension normalization.
.autodesn_feature_fit <- function(H, standardize, tolerance) {
  .autodesn_flag(standardize, "standardize_features")
  .autodesn_positive(tolerance, "feature_sd_tol")
  p <- ncol(H)
  center <- if (standardize) colMeans(H) else rep(0, p)
  spread <- if (standardize && p) sqrt(colSums(sweep(H, 2L, center, "-")^2) / (nrow(H) - 1L)) else rep(1, p)
  active <- if (standardize) which(spread > tolerance) else seq_len(p)
  # Constant columns cannot have unit variance. Their frozen exclusion avoids
  # introducing unidentified coefficients into the shrinkage hierarchy.
  F <- H[, active, drop = FALSE]
  scale_info <- NULL
  if (length(active)) {
    shared <- readout_scale_fit(cbind(intercept = 1, F), has_intercept = TRUE,
      center = standardize, scale = standardize, eps = tolerance)
    F <- shared$X[, -1L, drop = FALSE]
    scale_info <- shared$scale_info
  }
  list(features = F, raw_d = p, feature_center = center,
    feature_scale = spread, active_features = active,
    dropped_features = setdiff(seq_len(p), active),
    standardize_features = standardize, feature_sd_tol = tolerance,
    readout_scale_info = scale_info)
}

.autodesn_feature_apply <- function(model, H) {
  H <- as.matrix(H)
  raw_d <- if (is.null(model$raw_d)) model$d else model$raw_d
  if (!is.numeric(H) || nrow(H) < 1L || ncol(H) != raw_d || any(!is.finite(H)))
    stop("New features must be finite with the original fitted feature dimension.", call. = FALSE)
  if (is.null(model$active_features)) return(H / model$divisor)
  active <- model$active_features
  F <- H[, active, drop = FALSE]
  if (length(active) && !is.null(model$readout_scale_info))
    F <- readout_scale_apply(cbind(intercept = 1, F), model$readout_scale_info)[, -1L, drop = FALSE]
  F / model$divisor
}

# Transport a joint draw to the shared reservoir engine's raw coordinates.
# The intercept shift is essential: scaling slopes alone changes forecasts.
.autodesn_raw_beta <- function(model, beta) {
  beta <- as.matrix(beta)
  if (ncol(beta) != model$d + 1L || any(!is.finite(beta)))
    stop("Coefficient dimension does not match the fitted readout.", call. = FALSE)
  if (is.null(model$active_features)) {
    beta[, -1L] <- beta[, -1L, drop = FALSE] / model$divisor
    return(beta)
  }
  active <- model$active_features
  out <- matrix(0, nrow(beta), model$raw_d + 1L)
  out[, 1L] <- beta[, 1L]
  if (length(active)) {
    beta[, -1L] <- beta[, -1L, drop = FALSE] / model$divisor
    raw <- readout_unscale_beta(beta, model$readout_scale_info)
    out[, 1L] <- raw[, 1L]
    out[, active + 1L] <- raw[, -1L, drop = FALSE]
  }
  out
}

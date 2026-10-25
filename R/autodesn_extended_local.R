#' Frozen reservoir-local scale proposal for augmented AutoDESN
#'
#' This is a computational proposal and leaves the normalized RHS prior intact.
#' Its active-scale density mixes the joint unit log-half-Cauchy prior with a
#' product of Gaussian kernel estimates. Inactive reservoir slots use their
#' proper prior. Supply it as model_control$local_proposal; local_moves defaults
#' to one when a proposal is supplied. Coefficients and reservoir auxiliaries
#' are marginalized in these moves and redrawn before conditioned updates.
#' Set model_control$local_scale_proposal=TRUE to additionally propose noise,
#' global and slab scales using the supplied frozen joint_proposal. This remains
#' one exact joint MH move, with the local density conditioned on each state's
#' own global scale and all transformed scale-prior/proposal terms retained.
#'
#' @param centers List of K_m by d_m matrices of log-local-scale kernel centers.
#' @param bandwidth List of positive kernel SD vectors, one per reservoir.
#' @param slope Optional list of shifts per unit change in log global scale.
#' @param reference_log_global Reference global log scale, scalar or per reservoir.
#' @param weight Kernel-product mixture weight, scalar or per reservoir, in [0,1).
#' @param bank_id Exact augmented bank identity used to prepare the proposal.
#' @param kernel_coordinates Optional list of distinct integer positions among
#'   each model's active reservoir coefficients to use in the kernel density.
#'   Remaining local scales are proposed from their proper half-Cauchy priors.
#'   This changes only the proposal; no feature or architecture is removed.
#' @return A serializable normalized proposal. Freeze it before production.
#' @export
autodesn_extended_local_proposal <- function(centers, bandwidth, slope = NULL,
    reference_log_global = 0, weight = .8, bank_id, kernel_coordinates = NULL) {
  if (!is.list(centers) || !length(centers) || !is.list(bandwidth) ||
      length(centers) != length(bandwidth)) stop("Supply one center matrix and bandwidth vector per reservoir.", call. = FALSE)
  M <- length(centers)
  dimension <- vapply(centers, function(x) {
    if (!is.matrix(x) || !is.numeric(x) || any(!is.finite(x))) stop("Local centers must be finite numeric matrices.", call. = FALSE)
    ncol(x)
  }, 0L)
  if (is.null(slope)) slope <- lapply(dimension, function(d) numeric(d))
  if (!is.list(slope) || length(slope) != M) stop("Supply one slope vector per reservoir.", call. = FALSE)
  expand <- function(x, label) {
    if (!is.numeric(x) || !length(x) %in% c(1L, M) || any(!is.finite(x))) stop("Invalid ", label, ".", call. = FALSE)
    rep_len(x, M)
  }
  reference_log_global <- expand(reference_log_global, "reference log global scales")
  weight <- expand(weight, "mixture weights")
  if (any(weight < 0 | weight >= 1)) stop("Local mixture weights must lie in [0,1), retaining a prior component.", call. = FALSE)
  for (m in seq_len(M)) {
    if (length(bandwidth[[m]]) != dimension[m] || any(!is.finite(bandwidth[[m]]) | bandwidth[[m]] <= 0) ||
        length(slope[[m]]) != dimension[m] || any(!is.finite(slope[[m]])) ||
        (weight[m] > 0 && !nrow(centers[[m]]))) stop("Inconsistent local proposal dimensions or scales.", call. = FALSE)
  }
  if (!is.character(bank_id) || length(bank_id) != 1L || !nzchar(bank_id)) stop("Supply the exact augmented bank_id.", call. = FALSE)
  if (!is.null(kernel_coordinates)) {
    if (!is.list(kernel_coordinates) || length(kernel_coordinates) != M) stop("Supply one kernel-coordinate vector per reservoir.", call. = FALSE)
    kernel_coordinates <- lapply(seq_len(M), function(m) {
      x <- kernel_coordinates[[m]]
      if (!is.numeric(x) || any(!is.finite(x) | x != floor(x) | x < 1 | x > dimension[m]) || anyDuplicated(x)) stop("Kernel coordinates must be distinct active-column positions.", call. = FALSE)
      sort(as.integer(x))
    })
  }
  result <- list(centers = centers, bandwidth = bandwidth, slope = slope,
    reference_log_global = reference_log_global, weight = weight, bank_id = bank_id)
  if (!is.null(kernel_coordinates)) result$kernel_coordinates <- kernel_coordinates
  structure(result,
    class = c("autodesn_extended_local_proposal", "list"))
}

.ext_local_logq <- function(value, m, log_global, proposal) {
  prior <- sum(.autodesn_rhs_log_hc_log(value))
  w <- proposal$weight[m]
  if (!length(value) || w == 0) return(prior)
  center <- proposal$centers[[m]]
  shift <- proposal$slope[[m]] * (log_global - proposal$reference_log_global[m])
  selected <- proposal$kernel_coordinates[[m]]
  other <- 0
  if (!is.null(selected)) {
    if (!length(selected)) return(prior)
    other <- sum(.autodesn_rhs_log_hc_log(value[-selected]))
    value <- value[selected]
    prior <- sum(.autodesn_rhs_log_hc_log(value))
    center <- center[, selected, drop = FALSE]
    shift <- shift[selected]
  }
  bandwidth <- if (is.null(selected)) proposal$bandwidth[[m]] else proposal$bandwidth[[m]][selected]
  residual <- sweep(center, 2L, value - shift, "-")
  z <- sweep(residual, 2L, bandwidth, "/")
  kernel <- matrix(stats::dnorm(as.numeric(z), log = TRUE), nrow(z), ncol(z))
  kernel <- sweep(kernel, 2L, log(bandwidth), "-")
  top <- apply(kernel, 2L, max)
  marginal <- rep(-Inf, length(top))
  finite <- is.finite(top)
  if (any(finite)) marginal[finite] <- top[finite] +
    log(colMeans(exp(sweep(kernel[, finite, drop = FALSE], 2L, top[finite], "-"))))
  value <- .autodesn_rhs_logadd(log1p(-w) + prior, log(w) + sum(marginal))
  if (is.null(selected)) value else other + value
}

.ext_local_draw <- function(m, log_global, proposal) {
  d <- ncol(proposal$centers[[m]])
  if (!d) return(numeric(0))
  if (stats::runif(1) >= proposal$weight[m]) return(log(abs(stats::rcauchy(d))))
  center <- proposal$centers[[m]]
  coordinates <- proposal$kernel_coordinates[[m]]
  if (!is.null(coordinates)) {
    value <- log(abs(stats::rcauchy(d)))
    if (!length(coordinates)) return(value)
    row <- sample.int(nrow(center), length(coordinates), replace = TRUE)
    value[coordinates] <- center[cbind(row, coordinates)] + proposal$slope[[m]][coordinates] *
      (log_global - proposal$reference_log_global[m]) +
      proposal$bandwidth[[m]][coordinates] * stats::rnorm(length(coordinates))
    return(value)
  }
  selected <- sample.int(nrow(center), d, replace = TRUE)
  center[cbind(selected, seq_len(d))] + proposal$slope[[m]] *
    (log_global - proposal$reference_log_global[m]) +
    proposal$bandwidth[[m]] * stats::rnorm(d)
}

.ext_local_correction <- function(value, m, log_global, proposal) {
  sum(.autodesn_rhs_log_hc_log(value)) - .ext_local_logq(value, m, log_global, proposal)
}

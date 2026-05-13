.exdqlm_default_kl_k <- function(n_self, n_ref) {
  limit <- min(as.integer(n_self) - 1L, as.integer(n_ref))
  if (!is.finite(limit) || limit < 1L) {
    return(integer())
  }
  k <- c(3L, 5L, 10L, 20L, 30L)
  k <- k[k <= limit]
  if (!length(k)) {
    k <- 1L
  }
  k
}

.exdqlm_validate_kl_k <- function(kl_k, n_self, n_ref) {
  limit <- min(as.integer(n_self) - 1L, as.integer(n_ref))
  if (!is.finite(limit) || limit < 1L) {
    if (is.null(kl_k)) {
      return(integer())
    }
    stop("`kl_k` cannot be used with fewer than two finite standardized errors.", call. = FALSE)
  }
  if (is.null(kl_k)) {
    return(.exdqlm_default_kl_k(n_self, n_ref))
  }
  if (!is.numeric(kl_k) || !length(kl_k) || any(!is.finite(kl_k)) || any(kl_k <= 0)) {
    stop("`kl_k` must be a non-empty numeric vector of positive finite integers.", call. = FALSE)
  }
  if (any(abs(kl_k - round(kl_k)) > sqrt(.Machine$double.eps))) {
    stop("`kl_k` must contain integer values.", call. = FALSE)
  }
  kl_k <- as.integer(round(kl_k))
  if (anyDuplicated(kl_k)) {
    stop("`kl_k` must not contain duplicate values.", call. = FALSE)
  }
  if (any(kl_k > limit)) {
    stop(
      "`kl_k` values must be no larger than min(number of finite standardized errors - 1, reference sample size).",
      call. = FALSE
    )
  }
  sort(kl_k)
}

.exdqlm_normal_quantile_grid <- function(n) {
  n <- as.integer(n)
  if (!is.finite(n) || n < 1L) {
    return(numeric())
  }
  stats::qnorm((seq_len(n) - 0.5) / n)
}

.exdqlm_kl_distance_floor <- function() {
  sqrt(.Machine$double.eps)
}

.exdqlm_floor_kl_distances <- function(distances) {
  floor_value <- .exdqlm_kl_distance_floor()
  needs_floor <- !is.finite(distances) | distances <= 0
  zero_count <- colSums(needs_floor)
  distances[needs_floor] <- floor_value
  list(distances = distances, zero_count = as.integer(zero_count))
}

.exdqlm_knn_self_dist_1d <- function(x, k_values) {
  x <- sort(as.numeric(x))
  n <- length(x)
  kmax <- max(k_values)
  distances <- matrix(NA_real_, nrow = n, ncol = length(k_values))

  for (i in seq_len(n)) {
    lo <- max(1L, i - kmax)
    hi <- min(n, i + kmax)
    idx <- seq.int(lo, hi)
    idx <- idx[idx != i]
    d <- sort(abs(x[idx] - x[i]), method = "quick")
    distances[i, ] <- d[k_values]
  }

  out <- .exdqlm_floor_kl_distances(distances)
  colnames(out$distances) <- as.character(k_values)
  names(out$zero_count) <- as.character(k_values)
  out
}

.exdqlm_knn_cross_dist_1d <- function(query, reference, k_values) {
  query <- as.numeric(query)
  reference <- sort(as.numeric(reference))
  n_query <- length(query)
  n_ref <- length(reference)
  kmax <- max(k_values)
  distances <- matrix(NA_real_, nrow = n_query, ncol = length(k_values))
  pos <- findInterval(query, reference)

  for (i in seq_len(n_query)) {
    lo <- max(1L, pos[[i]] - kmax)
    hi <- min(n_ref, pos[[i]] + kmax + 1L)
    idx <- seq.int(lo, hi)
    d <- sort(abs(reference[idx] - query[[i]]), method = "quick")
    distances[i, ] <- d[k_values]
  }

  out <- .exdqlm_floor_kl_distances(distances)
  colnames(out$distances) <- as.character(k_values)
  names(out$zero_count) <- as.character(k_values)
  out
}

.exdqlm_kl_gaussian_1d <- function(x) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (length(x) < 2L) {
    return(list(KL = NA_real_, KL.flip = NA_real_))
  }
  mu <- mean(x)
  sigma2 <- stats::var(x)
  if (!is.finite(sigma2) || sigma2 <= 0) {
    sigma2 <- .Machine$double.eps
  }
  list(
    KL = 0.5 * (sigma2 + mu^2 - 1 - log(sigma2)),
    KL.flip = 0.5 * (1 / sigma2 + mu^2 / sigma2 - 1 + log(sigma2))
  )
}

.exdqlm_kl_empty_table <- function(columns) {
  out <- as.data.frame(stats::setNames(rep(list(numeric()), length(columns)), columns))
  out
}

.exdqlm_kl_scalar <- function(x) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (!length(x)) {
    NA_real_
  } else {
    stats::median(x)
  }
}

.exdqlm_kl_normality_1d <- function(x, ref = NULL, kl_k = NULL) {
  x <- as.numeric(x)
  n_total <- length(x)
  x <- x[is.finite(x)]
  n_self <- length(x)

  if (is.null(ref)) {
    ref_use <- .exdqlm_normal_quantile_grid(n_self)
    reference_label <- "normal_quantile_grid"
  } else {
    ref <- as.numeric(ref)
    if (length(ref) != n_total) {
      stop("ref should be a sample of size 'length(y)' from a standard normal distribution", call. = FALSE)
    }
    if (any(!is.finite(ref))) {
      stop("ref must contain only finite values.", call. = FALSE)
    }
    ref_use <- ref
    reference_label <- "user_ref"
  }

  n_ref <- length(ref_use)
  k_values <- .exdqlm_validate_kl_k(kl_k, n_self, n_ref)
  gaussian <- .exdqlm_kl_gaussian_1d(x)

  if (!length(k_values)) {
    return(list(
      KL = NA_real_,
      KL.flip = NA_real_,
      KL.by_k = .exdqlm_kl_empty_table(c("k", "normal_cross_entropy", "entropy", "KL", "zero_distance_count")),
      KL.flip.by_k = .exdqlm_kl_empty_table(c("k", "cross_entropy", "normal_entropy", "KL", "zero_distance_count")),
      KL.gaussian = gaussian$KL,
      KL.flip.gaussian = gaussian$KL.flip,
      method = "semiclosed_knn_1d",
      k = integer(),
      aggregate = "median",
      reference = reference_label,
      n_finite = n_self,
      n_ref = n_ref,
      zero_distance_count = 0L
    ))
  }

  self_dist <- .exdqlm_knn_self_dist_1d(x, k_values)
  cross_dist <- .exdqlm_knn_cross_dist_1d(ref_use, x, k_values)

  entropy <- digamma(n_self) - digamma(k_values) + log(2) +
    colMeans(log(self_dist$distances))
  normal_cross_entropy <- 0.5 * log(2 * pi) + 0.5 * mean(x^2)
  forward <- data.frame(
    k = k_values,
    normal_cross_entropy = rep(normal_cross_entropy, length(k_values)),
    entropy = as.numeric(entropy),
    KL = as.numeric(normal_cross_entropy - entropy),
    zero_distance_count = as.integer(self_dist$zero_count),
    row.names = NULL
  )

  cross_entropy <- digamma(n_self) - digamma(k_values) + log(2) +
    colMeans(log(cross_dist$distances))
  normal_entropy <- 0.5 * log(2 * pi * exp(1))
  reverse <- data.frame(
    k = k_values,
    cross_entropy = as.numeric(cross_entropy),
    normal_entropy = rep(normal_entropy, length(k_values)),
    KL = as.numeric(cross_entropy - normal_entropy),
    zero_distance_count = as.integer(cross_dist$zero_count),
    row.names = NULL
  )

  list(
    KL = .exdqlm_kl_scalar(forward$KL),
    KL.flip = .exdqlm_kl_scalar(reverse$KL),
    KL.by_k = forward,
    KL.flip.by_k = reverse,
    KL.gaussian = gaussian$KL,
    KL.flip.gaussian = gaussian$KL.flip,
    method = "semiclosed_knn_1d",
    k = k_values,
    aggregate = "median",
    reference = reference_label,
    n_finite = n_self,
    n_ref = n_ref,
    zero_distance_count = as.integer(sum(self_dist$zero_count) + sum(cross_dist$zero_count))
  )
}

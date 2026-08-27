.qdesn_readout_transform_spec <- function(spec = NULL) {
  spec <- spec %||% list()
  mode <- tolower(as.character(spec$mode %||% "none")[1L])
  aliases <- c(
    identity = "none",
    residualize = "orthogonalize_reservoir",
    orthogonalize = "orthogonalize_reservoir",
    residualize_svd = "orthogonalize_reservoir_svd",
    orthogonalize_svd = "orthogonalize_reservoir_svd"
  )
  if (mode %in% names(aliases)) mode <- unname(aliases[[mode]])
  allowed <- c("none", "orthogonalize_reservoir", "orthogonalize_reservoir_svd")
  if (!mode %in% allowed) {
    stop(sprintf("Unknown readout linear-transform mode '%s'.", mode), call. = FALSE)
  }
  prefix <- as.character(spec$deterministic_prefix %||% "period90_")[1L]
  if (is.na(prefix) || !nzchar(prefix)) prefix <- "period90_"
  ridge <- as.numeric(spec$projection_ridge %||% 1e-10)[1L]
  if (!is.finite(ridge) || ridge < 0) {
    stop("readout linear-transform projection_ridge must be finite and nonnegative.",
         call. = FALSE)
  }
  energy <- as.numeric(spec$svd_energy_threshold %||% 0.995)[1L]
  if (!is.finite(energy) || energy <= 0 || energy > 1) {
    stop("readout linear-transform svd_energy_threshold must be in (0, 1].",
         call. = FALSE)
  }
  max_rank <- as.integer(spec$svd_max_rank %||% 80L)[1L]
  min_rank <- as.integer(spec$svd_min_rank %||% 1L)[1L]
  if (!is.finite(max_rank) || max_rank < 1L ||
      !is.finite(min_rank) || min_rank < 1L || min_rank > max_rank) {
    stop("Invalid readout linear-transform SVD rank bounds.", call. = FALSE)
  }
  list(
    mode = mode,
    deterministic_prefix = prefix,
    projection_ridge = ridge,
    svd_energy_threshold = energy,
    svd_max_rank = max_rank,
    svd_min_rank = min_rank
  )
}

.qdesn_readout_transform_indices <- function(X, p_res, has_intercept, spec) {
  p <- ncol(X)
  nm <- colnames(X)
  if (is.null(nm) || length(nm) != p || any(!nzchar(nm))) {
    stop("Readout linear transforms require complete design column names.", call. = FALSE)
  }
  p_res <- as.integer(p_res)[1L]
  if (!is.finite(p_res) || p_res < 1L || p_res > p) {
    stop("readout linear-transform p_res is outside the design dimension.",
         call. = FALSE)
  }
  intercept_idx <- if (isTRUE(has_intercept)) 1L else integer(0)
  reservoir_idx <- unique(c(
    seq_len(p_res),
    which(grepl("_res_lag_[0-9]+$", nm))
  ))
  reservoir_idx <- setdiff(reservoir_idx, intercept_idx)
  deterministic_idx <- which(startsWith(nm, spec$deterministic_prefix))
  deterministic_idx <- setdiff(deterministic_idx, reservoir_idx)
  if (!length(deterministic_idx)) {
    stop(sprintf(
      "No deterministic readout columns matched prefix '%s'.",
      spec$deterministic_prefix
    ), call. = FALSE)
  }
  if (!length(reservoir_idx)) {
    stop("No non-intercept reservoir columns were available to transform.",
         call. = FALSE)
  }
  list(
    intercept = intercept_idx,
    deterministic = deterministic_idx,
    reservoir = reservoir_idx,
    retained = setdiff(seq_len(p), reservoir_idx)
  )
}

readout_linear_transform_fit <- function(X, transform_spec = NULL, p_res,
                                         has_intercept = FALSE) {
  stopifnot(is.matrix(X))
  spec <- .qdesn_readout_transform_spec(transform_spec)
  if (identical(spec$mode, "none")) {
    return(list(
      X = X,
      transform = list(
        schema_version = "qdesn_readout_linear_transform_v1",
        mode = "none",
        active = FALSE,
        input_colnames = colnames(X),
        output_colnames = colnames(X),
        input_dimension = ncol(X),
        output_dimension = ncol(X)
      )
    ))
  }

  idx <- .qdesn_readout_transform_indices(X, p_res, has_intercept, spec)
  anchor_idx <- c(idx$intercept, idx$deterministic)
  A <- X[, anchor_idx, drop = FALSE]
  R <- X[, idx$reservoir, drop = FALSE]
  if (any(!is.finite(A)) || any(!is.finite(R))) {
    stop("Readout linear-transform inputs must be finite.", call. = FALSE)
  }
  gram <- crossprod(A)
  penalty <- diag(spec$projection_ridge, nrow = ncol(A))
  if (length(idx$intercept)) penalty[1L, 1L] <- 0
  coef <- tryCatch(
    solve(gram + penalty, crossprod(A, R)),
    error = function(e) qr.solve(gram + penalty, crossprod(A, R), tol = 1e-12)
  )
  residual <- R - A %*% coef

  output <- X
  loadings <- NULL
  retained_idx <- seq_len(ncol(X))
  singular_values <- numeric(0)
  selected_rank <- ncol(residual)
  if (identical(spec$mode, "orthogonalize_reservoir")) {
    output[, idx$reservoir] <- residual
  } else {
    sv <- svd(residual, nu = 0L, nv = min(nrow(residual), ncol(residual)))
    singular_values <- as.numeric(sv$d)
    energy <- singular_values^2
    cumulative <- if (sum(energy) > 0) cumsum(energy) / sum(energy) else
      rep(1, length(energy))
    selected_rank <- which(cumulative >= spec$svd_energy_threshold)[1L]
    if (!is.finite(selected_rank)) selected_rank <- 1L
    selected_rank <- max(spec$svd_min_rank,
                         min(spec$svd_max_rank, selected_rank, ncol(sv$v)))
    loadings <- sv$v[, seq_len(selected_rank), drop = FALSE]
    scores <- residual %*% loadings
    colnames(scores) <- sprintf("reservoir_orth_svd_%03d", seq_len(selected_rank))
    retained_idx <- idx$retained
    output <- cbind(X[, retained_idx, drop = FALSE], scores)
  }
  colnames(output) <- make.unique(colnames(output), sep = "_")

  fitted <- A %*% coef
  total_ss <- colSums(sweep(R, 2L, colMeans(R), "-")^2)
  residual_ss <- colSums(residual^2)
  explained <- 1 - residual_ss / pmax(total_ss, .Machine$double.eps)
  transform <- list(
    schema_version = "qdesn_readout_linear_transform_v1",
    mode = spec$mode,
    active = TRUE,
    deterministic_prefix = spec$deterministic_prefix,
    projection_ridge = spec$projection_ridge,
    input_colnames = colnames(X),
    output_colnames = colnames(output),
    input_dimension = ncol(X),
    output_dimension = ncol(output),
    p_res_raw = as.integer(p_res),
    has_intercept = isTRUE(has_intercept),
    anchor_idx = as.integer(anchor_idx),
    deterministic_idx = as.integer(idx$deterministic),
    reservoir_idx = as.integer(idx$reservoir),
    retained_idx = as.integer(retained_idx),
    projection_coef = unclass(coef),
    svd_loadings = if (is.null(loadings)) NULL else unclass(loadings),
    svd_energy_threshold = spec$svd_energy_threshold,
    svd_max_rank = spec$svd_max_rank,
    selected_rank = as.integer(selected_rank),
    singular_values = singular_values,
    reservoir_projection_r2_median = stats::median(explained, na.rm = TRUE),
    reservoir_projection_r2_max = max(explained, na.rm = TRUE),
    projection_fitted_frobenius = sqrt(sum(fitted^2)),
    residual_frobenius = sqrt(sum(residual^2))
  )
  list(X = output, transform = transform)
}

readout_linear_transform_apply <- function(X, transform) {
  stopifnot(is.matrix(X))
  if (is.null(transform) || !isTRUE(transform$active) ||
      identical(as.character(transform$mode), "none")) return(X)
  expected <- as.integer(transform$input_dimension)[1L]
  if (ncol(X) != expected) {
    stop(sprintf(
      "Readout linear-transform dimension mismatch: expected %d, got %d.",
      expected, ncol(X)
    ), call. = FALSE)
  }
  expected_names <- as.character(unlist(transform$input_colnames, use.names = FALSE))
  if (length(expected_names) && !identical(colnames(X), expected_names)) {
    stop("Readout linear-transform input column names do not match training.",
         call. = FALSE)
  }
  anchor_idx <- as.integer(unlist(transform$anchor_idx, use.names = FALSE))
  reservoir_idx <- as.integer(unlist(transform$reservoir_idx, use.names = FALSE))
  retained_idx <- as.integer(unlist(transform$retained_idx, use.names = FALSE))
  coef <- as.matrix(transform$projection_coef)
  residual <- X[, reservoir_idx, drop = FALSE] -
    X[, anchor_idx, drop = FALSE] %*% coef
  mode <- as.character(transform$mode)[1L]
  if (identical(mode, "orthogonalize_reservoir")) {
    out <- X
    out[, reservoir_idx] <- residual
  } else if (identical(mode, "orthogonalize_reservoir_svd")) {
    loadings <- as.matrix(transform$svd_loadings)
    scores <- residual %*% loadings
    colnames(scores) <- sprintf("reservoir_orth_svd_%03d", seq_len(ncol(scores)))
    out <- cbind(X[, retained_idx, drop = FALSE], scores)
  } else {
    stop(sprintf("Unsupported fitted readout transform mode '%s'.", mode),
         call. = FALSE)
  }
  output_names <- as.character(unlist(transform$output_colnames, use.names = FALSE))
  if (length(output_names) == ncol(out)) colnames(out) <- output_names
  out
}

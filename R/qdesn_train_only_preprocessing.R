#' Fit Q-DESN preprocessing on training rows only
#'
#' Applies optional affine scaling to the complete response and covariate arrays,
#' while estimating every transformation exclusively from the fitted portion of
#' the selected analysis window. This prevents held-out observations from
#' influencing either model fitting or forecast evaluation.
#'
#' @param y_all Numeric response vector on the complete input series.
#' @param X_all Optional numeric covariate matrix on the complete input series.
#' @param idx_use Integer input-row indices defining the selected analysis window.
#' @param n_train Number of leading rows in `idx_use` used for fitting.
#' @param scale_y Whether to standardize the response.
#' @param scale_x Whether to standardize covariates.
#'
#' @return A list containing transformed arrays, transformation parameters, and
#'   an auditable provenance record.
#' @keywords internal
qdesn_train_only_preprocess <- function(y_all, X_all = NULL, idx_use, n_train,
                                        scale_y = TRUE, scale_x = TRUE) {
  y_all <- as.numeric(y_all)
  idx_use <- as.integer(idx_use)
  n_train <- as.integer(n_train)[1L]

  if (!length(y_all)) stop("`y_all` must contain at least one observation.", call. = FALSE)
  if (!length(idx_use)) stop("`idx_use` must contain at least one row index.", call. = FALSE)
  if (anyNA(idx_use) || any(idx_use < 1L) || any(idx_use > length(y_all))) {
    stop("`idx_use` contains invalid input-row indices.", call. = FALSE)
  }
  if (!is.finite(n_train) || n_train < 1L || n_train >= length(idx_use)) {
    stop("`n_train` must leave at least one held-out row in `idx_use`.", call. = FALSE)
  }
  if (anyDuplicated(idx_use)) stop("`idx_use` must not contain duplicate rows.", call. = FALSE)

  fit_rows <- idx_use[seq_len(n_train)]
  y_fit <- y_all[fit_rows]
  if (!any(is.finite(y_fit))) {
    stop("Training responses contain no finite values for preprocessing.", call. = FALSE)
  }

  y_center <- mean(y_fit, na.rm = TRUE)
  y_scale <- stats::sd(y_fit, na.rm = TRUE)
  if (!is.finite(y_scale) || y_scale == 0) y_scale <- 1
  y_transformed <- if (isTRUE(scale_y)) (y_all - y_center) / y_scale else y_all

  X_transformed <- X_all
  X_center <- numeric(0)
  X_scale <- numeric(0)
  if (!is.null(X_all)) {
    X_all <- as.matrix(X_all)
    if (nrow(X_all) != length(y_all)) {
      stop("`X_all` must have one row per response observation.", call. = FALSE)
    }
    if (ncol(X_all) > 0L) {
      storage.mode(X_all) <- "double"
      X_fit <- X_all[fit_rows, , drop = FALSE]
      X_center <- colMeans(X_fit, na.rm = TRUE)
      if (any(!is.finite(X_center))) {
        stop("At least one training covariate has no finite values for preprocessing.", call. = FALSE)
      }
      X_scale <- apply(X_fit, 2L, function(v) {
        value <- stats::sd(v, na.rm = TRUE)
        if (!is.finite(value) || value == 0) 1 else value
      })
      names(X_center) <- colnames(X_all)
      names(X_scale) <- colnames(X_all)
      X_transformed <- if (isTRUE(scale_x)) {
        sweep(sweep(X_all, 2L, X_center, "-"), 2L, X_scale, "/")
      } else {
        X_all
      }
    }
  }

  fit_rows_contiguous <- length(fit_rows) <= 1L || all(diff(fit_rows) == 1L)
  provenance <- list(
    scope = "train_only",
    index_space = "absolute_input_row",
    fit_row_start = as.integer(fit_rows[1L]),
    fit_row_end = as.integer(fit_rows[length(fit_rows)]),
    fit_row_count = as.integer(length(fit_rows)),
    fit_rows_contiguous = isTRUE(fit_rows_contiguous),
    fit_row_indices_sha256 = digest::digest(fit_rows, algo = "sha256"),
    analysis_row_start = as.integer(idx_use[1L]),
    analysis_row_end = as.integer(idx_use[length(idx_use)]),
    analysis_row_count = as.integer(length(idx_use)),
    heldout_row_count = as.integer(length(idx_use) - length(fit_rows)),
    heldout_response_used_for_scaling = FALSE,
    heldout_covariates_used_for_scaling = FALSE,
    scale_y = isTRUE(scale_y),
    scale_x = isTRUE(scale_x),
    y_center = as.numeric(y_center),
    y_scale = as.numeric(y_scale),
    x_center = as.numeric(X_center),
    x_scale = as.numeric(X_scale)
  )
  if (length(X_center) && !is.null(names(X_center))) {
    provenance$x_columns <- names(X_center)
  } else {
    provenance$x_columns <- character(0)
  }

  list(
    y_all = y_transformed,
    X_all = X_transformed,
    y_center = y_center,
    y_scale = y_scale,
    X_center = X_center,
    X_scale = X_scale,
    fit_rows = fit_rows,
    provenance = provenance
  )
}

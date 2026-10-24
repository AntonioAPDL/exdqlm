#' Transport augmented readout coefficients to raw predictor coordinates
#'
#' The proper intercept and slope prior remain defined in the standardized fit
#' coordinates. This function transports a matching posterior draw, including
#' every intercept correction. It does not refit or assign a prior after rotation.
#'
#' @param object Augmented AutoDESN fit with its matching bank attached.
#' @param draw_index Indices of matching saved joint posterior draws.
#' @param response_scale If TRUE, predict the original response using original
#'   response-unit lag predictors. If FALSE, both response and lag predictors use
#'   the bank's frozen input/response scaling. Reservoir predictors in either case
#'   are the original reservoir readout features, before column standardization;
#'   calendar predictors are raw sine/cosine values at absolute timestamps.
#' @return List of named coefficient vectors and matching model/period identifiers.
#'   Dropped constant columns receive zero slopes. Incompatible readout vectors
#'   are kept separate rather than averaged.
#' @export
autodesn_readout_coefficients <- function(object,
    draw_index = seq_len(nrow(object$draws)), response_scale = TRUE) {
  if (!inherits(object, "autodesn_extended_fit") || is.null(object[["bank"]])) stop("Attach the matching augmented bank to an augmented fit.", call. = FALSE)
  .autodesn_flag(response_scale, "response_scale")
  ids <- draw_index
  if (!is.numeric(ids) || !length(ids) || any(!is.finite(ids) | ids != floor(ids) | ids < 1 | ids > nrow(object$draws))) stop("Invalid posterior draw indices.", call. = FALSE)
  bank <- object$bank
  e <- bank$extension
  if (!identical(e$id, object$controls$target$bank_id)) stop("Attached bank does not match the conditional posterior.", call. = FALSE)
  response_center <- if (is.null(bank$preprocessing)) 0 else bank$preprocessing$center
  response_sd <- if (is.null(bank$preprocessing)) 1 else bank$preprocessing$scale
  lapply(ids, function(k) {
    m <- object$draws$model[k]
    p <- object$draws$period_index[k]
    res <- bank$models[[m]]
    cal <- e$calendar[[p]]
    geometry <- list(e$lag, list(raw_d = res$raw_d, active = res$active_features,
      center = res$feature_center, scale = res$feature_scale), cal)
    dimensions <- vapply(geometry, `[[`, 0L, "raw_d")
    active <- lapply(geometry, `[[`, "active")
    B <- object$beta[[k]]
    stopifnot(length(B) == 1L + sum(lengths(active)))
    out <- numeric(1L + sum(dimensions))
    out[1L] <- B[1L]
    raw_offset <- 1L
    fitted_offset <- 1L
    for (g in seq_along(geometry)) {
      ix <- active[[g]]
      if (length(ix)) {
        slopes <- B[fitted_offset + seq_along(ix)] / geometry[[g]]$scale[ix]
        out[raw_offset + ix] <- slopes
        out[1L] <- out[1L] - sum(slopes * geometry[[g]]$center[ix])
      }
      raw_offset <- raw_offset + dimensions[g]
      fitted_offset <- fitted_offset + length(ix)
    }
    if (response_scale) {
      out <- out * response_sd
      out[1L] <- out[1L] + response_center
      if (dimensions[1L]) {
        ix <- 1L + seq_len(dimensions[1L])
        out[ix] <- out[ix] / response_sd
        out[1L] <- out[1L] - response_center * sum(out[ix])
      }
    }
    names(out) <- c("intercept", if (dimensions[1L]) paste0("lag_y", e$readout$lags) else character(),
      if (dimensions[2L]) paste0("reservoir_", seq_len(dimensions[2L])) else character(),
      if (dimensions[3L]) colnames(.ext_fourier(e$times[1L], e$periods[p], e$seasonal$harmonics)) else character())
    list(draw_index = k, model = m, period_index = p, period = e$periods[p],
      coefficients = out, response_scale = response_scale)
  })
}

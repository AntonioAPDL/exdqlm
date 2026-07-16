#' Forecast interval paths from an RQR-DESN fit
#'
#' RQR-DESN does not define response predictive draws. This method therefore
#' works only with an explicit future design matrix or a declared driver that
#' supplies such a design matrix. It refuses silent recursive response sampling.
#'
#' @param object An `rqr_desn_fit` object.
#' @param H Forecast horizon.
#' @param X_future Optional explicit future design matrix with `H` rows.
#' @param history_driver One of `"none"`, `"teacher_forced"`, `"companion_fit"`,
#'   or `"plugin"`.
#' @param plugin Optional function returning an explicit future design matrix.
#' @param nd Number of posterior draws.
#' @param seed Optional RNG seed.
#' @param ... Reserved.
#' @return A list with interval draws and summaries.
#' @export
forecast_paths.rqr_desn_fit <- function(object, H, X_future = NULL,
                                        history_driver = c("none", "teacher_forced", "companion_fit", "plugin"),
                                        plugin = NULL,
                                        nd = NULL,
                                        seed = NULL,
                                        ...) {
  if (!inherits(object, "rqr_desn_fit")) stop("Expected an rqr_desn_fit object.", call. = FALSE)
  H <- as.integer(H)[1L]
  if (!is.finite(H) || H < 1L) stop("H must be a positive integer.", call. = FALSE)
  history_driver <- match.arg(history_driver)

  if (is.null(X_future) && identical(history_driver, "plugin")) {
    if (!is.function(plugin)) stop("history_driver='plugin' requires a plugin function.", call. = FALSE)
    X_future <- plugin(object = object, H = H, ...)
  }

  if (is.null(X_future)) {
    stop(
      paste(
        "RQR-DESN cannot recursively sample future responses from its pseudo-AL construction.",
        "Supply X_future or a plugin that returns an explicit future design matrix.",
        "Teacher-forced and companion-fit state drivers require a separate application adapter."
      ),
      call. = FALSE
    )
  }
  X_future <- as.matrix(X_future)
  if (nrow(X_future) != H) stop("X_future must have H rows.", call. = FALSE)
  out <- predict_interval(object, X_new = X_future, nd = nd, seed = seed)
  out$H <- H
  out$history_driver <- history_driver
  out$response_predictive_draws <- FALSE
  out
}

#' Held-out forecast diagnostics for exDQLM forecasts
#'
#' Computes held-out forecast scores from one or two \code{exdqlmForecast}
#' objects returned by [exdqlmForecast()]. Unlike [exdqlmDiagnostics()], which
#' summarizes fitted one-step-ahead forecast errors and their KL normality
#' diagnostics, this function evaluates posterior predictive forecast draws
#' against observations reserved outside the fitted sample.
#'
#' @param m1 An object of class "\code{exdqlmForecast}", returned by
#'   [exdqlmForecast()] with \code{return.draws = TRUE}.
#' @param m2 An optional second object of class "\code{exdqlmForecast}" to
#'   compare with \code{m1}.
#' @param y Numeric vector or time series of held-out observations. Its length
#'   must equal the forecast horizon.
#' @param p0 Optional quantile level used for the check-loss calculation. When
#'   \code{NULL}, the value is taken from \code{m1$m1$p0}. If \code{m2} is
#'   supplied, its fitted quantile level must agree with the resolved value.
#' @param crps_probs Numeric vector of quantile levels used to approximate CRPS
#'   through the integrated quantile-score identity. Values must be strictly
#'   between 0 and 1. Default is \code{seq(0.01, 0.99, by = 0.01)}.
#' @param crps_weights Optional non-negative numeric weights for
#'   \code{crps_probs}. When \code{NULL}, equal weights are used. When provided,
#'   weights are normalized to sum to 1.
#'
#' @return An object of class "\code{exdqlmForecastDiagnostic}" containing:
#' \itemize{
#'   \item \code{y} - Held-out observations used for scoring.
#'   \item \code{p0} - Quantile level used for check loss.
#'   \item \code{horizon} - Forecast horizon.
#'   \item \code{m1.check_loss} - Mean target-quantile check loss for
#'   \code{m1}.
#'   \item \code{m1.CRPS} - Mean CRPS approximation for \code{m1}.
#'   \item \code{m1.pointwise} - Pointwise held-out scores for \code{m1}.
#'   \item \code{crps.method}, \code{crps.probs}, and \code{crps.weights} -
#'   CRPS approximation metadata.
#' }
#' If \code{m2} is supplied, analogous \code{m2.*} fields are included.
#'
#' @details
#' The check loss is computed at the target quantile level \code{p0} using the
#' forecast quantile means \code{ff} stored in each forecast object. CRPS is
#' computed from \code{samp.fore} using the same finite integrated quantile-score
#' approximation used by [exdqlmDiagnostics()]. This function does not compute
#' KL diagnostics because KL in \pkg{exdqlm} is defined for fitted
#' one-step-ahead MAP standardized forecast errors, not for arbitrary held-out
#' forecast draws.
#'
#' @export
#'
#' @examples
#' \donttest{
#' data("scIVTmag", package = "exdqlm")
#' old = options(exdqlm.max_iter = 15L)
#' y = scIVTmag[1:65]
#' y_train = y[1:60]
#' y_holdout = y[61:65]
#' model = polytrendMod(1, stats::quantile(y_train, 0.85), 10)
#' M0 = exdqlmLDVB(y_train, p0 = 0.85, model, df = c(0.98), dim.df = c(1),
#'                  gam.init = -3.5, sig.init = 15,
#'                  n.samp = 20, tol = 0.2, verbose = FALSE)
#' fFF = model$FF[, 1, drop = FALSE]
#' fGG = model$GG
#' M0.forecast = exdqlmForecast(start.t = 60, k = 5, m1 = M0,
#'                              fFF = fFF, fGG = fGG,
#'                              return.draws = TRUE, n.samp = 20, seed = 123,
#'                              plot = FALSE)
#' exdqlmForecastDiagnostics(M0.forecast, y = y_holdout)
#' options(old)
#' }
exdqlmForecastDiagnostics <- function(m1, m2 = NULL, y, p0 = NULL,
                                      crps_probs = seq(0.01, 0.99, by = 0.01),
                                      crps_weights = NULL) {
  safe_metric_mean <- function(x) {
    x <- as.numeric(x)
    x <- x[is.finite(x)]
    if (!length(x)) NA_real_ else mean(x)
  }

  check_forecast <- function(x, name) {
    if (!is.exdqlmForecast(x)) {
      stop(sprintf("%s must be an output from 'exdqlmForecast()'.", name), call. = FALSE)
    }
    if (is.null(x$samp.fore)) {
      stop(sprintf(
        "%s must contain posterior forecast draws. Re-run exdqlmForecast(..., return.draws = TRUE).",
        name
      ), call. = FALSE)
    }
    draws <- as.matrix(x$samp.fore)
    if (nrow(draws) != x$k) {
      stop(sprintf("%s$samp.fore must have one row per forecast horizon step.", name), call. = FALSE)
    }
    if (length(x$ff) < x$k) {
      stop(sprintf("%s$ff must contain at least k forecast quantiles.", name), call. = FALSE)
    }
    invisible(draws)
  }

  y <- as.numeric(y)
  if (!length(y)) {
    stop("y must contain at least one held-out observation.", call. = FALSE)
  }
  if (any(!is.finite(y))) {
    stop("y must contain only finite held-out observations.", call. = FALSE)
  }

  draws1 <- check_forecast(m1, "m1")
  if (length(y) != m1$k || nrow(draws1) != length(y)) {
    stop("length(y) must equal the forecast horizon in m1.", call. = FALSE)
  }

  p0_resolved <- if (is.null(p0)) m1$m1$p0 else p0
  p0_resolved <- as.numeric(p0_resolved)[1]
  if (!is.finite(p0_resolved) || p0_resolved <= 0 || p0_resolved >= 1) {
    stop("p0 must be a finite numeric value strictly between 0 and 1.", call. = FALSE)
  }
  if (!is.null(m1$m1$p0) && !isTRUE(all.equal(as.numeric(m1$m1$p0), p0_resolved))) {
    stop("p0 does not match the quantile level stored in m1.", call. = FALSE)
  }

  crps_probs <- .exdqlm_validate_crps_probs(crps_probs)
  crps_weights <- .exdqlm_validate_crps_weights(crps_weights, length(crps_probs))

  score_one <- function(forecast_obj, draws) {
    qhat <- as.numeric(forecast_obj$ff[seq_along(y)])
    check_loss <- CheckLossFn(p0_resolved, y - qhat)
    crps <- .exdqlm_crps_vec(y, draws, probs = crps_probs, weights = crps_weights)
    list(
      check_loss = safe_metric_mean(check_loss),
      CRPS = safe_metric_mean(crps),
      pointwise = data.frame(
        step = seq_along(y),
        y = y,
        forecast_quantile = qhat,
        check_loss = as.numeric(check_loss),
        CRPS = as.numeric(crps),
        stringsAsFactors = FALSE
      )
    )
  }

  m1_scores <- score_one(m1, draws1)
  ret <- list(
    y = y,
    p0 = p0_resolved,
    horizon = length(y),
    m1.check_loss = m1_scores$check_loss,
    m1.CRPS = m1_scores$CRPS,
    m1.pointwise = m1_scores$pointwise,
    crps.method = "integrated_quantile_score",
    crps.probs = crps_probs,
    crps.weights = crps_weights
  )

  if (!is.null(m2)) {
    draws2 <- check_forecast(m2, "m2")
    if (length(y) != m2$k || nrow(draws2) != length(y)) {
      stop("length(y) must equal the forecast horizon in m2.", call. = FALSE)
    }
    if (!is.null(m2$m1$p0) && !isTRUE(all.equal(as.numeric(m2$m1$p0), p0_resolved))) {
      stop("m2 must be fitted at the same quantile level as p0.", call. = FALSE)
    }
    m2_scores <- score_one(m2, draws2)
    ret$m2.check_loss <- m2_scores$check_loss
    ret$m2.CRPS <- m2_scores$CRPS
    ret$m2.pointwise <- m2_scores$pointwise
  }

  class(ret) <- "exdqlmForecastDiagnostic"
  invisible(ret)
}

#' \code{exdqlmForecastDiagnostic} objects
#'
#' \code{is.exdqlmForecastDiagnostic} tests if its argument is an
#' \code{exdqlmForecastDiagnostic} object.
#'
#' @usage is.exdqlmForecastDiagnostic(x)
#' @param x an \strong{R} object.
#' @export
is.exdqlmForecastDiagnostic <- function(x) {
  methods::is(x, "exdqlmForecastDiagnostic")
}

.exdqlm_forecast_diagnostic_table <- function(x) {
  m1 <- c(
    "check loss" = as.numeric(x$m1.check_loss),
    "CRPS" = as.numeric(x$m1.CRPS)
  )
  if (is.null(x$m2.check_loss)) {
    data.frame(Diagnostic = names(m1), M1 = unname(m1), check.names = FALSE)
  } else {
    m2 <- c(
      "check loss" = as.numeric(x$m2.check_loss),
      "CRPS" = as.numeric(x$m2.CRPS)
    )
    data.frame(Diagnostic = names(m1), M1 = unname(m1), M2 = unname(m2), check.names = FALSE)
  }
}

#' Print Method for \code{exdqlmForecastDiagnostic} Objects
#'
#' @param x An \code{exdqlmForecastDiagnostic} object.
#' @param ... Additional arguments (unused).
#' @export
print.exdqlmForecastDiagnostic <- function(x, ...) {
  cat("Held-out exDQLM forecast diagnostics\n")
  cat("Quantile level (p0):", x$p0, "\n")
  cat("Forecast horizon:", x$horizon, "\n")
  print(.exdqlm_forecast_diagnostic_table(x), row.names = FALSE, digits = 4)
  invisible(x)
}

#' Summary Method for \code{exdqlmForecastDiagnostic} Objects
#'
#' @param object An \code{exdqlmForecastDiagnostic} object.
#' @param ... Additional arguments (unused).
#' @export
summary.exdqlmForecastDiagnostic <- function(object, ...) {
  out <- .exdqlm_forecast_diagnostic_table(object)
  print(out, row.names = FALSE, digits = 4)
  invisible(out)
}

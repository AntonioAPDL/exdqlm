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

##########################################
### "exdqlmForecastDiagnostic" objects ###
##########################################
# included: is(), print(), summary()


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

#' Print Method for \code{exdqlmForecastDiagnostic} Objects
#'
#' @param x An \code{exdqlmForecastDiagnostic} object.
#' @param ... Additional arguments (unused).
#' @export
print.exdqlmForecastDiagnostic <- function(x, ...) {
  cat("Held-out exDQLM forecast diagnostics\n")
  cat("Class:", paste(class(x), collapse = ", "), "\n")
  cat("Quantile level (p0):", x$p0, "\n")
  cat("Forecast horizon:", x$horizon, "\n")
  cat("Models:", if (is.null(x$m1.class)) "M1" else x$m1.class)
  if (!is.null(x$m2.class)) cat(" vs ", x$m2.class, sep = "")
  cat("\n")
  print(.exdqlm_forecast_diagnostic_table(x), row.names = FALSE, digits = 4)
  cat("CRPS method:", x$crps.method, "\n")
  cat("Use with: summary()\n")
  invisible(x)
}

#' Summary Method for \code{exdqlmForecastDiagnostic} Objects
#'
#' @param object An \code{exdqlmForecastDiagnostic} object.
#' @param ... Additional arguments (unused).
#' @export
summary.exdqlmForecastDiagnostic <- function(object, ...) {
  out <- .exdqlm_forecast_diagnostic_table(object)
  cat("Held-out exDQLM forecast diagnostics summary\n")
  cat("Quantile level (p0):", object$p0, "\n")
  cat("Forecast horizon:", object$horizon, "\n")
  print(out, row.names = FALSE, digits = 4)
  invisible(out)
}
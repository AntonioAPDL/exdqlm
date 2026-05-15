ffv2_health_from_outputs <- function(config,
                                     fit_summary = NULL,
                                     forecast_summary = NULL,
                                     runtime_sec = NA_real_,
                                     error = NULL) {
  gate <- "PASS"
  notes <- character()
  if (!is.null(error)) {
    gate <- "FAIL"
    notes <- c(notes, conditionMessage(error))
  }
  if (!is.null(fit_summary)) {
    if (!all(is.finite(fit_summary$qhat)) || !all(is.finite(fit_summary$q_true))) {
      gate <- "FAIL"
      notes <- c(notes, "non-finite fit qhat or q_true")
    }
  }
  if (!is.null(forecast_summary)) {
    if (!all(is.finite(forecast_summary$qhat)) || !all(is.finite(forecast_summary$q_true))) {
      gate <- "FAIL"
      notes <- c(notes, "non-finite forecast qhat or q_true")
    }
    if ("horizon" %in% names(forecast_summary)) {
      if (max(as.integer(forecast_summary$horizon), na.rm = TRUE) < 1000L) {
        gate <- "FAIL"
        notes <- c(notes, "forecast summary does not cover H=1000")
      }
    }
  }
  if (is.finite(runtime_sec) && runtime_sec <= 0) {
    gate <- if (identical(gate, "PASS")) "WARN" else gate
    notes <- c(notes, "non-positive runtime")
  }
  data.frame(
    row_id = as.integer(config$row_id),
    row_key = as.character(config$row_key),
    run_tag = as.character(config$run_tag),
    gate = gate,
    runtime_sec = as.numeric(runtime_sec),
    fit_rows = if (is.null(fit_summary)) 0L else nrow(fit_summary),
    forecast_rows = if (is.null(forecast_summary)) 0L else nrow(forecast_summary),
    notes = paste(notes, collapse = "; "),
    stringsAsFactors = FALSE
  )
}

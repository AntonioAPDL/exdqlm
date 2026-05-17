ffv2_protocol_freeze_path <- function(harness_root = NULL) {
  if (is.null(harness_root)) harness_root <- ffv2_harness_root()
  file.path(harness_root, "protocol", "rolling_origin_v3_protocol_freeze.csv")
}

ffv2_required_protocol_freeze_columns <- function() {
  c(
    "ledger_id", "recorded_date", "protocol_id", "protocol_role", "run_tag",
    "model_scope", "status", "old_forecast_protocol", "new_forecast_protocol",
    "primary_hmax", "primary_origin_stride", "forecast_block_start_source_index",
    "forecast_block_end_source_index", "source_period", "source_harmonics",
    "article_consumption", "evidence_path", "notes"
  )
}

ffv2_validate_protocol_freeze <- function(x) {
  missing <- setdiff(ffv2_required_protocol_freeze_columns(), names(x))
  if (length(missing)) {
    stop(sprintf("Protocol freeze ledger missing column(s): %s", paste(missing, collapse = ", ")),
         call. = FALSE)
  }
  ffv2_stop_stale_paths(x)

  active <- x[as.character(x$protocol_role) == "active_protocol", , drop = FALSE]
  if (nrow(active) != 1L) {
    stop("Protocol freeze ledger must contain exactly one active_protocol row.", call. = FALSE)
  }
  if (!identical(as.character(active$new_forecast_protocol[[1L]]), "rolling_origin_no_refit_state_update")) {
    stop("Active protocol must be rolling_origin_no_refit_state_update.", call. = FALSE)
  }
  if (as.integer(active$primary_hmax[[1L]]) != 30L) {
    stop("Active protocol primary_hmax must be 30.", call. = FALSE)
  }
  if (as.integer(active$primary_origin_stride[[1L]]) != 30L) {
    stop("Active protocol primary_origin_stride must be 30.", call. = FALSE)
  }

  superseded <- x[as.character(x$protocol_role) == "superseded_run", , drop = FALSE]
  if (!nrow(superseded)) {
    stop("Protocol freeze ledger must list at least one superseded_run row.", call. = FALSE)
  }
  bad <- superseded[as.character(superseded$article_consumption) != "refuse", , drop = FALSE]
  if (nrow(bad)) {
    stop("Superseded protocol rows must set article_consumption to 'refuse'.", call. = FALSE)
  }
  invisible(TRUE)
}

ffv2_read_protocol_freeze <- function(path = ffv2_protocol_freeze_path()) {
  out <- ffv2_read_csv(path)
  ffv2_validate_protocol_freeze(out)
  out
}

ffv2_active_protocol <- function(path = ffv2_protocol_freeze_path()) {
  ledger <- ffv2_read_protocol_freeze(path)
  ledger[as.character(ledger$protocol_role) == "active_protocol", , drop = FALSE]
}

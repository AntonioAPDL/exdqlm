ffv2_required_progress_columns <- function() {
  c(
    "timestamp", "run_tag", "row_id", "row_key", "model_family",
    "model_variant", "inference_method", "fit_size_label", "tau",
    "stage", "substage", "event", "phase", "current_iter",
    "total_iter", "burn_iter", "burn_total", "keep_iter",
    "keep_total", "vb_iter", "vb_max_iter", "mcmc_iter",
    "mcmc_total_iter", "forecast_origin_current",
    "forecast_origin_total", "forecast_lead_current",
    "forecast_lead_total", "percent_complete", "elapsed_seconds",
    "eta_seconds", "pid", "host", "message"
  )
}

ffv2_required_heartbeat_fields <- function() {
  c(
    "timestamp", "run_tag", "row_id", "row_key", "status", "stage",
    "substage", "inference_method", "current_iter", "total_iter",
    "percent_complete", "elapsed_seconds", "eta_seconds", "pid",
    "host", "last_progress_message"
  )
}

ffv2_as_int1 <- function(x, default = NA_integer_) {
  if (is.null(x) || !length(x)) return(default)
  out <- suppressWarnings(as.integer(x[[1L]]))
  if (!is.finite(out)) default else out
}

ffv2_as_num1 <- function(x, default = NA_real_) {
  if (is.null(x) || !length(x)) return(default)
  out <- suppressWarnings(as.numeric(x[[1L]]))
  if (!is.finite(out)) default else out
}

ffv2_as_chr1 <- function(x, default = NA_character_) {
  if (is.null(x) || !length(x)) return(default)
  out <- as.character(x[[1L]])
  if (!length(out) || is.na(out) || !nzchar(out)) default else out
}

ffv2_as_lgl1 <- function(x, default = FALSE) {
  if (is.null(x) || !length(x)) return(default)
  if (is.logical(x)) return(isTRUE(x[[1L]]))
  tolower(as.character(x[[1L]])) %in% c("1", "true", "yes", "y", "on")
}

ffv2_runtime_controls <- function(config, overrides = NULL) {
  runtime <- (config$runtime %||% list())
  if (!is.null(overrides) && length(overrides)) {
    runtime <- utils::modifyList(runtime, overrides)
  }
  list(
    verbose = ffv2_as_lgl1(runtime$verbose, TRUE),
    log_level = ffv2_as_chr1(runtime$log_level, "info"),
    progress_every = max(1L, ffv2_as_int1(runtime$progress_every, 50L)),
    trace_every = max(1L, ffv2_as_int1(runtime$trace_every, 50L)),
    heartbeat_seconds = max(1L, ffv2_as_int1(runtime$heartbeat_seconds, 1800L)),
    healthcheck_stale_seconds = max(1L, ffv2_as_int1(runtime$healthcheck_stale_seconds, 1800L)),
    progress_retention_mode = ffv2_as_chr1(runtime$progress_retention_mode, "compact"),
    progress_retention_max_rows_per_unit = max(
      1L,
      ffv2_as_int1(runtime$progress_retention_max_rows_per_unit, 5000L)
    ),
    telemetry_sidecar = ffv2_as_lgl1(runtime$telemetry_sidecar, TRUE),
    telemetry_sidecar_poll_seconds = max(
      1L,
      ffv2_as_int1(runtime$telemetry_sidecar_poll_seconds, 5L)
    )
  )
}

ffv2_runtime_overrides_from_args <- function(args) {
  out <- list()
  if (!is.null(args$verbose)) out$verbose <- ffv2_truthy(args$verbose)
  if (!is.null(args$quiet)) out$verbose <- FALSE
  if (!is.null(args$`log-level`)) out$log_level <- as.character(args$`log-level`)[1L]
  if (!is.null(args$`progress-every`)) out$progress_every <- ffv2_as_int1(args$`progress-every`, 50L)
  if (!is.null(args$`trace-every`)) out$trace_every <- ffv2_as_int1(args$`trace-every`, 50L)
  if (!is.null(args$`heartbeat-seconds`)) {
    out$heartbeat_seconds <- ffv2_as_int1(args$`heartbeat-seconds`, 1800L)
  }
  if (!is.null(args$`healthcheck-stale-seconds`)) {
    out$healthcheck_stale_seconds <- ffv2_as_int1(args$`healthcheck-stale-seconds`, 1800L)
  }
  if (!is.null(args$`telemetry-sidecar-poll-seconds`)) {
    out$telemetry_sidecar_poll_seconds <- ffv2_as_int1(
      args$`telemetry-sidecar-poll-seconds`,
      5L
    )
  }
  out
}

ffv2_runtime_override_cli_args <- function(overrides) {
  if (is.null(overrides) || !length(overrides)) return(character(0))
  out <- character(0)
  add <- function(flag, value) {
    if (is.null(value) || !length(value) || is.na(value[[1L]])) return(invisible(NULL))
    out <<- c(out, flag, as.character(value[[1L]]))
    invisible(NULL)
  }
  if (!is.null(overrides$verbose)) {
    out <- c(out, if (isTRUE(overrides$verbose)) "--verbose" else "--quiet")
  }
  add("--log-level", overrides$log_level)
  add("--progress-every", overrides$progress_every)
  add("--trace-every", overrides$trace_every)
  add("--heartbeat-seconds", overrides$heartbeat_seconds)
  add("--healthcheck-stale-seconds", overrides$healthcheck_stale_seconds)
  add("--telemetry-sidecar-poll-seconds", overrides$telemetry_sidecar_poll_seconds)
  out
}

ffv2_apply_runtime_phase_defaults <- function(runtime, smoke = FALSE) {
  runtime <- runtime %||% list()
  base <- list(
    verbose = TRUE,
    log_level = "info",
    progress_every = 50L,
    trace_every = 50L,
    heartbeat_seconds = 1800L,
    healthcheck_stale_seconds = 1800L,
    progress_retention_mode = "compact",
    progress_retention_max_rows_per_unit = 5000L,
    telemetry_sidecar = TRUE,
    telemetry_sidecar_poll_seconds = 5L
  )
  if (isTRUE(smoke)) {
    base <- utils::modifyList(base, list(
      progress_every = 1L,
      trace_every = 1L,
      heartbeat_seconds = 30L,
      healthcheck_stale_seconds = 180L,
      progress_retention_mode = "dense",
      telemetry_sidecar_poll_seconds = 1L
    ))
  }
  utils::modifyList(base, runtime)
}

ffv2_progress_path <- function(config) {
  path <- config$row_progress_path %||% NULL
  if (!is.null(path) && nzchar(as.character(path)[1L])) return(as.character(path)[1L])
  if (is.null(config$row_status_path) || !nzchar(as.character(config$row_status_path)[1L])) {
    return(NA_character_)
  }
  file.path(dirname(config$row_status_path), sprintf("%s_progress.csv", config$row_key))
}

ffv2_heartbeat_path <- function(config) {
  path <- config$row_heartbeat_path %||% NULL
  if (!is.null(path) && nzchar(as.character(path)[1L])) return(as.character(path)[1L])
  if (is.null(config$row_status_path) || !nzchar(as.character(config$row_status_path)[1L])) {
    return(NA_character_)
  }
  file.path(dirname(config$row_status_path), sprintf("%s_heartbeat.json", config$row_key))
}

ffv2_progress_timestamp <- function(time = Sys.time()) {
  format(time, "%Y-%m-%d %H:%M:%S %Z")
}

ffv2_progress_percent <- function(current_iter, total_iter) {
  current_iter <- suppressWarnings(as.numeric(current_iter)[1L])
  total_iter <- suppressWarnings(as.numeric(total_iter)[1L])
  if (!is.finite(current_iter) || !is.finite(total_iter) || total_iter <= 0) return(NA_real_)
  round(100 * current_iter / total_iter, 4)
}

ffv2_progress_eta <- function(elapsed_seconds, current_iter, total_iter) {
  elapsed_seconds <- suppressWarnings(as.numeric(elapsed_seconds)[1L])
  current_iter <- suppressWarnings(as.numeric(current_iter)[1L])
  total_iter <- suppressWarnings(as.numeric(total_iter)[1L])
  if (!is.finite(elapsed_seconds) || !is.finite(current_iter) ||
      !is.finite(total_iter) || current_iter <= 0 || total_iter <= current_iter) {
    return(NA_real_)
  }
  rate <- elapsed_seconds / current_iter
  round(rate * (total_iter - current_iter), 3)
}

ffv2_progress_row <- function(config,
                              stage,
                              substage,
                              event,
                              phase = NA_character_,
                              current_iter = NA_integer_,
                              total_iter = NA_integer_,
                              burn_iter = NA_integer_,
                              burn_total = NA_integer_,
                              keep_iter = NA_integer_,
                              keep_total = NA_integer_,
                              vb_iter = NA_integer_,
                              vb_max_iter = NA_integer_,
                              mcmc_iter = NA_integer_,
                              mcmc_total_iter = NA_integer_,
                              forecast_origin_current = NA_integer_,
                              forecast_origin_total = NA_integer_,
                              forecast_lead_current = NA_integer_,
                              forecast_lead_total = NA_integer_,
                              percent_complete = NA_real_,
                              elapsed_seconds = NA_real_,
                              eta_seconds = NA_real_,
                              message = "",
                              timestamp = Sys.time()) {
  if (is.na(percent_complete)) {
    percent_complete <- ffv2_progress_percent(current_iter, total_iter)
  }
  if (is.na(eta_seconds)) {
    eta_seconds <- ffv2_progress_eta(elapsed_seconds, current_iter, total_iter)
  }
  row <- data.frame(
    timestamp = ffv2_progress_timestamp(timestamp),
    run_tag = ffv2_as_chr1(config$run_tag),
    row_id = ffv2_as_int1(config$row_id),
    row_key = ffv2_as_chr1(config$row_key),
    model_family = ffv2_as_chr1(config$model_family, "exdqlm_dqlm"),
    model_variant = ffv2_as_chr1(config$model_variant),
    inference_method = ffv2_as_chr1(config$inference),
    fit_size_label = ffv2_as_chr1(config$fit_size_label, as.character(config$fit_size %||% NA)),
    tau = ffv2_as_num1(config$tau),
    stage = as.character(stage)[1L],
    substage = as.character(substage)[1L],
    event = as.character(event)[1L],
    phase = as.character(phase)[1L],
    current_iter = ffv2_as_int1(current_iter),
    total_iter = ffv2_as_int1(total_iter),
    burn_iter = ffv2_as_int1(burn_iter),
    burn_total = ffv2_as_int1(burn_total),
    keep_iter = ffv2_as_int1(keep_iter),
    keep_total = ffv2_as_int1(keep_total),
    vb_iter = ffv2_as_int1(vb_iter),
    vb_max_iter = ffv2_as_int1(vb_max_iter),
    mcmc_iter = ffv2_as_int1(mcmc_iter),
    mcmc_total_iter = ffv2_as_int1(mcmc_total_iter),
    forecast_origin_current = ffv2_as_int1(forecast_origin_current),
    forecast_origin_total = ffv2_as_int1(forecast_origin_total),
    forecast_lead_current = ffv2_as_int1(forecast_lead_current),
    forecast_lead_total = ffv2_as_int1(forecast_lead_total),
    percent_complete = as.numeric(percent_complete),
    elapsed_seconds = as.numeric(elapsed_seconds),
    eta_seconds = as.numeric(eta_seconds),
    pid = as.integer(Sys.getpid()),
    host = as.character(Sys.info()[["nodename"]]),
    message = as.character(message)[1L],
    stringsAsFactors = FALSE
  )
  required <- ffv2_required_progress_columns()
  for (nm in setdiff(required, names(row))) row[[nm]] <- NA
  row[, required, drop = FALSE]
}

ffv2_validate_progress_schema <- function(x) {
  missing <- setdiff(ffv2_required_progress_columns(), names(x))
  if (length(missing)) {
    stop(sprintf("Progress schema missing column(s): %s", paste(missing, collapse = ", ")),
         call. = FALSE)
  }
  invisible(TRUE)
}

ffv2_validate_heartbeat_schema <- function(x) {
  missing <- setdiff(ffv2_required_heartbeat_fields(), names(x))
  if (length(missing)) {
    stop(sprintf("Heartbeat schema missing field(s): %s", paste(missing, collapse = ", ")),
         call. = FALSE)
  }
  invisible(TRUE)
}

ffv2_append_progress <- function(config, progress_row) {
  ffv2_validate_progress_schema(progress_row)
  path <- ffv2_progress_path(config)
  if (is.na(path) || !nzchar(path)) return(NA_character_)
  ffv2_ensure_dir(dirname(path))
  exists <- file.exists(path)
  utils::write.table(
    progress_row,
    path,
    sep = ",",
    row.names = FALSE,
    col.names = !exists,
    append = exists,
    na = "",
    qmethod = "double"
  )
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

ffv2_heartbeat_from_progress <- function(config,
                                         progress_row,
                                         status = "running",
                                         timestamp = Sys.time()) {
  hb <- list(
    timestamp = ffv2_progress_timestamp(timestamp),
    run_tag = ffv2_as_chr1(config$run_tag),
    row_id = ffv2_as_int1(config$row_id),
    row_key = ffv2_as_chr1(config$row_key),
    status = as.character(status)[1L],
    stage = ffv2_as_chr1(progress_row$stage),
    substage = ffv2_as_chr1(progress_row$substage),
    inference_method = ffv2_as_chr1(progress_row$inference_method, ffv2_as_chr1(config$inference)),
    current_iter = ffv2_as_int1(progress_row$current_iter),
    total_iter = ffv2_as_int1(progress_row$total_iter),
    percent_complete = ffv2_as_num1(progress_row$percent_complete),
    elapsed_seconds = ffv2_as_num1(progress_row$elapsed_seconds),
    eta_seconds = ffv2_as_num1(progress_row$eta_seconds),
    pid = as.integer(Sys.getpid()),
    host = as.character(Sys.info()[["nodename"]]),
    last_progress_message = ffv2_as_chr1(progress_row$message, "")
  )
  ffv2_validate_heartbeat_schema(hb)
  hb
}

ffv2_write_heartbeat <- function(config,
                                 progress_row,
                                 status = "running",
                                 timestamp = Sys.time()) {
  hb <- ffv2_heartbeat_from_progress(config, progress_row, status = status, timestamp = timestamp)
  path <- ffv2_heartbeat_path(config)
  if (is.na(path) || !nzchar(path)) return(NA_character_)
  ffv2_ensure_dir(dirname(path))
  tmp <- tempfile(pattern = paste0(basename(path), "."), tmpdir = dirname(path))
  ffv2_write_json(hb, tmp, pretty = TRUE)
  if (!file.rename(tmp, path)) {
    unlink(tmp)
    stop(sprintf("Failed to atomically write heartbeat: %s", path), call. = FALSE)
  }
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

ffv2_record_progress <- function(config,
                                 stage,
                                 substage,
                                 event,
                                 phase = NA_character_,
                                 current_iter = NA_integer_,
                                 total_iter = NA_integer_,
                                 burn_iter = NA_integer_,
                                 burn_total = NA_integer_,
                                 keep_iter = NA_integer_,
                                 keep_total = NA_integer_,
                                 vb_iter = NA_integer_,
                                 vb_max_iter = NA_integer_,
                                 mcmc_iter = NA_integer_,
                                 mcmc_total_iter = NA_integer_,
                                 forecast_origin_current = NA_integer_,
                                 forecast_origin_total = NA_integer_,
                                 forecast_lead_current = NA_integer_,
                                 forecast_lead_total = NA_integer_,
                                 percent_complete = NA_real_,
                                 elapsed_seconds = NA_real_,
                                 eta_seconds = NA_real_,
                                 message = "",
                                 status = "running",
                                 timestamp = Sys.time()) {
  row <- ffv2_progress_row(
    config = config,
    stage = stage,
    substage = substage,
    event = event,
    phase = phase,
    current_iter = current_iter,
    total_iter = total_iter,
    burn_iter = burn_iter,
    burn_total = burn_total,
    keep_iter = keep_iter,
    keep_total = keep_total,
    vb_iter = vb_iter,
    vb_max_iter = vb_max_iter,
    mcmc_iter = mcmc_iter,
    mcmc_total_iter = mcmc_total_iter,
    forecast_origin_current = forecast_origin_current,
    forecast_origin_total = forecast_origin_total,
    forecast_lead_current = forecast_lead_current,
    forecast_lead_total = forecast_lead_total,
    percent_complete = percent_complete,
    elapsed_seconds = elapsed_seconds,
    eta_seconds = eta_seconds,
    message = message,
    timestamp = timestamp
  )
  ffv2_append_progress(config, row)
  ffv2_write_heartbeat(config, row, status = status, timestamp = timestamp)
  invisible(row)
}

ffv2_touch_heartbeat <- function(config,
                                 status = "running",
                                 stage = "unknown",
                                 substage = "unknown",
                                 message = "heartbeat",
                                 timestamp = Sys.time()) {
  row <- ffv2_progress_row(
    config = config,
    stage = stage,
    substage = substage,
    event = "heartbeat",
    message = message,
    timestamp = timestamp
  )
  ffv2_write_heartbeat(config, row, status = status, timestamp = timestamp)
}

ffv2_read_progress <- function(path) {
  out <- ffv2_read_csv(path)
  ffv2_validate_progress_schema(out)
  out
}

ffv2_read_heartbeat <- function(path) {
  hb <- ffv2_read_json(path)
  hb_df <- as.data.frame(hb, stringsAsFactors = FALSE, optional = TRUE)
  ffv2_validate_heartbeat_schema(hb_df)
  hb_df
}

ffv2_parse_progress_key_values <- function(line) {
  parts <- strsplit(line, " *[|] *")[[1L]]
  label <- trimws(parts[[1L]])
  fields <- list()
  if (length(parts) > 1L) {
    for (item in parts[-1L]) {
      kv <- strsplit(item, "=", fixed = TRUE)[[1L]]
      if (length(kv) < 2L) next
      key <- trimws(kv[[1L]])
      val <- trimws(paste(kv[-1L], collapse = "="))
      fields[[key]] <- val
    }
  }
  list(label = label, fields = fields)
}

ffv2_parse_iter_pair <- function(x) {
  x <- as.character(x %||% NA_character_)[1L]
  if (is.na(x) || !nzchar(x)) return(c(current = NA_integer_, total = NA_integer_))
  if (grepl("/", x, fixed = TRUE)) {
    parts <- strsplit(x, "/", fixed = TRUE)[[1L]]
    return(c(
      current = ffv2_as_int1(parts[[1L]]),
      total = ffv2_as_int1(parts[[2L]])
    ))
  }
  c(current = ffv2_as_int1(x), total = NA_integer_)
}

ffv2_progress_row_from_log_line <- function(config,
                                            line,
                                            started_at = Sys.time(),
                                            vb_max_iter = NA_integer_,
                                            mcmc_total_iter = NA_integer_,
                                            timestamp = Sys.time()) {
  parsed <- ffv2_parse_progress_key_values(line)
  label <- parsed$label
  fields <- parsed$fields
  is_vb <- grepl("^LDVB", label)
  is_mcmc <- grepl("^MCMC", label)
  if (!is_vb && !is_mcmc) return(NULL)

  event <- if (grepl("start", label, ignore.case = TRUE)) {
    "start"
  } else if (grepl("done|complete", label, ignore.case = TRUE)) {
    "complete"
  } else {
    "progress"
  }
  elapsed <- ffv2_seconds(started_at, timestamp)
  if (is_vb) {
    iter <- ffv2_as_int1(fields$iter, if (identical(event, "start")) 0L else NA_integer_)
    total <- ffv2_as_int1(fields$max_iter, vb_max_iter)
    return(ffv2_progress_row(
      config = config,
      stage = "fit",
      substage = "vb",
      event = event,
      phase = "vb",
      current_iter = iter,
      total_iter = total,
      vb_iter = iter,
      vb_max_iter = total,
      elapsed_seconds = elapsed,
      message = line,
      timestamp = timestamp
    ))
  }

  iter_pair <- ffv2_parse_iter_pair(fields$iter)
  total <- if (is.na(iter_pair[["total"]])) {
    ffv2_as_int1(fields$total_iter, mcmc_total_iter)
  } else {
    iter_pair[["total"]]
  }
  burn_total <- ffv2_as_int1(fields$burn, fields$n_burn %||% NA_integer_)
  keep_total <- ffv2_as_int1(fields$keep, fields$n_mcmc %||% NA_integer_)
  current <- iter_pair[["current"]]
  phase <- ffv2_as_chr1(fields$phase, NA_character_)
  burn_iter <- if (is.finite(current) && is.finite(burn_total)) min(current, burn_total) else NA_integer_
  keep_iter <- if (is.finite(current) && is.finite(burn_total)) max(0L, current - burn_total) else NA_integer_
  ffv2_progress_row(
    config = config,
    stage = "fit",
    substage = "mcmc",
    event = event,
    phase = phase,
    current_iter = current,
    total_iter = total,
    burn_iter = burn_iter,
    burn_total = burn_total,
    keep_iter = keep_iter,
    keep_total = keep_total,
    mcmc_iter = current,
    mcmc_total_iter = total,
    elapsed_seconds = elapsed,
    message = line,
    timestamp = timestamp
  )
}

ffv2_parse_exdqlm_progress_lines <- function(config,
                                             lines,
                                             started_at = Sys.time(),
                                             vb_max_iter = NA_integer_,
                                             mcmc_total_iter = NA_integer_,
                                             parse_vb = TRUE,
                                             parse_mcmc = TRUE,
                                             timestamp = Sys.time()) {
  rows <- lapply(lines, function(line) {
    row <- ffv2_progress_row_from_log_line(
      config = config,
      line = line,
      started_at = started_at,
      vb_max_iter = vb_max_iter,
      mcmc_total_iter = mcmc_total_iter,
      timestamp = timestamp
    )
    if (is.null(row)) return(NULL)
    if (!isTRUE(parse_vb) && identical(row$substage[[1L]], "vb")) return(NULL)
    if (!isTRUE(parse_mcmc) && identical(row$substage[[1L]], "mcmc")) return(NULL)
    row
  })
  ffv2_bind_rows(rows)
}

ffv2_make_mcmc_progress_callback <- function(config, started_at = Sys.time()) {
  force(config)
  force(started_at)
  function(info) {
    iter <- ffv2_as_int1(info$iter, 0L)
    total <- ffv2_as_int1(info$total_iter, NA_integer_)
    burn_total <- ffv2_as_int1(info$n_burn, NA_integer_)
    keep_total <- ffv2_as_int1(info$n_mcmc, NA_integer_)
    burn_iter <- if (is.finite(iter) && is.finite(burn_total)) min(iter, burn_total) else NA_integer_
    keep_iter <- if (is.finite(iter) && is.finite(burn_total)) max(0L, iter - burn_total) else NA_integer_
    event <- ffv2_as_chr1(info$event, "progress")
    ffv2_record_progress(
      config = config,
      stage = "fit",
      substage = "mcmc",
      event = event,
      phase = ffv2_as_chr1(info$phase, NA_character_),
      current_iter = iter,
      total_iter = total,
      burn_iter = burn_iter,
      burn_total = burn_total,
      keep_iter = keep_iter,
      keep_total = keep_total,
      mcmc_iter = iter,
      mcmc_total_iter = total,
      elapsed_seconds = ffv2_seconds(started_at),
      message = sprintf("MCMC %s iter %s/%s", event, iter, total)
    )
    invisible(NULL)
  }
}

ffv2_start_log_telemetry_sidecar <- function(config,
                                             log_path = config$log_path,
                                             started_at = Sys.time(),
                                             vb_max_iter = NA_integer_,
                                             mcmc_total_iter = NA_integer_,
                                             parse_vb = TRUE,
                                             parse_mcmc = FALSE,
                                             poll_seconds = NULL) {
  runtime <- ffv2_runtime_controls(config)
  if (!isTRUE(runtime$telemetry_sidecar) || identical(.Platform$OS.type, "windows")) {
    return(list(active = FALSE))
  }
  if (is.null(log_path) || !length(log_path) || is.na(log_path[[1L]]) ||
      !nzchar(as.character(log_path[[1L]])) ||
      is.na(ffv2_progress_path(config)) || is.na(ffv2_heartbeat_path(config))) {
    return(list(active = FALSE))
  }
  if (is.null(poll_seconds)) poll_seconds <- runtime$telemetry_sidecar_poll_seconds
  stop_path <- tempfile("ffv2_telemetry_stop_", tmpdir = dirname(ffv2_heartbeat_path(config)))
  ffv2_ensure_dir(dirname(stop_path))
  job <- parallel::mcparallel({
    last_n <- 0L
    last_touch <- Sys.time()
    repeat {
      now <- Sys.time()
      if (file.exists(log_path)) {
        lines <- tryCatch(readLines(log_path, warn = FALSE), error = function(e) character(0))
        if (length(lines) > last_n) {
          new_lines <- lines[seq.int(last_n + 1L, length(lines))]
          parsed <- ffv2_parse_exdqlm_progress_lines(
            config = config,
            lines = new_lines,
            started_at = started_at,
            vb_max_iter = vb_max_iter,
            mcmc_total_iter = mcmc_total_iter,
            parse_vb = parse_vb,
            parse_mcmc = parse_mcmc,
            timestamp = now
          )
          if (nrow(parsed)) {
            for (i in seq_len(nrow(parsed))) {
              ffv2_append_progress(config, parsed[i, , drop = FALSE])
              ffv2_write_heartbeat(config, parsed[i, , drop = FALSE], status = "running", timestamp = now)
            }
            last_touch <- now
          }
          last_n <- length(lines)
        }
      }
      if (as.numeric(difftime(now, last_touch, units = "secs")) >= runtime$heartbeat_seconds) {
        ffv2_touch_heartbeat(
          config,
          status = "running",
          stage = "fit",
          substage = if (isTRUE(parse_vb)) "vb" else "mcmc",
          message = "telemetry sidecar heartbeat",
          timestamp = now
        )
        last_touch <- now
      }
      if (file.exists(stop_path)) break
      Sys.sleep(poll_seconds)
    }
    invisible(TRUE)
  }, silent = TRUE)
  list(active = TRUE, job = job, stop_path = stop_path)
}

ffv2_stop_log_telemetry_sidecar <- function(sidecar, timeout = 5) {
  if (is.null(sidecar) || !isTRUE(sidecar$active)) return(invisible(FALSE))
  writeLines("stop", sidecar$stop_path)
  out <- tryCatch(parallel::mccollect(sidecar$job, wait = TRUE, timeout = timeout),
                  error = function(e) NULL)
  if (is.null(out)) {
    pid <- tryCatch(sidecar$job$pid, error = function(e) NA_integer_)
    if (is.finite(pid)) tools::pskill(pid, tools::SIGTERM)
  }
  unlink(sidecar$stop_path)
  invisible(TRUE)
}

ffv2_start_row_log_sink <- function(config, runtime = ffv2_runtime_controls(config)) {
  log_path <- config$log_path %||% NA_character_
  if (is.na(log_path) || !nzchar(as.character(log_path)[1L])) {
    return(list(active = FALSE))
  }
  ffv2_ensure_dir(dirname(log_path))
  out_con <- file(log_path, open = "at")
  msg_con <- file(log_path, open = "at")
  sink(out_con, split = isTRUE(runtime$verbose))
  sink(msg_con, type = "message")
  cat(sprintf("\n--- row log opened %s ---\n", ffv2_progress_timestamp()))
  list(active = TRUE, out_con = out_con, msg_con = msg_con)
}

ffv2_stop_row_log_sink <- function(sink_state) {
  if (is.null(sink_state) || !isTRUE(sink_state$active)) return(invisible(FALSE))
  try(cat(sprintf("--- row log closed %s ---\n", ffv2_progress_timestamp())), silent = TRUE)
  try(if (sink.number(type = "message") > 0L) sink(type = "message"), silent = TRUE)
  try(if (sink.number() > 0L) sink(), silent = TRUE)
  try(close(sink_state$msg_con), silent = TRUE)
  try(close(sink_state$out_con), silent = TRUE)
  invisible(TRUE)
}

ffv2_last_status <- function(status_path) {
  if (!file.exists(status_path)) return("pending")
  st <- tryCatch(ffv2_read_csv(status_path), error = function(e) NULL)
  if (is.null(st) || !nrow(st) || !"status" %in% names(st)) return("unknown")
  as.character(tail(st$status, 1L))
}

ffv2_parse_telemetry_time <- function(x) {
  if (is.null(x) || !length(x) || is.na(x[[1L]]) || !nzchar(as.character(x[[1L]]))) {
    return(as.POSIXct(NA_real_, origin = "1970-01-01", tz = Sys.timezone()))
  }
  raw <- as.character(x[[1L]])
  if (grepl(" UTC$", raw)) {
    return(as.POSIXct(sub(" UTC$", "", raw), tz = "UTC"))
  }
  if (grepl(" GMT$", raw)) {
    return(as.POSIXct(sub(" GMT$", "", raw), tz = "GMT"))
  }
  as.POSIXct(raw, tz = Sys.timezone())
}

ffv2_row_telemetry_summary <- function(manifest_row,
                                       now = Sys.time(),
                                       stale_seconds = 1800L) {
  status <- ffv2_last_status(manifest_row$row_status_path[[1L]])
  heartbeat_path <- if ("row_heartbeat_path" %in% names(manifest_row)) {
    manifest_row$row_heartbeat_path[[1L]]
  } else {
    file.path(dirname(manifest_row$row_status_path[[1L]]), sprintf("%s_heartbeat.json", manifest_row$row_key[[1L]]))
  }
  hb <- if (file.exists(heartbeat_path)) {
    tryCatch(ffv2_read_heartbeat(heartbeat_path), error = function(e) NULL)
  } else {
    NULL
  }
  hb_time <- if (!is.null(hb)) ffv2_parse_telemetry_time(hb$timestamp) else as.POSIXct(NA_real_, origin = "1970-01-01")
  hb_age <- if (is.na(hb_time)) NA_real_ else as.numeric(difftime(now, hb_time, units = "secs"))
  stale <- isTRUE(is.finite(hb_age) && hb_age > stale_seconds)
  state <- if (status %in% c("done", "success")) {
    "completed"
  } else if (status %in% c("failed_interrupted", "aborted_protocol_superseded")) {
    "interrupted"
  } else if (startsWith(status, "failed")) {
    "failed"
  } else if (identical(status, "running") && is.null(hb)) {
    "interrupted"
  } else if (identical(status, "running") && stale) {
    "stalled"
  } else if (identical(status, "running")) {
    "progressing"
  } else {
    status
  }
  data.frame(
    row_id = ffv2_as_int1(manifest_row$row_id),
    row_key = ffv2_as_chr1(manifest_row$row_key),
    run_tag = ffv2_as_chr1(manifest_row$run_tag),
    model_variant = ffv2_as_chr1(manifest_row$model_variant),
    inference = ffv2_as_chr1(manifest_row$inference),
    fit_size = ffv2_as_int1(manifest_row$fit_size),
    family = ffv2_as_chr1(manifest_row$family),
    tau = ffv2_as_num1(manifest_row$tau),
    status = status,
    telemetry_state = state,
    stage = if (is.null(hb)) NA_character_ else ffv2_as_chr1(hb$stage),
    substage = if (is.null(hb)) NA_character_ else ffv2_as_chr1(hb$substage),
    current_iter = if (is.null(hb)) NA_integer_ else ffv2_as_int1(hb$current_iter),
    total_iter = if (is.null(hb)) NA_integer_ else ffv2_as_int1(hb$total_iter),
    percent_complete = if (is.null(hb)) NA_real_ else ffv2_as_num1(hb$percent_complete),
    last_heartbeat_at = if (is.null(hb)) NA_character_ else ffv2_as_chr1(hb$timestamp),
    heartbeat_age_seconds = as.numeric(hb_age),
    stale = stale,
    message = if (is.null(hb)) NA_character_ else ffv2_as_chr1(hb$last_progress_message),
    row_progress_path = if ("row_progress_path" %in% names(manifest_row)) {
      manifest_row$row_progress_path[[1L]]
    } else {
      NA_character_
    },
    row_heartbeat_path = heartbeat_path,
    stringsAsFactors = FALSE
  )
}

ffv2_telemetry_summary <- function(manifest,
                                   now = Sys.time(),
                                   stale_seconds = NULL) {
  if (is.null(stale_seconds)) {
    stale_seconds <- 1800L
    if ("runtime" %in% names(manifest)) stale_seconds <- 1800L
  }
  rows <- lapply(seq_len(nrow(manifest)), function(i) {
    ffv2_row_telemetry_summary(manifest[i, , drop = FALSE], now = now, stale_seconds = stale_seconds)
  })
  ffv2_bind_rows(rows)
}

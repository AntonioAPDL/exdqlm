#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/healthcheck_independent_mean_readout_state_forecast_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
state_root <- normalizePath(args$`state-root` %||% "", winslash = "/",
                            mustWork = TRUE)
fit_plan <- ffv2_read_csv(file.path(state_root, "manifests", "fit_plan.csv"))
forecast_plan <- ffv2_read_csv(
  file.path(state_root, "manifests", "forecast_plan.csv")
)
fit_plan$is_canary <- as.logical(fit_plan$is_canary)
forecast_plan$is_canary <- as.logical(forecast_plan$is_canary)

pid_alive <- function(pid) {
  pid <- suppressWarnings(as.integer(pid)[1L])
  is.finite(pid) && dir.exists(file.path("/proc", pid))
}

read_status <- function(stage, id, expected_sha) {
  path <- imrs_v1_status_path(state_root, stage, id)
  if (!file.exists(path)) {
    return(list(status = "PLANNED", pid = NA_integer_, elapsed_seconds = NA_real_,
                request_match = NA, stale = FALSE, error_message = ""))
  }
  x <- tryCatch(imrs_v1_read_json(path), error = function(e) {
    list(status = "CORRUPT", error_message = conditionMessage(e))
  })
  status <- as.character(x$status %||% "CORRUPT")[[1L]]
  request_match <- identical(
    as.character(x$request_sha256 %||% ""), as.character(expected_sha)
  )
  stale <- identical(status, "RUNNING") && !pid_alive(x$pid %||% NA_integer_)
  if (stale) status <- "STALE_RUNNING"
  list(
    status = status, pid = as.integer(x$pid %||% NA_integer_),
    elapsed_seconds = as.numeric(x$elapsed_seconds %||% NA_real_),
    request_match = request_match, stale = stale,
    error_message = as.character(x$error_message %||% "")
  )
}

fit_rows <- lapply(seq_len(nrow(fit_plan)), function(i) {
  row <- fit_plan[i, , drop = FALSE]
  x <- read_status("fit", row$job_id[[1L]], row$config_sha256[[1L]])
  data.frame(
    stage = "fit", job_id = row$job_id[[1L]], source_id = row$source_id[[1L]],
    inference = row$inference[[1L]],
    is_canary = isTRUE(as.logical(row$is_canary[[1L]])),
    status = x$status, pid = x$pid, elapsed_seconds = x$elapsed_seconds,
    request_match = x$request_match, stale = x$stale,
    error_message = x$error_message, stringsAsFactors = FALSE
  )
})
forecast_rows <- lapply(seq_len(nrow(forecast_plan)), function(i) {
  row <- forecast_plan[i, , drop = FALSE]
  x <- read_status(
    "forecast", row$forecast_id[[1L]], row$config_sha256[[1L]]
  )
  deps <- imrs_v1_split_ids(row$fit_job_ids[[1L]])
  dep_done <- all(vapply(deps, function(id) {
    match_row <- fit_plan[fit_plan$job_id == id, , drop = FALSE]
    nrow(match_row) == 1L && imrs_v1_status_success(
      state_root, "fit", id, match_row$config_sha256[[1L]]
    )
  }, logical(1L)))
  data.frame(
    stage = "forecast", job_id = row$forecast_id[[1L]],
    source_id = row$source_id[[1L]], inference = row$inference[[1L]],
    is_canary = isTRUE(as.logical(row$is_canary[[1L]])),
    status = x$status, pid = x$pid,
    elapsed_seconds = x$elapsed_seconds, request_match = x$request_match,
    stale = x$stale, dependency_ready = dep_done,
    error_message = x$error_message, stringsAsFactors = FALSE
  )
})
jobs <- ffv2_bind_rows(c(fit_rows, forecast_rows))
jobs$request_match[is.na(jobs$request_match) & jobs$status == "PLANNED"] <- TRUE

summary_count <- function(stage, status) {
  sum(jobs$stage == stage & jobs$status == status)
}
terminal_success <- jobs$status == "SUCCESS" & jobs$request_match
failed <- jobs$status %in% c("FAILED", "CORRUPT", "STALE_RUNNING") |
  (!jobs$request_match & jobs$status != "PLANNED")
running <- jobs$status == "RUNNING"
remaining <- !terminal_success & !failed
elapsed_fit <- jobs$elapsed_seconds[jobs$stage == "fit" & terminal_success]
elapsed_forecast <- jobs$elapsed_seconds[jobs$stage == "forecast" & terminal_success]
median_or_na <- function(x) {
  x <- x[is.finite(x)]
  if (length(x)) stats::median(x) else NA_real_
}
eta_seconds <- sum(c(
  sum(jobs$stage == "fit" & remaining) * median_or_na(elapsed_fit),
  sum(jobs$stage == "forecast" & remaining) * median_or_na(elapsed_forecast)
), na.rm = TRUE) / imrs_v1_workers
if (!is.finite(eta_seconds) || eta_seconds == 0) eta_seconds <- NA_real_

heavy <- list.files(
  state_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
  full.names = TRUE, ignore.case = TRUE
)
disk_bytes <- sum(file.info(list.files(
  state_root, recursive = TRUE, full.names = TRUE, all.files = TRUE
))$size, na.rm = TRUE)

health <- list(
  schema_version = imrs_v1_schema,
  checked_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  state_root = state_root,
  workers_max = imrs_v1_workers,
  active_workers = sum(running),
  planned_total = nrow(jobs),
  completed_total = sum(terminal_success),
  failed_total = sum(failed),
  running_total = sum(running),
  remaining_total = sum(remaining),
  fit = list(
    planned = nrow(fit_plan), completed = summary_count("fit", "SUCCESS"),
    running = summary_count("fit", "RUNNING"),
    failed = sum(failed & jobs$stage == "fit"),
    remaining = sum(remaining & jobs$stage == "fit")
  ),
  forecast = list(
    planned = nrow(forecast_plan),
    completed = summary_count("forecast", "SUCCESS"),
    running = summary_count("forecast", "RUNNING"),
    failed = sum(failed & jobs$stage == "forecast"),
    remaining = sum(remaining & jobs$stage == "forecast"),
    ready = sum(
      jobs$stage == "forecast" & jobs$status == "PLANNED" &
        jobs$dependency_ready %in% TRUE
    ),
    dependency_blocked = sum(
      jobs$stage == "forecast" & jobs$status == "PLANNED" &
        !(jobs$dependency_ready %in% TRUE)
    )
  ),
  canary = list(
    planned = sum(jobs$is_canary),
    completed = sum(terminal_success & jobs$is_canary),
    failed = sum(failed & jobs$is_canary)
  ),
  estimated_remaining_seconds = eta_seconds,
  disk_bytes = disk_bytes,
  heavy_binary_files = length(heavy),
  heavy_binary_bytes = sum(file.info(heavy)$size, na.rm = TRUE),
  all_complete = all(terminal_success),
  healthy = !any(failed) && !any(jobs$stale)
)

dir.create(file.path(state_root, "health"), recursive = TRUE, showWarnings = FALSE)
imrs_v1_atomic_write_csv(jobs, file.path(state_root, "health", "health_jobs.csv"))
imrs_v1_atomic_write_json(
  health, file.path(state_root, "health", "health_current.json")
)
cat(sprintf(
  paste0(
    "stage       done  running  failed  remaining\n",
    "fit         %3d   %3d      %3d     %3d\n",
    "forecast    %3d   %3d      %3d     %3d\n",
    "total       %3d   %3d      %3d     %3d\n",
    "canary      %3d/%3d complete; active workers %d/%d; heavy %.2f GiB\n"
  ),
  health$fit$completed, health$fit$running, health$fit$failed,
  health$fit$remaining, health$forecast$completed, health$forecast$running,
  health$forecast$failed, health$forecast$remaining,
  health$completed_total, health$running_total, health$failed_total,
  health$remaining_total, health$canary$completed, health$canary$planned,
  health$active_workers, health$workers_max,
  health$heavy_binary_bytes / 1024^3
))
quit(save = "no", status = if (isTRUE(health$healthy)) 0L else 1L)

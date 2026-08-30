#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/healthcheck_independent_exdqlm_mcmc_rolling_state_fix_v1_full.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/",
                           mustWork = TRUE)
manifest_path <- normalizePath(args$manifest %||% "", winslash = "/", mustWork = TRUE)
manifest <- ffv2_read_csv(manifest_path)
iems_v1_validate_launcher_manifest(manifest)
run_root <- dirname(dirname(manifest_path))
run_id <- basename(run_root)
state_root <- file.path(repo_root, "reports", "shared_fitforecast_v2_orchestration", run_id)

last_row <- function(path) {
  path <- as.character(path %||% "")[1L]
  if (!nzchar(path) || !file.exists(path)) return(NULL)
  out <- tryCatch(ffv2_read_csv(path), error = function(...) NULL)
  if (is.null(out) || !nrow(out)) NULL else out[nrow(out), , drop = FALSE]
}
scalar <- function(x, fallback = NA) {
  if (is.null(x) || !length(x) || is.na(x[[1L]])) fallback else x[[1L]]
}

rows <- lapply(seq_len(nrow(manifest)), function(i) {
  config <- ffv2_read_json(manifest$row_config_path[[i]])
  status <- last_row(config$row_status_path)
  progress <- last_row(config$row_progress_path)
  final_status <- tolower(as.character(scalar(status$status, "")))
  state <- if (final_status == "done") {
    "completed"
  } else if (final_status == "failed") {
    "failed"
  } else if (!is.null(progress)) {
    "running"
  } else {
    "pending"
  }
  pid <- suppressWarnings(as.integer(scalar(progress$pid, NA_integer_)))
  pid_active <- is.finite(pid) && file.exists(file.path("/proc", as.character(pid)))
  data.frame(
    source_job_id = as.character(manifest$source_job_id[[i]]),
    family = as.character(manifest$family[[i]]),
    tau = as.numeric(manifest$tau[[i]]),
    chain_id = as.integer(manifest$chain_id[[i]]),
    state = state,
    stage = as.character(scalar(progress$stage, if (state == "completed") "complete" else "")),
    substage = as.character(scalar(progress$substage, "")),
    percent_complete = suppressWarnings(as.numeric(scalar(
      progress$percent_complete, if (state == "completed") 100 else NA_real_
    ))),
    pid = pid,
    pid_active = pid_active,
    health_gate = as.character(scalar(status$health_gate, "")),
    metrics_present = file.exists(config$row_metrics_path),
    intervals_present = file.exists(config$metric_interval_summary_path),
    error_message = as.character(scalar(status$error_message, "")),
    stringsAsFactors = FALSE
  )
})
health <- ffv2_bind_rows(rows)

pipeline_status_path <- file.path(state_root, "pipeline.status")
pipeline_status <- if (file.exists(pipeline_status_path)) {
  paste(readLines(pipeline_status_path, warn = FALSE), collapse = " ")
} else {
  "status=NOT_STARTED"
}
heavy <- if (dir.exists(run_root)) {
  list.files(
    run_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
    full.names = TRUE, ignore.case = TRUE
  )
} else character(0)
summary <- data.frame(
  run_id = run_id,
  planned = nrow(health),
  completed = sum(health$state == "completed"),
  running = sum(health$state == "running" & health$pid_active),
  stale_running = sum(health$state == "running" & !health$pid_active),
  pending = sum(health$state == "pending"),
  failed = sum(health$state == "failed"),
  remaining = sum(health$state != "completed"),
  metrics_present = sum(health$metrics_present),
  intervals_present = sum(health$intervals_present),
  heavy_binary_files = length(heavy),
  pipeline_status = pipeline_status,
  stringsAsFactors = FALSE
)

output_root <- as.character(args$`output-root` %||% "")[1L]
if (nzchar(output_root)) {
  output_root <- ffv2_resolve_path(output_root, repo_root = repo_root, must_work = FALSE)
  ffv2_ensure_dir(output_root)
  ffv2_write_csv(health, file.path(output_root, "row_health_snapshot.csv"))
  ffv2_write_json(
    list(
      schema_version = iems_v1_schema,
      generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
      summary = as.list(summary[1L, , drop = FALSE]),
      manifest_path = manifest_path,
      manifest_sha256 = ffv2_file_sha256(manifest_path),
      active_job_pids = as.integer(health$pid[health$pid_active]),
      heavy_binary_paths = heavy,
      article_write_performed = FALSE
    ),
    file.path(output_root, "health_snapshot.json")
  )
}

print(summary, row.names = FALSE)
print(health, row.names = FALSE)
if (summary$failed > 0L || summary$stale_running > 0L) quit(status = 2L)

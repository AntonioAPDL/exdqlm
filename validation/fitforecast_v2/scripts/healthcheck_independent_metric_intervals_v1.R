#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/healthcheck_independent_metric_intervals_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- ffv2_repo_root()
state_root <- args$`state-root` %||% ""
if (!nzchar(state_root)) {
  candidates <- list.dirs(file.path(repo_root, "reports", "shared_fitforecast_v2_orchestration"),
                          full.names = TRUE, recursive = FALSE)
  candidates <- candidates[grepl("independent_metric_intervals_v1", basename(candidates)) &
                             file.exists(file.path(candidates, "manifests", "job_plan.csv"))]
  if (!length(candidates)) stop("No independent metric-interval campaign was found.", call. = FALSE)
  state_root <- candidates[[which.max(file.info(candidates)$mtime)]]
}
state_root <- normalizePath(state_root, winslash = "/", mustWork = TRUE)
plan_path <- file.path(state_root, "manifests", "job_plan.csv")
plan <- ffv2_read_csv(plan_path)
materialization_path <- file.path(state_root, "manifests", "materialization_manifest.json")
campaign_schema <- if (file.exists(materialization_path)) {
  as.character(ffv2_read_json(materialization_path)$schema_version %||% imi_v1_schema)[1L]
} else imi_v1_schema

pid_alive <- function(pid) {
  pid <- suppressWarnings(as.integer(pid)[1L])
  if (!is.finite(pid) || pid < 1L) return(FALSE)
  identical(system2("kill", c("-0", pid), stdout = FALSE, stderr = FALSE), 0L)
}

status_rows <- lapply(seq_len(nrow(plan)), function(i) {
  row <- plan[i, , drop = FALSE]
  path <- file.path(state_root, "status", paste0(row$job_id[[1L]], ".json"))
  payload <- if (file.exists(path)) tryCatch(ffv2_read_json(path), error = function(...) NULL) else NULL
  raw_status <- toupper(as.character((payload %||% list())$status %||% "PENDING"))[1L]
  alive <- if (raw_status == "RUNNING") pid_alive((payload %||% list())$pid) else FALSE
  status <- if (raw_status == "RUNNING" && !alive) "STALE" else raw_status
  cfg <- ffv2_read_json(row$config_path[[1L]])
  progress_current <- NA_integer_
  progress_target <- NA_integer_
  progress_phase <- ""
  if (row$engine[[1L]] == "qdesn") {
    progress_path <- file.path(row$job_root[[1L]], "progress_trace.csv")
    method <- as.character(row$inference[[1L]])
    if (method == "mcmc") {
      progress_target <- as.integer(cfg$config$inference$mcmc$n_mcmc)
      progress_phase <- "retained_mcmc"
    } else {
      progress_target <- as.integer(cfg$config$inference$vb$max_iter)
      progress_phase <- "vb"
    }
    if (file.exists(progress_path)) {
      p <- tryCatch(ffv2_read_csv(progress_path), error = function(...) data.frame())
      values <- suppressWarnings(as.integer(p$step %||% integer(0)))
      values <- values[is.finite(values)]
      if (length(values)) progress_current <- max(values)
    }
  } else {
    progress_path <- as.character(cfg$row_progress_path %||% "")
    if (row$inference[[1L]] == "mcmc") {
      progress_target <- as.integer(cfg$budget$mcmc$n_burn) + as.integer(cfg$budget$mcmc$n_mcmc)
      progress_phase <- "mcmc_total"
    } else {
      progress_target <- as.integer(cfg$budget$vb$max_iter)
      progress_phase <- "vb"
    }
    if (nzchar(progress_path) && file.exists(progress_path)) {
      p <- tryCatch(ffv2_read_csv(progress_path), error = function(...) data.frame())
      candidates <- if (row$inference[[1L]] == "mcmc") {
        suppressWarnings(as.integer(p$mcmc_iter %||% p$current_iter %||% integer(0)))
      } else suppressWarnings(as.integer(p$vb_iter %||% p$current_iter %||% integer(0)))
      candidates <- candidates[is.finite(candidates)]
      if (length(candidates)) progress_current <- max(candidates)
    }
  }
  if (status == "SUCCESS") progress_current <- progress_target
  data.frame(
    job_id = row$job_id[[1L]], engine = row$engine[[1L]],
    inference = row$inference[[1L]], model_variant = row$model_variant[[1L]],
    family = row$family[[1L]], tau = row$tau[[1L]], chain_id = row$chain_id[[1L]],
    status = status, pid = as.integer((payload %||% list())$pid %||% NA_integer_),
    pid_alive = alive,
    elapsed_seconds = as.numeric((payload %||% list())$elapsed_seconds %||% NA_real_),
    metric_draws = as.integer((payload %||% list())$metric_draws %||% NA_integer_),
    expected_draws = as.integer(row$expected_draws[[1L]]),
    progress_phase = progress_phase, iteration_current = progress_current,
    iteration_target = progress_target,
    iteration_pct = if (is.finite(progress_current) && is.finite(progress_target) && progress_target > 0)
      round(100 * progress_current / progress_target, 1) else NA_real_,
    error_message = as.character((payload %||% list())$error_message %||% ""),
    status_path = path,
    status_mtime = if (file.exists(path)) format(file.info(path)$mtime, "%Y-%m-%d %H:%M:%S %Z") else "",
    stringsAsFactors = FALSE
  )
})
detail <- do.call(rbind, status_rows)
groups <- split(detail, paste(detail$engine, detail$inference, sep = "\r"))
summary <- do.call(rbind, lapply(groups, function(x) data.frame(
  engine = x$engine[[1L]], inference = x$inference[[1L]], planned = nrow(x),
  completed = sum(x$status == "SUCCESS"), running = sum(x$status == "RUNNING"),
  failed = sum(x$status == "FAIL"), stale = sum(x$status == "STALE"),
  pending = sum(x$status == "PENDING"),
  remaining = sum(x$status != "SUCCESS"),
  completion_pct = round(100 * mean(x$status == "SUCCESS"), 1),
  stringsAsFactors = FALSE
)))
summary <- summary[order(summary$engine, summary$inference), , drop = FALSE]

result_roots <- unique(normalizePath(plan$job_root, winslash = "/", mustWork = FALSE))
result_roots <- result_roots[dir.exists(result_roots)]
heavy <- unique(unlist(lapply(result_roots, function(root) {
  list.files(root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
             full.names = TRUE, ignore.case = TRUE)
}), use.names = FALSE))
heavy_bytes <- if (length(heavy)) sum(as.numeric(file.info(heavy)$size), na.rm = TRUE) else 0

health_root <- file.path(state_root, "health")
ffv2_ensure_dir(health_root)
ffv2_write_csv(detail, file.path(health_root, "job_health_current.csv"))
ffv2_write_csv(summary, file.path(health_root, "summary_current.csv"))
payload <- list(
  schema_version = campaign_schema,
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  state_root = state_root, planned = nrow(detail),
  completed = sum(detail$status == "SUCCESS"),
  running = sum(detail$status == "RUNNING"), failed = sum(detail$status == "FAIL"),
  stale = sum(detail$status == "STALE"), pending = sum(detail$status == "PENDING"),
  remaining = sum(detail$status != "SUCCESS"),
  completion_pct = round(100 * mean(detail$status == "SUCCESS"), 2),
  active_worker_pids = as.integer(detail$pid[detail$status == "RUNNING"]),
  heavy_binary_count = length(heavy), heavy_binary_bytes = heavy_bytes,
  all_complete = all(detail$status == "SUCCESS"),
  healthy_to_wait = !any(detail$status %in% c("FAIL", "STALE")) &&
    any(detail$status %in% c("RUNNING", "PENDING"))
)
ffv2_write_json(payload, file.path(health_root, "health_current.json"))
cat(sprintf("state_root=%s planned=%d completed=%d running=%d failed=%d stale=%d pending=%d remaining=%d completion=%.2f%% heavy=%d (%.3f GiB)\n",
            state_root, payload$planned, payload$completed, payload$running, payload$failed,
            payload$stale, payload$pending, payload$remaining, payload$completion_pct,
            payload$heavy_binary_count, payload$heavy_binary_bytes / 1024^3))
print(summary, row.names = FALSE)
if (any(detail$status %in% c("FAIL", "STALE"))) {
  cat("\nFailed/stale jobs:\n")
  print(detail[detail$status %in% c("FAIL", "STALE"),
               c("job_id", "status", "error_message")], row.names = FALSE)
}

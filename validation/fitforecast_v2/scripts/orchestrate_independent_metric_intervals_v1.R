#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/orchestrate_independent_metric_intervals_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/", mustWork = TRUE)
state_root <- normalizePath(args$`state-root` %||% "", winslash = "/", mustWork = TRUE)
workers <- as.integer(args$workers %||% imi_v1_workers)[1L]
if (!is.finite(workers) || workers < 1L || workers > imi_v1_workers) {
  stop(sprintf("--workers must be between 1 and %d.", imi_v1_workers), call. = FALSE)
}
approved <- ffv2_truthy(args$approved %||% Sys.getenv("IMI_V1_LAUNCH_APPROVED", "false"))
if (!approved) {
  stop("Refusing to launch without IMI_V1_LAUNCH_APPROVED=true or --approved true.",
       call. = FALSE)
}

plan_path <- file.path(state_root, "manifests", "job_plan.csv")
materialization_path <- file.path(state_root, "manifests", "materialization_manifest.json")
plan <- ffv2_read_csv(plan_path)
materialization <- ffv2_read_json(materialization_path)
if (!nrow(plan) || anyDuplicated(plan$job_id)) stop("Job plan is empty or duplicated.", call. = FALSE)
observed_hashes <- vapply(plan$config_path, ffv2_file_sha256, character(1L))
if (any(observed_hashes != plan$config_sha256)) {
  stop("One or more materialized job configurations changed after planning.", call. = FALSE)
}

mem_available_kib <- function() {
  lines <- readLines("/proc/meminfo", warn = FALSE)
  line <- lines[grepl("^MemAvailable:", lines)]
  if (!length(line)) return(NA_real_)
  as.numeric(gsub("[^0-9]", "", line[[1L]]))
}

disk_available_kib <- function(path) {
  out <- system2("df", c("-Pk", shQuote(path)), stdout = TRUE, stderr = TRUE)
  fields <- strsplit(trimws(tail(out, 1L)), "[[:space:]]+")[[1L]]
  suppressWarnings(as.numeric(fields[[4L]]))
}

resource_gate <- function(wave) {
  cores <- parallel::detectCores(logical = TRUE)
  mem_kib <- mem_available_kib()
  disk_kib <- disk_available_kib(state_root)
  checks <- c(
    cores = is.finite(cores) && cores >= workers + 4L,
    memory = is.finite(mem_kib) && mem_kib >= 32 * 1024^2,
    disk = is.finite(disk_kib) && disk_kib >= 75 * 1024^2
  )
  row <- data.frame(
    checked_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), wave = wave,
    workers = workers, logical_cores = cores,
    memory_available_gib = mem_kib / 1024^2,
    disk_available_gib = disk_kib / 1024^2,
    gate_pass = all(checks), failed_checks = paste(names(checks)[!checks], collapse = ";"),
    stringsAsFactors = FALSE
  )
  path <- file.path(state_root, "manifests", "resource_gate_history.csv")
  old <- if (file.exists(path)) ffv2_read_csv(path) else data.frame()
  history <- if (nrow(old)) rbind(old, row) else row
  ffv2_write_csv(history, path)
  if (!all(checks)) {
    stop(sprintf("Resource gate failed before %s: %s", wave,
                 paste(names(checks)[!checks], collapse = ", ")), call. = FALSE)
  }
  row
}

status_matches <- function(row) {
  path <- file.path(state_root, "status", paste0(row$job_id[[1L]], ".json"))
  if (!file.exists(path)) return(FALSE)
  payload <- tryCatch(ffv2_read_json(path), error = function(...) NULL)
  !is.null(payload) && identical(as.character(payload$status), "SUCCESS") &&
    identical(as.character(payload$config_sha256), as.character(row$config_sha256[[1L]]))
}

worker_script <- file.path(harness_root, "scripts", "run_independent_metric_intervals_v1_job.R")
run_one <- function(row) {
  log_path <- file.path(state_root, "logs", paste0(row$job_id[[1L]], ".stdout.log"))
  ffv2_ensure_dir(dirname(log_path))
  worker_args <- c(shQuote(worker_script), "--repo-root", shQuote(repo_root),
                   "--state-root", shQuote(state_root), "--engine",
                   shQuote(row$engine[[1L]]), "--job-id", shQuote(row$job_id[[1L]]),
                   "--config", shQuote(row$config_path[[1L]]))
  cpu_id <- suppressWarnings(as.integer(row$cpu_id %||% NA_integer_)[1L])
  status <- if (is.finite(cpu_id)) {
    taskset <- Sys.which("taskset")
    if (!nzchar(taskset)) stop("taskset is required for a CPU-pinned plan.", call. = FALSE)
    system2(taskset, c("-c", as.character(cpu_id), shQuote(Sys.which("Rscript")),
                       worker_args), stdout = log_path, stderr = log_path)
  } else {
    system2(Sys.which("Rscript"), worker_args, stdout = log_path, stderr = log_path)
  }
  data.frame(job_id = row$job_id[[1L]], exit_status = as.integer(status),
             log_path = normalizePath(log_path, winslash = "/", mustWork = TRUE),
             stringsAsFactors = FALSE)
}

wave_id <- ifelse(
  plan$inference == "vb", "01_vb",
  ifelse(plan$engine == "dqlm", "02_dqlm_mcmc", "03_qdesn_mcmc")
)
wave_levels <- c("01_vb", "02_dqlm_mcmc", "03_qdesn_mcmc")
started <- Sys.time()
all_results <- list()
result_i <- 0L
for (wave in wave_levels) {
  selected <- plan[wave_id == wave, , drop = FALSE]
  if (!nrow(selected)) next
  resource_gate(wave)
  complete <- vapply(seq_len(nrow(selected)), function(i) status_matches(selected[i, , drop = FALSE]),
                     logical(1L))
  queue <- selected[!complete, , drop = FALSE]
  cat(sprintf("wave=%s planned=%d already_complete=%d queued=%d workers=%d\n",
              wave, nrow(selected), sum(complete), nrow(queue), workers))
  if (nrow(queue)) {
    pieces <- parallel::mclapply(
      seq_len(nrow(queue)),
      function(i) run_one(queue[i, , drop = FALSE]),
      mc.cores = min(workers, nrow(queue)), mc.preschedule = FALSE
    )
    block <- ffv2_bind_rows(pieces)
    result_i <- result_i + 1L
    all_results[[result_i]] <- block
    if (any(block$exit_status != 0L)) {
      ffv2_write_csv(ffv2_bind_rows(all_results),
                     file.path(state_root, "manifests", "orchestration_results.csv"))
      stop(sprintf("Wave %s has %d failed worker exits.", wave,
                   sum(block$exit_status != 0L)), call. = FALSE)
    }
  }
}

results <- if (length(all_results)) ffv2_bind_rows(all_results) else data.frame(
  job_id = character(0), exit_status = integer(0), log_path = character(0)
)
results_path <- ffv2_write_csv(results,
                               file.path(state_root, "manifests", "orchestration_results.csv"))
health_script <- file.path(harness_root, "scripts", "healthcheck_independent_metric_intervals_v1.R")
health_log <- file.path(state_root, "health", "post_orchestration_health.log")
health_status <- system2(Sys.which("Rscript"),
                         c(shQuote(health_script), "--state-root", shQuote(state_root)),
                         stdout = health_log, stderr = health_log)
health <- ffv2_read_json(file.path(state_root, "health", "health_current.json"))
if (health_status != 0L || !isTRUE(health$all_complete)) {
  stop("Orchestration ended without a complete 100% health state.", call. = FALSE)
}
ffv2_write_json(list(
  schema_version = imi_v1_schema,
  status = "SUCCESS", started_at = format(started, "%Y-%m-%d %H:%M:%S %Z"),
  ended_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), workers = workers,
  materialized_jobs = nrow(plan), executed_jobs = nrow(results),
  skipped_jobs = nrow(plan) - nrow(results),
  result_path = results_path, result_sha256 = ffv2_file_sha256(results_path),
  launch_commit = system("git rev-parse HEAD", intern = TRUE),
  materialization_commit = as.character(materialization$git_commit)
), file.path(state_root, "manifests", "orchestration_manifest.json"))
cat(sprintf("orchestration complete: %d/%d jobs successful\n",
            as.integer(health$completed), as.integer(health$planned)))

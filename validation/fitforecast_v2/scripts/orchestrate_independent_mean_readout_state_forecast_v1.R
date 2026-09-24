#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/orchestrate_independent_mean_readout_state_forecast_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/",
                           mustWork = TRUE)
state_root <- normalizePath(args$`state-root` %||% "", winslash = "/",
                            mustWork = TRUE)
workers <- as.integer(args$workers %||% imrs_v1_workers)[1L]
if (!identical(workers, imrs_v1_workers)) {
  stop("This campaign requires exactly eight worker slots.", call. = FALSE)
}
approved <- ffv2_truthy(
  args$approved %||% Sys.getenv("IMRS_V1_LAUNCH_APPROVED", "false")
)
if (!approved) stop("Launch approval flag is missing.", call. = FALSE)
cpu_ids <- as.integer(strsplit(
  as.character(args$`cpu-ids` %||% ""), ",", fixed = TRUE
)[[1L]])
if (length(cpu_ids) != workers || anyNA(cpu_ids) || anyDuplicated(cpu_ids) ||
    any(cpu_ids < 0L)) {
  stop("--cpu-ids must contain exactly eight unique nonnegative CPU IDs.",
       call. = FALSE)
}
setwd(repo_root)
imrs_v1_set_one_thread()

fit_plan <- ffv2_read_csv(file.path(state_root, "manifests", "fit_plan.csv"))
forecast_plan <- ffv2_read_csv(
  file.path(state_root, "manifests", "forecast_plan.csv")
)
fit_plan$is_canary <- as.logical(fit_plan$is_canary)
forecast_plan$is_canary <- as.logical(forecast_plan$is_canary)
materialization <- ffv2_read_json(
  file.path(state_root, "manifests", "materialization_manifest.json")
)
if (!identical(
  as.character(materialization$historical_authority_compatibility$schema_version),
  imrs_v1_historical_compatibility_schema
)) {
  stop("Materialized historical-authority compatibility policy is invalid.",
       call. = FALSE)
}
if (nrow(fit_plan) != 96L || nrow(forecast_plan) != 46L ||
    anyDuplicated(fit_plan$job_id) || anyDuplicated(forecast_plan$forecast_id)) {
  stop("Runtime plans do not match the frozen 96/46 contract.", call. = FALSE)
}
all_configs <- c(fit_plan$config_path, forecast_plan$config_path)
all_hashes <- c(fit_plan$config_sha256, forecast_plan$config_sha256)
if (any(vapply(all_configs, ffv2_file_sha256, character(1L)) != all_hashes)) {
  stop("A runtime configuration changed after materialization.", call. = FALSE)
}

fit_ok <- function(i) imrs_v1_status_success(
  state_root, "fit", fit_plan$job_id[[i]], fit_plan$config_sha256[[i]]
)
forecast_ok <- function(i) imrs_v1_status_success(
  state_root, "forecast", forecast_plan$forecast_id[[i]],
  forecast_plan$config_sha256[[i]]
)
status_value <- function(stage, id) {
  path <- imrs_v1_status_path(state_root, stage, id)
  if (!file.exists(path)) return("PLANNED")
  x <- tryCatch(imrs_v1_read_json(path), error = function(...) NULL)
  if (is.null(x)) "CORRUPT" else as.character(x$status %||% "CORRUPT")[[1L]]
}
forecast_ready <- function(i) {
  deps <- imrs_v1_split_ids(forecast_plan$fit_job_ids[[i]])
  all(vapply(deps, function(id) {
    j <- match(id, fit_plan$job_id)
    !is.na(j) && fit_ok(j)
  }, logical(1L)))
}

fit_script <- file.path(
  harness_root, "scripts", "run_independent_mean_readout_state_fit_job.R"
)
forecast_script <- file.path(
  harness_root, "scripts", "run_independent_mean_readout_state_forecast_job.R"
)
time_bin <- Sys.which("time")
if (!nzchar(time_bin) && file.exists("/usr/bin/time")) time_bin <- "/usr/bin/time"
taskset_bin <- Sys.which("taskset")
if (!nzchar(taskset_bin)) stop("taskset is required.", call. = FALSE)

run_task <- function(task, cpu_id) {
  stage <- task$stage
  id <- task$id
  log_path <- file.path(state_root, "logs", stage, paste0(id, ".stdout.log"))
  resource_path <- file.path(
    state_root, "logs", stage, paste0(id, ".resource.txt")
  )
  dir.create(dirname(log_path), recursive = TRUE, showWarnings = FALSE)
  script <- if (stage == "fit") fit_script else forecast_script
  id_flag <- if (stage == "fit") "--job-id" else "--forecast-id"
  worker_args <- c(
    shQuote(Sys.which("Rscript")), shQuote(script), "--repo-root",
    shQuote(repo_root), "--state-root", shQuote(state_root), id_flag,
    shQuote(id), "--config", shQuote(task$config)
  )
  command_args <- c("-c", as.character(cpu_id))
  if (nzchar(time_bin)) {
    command_args <- c(
      command_args, shQuote(time_bin), "-v", "-o", shQuote(resource_path),
      worker_args
    )
  } else {
    command_args <- c(command_args, worker_args)
  }
  exit_status <- system2(
    taskset_bin, command_args, stdout = log_path, stderr = log_path
  )
  list(
    stage = stage, id = id, cpu_id = cpu_id,
    exit_status = as.integer(exit_status), log_path = log_path,
    resource_path = if (file.exists(resource_path)) resource_path else NULL
  )
}

task_candidates <- function(canary_phase) {
  fi <- which(vapply(seq_len(nrow(fit_plan)), function(i) !fit_ok(i), logical(1L)))
  fj <- which(vapply(
    seq_len(nrow(forecast_plan)), function(i) !forecast_ok(i), logical(1L)
  ))
  if (canary_phase) {
    fi <- fi[fit_plan$is_canary[fi]]
    fj <- fj[forecast_plan$is_canary[fj]]
  } else {
    fi <- fi[!fit_plan$is_canary[fi]]
    fj <- fj[!forecast_plan$is_canary[fj]]
  }
  fj <- fj[vapply(fj, forecast_ready, logical(1L))]
  forecast_tasks <- lapply(fj, function(i) list(
    stage = "forecast", id = forecast_plan$forecast_id[[i]],
    config = forecast_plan$config_path[[i]], priority = 1L
  ))
  fit_order <- order(fit_plan$inference[fi] != "mcmc", fit_plan$source_id[fi])
  fit_tasks <- lapply(fi[fit_order], function(i) list(
    stage = "fit", id = fit_plan$job_id[[i]],
    config = fit_plan$config_path[[i]], priority = 2L
  ))
  c(forecast_tasks, fit_tasks)
}

validate_existing_statuses <- function() {
  fit_status <- vapply(fit_plan$job_id, function(id) status_value("fit", id),
                       character(1L))
  fc_status <- vapply(forecast_plan$forecast_id, function(id) {
    status_value("forecast", id)
  }, character(1L))
  retryable_fit <- vapply(seq_len(nrow(fit_plan)), function(i) {
    if (!identical(fit_status[[i]], "FAILED")) return(FALSE)
    status_path <- imrs_v1_status_path(state_root, "fit", fit_plan$job_id[[i]])
    compatibility_path <- file.path(
      fit_plan$job_root[[i]], "manifest",
      "historical_native_authority_compatibility.csv"
    )
    if (!file.exists(status_path) || !file.exists(compatibility_path)) {
      return(FALSE)
    }
    status <- tryCatch(imrs_v1_read_json(status_path), error = function(...) NULL)
    compatibility <- tryCatch(
      ffv2_read_csv(compatibility_path), error = function(...) NULL
    )
    if (is.null(status) || is.null(compatibility)) return(FALSE)
    imrs_v1_retryable_fit_compatibility_failure(
      status, compatibility, fit_plan$inference[[i]]
    )
  }, logical(1L))
  bad <- c(
    imrs_v1_label_ids(
      "fit:", fit_plan$job_id[
        fit_status %in% c("FAILED", "CORRUPT") & !retryable_fit
      ]
    ),
    imrs_v1_label_ids("forecast:", forecast_plan$forecast_id[
      fc_status %in% c("FAILED", "CORRUPT")
    ])
  )
  running <- c(
    imrs_v1_label_ids("fit:", fit_plan$job_id[fit_status == "RUNNING"]),
    imrs_v1_label_ids(
      "forecast:", forecast_plan$forecast_id[fc_status == "RUNNING"]
    )
  )
  if (length(bad)) stop("Terminal failed statuses exist: ", paste(bad, collapse = ", "))
  if (any(retryable_fit)) {
    cat("Retrying endpoint-review fit statuses under the pooled-source gate: ",
        paste(fit_plan$job_id[retryable_fit], collapse = ", "), "\n", sep = "")
  }
  if (length(running)) {
    stop("Stale or externally owned RUNNING statuses exist: ",
         paste(running, collapse = ", "))
  }
}
validate_existing_statuses()

started <- Sys.time()
active <- list()
results <- list()
result_i <- 0L
canary_phase <- !all(vapply(
  which(forecast_plan$is_canary), forecast_ok, logical(1L)
))
heartbeat_path <- file.path(state_root, "manifests", "orchestration_heartbeat.json")

repeat {
  if (length(active)) {
    processes <- lapply(active, `[[`, "process")
    done <- parallel::mccollect(processes, wait = FALSE)
    if (length(done)) {
      for (pid in names(done)) {
        meta <- active[[pid]]
        value <- done[[pid]]
        result_i <- result_i + 1L
        results[[result_i]] <- if (inherits(value, "try-error")) {
          list(stage = meta$task$stage, id = meta$task$id,
               cpu_id = meta$cpu_id, exit_status = 255L,
               error_message = as.character(value))
        } else value
        active[[pid]] <- NULL
      }
    }
  }

  failed_results <- if (length(results)) {
    vapply(results, function(x) {
      !identical(as.integer(x$exit_status), 0L)
    }, logical(1L))
  } else logical(0)
  halt_requested <- any(failed_results)
  if (halt_requested && !length(active)) {
      stop("One or more campaign workers failed; no automatic retry was attempted.",
           call. = FALSE)
  }

  if (canary_phase) {
    canary_done <- all(vapply(
      which(forecast_plan$is_canary), forecast_ok, logical(1L)
    ))
    if (canary_done && !length(active)) {
      canary_phase <- FALSE
      imrs_v1_atomic_write_json(list(
        schema_version = imrs_v1_schema,
        passed_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
        canary_fit_jobs = sum(fit_plan$is_canary),
        canary_forecast_jobs = sum(forecast_plan$is_canary),
        native_artifact_consistency_tolerance = imrs_v1_tolerance,
        historical_authority_compatibility_schema =
          imrs_v1_historical_compatibility_schema
      ), file.path(state_root, "manifests", "canary_gate.json"))
    }
  }

  all_done <- all(vapply(seq_len(nrow(fit_plan)), fit_ok, logical(1L))) &&
    all(vapply(seq_len(nrow(forecast_plan)), forecast_ok, logical(1L)))
  if (all_done && !length(active)) break

  tasks <- if (halt_requested) list() else task_candidates(canary_phase)
  active_ids <- vapply(active, function(x) x$task$id, character(1L))
  if (length(active_ids)) {
    tasks <- tasks[!vapply(tasks, function(x) x$id %in% active_ids, logical(1L))]
  }
  free_cpus <- setdiff(cpu_ids, vapply(active, `[[`, integer(1L), "cpu_id"))
  while (length(tasks) && length(free_cpus) && length(active) < workers) {
    task <- tasks[[1L]]
    tasks <- tasks[-1L]
    cpu <- free_cpus[[1L]]
    free_cpus <- free_cpus[-1L]
    process <- parallel::mcparallel(
      run_task(task, cpu), mc.set.seed = FALSE, silent = FALSE
    )
    active[[as.character(process$pid)]] <- list(
      process = process, task = task, cpu_id = cpu
    )
  }

  imrs_v1_atomic_write_json(list(
    schema_version = imrs_v1_schema,
    updated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    phase = if (canary_phase) "CANARY" else "FULL",
    active_workers = length(active), workers_max = workers,
    active = lapply(active, function(x) list(
      pid = x$process$pid, stage = x$task$stage, job_id = x$task$id,
      cpu_id = x$cpu_id
    )),
    completed_worker_invocations = length(results)
  ), heartbeat_path)

  if (!length(active) && !length(tasks)) {
    stop("Scheduler reached a dependency deadlock before completion.", call. = FALSE)
  }
  Sys.sleep(5)
}

results_df <- if (length(results)) do.call(rbind, lapply(results, function(x) {
  data.frame(
    stage = x$stage, job_id = x$id, cpu_id = x$cpu_id,
    exit_status = x$exit_status, log_path = x$log_path %||% NA_character_,
    resource_path = x$resource_path %||% NA_character_,
    stringsAsFactors = FALSE
  )
})) else data.frame()
results_path <- imrs_v1_atomic_write_csv(
  results_df, file.path(state_root, "manifests", "orchestration_results.csv")
)

closeout_script <- file.path(
  harness_root, "scripts", "closeout_independent_mean_readout_state_forecast_v1.R"
)
verify_script <- file.path(
  harness_root, "scripts", "verify_independent_mean_readout_state_forecast_v1.R"
)
closeout_log <- file.path(state_root, "logs", "closeout.stdout.log")
verify_log <- file.path(state_root, "logs", "verification.stdout.log")
closeout_status <- system2(
  Sys.which("Rscript"), c(shQuote(closeout_script), "--repo-root",
    shQuote(repo_root), "--state-root", shQuote(state_root)),
  stdout = closeout_log, stderr = closeout_log
)
if (closeout_status != 0L) stop("Automated scientific closeout failed.", call. = FALSE)
verify_status <- system2(
  Sys.which("Rscript"), c(shQuote(verify_script), "--repo-root",
    shQuote(repo_root), "--state-root", shQuote(state_root)),
  stdout = verify_log, stderr = verify_log
)
if (verify_status != 0L) stop("Final campaign verification failed.", call. = FALSE)

imrs_v1_atomic_write_json(list(
  schema_version = imrs_v1_schema, status = "SUCCESS",
  started_at = format(started, "%Y-%m-%d %H:%M:%S %Z"),
  ended_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  workers = workers, cpu_ids = cpu_ids,
  materialization_commit = materialization$git_commit,
  launch_commit = system("git rev-parse HEAD", intern = TRUE),
  executed_jobs = nrow(results_df),
  orchestration_results_path = results_path,
  orchestration_results_sha256 = ffv2_file_sha256(results_path),
  closeout_log = closeout_log, verify_log = verify_log
), file.path(state_root, "manifests", "orchestration_manifest.json"))
cat("ORCHESTRATION_COMPLETE 96/96 fits 46/46 forecasts closeout=PASS verify=PASS\n")

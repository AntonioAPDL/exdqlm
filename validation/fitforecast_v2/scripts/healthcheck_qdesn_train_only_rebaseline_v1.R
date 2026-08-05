#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  index <- which(args == flag)
  if (!length(index) || index[[1L]] >= length(args)) return(default)
  args[[index[[1L]] + 1L]]
}
`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/", mustWork = TRUE
)
setwd(repo_root)
stage <- "qdesn_dynamic_fitforecast_v2_500obs_trainonly_rebaseline_v1"
state_parent <- file.path("reports", "shared_fitforecast_v2_orchestration")
run_id <- as.character(get_arg("--run-id", ""))[1L]
if (!nzchar(run_id)) {
  candidates <- list.dirs(state_parent, recursive = FALSE, full.names = FALSE)
  candidates <- candidates[grepl("^qdesn_trainonly_rebaseline_v1_", candidates)]
  if (length(candidates)) {
    info <- file.info(file.path(state_parent, candidates))
    run_id <- candidates[[which.max(info$mtime)]]
  }
}

stub <- file.path("config", "validation", stage)
grid <- utils::read.csv(
  paste0(stub, "_grid.csv"), check.names = FALSE, stringsAsFactors = FALSE
)
targets <- utils::read.csv(
  paste0(stub, "_target_spec_ids.csv"), check.names = FALSE, stringsAsFactors = FALSE
)
expected_total <- nrow(targets)
state_root <- if (nzchar(run_id)) file.path(state_parent, run_id) else NA_character_
env <- character()
if (nzchar(run_id) && file.exists(file.path(state_root, "run_tags.env"))) {
  lines <- readLines(file.path(state_root, "run_tags.env"), warn = FALSE)
  for (line in lines[grepl("=", lines, fixed = TRUE)]) {
    pieces <- strsplit(line, "=", fixed = TRUE)[[1L]]
    env[[pieces[[1L]]]] <- paste(pieces[-1L], collapse = "=")
  }
}
full_tag <- unname(env["FULL_TAG"])
if (!length(full_tag) || is.na(full_tag)) full_tag <- ""
results_root <- file.path(
  "results", "qdesn_mcmc_validation", stage, full_tag
)
all_dirs <- if (nzchar(full_tag) && dir.exists(results_root)) {
  list.dirs(results_root, recursive = TRUE, full.names = TRUE)
} else character()
ps_lines <- tryCatch(system("ps -eo args", intern = TRUE), error = function(e) character())

parse_log_iteration <- function(path) {
  if (!file.exists(path)) return(0L)
  lines <- tail(readLines(path, warn = FALSE), 4000L)
  matches <- regmatches(
    lines,
    regexec("(?:burn-in|MCMC) iteration ([0-9]+)", lines, perl = TRUE)
  )
  values <- suppressWarnings(as.integer(vapply(matches, function(x) {
    if (length(x) >= 2L) x[[2L]] else NA_character_
  }, character(1L))))
  values <- values[is.finite(values)]
  if (length(values)) max(values) else 0L
}

rows <- lapply(seq_len(nrow(targets)), function(i) {
  spec <- targets[i, , drop = FALSE]
  root_id <- as.character(spec$root_id)
  profile <- as.character(spec$screening_profile_id)
  likelihood <- as.character(spec$likelihood_family)
  root_matches <- all_dirs[basename(all_dirs) == root_id]
  root_dir <- if (length(root_matches)) root_matches[[1L]] else NA_character_
  method_dir <- if (!is.na(root_dir)) {
    file.path(root_dir, "fits", paste0("mcmc_", likelihood))
  } else NA_character_
  fit_path <- if (!is.na(method_dir)) file.path(method_dir, "fit_summary_row.csv") else NA_character_
  horizon_path <- if (!is.na(method_dir)) {
    file.path(method_dir, "tables", "forecast_horizon_summary.csv")
  } else NA_character_
  trace_path <- if (!is.na(method_dir)) file.path(method_dir, "progress_trace.csv") else NA_character_
  log_path <- if (!is.na(method_dir)) {
    file.path(method_dir, "logs", "pipeline_child_live.log")
  } else NA_character_
  status_paths <- if (!is.na(method_dir)) c(
    file.path(method_dir, "manifest", "fit_status.txt"),
    file.path(method_dir, "manifest", "status.txt")
  ) else character()
  status_paths <- status_paths[file.exists(status_paths)]
  status <- if (file.exists(fit_path) && file.exists(horizon_path)) {
    "COMPLETE"
  } else if (length(status_paths)) {
    trimws(tail(readLines(status_paths[[1L]], warn = FALSE), 1L))
  } else if (!is.na(method_dir) && dir.exists(method_dir)) {
    "STARTED"
  } else "NOT_STARTED"
  chain_iteration <- 0L
  if (file.exists(trace_path)) {
    trace <- tryCatch(
      utils::read.csv(trace_path, check.names = FALSE), error = function(e) NULL
    )
    if (!is.null(trace) && nrow(trace)) {
      chain_iteration <- max(as.integer(trace$step), na.rm = TRUE)
    }
  }
  overall_iteration <- max(parse_log_iteration(log_path),
                           if (chain_iteration > 0L) 5000L + chain_iteration else 0L)
  if (identical(status, "COMPLETE")) overall_iteration <- 25000L
  phase <- if (identical(status, "COMPLETE")) {
    "complete"
  } else if (overall_iteration >= 25000L) {
    "forecast_metrics"
  } else if (overall_iteration > 5000L || chain_iteration > 0L) {
    "mcmc_sampling"
  } else if (overall_iteration > 0L) {
    "burn_in"
  } else if (!is.na(method_dir) && dir.exists(method_dir)) {
    "initialization"
  } else "queued"
  # The master launcher command contains every spec ID, including queued work.
  # A root ID appears only in the command path for a fit that has actually
  # started, so it distinguishes live workers from the pending queue.
  active <- any(grepl(root_id, ps_lines, fixed = TRUE))
  progress_files <- c(trace_path, log_path, fit_path, horizon_path)
  progress_files <- progress_files[file.exists(progress_files)]
  last_update <- if (length(progress_files)) max(file.info(progress_files)$mtime) else as.POSIXct(NA)
  age_minutes <- if (!is.na(last_update)) {
    as.numeric(difftime(Sys.time(), last_update, units = "mins"))
  } else NA_real_
  stale <- isTRUE(active) && is.finite(age_minutes) && age_minutes > 30
  data.frame(
    model = as.character(spec$model_variant),
    family = as.character(spec$family),
    tau = as.numeric(spec$tau),
    candidate = as.character(spec$legacy_candidate_id),
    likelihood = likelihood,
    phase = phase,
    status = status,
    iteration = min(overall_iteration, 25000L),
    total_iterations = 25000L,
    percent = round(100 * min(overall_iteration, 25000L) / 25000, 2),
    active_process = active,
    progress_age_min = round(age_minutes, 1),
    stale_over_30m = stale,
    spec_id = as.character(spec$spec_id),
    stringsAsFactors = FALSE
  )
})
health <- do.call(rbind, rows)
completed <- sum(health$status == "COMPLETE")
active <- sum(health$active_process)
started <- sum(health$status != "NOT_STARTED")
remaining <- expected_total - completed

stage_status <- "NOT_LAUNCHED"
detail <- "no orchestration state"
status_path <- if (nzchar(run_id)) file.path(state_root, "stage_status.csv") else ""
if (file.exists(status_path)) {
  status_table <- utils::read.csv(status_path, check.names = FALSE, stringsAsFactors = FALSE)
  if (nrow(status_table)) {
    stage_status <- paste(tail(status_table$stage, 1L), tail(status_table$status, 1L), sep = ":")
    detail <- tail(status_table$detail, 1L)
  }
}
heartbeat_age_min <- NA_real_
heartbeat_path <- if (nzchar(run_id)) file.path(state_root, "heartbeat.csv") else ""
if (file.exists(heartbeat_path)) {
  heartbeat_age_min <- as.numeric(difftime(
    Sys.time(), file.info(heartbeat_path)$mtime, units = "mins"
  ))
}
classification <- if (completed == expected_total) {
  "COMPLETED_AWAITING_OR_FINISHED_CLOSEOUT"
} else if (active > 0L) {
  "RUNNING"
} else if (started > completed) {
  "INCOMPLETE_NO_ACTIVE_WORKER"
} else if (started == 0L) {
  "NOT_LAUNCHED"
} else "WAITING_FOR_NEXT_STAGE"

output_path <- as.character(get_arg("--output", ""))[1L]
if (nzchar(output_path)) {
  if (!grepl("^/", output_path)) output_path <- file.path(repo_root, output_path)
  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(health, output_path, row.names = FALSE, na = "")
}
cat(sprintf("run_id: %s\n", if (nzchar(run_id)) run_id else "none"))
cat(sprintf("full_tag: %s\n", if (nzchar(full_tag)) full_tag else "none"))
cat(sprintf("classification: %s\n", classification))
cat(sprintf(
  "progress: %d/%d complete (%.1f%%), %d active, %d remaining\n",
  completed, expected_total, 100 * completed / expected_total, active, remaining
))
cat(sprintf("stage: %s\n", stage_status))
cat(sprintf("detail: %s\n", detail))
cat(sprintf(
  "heartbeat_age_min: %s\n",
  if (is.finite(heartbeat_age_min)) round(heartbeat_age_min, 1) else "NA"
))
print(health[, c(
  "model", "family", "tau", "candidate", "phase", "status",
  "iteration", "total_iterations", "percent", "active_process",
  "progress_age_min", "stale_over_30m"
)], row.names = FALSE)

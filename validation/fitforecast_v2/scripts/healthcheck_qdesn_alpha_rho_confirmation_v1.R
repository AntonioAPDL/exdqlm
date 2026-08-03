#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  index <- which(args == flag)
  if (!length(index) || index[[1L]] >= length(args)) return(default)
  args[[index[[1L]] + 1L]]
}
repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/", mustWork = TRUE
)
setwd(repo_root)
stage <- "qdesn_dynamic_fitforecast_v2_500obs_alpha_rho_confirmation_v1"
state_parent <- file.path("reports", "shared_fitforecast_v2_orchestration")
run_id <- as.character(get_arg("--run-id", ""))[1L]
if (!nzchar(run_id)) {
  candidates <- list.dirs(state_parent, recursive = FALSE, full.names = FALSE)
  candidates <- candidates[grepl("^qdesn_alpha_rho_confirmation_v1_", candidates)]
  if (length(candidates)) {
    info <- file.info(file.path(state_parent, candidates))
    run_id <- candidates[[which.max(info$mtime)]]
  }
}
grid_path <- file.path("config", "validation", paste0(stage, "_grid.csv"))
grid <- utils::read.csv(grid_path, check.names = FALSE, stringsAsFactors = FALSE)
state_root <- if (nzchar(run_id)) file.path(state_parent, run_id) else NA_character_
env <- character()
if (nzchar(run_id) && file.exists(file.path(state_root, "run_tags.env"))) {
  lines <- readLines(file.path(state_root, "run_tags.env"), warn = FALSE)
  for (line in lines[grepl("=", lines, fixed = TRUE)]) {
    parts <- strsplit(line, "=", fixed = TRUE)[[1L]]
    env[[parts[[1L]]]] <- paste(parts[-1L], collapse = "=")
  }
}
full_tag <- unname(env["FULL_TAG"])
if (!length(full_tag) || is.na(full_tag)) full_tag <- ""
results_root <- file.path(
  "results", "qdesn_mcmc_validation", stage, full_tag
)
ps_lines <- tryCatch(
  system("ps -eo args", intern = TRUE), error = function(e) character()
)

rows <- lapply(seq_len(nrow(grid)), function(i) {
  root_id <- as.character(grid$root_id[[i]])
  profile <- as.character(grid$screening_profile_id[[i]])
  root_dirs <- if (nzchar(full_tag) && dir.exists(results_root)) {
    list.dirs(results_root, recursive = TRUE, full.names = TRUE)
  } else character()
  root_dir <- root_dirs[basename(root_dirs) == root_id]
  root_dir <- if (length(root_dir)) root_dir[[1L]] else NA_character_
  trace_path <- if (!is.na(root_dir)) file.path(
    root_dir, "fits", "mcmc_exal", "progress_trace.csv"
  ) else NA_character_
  fit_path <- if (!is.na(root_dir)) file.path(
    root_dir, "fits", "mcmc_exal", "fit_summary_row.csv"
  ) else NA_character_
  status_paths <- if (!is.na(root_dir)) c(
    file.path(root_dir, "fits", "mcmc_exal", "manifest", "fit_status.txt"),
    file.path(root_dir, "fits", "mcmc_exal", "manifest", "status.txt"),
    file.path(root_dir, "manifest", "root_status.txt")
  ) else character()
  status_path <- status_paths[file.exists(status_paths)]
  status <- if (length(status_path)) {
    tail(readLines(status_path[[1L]], warn = FALSE), 1L)
  } else if (file.exists(fit_path)) "COMPLETE" else if (!is.na(root_dir)) "STARTED" else "NOT_STARTED"
  iteration <- 0L
  trace_mtime <- as.POSIXct(NA)
  if (file.exists(trace_path)) {
    trace <- tryCatch(
      utils::read.csv(trace_path, check.names = FALSE), error = function(e) NULL
    )
    if (!is.null(trace) && nrow(trace)) iteration <- max(as.integer(trace$step), na.rm = TRUE)
    trace_mtime <- file.info(trace_path)$mtime
  }
  active <- any(grepl(profile, ps_lines, fixed = TRUE))
  age_minutes <- if (!is.na(trace_mtime)) {
    as.numeric(difftime(Sys.time(), trace_mtime, units = "mins"))
  } else NA_real_
  data.frame(
    cell = as.character(grid$target_cell_id[[i]]),
    role = as.character(grid$comparison_role[[i]]),
    reservoir = as.integer(grid$reservoir_replicate[[i]]),
    status = status,
    iteration = iteration,
    total = 20000L,
    percent = round(100 * iteration / 20000, 2),
    active_process = active,
    trace_age_min = round(age_minutes, 1),
    profile = profile,
    stringsAsFactors = FALSE
  )
})
health <- do.call(rbind, rows)
completed <- sum(health$status %in% c("SUCCESS", "COMPLETE") | health$iteration >= 20000L)
active <- sum(health$active_process)
started <- sum(health$status != "NOT_STARTED")
remaining <- 8L - completed
stage_status <- "NOT_LAUNCHED"
last_detail <- "no confirmation orchestration state"
status_path <- if (nzchar(run_id)) file.path(state_root, "stage_status.csv") else ""
if (file.exists(status_path)) {
  status_table <- utils::read.csv(status_path, check.names = FALSE, stringsAsFactors = FALSE)
  if (nrow(status_table)) {
    stage_status <- paste(tail(status_table$stage, 1L), tail(status_table$status, 1L), sep = ":")
    last_detail <- tail(status_table$detail, 1L)
  }
}
heartbeat_age_min <- NA_real_
heartbeat_path <- if (nzchar(run_id)) file.path(state_root, "heartbeat.csv") else ""
if (file.exists(heartbeat_path)) {
  heartbeat_age_min <- as.numeric(difftime(
    Sys.time(), file.info(heartbeat_path)$mtime, units = "mins"
  ))
}
classification <- if (completed == 8L) {
  "COMPLETED_AWAIT_CLOSEOUT_OR_CLOSED"
} else if (active > 0L) {
  "RUNNING"
} else if (started > completed) {
  "INCOMPLETE_NO_ACTIVE_WORKER"
} else if (started == 0L) {
  "NOT_LAUNCHED"
} else {
  "WAITING_FOR_NEXT_STAGE"
}

cat(sprintf("run_id: %s\n", if (nzchar(run_id)) run_id else "none"))
cat(sprintf("full_tag: %s\n", if (nzchar(full_tag)) full_tag else "none"))
cat(sprintf("classification: %s\n", classification))
cat(sprintf("progress: %d/8 complete, %d active, %d remaining\n", completed, active, remaining))
cat(sprintf("stage: %s\n", stage_status))
cat(sprintf("detail: %s\n", last_detail))
cat(sprintf("heartbeat_age_min: %s\n", if (is.finite(heartbeat_age_min)) round(heartbeat_age_min, 1) else "NA"))
print(health[, c(
  "cell", "role", "reservoir", "status", "iteration", "total",
  "percent", "active_process", "trace_age_min"
)], row.names = FALSE)

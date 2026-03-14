#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo_root <- if (length(args)) args[[1]] else "."
state_dir <- if (length(args) >= 2L) args[[2]] else "/home/jaguir26/local/state/exdqlm/family_qspec_v2"
repo_root <- normalizePath(repo_root, mustWork = TRUE)
state_dir <- normalizePath(state_dir, mustWork = TRUE)

source(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_v2_common.R"))
queue <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_runtime_queue.tsv"))
registry_path <- file.path(state_dir, "launch_registry.tsv")
if (!file.exists(registry_path)) stop("Missing launch registry: ", registry_path)
registry <- fq_read_tsv(registry_path)
lock_dirs <- list.dirs(file.path(state_dir, "locks"), recursive = FALSE, full.names = FALSE)
lock_dirs <- lock_dirs[nzchar(lock_dirs)]
active <- registry[registry$task_id %in% lock_dirs, , drop = FALSE]
if (nrow(active) == 0L) {
  active <- data.frame(
    timestamp = character(),
    session_name = character(),
    task_id = character(),
    unit_type = character(),
    root_kind = character(),
    family = character(),
    tau = character(),
    fit_size = character(),
    prior = character(),
    model = character(),
    launch_mode = character(),
    run_root = character(),
    lock_dir = character(),
    worker_log = character(),
    stringsAsFactors = FALSE
  )
} else {
  active <- active[order(active$timestamp, active$session_name), , drop = FALSE]
  active <- active[!duplicated(active$task_id, fromLast = TRUE), , drop = FALSE]
  active <- merge(active, queue, by = c("task_id", "unit_type"), all.x = TRUE, sort = FALSE)
  active$lock_dir <- file.path(state_dir, "locks", active$task_id)
  active$worker_log <- file.path(state_dir, "worker_logs", paste0(active$task_id, ".log"))
  active <- active[, c("timestamp", "session_name", "task_id", "unit_type", "root_kind", "family", "tau", "fit_size", "prior", "model", "launch_mode", "run_root", "lock_dir", "worker_log")]
  active <- active[order(active$timestamp, active$session_name), ]
}
fq_write_tsv(active, file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_v2_active_tasks.tsv"))
cat(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_v2_active_tasks.tsv"), "\n")

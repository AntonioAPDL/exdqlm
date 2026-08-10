#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("jsonlite is required.")
})
args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (!length(i) || i[[1L]] >= length(args)) return(default)
  args[[i[[1L]] + 1L]]
}
repo_root <- normalizePath(get_arg(
  "--repo-root", system("git rev-parse --show-toplevel", intern = TRUE)
), winslash = "/", mustWork = TRUE)
setwd(repo_root)
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "independent_exal_m0_structural_screen_v2.R"))
run_tag <- get_arg("--run-tag")
plan_path <- normalizePath(get_arg("--plan"), winslash = "/", mustWork = TRUE)
output <- normalizePath(get_arg("--output", sub("[.]csv$", "_health.csv", plan_path)),
                        winslash = "/", mustWork = FALSE)
stale_seconds <- as.numeric(get_arg("--stale-seconds", "1800"))
plan <- qdesn_ssv2_read_csv(plan_path)
process_text <- paste(system("ps -eo pid=,etimes=,pcpu=,pmem=,args=", intern = TRUE), collapse = "\n")

latest_progress <- function(path) {
  if (!file.exists(path)) return(c(iteration = NA_real_, total = NA_real_))
  x <- tryCatch(qdesn_ssv2_read_csv(path), error = function(e) NULL)
  if (is.null(x) || !nrow(x)) return(c(iteration = NA_real_, total = NA_real_))
  iter_name <- intersect(c("iteration", "iter", "mcmc_iteration"), names(x))
  total_name <- intersect(c("total_iterations", "iteration_total", "n_total"), names(x))
  c(iteration = if (length(iter_name)) as.numeric(utils::tail(x[[iter_name[[1L]]]], 1L)) else nrow(x),
    total = if (length(total_name)) as.numeric(utils::tail(x[[total_name[[1L]]]], 1L)) else NA_real_)
}

rows <- lapply(seq_len(nrow(plan)), function(i) {
  root <- qdesn_ssv2_job_root(repo_root, run_tag, plan$job_id[[i]])
  status_path <- file.path(root, "job_status.json")
  started_path <- file.path(root, "job_started.json")
  status <- if (file.exists(status_path)) qdesn_ssv2_read_json(status_path) else NULL
  started <- if (file.exists(started_path)) qdesn_ssv2_read_json(started_path) else NULL
  state <- if (!is.null(status)) as.character(status$status) else if (!is.null(started)) "RUNNING" else "PLANNED"
  alive <- grepl(plan$config_path[[i]], process_text, fixed = TRUE)
  evidence <- c(status_path, file.path(root, "progress_trace.csv"), started_path)
  evidence <- evidence[file.exists(evidence)]
  age <- if (length(evidence)) as.numeric(difftime(Sys.time(), max(file.info(evidence)$mtime), units = "secs")) else NA_real_
  health <- if (state == "SUCCESS") "completed" else if (state == "FAIL") "failed" else if (state == "PLANNED") "planned" else if (!alive) "interrupted" else if (is.finite(age) && age > stale_seconds) "stalled" else "progressing"
  progress <- latest_progress(file.path(root, "progress_trace.csv"))
  data.frame(
    stage = plan$stage[[i]], target_cell_id = plan$target_cell_id[[i]],
    candidate_id = plan$candidate_id[[i]], source_id = plan$source_id[[i]],
    job_id = plan$job_id[[i]], status = state, health = health,
    process_alive = alive, evidence_age_seconds = age,
    iteration = progress[["iteration"]], iteration_total = progress[["total"]],
    completion_percent = if (is.finite(progress[["iteration"]]) && is.finite(progress[["total"]]) && progress[["total"]] > 0)
      100 * progress[["iteration"]] / progress[["total"]] else NA_real_,
    elapsed_seconds = as.numeric(status$elapsed_seconds %||% NA_real_),
    objective_value = as.numeric(status$objective_value %||% NA_real_),
    stringsAsFactors = FALSE
  )
})
health <- do.call(rbind, rows)
qdesn_ssv2_write_csv(health, output)
summary <- stats::aggregate(job_id ~ stage + health, health, length)
names(summary)[names(summary) == "job_id"] <- "jobs"
print(summary, row.names = FALSE)
cat(sprintf("total=%d completed=%d running=%d failed=%d remaining=%d output=%s\n",
            nrow(health), sum(health$health == "completed"),
            sum(health$health %in% c("progressing", "stalled")),
            sum(health$health == "failed"), sum(health$health != "completed"), output))

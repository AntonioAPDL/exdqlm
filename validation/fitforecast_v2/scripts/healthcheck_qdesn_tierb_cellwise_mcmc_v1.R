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
                 "qdesn_tierb_cellwise_mcmc_v1.R"))
run_tag <- get_arg("--run-tag")
plan_path <- normalizePath(get_arg("--plan"), winslash = "/", mustWork = TRUE)
output <- normalizePath(get_arg("--output", sub("[.]csv$", "_health.csv", plan_path)),
                        winslash = "/", mustWork = FALSE)
stale_seconds <- as.numeric(get_arg("--stale-seconds", "1800"))
plan <- qdesn_ssv2_read_csv(plan_path)
plan_value <- function(name, i, default = NA_character_) {
  if (name %in% names(plan)) plan[[name]][[i]] else default
}
process_text <- paste(system(
  "ps -eo pid=,etimes=,pcpu=,pmem=,args=", intern = TRUE
), collapse = "\n")

latest_progress <- function(root, expected_n_burn, expected_n_mcmc) {
  total <- as.integer(expected_n_burn) + as.integer(expected_n_mcmc)
  trace_path <- file.path(root, "progress_trace.csv")
  trace <- if (file.exists(trace_path)) tryCatch(
    qdesn_ssv2_read_csv(trace_path), error = function(e) NULL
  ) else NULL
  trace_iter <- if (!is.null(trace) && nrow(trace)) {
    field <- intersect(c("iteration", "iter", "mcmc_iteration"), names(trace))
    if (length(field)) as.numeric(utils::tail(trace[[field[[1L]]]], 1L)) else nrow(trace)
  } else NA_real_
  child_path <- file.path(root, "logs", "pipeline_child_live.log")
  parsed <- list(iteration = NA_real_, total = total, phase = NA_character_)
  if (file.exists(child_path)) {
    lines <- tryCatch(system2("tail", c("-n", "240", child_path), stdout = TRUE),
                      error = function(e) character())
    parsed <- qdesn_ssv2_parse_progress_lines(
      lines, expected_n_burn, expected_n_mcmc
    )
  }
  if (is.finite(parsed$iteration) &&
      (!is.finite(trace_iter) || parsed$iteration >= trace_iter)) {
    return(c(parsed, list(source = "pipeline_child_live_log")))
  }
  list(iteration = trace_iter, total = total, phase = NA_character_,
       source = if (is.finite(trace_iter)) "progress_trace" else NA_character_)
}

rows <- lapply(seq_len(nrow(plan)), function(i) {
  target_cell_id <- as.character(plan_value("target_cell_id", i))
  stage <- as.character(plan_value("stage", i))
  tier <- as.character(plan_value(
    "tier", i, if (grepl("tier_b", stage, fixed = TRUE)) "B" else NA_character_
  ))
  likelihood_target <- as.character(plan_value(
    "likelihood_target", i,
    if (grepl("^al_", target_cell_id)) "al" else NA_character_
  ))
  root <- qdesn_tbcv1_job_root(repo_root, run_tag, plan$job_id[[i]])
  status_path <- file.path(root, "job_status.json")
  started_path <- file.path(root, "job_started.json")
  status <- if (file.exists(status_path)) qdesn_ssv2_read_json(status_path) else NULL
  started <- if (file.exists(started_path)) qdesn_ssv2_read_json(started_path) else NULL
  state <- if (!is.null(status)) as.character(status$status) else
    if (!is.null(started)) "RUNNING" else "PLANNED"
  alive <- grepl(plan$config_path[[i]], process_text, fixed = TRUE)
  evidence <- c(status_path, file.path(root, "progress_trace.csv"), started_path,
                file.path(root, "logs", "pipeline_child_live.log"))
  evidence <- evidence[file.exists(evidence)]
  age <- if (length(evidence)) as.numeric(difftime(
    Sys.time(), max(file.info(evidence)$mtime), units = "secs"
  )) else NA_real_
  health <- if (state == "SUCCESS") "completed" else if (state == "FAIL") {
    "failed"
  } else if (state == "PLANNED") "planned" else if (!alive) {
    "interrupted"
  } else if (is.finite(age) && age > stale_seconds) "stalled" else "progressing"
  progress <- latest_progress(
    root, plan$expected_n_burn[[i]], plan$expected_n_mcmc[[i]]
  )
  metrics <- if (!is.null(status$metric_values)) {
    unlist(status$metric_values, use.names = TRUE)
  } else setNames(rep(NA_real_, 3L), qdesn_tbcv1_target_metrics)
  data.frame(
    stage = stage, tier = tier, target_cell_id = target_cell_id,
    likelihood_target = likelihood_target,
    candidate_id = plan$candidate_id[[i]], source_id = plan$source_id[[i]],
    job_id = plan$job_id[[i]], status = state, health = health,
    process_alive = alive, evidence_age_seconds = age,
    iteration = progress$iteration, iteration_total = progress$total,
    progress_phase = progress$phase, progress_source = progress$source,
    completion_percent = if (is.finite(progress$iteration) && progress$total > 0) {
      100 * progress$iteration / progress$total
    } else NA_real_,
    elapsed_seconds = as.numeric(status$elapsed_seconds %||% NA_real_),
    fit_qtrue_rmse = as.numeric(metrics[["fit_qtrue_rmse"]]),
    forecast_qtrue_mae_H1000 =
      as.numeric(metrics[["forecast_qtrue_mae_H1000"]]),
    forecast_check_loss_H1000 =
      as.numeric(metrics[["forecast_check_loss_H1000"]]),
    stringsAsFactors = FALSE
  )
})
health <- do.call(rbind, rows)
qdesn_ssv2_write_csv(health, output)
summary <- stats::aggregate(job_id ~ stage + health, health, length)
names(summary)[names(summary) == "job_id"] <- "jobs"
print(summary, row.names = FALSE)
cat(sprintf(
  "total=%d completed=%d running=%d failed=%d remaining=%d output=%s\n",
  nrow(health), sum(health$health == "completed"),
  sum(health$health %in% c("progressing", "stalled")),
  sum(health$health == "failed"), sum(health$health != "completed"), output
))

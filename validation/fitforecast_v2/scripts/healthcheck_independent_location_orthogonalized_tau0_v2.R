#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Missing jsonlite")
})
args <- commandArgs(trailingOnly = TRUE)
arg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (!length(i) || i[[1L]] >= length(args)) default else args[[i[[1L]] + 1L]]
}
repo <- normalizePath(
  arg("--repo-root", system("git rev-parse --show-toplevel", intern = TRUE)),
  winslash = "/", mustWork = TRUE
)
source(file.path(
  repo, "validation", "fitforecast_v2", "R",
  "independent_location_orthogonalized_tau0_v2.R"
))
run_tag <- arg("--run-tag")
plan <- qdesn_ssv2_read_csv(normalizePath(arg("--plan"), winslash = "/",
                                         mustWork = TRUE))
output <- normalizePath(arg("--output"), winslash = "/", mustWork = FALSE)
rows <- do.call(rbind, lapply(seq_len(nrow(plan)), function(i) {
  root <- idol_v2_job_root(repo, run_tag, plan$job_id[[i]])
  status_path <- file.path(root, "job_status.json")
  started_path <- file.path(root, "job_started.json")
  started <- if (file.exists(started_path)) {
    tryCatch(qdesn_ssv2_read_json(started_path), error = function(e) NULL)
  } else NULL
  status <- if (file.exists(status_path)) {
    qdesn_ssv2_read_json(status_path)
  } else if (!is.null(started)) {
    pid <- as.integer(started$pid %||% NA_integer_)
    live <- is.finite(pid) && system2("kill", c("-0", pid),
                                     stdout = FALSE, stderr = FALSE) == 0L
    list(status = if (live) "RUNNING" else "STALE")
  } else list(status = "PENDING")
  progress_files <- list.files(
    file.path(root, "telemetry"), pattern = "progress.*[.]csv$", full.names = TRUE
  )
  iteration <- 0L
  if (length(progress_files)) {
    z <- tryCatch(qdesn_ssv2_read_csv(progress_files[[1L]]),
                  error = function(e) NULL)
    if (!is.null(z)) {
      column <- intersect(c("iteration", "iter", "mcmc_iteration"), names(z))
      if (length(column)) {
        values <- suppressWarnings(as.integer(z[[column[[1L]]]]))
        if (any(is.finite(values))) iteration <- max(values, na.rm = TRUE)
      }
    }
  }
  total <- as.integer(plan$expected_n_burn[[i]] + plan$expected_n_mcmc[[i]])
  if (identical(as.character(status$status), "SUCCESS")) iteration <- total
  metrics <- idol_v2_metric_values(root)
  data.frame(
    stage = plan$stage[[i]], target_cell_id = plan$target_cell_id[[i]],
    likelihood_target = plan$likelihood_target[[i]],
    candidate_id = plan$candidate_id[[i]], profile_role = plan$profile_role[[i]],
    transform_mode = plan$transform_mode[[i]],
    rhs_tau0 = plan$rhs_tau0[[i]], chain_id = plan$chain_id[[i]],
    reservoir_seed_id = plan$reservoir_seed_id[[i]],
    status = as.character(status$status), iteration = iteration,
    total_iterations = total, percent = round(100 * iteration / total, 1),
    fit_qtrue_rmse = metrics[["fit_qtrue_rmse"]],
    forecast_qtrue_mae_H1000 = metrics[["forecast_qtrue_mae_H1000"]],
    forecast_check_loss_H1000 = metrics[["forecast_check_loss_H1000"]],
    binary_payloads = as.integer(status$binary_payloads_remaining %||% NA_integer_),
    stringsAsFactors = FALSE
  )
}))
qdesn_ssv2_write_csv(rows, output)
summary <- as.data.frame(table(rows$status), stringsAsFactors = FALSE)
names(summary) <- c("status", "jobs")
summary$planned_jobs <- nrow(rows)
summary$completed_percent <- round(100 * sum(rows$status == "SUCCESS") / nrow(rows), 2)
summary$runs_left <- sum(!rows$status %in% c("SUCCESS", "FAIL"))
qdesn_ssv2_write_csv(summary, sub("[.]csv$", "_summary.csv", output))
cat(sprintf(
  "HEALTH jobs=%d success=%d running=%d pending=%d stale=%d failed=%d complete=%.2f%% left=%d\n",
  nrow(rows), sum(rows$status == "SUCCESS"), sum(rows$status == "RUNNING"),
  sum(rows$status == "PENDING"), sum(rows$status == "STALE"),
  sum(rows$status == "FAIL"), 100 * sum(rows$status == "SUCCESS") / nrow(rows),
  sum(!rows$status %in% c("SUCCESS", "FAIL"))
))

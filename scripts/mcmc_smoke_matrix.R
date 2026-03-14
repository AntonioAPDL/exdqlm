#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("pkgload")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

`%||%` <- function(a, b) if (is.null(a)) b else a

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) && idx < length(args)) args[idx + 1L] else default
}

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE)),
  error = function(...) normalizePath(".", mustWork = TRUE)
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

timestamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
report_dir <- normalizePath(
  get_arg("--output-dir", file.path("reports", "mcmc_inference_smoke", timestamp)),
  winslash = "/",
  mustWork = FALSE
)
dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)
log_dir <- file.path(report_dir, "logs")
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

cases_tbl <- data.frame(
  label = c(
    "sim_vb_ridge",
    "sim_vb_rhs",
    "sim_mcmc_ridge",
    "sim_mcmc_rhs",
    "real_vb_ridge",
    "real_vb_rhs",
    "real_mcmc_ridge",
    "real_mcmc_rhs"
  ),
  slug = c(
    "dlm_constV_smallW_local_sim",
    "dlm_constV_smallW_local_sim",
    "dlm_constV_smallW_local_sim",
    "dlm_constV_smallW_local_sim",
    "dlm_constV_smallW_local_real",
    "dlm_constV_smallW_local_real",
    "dlm_constV_smallW_local_real",
    "dlm_constV_smallW_local_real"
  ),
  spec = c(
    "mcmc_smoke_sim_vb_ridge",
    "mcmc_smoke_sim_vb_rhs",
    "mcmc_smoke_sim_mcmc_ridge",
    "mcmc_smoke_sim_mcmc_rhs",
    "mcmc_smoke_real_vb_ridge",
    "mcmc_smoke_real_vb_rhs",
    "mcmc_smoke_real_mcmc_ridge",
    "mcmc_smoke_real_mcmc_rhs"
  ),
  mode = c("sim", "sim", "sim", "sim", "real", "real", "real", "real"),
  method = c("vb", "vb", "mcmc", "mcmc", "vb", "vb", "mcmc", "mcmc"),
  beta_prior_type = c("ridge", "rhs", "ridge", "rhs", "ridge", "rhs", "ridge", "rhs"),
  stringsAsFactors = FALSE
)

selected_cases <- get_arg("--cases", "")
if (nzchar(selected_cases)) {
  keep <- trimws(strsplit(selected_cases, ",", fixed = TRUE)[[1L]])
  cases_tbl <- cases_tbl[cases_tbl$label %in% keep, , drop = FALSE]
}
if (!nrow(cases_tbl)) stop("No smoke-matrix cases selected.")

parse_run_dir <- function(lines) {
  hit <- grep("^Run dir:\\s+", lines, value = TRUE)
  if (!length(hit)) return(NA_character_)
  trimws(sub("^Run dir:\\s+", "", utils::tail(hit, 1L)))
}

rbind_fill <- function(rows) {
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (!length(rows)) return(data.frame(stringsAsFactors = FALSE))
  cols <- unique(unlist(lapply(rows, names), use.names = FALSE))
  aligned <- lapply(rows, function(df) {
    miss <- setdiff(cols, names(df))
    for (nm in miss) df[[nm]] <- NA
    df[, cols, drop = FALSE]
  })
  do.call(rbind, aligned)
}

run_case <- function(row) {
  label <- row$label[[1L]]
  log_file <- file.path(log_dir, sprintf("%s.log", label))
  cmd_args <- c("scripts/pipeline_run.R", "--slug", row$slug[[1L]], "--spec", row$spec[[1L]])

  cat(sprintf("[mcmc_smoke_matrix] running %s\n", label))
  t0 <- proc.time()[["elapsed"]]
  status <- system2("Rscript", args = cmd_args, stdout = log_file, stderr = log_file)
  elapsed <- as.numeric(proc.time()[["elapsed"]] - t0)

  log_lines <- if (file.exists(log_file)) readLines(log_file, warn = FALSE) else character()
  run_dir <- parse_run_dir(log_lines)
  if (!nzchar(run_dir) || is.na(run_dir)) {
    run_dir <- NA_character_
  } else {
    run_dir <- normalizePath(run_dir, winslash = "/", mustWork = FALSE)
  }

  summary_obj <- NULL
  summary_row <- data.frame(stringsAsFactors = FALSE)
  if (!is.na(run_dir) && dir.exists(run_dir)) {
    summary_obj <- exdqlm:::collect_pipeline_run_summary(run_dir)
    summary_row <- summary_obj$summary
  }

  out <- data.frame(
    label = label,
    slug = row$slug[[1L]],
    spec = row$spec[[1L]],
    requested_mode = row$mode[[1L]],
    requested_method = row$method[[1L]],
    requested_beta_prior_type = row$beta_prior_type[[1L]],
    runner_status = as.integer(status),
    runner_elapsed_seconds = elapsed,
    log_file = normalizePath(log_file, winslash = "/", mustWork = FALSE),
    stringsAsFactors = FALSE
  )

  if (nrow(summary_row)) {
    out <- cbind(out, summary_row, stringsAsFactors = FALSE)
  } else {
    out$run_dir <- run_dir
    out$status <- if (identical(as.integer(status), 0L)) "UNKNOWN" else "FAIL"
  }

  out
}

rows <- lapply(seq_len(nrow(cases_tbl)), function(i) run_case(cases_tbl[i, , drop = FALSE]))
summary_df <- rbind_fill(rows)

vb_baseline <- summary_df[summary_df$requested_method == "vb", c(
  "requested_mode",
  "requested_beta_prior_type",
  "runner_elapsed_seconds",
  "wall_seconds",
  "forecast_CRPS_mean",
  "forecast_S_mean"
), drop = FALSE]
names(vb_baseline) <- c(
  "requested_mode",
  "requested_beta_prior_type",
  "vb_runner_elapsed_seconds",
  "vb_wall_seconds",
  "vb_forecast_CRPS_mean",
  "vb_forecast_S_mean"
)

summary_df <- merge(
  summary_df,
  vb_baseline,
  by = c("requested_mode", "requested_beta_prior_type"),
  all.x = TRUE,
  sort = FALSE
)

summary_df$runner_elapsed_ratio_vs_vb <- with(summary_df, ifelse(
  requested_method == "vb" | !is.finite(vb_runner_elapsed_seconds) | vb_runner_elapsed_seconds <= 0,
  1,
  runner_elapsed_seconds / vb_runner_elapsed_seconds
))
summary_df$wall_seconds_ratio_vs_vb <- with(summary_df, ifelse(
  requested_method == "vb" | !is.finite(vb_wall_seconds) | vb_wall_seconds <= 0,
  1,
  wall_seconds / vb_wall_seconds
))
summary_df$forecast_CRPS_delta_vs_vb <- with(summary_df, forecast_CRPS_mean - vb_forecast_CRPS_mean)
summary_df$forecast_S_delta_vs_vb <- with(summary_df, forecast_S_mean - vb_forecast_S_mean)

summary_df <- summary_df[order(summary_df$requested_mode, summary_df$requested_beta_prior_type, summary_df$requested_method), , drop = FALSE]

utils::write.csv(summary_df, file.path(report_dir, "matrix_summary.csv"), row.names = FALSE)
saveRDS(summary_df, file.path(report_dir, "matrix_summary.rds"))

print_cols <- intersect(
  c(
    "label",
    "status",
    "requested_mode",
    "requested_method",
    "requested_beta_prior_type",
    "runner_elapsed_seconds",
    "wall_seconds",
    "forecast_CRPS_mean",
    "forecast_S_mean",
    "runner_elapsed_ratio_vs_vb",
    "forecast_CRPS_delta_vs_vb",
    "forecast_S_delta_vs_vb"
  ),
  names(summary_df)
)
print(summary_df[, print_cols, drop = FALSE], row.names = FALSE)

if (any(summary_df$runner_status != 0L, na.rm = TRUE)) {
  stop("At least one smoke-matrix run failed. See logs in ", report_dir)
}

cat(sprintf("[mcmc_smoke_matrix] summary written to %s\n", report_dir))

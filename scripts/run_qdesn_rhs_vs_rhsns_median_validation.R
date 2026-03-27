#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("pkgload", "jsonlite")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) && idx < length(args)) args[idx + 1L] else default
}
has_flag <- function(flag) any(args == flag)
`%||%` <- function(a, b) if (is.null(a)) b else a

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}
read_csv_safe <- function(path) {
  if (!file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  utils::read.csv(path, stringsAsFactors = FALSE)
}
write_csv_safe <- function(df, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(df, path, row.names = FALSE)
}

defaults_path <- resolve_path(
  get_arg("--defaults", file.path("config", "validation", "qdesn_rhs_vs_rhs_ns_median_defaults.yaml")),
  must_work = TRUE
)
grid_path <- resolve_path(
  get_arg("--grid", file.path("config", "validation", "qdesn_rhs_vs_rhs_ns_median_grid.csv")),
  must_work = TRUE
)
results_root <- resolve_path(get_arg("--results-root", NULL), must_work = FALSE)
report_root <- resolve_path(get_arg("--report-root", NULL), must_work = FALSE)
create_plots <- !has_flag("--no-plots")
verbose <- !has_flag("--quiet")

baseline_refs <- c(
  file.path(
    "reports", "qdesn_mcmc_validation", "rhs_stageM_repair_wave",
    "stageNrepair-20260325-150856__git-d81c311",
    "mr3_full", "20260325-181919__git-d81c311",
    "tables", "campaign_method_summary.csv"
  ),
  file.path(
    "reports", "qdesn_mcmc_validation", "rhs_stageO_wave",
    "stageO-20260326-081449__git-d81c311",
    "o3_stress6", "20260326-083656__git-d81c311",
    "tables", "campaign_method_summary.csv"
  )
)
baseline_ref_rows <- lapply(baseline_refs, function(rel) {
  abs <- resolve_path(rel, must_work = FALSE)
  data.frame(
    baseline_artifact = rel,
    baseline_artifact_abs = abs,
    exists = file.exists(abs),
    stringsAsFactors = FALSE
  )
})
baseline_ref_df <- do.call(rbind, baseline_ref_rows)

head_sha <- trimws(system("git rev-parse HEAD", intern = TRUE))
if (isTRUE(verbose)) {
  cat(sprintf("[rhs-vs-rhs_ns] baseline freeze HEAD: %s\n", head_sha))
}

run <- exdqlm:::qdesn_validation_run_campaign(
  grid_path = grid_path,
  defaults_path = defaults_path,
  results_root = results_root,
  report_root = report_root,
  create_plots = create_plots,
  verbose = verbose
)

report_run_root <- normalizePath(run$report_root, winslash = "/", mustWork = TRUE)
results_run_root <- normalizePath(run$results_root, winslash = "/", mustWork = TRUE)
tables_dir <- file.path(report_run_root, "tables")
manifest_dir <- file.path(report_run_root, "manifest")
dir.create(manifest_dir, recursive = TRUE, showWarnings = FALSE)

method_df <- read_csv_safe(file.path(tables_dir, "campaign_method_summary.csv"))
pair_df <- read_csv_safe(file.path(tables_dir, "campaign_pair_summary.csv"))
root_df <- read_csv_safe(file.path(tables_dir, "campaign_root_summary.csv"))
signoff_df <- read_csv_safe(file.path(tables_dir, "campaign_method_signoff.csv"))

forecast_cols <- intersect(c(
  "scenario", "tau", "beta_prior_type", "method",
  "forecast_CRPS_mean", "forecast_PinballMean_mean", "forecast_S_mean",
  "forecast_qhat_mae", "forecast_qhat_rmse", "forecast_pinball_tau", "forecast_qhat_bias"
), names(method_df))
signal_cols <- intersect(c(
  "scenario", "tau", "beta_prior_type", "method",
  "signal_qhat_mae", "signal_qhat_rmse", "signal_qhat_corr"
), names(method_df))
health_cols <- intersect(c(
  "scenario", "tau", "beta_prior_type", "method",
  "status", "wall_seconds", "total_stage_seconds", "fit_runtime_seconds",
  "rhs_diag_available", "rhs_collapse_flag", "rhs_collapse_flag_bound", "rhs_collapse_flag_shrink",
  "rhs_diag_tau_last", "rhs_diag_E_invV_med_last", "rhs_diag_beta_l2_last", "rhs_diag_beta_small_frac_1e4_last",
  "unhealthy", "unhealthy_reason", "rhs_root_cause_context"
), names(method_df))
signoff_cols <- intersect(c(
  "scenario", "tau", "beta_prior_type", "method",
  "signoff_grade", "comparison_eligible", "signoff_reason"
), names(signoff_df))

forecast_df <- if (length(forecast_cols)) method_df[, forecast_cols, drop = FALSE] else data.frame(stringsAsFactors = FALSE)
signal_df <- if (length(signal_cols)) method_df[, signal_cols, drop = FALSE] else data.frame(stringsAsFactors = FALSE)
health_df <- if (length(health_cols)) method_df[, health_cols, drop = FALSE] else data.frame(stringsAsFactors = FALSE)
signoff_view <- if (length(signoff_cols)) signoff_df[, signoff_cols, drop = FALSE] else data.frame(stringsAsFactors = FALSE)

if (nrow(health_df) && nrow(signoff_view)) {
  by_cols <- intersect(c("scenario", "tau", "beta_prior_type", "method"), intersect(names(health_df), names(signoff_view)))
  health_df <- merge(health_df, signoff_view, by = by_cols, all.x = TRUE, sort = FALSE)
}

delta_rows <- list()
if (nrow(method_df)) {
  methods <- unique(as.character(method_df$method))
  for (mth in methods) {
    sub <- method_df[as.character(method_df$method) == mth, , drop = FALSE]
    rhs <- sub[tolower(as.character(sub$beta_prior_type)) == "rhs", , drop = FALSE]
    rhs_ns <- sub[tolower(as.character(sub$beta_prior_type)) == "rhs_ns", , drop = FALSE]
    if (!nrow(rhs) || !nrow(rhs_ns)) next
    by_cols <- intersect(c("scenario", "tau", "method"), intersect(names(rhs), names(rhs_ns)))
    rhs_k <- rhs[, unique(c(by_cols, "forecast_CRPS_mean", "forecast_PinballMean_mean", "forecast_S_mean", "forecast_qhat_mae", "forecast_qhat_rmse", "forecast_pinball_tau", "signal_qhat_rmse", "signal_qhat_corr", "wall_seconds", "fit_runtime_seconds", "status", "unhealthy")), drop = FALSE]
    rhs_ns_k <- rhs_ns[, unique(c(by_cols, "forecast_CRPS_mean", "forecast_PinballMean_mean", "forecast_S_mean", "forecast_qhat_mae", "forecast_qhat_rmse", "forecast_pinball_tau", "signal_qhat_rmse", "signal_qhat_corr", "wall_seconds", "fit_runtime_seconds", "status", "unhealthy")), drop = FALSE]
    names(rhs_k) <- ifelse(names(rhs_k) %in% by_cols, names(rhs_k), paste0("rhs_", names(rhs_k)))
    names(rhs_ns_k) <- ifelse(names(rhs_ns_k) %in% by_cols, names(rhs_ns_k), paste0("rhs_ns_", names(rhs_ns_k)))
    cmp <- merge(rhs_k, rhs_ns_k, by = by_cols, all = TRUE, sort = FALSE)
    if ("rhs_ns_forecast_CRPS_mean" %in% names(cmp) && "rhs_forecast_CRPS_mean" %in% names(cmp)) cmp$delta_CRPS_rhs_ns_minus_rhs <- cmp$rhs_ns_forecast_CRPS_mean - cmp$rhs_forecast_CRPS_mean
    if ("rhs_ns_forecast_PinballMean_mean" %in% names(cmp) && "rhs_forecast_PinballMean_mean" %in% names(cmp)) cmp$delta_PinballMean_rhs_ns_minus_rhs <- cmp$rhs_ns_forecast_PinballMean_mean - cmp$rhs_forecast_PinballMean_mean
    if ("rhs_ns_forecast_S_mean" %in% names(cmp) && "rhs_forecast_S_mean" %in% names(cmp)) cmp$delta_S_rhs_ns_minus_rhs <- cmp$rhs_ns_forecast_S_mean - cmp$rhs_forecast_S_mean
    if ("rhs_ns_forecast_qhat_mae" %in% names(cmp) && "rhs_forecast_qhat_mae" %in% names(cmp)) cmp$delta_qhat_mae_rhs_ns_minus_rhs <- cmp$rhs_ns_forecast_qhat_mae - cmp$rhs_forecast_qhat_mae
    if ("rhs_ns_forecast_qhat_rmse" %in% names(cmp) && "rhs_forecast_qhat_rmse" %in% names(cmp)) cmp$delta_qhat_rmse_rhs_ns_minus_rhs <- cmp$rhs_ns_forecast_qhat_rmse - cmp$rhs_forecast_qhat_rmse
    if ("rhs_ns_forecast_pinball_tau" %in% names(cmp) && "rhs_forecast_pinball_tau" %in% names(cmp)) cmp$delta_pinball_tau_rhs_ns_minus_rhs <- cmp$rhs_ns_forecast_pinball_tau - cmp$rhs_forecast_pinball_tau
    if ("rhs_ns_signal_qhat_rmse" %in% names(cmp) && "rhs_signal_qhat_rmse" %in% names(cmp)) cmp$delta_signal_qhat_rmse_rhs_ns_minus_rhs <- cmp$rhs_ns_signal_qhat_rmse - cmp$rhs_signal_qhat_rmse
    if ("rhs_ns_signal_qhat_corr" %in% names(cmp) && "rhs_signal_qhat_corr" %in% names(cmp)) cmp$delta_signal_qhat_corr_rhs_ns_minus_rhs <- cmp$rhs_ns_signal_qhat_corr - cmp$rhs_signal_qhat_corr
    if ("rhs_wall_seconds" %in% names(cmp) && "rhs_ns_wall_seconds" %in% names(cmp)) {
      cmp$runtime_ratio_rhs_ns_vs_rhs <- ifelse(
        is.finite(cmp$rhs_wall_seconds) & cmp$rhs_wall_seconds > 0,
        cmp$rhs_ns_wall_seconds / cmp$rhs_wall_seconds,
        NA_real_
      )
    }
    delta_rows[[length(delta_rows) + 1L]] <- cmp
  }
}
delta_df <- if (length(delta_rows)) do.call(rbind, delta_rows) else data.frame(stringsAsFactors = FALSE)

write_csv_safe(forecast_df, file.path(tables_dir, "rhs_vs_rhsns_forecast_metrics.csv"))
write_csv_safe(signal_df, file.path(tables_dir, "rhs_vs_rhsns_signal_recovery.csv"))
write_csv_safe(health_df, file.path(tables_dir, "rhs_vs_rhsns_runtime_health.csv"))
write_csv_safe(delta_df, file.path(tables_dir, "rhs_vs_rhsns_method_deltas.csv"))
write_csv_safe(baseline_ref_df, file.path(tables_dir, "rhs_vs_rhsns_baseline_refs.csv"))

summary_lines <- c(
  "# QDESN Median Validation: rhs vs rhs_ns",
  "",
  sprintf("- run_timestamp: `%s`", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  sprintf("- git_head: `%s`", head_sha),
  sprintf("- defaults_path: `%s`", defaults_path),
  sprintf("- grid_path: `%s`", grid_path),
  sprintf("- results_root: `%s`", results_run_root),
  sprintf("- report_root: `%s`", report_run_root),
  sprintf("- n_roots: `%d`", nrow(root_df)),
  sprintf("- n_methods: `%d`", nrow(method_df)),
  ""
)

if (nrow(forecast_df)) {
  summary_lines <- c(summary_lines, "## Forecast Metrics", exdqlm:::.qdesn_validation_df_to_markdown(forecast_df), "")
}
if (nrow(signal_df)) {
  summary_lines <- c(summary_lines, "## Signal Recovery", exdqlm:::.qdesn_validation_df_to_markdown(signal_df), "")
}
if (nrow(health_df)) {
  summary_lines <- c(summary_lines, "## Runtime And Health", exdqlm:::.qdesn_validation_df_to_markdown(health_df), "")
}
if (nrow(delta_df)) {
  summary_lines <- c(summary_lines, "## rhs_ns Minus rhs (Within Method)", exdqlm:::.qdesn_validation_df_to_markdown(delta_df), "")
}
summary_lines <- c(summary_lines, "## Baseline Artifact References", exdqlm:::.qdesn_validation_df_to_markdown(baseline_ref_df))

writeLines(summary_lines, file.path(report_run_root, "rhs_vs_rhsns_median_summary.md"))

manifest <- list(
  generated_at = as.character(Sys.time()),
  git_head = head_sha,
  defaults_path = defaults_path,
  grid_path = grid_path,
  results_root = results_run_root,
  report_root = report_run_root,
  baseline_refs = baseline_ref_df,
  tables = list(
    forecast = file.path(tables_dir, "rhs_vs_rhsns_forecast_metrics.csv"),
    signal = file.path(tables_dir, "rhs_vs_rhsns_signal_recovery.csv"),
    runtime_health = file.path(tables_dir, "rhs_vs_rhsns_runtime_health.csv"),
    deltas = file.path(tables_dir, "rhs_vs_rhsns_method_deltas.csv"),
    baseline_refs = file.path(tables_dir, "rhs_vs_rhsns_baseline_refs.csv")
  ),
  summary_markdown = file.path(report_run_root, "rhs_vs_rhsns_median_summary.md")
)
jsonlite::write_json(manifest, file.path(manifest_dir, "rhs_vs_rhsns_median_manifest.json"), pretty = TRUE, auto_unbox = TRUE, null = "null")

cat(sprintf("Comparison report root: %s\n", report_run_root))
cat(sprintf("Comparison results root: %s\n", results_run_root))
cat(sprintf("Summary: %s\n", file.path(report_run_root, "rhs_vs_rhsns_median_summary.md")))

#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(name, default = NULL) {
  prefix <- paste0("--", name, "=")
  hit <- grep(paste0("^", prefix), args, value = TRUE)
  if (!length(hit)) return(default)
  sub(prefix, "", hit[[length(hit)]], fixed = TRUE)
}

repo_root <- normalizePath(arg_value("repo-root", getwd()), winslash = "/", mustWork = TRUE)
run_tag <- arg_value("run-tag", Sys.getenv("REFRESHED288_RUN_TAG", unset = "20260507_p90_dynamic72_qdesn_comparable_fresh_v1"))
git_sha <- arg_value("git-sha", tryCatch(system2("git", c("-C", repo_root, "rev-parse", "HEAD"), stdout = TRUE), error = function(e) NA_character_)[1L])
comparison_long_path <- arg_value("comparison-long", file.path(repo_root, "tools/merge_reports", sprintf("LOCAL_refreshed288_comparison_long_20260507_%s.csv", run_tag)))
manifest_path <- arg_value("manifest", file.path(repo_root, "tools/merge_reports", sprintf("LOCAL_refreshed288_full_manifest_%s.csv", run_tag)))
status_path <- arg_value("status", file.path(repo_root, "tools/merge_reports", sprintf("LOCAL_refreshed288_full_manifest_status_%s.csv", run_tag)))
out_csv <- arg_value("out-csv", file.path(repo_root, "tools/merge_reports", sprintf("LOCAL_refreshed288_dynamic72_shared_interface_%s.csv", run_tag)))
require_compact <- tolower(arg_value("require-compact", "true")) %in% c("1", "true", "yes", "y")

read_required_csv <- function(path) {
  if (!file.exists(path)) stop("Missing required CSV: ", path, call. = FALSE)
  read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

pinball_loss <- function(y, q, tau) {
  err <- y - q
  mean(ifelse(err >= 0, tau * err, (tau - 1) * err), na.rm = TRUE)
}

safe_col <- function(df, col, default = NA) {
  if (col %in% names(df)) df[[col]] else rep(default, nrow(df))
}

scenario_from_case <- function(case_key) {
  rep("dlm_constV_p90_m0amp_highnoise_steepertrend_v1", length(case_key))
}

if (!file.exists(comparison_long_path)) {
  comparison <- read_required_csv(status_path)
  comparison$case_key <- safe_col(comparison, "original_case_key", NA_character_)
  comparison$status <- safe_col(comparison, "status_current", safe_col(comparison, "status", NA_character_))
  comparison$gate_overall <- safe_col(comparison, "gate_current", safe_col(comparison, "gate_overall", NA_character_))
  comparison$runtime_sec <- safe_col(comparison, "runtime_sec_current", safe_col(comparison, "runtime_sec", NA_real_))
  comparison$q_rmse <- safe_col(comparison, "q_rmse_metric", NA_real_)
  if (!"tau" %in% names(comparison) && "tau_label" %in% names(comparison)) {
    comparison$tau <- suppressWarnings(as.numeric(sub("^0p", "0.", comparison$tau_label)))
  }
} else {
  comparison <- read_required_csv(comparison_long_path)
}
manifest <- read_required_csv(manifest_path)
dynamic <- comparison[comparison$block == "dynamic", , drop = FALSE]
if (!nrow(dynamic)) stop("Comparison input has no dynamic rows: ", comparison_long_path, call. = FALSE)
if ("status" %in% names(dynamic)) {
  dynamic <- dynamic[dynamic$status == "done", , drop = FALSE]
}
if (!nrow(dynamic)) stop("Comparison input has no completed dynamic rows: ", comparison_long_path, call. = FALSE)

path_cols <- intersect(c("row_id", "plot_summary_path"), names(manifest))
manifest_paths <- manifest[, path_cols, drop = FALSE]
dynamic <- merge(dynamic, manifest_paths, by = "row_id", all.x = TRUE, sort = FALSE)
if (!"plot_summary_path" %in% names(dynamic)) {
  if (all(c("plot_summary_path.y", "plot_summary_path.x") %in% names(dynamic))) {
    dynamic$plot_summary_path <- dynamic$plot_summary_path.y
    missing_path <- is.na(dynamic$plot_summary_path) | !nzchar(as.character(dynamic$plot_summary_path))
    dynamic$plot_summary_path[missing_path] <- dynamic$plot_summary_path.x[missing_path]
  } else {
    path_candidates <- intersect(c("plot_summary_path.y", "plot_summary_path.x"), names(dynamic))
    if (length(path_candidates)) dynamic$plot_summary_path <- dynamic[[path_candidates[1L]]]
  }
}
if (!"plot_summary_path" %in% names(dynamic) && "run_root" %in% names(dynamic)) {
  dynamic$plot_summary_path <- file.path(
    dynamic$run_root,
    "plot_summaries",
    sprintf("row_%04d_plot_summary.csv", as.integer(dynamic$row_id))
  )
}

compact_metrics <- lapply(seq_len(nrow(dynamic)), function(i) {
  row <- dynamic[i, , drop = FALSE]
  plot_path <- as.character(row$plot_summary_path[1L])
  if (is.na(plot_path) || !nzchar(plot_path)) {
    if (require_compact) stop("Missing plot_summary_path for row_id=", row$row_id[1L], call. = FALSE)
    return(data.frame(train_pinball_tau = NA_real_, train_qtrue_mae = NA_real_, source_index_start = NA_integer_, source_index_end = NA_integer_, compact_rows = NA_integer_))
  }
  if (!file.exists(plot_path)) {
    if (require_compact) stop("Missing compact plot summary for row_id=", row$row_id[1L], ": ", plot_path, call. = FALSE)
    return(data.frame(train_pinball_tau = NA_real_, train_qtrue_mae = NA_real_, source_index_start = NA_integer_, source_index_end = NA_integer_, compact_rows = NA_integer_))
  }
  plot <- read_required_csv(plot_path)
  needed <- c("y", "q_fit_tau", "q_true", "source_index")
  missing <- setdiff(needed, names(plot))
  if (length(missing)) stop("Compact plot summary missing columns for row_id=", row$row_id[1L], ": ", paste(missing, collapse = ", "), call. = FALSE)
  data.frame(
    train_pinball_tau = pinball_loss(plot$y, plot$q_fit_tau, as.numeric(row$tau[1L])),
    train_qtrue_mae = mean(abs(plot$q_fit_tau - plot$q_true), na.rm = TRUE),
    source_index_start = min(plot$source_index, na.rm = TRUE),
    source_index_end = max(plot$source_index, na.rm = TRUE),
    compact_rows = nrow(plot)
  )
})
compact_metrics <- do.call(rbind, compact_metrics)

source_cell_id <- paste(
  scenario_from_case(dynamic$case_key),
  dynamic$family,
  dynamic$tau_label,
  dynamic$fit_size,
  sep = "::"
)

out <- data.frame(
  study = "exdqlm_dqlm_dynamic72",
  run_tag = run_tag,
  git_sha = git_sha,
  row_id = dynamic$row_id,
  source_cell_id = source_cell_id,
  scenario = scenario_from_case(dynamic$case_key),
  family = dynamic$family,
  tau = as.numeric(dynamic$tau),
  effective_fit_size = as.integer(dynamic$fit_size),
  source_total_size = as.integer(dynamic$fit_size),
  source_index_start = compact_metrics$source_index_start,
  source_index_end = compact_metrics$source_index_end,
  evaluation_split = "train_effective_window",
  model_family = "dqlm",
  model_variant = dynamic$model,
  inference = dynamic$inference,
  prior = dynamic$prior_semantics,
  status = safe_col(dynamic, "status", NA_character_),
  signoff_grade = safe_col(dynamic, "gate_overall", NA_character_),
  runtime_sec = suppressWarnings(as.numeric(safe_col(dynamic, "runtime_sec", NA_real_))),
  train_pinball_tau = compact_metrics$train_pinball_tau,
  train_qtrue_mae = compact_metrics$train_qtrue_mae,
  train_qtrue_rmse = suppressWarnings(as.numeric(safe_col(dynamic, "q_rmse", NA_real_))),
  compact_plot_summary_path = dynamic$plot_summary_path,
  compact_fit_path_train_file = NA_character_,
  compact_fit_path_holdout_file = NA_character_,
  holdout_status = "not_applicable",
  artifact_note = sprintf("compact_rows=%s; generated_from=LOCAL_refreshed288_shared_interface_20260507.R", compact_metrics$compact_rows),
  stringsAsFactors = FALSE
)

out <- out[order(out$family, out$tau, out$effective_fit_size, out$model_variant, out$inference), , drop = FALSE]
dir.create(dirname(out_csv), recursive = TRUE, showWarnings = FALSE)
write.csv(out, out_csv, row.names = FALSE, na = "")
cat(sprintf("shared_interface_rows=%d\n", nrow(out)))
cat(sprintf("wrote_csv=%s\n", out_csv))

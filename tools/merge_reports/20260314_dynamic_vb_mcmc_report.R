#!/usr/bin/env Rscript

resolve_run_root <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) && nzchar(args[[1]]) && dir.exists(args[[1]])) {
    return(normalizePath(args[[1]], mustWork = TRUE))
  }
  rr <- Sys.getenv("EXDQLM_DYNAMIC_RUN_ROOT", "")
  if (nzchar(rr) && dir.exists(rr)) {
    return(normalizePath(rr, mustWork = TRUE))
  }
  stop("Provide dynamic run root as argv[1] or EXDQLM_DYNAMIC_RUN_ROOT.", call. = FALSE)
}

run_root <- resolve_run_root()
out_tables <- file.path(run_root, "tables")
if (!dir.exists(out_tables)) {
  stop("Missing tables directory under run root: ", run_root, call. = FALSE)
}

read_csv_required <- function(path) {
  if (!file.exists(path)) stop("Missing required table: ", path, call. = FALSE)
  utils::read.csv(path, stringsAsFactors = FALSE)
}

ensure_col <- function(df, nm, default = NA) {
  if (!nm %in% names(df)) df[[nm]] <- default
  df
}

mean_or_na <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  x <- x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  mean(x)
}

tau_lab <- function(tau) gsub("\\.", "p", format(as.numeric(tau), nsmall = 2))

fit_bundle_path <- function(inference, model, tau) {
  file.path(run_root, "fits", inference, sprintf("%s_%s_tau_%s_fit.rds", inference, model, tau_lab(tau)))
}

read_fit_runtime <- function(inference, model, tau) {
  path <- fit_bundle_path(inference, model, tau)
  if (!file.exists(path)) return(NA_real_)
  bundle <- tryCatch(readRDS(path), error = function(e) NULL)
  if (is.null(bundle)) return(NA_real_)
  meta_rt <- suppressWarnings(as.numeric(bundle$meta$runtime_sec)[1])
  if (is.finite(meta_rt)) return(meta_rt)
  fit_rt <- suppressWarnings(as.numeric(bundle$fit$run.time)[1])
  if (is.finite(fit_rt)) return(fit_rt)
  NA_real_
}

metrics_df <- read_csv_required(file.path(out_tables, "metrics_summary.csv"))
method_signoff <- read_csv_required(file.path(out_tables, "method_signoff_long.csv"))
algorithm_pair_signoff <- read_csv_required(file.path(out_tables, "algorithm_pair_signoff.csv"))
model_pair_signoff <- read_csv_required(file.path(out_tables, "model_pair_signoff.csv"))
root_signoff_summary <- read_csv_required(file.path(out_tables, "root_signoff_summary.csv"))

method_signoff$inference <- tolower(as.character(method_signoff$inference))
method_signoff$model <- tolower(as.character(method_signoff$model))
method_signoff$tau <- suppressWarnings(as.numeric(method_signoff$tau))
metrics_df$inference <- tolower(as.character(metrics_df$inference))
metrics_df$model <- tolower(as.character(metrics_df$model))
metrics_df$tau <- suppressWarnings(as.numeric(metrics_df$tau))

algorithm_pair_signoff$model <- tolower(as.character(algorithm_pair_signoff$model))
algorithm_pair_signoff$tau <- suppressWarnings(as.numeric(algorithm_pair_signoff$tau))
model_pair_signoff$inference <- tolower(as.character(model_pair_signoff$inference))
model_pair_signoff$tau <- suppressWarnings(as.numeric(model_pair_signoff$tau))

signoff_cols <- method_signoff[, c(
  "inference", "model", "tau", "signoff_grade", "comparison_eligible",
  "convergence_certified", "execution_healthy", "signoff_reason"
), drop = FALSE]

fit_metrics <- merge(
  metrics_df,
  signoff_cols,
  by = c("inference", "model", "tau"),
  all.x = TRUE,
  sort = FALSE
)
fit_metrics <- ensure_col(fit_metrics, "signoff_grade", NA_character_)
fit_metrics <- ensure_col(fit_metrics, "comparison_eligible", NA)
fit_metrics <- ensure_col(fit_metrics, "convergence_certified", NA)
fit_metrics <- ensure_col(fit_metrics, "execution_healthy", NA)
fit_metrics <- ensure_col(fit_metrics, "signoff_reason", NA_character_)
fit_metrics_eligible <- fit_metrics[as.logical(fit_metrics$comparison_eligible %in% TRUE), , drop = FALSE]

pair_df <- merge(
  fit_metrics[fit_metrics$model == "dqlm", c("inference", "tau", "rmse", "coverage", "mean_ci_width", "n_draws", "signoff_grade", "comparison_eligible", "signoff_reason"), drop = FALSE],
  fit_metrics[fit_metrics$model == "exdqlm", c("inference", "tau", "rmse", "coverage", "mean_ci_width", "n_draws", "signoff_grade", "comparison_eligible", "signoff_reason"), drop = FALSE],
  by = c("inference", "tau"),
  suffixes = c("_baseline", "_extended"),
  all = TRUE,
  sort = FALSE
)
if (nrow(pair_df)) {
  pair_df$rmse_delta_extended_minus_baseline <- pair_df$rmse_extended - pair_df$rmse_baseline
  pair_df$coverage_delta_extended_minus_baseline <- pair_df$coverage_extended - pair_df$coverage_baseline
  pair_df$mean_ci_width_delta_extended_minus_baseline <- pair_df$mean_ci_width_extended - pair_df$mean_ci_width_baseline
}
pair_df <- ensure_col(pair_df, "pair_signoff_grade", NA_character_)
pair_df <- ensure_col(pair_df, "pair_comparison_eligible", NA)
if (nrow(pair_df) && nrow(model_pair_signoff)) {
  pair_map <- model_pair_signoff[, c(
    "inference", "tau", "pair_signoff_grade", "pair_comparison_eligible",
    "baseline_signoff_grade", "extended_signoff_grade"
  ), drop = FALSE]
  pair_df <- merge(pair_df, pair_map, by = c("inference", "tau"), all.x = TRUE, sort = FALSE, suffixes = c("", ".signoff"))
  for (nm in c("pair_signoff_grade", "pair_comparison_eligible")) {
    nm_new <- paste0(nm, ".signoff")
    if (nm_new %in% names(pair_df)) {
      pair_df[[nm]] <- ifelse(is.na(pair_df[[nm]]), pair_df[[nm_new]], pair_df[[nm]])
      pair_df[[nm_new]] <- NULL
    }
  }
}
pair_df_eligible <- if (nrow(pair_df)) pair_df[as.logical(pair_df$pair_comparison_eligible %in% TRUE), , drop = FALSE] else pair_df
pair_df_excluded <- if (nrow(pair_df)) pair_df[!as.logical(pair_df$pair_comparison_eligible %in% TRUE), , drop = FALSE] else pair_df

gate_df <- merge(
  fit_metrics[fit_metrics$inference == "vb", c("model", "tau", "rmse", "coverage", "mean_ci_width", "n_draws", "signoff_grade", "comparison_eligible", "signoff_reason"), drop = FALSE],
  fit_metrics[fit_metrics$inference == "mcmc", c("model", "tau", "rmse", "coverage", "mean_ci_width", "n_draws", "signoff_grade", "comparison_eligible", "signoff_reason"), drop = FALSE],
  by = c("model", "tau"),
  suffixes = c("_vb", "_mcmc"),
  all = TRUE,
  sort = FALSE
)
if (nrow(gate_df)) {
  gate_df$rmse_ratio_vb_over_mcmc <- gate_df$rmse_vb / gate_df$rmse_mcmc
  gate_df$coverage_delta_vb_minus_mcmc <- gate_df$coverage_vb - gate_df$coverage_mcmc
  gate_df$mean_ci_width_delta_vb_minus_mcmc <- gate_df$mean_ci_width_vb - gate_df$mean_ci_width_mcmc
}
gate_df <- ensure_col(gate_df, "algorithm_pair_signoff_grade", NA_character_)
gate_df <- ensure_col(gate_df, "algorithm_pair_comparison_eligible", NA)
if (nrow(gate_df) && nrow(algorithm_pair_signoff)) {
  alg_cols <- algorithm_pair_signoff[, c("model", "tau", "pair_signoff_grade", "pair_comparison_eligible"), drop = FALSE]
  names(alg_cols) <- c("model", "tau", "algorithm_pair_signoff_grade", "algorithm_pair_comparison_eligible")
  gate_df <- merge(gate_df, alg_cols, by = c("model", "tau"), all.x = TRUE, sort = FALSE)
}

vb_mcmc_df <- gate_df
if (nrow(vb_mcmc_df)) {
  vb_mcmc_df$mae_vb <- NA_real_
  vb_mcmc_df$mae_mcmc <- NA_real_
  vb_mcmc_df$mae_delta_mcmc_minus_vb <- NA_real_
  vb_mcmc_df$bias_vb <- NA_real_
  vb_mcmc_df$bias_mcmc <- NA_real_
  vb_mcmc_df$bias_delta_mcmc_minus_vb <- NA_real_
  vb_mcmc_df$corr_vb <- NA_real_
  vb_mcmc_df$corr_mcmc <- NA_real_
  vb_mcmc_df$corr_delta_mcmc_minus_vb <- NA_real_
  vb_mcmc_df$vb_runtime_sec <- mapply(read_fit_runtime, "vb", vb_mcmc_df$model, vb_mcmc_df$tau, USE.NAMES = FALSE)
  vb_mcmc_df$mcmc_runtime_sec <- mapply(read_fit_runtime, "mcmc", vb_mcmc_df$model, vb_mcmc_df$tau, USE.NAMES = FALSE)
  vb_mcmc_df$runtime_ratio_mcmc_vs_vb <- vb_mcmc_df$mcmc_runtime_sec / vb_mcmc_df$vb_runtime_sec
  vb_mcmc_df$runtime_ratio_mcmc_vs_vb[!is.finite(vb_mcmc_df$runtime_ratio_mcmc_vs_vb) | vb_mcmc_df$vb_runtime_sec <= 0] <- NA_real_
  vb_mcmc_df$rmse_delta_mcmc_minus_vb <- vb_mcmc_df$rmse_mcmc - vb_mcmc_df$rmse_vb
  vb_mcmc_df$coverage_delta_mcmc_minus_vb <- vb_mcmc_df$coverage_mcmc - vb_mcmc_df$coverage_vb
  vb_mcmc_df$mean_ci_width_delta_mcmc_minus_vb <- vb_mcmc_df$mean_ci_width_mcmc - vb_mcmc_df$mean_ci_width_vb
  names(vb_mcmc_df)[names(vb_mcmc_df) == "algorithm_pair_signoff_grade.y"] <- "algorithm_pair_signoff_grade"
  names(vb_mcmc_df)[names(vb_mcmc_df) == "algorithm_pair_comparison_eligible.y"] <- "algorithm_pair_comparison_eligible"
  vb_mcmc_df <- ensure_col(vb_mcmc_df, "algorithm_pair_signoff_grade", NA_character_)
  vb_mcmc_df <- ensure_col(vb_mcmc_df, "algorithm_pair_comparison_eligible", NA)
  keep_cols <- c(
    "model", "tau",
    "rmse_vb", "rmse_mcmc", "rmse_delta_mcmc_minus_vb",
    "mae_vb", "mae_mcmc", "mae_delta_mcmc_minus_vb",
    "bias_vb", "bias_mcmc", "bias_delta_mcmc_minus_vb",
    "corr_vb", "corr_mcmc", "corr_delta_mcmc_minus_vb",
    "coverage_vb", "coverage_mcmc", "coverage_delta_mcmc_minus_vb",
    "mean_ci_width_vb", "mean_ci_width_mcmc", "mean_ci_width_delta_mcmc_minus_vb",
    "n_draws_vb", "n_draws_mcmc",
    "vb_runtime_sec", "mcmc_runtime_sec", "runtime_ratio_mcmc_vs_vb",
    "signoff_grade_vb", "signoff_grade_mcmc",
    "comparison_eligible_vb", "comparison_eligible_mcmc",
    "signoff_reason_vb", "signoff_reason_mcmc",
    "algorithm_pair_signoff_grade", "algorithm_pair_comparison_eligible"
  )
  vb_mcmc_df <- vb_mcmc_df[, keep_cols, drop = FALSE]
}
vb_mcmc_eligible_df <- if (nrow(vb_mcmc_df)) vb_mcmc_df[as.logical(vb_mcmc_df$algorithm_pair_comparison_eligible %in% TRUE), , drop = FALSE] else vb_mcmc_df
vb_mcmc_excluded_df <- if (nrow(vb_mcmc_df)) vb_mcmc_df[!as.logical(vb_mcmc_df$algorithm_pair_comparison_eligible %in% TRUE), , drop = FALSE] else vb_mcmc_df

utils::write.csv(fit_metrics, file.path(out_tables, "fit_metrics_by_task.csv"), row.names = FALSE)
utils::write.csv(fit_metrics_eligible, file.path(out_tables, "fit_metrics_by_task_eligible.csv"), row.names = FALSE)
utils::write.csv(pair_df_eligible, file.path(out_tables, "pairwise_exdqlm_vs_dqlm.csv"), row.names = FALSE)
utils::write.csv(pair_df_excluded, file.path(out_tables, "pairwise_exdqlm_vs_dqlm_excluded.csv"), row.names = FALSE)
utils::write.csv(gate_df, file.path(out_tables, "acceptance_gate_summary.csv"), row.names = FALSE)
utils::write.csv(vb_mcmc_df, file.path(out_tables, "pairwise_vb_vs_mcmc.csv"), row.names = FALSE)
utils::write.csv(vb_mcmc_eligible_df, file.path(out_tables, "pairwise_vb_vs_mcmc_eligible.csv"), row.names = FALSE)
utils::write.csv(vb_mcmc_excluded_df, file.path(out_tables, "pairwise_vb_vs_mcmc_excluded.csv"), row.names = FALSE)

summary_md <- file.path(out_tables, "report_summary.md")
writeLines(c(
  "# Dynamic VB/MCMC Review Summary",
  "",
  sprintf("- generated_at: `%s`", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  sprintf("- run_root: `%s`", run_root),
  sprintf("- method_signoff_pass_count: %d", sum(method_signoff$signoff_grade == "PASS", na.rm = TRUE)),
  sprintf("- method_signoff_warn_count: %d", sum(method_signoff$signoff_grade == "WARN", na.rm = TRUE)),
  sprintf("- method_signoff_fail_count: %d", sum(method_signoff$signoff_grade == "FAIL", na.rm = TRUE)),
  sprintf("- method_comparison_eligible_count: %d", sum(as.logical(method_signoff$comparison_eligible), na.rm = TRUE)),
  sprintf("- algorithm_pair_eligible_count: %d", sum(as.logical(algorithm_pair_signoff$pair_comparison_eligible), na.rm = TRUE)),
  sprintf("- model_pair_eligible_count: %d", sum(as.logical(model_pair_signoff$pair_comparison_eligible), na.rm = TRUE)),
  sprintf("- root_full_eligible_count: %d", sum(as.logical(root_signoff_summary$root_comparison_eligible_full), na.rm = TRUE)),
  sprintf("- root_any_eligible_count: %d", sum(as.logical(root_signoff_summary$root_comparison_eligible_any), na.rm = TRUE)),
  sprintf("- fit_metric_rows_all: %d", nrow(fit_metrics)),
  sprintf("- fit_metric_rows_eligible: %d", nrow(fit_metrics_eligible)),
  sprintf("- eligible_pairwise_rows: %d", nrow(pair_df_eligible)),
  sprintf("- excluded_pairwise_rows: %d", nrow(pair_df_excluded)),
  sprintf("- vb_vs_mcmc_rows_all: %d", nrow(vb_mcmc_df)),
  sprintf("- vb_vs_mcmc_rows_eligible: %d", nrow(vb_mcmc_eligible_df)),
  sprintf("- vb_vs_mcmc_rows_excluded: %d", nrow(vb_mcmc_excluded_df)),
  "",
  "## Core tables",
  "- `tables/fit_metrics_by_task.csv`",
  "- `tables/fit_metrics_by_task_eligible.csv`",
  "- `tables/pairwise_exdqlm_vs_dqlm.csv`",
  "- `tables/pairwise_exdqlm_vs_dqlm_excluded.csv`",
  "- `tables/acceptance_gate_summary.csv`",
  "- `tables/pairwise_vb_vs_mcmc.csv`",
  "- `tables/pairwise_vb_vs_mcmc_eligible.csv`",
  "- `tables/pairwise_vb_vs_mcmc_excluded.csv`"
), con = summary_md)

cat(sprintf("Dynamic review outputs written under: %s\n", out_tables))

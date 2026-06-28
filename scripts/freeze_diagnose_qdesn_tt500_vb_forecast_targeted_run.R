#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite", "pkgload")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx)) return(default)
  idx <- idx[[1L]]
  if (idx >= length(args)) return(default)
  args[[idx + 1L]]
}
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
read_csv <- function(path) utils::read.csv(resolve_path(path, must_work = TRUE), stringsAsFactors = FALSE, check.names = FALSE)
safe_read_csv <- function(path) {
  path <- as.character(path %||% "")[1L]
  if (!nzchar(path) || !file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}
mean_or_na <- function(x) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (!length(x)) NA_real_ else mean(x)
}

default_report_root <- file.path(
  "reports", "qdesn_mcmc_validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_forecast_targeted",
  "qdesn-tt500-vb-forecast-targeted-full-20260628", "20260628-100556__git-2aaf1bd"
)
report_root <- resolve_path(get_arg("--report-root", default_report_root), must_work = TRUE)
output_root <- resolve_path(
  get_arg("--output-root", file.path(report_root, "freeze", "qdesn_tt500_vb_forecast_targeted_closeout")),
  must_work = FALSE
)
dir.create(file.path(output_root, "tables"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(output_root, "summary"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(output_root, "manifest"), recursive = TRUE, showWarnings = FALSE)

audit_path <- file.path(report_root, "audit", "tables", "qdesn_tt500_vb_screen_audit_summary.csv")
cell_path <- file.path(report_root, "tables", "qdesn_tt500_vb_dominance_cell_summary.csv")
fit_path <- file.path(report_root, "tables", "qdesn_tt500_vb_screen_fit_forecast_summary.csv")
profile_rank_path <- file.path(report_root, "tables", "qdesn_tt500_vb_dominance_profile_ranking.csv")

audit <- read_csv(audit_path)
cell <- read_csv(cell_path)
fit <- read_csv(fit_path)
profile_rank <- read_csv(profile_rank_path)

ratio_cols <- exdqlm:::.qdesn_dynamic_fitforecast_ratio_cols()
cell$primary_worst_ratio_vs_baseline <- do.call(pmax, c(cell[intersect(ratio_cols, names(cell))], na.rm = TRUE))
cell$beats_all_primary_calc <- exdqlm:::.qdesn_dynamic_fitforecast_beats_all_primary(cell)
cell_key <- paste(cell$family, sprintf("%.2f", as.numeric(cell$tau)), sep = "|")
pass_counts <- tapply(cell$beats_all_primary_calc, cell_key, sum, na.rm = TRUE)
eval_counts <- tapply(cell$screening_profile_base, cell_key, length)
cell <- cell[order(cell_key, cell$primary_worst_ratio_vs_baseline, cell$qdesn_runtime_sec_mean), , drop = FALSE]
cell_key_sorted <- paste(cell$family, sprintf("%.2f", as.numeric(cell$tau)), sep = "|")
best <- cell[!duplicated(cell_key_sorted), , drop = FALSE]
best_key <- paste(best$family, sprintf("%.2f", as.numeric(best$tau)), sep = "|")
best$n_profiles_evaluated <- as.integer(eval_counts[best_key])
best$n_profiles_beating_all_primary <- as.integer(pass_counts[best_key])
best$needs_stage3 <- best$n_profiles_beating_all_primary == 0L
best <- best[order(best$needs_stage3 != TRUE, best$family, best$tau), , drop = FALSE]

best_cols <- intersect(c(
  "family", "tau", "n_profiles_evaluated", "n_profiles_beating_all_primary", "needs_stage3",
  "screening_profile_base", "primary_worst_ratio_vs_baseline",
  "forecast_mae_ratio_vs_best_vb_baseline", "forecast_pinball_ratio_vs_best_vb_baseline",
  "fit_rmse_ratio_vs_best_vb_baseline", "fit_pinball_ratio_vs_best_vb_baseline",
  "qdesn_forecast_mae_mean", "qdesn_forecast_pinball_mean",
  "qdesn_fit_rmse_mean", "qdesn_fit_pinball_mean", "qdesn_runtime_sec_mean",
  "D", "n_each", "alpha", "rho", "m", "readout_y_lags", "reservoir_lags", "pi_w", "pi_in"
), names(best))
best_out <- best[, best_cols, drop = FALSE]

failing <- best[best$needs_stage3, , drop = FALSE]
diagnostic_rows <- list()
lead_rows <- list()
rolling_rows <- list()
for (i in seq_len(nrow(failing))) {
  b <- failing[i, , drop = FALSE]
  f <- fit[
    as.character(fit$family) == as.character(b$family[[1L]]) &
      abs(as.numeric(fit$tau) - as.numeric(b$tau[[1L]])) < 1e-8 &
      as.character(fit$screening_profile_base) == as.character(b$screening_profile_base[[1L]]),
    ,
    drop = FALSE
  ]
  if (!nrow(f)) next
  f <- f[1L, , drop = FALSE]
  diagnostic_rows[[length(diagnostic_rows) + 1L]] <- data.frame(
    family = b$family[[1L]],
    tau = as.numeric(b$tau[[1L]]),
    screening_profile_base = b$screening_profile_base[[1L]],
    forecast_all_qtrue_mae = as.numeric(f$forecast_all_qtrue_mae %||% NA_real_)[1L],
    forecast_all_qtrue_rmse = as.numeric(f$forecast_all_qtrue_rmse %||% NA_real_)[1L],
    forecast_all_abs_qtrue_bias = as.numeric(f$forecast_all_abs_qtrue_bias %||% NA_real_)[1L],
    forecast_all_pinball_mean = as.numeric(f$forecast_all_pinball_mean %||% NA_real_)[1L],
    forecast_l1_5_qtrue_mae = as.numeric(f$forecast_l1_5_qtrue_mae %||% NA_real_)[1L],
    forecast_l6_15_qtrue_mae = as.numeric(f$forecast_l6_15_qtrue_mae %||% NA_real_)[1L],
    forecast_l16_30_qtrue_mae = as.numeric(f$forecast_l16_30_qtrue_mae %||% NA_real_)[1L],
    train_qtrue_mae = as.numeric(f$train_qtrue_mae %||% NA_real_)[1L],
    holdout_qtrue_mae = as.numeric(f$holdout_qtrue_mae %||% NA_real_)[1L],
    runtime_sec = as.numeric(f$runtime_sec %||% NA_real_)[1L],
    forecast_lead_metrics_path = as.character(f$forecast_lead_metrics_path %||% NA_character_)[1L],
    forecast_rolling_origin_path_file = as.character(f$forecast_rolling_origin_path_file %||% NA_character_)[1L],
    stringsAsFactors = FALSE
  )
  lead <- safe_read_csv(f$forecast_lead_metrics_path[[1L]])
  if (nrow(lead)) {
    lead$screening_profile_base <- b$screening_profile_base[[1L]]
    lead_rows[[length(lead_rows) + 1L]] <- lead
  }
  rolling <- safe_read_csv(f$forecast_rolling_origin_path_file[[1L]])
  if (nrow(rolling)) {
    bands <- list(all = 1:30, lead_1_5 = 1:5, lead_6_15 = 6:15, lead_16_30 = 16:30)
    for (nm in names(bands)) {
      sub <- rolling[as.integer(rolling$forecast_lead) %in% bands[[nm]], , drop = FALSE]
      if (!nrow(sub)) next
      rolling_rows[[length(rolling_rows) + 1L]] <- data.frame(
        family = b$family[[1L]],
        tau = as.numeric(b$tau[[1L]]),
        screening_profile_base = b$screening_profile_base[[1L]],
        lead_band = nm,
        n_rows = nrow(sub),
        n_origins = length(unique(as.integer(sub$forecast_origin_source_index))),
        qtrue_mean = mean_or_na(sub$q_true),
        qhat_mean = mean_or_na(sub$qhat),
        mean_error = mean_or_na(sub$q_error),
        mae = mean_or_na(abs(as.numeric(sub$q_error))),
        rmse = sqrt(mean_or_na(as.numeric(sub$q_error)^2)),
        pinball = mean_or_na(sub$pinball_tau),
        coverage_abs_error = mean_or_na(abs(as.numeric(sub$coverage_minus_tau))),
        stringsAsFactors = FALSE
      )
    }
  }
}

diag <- exdqlm:::.qdesn_validation_bind_rows(diagnostic_rows)
lead_diag <- exdqlm:::.qdesn_validation_bind_rows(lead_rows)
rolling_diag <- exdqlm:::.qdesn_validation_bind_rows(rolling_rows)

paths <- list(
  audit_snapshot = file.path(output_root, "tables", "audit_snapshot.csv"),
  cell_best = file.path(output_root, "tables", "cell_best_primary_status.csv"),
  failing_cell_diagnostics = file.path(output_root, "tables", "failing_cell_diagnostics.csv"),
  failing_lead_metrics = file.path(output_root, "tables", "failing_cell_best_lead_metrics.csv"),
  failing_rolling_bias = file.path(output_root, "tables", "failing_cell_best_rolling_bias_summary.csv"),
  summary = file.path(output_root, "summary", "qdesn_tt500_vb_forecast_targeted_closeout.md"),
  manifest = file.path(output_root, "manifest", "qdesn_tt500_vb_forecast_targeted_closeout_manifest.json")
)
exdqlm:::.qdesn_validation_write_df(audit, paths$audit_snapshot)
exdqlm:::.qdesn_validation_write_df(best_out, paths$cell_best)
exdqlm:::.qdesn_validation_write_df(diag, paths$failing_cell_diagnostics)
exdqlm:::.qdesn_validation_write_df(lead_diag, paths$failing_lead_metrics)
exdqlm:::.qdesn_validation_write_df(rolling_diag, paths$failing_rolling_bias)

audit_display <- audit[, intersect(c(
  "expected_roots", "observed_roots", "n_success", "n_running", "n_fail",
  "n_success_lead_pass", "n_success_rolling_pass", "n_success_storage_light_pass",
  "forbidden_binary_count_total", "generic_ranking_exists", "dominance_ranking_exists", "strict_ready"
), names(audit)), drop = FALSE]
best_display <- best_out[, intersect(c(
  "family", "tau", "n_profiles_evaluated", "n_profiles_beating_all_primary", "needs_stage3",
  "primary_worst_ratio_vs_baseline", "forecast_mae_ratio_vs_best_vb_baseline",
  "forecast_pinball_ratio_vs_best_vb_baseline", "fit_rmse_ratio_vs_best_vb_baseline",
  "fit_pinball_ratio_vs_best_vb_baseline", "screening_profile_base"
), names(best_out)), drop = FALSE]
summary_lines <- c(
  "# Q-DESN TT500 VB Forecast-Targeted Closeout",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- report_root: `%s`", report_root),
  sprintf("- audit_path: `%s`", audit_path),
  sprintf("- dominance_cell_summary: `%s`", cell_path),
  sprintf("- profile_ranking: `%s`", profile_rank_path),
  "",
  "## Completion Audit",
  exdqlm:::.qdesn_validation_df_to_markdown(audit_display),
  "",
  "## Cell-Level Scientific Status",
  exdqlm:::.qdesn_validation_df_to_markdown(best_display),
  "",
  sprintf("- cells_needing_stage3: `%d`", nrow(failing)),
  sprintf("- cells_with_any_qdesn_profile_beating_all_primary: `%d / %d`", sum(best$n_profiles_beating_all_primary > 0L), nrow(best)),
  "",
  "Interpretation: the run is mechanically complete and storage-light, but it is not a final article-facing replacement because some cells still lack a Q-DESN VB profile that beats the best DQLM/exDQLM VB baseline on all four primary fit+forecast metrics.",
  "",
  "## Diagnostic Tables",
  sprintf("- cell_best: `%s`", paths$cell_best),
  sprintf("- failing_cell_diagnostics: `%s`", paths$failing_cell_diagnostics),
  sprintf("- failing_lead_metrics: `%s`", paths$failing_lead_metrics),
  sprintf("- failing_rolling_bias: `%s`", paths$failing_rolling_bias),
  sprintf("- manifest: `%s`", paths$manifest)
)
exdqlm:::.qdesn_validation_write_lines(paths$summary, summary_lines)

manifest <- list(
  generated_at = as.character(Sys.time()),
  report_root = report_root,
  output_root = output_root,
  git_sha = trimws(system("git rev-parse HEAD", intern = TRUE)),
  git_branch = trimws(system("git rev-parse --abbrev-ref HEAD", intern = TRUE)),
  strict_ready = isTRUE(audit$strict_ready[[1L]]),
  expected_roots = as.integer(audit$expected_roots[[1L]]),
  observed_roots = as.integer(audit$observed_roots[[1L]]),
  n_success = as.integer(audit$n_success[[1L]]),
  n_fail = as.integer(audit$n_fail[[1L]]),
  cells_total = nrow(best),
  cells_needing_stage3 = nrow(failing),
  cells_needing_stage3_keys = as.list(paste(failing$family, sprintf("%.2f", as.numeric(failing$tau)), sep = ":")),
  paths = paths,
  file_manifest = exdqlm:::qdesn_validation_file_manifest(c(
    audit_path, cell_path, fit_path, profile_rank_path,
    paths$audit_snapshot, paths$cell_best, paths$failing_cell_diagnostics,
    paths$failing_lead_metrics, paths$failing_rolling_bias, paths$summary
  ))
)
exdqlm:::.qdesn_validation_write_json(paths$manifest, manifest)

cat(sprintf("output_root: %s\n", output_root))
cat(sprintf("summary: %s\n", paths$summary))
cat(sprintf("manifest: %s\n", paths$manifest))
cat(sprintf("cells_needing_stage3: %d\n", nrow(failing)))

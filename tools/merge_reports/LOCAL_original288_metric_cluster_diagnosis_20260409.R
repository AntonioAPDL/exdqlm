#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

ensure_dir_diag <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  invisible(path)
}

safe_median <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  if (!length(x) || all(is.na(x))) return(NA_real_)
  stats::median(x, na.rm = TRUE)
}

summarize_groups <- function(df, by, metric_cols, win_cols) {
  split_df <- split(df, interaction(df[by], drop = TRUE, lex.order = TRUE))
  out <- lapply(split_df, function(chunk) {
    base <- chunk[1, by, drop = FALSE]
    row <- base
    row$n <- nrow(chunk)
    row$available_metric_slots <- sum(!is.na(as.matrix(chunk[win_cols])))
    row$win_metric_slots <- sum(as.matrix(chunk[win_cols]), na.rm = TRUE)
    row$loss_metric_slots <- row$available_metric_slots - row$win_metric_slots
    row$win_share <- if (row$available_metric_slots > 0) {
      row$win_metric_slots / row$available_metric_slots
    } else {
      NA_real_
    }
    row$net_advantage <- row$win_metric_slots - row$loss_metric_slots

    for (metric in metric_cols) {
      vals <- suppressWarnings(as.numeric(chunk[[metric]]))
      row[[paste0(metric, "_available_n")]] <- sum(!is.na(vals))
      row[[paste0(metric, "_median")]] <- safe_median(vals)
      row[[paste0(metric, "_mean")]] <- if (all(is.na(vals))) NA_real_ else mean(vals, na.rm = TRUE)
    }

    for (metric in win_cols) {
      vals <- chunk[[metric]]
      row[[paste0(metric, "_available_n")]] <- sum(!is.na(vals))
      row[[metric]] <- sum(as.logical(vals), na.rm = TRUE)
    }

    row
  })
  do.call(rbind, out)
}

build_case_scores <- function(df, win_cols, score_name) {
  win_mat <- as.matrix(df[win_cols])
  available <- rowSums(!is.na(win_mat))
  wins <- rowSums(win_mat, na.rm = TRUE)
  losses <- available - wins
  df[[paste0(score_name, "_available_metrics")]] <- available
  df[[paste0(score_name, "_wins")]] <- wins
  df[[paste0(score_name, "_losses")]] <- losses
  df[[paste0(score_name, "_net")]] <- wins - losses
  df
}

input_dir <- file.path("tools", "merge_reports", "original288_metric_comparison_20260409")
out_dir <- input_dir
ensure_dir_diag(out_dir)

static_pairs <- utils::read.csv(file.path(input_dir, "original288_static_metric_pair_comparison_20260409.csv"), stringsAsFactors = FALSE)
dynamic_pairs <- utils::read.csv(file.path(input_dir, "original288_dynamic_metric_pair_comparison_20260409.csv"), stringsAsFactors = FALSE)

static_win_cols <- c("exal_better_q_rmse", "exal_better_cie", "exal_better_beta_rmse", "exal_better_beta_coverage")
static_metric_cols <- c(
  "q_rmse_delta_exal_minus_al",
  "cie_delta_exal_minus_al",
  "beta_rmse_delta_exal_minus_al",
  "beta_coverage_gap_delta_exal_minus_al",
  "runtime_ratio_exal_over_al"
)
dynamic_win_cols <- c("exdqlm_better_q_rmse", "exdqlm_better_pplc", "exdqlm_better_crps", "exdqlm_better_interval_score", "exdqlm_better_coverage95")
dynamic_metric_cols <- c(
  "q_rmse_delta_exdqlm_minus_dqlm",
  "pplc_delta_exdqlm_minus_dqlm",
  "crps_delta_exdqlm_minus_dqlm",
  "interval_score_delta_exdqlm_minus_dqlm",
  "coverage95_gap_delta_exdqlm_minus_dqlm",
  "runtime_ratio_exdqlm_over_dqlm"
)

static_pairs <- build_case_scores(static_pairs, static_win_cols, "static_case")
dynamic_pairs <- build_case_scores(dynamic_pairs, dynamic_win_cols, "dynamic_case")

static_cluster_summary <- summarize_groups(
  static_pairs,
  c("block", "prior_semantics", "inference"),
  static_metric_cols,
  static_win_cols
)

static_family_cluster <- summarize_groups(
  static_pairs,
  c("block", "prior_semantics", "inference", "family", "tau_label", "fit_size"),
  static_metric_cols,
  static_win_cols
)

dynamic_cluster_summary <- summarize_groups(
  dynamic_pairs,
  c("inference"),
  dynamic_metric_cols,
  dynamic_win_cols
)

dynamic_tau_cluster <- summarize_groups(
  dynamic_pairs,
  c("inference", "tau_label"),
  dynamic_metric_cols,
  dynamic_win_cols
)

dynamic_family_cluster <- summarize_groups(
  dynamic_pairs,
  c("inference", "family", "tau_label", "fit_size"),
  dynamic_metric_cols,
  dynamic_win_cols
)

static_best_cases <- static_pairs[order(-static_pairs$static_case_net, static_pairs$q_rmse_delta_exal_minus_al), , drop = FALSE]
static_worst_cases <- static_pairs[order(static_pairs$static_case_net, -static_pairs$q_rmse_delta_exal_minus_al), , drop = FALSE]
dynamic_best_cases <- dynamic_pairs[order(-dynamic_pairs$dynamic_case_net, dynamic_pairs$q_rmse_delta_exdqlm_minus_dqlm), , drop = FALSE]
dynamic_worst_cases <- dynamic_pairs[order(dynamic_pairs$dynamic_case_net, -dynamic_pairs$q_rmse_delta_exdqlm_minus_dqlm), , drop = FALSE]

utils::write.csv(static_cluster_summary, file.path(out_dir, "original288_static_metric_cluster_summary_20260409.csv"), row.names = FALSE)
utils::write.csv(static_family_cluster, file.path(out_dir, "original288_static_metric_cluster_detail_20260409.csv"), row.names = FALSE)
utils::write.csv(dynamic_cluster_summary, file.path(out_dir, "original288_dynamic_metric_cluster_summary_20260409.csv"), row.names = FALSE)
utils::write.csv(dynamic_tau_cluster, file.path(out_dir, "original288_dynamic_metric_cluster_by_tau_20260409.csv"), row.names = FALSE)
utils::write.csv(dynamic_family_cluster, file.path(out_dir, "original288_dynamic_metric_cluster_detail_20260409.csv"), row.names = FALSE)
utils::write.csv(utils::head(static_best_cases, 20), file.path(out_dir, "original288_static_metric_best_cases_20260409.csv"), row.names = FALSE)
utils::write.csv(utils::head(static_worst_cases, 20), file.path(out_dir, "original288_static_metric_worst_cases_20260409.csv"), row.names = FALSE)
utils::write.csv(utils::head(dynamic_best_cases, 20), file.path(out_dir, "original288_dynamic_metric_best_cases_20260409.csv"), row.names = FALSE)
utils::write.csv(utils::head(dynamic_worst_cases, 20), file.path(out_dir, "original288_dynamic_metric_worst_cases_20260409.csv"), row.names = FALSE)

cat(sprintf("Wrote cluster diagnosis outputs to %s\n", out_dir))

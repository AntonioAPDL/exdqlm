#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_original288_recovery_helpers_20260405.R")

carry_in <- "tools/merge_reports/LOCAL_original288_carryforward_selection_v8_20260410.csv"
status_in <- "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_restored_closure_manifest_status_20260410.csv"

carry_out <- "tools/merge_reports/LOCAL_original288_carryforward_selection_v9_20260411.csv"
accepted_delta_out <- "tools/merge_reports/LOCAL_original288_dynamic_restored_selection_update_20260411.csv"
row_health_out <- "tools/merge_reports/LOCAL_original288_row_health_v9_20260411.csv"
summary_out <- "tools/merge_reports/LOCAL_original288_health_summary_v9_20260411.csv"
block_status_out <- "tools/merge_reports/LOCAL_original288_recovery_block_status_v9_20260411.csv"
method_breakdown_out <- "tools/merge_reports/LOCAL_original288_health_breakdown_by_method_v9_20260411.csv"
unresolved_out <- "tools/merge_reports/LOCAL_original288_unresolved_inventory_v9_20260411.csv"
unresolved_dynamic_out <- "tools/merge_reports/LOCAL_original288_unresolved_dynamic_inventory_v9_20260411.csv"

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

first_numeric_col_dynamic_promote <- function(x) {
  if (is.null(dim(x))) return(as.numeric(x))
  as.numeric(x[, 1])
}

interval_score_vec_dynamic_promote <- function(observed, lower, upper, level = 95) {
  alpha <- 1 - level / 100
  width <- upper - lower
  lower_penalty <- (2 / alpha) * (lower - observed) * (observed < lower)
  upper_penalty <- (2 / alpha) * (observed - upper) * (observed > upper)
  width + lower_penalty + upper_penalty
}

check_loss_vec_dynamic_promote <- function(p0, residual) {
  residual * (p0 - (residual < 0))
}

.crps_row_dynamic_promote <- function(y_true, draws_vec) {
  z <- sort(as.numeric(draws_vec))
  z <- z[is.finite(z)]
  m <- length(z)
  if (m < 2L || !is.finite(y_true)) {
    return(NA_real_)
  }
  mean(abs(z - y_true)) - sum((2 * seq_len(m) - m - 1) * z) / (m^2)
}

.crps_vec_dynamic_promote <- function(y_true, draws_mat) {
  draws_mat <- as.matrix(draws_mat)
  stopifnot(length(y_true) == nrow(draws_mat))
  vapply(seq_len(nrow(draws_mat)), function(i) {
    .crps_row_dynamic_promote(y_true[[i]], draws_mat[i, ])
  }, numeric(1))
}

coverage_gap_dynamic_promote <- function(x, target = 0.95) {
  abs(x - target)
}

extract_dynamic_metrics_from_paths <- function(fit_path, sim_path) {
  fit_raw <- readRDS(fit_path)
  fit_obj <- fit_raw$fit %||% fit_raw
  sim <- readRDS(sim_path)

  y <- as.numeric(fit_obj$y %||% sim$y)
  q_truth <- first_numeric_col_dynamic_promote(sim$q)
  pred <- as.matrix(fit_obj$samp.post.pred)
  p0 <- as.numeric(fit_obj$p0)[1]

  q_fit <- apply(pred, 1, stats::quantile, probs = p0, na.rm = TRUE)
  q_rmse <- sqrt(mean((q_fit - q_truth) ^ 2, na.rm = TRUE))

  err <- matrix(y, nrow = length(y), ncol = ncol(pred)) - pred
  pplc <- sum(rowMeans(check_loss_vec_dynamic_promote(p0, err), na.rm = TRUE), na.rm = TRUE)
  crps <- mean(.crps_vec_dynamic_promote(y, pred), na.rm = TRUE)

  qq95 <- t(apply(pred, 1, stats::quantile, probs = c(0.025, 0.975), na.rm = TRUE))
  interval_score_mean <- mean(
    interval_score_vec_dynamic_promote(y, qq95[, 1], qq95[, 2], level = 95),
    na.rm = TRUE
  )
  coverage95 <- mean(y >= qq95[, 1] & y <= qq95[, 2], na.rm = TRUE)

  data.frame(
    q_rmse = q_rmse,
    pplc = pplc,
    crps = crps,
    interval_score_mean = interval_score_mean,
    coverage95 = coverage95,
    coverage95_gap = coverage_gap_dynamic_promote(coverage95),
    stringsAsFactors = FALSE
  )
}

carry <- read.csv(carry_in, stringsAsFactors = FALSE, check.names = FALSE)
status <- read.csv(status_in, stringsAsFactors = FALSE, check.names = FALSE)

winner_pool <- subset(
  status,
  accepted_compare == "better_than_accepted" &
    gate_current %in% c("PASS", "WARN") &
    normalize_bool_original288(healthy_current)
)

if (!nrow(winner_pool)) {
  stop("No dynamic restored-closure rows qualified for promotion.")
}

metric_list <- lapply(seq_len(nrow(winner_pool)), function(i) {
  extract_dynamic_metrics_from_paths(
    fit_path = winner_pool$candidate_fit_path_manifest[[i]],
    sim_path = winner_pool$sim_output_path[[i]]
  )
})
metric_df <- do.call(rbind, metric_list)
winner_pool$q_rmse_metric <- metric_df$q_rmse
winner_pool$pplc_metric <- metric_df$pplc
winner_pool$crps_metric <- metric_df$crps
winner_pool$interval_score_metric <- metric_df$interval_score_mean
winner_pool$coverage95_metric <- metric_df$coverage95
winner_pool$coverage95_gap_metric <- metric_df$coverage95_gap

winner_pool$gate_rank <- gate_rank_original288(winner_pool$gate_current)
winner_pool$metric_total_rank <- NA_real_
winner_pool$metric_win_slots <- NA_integer_
winner_pool$metric_loss_slots <- NA_integer_

split_case <- split(winner_pool, winner_pool$target_row_id)
winner_pool <- do.call(rbind, lapply(split_case, function(d) {
  d$q_rmse_rank <- rank(d$q_rmse_metric, ties.method = "min")
  d$pplc_rank <- rank(d$pplc_metric, ties.method = "min")
  d$crps_rank <- rank(d$crps_metric, ties.method = "min")
  d$interval_score_rank <- rank(d$interval_score_metric, ties.method = "min")
  d$coverage95_gap_rank <- rank(d$coverage95_gap_metric, ties.method = "min")
  d$runtime_rank <- rank(suppressWarnings(as.numeric(d$runtime_sec)), ties.method = "min")
  d$metric_total_rank <- d$q_rmse_rank +
    d$pplc_rank +
    d$crps_rank +
    d$interval_score_rank +
    d$coverage95_gap_rank
  metric_mat <- cbind(
    d$q_rmse_rank,
    d$pplc_rank,
    d$crps_rank,
    d$interval_score_rank,
    d$coverage95_gap_rank
  )
  d$metric_win_slots <- rowSums(metric_mat == 1, na.rm = TRUE)
  d$metric_loss_slots <- rowSums(metric_mat > 1, na.rm = TRUE)
  d
}))

winner_pool <- winner_pool[order(
  winner_pool$target_row_id,
  winner_pool$gate_rank,
  winner_pool$metric_total_rank,
  winner_pool$q_rmse_metric,
  winner_pool$pplc_metric,
  winner_pool$crps_metric,
  winner_pool$interval_score_metric,
  winner_pool$coverage95_gap_metric,
  suppressWarnings(as.numeric(winner_pool$runtime_sec)),
  winner_pool$row_id
), , drop = FALSE]

winners <- winner_pool[!duplicated(winner_pool$target_row_id), , drop = FALSE]
winners$selected_source_type <- "dynamic_restored_closure_20260410"
winners$selected_source_subtype <- winners$phase
winners$selected_candidate <- winners$planned_candidate_label
winners$selected_variant_tag <- "orig288_sync0p4p0_dynamic_restored_closure_20260410"
winners$selected_fit_path <- winners$candidate_fit_path_manifest
winners$selected_health_path <- winners$health_csv
winners$selected_summary_path <- winners$telemetry_csv
winners$source_path <- winners$health_csv
winners$selection_mode <- "promoted_dynamic_restored_closure"
winners$selection_reason <- sprintf(
  paste(
    "Promote dynamic restored-closure candidate %s after improving accepted carry-forward",
    "from %s to %s; winner chosen within case by gate, multi-metric rank, and runtime."
  ),
  winners$planned_candidate_label,
  winners$accepted_gate,
  winners$gate_current
)
winners$metric_sim_path_override <- winners$sim_output_path

utils::write.csv(
  winners[, c(
    "target_row_id", "original_case_key", "planned_candidate_label", "gate_current",
    "accepted_gate", "runtime_sec", "q_rmse_metric", "pplc_metric", "crps_metric",
    "interval_score_metric", "coverage95_metric", "coverage95_gap_metric",
    "metric_total_rank", "metric_win_slots", "metric_loss_slots",
    "selected_source_type", "selected_source_subtype", "selected_candidate",
    "selected_variant_tag", "selected_fit_path", "selected_health_path",
    "selected_summary_path", "source_path", "selection_mode", "selection_reason",
    "metric_sim_path_override"
  )],
  accepted_delta_out,
  row.names = FALSE,
  na = ""
)

carry2 <- carry
idx <- match(winners$original_case_key, carry2$original_case_key)
hit <- which(!is.na(idx))
if (!length(hit)) {
  stop("No accepted carryforward rows matched the dynamic restored-closure winners.")
}

carry2$selected_source_type[idx[hit]] <- winners$selected_source_type[hit]
carry2$selected_source_subtype[idx[hit]] <- winners$selected_source_subtype[hit]
carry2$selected_candidate[idx[hit]] <- winners$selected_candidate[hit]
carry2$selected_variant_tag[idx[hit]] <- winners$selected_variant_tag[hit]
carry2$selected_fit_path[idx[hit]] <- winners$selected_fit_path[hit]
carry2$selected_health_path[idx[hit]] <- winners$selected_health_path[hit]
carry2$selected_summary_path[idx[hit]] <- winners$selected_summary_path[hit]
carry2$source_path[idx[hit]] <- winners$source_path[hit]
carry2$gate_overall[idx[hit]] <- winners$gate_current[hit]
carry2$healthy[idx[hit]] <- normalize_bool_original288(winners$healthy_current[hit])
carry2$runtime_sec[idx[hit]] <- winners$runtime_sec[hit]
carry2$improved_over_baseline[idx[hit]] <-
  gate_rank_original288(winners$gate_current[hit]) <
  gate_rank_original288(carry2$baseline_gate_overall[idx[hit]])
carry2$selection_mode[idx[hit]] <- winners$selection_mode[hit]
carry2$selection_reason[idx[hit]] <- winners$selection_reason[hit]

carry2 <- carry2[order(
  carry2$block, carry2$family, carry2$tau, carry2$fit_size,
  carry2$prior_semantics, carry2$model, carry2$inference
), , drop = FALSE]
utils::write.csv(carry2, carry_out, row.names = FALSE, na = "")

count_gate_dynamic_promote <- function(x, gate) sum(x == gate, na.rm = TRUE)

row_health <- carry2[, c(
  "block", "root_kind", "family", "tau", "fit_size", "prior_semantics",
  "model", "inference", "method", "root_id", "original_scenario_key",
  "original_case_key", "baseline_gate_overall", "baseline_healthy",
  "selected_source_type", "selected_source_subtype", "selected_candidate",
  "selected_variant_tag", "selected_fit_path", "selected_health_path",
  "selected_summary_path", "source_path", "gate_overall", "healthy",
  "runtime_sec", "improved_over_baseline", "selection_mode",
  "selection_reason"
)]
utils::write.csv(row_health, row_health_out, row.names = FALSE, na = "")

summarise_slice_dynamic_promote <- function(df, label) {
  data.frame(
    slice = label,
    total = nrow(df),
    pass = count_gate_dynamic_promote(df$gate_overall, "PASS"),
    warn = count_gate_dynamic_promote(df$gate_overall, "WARN"),
    fail = count_gate_dynamic_promote(df$gate_overall, "FAIL"),
    healthy_true = sum(normalize_bool_original288(df$healthy)),
    healthy_false = sum(!normalize_bool_original288(df$healthy)),
    stringsAsFactors = FALSE
  )
}

summary_table <- rbind(
  summarise_slice_dynamic_promote(row_health, "overall"),
  summarise_slice_dynamic_promote(subset(row_health, block == "dynamic"), "dynamic"),
  summarise_slice_dynamic_promote(subset(row_health, block == "static_paper"), "static_paper"),
  summarise_slice_dynamic_promote(subset(row_health, block == "static_shrink"), "static_shrink")
)
utils::write.csv(summary_table, summary_out, row.names = FALSE, na = "")

block_status <- do.call(
  rbind,
  lapply(split(row_health, row_health$block), function(d) {
    data.frame(
      block = unique(d$block),
      total = nrow(d),
      pass = count_gate_dynamic_promote(d$gate_overall, "PASS"),
      warn = count_gate_dynamic_promote(d$gate_overall, "WARN"),
      fail = count_gate_dynamic_promote(d$gate_overall, "FAIL"),
      healthy_true = sum(normalize_bool_original288(d$healthy)),
      healthy_false = sum(!normalize_bool_original288(d$healthy)),
      stringsAsFactors = FALSE
    )
  })
)
utils::write.csv(block_status, block_status_out, row.names = FALSE, na = "")

method_breakdown <- do.call(
  rbind,
  lapply(split(row_health, paste(row_health$block, row_health$model, row_health$inference, sep = "::")), function(d) {
    data.frame(
      block = unique(d$block),
      model = unique(d$model),
      inference = unique(d$inference),
      total = nrow(d),
      pass = count_gate_dynamic_promote(d$gate_overall, "PASS"),
      warn = count_gate_dynamic_promote(d$gate_overall, "WARN"),
      fail = count_gate_dynamic_promote(d$gate_overall, "FAIL"),
      healthy_true = sum(normalize_bool_original288(d$healthy)),
      healthy_false = sum(!normalize_bool_original288(d$healthy)),
      stringsAsFactors = FALSE
    )
  })
)
utils::write.csv(method_breakdown, method_breakdown_out, row.names = FALSE, na = "")

unresolved <- subset(row_health, gate_overall == "FAIL" | !normalize_bool_original288(healthy))
utils::write.csv(unresolved, unresolved_out, row.names = FALSE, na = "")
utils::write.csv(subset(unresolved, block == "dynamic"), unresolved_dynamic_out, row.names = FALSE, na = "")

cat(sprintf(
  paste(
    "DYNAMIC_RESTORED_PROMOTION winners=%d accepted=%d/%d dynamic=%d/%d",
    "remaining_dynamic_fail=%d"
  ),
  nrow(winners),
  summary_table$healthy_true[summary_table$slice == "overall"],
  summary_table$total[summary_table$slice == "overall"],
  summary_table$healthy_true[summary_table$slice == "dynamic"],
  summary_table$total[summary_table$slice == "dynamic"],
  summary_table$healthy_false[summary_table$slice == "dynamic"]
))

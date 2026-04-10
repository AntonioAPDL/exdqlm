#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

ensure_dir_prop <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  invisible(path)
}

split_selector <- function(x) {
  x <- as.character(x)[1]
  if (!nzchar(x) || identical(x, "*")) return("*")
  trimws(strsplit(x, "\\|", fixed = FALSE)[[1]])
}

selector_match <- function(value, selector) {
  sel <- split_selector(selector)
  if (identical(sel, "*")) return(rep(TRUE, length(value)))
  value %in% sel
}

safe_num <- function(x) suppressWarnings(as.numeric(x))

score_cluster <- function(df, scope) {
  if (!nrow(df)) return(df)
  if (scope == "static") {
    df$cluster_signal <- ifelse(df$net_advantage >= 20, "strong_positive",
      ifelse(df$net_advantage >= 1, "positive",
        ifelse(df$net_advantage <= -10, "strong_negative",
          ifelse(df$net_advantage <= -1, "negative", "mixed"))))
  } else {
    df$cluster_signal <- ifelse(df$net_advantage >= 10, "strong_positive",
      ifelse(df$net_advantage >= 1, "positive",
        ifelse(df$net_advantage <= -10, "strong_negative",
          ifelse(df$net_advantage <= -1, "negative", "mixed"))))
  }
  df
}

root_dir <- "."
reports_dir <- file.path(root_dir, "reports", "static_exal_tuning_20260409")
diag_dir <- file.path(root_dir, "tools", "merge_reports", "original288_metric_comparison_20260409")
ensure_dir_prop(reports_dir)

rules <- utils::read.csv(file.path(reports_dir, "original288_propagation_rules_20260409.csv"), stringsAsFactors = FALSE)
static_summary <- utils::read.csv(file.path(diag_dir, "original288_static_metric_cluster_summary_20260409.csv"), stringsAsFactors = FALSE)
static_detail <- utils::read.csv(file.path(diag_dir, "original288_static_metric_cluster_detail_20260409.csv"), stringsAsFactors = FALSE)
dynamic_summary <- utils::read.csv(file.path(diag_dir, "original288_dynamic_metric_cluster_summary_20260409.csv"), stringsAsFactors = FALSE)
dynamic_detail <- utils::read.csv(file.path(diag_dir, "original288_dynamic_metric_cluster_detail_20260409.csv"), stringsAsFactors = FALSE)

static_summary <- score_cluster(static_summary, "static")
static_detail <- score_cluster(static_detail, "static")
dynamic_summary <- score_cluster(dynamic_summary, "dynamic")
dynamic_detail <- score_cluster(dynamic_detail, "dynamic")

expand_rule <- function(rule_row) {
  is_dynamic <- identical(rule_row$root_kind[[1]], "dynamic")
  source_df <- if (is_dynamic) dynamic_detail else static_detail

  keep <- rep(TRUE, nrow(source_df))
  if (!is_dynamic) {
    keep <- keep & selector_match(source_df$block, rule_row$block[[1]])
    keep <- keep & selector_match(source_df$prior_semantics, rule_row$prior_semantics[[1]])
  } else {
    keep <- keep & selector_match(source_df$inference, rule_row$inference[[1]])
  }
  keep <- keep & selector_match(source_df$inference, rule_row$inference[[1]])
  keep <- keep & selector_match(source_df$tau_label, rule_row$tau_selector[[1]])
  keep <- keep & selector_match(source_df$family, rule_row$family_selector[[1]])
  keep <- keep & selector_match(as.character(source_df$fit_size), rule_row$fit_size_selector[[1]])

  matched <- source_df[keep, , drop = FALSE]
  if (!nrow(matched)) return(data.frame())

  out <- data.frame(
    rule_id = rule_row$rule_id[[1]],
    phase = rule_row$phase[[1]],
    priority = safe_num(rule_row$priority[[1]]),
    action = rule_row$action[[1]],
    root_kind = rule_row$root_kind[[1]],
    block = if ("block" %in% names(matched)) matched$block else NA_character_,
    prior_semantics = if ("prior_semantics" %in% names(matched)) matched$prior_semantics else NA_character_,
    inference = matched$inference,
    family = matched$family,
    tau_label = matched$tau_label,
    fit_size = matched$fit_size,
    target_profile = rule_row$target_profile[[1]],
    audit_required = as.logical(rule_row$audit_required[[1]]),
    hold_fixed = as.logical(rule_row$hold_fixed[[1]]),
    target_behavior = rule_row$target_behavior[[1]],
    rationale = rule_row$rationale[[1]],
    cluster_signal = matched$cluster_signal,
    available_metric_slots = matched$available_metric_slots,
    win_metric_slots = matched$win_metric_slots,
    loss_metric_slots = matched$loss_metric_slots,
    win_share = matched$win_share,
    net_advantage = matched$net_advantage,
    stringsAsFactors = FALSE
  )

  if (is_dynamic) {
    out$q_rmse_median_delta = matched$q_rmse_delta_exdqlm_minus_dqlm_median
    out$loss_metric_median_delta = matched$pplc_delta_exdqlm_minus_dqlm_median
    out$crps_median_delta = matched$crps_delta_exdqlm_minus_dqlm_median
    out$interval_median_delta = matched$interval_score_delta_exdqlm_minus_dqlm_median
    out$coverage_gap_median_delta = matched$coverage95_gap_delta_exdqlm_minus_dqlm_median
    out$runtime_ratio_median = matched$runtime_ratio_exdqlm_over_dqlm_median
  } else {
    out$q_rmse_median_delta = matched$q_rmse_delta_exal_minus_al_median
    out$loss_metric_median_delta = if ("cie_delta_exal_minus_al_median" %in% names(matched)) matched$cie_delta_exal_minus_al_median else NA_real_
    out$crps_median_delta = matched$beta_rmse_delta_exal_minus_al_median
    out$interval_median_delta = NA_real_
    out$coverage_gap_median_delta = matched$beta_coverage_gap_delta_exal_minus_al_median
    out$runtime_ratio_median = matched$runtime_ratio_exal_over_al_median
  }

  out
}

schedule_rows <- lapply(seq_len(nrow(rules)), function(i) expand_rule(rules[i, , drop = FALSE]))
schedule <- do.call(rbind, schedule_rows)
schedule <- schedule[order(schedule$priority, schedule$action, schedule$root_kind, schedule$inference, schedule$tau_label, schedule$family, schedule$fit_size), , drop = FALSE]

workstream_summary <- aggregate(
  cbind(cluster_count = rep(1, nrow(schedule)), available_metric_slots, win_metric_slots, loss_metric_slots) ~
    phase + priority + action + root_kind + target_profile + audit_required + hold_fixed,
  data = schedule,
  FUN = sum
)
workstream_summary$win_share <- ifelse(
  workstream_summary$available_metric_slots > 0,
  workstream_summary$win_metric_slots / workstream_summary$available_metric_slots,
  NA_real_
)
workstream_summary$net_advantage <- workstream_summary$win_metric_slots - workstream_summary$loss_metric_slots

legacy_freeze <- subset(schedule, action == "freeze_legacy")
rebuild_required <- subset(schedule, action == "rebuild_required")
hold_fixed <- subset(schedule, hold_fixed)
audit_blockers <- subset(schedule, audit_required)

utils::write.csv(schedule, file.path(reports_dir, "original288_propagation_schedule_20260409.csv"), row.names = FALSE)
utils::write.csv(workstream_summary, file.path(reports_dir, "original288_propagation_workstreams_20260409.csv"), row.names = FALSE)
utils::write.csv(legacy_freeze, file.path(reports_dir, "original288_propagation_legacy_freeze_20260409.csv"), row.names = FALSE)
utils::write.csv(rebuild_required, file.path(reports_dir, "original288_propagation_rebuild_required_20260409.csv"), row.names = FALSE)
utils::write.csv(hold_fixed, file.path(reports_dir, "original288_propagation_hold_fixed_20260409.csv"), row.names = FALSE)
utils::write.csv(audit_blockers, file.path(reports_dir, "original288_propagation_audit_blockers_20260409.csv"), row.names = FALSE)

cat(sprintf("Wrote propagation framework outputs to %s\n", reports_dir))

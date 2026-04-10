#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_original288_recovery_helpers_20260405.R")

working_baseline_in <- "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_working_baseline_20260410.csv"
final_status_in <- "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_final_closure_manifest_status_20260410.csv"

working_update_out <- "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_working_selection_update_v2_20260410.csv"
working_baseline_out <- "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_working_baseline_v2_20260410.csv"
working_summary_out <- "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_working_summary_v2_20260410.csv"
working_method_out <- "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_working_method_breakdown_v2_20260410.csv"
working_unresolved_out <- "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_working_unresolved_v2_20260410.csv"

working <- read.csv(working_baseline_in, stringsAsFactors = FALSE, check.names = FALSE)
final_status <- read.csv(final_status_in, stringsAsFactors = FALSE, check.names = FALSE)

safe_num_final_closure <- function(x, default = Inf) {
  v <- suppressWarnings(as.numeric(x)[1])
  if (is.finite(v)) v else default
}

safe_num_vec_final_closure <- function(x, default = Inf) {
  v <- suppressWarnings(as.numeric(x))
  v[!is.finite(v)] <- default
  v
}

safe_metric_final_closure <- function(path, metric_name, default = Inf) {
  if (!nzchar(path) || !file.exists(path)) return(default)
  x <- tryCatch(read.csv(path, stringsAsFactors = FALSE, check.names = FALSE), error = function(e) NULL)
  if (is.null(x) || !nrow(x) || !metric_name %in% names(x)) return(default)
  safe_num_final_closure(x[[metric_name]], default)
}

final_status$gate_rank <- gate_rank_original288(final_status$gate_current)
final_status$healthy_current <- normalize_bool_original288(final_status$healthy_current)
final_status$q_rmse_rank <- vapply(final_status$metrics_csv, safe_metric_final_closure, numeric(1), metric_name = "q_rmse")
final_status$beta_rmse_rank <- vapply(final_status$metrics_csv, safe_metric_final_closure, numeric(1), metric_name = "beta_rmse_mean")
final_status$beta_coverage_gap_rank <- vapply(final_status$metrics_csv, safe_metric_final_closure, numeric(1), metric_name = "beta_coverage_gap")
final_status$cie_rank <- -vapply(final_status$metrics_csv, safe_metric_final_closure, numeric(1), metric_name = "cie", default = -Inf)

winner_pool <- subset(
  final_status,
  rebuild_compare == "better_than_accepted" &
    gate_current %in% c("PASS", "WARN") &
    healthy_current
)

winner_pool <- winner_pool[order(
  suppressWarnings(as.integer(winner_pool$base_row_id)),
  winner_pool$gate_rank,
  winner_pool$q_rmse_rank,
  winner_pool$beta_rmse_rank,
  winner_pool$beta_coverage_gap_rank,
  winner_pool$cie_rank,
  safe_num_vec_final_closure(winner_pool$runtime_sec),
  suppressWarnings(as.integer(winner_pool$row_id))
), , drop = FALSE]

winners <- winner_pool[!duplicated(winner_pool$base_row_id), , drop = FALSE]
winners$rhsns_original_case_key <- winners$target_original_case_key
winners$accepted_original_case_key <- mapply(
  make_original_case_key_original288,
  root_kind = "static_shrink",
  family = winners$family,
  tau_label = winners$tau_label,
  fit_size = suppressWarnings(as.integer(winners$fit_size)),
  prior_semantics = "rhs",
  model = "exal",
  inference = "mcmc",
  USE.NAMES = FALSE
)
winners$selected_source_type <- "rhsns_exal_mcmc_final_closure_20260410"
winners$selected_source_subtype <- winners$phase
winners$selected_candidate <- sprintf("row_%04d", suppressWarnings(as.integer(winners$row_id)))
winners$selected_variant_tag <- "orig288_static_shrink_rhsns_exal_mcmc_final_closure_20260410"
winners$selected_fit_path <- winners$candidate_fit_path
winners$selected_health_path <- winners$health_csv
winners$selected_summary_path <- winners$health_csv
winners$selection_mode <- "promoted_rhsns_final_closure_working_baseline"
winners$selection_reason <- sprintf(
  paste(
    "Promote corrected rhs_ns final-closure row %s for %s after improving the",
    "rhs_ns working baseline from FAIL to %s."
  ),
  winners$selected_candidate,
  winners$rhsns_original_case_key,
  winners$gate_current
)

utils::write.csv(
  winners[, c(
    "base_row_id", "rhsns_original_case_key", "accepted_original_case_key",
    "family", "tau_label", "fit_size", "row_id", "phase", "profile_id_row",
    "gate_current", "accepted_compare", "rebuild_compare", "runtime_sec",
    "q_rmse_rank", "beta_rmse_rank", "beta_coverage_gap_rank", "cie_rank",
    "selected_source_type", "selected_source_subtype", "selected_candidate",
    "selected_variant_tag", "selected_fit_path", "selected_health_path",
    "selected_summary_path", "selection_mode", "selection_reason"
  )],
  working_update_out,
  row.names = FALSE,
  na = ""
)

working2 <- working
working2$working_update_source <- if ("working_update_source" %in% names(working2)) working2$working_update_source else rep(NA_character_, nrow(working2))
working2$working_update_subtype <- if ("working_update_subtype" %in% names(working2)) working2$working_update_subtype else rep(NA_character_, nrow(working2))
working2$working_update_row_id <- if ("working_update_row_id" %in% names(working2)) working2$working_update_row_id else rep(NA_integer_, nrow(working2))
working2$working_update_reason <- if ("working_update_reason" %in% names(working2)) working2$working_update_reason else rep(NA_character_, nrow(working2))

for (i in seq_len(nrow(winners))) {
  idx <- which(working2$row_id == suppressWarnings(as.integer(winners$base_row_id[i])))
  if (!length(idx)) next
  working2$profile_id_row[idx] <- winners$profile_id_row[i]
  if ("profile_id" %in% names(working2)) working2$profile_id[idx] <- winners$profile_id_row[i]
  working2$selected_variant_tag_row[idx] <- winners$selected_variant_tag[i]
  if ("selected_variant_tag" %in% names(working2)) working2$selected_variant_tag[idx] <- winners$selected_variant_tag[i]
  working2$candidate_fit_path_row[idx] <- winners$candidate_fit_path[i]
  if ("candidate_fit_path" %in% names(working2)) working2$candidate_fit_path[idx] <- winners$candidate_fit_path[i]
  working2$health_csv[idx] <- winners$health_csv[i]
  working2$metrics_csv[idx] <- winners$metrics_csv[i]
  working2$status_row[idx] <- winners$status[i]
  if ("status" %in% names(working2)) working2$status[idx] <- winners$status[i]
  working2$gate_overall[idx] <- winners$gate_current[i]
  if ("gate_current" %in% names(working2)) working2$gate_current[idx] <- winners$gate_current[i]
  working2$healthy[idx] <- winners$healthy_current[i]
  if ("healthy_current" %in% names(working2)) working2$healthy_current[idx] <- winners$healthy_current[i]
  working2$runtime_sec[idx] <- winners$runtime_sec[i]
  working2$error[idx] <- NA_character_
  working2$working_update_source[idx] <- winners$selected_source_type[i]
  working2$working_update_subtype[idx] <- winners$selected_source_subtype[i]
  working2$working_update_row_id[idx] <- suppressWarnings(as.integer(winners$row_id[i]))
  working2$working_update_reason[idx] <- winners$selection_reason[i]
}

utils::write.csv(working2, working_baseline_out, row.names = FALSE, na = "")

working_summary <- data.frame(
  slice = "static_shrink_rhsns_working",
  total = nrow(working2),
  pass = sum(working2$gate_overall == "PASS", na.rm = TRUE),
  warn = sum(working2$gate_overall == "WARN", na.rm = TRUE),
  fail = sum(working2$gate_overall == "FAIL", na.rm = TRUE),
  healthy_true = sum(normalize_bool_original288(working2$healthy)),
  healthy_false = sum(!normalize_bool_original288(working2$healthy)),
  stringsAsFactors = FALSE
)
utils::write.csv(working_summary, working_summary_out, row.names = FALSE, na = "")

working_method <- do.call(
  rbind,
  lapply(split(working2, paste(working2$model, working2$inference, sep = "::")), function(d) {
    data.frame(
      block = "static_shrink_rhsns_working",
      model = unique(d$model),
      inference = unique(d$inference),
      total = nrow(d),
      pass = sum(d$gate_overall == "PASS", na.rm = TRUE),
      warn = sum(d$gate_overall == "WARN", na.rm = TRUE),
      fail = sum(d$gate_overall == "FAIL", na.rm = TRUE),
      healthy_true = sum(normalize_bool_original288(d$healthy)),
      healthy_false = sum(!normalize_bool_original288(d$healthy)),
      stringsAsFactors = FALSE
    )
  })
)
utils::write.csv(working_method, working_method_out, row.names = FALSE, na = "")

working_unresolved <- subset(working2, gate_overall == "FAIL" | !normalize_bool_original288(working2$healthy))
utils::write.csv(working_unresolved, working_unresolved_out, row.names = FALSE, na = "")

cat(sprintf(
  "RHSNS_FINAL_CLOSURE_UPDATE working_promoted=%d working_rhsns=%d/%d unresolved_rhsns=%d\n",
  nrow(winners),
  working_summary$healthy_true[1],
  working_summary$total[1],
  working_summary$healthy_false[1]
))

#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_original288_recovery_helpers_20260405.R")

accepted_in <- "tools/merge_reports/LOCAL_original288_carryforward_selection_v9_20260411.csv"
rhsns_working_in <- "tools/merge_reports/LOCAL_original288_static_shrink_rhsns_working_baseline_v3_20260410.csv"
dynamic_delta_in <- "tools/merge_reports/LOCAL_original288_dynamic_restored_selection_update_20260411.csv"

comparison_out <- "tools/merge_reports/LOCAL_original288_comparison_selection_rhsns_v1_20260411.csv"
comparison_summary_out <- "tools/merge_reports/LOCAL_original288_comparison_selection_rhsns_summary_v1_20260411.csv"

accepted <- read.csv(accepted_in, stringsAsFactors = FALSE, check.names = FALSE)
rhsns <- read.csv(rhsns_working_in, stringsAsFactors = FALSE, check.names = FALSE)
dynamic_delta <- read.csv(dynamic_delta_in, stringsAsFactors = FALSE, check.names = FALSE)

rhsns$match_family <- rhsns$family %||% rhsns$family_row %||% rhsns$family_manifest
rhsns$match_tau <- if ("tau_label" %in% names(rhsns)) rhsns$tau_label else if ("tau_label_row" %in% names(rhsns)) rhsns$tau_label_row else rhsns$tau_label_manifest
rhsns$match_fit_size <- if ("fit_size" %in% names(rhsns)) rhsns$fit_size else if ("fit_size_row" %in% names(rhsns)) rhsns$fit_size_row else rhsns$fit_size_manifest
rhsns$match_model <- if ("model" %in% names(rhsns)) rhsns$model else if ("model_row" %in% names(rhsns)) rhsns$model_row else rhsns$model_manifest
rhsns$match_inference <- if ("inference" %in% names(rhsns)) rhsns$inference else if ("inference_row" %in% names(rhsns)) rhsns$inference_row else rhsns$inference_manifest

comparison <- accepted
comparison$metric_sim_path_override <- NA_character_
comparison$comparison_note <- NA_character_

if (nrow(dynamic_delta)) {
  dyn_idx <- match(dynamic_delta$original_case_key, comparison$original_case_key)
  dyn_hit <- which(!is.na(dyn_idx))
  comparison$metric_sim_path_override[dyn_idx[dyn_hit]] <- dynamic_delta$metric_sim_path_override[dyn_hit]
  comparison$comparison_note[dyn_idx[dyn_hit]] <- "dynamic restored-closure promotion with explicit sim_output override"
}

rhs_rows <- which(comparison$block == "static_shrink" & comparison$prior_semantics == "rhs")
if (length(rhs_rows) != 72L) {
  stop(sprintf("Expected 72 legacy rhs rows for comparison substitution, found %d.", length(rhs_rows)))
}

rhsns$key <- paste(rhsns$match_family, rhsns$match_tau, rhsns$match_fit_size, rhsns$match_model, rhsns$match_inference, sep = "__")
rhs_rows_key <- paste(
  comparison$family[rhs_rows],
  comparison$tau[rhs_rows],
  comparison$fit_size[rhs_rows],
  comparison$model[rhs_rows],
  comparison$inference[rhs_rows],
  sep = "__"
)
match_idx <- match(rhs_rows_key, rhsns$key)
if (any(is.na(match_idx))) {
  missing_keys <- unique(rhs_rows_key[is.na(match_idx)])
  stop(sprintf(
    "Missing rhs_ns working rows for %d comparison keys: %s",
    length(missing_keys),
    paste(missing_keys, collapse = ", ")
  ))
}

rhsns_matched <- rhsns[match_idx, , drop = FALSE]

comparison$prior_semantics[rhs_rows] <- "rhs_ns"
comparison$root_id[rhs_rows] <- rhsns_matched$target_root_id
comparison$original_scenario_key[rhs_rows] <- rhsns_matched$target_original_scenario_key
comparison$original_case_key[rhs_rows] <- rhsns_matched$target_original_case_key
comparison$selected_source_type[rhs_rows] <- ifelse(
  nzchar(rhsns_matched$working_update_source),
  rhsns_matched$working_update_source,
  rhsns_matched$selected_source_type
)
comparison$selected_source_subtype[rhs_rows] <- ifelse(
  nzchar(rhsns_matched$working_update_subtype),
  rhsns_matched$working_update_subtype,
  rhsns_matched$selected_source_subtype
)
comparison$selected_candidate[rhs_rows] <- rhsns_matched$selected_candidate
comparison$selected_variant_tag[rhs_rows] <- rhsns_matched$selected_variant_tag_row
comparison$selected_fit_path[rhs_rows] <- rhsns_matched$candidate_fit_path
comparison$selected_health_path[rhs_rows] <- rhsns_matched$health_csv
comparison$selected_summary_path[rhs_rows] <- rhsns_matched$metrics_csv
comparison$source_path[rhs_rows] <- rhsns_matched$health_csv
comparison$gate_overall[rhs_rows] <- rhsns_matched$gate_current
comparison$healthy[rhs_rows] <- normalize_bool_original288(rhsns_matched$healthy_current)
comparison$runtime_sec[rhs_rows] <- rhsns_matched$runtime_sec
comparison$improved_over_baseline[rhs_rows] <-
  gate_rank_original288(rhsns_matched$gate_current) <
  gate_rank_original288(comparison$baseline_gate_overall[rhs_rows])
comparison$selection_mode[rhs_rows] <- paste0("comparison_rhsns__", rhsns_matched$selection_mode)
comparison$selection_reason[rhs_rows] <- paste(
  "Comparison refresh substitutes the frozen legacy mixed-prior rhs row with",
  "the corrected rhs_ns working-branch row. Legacy rhs remains frozen and",
  "documented separately."
)
comparison$comparison_note[rhs_rows] <- "corrected rhs_ns working-branch substitution"

comparison <- comparison[order(
  comparison$block, comparison$family, comparison$tau, comparison$fit_size,
  comparison$prior_semantics, comparison$model, comparison$inference
), , drop = FALSE]

utils::write.csv(comparison, comparison_out, row.names = FALSE, na = "")

comparison_summary <- do.call(
  rbind,
  lapply(split(comparison, paste(comparison$block, comparison$prior_semantics, sep = "::")), function(d) {
    data.frame(
      block = unique(d$block),
      prior_semantics = unique(d$prior_semantics),
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
utils::write.csv(comparison_summary, comparison_summary_out, row.names = FALSE, na = "")

cat(sprintf(
  paste(
    "COMPARISON_SELECTION rhs_replaced=%d total=%d dynamic_sim_overrides=%d",
    "rhsns_healthy=%d/%d"
  ),
  length(rhs_rows),
  nrow(comparison),
  sum(nzchar(comparison$metric_sim_path_override)),
  sum(comparison$block == "static_shrink" & comparison$prior_semantics == "rhs_ns" & normalize_bool_original288(comparison$healthy)),
  sum(comparison$block == "static_shrink" & comparison$prior_semantics == "rhs_ns")
))

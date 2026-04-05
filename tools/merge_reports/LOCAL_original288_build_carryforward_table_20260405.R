#!/usr/bin/env Rscript

source("tools/merge_reports/LOCAL_original288_recovery_helpers_20260405.R")

registry_path <- "tools/merge_reports/LOCAL_original288_registry_v1_20260405.csv"
dynamic_harvest_path <- "tools/merge_reports/LOCAL_original288_dynamic_harvest_candidates_v1_20260405.csv"
candidate_pool_output_path <- "tools/merge_reports/LOCAL_original288_candidate_pool_v1_20260405.csv"
duplicate_groups_output_path <- "tools/merge_reports/LOCAL_original288_hybrid_static_duplicate_groups_v1_20260405.csv"
selection_output_path <- "tools/merge_reports/LOCAL_original288_carryforward_selection_v1_20260405.csv"

registry <- read.csv(registry_path, stringsAsFactors = FALSE)
hybrid <- read_hybrid291_candidates_original288()
static_refresh <- read_static_refresh_candidates_original288()
dynamic_harvest <- read.csv(dynamic_harvest_path, stringsAsFactors = FALSE)

candidate_pool <- rbind(
  hybrid[, c(
    "original_case_key", "original_scenario_key", "block", "family", "tau",
    "fit_size", "prior_semantics", "model", "inference",
    "candidate_source_type", "candidate_source_subtype", "source_rank",
    "selected_candidate", "selected_variant_tag", "selected_fit_path",
    "selected_health_path", "selected_summary_path", "source_path",
    "gate_overall", "healthy", "runtime_sec", "evidence_note"
  )],
  static_refresh[, c(
    "original_case_key", "original_scenario_key", "block", "family", "tau",
    "fit_size", "prior_semantics", "model", "inference",
    "candidate_source_type", "candidate_source_subtype", "source_rank",
    "selected_candidate", "selected_variant_tag", "selected_fit_path",
    "selected_health_path", "selected_summary_path", "source_path",
    "gate_overall", "healthy", "runtime_sec", "evidence_note"
  )],
  dynamic_harvest[, c(
    "original_case_key", "original_scenario_key", "block", "family", "tau",
    "fit_size", "prior_semantics", "model", "inference",
    "candidate_source_type", "candidate_source_subtype", "source_rank",
    "selected_candidate", "selected_variant_tag", "selected_fit_path",
    "selected_health_path", "selected_summary_path", "source_path",
    "gate_overall", "healthy", "runtime_sec", "evidence_note"
  )]
)

if (nrow(candidate_pool)) {
  candidate_pool <- candidate_pool[order(
    candidate_pool$original_case_key,
    gate_rank_original288(candidate_pool$gate_overall),
    candidate_pool$source_rank,
    ifelse(is.na(candidate_pool$runtime_sec), Inf, candidate_pool$runtime_sec),
    candidate_pool$selected_fit_path
  ), ]
  rownames(candidate_pool) <- NULL
}

write.csv(candidate_pool, candidate_pool_output_path, row.names = FALSE, na = "")

dup_groups <- subset(candidate_pool, block == "static_shrink")
if (nrow(dup_groups)) {
  split_dup <- split(dup_groups, dup_groups$original_case_key)
  dup_summary <- do.call(rbind, lapply(split_dup, function(d) {
    if (nrow(d) < 2) {
      return(NULL)
    }
    data.frame(
      original_case_key = d$original_case_key[1],
      family = d$family[1],
      tau = d$tau[1],
      fit_size = d$fit_size[1],
      prior_semantics = d$prior_semantics[1],
      model = d$model[1],
      inference = d$inference[1],
      candidate_rows = nrow(d),
      distinct_gate_count = length(unique(d$gate_overall)),
      distinct_fit_path_count = length(unique(d$selected_fit_path)),
      candidate_subtypes = paste(unique(d$candidate_source_subtype), collapse = "; "),
      gates = paste(unique(d$gate_overall), collapse = "; "),
      stringsAsFactors = FALSE
    )
  }))
  if (is.null(dup_summary)) {
    dup_summary <- data.frame()
  }
} else {
  dup_summary <- data.frame()
}

write.csv(dup_summary, duplicate_groups_output_path, row.names = FALSE, na = "")

selection_rows <- lapply(seq_len(nrow(registry)), function(i) {
  reg_row <- registry[i, , drop = FALSE]
  pool_case <- subset(candidate_pool, original_case_key == reg_row$original_case_key)
  selected <- choose_original288_candidate(reg_row, pool_case)
  cbind(
    reg_row[, c(
      "block", "root_kind", "family", "tau", "fit_size", "prior_semantics",
      "model", "inference", "method", "root_id", "original_scenario_key",
      "original_case_key", "baseline_signoff_path", "baseline_fit_path",
      "baseline_fit_path_exists", "baseline_gate_overall", "baseline_healthy",
      "baseline_status", "baseline_signoff_reason", "comparison_eligible",
      "convergence_certified", "execution_healthy"
    )],
    selected[, c(
      "selected_source_type", "selected_source_subtype", "selected_candidate",
      "selected_variant_tag", "selected_fit_path", "selected_health_path",
      "selected_summary_path", "source_path", "gate_overall", "healthy",
      "runtime_sec", "improved_over_baseline", "selection_mode",
      "selection_reason"
    )],
    stringsAsFactors = FALSE
  )
})

selection <- do.call(rbind, selection_rows)
selection <- selection[order(
  selection$root_kind, selection$family, selection$tau, selection$fit_size,
  selection$prior_semantics, selection$model, selection$inference
), ]
rownames(selection) <- NULL

write.csv(selection, selection_output_path, row.names = FALSE, na = "")

cat(sprintf("Wrote candidate pool to %s\n", candidate_pool_output_path))
cat(sprintf("Wrote static duplicate summary to %s\n", duplicate_groups_output_path))
cat(sprintf("Wrote corrected original-288 selection to %s\n", selection_output_path))
cat(sprintf("Rows: %d\n", nrow(selection)))

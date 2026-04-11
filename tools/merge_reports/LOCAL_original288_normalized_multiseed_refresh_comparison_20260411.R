#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_original288_normalized_multiseed_helpers_20260411.R")

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)

paths <- paths_original288_normalized_multiseed()

selection <- utils::read.csv(paths$selection, stringsAsFactors = FALSE, check.names = FALSE)
selected <- utils::read.csv(paths$full_selected, stringsAsFactors = FALSE, check.names = FALSE)

if (nrow(selected) != nrow(selection)) {
  stop(sprintf("selected winner table has %d rows but selection has %d rows", nrow(selected), nrow(selection)))
}

normalized <- merge(
  selection,
  selected,
  by = c("base_row_id", "original_case_key"),
  all.x = TRUE,
  sort = FALSE,
  suffixes = c("_baseline", "_selected")
)
normalized <- normalized[order(normalized$base_row_id), , drop = FALSE]

normalized$selected_source_type <- "normalized_multiseed_relaunch_20260411"
normalized$selected_source_subtype <- "selected_seed"
normalized$selected_candidate <- normalized$candidate_label
normalized$selected_variant_tag <- run_tag_original288_normalized_multiseed()
normalized$selected_fit_path <- normalized$candidate_fit_path
normalized$selected_health_path <- normalized$health_csv
normalized$selected_summary_path <- normalized$metrics_csv
normalized$source_path <- normalized$metrics_csv
normalized$gate_overall <- normalized$gate_current
normalized$healthy <- normalized$healthy_current
normalized$runtime_sec <- normalized$runtime_sec_current
normalized$improved_over_baseline <- normalized$accepted_compare == "better_than_accepted"
normalized$selection_mode <- "normalized_multiseed_selected"
normalized$selection_reason <- sprintf(
  "Select best of 4 deterministic seeds using gate, CRPS, primary accuracy, runtime, then seed from %s.",
  run_tag_original288_normalized_multiseed()
)
normalized$metric_sim_path_override <- NA_character_
normalized$comparison_note <- sprintf(
  "selected_seed_slot=%02d; selected_seed=%d; gate_rank=%d; crps=%.8f",
  as.integer(normalized$seed_slot),
  as.integer(normalized$seed),
  as.integer(normalized$gate_rank),
  as.numeric(normalized$crps_metric)
)

selection_cols <- c(
  "block","root_kind","family","tau","fit_size","prior_semantics","model","inference","method","root_id",
  "original_scenario_key","original_case_key","baseline_signoff_path","baseline_fit_path","baseline_fit_path_exists",
  "baseline_gate_overall","baseline_healthy","baseline_status","baseline_signoff_reason","comparison_eligible",
  "convergence_certified","execution_healthy","selected_source_type","selected_source_subtype","selected_candidate",
  "selected_variant_tag","selected_fit_path","selected_health_path","selected_summary_path","source_path",
  "gate_overall","healthy","runtime_sec","improved_over_baseline","selection_mode","selection_reason",
  "metric_sim_path_override","comparison_note"
)
for (nm in selection_cols) {
  if (!nm %in% names(normalized)) normalized[[nm]] <- NA
}

normalized_out <- normalized[, selection_cols, drop = FALSE]
utils::write.csv(normalized_out, paths$normalized_selection, row.names = FALSE)

selection_summary <- aggregate(
  list(
    total = rep(1L, nrow(normalized_out)),
    healthy = normalized_out$healthy,
    pass = normalized$gate_current == "PASS",
    warn = normalized$gate_current == "WARN",
    fail = normalized$gate_current == "FAIL",
    improved = normalized$accepted_compare == "better_than_accepted"
  ),
  by = list(block = normalized_out$block, model = normalized_out$model, inference = normalized_out$inference),
  FUN = function(x) sum(x, na.rm = TRUE)
)
utils::write.csv(selection_summary, paths$normalized_selection_summary, row.names = FALSE)

rc <- system2(
  "Rscript",
  args = c(
    "tools/merge_reports/LOCAL_original288_tablebacked_cluster_comparison_20260411.R",
    sprintf("--selection=%s", paths$normalized_selection),
    "--dynamic_update=",
    sprintf("--output_dir=%s", paths$comparison_output_dir),
    sprintf("--report=%s", paths$comparison_report)
  )
)
if (!is.null(rc) && rc != 0L) stop(sprintf("comparison refresh failed with code %s", rc))

cat(sprintf(
  "REFRESH normalized_selection=%s rows=%d comparison_report=%s\n",
  paths$normalized_selection,
  nrow(normalized_out),
  paths$comparison_report
))

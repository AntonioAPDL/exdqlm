#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_original288_dynamic_tt5000_postfix_repair_helpers_20260415.R")

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)

paths <- paths_original288_dynamic_tt5000_postfix_repair()

selection <- utils::read.csv(paths$current_selection, stringsAsFactors = FALSE, check.names = FALSE)
selection$base_row_id <- seq_len(nrow(selection))
selected <- utils::read.csv(paths$full_selected, stringsAsFactors = FALSE, check.names = FALSE)
manifest <- utils::read.csv(paths$full_manifest, stringsAsFactors = FALSE, check.names = FALSE)

manifest_keep <- manifest[, c(
  "row_id",
  "candidate_fit_path",
  "health_path",
  "metrics_path",
  "draws_path",
  "candidate_source_type",
  "candidate_source_subtype"
), drop = FALSE]
selected <- merge(selected, manifest_keep, by = "row_id", all.x = TRUE, sort = FALSE)

selection$row_index <- seq_len(nrow(selection))
target_keys <- unique(selected$original_case_key)
target_idx <- match(target_keys, selection$original_case_key)
if (anyNA(target_idx)) {
  stop("Could not locate one or more repaired cases in the current selection.")
}

selected <- selected[order(selected$base_row_id), , drop = FALSE]
for (i in seq_len(nrow(selected))) {
  key <- selected$original_case_key[i]
  idx <- match(key, selection$original_case_key)
  old_gate <- selection$gate_overall[idx]

  selection$selected_source_type[idx] <- "dynamic_tt5000_postfix_repair_20260415"
  selection$selected_source_subtype[idx] <- "selected_seed"
  selection$selected_candidate[idx] <- selected$candidate_label[i]
  selection$selected_variant_tag[idx] <- run_tag_original288_dynamic_tt5000_postfix_repair()
  selection$selected_fit_path[idx] <- selected$candidate_fit_path[i]
  selection$selected_health_path[idx] <- selected$health_path[i]
  selection$selected_summary_path[idx] <- selected$metrics_path[i]
  selection$source_path[idx] <- selected$metrics_path[i]
  selection$gate_overall[idx] <- selected$gate_current[i]
  selection$healthy[idx] <- selected$healthy_current[i]
  selection$runtime_sec[idx] <- selected$runtime_sec_current[i]
  selection$improved_over_baseline[idx] <-
    gate_rank_original288_dynamic_tt5000_postfix_repair(selected$gate_current[i]) <
    gate_rank_original288_dynamic_tt5000_postfix_repair(old_gate)
  selection$selection_mode[idx] <- "dynamic_tt5000_postfix_repair_selected"
  selection$selection_reason[idx] <- sprintf(
    "Repair unresolved dynamic TT5000 exact-spec replay case using staged exact-source plus historical TT5000 repair lane %s.",
    run_tag_original288_dynamic_tt5000_postfix_repair()
  )
  selection$comparison_note[idx] <- sprintf(
    "phase=%s; candidate=%s; seed_slot=%02d; seed=%d; gate=%s; crps=%.8f",
    selected$phase[i],
    selected$candidate_label[i],
    as.integer(selected$seed_slot[i]),
    as.integer(selected$seed[i]),
    selected$gate_current[i],
    as.numeric(selected$crps_metric[i])
  )
}

selection_out_cols <- c(
  "block","root_kind","family","tau","fit_size","prior_semantics","model","inference","method","root_id",
  "original_scenario_key","original_case_key","baseline_signoff_path","baseline_fit_path","baseline_fit_path_exists",
  "baseline_gate_overall","baseline_healthy","baseline_status","baseline_signoff_reason","comparison_eligible",
  "convergence_certified","execution_healthy","selected_source_type","selected_source_subtype","selected_candidate",
  "selected_variant_tag","selected_fit_path","selected_health_path","selected_summary_path","source_path",
  "gate_overall","healthy","runtime_sec","improved_over_baseline","selection_mode","selection_reason",
  "metric_sim_path_override","comparison_note"
)
for (nm in selection_out_cols) {
  if (!nm %in% names(selection)) selection[[nm]] <- NA
}
selection_out <- selection[, selection_out_cols, drop = FALSE]
utils::write.csv(selection_out, paths$repaired_selection, row.names = FALSE)

summary_df <- aggregate(
  list(
    total = rep(1L, nrow(selection_out)),
    healthy = selection_out$healthy,
    pass = selection_out$gate_overall == "PASS",
    warn = selection_out$gate_overall == "WARN",
    fail = selection_out$gate_overall == "FAIL"
  ),
  by = list(block = selection_out$block, model = selection_out$model, inference = selection_out$inference),
  FUN = function(x) sum(x, na.rm = TRUE)
)
utils::write.csv(summary_df, paths$repaired_selection_summary, row.names = FALSE)

rc <- system2(
  "Rscript",
  args = c(
    "tools/merge_reports/LOCAL_original288_tablebacked_cluster_comparison_20260411.R",
    sprintf("--selection=%s", paths$repaired_selection),
    "--dynamic_update=",
    sprintf("--output_dir=%s", paths$comparison_output_dir),
    sprintf("--report=%s", paths$comparison_report)
  )
)
if (!is.null(rc) && rc != 0L) stop(sprintf("comparison refresh failed with code %s", rc))

cat(sprintf("selection=%s\n", paths$repaired_selection))
cat(sprintf("report=%s\n", paths$comparison_report))

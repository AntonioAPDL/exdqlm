#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_original288_exactspec_multiseed_helpers_20260412.R")

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)

paths <- paths_original288_exactspec_multiseed()

selection <- utils::read.csv(paths$selection, stringsAsFactors = FALSE, check.names = FALSE)
selection$base_row_id <- seq_len(nrow(selection))
selected <- utils::read.csv(paths$full_selected, stringsAsFactors = FALSE, check.names = FALSE)

if (nrow(selected) != nrow(selection)) {
  stop(sprintf("selected winner table has %d rows but selection has %d rows", nrow(selected), nrow(selection)))
}

refreshed <- merge(
  selection,
  selected,
  by = c("base_row_id", "original_case_key"),
  all.x = TRUE,
  sort = FALSE,
  suffixes = c("_baseline", "_selected")
)
refreshed <- refreshed[order(refreshed$base_row_id), , drop = FALSE]

refreshed$selected_source_type <- "exactspec_multiseed_relaunch_20260412"
refreshed$selected_source_subtype <- "selected_seed"
refreshed$selected_candidate <- refreshed$candidate_label
refreshed$selected_variant_tag <- run_tag_original288_exactspec_multiseed()
refreshed$selected_fit_path <- refreshed$candidate_fit_path
refreshed$selected_health_path <- refreshed$health_csv
refreshed$selected_summary_path <- refreshed$metrics_csv
refreshed$source_path <- refreshed$metrics_csv
refreshed$gate_overall <- refreshed$gate_current
refreshed$healthy <- refreshed$healthy_current
refreshed$runtime_sec <- refreshed$runtime_sec_current
refreshed$improved_over_baseline <- refreshed$accepted_compare == "better_than_accepted"
refreshed$selection_mode <- "exactspec_multiseed_selected"
refreshed$selection_reason <- sprintf(
  "Replay exact prior row spec with only n.burn=5000, n.mcmc=20000, stored_posterior_draws=20000, and deterministic 4-seed selection under %s.",
  run_tag_original288_exactspec_multiseed()
)
refreshed$metric_sim_path_override <- NA_character_
refreshed$comparison_note <- sprintf(
  "selected_seed_slot=%02d; selected_seed=%d; gate=%s; crps=%.8f; primary_accuracy=%.8f",
  as.integer(refreshed$seed_slot),
  as.integer(refreshed$seed),
  as.character(refreshed$gate_current),
  as.numeric(refreshed$crps_metric),
  as.numeric(refreshed$primary_accuracy_metric)
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
  if (!nm %in% names(refreshed)) refreshed[[nm]] <- NA
}

refreshed_out <- refreshed[, selection_cols, drop = FALSE]
utils::write.csv(refreshed_out, paths$exactspec_selection, row.names = FALSE)

selection_summary <- aggregate(
  list(
    total = rep(1L, nrow(refreshed_out)),
    healthy = refreshed_out$healthy,
    pass = refreshed$gate_current == "PASS",
    warn = refreshed$gate_current == "WARN",
    fail = refreshed$gate_current == "FAIL",
    improved = refreshed$accepted_compare == "better_than_accepted"
  ),
  by = list(block = refreshed_out$block, model = refreshed_out$model, inference = refreshed_out$inference),
  FUN = function(x) sum(x, na.rm = TRUE)
)
utils::write.csv(selection_summary, paths$exactspec_selection_summary, row.names = FALSE)

rc <- system2(
  "Rscript",
  args = c(
    "tools/merge_reports/LOCAL_original288_tablebacked_cluster_comparison_20260411.R",
    sprintf("--selection=%s", paths$exactspec_selection),
    "--dynamic_update=",
    sprintf("--output_dir=%s", paths$comparison_output_dir),
    sprintf("--report=%s", paths$comparison_report)
  )
)
if (!is.null(rc) && rc != 0L) stop(sprintf("comparison refresh failed with code %s", rc))

cat(sprintf(
  "REFRESH exactspec_selection=%s rows=%d comparison_report=%s\n",
  paths$exactspec_selection,
  nrow(refreshed_out),
  paths$comparison_report
))

#!/usr/bin/env Rscript

source("tools/merge_reports/LOCAL_validation_campaign_comparison_helpers_20260405.R")

selection_path <- "tools/merge_reports/LOCAL_validation_campaign_selection_table_v1_20260405.csv"
comparison_long_path <- "tools/merge_reports/LOCAL_validation_campaign_comparison_long_v1_20260405.csv"
warn_inventory_path <- "tools/merge_reports/LOCAL_validation_campaign_warn_inventory_v1_20260405.csv"

selection <- read.csv(selection_path, check.names = FALSE, stringsAsFactors = FALSE)

rows <- lapply(seq_len(nrow(selection)), function(i) {
  vc_build_comparison_row_20260405(selection[i, , drop = FALSE])
})

comparison_long <- do.call(rbind, rows)
comparison_long <- comparison_long[order(
  comparison_long$root_kind,
  comparison_long$run_root_rel,
  comparison_long$inference,
  comparison_long$model
), ]

if (nrow(comparison_long) != 291L) {
  stop(sprintf("Comparison dataset must contain 291 rows, found %d", nrow(comparison_long)))
}

if (any(is.na(comparison_long$source_gate_matches_selected))) {
  warning("Some comparison rows do not have a source gate to compare against.")
}

gate_mismatch <- subset(
  comparison_long,
  !is.na(source_gate_matches_selected) & !source_gate_matches_selected
)
if (nrow(gate_mismatch)) {
  stop(sprintf("Found %d rows where selected gate does not match source evidence.", nrow(gate_mismatch)))
}

write.csv(comparison_long, comparison_long_path, row.names = FALSE, na = "")
write.csv(
  subset(
    comparison_long,
    gate_overall == "WARN",
    select = c(
      "case_key", "root_kind", "scope_label", "family", "tau_label",
      "fit_size", "inference", "model", "selected_pool",
      "selected_candidate", "selected_variant_tag", "gate_overall",
      "runtime_sec", "signoff_reason", "selection_reason",
      "provenance_source", "selected_health_path_rel"
    )
  ),
  warn_inventory_path,
  row.names = FALSE,
  na = ""
)

cat(sprintf("Wrote comparison-long dataset to %s\n", comparison_long_path))
cat(sprintf("Rows: %d total, WARN inventory rows: %d\n",
  nrow(comparison_long),
  sum(comparison_long$gate_overall == "WARN", na.rm = TRUE)
))

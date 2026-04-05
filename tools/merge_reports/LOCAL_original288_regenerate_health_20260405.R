#!/usr/bin/env Rscript

selection_path <- "tools/merge_reports/LOCAL_original288_carryforward_selection_v1_20260405.csv"
row_health_path <- "tools/merge_reports/LOCAL_original288_row_health_v1_20260405.csv"
summary_path <- "tools/merge_reports/LOCAL_original288_health_summary_v1_20260405.csv"
block_status_path <- "tools/merge_reports/LOCAL_original288_recovery_block_status_v1_20260405.csv"
method_breakdown_path <- "tools/merge_reports/LOCAL_original288_health_breakdown_by_method_v1_20260405.csv"
unresolved_path <- "tools/merge_reports/LOCAL_original288_unresolved_inventory_v1_20260405.csv"
unresolved_dynamic_path <- "tools/merge_reports/LOCAL_original288_unresolved_dynamic_inventory_v1_20260405.csv"

selection <- read.csv(selection_path, stringsAsFactors = FALSE)

count_gate <- function(x, gate) {
  sum(x == gate, na.rm = TRUE)
}

row_health <- selection[, c(
  "block", "root_kind", "family", "tau", "fit_size", "prior_semantics",
  "model", "inference", "method", "root_id", "original_scenario_key",
  "original_case_key", "baseline_gate_overall", "baseline_healthy",
  "selected_source_type", "selected_source_subtype", "selected_candidate",
  "selected_variant_tag", "selected_fit_path", "selected_health_path",
  "selected_summary_path", "source_path", "gate_overall", "healthy",
  "runtime_sec", "improved_over_baseline", "selection_mode",
  "selection_reason"
)]

write.csv(row_health, row_health_path, row.names = FALSE, na = "")

overall <- data.frame(
  slice = "overall",
  total = nrow(row_health),
  pass = count_gate(row_health$gate_overall, "PASS"),
  warn = count_gate(row_health$gate_overall, "WARN"),
  fail = count_gate(row_health$gate_overall, "FAIL"),
  healthy_true = sum(row_health$healthy == TRUE, na.rm = TRUE),
  healthy_false = sum(row_health$healthy == FALSE, na.rm = TRUE),
  stringsAsFactors = FALSE
)

by_block <- do.call(
  rbind,
  lapply(split(row_health, row_health$block), function(d) {
    data.frame(
      slice = unique(d$block),
      total = nrow(d),
      pass = count_gate(d$gate_overall, "PASS"),
      warn = count_gate(d$gate_overall, "WARN"),
      fail = count_gate(d$gate_overall, "FAIL"),
      healthy_true = sum(d$healthy == TRUE, na.rm = TRUE),
      healthy_false = sum(d$healthy == FALSE, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  })
)

method_breakdown <- do.call(
  rbind,
  lapply(split(row_health, paste(row_health$block, row_health$model, row_health$inference, sep = "::")), function(d) {
    data.frame(
      block = unique(d$block),
      model = unique(d$model),
      inference = unique(d$inference),
      total = nrow(d),
      pass = count_gate(d$gate_overall, "PASS"),
      warn = count_gate(d$gate_overall, "WARN"),
      fail = count_gate(d$gate_overall, "FAIL"),
      healthy_true = sum(d$healthy == TRUE, na.rm = TRUE),
      healthy_false = sum(d$healthy == FALSE, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  })
)

block_status <- do.call(
  rbind,
  lapply(split(row_health, row_health$block), function(d) {
    data.frame(
      block = unique(d$block),
      original_cells = nrow(d),
      healthy_via_promoted_selection = sum(d$selection_mode != "baseline_kept" & d$gate_overall != "FAIL", na.rm = TRUE),
      healthy_via_untouched_baseline = sum(d$selection_mode == "baseline_kept" & d$gate_overall != "FAIL", na.rm = TRUE),
      healthy_now = sum(d$gate_overall != "FAIL", na.rm = TRUE),
      unresolved = sum(d$gate_overall == "FAIL", na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  })
)

unresolved <- subset(
  row_health,
  gate_overall == "FAIL" | healthy == FALSE,
  select = c(
    "block", "root_kind", "family", "tau", "fit_size", "prior_semantics",
    "model", "inference", "method", "original_case_key",
    "baseline_gate_overall", "baseline_healthy", "selected_source_type",
    "selected_source_subtype", "selected_candidate", "selected_variant_tag",
    "selected_fit_path", "selected_health_path", "selected_summary_path",
    "source_path", "gate_overall", "healthy", "selection_mode",
    "selection_reason"
  )
)

unresolved_dynamic <- subset(unresolved, block == "dynamic")

summary_table <- rbind(overall, by_block)

write.csv(summary_table, summary_path, row.names = FALSE, na = "")
write.csv(block_status, block_status_path, row.names = FALSE, na = "")
write.csv(method_breakdown, method_breakdown_path, row.names = FALSE, na = "")
write.csv(unresolved, unresolved_path, row.names = FALSE, na = "")
write.csv(unresolved_dynamic, unresolved_dynamic_path, row.names = FALSE, na = "")

cat(sprintf("Wrote row health to %s\n", row_health_path))
cat(sprintf("Wrote health summary to %s\n", summary_path))
cat(sprintf("Wrote block status to %s\n", block_status_path))
cat(sprintf("Wrote unresolved inventory to %s\n", unresolved_path))
cat(sprintf("Overall: total=%d PASS=%d WARN=%d FAIL=%d\n", overall$total, overall$pass, overall$warn, overall$fail))

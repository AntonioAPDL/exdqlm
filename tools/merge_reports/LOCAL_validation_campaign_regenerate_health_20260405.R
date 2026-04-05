#!/usr/bin/env Rscript

selection_path <- "tools/merge_reports/LOCAL_validation_campaign_selection_table_v1_20260405.csv"
row_health_path <- "tools/merge_reports/LOCAL_validation_campaign_row_health_v1_20260405.csv"
summary_path <- "tools/merge_reports/LOCAL_validation_campaign_health_summary_v1_20260405.csv"
pool_breakdown_path <- "tools/merge_reports/LOCAL_validation_campaign_health_breakdown_by_pool_v1_20260405.csv"
model_breakdown_path <- "tools/merge_reports/LOCAL_validation_campaign_health_breakdown_by_method_v1_20260405.csv"

selection <- read.csv(selection_path, stringsAsFactors = FALSE)

row_health <- selection[, c(
  "case_key", "workstream", "scope_label", "row_id", "root_kind", "family",
  "tau_label", "fit_size", "inference", "model", "selected_pool",
  "selected_pool_group", "selected_candidate", "selected_variant_tag",
  "gate_overall", "healthy", "state", "runtime_sec", "prior_semantics",
  "selected_fit_path", "selected_health_path", "selected_summary_path",
  "provenance_source", "selection_reason"
)]

write.csv(row_health, row_health_path, row.names = FALSE, na = "")

count_gate <- function(x, gate) {
  sum(x == gate, na.rm = TRUE)
}

overall <- data.frame(
  slice = "overall",
  total = nrow(row_health),
  pass = count_gate(row_health$gate_overall, "PASS"),
  warn = count_gate(row_health$gate_overall, "WARN"),
  fail = count_gate(row_health$gate_overall, "FAIL"),
  healthy_true = sum(row_health$healthy == TRUE, na.rm = TRUE),
  healthy_false = sum(row_health$healthy == FALSE, na.rm = TRUE),
  runtime_sec_total = sum(row_health$runtime_sec, na.rm = TRUE),
  stringsAsFactors = FALSE
)

pool_breakdown <- do.call(
  rbind,
  lapply(split(row_health, row_health$selected_pool), function(d) {
    data.frame(
      slice = unique(d$selected_pool),
      total = nrow(d),
      pass = count_gate(d$gate_overall, "PASS"),
      warn = count_gate(d$gate_overall, "WARN"),
      fail = count_gate(d$gate_overall, "FAIL"),
      healthy_true = sum(d$healthy == TRUE, na.rm = TRUE),
      healthy_false = sum(d$healthy == FALSE, na.rm = TRUE),
      runtime_sec_total = sum(d$runtime_sec, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  })
)

method_breakdown <- do.call(
  rbind,
  lapply(split(row_health, paste(row_health$root_kind, row_health$inference, row_health$model, sep = "::")), function(d) {
    data.frame(
      root_kind = unique(d$root_kind),
      inference = unique(d$inference),
      model = unique(d$model),
      total = nrow(d),
      pass = count_gate(d$gate_overall, "PASS"),
      warn = count_gate(d$gate_overall, "WARN"),
      fail = count_gate(d$gate_overall, "FAIL"),
      healthy_true = sum(d$healthy == TRUE, na.rm = TRUE),
      healthy_false = sum(d$healthy == FALSE, na.rm = TRUE),
      runtime_sec_total = sum(d$runtime_sec, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  })
)

summary_table <- rbind(overall, pool_breakdown)

write.csv(summary_table, summary_path, row.names = FALSE, na = "")
write.csv(pool_breakdown, pool_breakdown_path, row.names = FALSE, na = "")
write.csv(method_breakdown, model_breakdown_path, row.names = FALSE, na = "")

cat(sprintf("Wrote row health to %s\n", row_health_path))
cat(sprintf("Wrote overall summary to %s\n", summary_path))
cat(sprintf("Overall: total=%d PASS=%d WARN=%d FAIL=%d\n", overall$total, overall$pass, overall$warn, overall$fail))

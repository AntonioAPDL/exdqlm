#!/usr/bin/env Rscript

source("tools/merge_reports/LOCAL_refreshed288_comparison_helpers_20260427.R")

comparison_long_path <- rf288_output_path_20260427("comparison_long")

inputs <- rf288_read_inputs_20260427()
comparison_long <- rf288_build_comparison_long_20260427(inputs)

rf288_write_csv_20260427(comparison_long, comparison_long_path)

cat(sprintf("Wrote refreshed288 comparison-long dataset to %s\n", comparison_long_path))
cat(sprintf("Rows: %d\n", nrow(comparison_long)))
cat(sprintf("Completed: %d\n", sum(comparison_long$completed, na.rm = TRUE)))
cat(sprintf("PASS/WARN/FAIL: %d/%d/%d\n",
  sum(comparison_long$gate_overall == "PASS", na.rm = TRUE),
  sum(comparison_long$gate_overall == "WARN", na.rm = TRUE),
  sum(comparison_long$gate_overall == "FAIL", na.rm = TRUE)
))

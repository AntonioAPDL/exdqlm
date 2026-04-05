#!/usr/bin/env Rscript

comparison_long_path <- "tools/merge_reports/LOCAL_validation_campaign_comparison_long_v1_20260405.csv"
static_broad_path <- "tools/merge_reports/LOCAL_validation_campaign_static_broad_comparison_v1_20260405.csv"
dynamic_broad_path <- "tools/merge_reports/LOCAL_validation_campaign_dynamic_broad_comparison_v1_20260405.csv"
model_pair_path <- "tools/merge_reports/LOCAL_validation_campaign_model_pair_comparison_v1_20260405.csv"
inference_pair_path <- "tools/merge_reports/LOCAL_validation_campaign_inference_pair_comparison_v1_20260405.csv"
audit_output_path <- "tools/merge_reports/LOCAL_validation_campaign_comparison_audit_v1_20260405.csv"

comparison_long <- read.csv(comparison_long_path, check.names = FALSE, stringsAsFactors = FALSE)
static_broad <- read.csv(static_broad_path, check.names = FALSE, stringsAsFactors = FALSE)
dynamic_broad <- read.csv(dynamic_broad_path, check.names = FALSE, stringsAsFactors = FALSE)
model_pair <- read.csv(model_pair_path, check.names = FALSE, stringsAsFactors = FALSE)
inference_pair <- read.csv(inference_pair_path, check.names = FALSE, stringsAsFactors = FALSE)

checks <- data.frame(
  check_name = c(
    "comparison_long_rows_291",
    "comparison_long_zero_fail",
    "comparison_long_all_source_gates_match",
    "static_broad_rows_72",
    "dynamic_broad_rows_3",
    "model_pair_rows_144",
    "inference_pair_rows_144"
  ),
  pass = c(
    nrow(comparison_long) == 291L,
    sum(comparison_long$gate_overall == "FAIL", na.rm = TRUE) == 0L,
    all(is.na(comparison_long$source_gate_matches_selected) | comparison_long$source_gate_matches_selected),
    nrow(static_broad) == 72L,
    nrow(dynamic_broad) == 3L,
    nrow(model_pair) == 144L,
    nrow(inference_pair) == 144L
  ),
  detail = c(
    sprintf("rows=%d", nrow(comparison_long)),
    sprintf("fail_rows=%d", sum(comparison_long$gate_overall == "FAIL", na.rm = TRUE)),
    sprintf("mismatches=%d", sum(!is.na(comparison_long$source_gate_matches_selected) & !comparison_long$source_gate_matches_selected)),
    sprintf("rows=%d", nrow(static_broad)),
    sprintf("rows=%d", nrow(dynamic_broad)),
    sprintf("rows=%d", nrow(model_pair)),
    sprintf("rows=%d", nrow(inference_pair))
  ),
  stringsAsFactors = FALSE
)

write.csv(checks, audit_output_path, row.names = FALSE, na = "")

if (!all(checks$pass)) {
  stop("Comparison reporting audit failed.")
}

cat(sprintf("Wrote comparison audit to %s\n", audit_output_path))
cat("All checks passed: yes\n")

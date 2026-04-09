#!/usr/bin/env Rscript

comparison_long_path <- "tools/merge_reports/LOCAL_original288_comparison_long_v1_20260408.csv"
static_scenario_path <- "tools/merge_reports/LOCAL_original288_static_scenario_comparison_v1_20260408.csv"
dynamic_scenario_path <- "tools/merge_reports/LOCAL_original288_dynamic_scenario_comparison_v1_20260408.csv"
static_model_pair_path <- "tools/merge_reports/LOCAL_original288_static_model_pair_comparison_v1_20260408.csv"
static_inference_pair_path <- "tools/merge_reports/LOCAL_original288_static_inference_pair_comparison_v1_20260408.csv"
dynamic_model_pair_path <- "tools/merge_reports/LOCAL_original288_dynamic_model_pair_comparison_v1_20260408.csv"
dynamic_inference_pair_path <- "tools/merge_reports/LOCAL_original288_dynamic_inference_pair_comparison_v1_20260408.csv"
warn_inventory_path <- "tools/merge_reports/LOCAL_original288_warn_inventory_v1_20260408.csv"
fail_inventory_path <- "tools/merge_reports/LOCAL_original288_fail_inventory_v1_20260408.csv"

health_summary_path <- "tools/merge_reports/LOCAL_original288_health_summary_v7_20260407.csv"
health_breakdown_path <- "tools/merge_reports/LOCAL_original288_health_breakdown_by_method_v7_20260407.csv"
unresolved_dynamic_path <- "tools/merge_reports/LOCAL_original288_unresolved_dynamic_inventory_v7_20260407.csv"

audit_output_path <- "tools/merge_reports/LOCAL_original288_comparison_audit_v1_20260408.csv"

comparison_long <- read.csv(comparison_long_path, check.names = FALSE, stringsAsFactors = FALSE)
static_scenario <- read.csv(static_scenario_path, check.names = FALSE, stringsAsFactors = FALSE)
dynamic_scenario <- read.csv(dynamic_scenario_path, check.names = FALSE, stringsAsFactors = FALSE)
static_model_pair <- read.csv(static_model_pair_path, check.names = FALSE, stringsAsFactors = FALSE)
static_inference_pair <- read.csv(static_inference_pair_path, check.names = FALSE, stringsAsFactors = FALSE)
dynamic_model_pair <- read.csv(dynamic_model_pair_path, check.names = FALSE, stringsAsFactors = FALSE)
dynamic_inference_pair <- read.csv(dynamic_inference_pair_path, check.names = FALSE, stringsAsFactors = FALSE)
warn_inventory <- read.csv(warn_inventory_path, check.names = FALSE, stringsAsFactors = FALSE)
fail_inventory <- read.csv(fail_inventory_path, check.names = FALSE, stringsAsFactors = FALSE)

health_summary <- read.csv(health_summary_path, check.names = FALSE, stringsAsFactors = FALSE)
health_breakdown <- read.csv(health_breakdown_path, check.names = FALSE, stringsAsFactors = FALSE)
unresolved_dynamic <- read.csv(unresolved_dynamic_path, check.names = FALSE, stringsAsFactors = FALSE)

comparison_summary <- do.call(rbind, lapply(split(comparison_long, comparison_long$block, drop = TRUE), function(chunk) {
  data.frame(
    slice = chunk$block[1],
    total = nrow(chunk),
    pass = sum(chunk$gate_overall == "PASS", na.rm = TRUE),
    warn = sum(chunk$gate_overall == "WARN", na.rm = TRUE),
    fail = sum(chunk$gate_overall == "FAIL", na.rm = TRUE),
    healthy_true = sum(isTRUE(chunk$healthy) | chunk$healthy == TRUE, na.rm = TRUE),
    healthy_false = sum(!(isTRUE(chunk$healthy) | chunk$healthy == TRUE), na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}))
comparison_summary <- rbind(
  data.frame(
    slice = "overall",
    total = nrow(comparison_long),
    pass = sum(comparison_long$gate_overall == "PASS", na.rm = TRUE),
    warn = sum(comparison_long$gate_overall == "WARN", na.rm = TRUE),
    fail = sum(comparison_long$gate_overall == "FAIL", na.rm = TRUE),
    healthy_true = sum(isTRUE(comparison_long$healthy) | comparison_long$healthy == TRUE, na.rm = TRUE),
    healthy_false = sum(!(isTRUE(comparison_long$healthy) | comparison_long$healthy == TRUE), na.rm = TRUE),
    stringsAsFactors = FALSE
  ),
  comparison_summary
)

comparison_breakdown <- do.call(rbind, lapply(split(comparison_long, interaction(comparison_long[c("block", "model", "inference")], drop = TRUE, lex.order = TRUE)), function(chunk) {
  data.frame(
    block = chunk$block[1],
    model = chunk$model[1],
    inference = chunk$inference[1],
    total = nrow(chunk),
    pass = sum(chunk$gate_overall == "PASS", na.rm = TRUE),
    warn = sum(chunk$gate_overall == "WARN", na.rm = TRUE),
    fail = sum(chunk$gate_overall == "FAIL", na.rm = TRUE),
    healthy_true = sum(isTRUE(chunk$healthy) | chunk$healthy == TRUE, na.rm = TRUE),
    healthy_false = sum(!(isTRUE(chunk$healthy) | chunk$healthy == TRUE), na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}))

comparison_summary <- comparison_summary[order(comparison_summary$slice), ]
health_summary <- health_summary[order(health_summary$slice), ]
comparison_breakdown <- comparison_breakdown[order(comparison_breakdown$block, comparison_breakdown$model, comparison_breakdown$inference), ]
health_breakdown <- health_breakdown[order(health_breakdown$block, health_breakdown$model, health_breakdown$inference), ]

comparison_summary_core <- comparison_summary[, c("slice", "total", "pass", "warn", "fail", "healthy_true", "healthy_false")]
health_summary_core <- health_summary[, c("slice", "total", "pass", "warn", "fail", "healthy_true", "healthy_false")]

comparison_breakdown_core <- comparison_breakdown[, c("block", "model", "inference", "total", "pass", "warn", "fail", "healthy_true", "healthy_false")]
health_breakdown_core <- health_breakdown[, c("block", "model", "inference", "total", "pass", "warn", "fail", "healthy_true", "healthy_false")]

fail_case_match <- identical(
  sort(fail_inventory$case_key),
  sort(unresolved_dynamic$original_case_key)
)

checks <- data.frame(
  check_name = c(
    "comparison_long_rows_288",
    "comparison_long_unique_case_keys",
    "comparison_long_fail_rows_6",
    "comparison_long_warn_rows_52",
    "comparison_long_source_gates_match_when_available",
    "scenario_rows_total_72",
    "static_scenario_rows_54",
    "dynamic_scenario_rows_18",
    "static_model_pair_rows_108",
    "static_inference_pair_rows_108",
    "dynamic_model_pair_rows_36",
    "dynamic_inference_pair_rows_36",
    "warn_inventory_rows_52",
    "fail_inventory_rows_6",
    "health_summary_matches_v7",
    "health_breakdown_matches_v7",
    "fail_inventory_matches_unresolved_dynamic_v7"
  ),
  pass = c(
    nrow(comparison_long) == 288L,
    !anyDuplicated(comparison_long$case_key),
    sum(comparison_long$gate_overall == "FAIL", na.rm = TRUE) == 6L,
    sum(comparison_long$gate_overall == "WARN", na.rm = TRUE) == 52L,
    all(is.na(comparison_long$source_gate_matches_selected) | comparison_long$source_gate_matches_selected),
    (nrow(static_scenario) + nrow(dynamic_scenario)) == 72L,
    nrow(static_scenario) == 54L,
    nrow(dynamic_scenario) == 18L,
    nrow(static_model_pair) == 108L,
    nrow(static_inference_pair) == 108L,
    nrow(dynamic_model_pair) == 36L,
    nrow(dynamic_inference_pair) == 36L,
    nrow(warn_inventory) == 52L,
    nrow(fail_inventory) == 6L,
    isTRUE(all.equal(comparison_summary_core, health_summary_core, check.attributes = FALSE)),
    isTRUE(all.equal(comparison_breakdown_core, health_breakdown_core, check.attributes = FALSE)),
    fail_case_match
  ),
  detail = c(
    sprintf("rows=%d", nrow(comparison_long)),
    sprintf("duplicate_case_keys=%d", sum(duplicated(comparison_long$case_key))),
    sprintf("fail_rows=%d", sum(comparison_long$gate_overall == "FAIL", na.rm = TRUE)),
    sprintf("warn_rows=%d", sum(comparison_long$gate_overall == "WARN", na.rm = TRUE)),
    sprintf("mismatches=%d", sum(!is.na(comparison_long$source_gate_matches_selected) & !comparison_long$source_gate_matches_selected)),
    sprintf("rows=%d", nrow(static_scenario) + nrow(dynamic_scenario)),
    sprintf("rows=%d", nrow(static_scenario)),
    sprintf("rows=%d", nrow(dynamic_scenario)),
    sprintf("rows=%d", nrow(static_model_pair)),
    sprintf("rows=%d", nrow(static_inference_pair)),
    sprintf("rows=%d", nrow(dynamic_model_pair)),
    sprintf("rows=%d", nrow(dynamic_inference_pair)),
    sprintf("rows=%d", nrow(warn_inventory)),
    sprintf("rows=%d", nrow(fail_inventory)),
    sprintf("comparison_rows=%d; summary_rows=%d", nrow(comparison_summary_core), nrow(health_summary_core)),
    sprintf("comparison_rows=%d; breakdown_rows=%d", nrow(comparison_breakdown_core), nrow(health_breakdown_core)),
    sprintf("match=%s; fail_rows=%d; unresolved_rows=%d", fail_case_match, nrow(fail_inventory), nrow(unresolved_dynamic))
  ),
  stringsAsFactors = FALSE
)

write.csv(checks, audit_output_path, row.names = FALSE, na = "")

if (!all(checks$pass)) {
  stop("Original288 comparison reporting audit failed.")
}

cat(sprintf("Wrote original288 comparison audit to %s\n", audit_output_path))
cat("All checks passed: yes\n")

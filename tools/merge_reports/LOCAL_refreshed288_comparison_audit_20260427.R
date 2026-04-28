#!/usr/bin/env Rscript

source("tools/merge_reports/LOCAL_refreshed288_comparison_helpers_20260427.R")

comparison_long_path <- rf288_output_path_20260427("comparison_long")
static_scenario_path <- rf288_output_path_20260427("static_scenario_comparison")
dynamic_scenario_path <- rf288_output_path_20260427("dynamic_scenario_comparison")
static_model_pair_path <- rf288_output_path_20260427("static_model_pair_comparison")
static_inference_pair_path <- rf288_output_path_20260427("static_inference_pair_comparison")
dynamic_model_pair_path <- rf288_output_path_20260427("dynamic_model_pair_comparison")
dynamic_inference_pair_path <- rf288_output_path_20260427("dynamic_inference_pair_comparison")
warn_inventory_path <- rf288_output_path_20260427("warn_inventory")
fail_inventory_path <- rf288_output_path_20260427("fail_inventory")
audit_output_path <- rf288_output_path_20260427("comparison_audit")

comparison_long <- rf288_read_csv_20260427(comparison_long_path)
static_scenario <- rf288_read_csv_20260427(static_scenario_path)
dynamic_scenario <- rf288_read_csv_20260427(dynamic_scenario_path)
static_model_pair <- rf288_read_csv_20260427(static_model_pair_path)
static_inference_pair <- rf288_read_csv_20260427(static_inference_pair_path)
dynamic_model_pair <- rf288_read_csv_20260427(dynamic_model_pair_path)
dynamic_inference_pair <- rf288_read_csv_20260427(dynamic_inference_pair_path)
warn_inventory <- rf288_read_csv_20260427(warn_inventory_path)
fail_inventory <- rf288_read_csv_20260427(fail_inventory_path)

truthy <- rf288_truthy_20260427

error_text <- paste(
  rf288_na_chr_20260427(comparison_long$error_current),
  rf288_na_chr_20260427(comparison_long$metric_error),
  sep = " "
)
error_text <- error_text[!is.na(error_text) & nzchar(trimws(error_text))]
numerical_pattern <- "NaN|Inf|non[- ]?finite|nonfinite|Cholesky|singular|numerical|failed_runtime|error writing|error reading"
numerical_error_count <- sum(grepl(numerical_pattern, error_text, ignore.case = TRUE))

add_check <- function(check_name, expected, actual, pass, detail = "") {
  data.frame(
    check_name = check_name,
    expected = as.character(expected),
    actual = as.character(actual),
    pass = as.logical(pass),
    detail = detail,
    stringsAsFactors = FALSE
  )
}

checks <- do.call(rbind, list(
  add_check("comparison_long_rows", 288L, nrow(comparison_long), nrow(comparison_long) == 288L),
  add_check("comparison_long_unique_case_keys", 288L, length(unique(comparison_long$case_key)), length(unique(comparison_long$case_key)) == 288L),
  add_check("completed_rows", 288L, sum(comparison_long$status == "done", na.rm = TRUE), sum(comparison_long$status == "done", na.rm = TRUE) == 288L),
  add_check("not_started_rows", 0L, sum(comparison_long$status == "not_started", na.rm = TRUE), sum(comparison_long$status == "not_started", na.rm = TRUE) == 0L),
  add_check("running_rows", 0L, sum(comparison_long$status == "running", na.rm = TRUE), sum(comparison_long$status == "running", na.rm = TRUE) == 0L),
  add_check("pass_rows", 221L, sum(comparison_long$gate_overall == "PASS", na.rm = TRUE), sum(comparison_long$gate_overall == "PASS", na.rm = TRUE) == 221L),
  add_check("warn_rows", 34L, sum(comparison_long$gate_overall == "WARN", na.rm = TRUE), sum(comparison_long$gate_overall == "WARN", na.rm = TRUE) == 34L),
  add_check("fail_rows", 33L, sum(comparison_long$gate_overall == "FAIL", na.rm = TRUE), sum(comparison_long$gate_overall == "FAIL", na.rm = TRUE) == 33L),
  add_check("healthy_rows", 255L, sum(truthy(comparison_long$healthy), na.rm = TRUE), sum(truthy(comparison_long$healthy), na.rm = TRUE) == 255L),
  add_check("static_rows", 216L, sum(comparison_long$block == "static", na.rm = TRUE), sum(comparison_long$block == "static", na.rm = TRUE) == 216L),
  add_check("dynamic_rows", 72L, sum(comparison_long$block == "dynamic", na.rm = TRUE), sum(comparison_long$block == "dynamic", na.rm = TRUE) == 72L),
  add_check("static_scenario_rows", 54L, nrow(static_scenario), nrow(static_scenario) == 54L),
  add_check("dynamic_scenario_rows", 18L, nrow(dynamic_scenario), nrow(dynamic_scenario) == 18L),
  add_check("static_model_pair_rows", 108L, nrow(static_model_pair), nrow(static_model_pair) == 108L),
  add_check("static_inference_pair_rows", 108L, nrow(static_inference_pair), nrow(static_inference_pair) == 108L),
  add_check("dynamic_model_pair_rows", 36L, nrow(dynamic_model_pair), nrow(dynamic_model_pair) == 36L),
  add_check("dynamic_inference_pair_rows", 36L, nrow(dynamic_inference_pair), nrow(dynamic_inference_pair) == 36L),
  add_check("warn_inventory_rows", 34L, nrow(warn_inventory), nrow(warn_inventory) == 34L),
  add_check("fail_inventory_rows", 33L, nrow(fail_inventory), nrow(fail_inventory) == 33L),
  add_check("hard_error_rows", 0L, sum(!is.na(comparison_long$error_current) & nzchar(comparison_long$error_current)), sum(!is.na(comparison_long$error_current) & nzchar(comparison_long$error_current)) == 0L),
  add_check("metric_error_rows", 0L, sum(!is.na(comparison_long$metric_error) & nzchar(comparison_long$metric_error)), sum(!is.na(comparison_long$metric_error) & nzchar(comparison_long$metric_error)) == 0L),
  add_check("numerical_error_rows", 0L, numerical_error_count, numerical_error_count == 0L, "Scanned row-level error_current and metric_error text."),
  add_check("scenario_rows_total", 72L, nrow(static_scenario) + nrow(dynamic_scenario), (nrow(static_scenario) + nrow(dynamic_scenario)) == 72L)
))

rf288_write_csv_20260427(checks, audit_output_path)

if (!all(checks$pass)) {
  print(checks[!checks$pass, ], row.names = FALSE)
  stop("Refreshed288 comparison reporting audit failed.", call. = FALSE)
}

cat(sprintf("Wrote refreshed288 comparison audit to %s\n", audit_output_path))
cat("All checks passed: yes\n")

#!/usr/bin/env Rscript

source("tools/merge_reports/LOCAL_validation_campaign_assembly_helpers_20260405.R")

selection_path <- "tools/merge_reports/LOCAL_validation_campaign_selection_table_v1_20260405.csv"
row_health_path <- "tools/merge_reports/LOCAL_validation_campaign_row_health_v1_20260405.csv"
audit_csv_path <- "tools/merge_reports/LOCAL_validation_campaign_audit_v1_20260405.csv"
audit_md_path <- "reports/static_exal_tuning_20260405/comparison_ready_assembly_execution_20260405.md"

selection <- read.csv(selection_path, stringsAsFactors = FALSE)
row_health <- read.csv(row_health_path, stringsAsFactors = FALSE)

expected_counts <- data.frame(
  selected_pool = c(
    "historical_reusable_static",
    "static_refresh_nonfail",
    "static_residual_broad_default",
    "static_local_override",
    "dynamic_historical_reusable",
    "dynamic_local_override"
  ),
  expected_n = c(216L, 42L, 21L, 9L, 2L, 1L),
  stringsAsFactors = FALSE
)

observed_counts <- as.data.frame(table(selection$selected_pool), stringsAsFactors = FALSE)
names(observed_counts) <- c("selected_pool", "observed_n")
counts <- merge(expected_counts, observed_counts, by = "selected_pool", all.x = TRUE, sort = FALSE)
counts$observed_n[is.na(counts$observed_n)] <- 0L
counts$pass <- counts$expected_n == counts$observed_n

missing_files <- unique(c(
  ensure_files_exist_20260405(selection$selected_fit_path),
  ensure_files_exist_20260405(selection$selected_health_path),
  ensure_files_exist_20260405(selection$provenance_source)
))

checks <- data.frame(
  check_name = c(
    "total_rows_291",
    "unique_case_keys_291",
    "selected_pool_counts_match",
    "selected_fit_paths_exist",
    "selected_health_paths_exist",
    "provenance_sources_exist",
    "zero_selected_fail",
    "all_selected_healthy_true"
  ),
  pass = c(
    nrow(selection) == 291L,
    length(unique(selection$case_key)) == 291L,
    all(counts$pass),
    !length(ensure_files_exist_20260405(selection$selected_fit_path)),
    !length(ensure_files_exist_20260405(selection$selected_health_path)),
    !length(ensure_files_exist_20260405(selection$provenance_source)),
    sum(row_health$gate_overall == "FAIL", na.rm = TRUE) == 0L,
    all(row_health$healthy == TRUE, na.rm = TRUE)
  ),
  detail = c(
    sprintf("rows=%d", nrow(selection)),
    sprintf("unique_case_keys=%d", length(unique(selection$case_key))),
    paste(sprintf("%s:%d", counts$selected_pool, counts$observed_n), collapse = "; "),
    if (!length(ensure_files_exist_20260405(selection$selected_fit_path))) "all fit paths present" else paste(ensure_files_exist_20260405(selection$selected_fit_path), collapse = "; "),
    if (!length(ensure_files_exist_20260405(selection$selected_health_path))) "all health paths present" else paste(ensure_files_exist_20260405(selection$selected_health_path), collapse = "; "),
    if (!length(ensure_files_exist_20260405(selection$provenance_source))) "all provenance sources present" else paste(ensure_files_exist_20260405(selection$provenance_source), collapse = "; "),
    sprintf("fail_rows=%d", sum(row_health$gate_overall == "FAIL", na.rm = TRUE)),
    sprintf("healthy_false_rows=%d", sum(row_health$healthy == FALSE, na.rm = TRUE))
  ),
  stringsAsFactors = FALSE
)

write.csv(checks, audit_csv_path, row.names = FALSE, na = "")

warn_rows <- subset(
  row_health,
  gate_overall == "WARN",
  select = c("case_key", "selected_pool", "selected_candidate", "selected_variant_tag")
)

summary_lines <- c(
  "# Comparison-Ready Assembly Execution",
  "",
  "Date: 2026-04-05",
  "",
  "The comparison-ready assembly pipeline was implemented and executed from the",
  "frozen promoted campaign map. The resulting merged campaign table contains",
  sprintf("exactly `%d` selected cases.", nrow(selection)),
  "",
  "## Audit Summary",
  "",
  sprintf("- total selected rows: `%d`", nrow(selection)),
  sprintf("- unique case keys: `%d`", length(unique(selection$case_key))),
  sprintf("- selected `FAIL` rows: `%d`", sum(row_health$gate_overall == "FAIL", na.rm = TRUE)),
  sprintf("- selected `WARN` rows: `%d`", sum(row_health$gate_overall == "WARN", na.rm = TRUE)),
  "",
  "## Pool Counts",
  "",
  "| pool | expected | observed |",
  "|---|---:|---:|"
)

summary_lines <- c(
  summary_lines,
  apply(counts, 1, function(r) sprintf("| `%s` | %s | %s |", r[["selected_pool"]], r[["expected_n"]], r[["observed_n"]]))
)

summary_lines <- c(
  summary_lines,
  "",
  "## Acceptance Checks",
  "",
  "| check | pass | detail |",
  "|---|---|---|"
)

summary_lines <- c(
  summary_lines,
  apply(checks, 1, function(r) sprintf("| `%s` | `%s` | %s |", r[["check_name"]], ifelse(r[["pass"]] == "TRUE", "yes", "no"), r[["detail"]]))
)

if (nrow(warn_rows)) {
  summary_lines <- c(
    summary_lines,
    "",
    "## Selected WARN Rows",
    "",
    "| case_key | pool | candidate | variant |",
    "|---|---|---|---|",
    apply(warn_rows, 1, function(r) sprintf(
      "| `%s` | `%s` | `%s` | `%s` |",
      r[["case_key"]], r[["selected_pool"]], r[["selected_candidate"]], r[["selected_variant_tag"]]
    ))
  )
}

writeLines(summary_lines, audit_md_path)

cat(sprintf("Wrote audit checks to %s\n", audit_csv_path))
cat(sprintf("Wrote execution report to %s\n", audit_md_path))
cat(sprintf("All checks passed: %s\n", ifelse(all(checks$pass), "yes", "no")))

#!/usr/bin/env Rscript

source("tools/merge_reports/LOCAL_original288_recovery_helpers_20260405.R")

registry_path <- "tools/merge_reports/LOCAL_original288_registry_v1_20260405.csv"
selection_path <- "tools/merge_reports/LOCAL_original288_carryforward_selection_v1_20260405.csv"
row_health_path <- "tools/merge_reports/LOCAL_original288_row_health_v1_20260405.csv"
block_status_path <- "tools/merge_reports/LOCAL_original288_recovery_block_status_v1_20260405.csv"
dynamic_scoreable_path <- "tools/merge_reports/LOCAL_original288_dynamic_scoreable_candidate_inventory_v1_20260405.csv"
audit_csv_path <- "tools/merge_reports/LOCAL_original288_audit_v1_20260405.csv"
audit_md_path <- "reports/static_exal_tuning_20260405/original_288_realignment_execution_20260405.md"

registry <- read.csv(registry_path, stringsAsFactors = FALSE)
selection <- read.csv(selection_path, stringsAsFactors = FALSE)
row_health <- read.csv(row_health_path, stringsAsFactors = FALSE)
block_status <- read.csv(block_status_path, stringsAsFactors = FALSE)
dynamic_scoreable <- read.csv(dynamic_scoreable_path, stringsAsFactors = FALSE)

expected_blocks <- data.frame(
  block = c("dynamic", "static_paper", "static_shrink"),
  expected_n = c(72L, 72L, 144L),
  stringsAsFactors = FALSE
)

observed_blocks <- as.data.frame(table(registry$block), stringsAsFactors = FALSE)
names(observed_blocks) <- c("block", "observed_n")
block_check <- merge(expected_blocks, observed_blocks, by = "block", all.x = TRUE, sort = FALSE)
block_check$observed_n[is.na(block_check$observed_n)] <- 0L
block_check$pass <- block_check$expected_n == block_check$observed_n

selected_evidence_path <- ifelse(
  !is.na(selection$selected_health_path) & nzchar(selection$selected_health_path),
  selection$selected_health_path,
  ifelse(
    !is.na(selection$selected_summary_path) & nzchar(selection$selected_summary_path),
    selection$selected_summary_path,
    selection$source_path
  )
)

checks <- data.frame(
  check_name = c(
    "registry_rows_288",
    "registry_unique_keys_288",
    "selection_rows_288",
    "selection_unique_keys_288",
    "registry_block_counts_match",
    "baseline_fit_paths_exist",
    "baseline_signoff_paths_exist",
    "selected_fit_paths_exist",
    "selected_evidence_paths_exist",
    "static_unresolved_zero",
    "all_unresolved_dynamic_only"
  ),
  pass = c(
    nrow(registry) == 288L,
    length(unique(registry$original_case_key)) == 288L,
    nrow(selection) == 288L,
    length(unique(selection$original_case_key)) == 288L,
    all(block_check$pass),
    !length(ensure_files_exist_original288(registry$baseline_fit_path)),
    !length(ensure_files_exist_original288(registry$baseline_signoff_path)),
    !length(ensure_files_exist_original288(selection$selected_fit_path)),
    !length(ensure_files_exist_original288(selected_evidence_path)),
    sum(row_health$block != "dynamic" & row_health$gate_overall == "FAIL", na.rm = TRUE) == 0L,
    all(row_health$block[row_health$gate_overall == "FAIL"] == "dynamic")
  ),
  detail = c(
    sprintf("rows=%d", nrow(registry)),
    sprintf("unique_keys=%d", length(unique(registry$original_case_key))),
    sprintf("rows=%d", nrow(selection)),
    sprintf("unique_keys=%d", length(unique(selection$original_case_key))),
    paste(sprintf("%s:%d", block_check$block, block_check$observed_n), collapse = "; "),
    if (!length(ensure_files_exist_original288(registry$baseline_fit_path))) "all baseline fit paths present" else paste(ensure_files_exist_original288(registry$baseline_fit_path), collapse = "; "),
    if (!length(ensure_files_exist_original288(registry$baseline_signoff_path))) "all baseline signoff paths present" else paste(ensure_files_exist_original288(registry$baseline_signoff_path), collapse = "; "),
    if (!length(ensure_files_exist_original288(selection$selected_fit_path))) "all selected fit paths present" else paste(ensure_files_exist_original288(selection$selected_fit_path), collapse = "; "),
    if (!length(ensure_files_exist_original288(selected_evidence_path))) "all selected evidence paths present" else paste(ensure_files_exist_original288(selected_evidence_path), collapse = "; "),
    sprintf("static_fail_rows=%d", sum(row_health$block != "dynamic" & row_health$gate_overall == "FAIL", na.rm = TRUE)),
    sprintf("dynamic_fail_rows=%d", sum(row_health$block == "dynamic" & row_health$gate_overall == "FAIL", na.rm = TRUE))
  ),
  stringsAsFactors = FALSE
)

write.csv(checks, audit_csv_path, row.names = FALSE, na = "")

overall <- subset(read.csv("tools/merge_reports/LOCAL_original288_health_summary_v1_20260405.csv", stringsAsFactors = FALSE), slice == "overall")
unresolved_dynamic <- subset(row_health, block == "dynamic" & gate_overall == "FAIL")
source_counts <- as.data.frame(table(selection$selected_source_type), stringsAsFactors = FALSE)
names(source_counts) <- c("selected_source_type", "selected_n")
selection_mode_counts <- as.data.frame(table(selection$selection_mode), stringsAsFactors = FALSE)
names(selection_mode_counts) <- c("selection_mode", "selected_n")

summary_lines <- c(
  "# Original 288 Realignment Execution",
  "",
  "Date: 2026-04-05",
  "",
  "The corrected original-288 carry-forward pipeline was implemented and executed.",
  "This replaces the earlier hybrid `291` campaign as the publication-target",
  "recovery view.",
  "",
  "## Top-Line Result",
  "",
  sprintf("- original baseline cells: `%d`", nrow(registry)),
  sprintf("- healthy now: `%d`", overall$healthy_true[1]),
  sprintf("- unresolved now: `%d`", overall$fail[1]),
  sprintf("- scoreable archived dynamic rescues harvested: `%d`", if (nrow(dynamic_scoreable)) nrow(dynamic_scoreable) else 0L),
  "- publication target should now be the corrected original-`288` carry-forward table, not the earlier hybrid `291` bundle",
  "",
  "## Block Status",
  "",
  "| block | original cells | healthy via promoted selection | healthy via untouched baseline | healthy now | unresolved |",
  "|---|---:|---:|---:|---:|---:|"
)

summary_lines <- c(
  summary_lines,
  apply(block_status, 1, function(r) sprintf(
    "| `%s` | %s | %s | %s | %s | %s |",
    r[["block"]], r[["original_cells"]], r[["healthy_via_promoted_selection"]],
    r[["healthy_via_untouched_baseline"]], r[["healthy_now"]], r[["unresolved"]]
  ))
)

summary_lines <- c(
  summary_lines,
  "",
  "## Selection Routing",
  "",
  "| selected source type | rows |",
  "|---|---:|"
)

summary_lines <- c(
  summary_lines,
  apply(source_counts, 1, function(r) sprintf(
    "| `%s` | %s |",
    r[["selected_source_type"]], r[["selected_n"]]
  ))
)

summary_lines <- c(
  summary_lines,
  "",
  "## Selection Mode",
  "",
  "| selection mode | rows |",
  "|---|---:|"
)

summary_lines <- c(
  summary_lines,
  apply(selection_mode_counts, 1, function(r) sprintf(
    "| `%s` | %s |",
    r[["selection_mode"]], r[["selected_n"]]
  ))
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
  apply(checks, 1, function(r) sprintf(
    "| `%s` | `%s` | %s |",
    r[["check_name"]],
    ifelse(r[["pass"]] == "TRUE", "yes", "no"),
    r[["detail"]]
  ))
)

if (nrow(unresolved_dynamic)) {
  summary_lines <- c(
    summary_lines,
    "",
    "## Remaining Unresolved Dynamic Cells",
    "",
    "| family | tau | horizon | model | inference | baseline | selected status |",
    "|---|---|---:|---|---|---|---|",
    apply(unresolved_dynamic, 1, function(r) sprintf(
      "| `%s` | `%s` | %s | `%s` | `%s` | `%s` | `%s` |",
      r[["family"]], r[["tau"]], r[["fit_size"]], r[["model"]], r[["inference"]],
      r[["baseline_gate_overall"]], r[["selection_mode"]]
    ))
  )
}

summary_lines <- c(
  summary_lines,
  "",
  "## Next-Phase Checklist",
  "",
  "1. Freeze the corrected original-`288` carry-forward table as the only publication-target comparison registry.",
  "2. Do not reopen static repair work unless a provenance bug is found; static is fully recovered at `72 / 72` paper and `144 / 144` shrink healthy.",
  "3. Use `tools/merge_reports/LOCAL_original288_unresolved_dynamic_inventory_v1_20260405.csv` as the exact residual repair queue.",
  "4. Start the next dynamic phase by harvesting any remaining candidate evidence for those `19` unresolved keys before launching new compute.",
  "5. Only after that harvest pass, build a dynamic-only residual manifest and repair program."
)

writeLines(summary_lines, audit_md_path)

cat(sprintf("Wrote audit CSV to %s\n", audit_csv_path))
cat(sprintf("Wrote execution report to %s\n", audit_md_path))
cat(sprintf("All audit checks passed: %s\n", ifelse(all(checks$pass), "yes", "no")))

#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_original288_recovery_helpers_20260405.R")
source("tools/merge_reports/LOCAL_original288_dynamic_residual_helpers_20260405.R")

selection_in <- paths_dynamic_residual_original288()$carryforward_preview
selection_out <- "tools/merge_reports/LOCAL_original288_carryforward_selection_v2_20260405.csv"
row_health_out <- "tools/merge_reports/LOCAL_original288_row_health_v2_20260405.csv"
summary_out <- "tools/merge_reports/LOCAL_original288_health_summary_v2_20260405.csv"
block_status_out <- "tools/merge_reports/LOCAL_original288_recovery_block_status_v2_20260405.csv"
method_breakdown_out <- "tools/merge_reports/LOCAL_original288_health_breakdown_by_method_v2_20260405.csv"
unresolved_out <- "tools/merge_reports/LOCAL_original288_unresolved_inventory_v2_20260405.csv"
unresolved_dynamic_out <- "tools/merge_reports/LOCAL_original288_unresolved_dynamic_inventory_v2_20260405.csv"
audit_out <- "tools/merge_reports/LOCAL_original288_audit_v2_20260405.csv"

registry_path <- "tools/merge_reports/LOCAL_original288_registry_v1_20260405.csv"

if (!file.exists(selection_in)) {
  stop(sprintf("selection preview not found: %s", selection_in))
}
if (!file.exists(registry_path)) {
  stop(sprintf("registry not found: %s", registry_path))
}

selection <- read.csv(selection_in, stringsAsFactors = FALSE, check.names = FALSE)
registry <- read.csv(registry_path, stringsAsFactors = FALSE, check.names = FALSE)

if (nrow(selection) != 288L) {
  stop(sprintf("selection preview has %d rows, expected 288", nrow(selection)))
}
if (length(unique(selection$original_case_key)) != 288L) {
  stop("selection preview does not have 288 unique original_case_key values")
}

write.csv(selection, selection_out, row.names = FALSE, na = "")

count_gate <- function(x, gate) sum(x == gate, na.rm = TRUE)

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
write.csv(row_health, row_health_out, row.names = FALSE, na = "")

summarise_slice <- function(df, label) {
  data.frame(
    slice = label,
    total = nrow(df),
    pass = count_gate(df$gate_overall, "PASS"),
    warn = count_gate(df$gate_overall, "WARN"),
    fail = count_gate(df$gate_overall, "FAIL"),
    healthy_true = sum(normalize_bool_original288(df$healthy)),
    healthy_false = sum(!normalize_bool_original288(df$healthy)),
    stringsAsFactors = FALSE
  )
}

summary_table <- rbind(
  summarise_slice(row_health, "overall"),
  summarise_slice(subset(row_health, block == "dynamic"), "dynamic"),
  summarise_slice(subset(row_health, block == "static_paper"), "static_paper"),
  summarise_slice(subset(row_health, block == "static_shrink"), "static_shrink")
)
write.csv(summary_table, summary_out, row.names = FALSE, na = "")

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
write.csv(block_status, block_status_out, row.names = FALSE, na = "")

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
      healthy_true = sum(normalize_bool_original288(d$healthy)),
      healthy_false = sum(!normalize_bool_original288(d$healthy)),
      stringsAsFactors = FALSE
    )
  })
)
write.csv(method_breakdown, method_breakdown_out, row.names = FALSE, na = "")

unresolved <- subset(
  row_health,
  gate_overall == "FAIL" | !normalize_bool_original288(healthy),
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
write.csv(unresolved, unresolved_out, row.names = FALSE, na = "")

unresolved_dynamic <- subset(unresolved, block == "dynamic")
write.csv(unresolved_dynamic, unresolved_dynamic_out, row.names = FALSE, na = "")

selected_evidence_path <- ifelse(
  !is.na(selection$selected_health_path) & nzchar(selection$selected_health_path),
  selection$selected_health_path,
  ifelse(
    !is.na(selection$selected_summary_path) & nzchar(selection$selected_summary_path),
    selection$selected_summary_path,
    selection$source_path
  )
)

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

checks <- data.frame(
  check_name = c(
    "registry_rows_288",
    "registry_unique_keys_288",
    "selection_rows_288",
    "selection_unique_keys_288",
    "registry_block_counts_match",
    "selected_fit_paths_exist",
    "selected_evidence_paths_exist",
    "static_unresolved_zero"
  ),
  pass = c(
    nrow(registry) == 288L,
    length(unique(registry$original_case_key)) == 288L,
    nrow(selection) == 288L,
    length(unique(selection$original_case_key)) == 288L,
    all(block_check$pass),
    !length(ensure_files_exist_original288(selection$selected_fit_path)),
    !length(ensure_files_exist_original288(selected_evidence_path)),
    sum(row_health$block != "dynamic" & row_health$gate_overall == "FAIL", na.rm = TRUE) == 0L
  ),
  detail = c(
    sprintf("rows=%d", nrow(registry)),
    sprintf("unique_keys=%d", length(unique(registry$original_case_key))),
    sprintf("rows=%d", nrow(selection)),
    sprintf("unique_keys=%d", length(unique(selection$original_case_key))),
    paste(sprintf("%s:%d", block_check$block, block_check$observed_n), collapse = "; "),
    if (!length(ensure_files_exist_original288(selection$selected_fit_path))) "all selected fit paths present" else paste(ensure_files_exist_original288(selection$selected_fit_path), collapse = "; "),
    if (!length(ensure_files_exist_original288(selected_evidence_path))) "all selected evidence paths present" else paste(ensure_files_exist_original288(selected_evidence_path), collapse = "; "),
    sprintf("static_fail_rows=%d", sum(row_health$block != "dynamic" & row_health$gate_overall == "FAIL", na.rm = TRUE))
  ),
  stringsAsFactors = FALSE
)
write.csv(checks, audit_out, row.names = FALSE, na = "")

cat(sprintf("Applied archive-stage promotions to %s\n", selection_out))
cat(sprintf("Overall healthy: %d / %d\n", summary_table$healthy_true[summary_table$slice == 'overall'], nrow(selection)))
cat(sprintf("Dynamic healthy: %d / %d\n", summary_table$healthy_true[summary_table$slice == 'dynamic'], sum(selection$block == 'dynamic')))
cat(sprintf("Unresolved dynamic remaining: %d\n", nrow(unresolved_dynamic)))

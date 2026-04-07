#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_original288_recovery_helpers_20260405.R")

carry_in <- "tools/merge_reports/LOCAL_original288_carryforward_selection_v5_20260407.csv"
status_in <- "tools/merge_reports/LOCAL_original288_syncedbase_residual_manifest_status_20260407.csv"

carry_out <- "tools/merge_reports/LOCAL_original288_carryforward_selection_v6_20260407.csv"
delta_out <- "tools/merge_reports/LOCAL_original288_syncedbase_residual_selection_update_20260407.csv"
row_health_out <- "tools/merge_reports/LOCAL_original288_row_health_v6_20260407.csv"
summary_out <- "tools/merge_reports/LOCAL_original288_health_summary_v6_20260407.csv"
block_status_out <- "tools/merge_reports/LOCAL_original288_recovery_block_status_v6_20260407.csv"
method_breakdown_out <- "tools/merge_reports/LOCAL_original288_health_breakdown_by_method_v6_20260407.csv"
unresolved_out <- "tools/merge_reports/LOCAL_original288_unresolved_inventory_v6_20260407.csv"
unresolved_dynamic_out <- "tools/merge_reports/LOCAL_original288_unresolved_dynamic_inventory_v6_20260407.csv"

carry <- read.csv(carry_in, stringsAsFactors = FALSE, check.names = FALSE)
status <- read.csv(status_in, stringsAsFactors = FALSE, check.names = FALSE)

promotions <- subset(
  status,
  accepted_compare == "better_than_accepted" & gate_current %in% c("PASS", "WARN")
)

promotions <- promotions[, c(
  "row_id", "phase", "original_case_key", "accepted_gate", "gate_current",
  "healthy_current", "candidate_fit_path", "health_csv", "runtime_sec"
)]

promotions$selected_source_type <- "syncedbase_residual_repair_20260407"
promotions$selected_source_subtype <- promotions$phase
promotions$selected_candidate <- sprintf("row_%04d", as.integer(promotions$row_id))
promotions$selected_variant_tag <- "orig288_sync0p4p0_residual_20260407"
promotions$selected_fit_path <- promotions$candidate_fit_path
promotions$selected_health_path <- promotions$health_csv
promotions$selected_summary_path <- promotions$health_csv
promotions$source_path <- promotions$health_csv
promotions$selection_mode <- "promoted_syncedbase_residual_repair"
promotions$selection_reason <- sprintf(
  "Promote synced-base residual repair row %s after improving accepted carry-forward from %s to %s on the updated 0.4.0 base.",
  promotions$selected_candidate,
  promotions$accepted_gate,
  promotions$gate_current
)

utils::write.csv(promotions, delta_out, row.names = FALSE, na = "")

carry2 <- carry
if (nrow(promotions)) {
  idx <- match(promotions$original_case_key, carry2$original_case_key)
  hit <- which(!is.na(idx))
  if (length(hit)) {
    carry2$selected_source_type[idx[hit]] <- promotions$selected_source_type[hit]
    carry2$selected_source_subtype[idx[hit]] <- promotions$selected_source_subtype[hit]
    carry2$selected_candidate[idx[hit]] <- promotions$selected_candidate[hit]
    carry2$selected_variant_tag[idx[hit]] <- promotions$selected_variant_tag[hit]
    carry2$selected_fit_path[idx[hit]] <- promotions$selected_fit_path[hit]
    carry2$selected_health_path[idx[hit]] <- promotions$selected_health_path[hit]
    carry2$selected_summary_path[idx[hit]] <- promotions$selected_summary_path[hit]
    carry2$source_path[idx[hit]] <- promotions$source_path[hit]
    carry2$gate_overall[idx[hit]] <- promotions$gate_current[hit]
    carry2$healthy[idx[hit]] <- normalize_bool_original288(promotions$healthy_current[hit])
    carry2$runtime_sec[idx[hit]] <- promotions$runtime_sec[hit]
    carry2$improved_over_baseline[idx[hit]] <-
      gate_rank_original288(promotions$gate_current[hit]) <
      gate_rank_original288(carry2$baseline_gate_overall[idx[hit]])
    carry2$selection_mode[idx[hit]] <- promotions$selection_mode[hit]
    carry2$selection_reason[idx[hit]] <- promotions$selection_reason[hit]
  }
}

carry2 <- carry2[order(
  carry2$block, carry2$family, carry2$tau, carry2$fit_size,
  carry2$prior_semantics, carry2$model, carry2$inference
), , drop = FALSE]

utils::write.csv(carry2, carry_out, row.names = FALSE, na = "")

count_gate <- function(x, gate) sum(x == gate, na.rm = TRUE)

row_health <- carry2[, c(
  "block", "root_kind", "family", "tau", "fit_size", "prior_semantics",
  "model", "inference", "method", "root_id", "original_scenario_key",
  "original_case_key", "baseline_gate_overall", "baseline_healthy",
  "selected_source_type", "selected_source_subtype", "selected_candidate",
  "selected_variant_tag", "selected_fit_path", "selected_health_path",
  "selected_summary_path", "source_path", "gate_overall", "healthy",
  "runtime_sec", "improved_over_baseline", "selection_mode",
  "selection_reason"
)]

utils::write.csv(row_health, row_health_out, row.names = FALSE, na = "")

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
utils::write.csv(summary_table, summary_out, row.names = FALSE, na = "")

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
utils::write.csv(block_status, block_status_out, row.names = FALSE, na = "")

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
utils::write.csv(method_breakdown, method_breakdown_out, row.names = FALSE, na = "")

unresolved <- subset(
  row_health,
  gate_overall == "FAIL" | !normalize_bool_original288(healthy)
)
unresolved_dynamic <- subset(unresolved, block == "dynamic")
utils::write.csv(unresolved, unresolved_out, row.names = FALSE, na = "")
utils::write.csv(unresolved_dynamic, unresolved_dynamic_out, row.names = FALSE, na = "")

overall <- subset(summary_table, slice == "overall")
cat(sprintf(
  "PROMOTION_UPDATE promoted=%d accepted_now=%d/%d pass=%d warn=%d fail=%d\n",
  nrow(promotions),
  overall$healthy_true[1],
  overall$total[1],
  overall$pass[1],
  overall$warn[1],
  overall$fail[1]
))

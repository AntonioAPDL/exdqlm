#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_original288_dynamic_tail8_helpers_20260405.R")

paths <- paths_dynamic_tail8_original288()

case_best_path <- paths$case_best
status_path <- paths$manifest_status
carry_path <- "tools/merge_reports/LOCAL_original288_carryforward_selection_v2_20260405.csv"

if (!file.exists(case_best_path)) {
  stop(sprintf("case_best not found: %s", case_best_path))
}
if (!file.exists(status_path)) {
  stop(sprintf("manifest_status not found: %s", status_path))
}
if (!file.exists(carry_path)) {
  stop(sprintf("carryforward selection not found: %s", carry_path))
}

case_best <- read.csv(case_best_path, stringsAsFactors = FALSE, check.names = FALSE)
status <- read.csv(status_path, stringsAsFactors = FALSE, check.names = FALSE)
carry <- read.csv(carry_path, stringsAsFactors = FALSE, check.names = FALSE)

best_rows <- merge(
  case_best,
  status[, c(
    "original_case_key", "phase", "config_id", "candidate_variant_tag",
    "candidate_fit_path", "health_csv", "state", "runtime_sec"
  )],
  by.x = c("original_case_key", "best_phase", "best_config_id", "best_candidate_variant_tag", "best_candidate_fit_path"),
  by.y = c("original_case_key", "phase", "config_id", "candidate_variant_tag", "candidate_fit_path"),
  all.x = TRUE,
  suffixes = c("", "_status")
)

best_rows$selection_source_type <- "dynamic_tail8_20260405"
best_rows$selection_source_subtype <- best_rows$best_phase
best_rows$selection_candidate <- best_rows$best_config_id
best_rows$selection_variant_tag <- best_rows$best_candidate_variant_tag
best_rows$selection_fit_path <- best_rows$best_candidate_fit_path
best_rows$selection_health_path <- best_rows$best_health_csv
best_rows$selection_reason <- ifelse(
  best_rows$promote_recommend,
  sprintf(
    "Promote dynamic tail-8 candidate %s from phase %s after improving original baseline from %s to %s.",
    best_rows$best_candidate_variant_tag,
    best_rows$best_phase,
    best_rows$baseline_gate_overall,
    best_rows$best_gate_overall
  ),
  sprintf(
    "Retain unresolved original baseline because dynamic tail-8 best candidate remained %s.",
    best_rows$best_gate_overall
  )
)

write.csv(best_rows, paths$selection_delta, row.names = FALSE, na = "")

selection_update <- subset(best_rows, promote_recommend)
write.csv(selection_update, paths$selection_update, row.names = FALSE, na = "")

carry2 <- carry
if (nrow(selection_update)) {
  idx <- match(selection_update$original_case_key, carry2$original_case_key)
  hit <- which(!is.na(idx))
  if (length(hit)) {
    carry2$selected_source_type[idx[hit]] <- selection_update$selection_source_type[hit]
    carry2$selected_source_subtype[idx[hit]] <- selection_update$selection_source_subtype[hit]
    carry2$selected_candidate[idx[hit]] <- selection_update$selection_candidate[hit]
    carry2$selected_variant_tag[idx[hit]] <- selection_update$selection_variant_tag[hit]
    carry2$selected_fit_path[idx[hit]] <- selection_update$selection_fit_path[hit]
    carry2$selected_health_path[idx[hit]] <- selection_update$selection_health_path[hit]
    carry2$source_path[idx[hit]] <- selection_update$selection_health_path[hit]
    carry2$gate_overall[idx[hit]] <- selection_update$best_gate_overall[hit]
    carry2$healthy[idx[hit]] <- selection_update$best_gate_overall[hit] %in% c("PASS", "WARN")
    carry2$runtime_sec[idx[hit]] <- selection_update$best_runtime_sec[hit]
    carry2$improved_over_baseline[idx[hit]] <- selection_update$improvement_over_baseline[hit]
    carry2$selection_mode[idx[hit]] <- "promoted_dynamic_tail8"
    carry2$selection_reason[idx[hit]] <- selection_update$selection_reason[hit]
  }
}

carry2 <- carry2[order(carry2$block, carry2$family, carry2$tau, carry2$fit_size, carry2$prior_semantics, carry2$model, carry2$inference), , drop = FALSE]
write.csv(carry2, paths$carryforward_preview, row.names = FALSE, na = "")

summarise_slice <- function(df, label) {
  data.frame(
    slice = label,
    total = nrow(df),
    pass = sum(df$gate_overall == "PASS"),
    warn = sum(df$gate_overall == "WARN"),
    fail = sum(df$gate_overall == "FAIL"),
    healthy_true = sum(normalize_bool_original288(df$healthy)),
    healthy_false = sum(!normalize_bool_original288(df$healthy)),
    stringsAsFactors = FALSE
  )
}

health_summary <- rbind(
  summarise_slice(carry2, "overall"),
  summarise_slice(subset(carry2, block == "dynamic"), "dynamic"),
  summarise_slice(subset(carry2, block == "static_paper"), "static_paper"),
  summarise_slice(subset(carry2, block == "static_shrink"), "static_shrink")
)
write.csv(health_summary, paths$health_summary_preview, row.names = FALSE, na = "")

cat(sprintf(
  "SELECTION_UPDATE promoted=%d unresolved=%d preview_health=%d/%d dynamic_healthy=%d/%d\n",
  nrow(selection_update),
  sum(!(case_best$best_gate_overall %in% c("PASS", "WARN"))),
  sum(normalize_bool_original288(carry2$healthy)),
  nrow(carry2),
  sum(normalize_bool_original288(subset(carry2, block == 'dynamic')$healthy)),
  nrow(subset(carry2, block == 'dynamic'))
))

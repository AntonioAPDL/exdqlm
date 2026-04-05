#!/usr/bin/env Rscript

source("tools/merge_reports/LOCAL_validation_campaign_assembly_helpers_20260405.R")

promoted_map_path <- "tools/merge_reports/LOCAL_validation_campaign_promoted_local_map_v9_20260405.csv"
output_policy_path <- "tools/merge_reports/LOCAL_validation_campaign_frozen_policy_v1_20260405.csv"
output_registry_path <- "tools/merge_reports/LOCAL_validation_campaign_local_override_registry_v1_20260405.csv"

registry <- read_summary_registry_20260405()
map <- read.csv(promoted_map_path, stringsAsFactors = FALSE)

resolve_one <- function(row, registry) {
  workstream <- row[["workstream"]]
  preferred_candidate <- row[["preferred_candidate"]]
  row_id <- as.integer(row[["row_id"]])

  candidates <- subset(
    registry,
    workstream == workstream &
      row_id == row_id &
      gate_overall != "FAIL" &
      grepl(preferred_candidate, variant_tag, fixed = TRUE)
  )

  if (identical(workstream, "static_exal")) {
    candidates <- subset(candidates, scope_label == row[["scope_label"]])
  }

  if (!nrow(candidates)) {
    stop(sprintf(
      "No non-FAIL summary match found for %s row %s candidate %s",
      workstream,
      row_id,
      preferred_candidate
    ))
  }

  candidates$gate_rank <- gate_rank(candidates$gate_overall)
  candidates$ts_num <- suppressWarnings(as.numeric(as.POSIXct(candidates$ts, tz = "America/New_York")))
  candidates$ts_num[is.na(candidates$ts_num)] <- -Inf
  candidates <- candidates[order(candidates$gate_rank, -candidates$ts_num, candidates$file), ]
  candidates[1, ]
}

override_rows <- do.call(
  rbind,
  lapply(seq_len(nrow(map)), function(i) {
    chosen <- resolve_one(map[i, , drop = FALSE], registry)
    data.frame(
      rule_type = "local_override",
      workstream = map$workstream[i],
      scope_label = map$scope_label[i],
      row_id = map$row_id[i],
      global_default_candidate = if (map$workstream[i] == "static_exal") "F085_sub2_s100" else NA_character_,
      preferred_candidate = map$preferred_candidate[i],
      role = map$role[i],
      best_read = map$best_read[i],
      evidence_note = map$evidence_note[i],
      selected_variant_tag = chosen$variant_tag[1],
      selected_gate_overall = chosen$gate_overall[1],
      selected_healthy = chosen$healthy[1],
      selected_fit_path = chosen$candidate_path[1],
      selected_health_path = chosen$health_csv[1],
      selected_summary_path = chosen$file[1],
      selected_ts = chosen$ts[1],
      stringsAsFactors = FALSE
    )
  })
)

default_rows <- rbind(
  data.frame(
    rule_type = "default",
    workstream = "static_validation",
    scope_label = "*",
    row_id = NA_integer_,
    global_default_candidate = "F085_sub2_s100",
    preferred_candidate = "F085_sub2_s100",
    role = "broad_default",
    best_read = "mixed_nonfail",
    evidence_note = paste(
      "Default static campaign baseline outside promoted local overrides.",
      "The exact selected broad-default artifacts are resolved from the",
      "failband2 paired checkpoint registry during selection-table assembly."
    ),
    selected_variant_tag = "failband2_F085_sub2_s100",
    selected_gate_overall = NA_character_,
    selected_healthy = NA,
    selected_fit_path = NA_character_,
    selected_health_path = NA_character_,
    selected_summary_path = NA_character_,
    selected_ts = NA_character_,
    stringsAsFactors = FALSE
  ),
  data.frame(
    rule_type = "default",
    workstream = "dynamic_tail_cppgig_refresh_20260331",
    scope_label = "*",
    row_id = NA_integer_,
    global_default_candidate = "historical_dynamic_reuse",
    preferred_candidate = "historical_dynamic_reuse",
    role = "broad_default",
    best_read = "historical_nonfail",
    evidence_note = "Dynamic rows 5 and 57 stay on their existing healthy historical artifacts; row 15 is a promoted local override.",
    selected_variant_tag = "historical_dynamic_reuse",
    selected_gate_overall = NA_character_,
    selected_healthy = NA,
    selected_fit_path = NA_character_,
    selected_health_path = NA_character_,
    selected_summary_path = NA_character_,
    selected_ts = NA_character_,
    stringsAsFactors = FALSE
  )
)

policy <- rbind(default_rows, override_rows)
write.csv(policy, output_policy_path, row.names = FALSE, na = "")
write.csv(override_rows, output_registry_path, row.names = FALSE, na = "")

cat(sprintf("Wrote frozen policy to %s\n", output_policy_path))
cat(sprintf("Wrote local override registry to %s\n", output_registry_path))
cat(sprintf("Rows: %d total policy rules, %d promoted overrides\n", nrow(policy), nrow(override_rows)))

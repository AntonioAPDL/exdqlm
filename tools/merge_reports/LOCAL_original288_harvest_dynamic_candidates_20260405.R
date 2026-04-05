#!/usr/bin/env Rscript

source("tools/merge_reports/LOCAL_original288_recovery_helpers_20260405.R")

registry_path <- "tools/merge_reports/LOCAL_original288_registry_v1_20260405.csv"
harvest_output_path <- "tools/merge_reports/LOCAL_original288_dynamic_harvest_candidates_v1_20260405.csv"
scoreable_inventory_path <- "tools/merge_reports/LOCAL_original288_dynamic_scoreable_candidate_inventory_v1_20260405.csv"

registry <- read.csv(registry_path, stringsAsFactors = FALSE)
dynamic_registry <- subset(registry, root_kind == "dynamic")

harvest <- read_dynamic_harvest_candidates_original288()
harvest <- subset(harvest, block == "dynamic")

if (!nrow(harvest)) {
  write.csv(data.frame(), harvest_output_path, row.names = FALSE)
  write.csv(data.frame(), scoreable_inventory_path, row.names = FALSE)
  quit(save = "no", status = 0L)
}

harvest <- merge(
  harvest,
  unique(dynamic_registry[, c("original_case_key", "baseline_gate_overall", "baseline_healthy")]),
  by = "original_case_key",
  all.x = TRUE,
  sort = FALSE
)

write.csv(harvest, harvest_output_path, row.names = FALSE, na = "")

scoreable <- subset(harvest, healthy == TRUE & gate_overall %in% c("PASS", "WARN"))
if (nrow(scoreable)) {
  scoreable$gate_rank <- gate_rank_original288(scoreable$gate_overall)
  scoreable$runtime_rank <- ifelse(is.na(scoreable$runtime_sec), Inf, scoreable$runtime_sec)
  scoreable <- scoreable[order(
    scoreable$original_case_key,
    scoreable$gate_rank,
    scoreable$source_rank,
    scoreable$runtime_rank,
    scoreable$selected_fit_path
  ), ]

  best <- scoreable[!duplicated(scoreable$original_case_key), ]
  counts <- as.data.frame(table(scoreable$original_case_key), stringsAsFactors = FALSE)
  names(counts) <- c("original_case_key", "scoreable_candidate_count")
  inventory <- merge(
    unique(best[, c(
      "original_case_key", "block", "family", "tau", "fit_size",
      "prior_semantics", "model", "inference", "baseline_gate_overall",
      "selected_candidate", "selected_variant_tag", "selected_fit_path",
      "selected_health_path", "selected_summary_path", "gate_overall", "healthy"
    )]),
    counts,
    by = "original_case_key",
    all.x = TRUE,
    sort = FALSE
  )
  names(inventory)[names(inventory) == "gate_overall"] <- "best_scoreable_gate"
  names(inventory)[names(inventory) == "healthy"] <- "best_scoreable_healthy"
} else {
  inventory <- data.frame()
}

write.csv(inventory, scoreable_inventory_path, row.names = FALSE, na = "")

cat(sprintf("Wrote dynamic harvest to %s\n", harvest_output_path))
cat(sprintf("Wrote scoreable inventory to %s\n", scoreable_inventory_path))
cat(sprintf("Harvested candidate rows: %d\n", nrow(harvest)))
cat(sprintf("Scoreable dynamic keys: %d\n", if (nrow(inventory)) nrow(inventory) else 0L))

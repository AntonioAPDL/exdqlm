#!/usr/bin/env Rscript

source("tools/merge_reports/LOCAL_original288_comparison_helpers_20260408.R")

selection_path <- "tools/merge_reports/LOCAL_original288_carryforward_selection_v7_20260407.csv"
comparison_long_path <- "tools/merge_reports/LOCAL_original288_comparison_long_v1_20260408.csv"

selection <- read.csv(selection_path, check.names = FALSE, stringsAsFactors = FALSE)
selection$row_id <- seq_len(nrow(selection))

if (nrow(selection) != 288L) {
  stop(sprintf("Accepted v7 carryforward table must contain 288 rows, found %d", nrow(selection)))
}

if (anyDuplicated(selection$original_case_key)) {
  dupes <- unique(selection$original_case_key[duplicated(selection$original_case_key)])
  stop(sprintf(
    "Accepted v7 carryforward table has duplicate original_case_key values: %s",
    paste(dupes, collapse = ", ")
  ))
}

rows <- lapply(seq_len(nrow(selection)), function(i) {
  o288_build_comparison_row_20260408(selection[i, , drop = FALSE])
})

comparison_long <- do.call(rbind, rows)
comparison_long <- comparison_long[order(
  comparison_long$block,
  comparison_long$family,
  comparison_long$tau_label,
  comparison_long$fit_size,
  comparison_long$prior_semantics,
  comparison_long$inference,
  comparison_long$model
), ]
rownames(comparison_long) <- NULL

if (nrow(comparison_long) != 288L) {
  stop(sprintf("Comparison dataset must contain 288 rows, found %d", nrow(comparison_long)))
}

if (anyDuplicated(comparison_long$case_key)) {
  dupes <- unique(comparison_long$case_key[duplicated(comparison_long$case_key)])
  stop(sprintf(
    "Comparison dataset has duplicate case_key values: %s",
    paste(dupes, collapse = ", ")
  ))
}

gate_mismatch <- subset(
  comparison_long,
  !is.na(source_gate_matches_selected) & !source_gate_matches_selected
)
if (nrow(gate_mismatch)) {
  stop(sprintf(
    "Found %d rows where selected gate does not match selected source evidence.",
    nrow(gate_mismatch)
  ))
}

write.csv(comparison_long, comparison_long_path, row.names = FALSE, na = "")

cat(sprintf("Wrote original288 comparison-long dataset to %s\n", comparison_long_path))
cat(sprintf(
  "Rows: %d total, PASS=%d, WARN=%d, FAIL=%d\n",
  nrow(comparison_long),
  sum(comparison_long$gate_overall == "PASS", na.rm = TRUE),
  sum(comparison_long$gate_overall == "WARN", na.rm = TRUE),
  sum(comparison_long$gate_overall == "FAIL", na.rm = TRUE)
))

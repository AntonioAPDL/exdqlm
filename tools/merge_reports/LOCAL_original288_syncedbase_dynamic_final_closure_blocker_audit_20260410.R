#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)

queue_path <- "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_final_closure_queue_20260410.csv"
out_path <- "tools/merge_reports/LOCAL_original288_syncedbase_dynamic_final_closure_blocker_audit_20260410.csv"

if (!file.exists(queue_path)) {
  stop(sprintf("Missing queue file: %s", queue_path))
}

queue <- read.csv(queue_path, stringsAsFactors = FALSE)

required_cols <- c(
  "original_case_key",
  "family",
  "tau_label",
  "fit_size",
  "source_reference_fit_path",
  "source_selected_fit_path",
  "vb_reference_fit_path",
  "source_run_config_path",
  "sim_output_path"
)

missing_cols <- setdiff(required_cols, names(queue))
if (length(missing_cols)) {
  stop(sprintf("Queue file missing required columns: %s", paste(missing_cols, collapse = ", ")))
}

audit <- within(queue[, required_cols], {
  source_reference_fit_exists <- file.exists(source_reference_fit_path)
  source_selected_fit_exists <- file.exists(source_selected_fit_path)
  vb_reference_fit_exists <- file.exists(vb_reference_fit_path)
  source_run_config_exists <- file.exists(source_run_config_path)
  sim_output_exists <- file.exists(sim_output_path)
  missing_required_inputs <- !source_reference_fit_exists |
    !source_selected_fit_exists |
    !vb_reference_fit_exists |
    !source_run_config_exists |
    !sim_output_exists
})

audit$blocker_reason <- vapply(seq_len(nrow(audit)), function(i) {
  reasons <- character()
  if (!audit$source_reference_fit_exists[i]) {
    reasons <- c(reasons, "missing_source_reference_fit")
  }
  if (!audit$source_selected_fit_exists[i]) {
    reasons <- c(reasons, "missing_source_selected_fit")
  }
  if (!audit$vb_reference_fit_exists[i]) {
    reasons <- c(reasons, "missing_vb_reference_fit")
  }
  if (!audit$source_run_config_exists[i]) {
    reasons <- c(reasons, "missing_source_run_config")
  }
  if (!audit$sim_output_exists[i]) {
    reasons <- c(reasons, "missing_sim_output")
  }
  if (!length(reasons)) "ready" else paste(reasons, collapse = ";")
}, character(1))

audit <- audit[, c(
  "original_case_key", "family", "tau_label", "fit_size",
  "source_reference_fit_path", "source_reference_fit_exists",
  "source_selected_fit_path", "source_selected_fit_exists",
  "vb_reference_fit_path", "vb_reference_fit_exists",
  "source_run_config_path", "source_run_config_exists",
  "sim_output_path", "sim_output_exists",
  "missing_required_inputs", "blocker_reason"
)]

write.csv(audit, out_path, row.names = FALSE)

cat(sprintf("rows=%d\n", nrow(audit)))
cat(sprintf("blocked=%d\n", sum(audit$missing_required_inputs)))
cat(sprintf("output=%s\n", out_path))

#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo_root <- if (length(args)) args[[1]] else "."
repo_root <- normalizePath(repo_root, mustWork = TRUE)

source(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_v2_common.R"))

root_catalog <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_root_catalog.tsv"))
audit <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_reusable_state_audit.tsv"))
jerez_audit <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_jerez_root_audit.tsv"))

root_review_audit <- audit[audit$unit_type == "root_review", c("root_id", "state")]
root_post_audit <- audit[audit$unit_type == "root_postprocess", c("root_id", "state")]
model_audit <- audit[audit$unit_type == "model_path", c("root_id", "state", "recommended_action")]

rows <- lapply(seq_len(nrow(root_catalog)), function(i) {
  root_row <- root_catalog[i, , drop = FALSE]
  root_id <- root_row$root_id[[1]]
  local_review_state <- root_review_audit$state[match(root_id, root_review_audit$root_id)]
  local_post_state <- root_post_audit$state[match(root_id, root_post_audit$root_id)]
  local_model_states <- model_audit[model_audit$root_id == root_id, , drop = FALSE]
  local_partial <- any(local_model_states$state %in% c("partial_reusable", "partial_stale")) ||
    (!is.na(local_post_state) && local_post_state %in% c("partial_reusable", "partial_stale")) ||
    (!is.na(local_review_state) && local_review_state %in% c("partial_reusable", "partial_stale"))
  local_absent <- all(local_model_states$state %in% c("missing", "blocked")) &&
    (is.na(local_post_state) || local_post_state == "blocked") &&
    (is.na(local_review_state) || local_review_state == "blocked")

  j_row <- jerez_audit[jerez_audit$root_id == root_id, , drop = FALSE]
  if (!nrow(j_row)) {
    j_state <- "missing"
    j_prep <- FALSE
  } else {
    j_state <- j_row$root_state[[1]]
    j_prep <- identical(j_row$prepared_present[[1]], TRUE) || identical(j_row$prepared_present[[1]], "TRUE")
  }

  action <- "skip_not_complete_on_jerez"
  note <- "Jerez root is not complete under the canonical relaunch contract."
  if (identical(local_review_state, "complete_reusable")) {
    action <- "skip_already_complete_on_muscat"
    note <- "Muscat already has a complete reusable root review for this root."
  } else if (j_state == "complete" && local_absent) {
    action <- "sync_root"
    note <- "Complete on jerez and absent on muscat; safe exact-root sync candidate."
  } else if (j_state == "complete" && local_partial) {
    action <- "conflict_local_partial"
    note <- "Complete on jerez but muscat already has partial local state for the same root; do not overwrite blindly."
  } else if (j_state == "complete") {
    action <- "review_needed"
    note <- "Complete on jerez but local state does not cleanly classify as absent or complete."
  }

  data.frame(
    root_id = root_id,
    root_kind = root_row$root_kind,
    family = root_row$family,
    tau = root_row$tau,
    fit_size = root_row$fit_size,
    prior = root_row$prior,
    run_root = root_row$run_root,
    jerez_root_state = j_state,
    jerez_prepared_present = j_prep,
    muscat_root_review_state = local_review_state,
    muscat_root_postprocess_state = local_post_state,
    muscat_model_states = paste(local_model_states$state, collapse = ","),
    sync_action = action,
    note = note,
    stringsAsFactors = FALSE
  )
})

manifest <- do.call(rbind, rows)
summary_tab <- sort(table(manifest$sync_action))
summary_df <- data.frame(
  sync_action = names(summary_tab),
  count = as.integer(summary_tab),
  stringsAsFactors = FALSE
)

out_dir <- file.path(repo_root, "tools", "merge_reports")
fq_write_tsv(manifest, file.path(out_dir, "20260312_family_qspec_jerez_sync_manifest.tsv"))
fq_write_tsv(summary_df, file.path(out_dir, "20260312_family_qspec_jerez_sync_manifest_summary.tsv"))

cat("Wrote:\n")
cat(file.path(out_dir, "20260312_family_qspec_jerez_sync_manifest.tsv"), "\n")
cat(file.path(out_dir, "20260312_family_qspec_jerez_sync_manifest_summary.tsv"), "\n")

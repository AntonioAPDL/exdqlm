#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo_root <- if (length(args)) args[[1]] else "."
repo_root <- normalizePath(repo_root, mustWork = TRUE)

source(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_v2_common.R"))

audit <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_reusable_state_audit.tsv"))
root_catalog <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_root_catalog.tsv"))
model_manifest <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_model_path_scheduler_manifest.tsv"))
postprocess_manifest <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_root_postprocess_manifest.tsv"))
comparison_barriers <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_comparison_barriers.tsv"))

queue_rows <- list()

add_queue_row <- function(df) {
  queue_rows[[length(queue_rows) + 1L]] <<- df
}

model_audit <- audit[audit$unit_type == "model_path", , drop = FALSE]
model_rows <- merge(
  model_manifest,
  model_audit[, c("task_id", "state", "recommended_action", "notes")],
  by = "task_id",
  all.x = TRUE,
  sort = FALSE
)
model_rows$launch_ready <- model_rows$state %in% c("missing", "partial_reusable", "partial_stale")
model_rows$priority <- ifelse(
  model_rows$recommended_action == "resume_mcmc_from_vb", 0L,
  as.integer(model_rows$priority_band)
)
if (nrow(model_rows)) {
  add_queue_row(data.frame(
    task_id = model_rows$task_id,
    unit_type = "model_path",
    root_id = model_rows$root_id,
    barrier_id = NA_character_,
    root_kind = model_rows$root_kind,
    family = model_rows$family,
    tau = model_rows$tau,
    fit_size = as.integer(model_rows$fit_size),
    prior = model_rows$prior,
    model = model_rows$model,
    state = model_rows$state,
    launch_ready = model_rows$launch_ready,
    launch_mode = model_rows$recommended_action,
    slot_cost = as.integer(model_rows$slot_cost),
    priority = as.integer(model_rows$priority),
    prepared_root = root_catalog$prepared_root[match(model_rows$root_id, root_catalog$root_id)],
    run_root = model_rows$run_root,
    script_ref = model_rows$pipeline_script,
    notes = model_rows$notes,
    stringsAsFactors = FALSE
  ))
}

post_audit <- audit[audit$unit_type == "root_postprocess", , drop = FALSE]
post_rows <- merge(postprocess_manifest, post_audit[, c("task_id", "state", "recommended_action", "notes")], by = "task_id", all.x = TRUE, sort = FALSE)
post_rows$launch_ready <- post_rows$state %in% c("missing", "partial_reusable")
post_rows$priority <- 20L
if (nrow(post_rows)) {
  add_queue_row(data.frame(
    task_id = post_rows$task_id,
    unit_type = "root_postprocess",
    root_id = post_rows$root_id,
    barrier_id = NA_character_,
    root_kind = post_rows$root_kind,
    family = post_rows$family,
    tau = post_rows$tau,
    fit_size = as.integer(post_rows$fit_size),
    prior = post_rows$prior,
    model = NA_character_,
    state = post_rows$state,
    launch_ready = post_rows$launch_ready,
    launch_mode = post_rows$recommended_action,
    slot_cost = 1L,
    priority = 20L,
    prepared_root = root_catalog$prepared_root[match(post_rows$root_id, root_catalog$root_id)],
    run_root = root_catalog$run_root[match(post_rows$root_id, root_catalog$root_id)],
    script_ref = post_rows$postprocess_script,
    notes = post_rows$notes,
    stringsAsFactors = FALSE
  ))
}

review_audit <- audit[audit$unit_type == "root_review" & audit$root_kind != "dynamic", , drop = FALSE]
if (nrow(review_audit)) {
  add_queue_row(data.frame(
    task_id = review_audit$task_id,
    unit_type = "root_review",
    root_id = review_audit$root_id,
    barrier_id = NA_character_,
    root_kind = review_audit$root_kind,
    family = review_audit$family,
    tau = review_audit$tau,
    fit_size = as.integer(review_audit$fit_size),
    prior = review_audit$prior,
    model = NA_character_,
    state = review_audit$state,
    launch_ready = review_audit$state %in% c("missing", "partial_reusable"),
    launch_mode = review_audit$recommended_action,
    slot_cost = 1L,
    priority = 21L,
    prepared_root = root_catalog$prepared_root[match(review_audit$root_id, root_catalog$root_id)],
    run_root = root_catalog$run_root[match(review_audit$root_id, root_catalog$root_id)],
    script_ref = "tools/merge_reports/20260305_static_vb_mcmc_report.R",
    notes = review_audit$notes,
    stringsAsFactors = FALSE
  ))
}

prior_audit <- audit[audit$unit_type == "prior_compare", , drop = FALSE]
prior_rows <- merge(comparison_barriers[comparison_barriers$barrier_type == "prior_compare", ], prior_audit[, c("barrier_id", "state", "recommended_action", "notes")], by = "barrier_id", all.x = TRUE, sort = FALSE)
prior_rows$queue_notes <- if ("notes.y" %in% names(prior_rows)) prior_rows$notes.y else prior_rows$notes
if (nrow(prior_rows)) {
  add_queue_row(data.frame(
    task_id = prior_rows$barrier_id,
    unit_type = "prior_compare",
    root_id = NA_character_,
    barrier_id = prior_rows$barrier_id,
    root_kind = prior_rows$root_kind,
    family = prior_rows$family,
    tau = prior_rows$tau,
    fit_size = as.integer(prior_rows$fit_size),
    prior = "ridge_vs_rhs",
    model = NA_character_,
    state = prior_rows$state,
    launch_ready = prior_rows$state %in% c("missing", "partial_reusable"),
    launch_mode = prior_rows$recommended_action,
    slot_cost = 1L,
    priority = 30L,
    prepared_root = prior_rows$prepared_root,
    run_root = prior_rows$compare_root,
    script_ref = prior_rows$implementation_script,
    notes = prior_rows$queue_notes,
    stringsAsFactors = FALSE
  ))
}

higher_audit <- audit[audit$unit_type %in% c("campaign_review", "global_summary"), , drop = FALSE]
higher_rows <- merge(comparison_barriers[comparison_barriers$barrier_type %in% c("campaign_review", "global_summary"), ], higher_audit[, c("barrier_id", "state", "recommended_action", "notes")], by = "barrier_id", all.x = TRUE, sort = FALSE)
higher_rows$queue_notes <- if ("notes.y" %in% names(higher_rows)) higher_rows$notes.y else higher_rows$notes
if (nrow(higher_rows)) {
  add_queue_row(data.frame(
    task_id = higher_rows$barrier_id,
    unit_type = higher_rows$barrier_type,
    root_id = NA_character_,
    barrier_id = higher_rows$barrier_id,
    root_kind = higher_rows$root_kind,
    family = higher_rows$family,
    tau = higher_rows$tau,
    fit_size = as.integer(higher_rows$fit_size),
    prior = NA_character_,
    model = NA_character_,
    state = higher_rows$state,
    launch_ready = higher_rows$state %in% c("missing", "partial_reusable"),
    launch_mode = higher_rows$recommended_action,
    slot_cost = 1L,
    priority = ifelse(higher_rows$barrier_type == "global_summary", 50L, 40L),
    prepared_root = NA_character_,
    run_root = vapply(higher_rows$barrier_id, fq_barrier_output_root, character(1), repo_root = repo_root),
    script_ref = "tools/merge_reports/20260312_family_qspec_campaign_aggregate.R",
    notes = higher_rows$queue_notes,
    stringsAsFactors = FALSE
  ))
}

queue <- do.call(rbind, queue_rows)
queue <- queue[order(-as.integer(queue$launch_ready), queue$priority, queue$root_kind, queue$family, queue$tau, queue$fit_size, queue$prior, queue$model), ]
summary_df <- as.data.frame.matrix(table(queue$unit_type, interaction(queue$state, queue$launch_ready, drop = TRUE)), stringsAsFactors = FALSE)
summary_df <- cbind(unit_type = rownames(summary_df), summary_df)
rownames(summary_df) <- NULL

out_dir <- file.path(repo_root, "tools", "merge_reports")
fq_write_tsv(queue, file.path(out_dir, "20260312_family_qspec_runtime_queue.tsv"))
fq_write_tsv(summary_df, file.path(out_dir, "20260312_family_qspec_runtime_queue_summary.tsv"))

cat("Wrote:\n")
cat(file.path(out_dir, "20260312_family_qspec_runtime_queue.tsv"), "\n")
cat(file.path(out_dir, "20260312_family_qspec_runtime_queue_summary.tsv"), "\n")

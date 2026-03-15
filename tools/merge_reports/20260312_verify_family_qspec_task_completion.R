#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) {
  stop("Usage: 20260312_verify_family_qspec_task_completion.R <repo_root> <task_id>", call. = FALSE)
}

repo_root <- normalizePath(args[[1]], mustWork = TRUE)
task_id <- args[[2]]

source(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_v2_common.R"))

root_catalog <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_root_catalog.tsv"))
model_manifest <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_model_path_scheduler_manifest.tsv"))
postprocess_manifest <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_root_postprocess_manifest.tsv"))
signoff_manifest <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_root_signoff_manifest.tsv"))
comparison_barriers <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_comparison_barriers.tsv"))

fail_verify <- function(unit_type, state, details = character()) {
  msg <- paste(
    c(
      sprintf("post-run verification failed for %s '%s'", unit_type, task_id),
      sprintf("detected_state=%s", state),
      details
    ),
    collapse = " | "
  )
  writeLines(msg, con = stderr())
  quit(save = "no", status = 1L)
}

root_lookup <- root_catalog
rownames(root_lookup) <- root_lookup$root_id

model_idx <- match(task_id, model_manifest$task_id)
if (!is.na(model_idx)) {
  row <- model_manifest[model_idx, , drop = FALSE]
  row$run_root <- root_catalog$run_root[match(row$root_id, root_catalog$root_id)]
  det <- fq_detect_model_path(row, repo_root)
  if (!identical(det$state[[1]], "complete_reusable")) {
    fail_verify(
      "model_path",
      det$state[[1]],
      c(
        sprintf("vb_fit=%s", det$vb_fit_exists[[1]]),
        sprintf("mcmc_fit=%s", det$mcmc_fit_exists[[1]]),
        sprintf("status_mcmc_done=%s", det$status_has_mcmc_done[[1]]),
        sprintf("pipeline_done=%s", det$pipeline_done[[1]]),
        sprintf("pipeline_error=%s", det$pipeline_error[[1]])
      )
    )
  }
  cat(sprintf("verified model_path '%s' as complete_reusable\n", task_id))
  quit(save = "no", status = 0L)
}

post_idx <- match(task_id, postprocess_manifest$task_id)
if (!is.na(post_idx)) {
  row <- root_lookup[postprocess_manifest$root_id[post_idx], , drop = FALSE]
  det <- fq_detect_root_postprocess(row, repo_root)
  if (!identical(det$state[[1]], "complete_reusable")) {
    fail_verify("root_postprocess", det$state[[1]], sprintf("missing_count=%d", det$missing_count[[1]]))
  }
  cat(sprintf("verified root_postprocess '%s' as complete_reusable\n", task_id))
  quit(save = "no", status = 0L)
}

signoff_idx <- match(task_id, signoff_manifest$task_id)
if (!is.na(signoff_idx)) {
  row <- root_lookup[signoff_manifest$root_id[signoff_idx], , drop = FALSE]
  det <- fq_detect_root_signoff(row, repo_root)
  if (!identical(det$state[[1]], "complete_reusable")) {
    fail_verify("root_signoff", det$state[[1]], sprintf("missing_count=%d", det$missing_count[[1]]))
  }
  cat(sprintf("verified root_signoff '%s' as complete_reusable\n", task_id))
  quit(save = "no", status = 0L)
}

review_idx <- match(task_id, root_catalog$review_task_id)
if (!is.na(review_idx)) {
  row <- root_catalog[review_idx, , drop = FALSE]
  det <- fq_detect_root_review(row, repo_root)
  if (!identical(det$state[[1]], "complete_reusable")) {
    fail_verify("root_review", det$state[[1]], sprintf("missing_count=%d", det$missing_count[[1]]))
  }
  cat(sprintf("verified root_review '%s' as complete_reusable\n", task_id))
  quit(save = "no", status = 0L)
}

prior_rows <- comparison_barriers[comparison_barriers$barrier_type == "prior_compare", , drop = FALSE]
prior_idx <- match(task_id, prior_rows$barrier_id)
if (!is.na(prior_idx)) {
  row <- prior_rows[prior_idx, , drop = FALSE]
  det <- fq_detect_prior_compare(row, repo_root)
  if (!identical(det$state[[1]], "complete_reusable")) {
    fail_verify("prior_compare", det$state[[1]], sprintf("missing_count=%d", det$missing_count[[1]]))
  }
  cat(sprintf("verified prior_compare '%s' as complete_reusable\n", task_id))
  quit(save = "no", status = 0L)
}

higher_rows <- comparison_barriers[comparison_barriers$barrier_type %in% c("campaign_review", "global_summary"), , drop = FALSE]
higher_idx <- match(task_id, higher_rows$barrier_id)
if (!is.na(higher_idx)) {
  row <- higher_rows[higher_idx, , drop = FALSE]
  det <- fq_detect_campaign_barrier(row, repo_root)
  if (!identical(det$state[[1]], "complete_reusable")) {
    fail_verify(as.character(row$barrier_type[[1]]), det$state[[1]], sprintf("missing_count=%d", det$missing_count[[1]]))
  }
  cat(sprintf("verified %s '%s' as complete_reusable\n", row$barrier_type[[1]], task_id))
  quit(save = "no", status = 0L)
}

stop(sprintf("Task id '%s' not found in manifests.", task_id), call. = FALSE)

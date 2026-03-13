#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo_root <- if (length(args)) args[[1]] else "."
repo_root <- normalizePath(repo_root, mustWork = TRUE)

source(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_v2_common.R"))

root_catalog <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_root_catalog.tsv"))
model_manifest <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_model_path_scheduler_manifest.tsv"))
postprocess_manifest <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_root_postprocess_manifest.tsv"))
dependency_edges <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_dependency_edges.tsv"))
comparison_barriers <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_comparison_barriers.tsv"))

root_lookup <- root_catalog
rownames(root_lookup) <- root_lookup$root_id
model_with_root <- merge(
  model_manifest,
  root_catalog[, c("root_id", "prepared_root", "run_root")],
  by = c("root_id", "run_root"),
  all.x = TRUE,
  sort = FALSE
)

rows <- list()
model_state_map <- setNames(vector("list", nrow(model_with_root)), model_with_root$task_id)
post_state_map <- setNames(vector("list", nrow(postprocess_manifest)), postprocess_manifest$task_id)
review_state_map <- setNames(vector("list", nrow(root_catalog)), root_catalog$review_task_id)
barrier_state_map <- list()

add_row <- function(df) {
  rows[[length(rows) + 1L]] <<- df
}

prepared_roots <- unique(root_catalog[, c("root_kind", "family", "tau", "fit_size", "prepared_root")])
for (i in seq_len(nrow(prepared_roots))) {
  row <- prepared_roots[i, , drop = FALSE]
  sim_path <- file.path(repo_root, row$prepared_root, "sim_output.rds")
  state <- if (file.exists(sim_path)) "complete_reusable" else "missing"
  add_row(data.frame(
    unit_id = paste0("prep__", gsub("/", "__", row$prepared_root)),
    unit_type = "prepared_input",
    root_id = NA_character_,
    task_id = NA_character_,
    barrier_id = NA_character_,
    root_kind = row$root_kind,
    family = row$family,
    tau = row$tau,
    fit_size = as.integer(row$fit_size),
    prior = NA_character_,
    model = NA_character_,
    scope = "in_scope",
    state = state,
    recommended_action = if (state == "complete_reusable") "skip" else "generate_prepared_input",
    location = row$prepared_root,
    notes = if (state == "complete_reusable") "Prepared simulation input present." else "Missing sim_output.rds for canonical relaunch root.",
    stringsAsFactors = FALSE
  ))
}

for (i in seq_len(nrow(model_with_root))) {
  row <- model_with_root[i, , drop = FALSE]
  det <- fq_detect_model_path(row, repo_root)
  prepared_ok <- file.exists(file.path(repo_root, row$prepared_root, "sim_output.rds"))
  state <- det$state[[1]]
  recommended_action <- det$recommended_action[[1]]
  notes <- c()
  if (!prepared_ok && state == "missing") {
    state <- "blocked"
    recommended_action <- "generate_prepared_input"
    notes <- c(notes, "Prepared input missing.")
  }
  if (det$status_has_error[[1]] || det$pipeline_error[[1]]) {
    notes <- c(notes, "Existing status/pipeline summary indicates an error state.")
  }
  model_state_map[[row$task_id[[1]]]] <- list(
    state = state,
    recommended_action = recommended_action,
    row = row
  )
  add_row(data.frame(
    unit_id = row$task_id,
    unit_type = "model_path",
    root_id = row$root_id,
    task_id = row$task_id,
    barrier_id = NA_character_,
    root_kind = row$root_kind,
    family = row$family,
    tau = row$tau,
    fit_size = as.integer(row$fit_size),
    prior = row$prior,
    model = row$model,
    scope = "in_scope",
    state = state,
    recommended_action = recommended_action,
    location = row$run_root,
    notes = paste(c(
      sprintf("vb_fit=%s", det$vb_fit_exists[[1]]),
      sprintf("mcmc_fit=%s", det$mcmc_fit_exists[[1]]),
      sprintf("status_mcmc_done=%s", det$status_has_mcmc_done[[1]]),
      notes
    ), collapse = " | "),
    stringsAsFactors = FALSE
  ))
}

for (i in seq_len(nrow(postprocess_manifest))) {
  row <- postprocess_manifest[i, , drop = FALSE]
  root_row <- root_lookup[row$root_id, , drop = FALSE]
  det <- fq_detect_root_postprocess(root_row, repo_root)
  dep_ids <- dependency_edges$child_task_id[dependency_edges$parent_task_id == row$task_id]
  deps_complete <- all(vapply(dep_ids, function(id) identical(model_state_map[[id]]$state, "complete_reusable"), logical(1)))
  state <- det$state[[1]]
  recommended_action <- if (state == "complete_reusable") "skip" else "run_root_postprocess"
  if (state == "missing" && !deps_complete) {
    state <- "blocked"
    recommended_action <- "wait_for_model_paths"
  }
  post_state_map[[row$task_id[[1]]]] <- list(state = state, recommended_action = recommended_action)
  add_row(data.frame(
    unit_id = row$task_id,
    unit_type = "root_postprocess",
    root_id = row$root_id,
    task_id = row$task_id,
    barrier_id = NA_character_,
    root_kind = row$root_kind,
    family = row$family,
    tau = row$tau,
    fit_size = as.integer(row$fit_size),
    prior = row$prior,
    model = NA_character_,
    scope = "in_scope",
    state = state,
    recommended_action = recommended_action,
    location = root_row$run_root,
    notes = paste(c(sprintf("deps_complete=%s", deps_complete), sprintf("missing_count=%d", det$missing_count[[1]])), collapse = " | "),
    stringsAsFactors = FALSE
  ))
}

for (i in seq_len(nrow(root_catalog))) {
  row <- root_catalog[i, , drop = FALSE]
  det <- fq_detect_root_review(row, repo_root)
  dep_ids <- dependency_edges$child_task_id[dependency_edges$parent_task_id == row$review_task_id]
  deps_complete <- all(vapply(dep_ids, function(id) identical(post_state_map[[id]]$state, "complete_reusable"), logical(1)))
  state <- det$state[[1]]
  recommended_action <- if (state == "complete_reusable") "skip" else if (row$root_kind == "dynamic") "run_root_postprocess" else "run_root_review"
  if (state == "missing" && !deps_complete) {
    state <- "blocked"
    recommended_action <- "wait_for_root_postprocess"
  }
  review_state_map[[row$review_task_id[[1]]]] <- list(state = state, recommended_action = recommended_action)
  add_row(data.frame(
    unit_id = row$review_task_id,
    unit_type = "root_review",
    root_id = row$root_id,
    task_id = row$review_task_id,
    barrier_id = NA_character_,
    root_kind = row$root_kind,
    family = row$family,
    tau = row$tau,
    fit_size = as.integer(row$fit_size),
    prior = row$prior,
    model = NA_character_,
    scope = "in_scope",
    state = state,
    recommended_action = recommended_action,
    location = row$run_root,
    notes = paste(c(sprintf("deps_complete=%s", deps_complete), sprintf("missing_count=%d", det$missing_count[[1]])), collapse = " | "),
    stringsAsFactors = FALSE
  ))
}

prior_rows <- comparison_barriers[comparison_barriers$barrier_type == "prior_compare", , drop = FALSE]
for (i in seq_len(nrow(prior_rows))) {
  row <- prior_rows[i, , drop = FALSE]
  det <- fq_detect_prior_compare(row, repo_root)
  dep_ids <- dependency_edges$child_task_id[dependency_edges$parent_task_id == row$barrier_id]
  deps_complete <- all(vapply(dep_ids, function(id) identical(review_state_map[[id]]$state, "complete_reusable"), logical(1)))
  state <- det$state[[1]]
  recommended_action <- if (state == "complete_reusable") "skip" else "run_prior_compare"
  if (state == "missing" && !deps_complete) {
    state <- "blocked"
    recommended_action <- "wait_for_root_reviews"
  }
  barrier_state_map[[row$barrier_id[[1]]]] <- list(state = state, recommended_action = recommended_action)
  add_row(data.frame(
    unit_id = row$barrier_id,
    unit_type = "prior_compare",
    root_id = NA_character_,
    task_id = NA_character_,
    barrier_id = row$barrier_id,
    root_kind = row$root_kind,
    family = row$family,
    tau = row$tau,
    fit_size = as.integer(row$fit_size),
    prior = "ridge_vs_rhs",
    model = NA_character_,
    scope = "in_scope",
    state = state,
    recommended_action = recommended_action,
    location = row$compare_root,
    notes = paste(c(sprintf("deps_complete=%s", deps_complete), sprintf("missing_count=%d", det$missing_count[[1]])), collapse = " | "),
    stringsAsFactors = FALSE
  ))
}

higher_rows <- comparison_barriers[comparison_barriers$barrier_type %in% c("campaign_review", "global_summary"), , drop = FALSE]
for (i in seq_len(nrow(higher_rows))) {
  row <- higher_rows[i, , drop = FALSE]
  det <- fq_detect_campaign_barrier(row, repo_root)
  dep_ids <- dependency_edges$child_task_id[dependency_edges$parent_task_id == row$barrier_id]
  deps_complete <- TRUE
  for (dep_id in dep_ids) {
    dep_state <- if (!is.null(review_state_map[[dep_id]])) {
      review_state_map[[dep_id]]$state
    } else if (!is.null(barrier_state_map[[dep_id]])) {
      barrier_state_map[[dep_id]]$state
    } else {
      "blocked"
    }
    deps_complete <- deps_complete && identical(dep_state, "complete_reusable")
  }
  state <- det$state[[1]]
  recommended_action <- if (state == "complete_reusable") "skip" else if (row$barrier_type == "global_summary") "run_global_summary" else "run_campaign_review"
  if (state == "missing" && !deps_complete) {
    state <- "blocked"
    recommended_action <- "wait_for_prerequisites"
  }
  barrier_state_map[[row$barrier_id[[1]]]] <- list(state = state, recommended_action = recommended_action)
  add_row(data.frame(
    unit_id = row$barrier_id,
    unit_type = row$barrier_type,
    root_id = NA_character_,
    task_id = NA_character_,
    barrier_id = row$barrier_id,
    root_kind = row$root_kind,
    family = row$family,
    tau = row$tau,
    fit_size = as.integer(row$fit_size),
    prior = NA_character_,
    model = NA_character_,
    scope = "in_scope",
    state = state,
    recommended_action = recommended_action,
    location = fq_barrier_output_root(row$barrier_id, repo_root),
    notes = paste(c(sprintf("deps_complete=%s", deps_complete), sprintf("missing_count=%d", det$missing_count[[1]])), collapse = " | "),
    stringsAsFactors = FALSE
  ))
}

legacy_rows <- fq_scan_legacy_roots(repo_root, root_catalog, comparison_barriers)
if (nrow(legacy_rows)) {
  rows[[length(rows) + 1L]] <- legacy_rows
}

audit <- do.call(rbind, rows)
audit <- audit[order(audit$scope, audit$unit_type, audit$root_kind, audit$family, audit$tau, audit$fit_size, audit$prior, audit$model), ]

summary_df <- as.data.frame.matrix(table(audit$unit_type, audit$state), stringsAsFactors = FALSE)
summary_df <- cbind(unit_type = rownames(summary_df), summary_df)
rownames(summary_df) <- NULL

out_dir <- file.path(repo_root, "tools", "merge_reports")
fq_write_tsv(audit, file.path(out_dir, "20260312_family_qspec_reusable_state_audit.tsv"))
fq_write_tsv(summary_df, file.path(out_dir, "20260312_family_qspec_reusable_state_audit_summary.tsv"))

cat("Wrote:\n")
cat(file.path(out_dir, "20260312_family_qspec_reusable_state_audit.tsv"), "\n")
cat(file.path(out_dir, "20260312_family_qspec_reusable_state_audit_summary.tsv"), "\n")

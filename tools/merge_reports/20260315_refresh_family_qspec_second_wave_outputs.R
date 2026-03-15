#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo_root <- if (length(args) >= 1L) normalizePath(args[[1L]], mustWork = TRUE) else normalizePath('.', mustWork = TRUE)
jobs <- if (length(args) >= 2L) suppressWarnings(as.integer(args[[2L]])) else suppressWarnings(as.integer(Sys.getenv('EXDQLM_FQSG_REBUILD_JOBS', '8')))
if (!is.finite(jobs) || is.na(jobs) || jobs < 1L) jobs <- 1L
signoff_jobs <- 1L

source(file.path(repo_root, 'tools', 'merge_reports', '20260312_family_qspec_v2_common.R'))

root_catalog <- fq_read_tsv(file.path(repo_root, 'tools', 'merge_reports', '20260312_family_qspec_root_catalog.tsv'))
comparison_barriers <- fq_read_tsv(file.path(repo_root, 'tools', 'merge_reports', '20260312_family_qspec_comparison_barriers.tsv'))
dependency_edges <- fq_read_tsv(file.path(repo_root, 'tools', 'merge_reports', '20260312_family_qspec_dependency_edges.tsv'))
moderate_rows <- fq_read_tsv(file.path(repo_root, 'tools', 'merge_reports', '20260315_family_qspec_newly_eligible_under_second_wave_policy.tsv'))

run_rscript <- function(script, args = character(), env = character(), label = basename(script)) {
  status <- system2('Rscript', c(script, args), env = env)
  if (!identical(status, 0L)) {
    stop(sprintf('Command failed for %s: Rscript %s %s', label, script, paste(args, collapse = ' ')), call. = FALSE)
  }
  invisible(TRUE)
}

parallel_apply <- function(items, fn, mc.cores = 1L) {
  if (!length(items)) return(invisible(list()))
  if (mc.cores > 1L && .Platform$OS.type == 'unix') {
    out <- parallel::mclapply(items, function(item) {
      tryCatch({
        fn(item)
        list(ok = TRUE, id = item)
      }, error = function(e) {
        list(ok = FALSE, id = item, message = conditionMessage(e))
      })
    }, mc.cores = mc.cores)
  } else {
    out <- lapply(items, function(item) {
      tryCatch({
        fn(item)
        list(ok = TRUE, id = item)
      }, error = function(e) {
        list(ok = FALSE, id = item, message = conditionMessage(e))
      })
    })
  }
  failures <- Filter(function(x) !isTRUE(x$ok), out)
  if (length(failures)) {
    stop(
      paste(
        c('One or more refresh subtasks failed:', vapply(failures, function(x) sprintf('- %s: %s', x$id, x$message), character(1))),
        collapse = '\n'
      ),
      call. = FALSE
    )
  }
  invisible(out)
}

impacted_root_ids <- unique(as.character(moderate_rows$root_id))
impacted_root_ids <- impacted_root_ids[!is.na(impacted_root_ids) & nzchar(impacted_root_ids)]
if (!length(impacted_root_ids)) {
  stop('No impacted roots found in newly eligible second-wave policy rows.', call. = FALSE)
}
impacted_roots <- root_catalog[root_catalog$root_id %in% impacted_root_ids, , drop = FALSE]
impacted_review_task_ids <- unique(as.character(impacted_roots$review_task_id))
impacted_review_task_ids <- impacted_review_task_ids[!is.na(impacted_review_task_ids) & nzchar(impacted_review_task_ids)]

prior_rows <- comparison_barriers[comparison_barriers$barrier_type == 'prior_compare', , drop = FALSE]
impacted_prior_barrier_ids <- unique(dependency_edges$parent_task_id[
  dependency_edges$parent_task_type == 'prior_compare' &
    dependency_edges$child_task_id %in% impacted_review_task_ids
])
impacted_prior_rows <- prior_rows[prior_rows$barrier_id %in% impacted_prior_barrier_ids, , drop = FALSE]

campaign_rows <- comparison_barriers[comparison_barriers$barrier_type == 'campaign_review', , drop = FALSE]
impacted_campaign_ids <- unique(dependency_edges$parent_task_id[
  dependency_edges$parent_task_type == 'campaign_review' &
    (dependency_edges$child_task_id %in% impacted_review_task_ids | dependency_edges$child_task_id %in% impacted_prior_barrier_ids)
])
if (!length(impacted_campaign_ids)) {
  impacted_campaign_ids <- unique(campaign_rows$barrier_id[campaign_rows$root_kind %in% unique(impacted_roots$root_kind)])
}
impacted_campaign_ids <- impacted_campaign_ids[!is.na(impacted_campaign_ids) & nzchar(impacted_campaign_ids)]

global_rows <- comparison_barriers[comparison_barriers$barrier_type == 'global_summary', , drop = FALSE]
impacted_global_ids <- unique(dependency_edges$parent_task_id[
  dependency_edges$parent_task_type == 'global_summary' &
    dependency_edges$child_task_id %in% impacted_campaign_ids
])
if (!length(impacted_global_ids)) {
  impacted_global_ids <- unique(global_rows$barrier_id)
}
impacted_global_ids <- impacted_global_ids[!is.na(impacted_global_ids) & nzchar(impacted_global_ids)]

cat(sprintf('Refreshing second-wave policy outputs for %d impacted roots, %d prior barriers, %d campaign barriers, %d global barriers\n',
            nrow(impacted_roots), nrow(impacted_prior_rows), length(impacted_campaign_ids), length(impacted_global_ids)))

parallel_apply(seq_len(nrow(impacted_roots)), function(i) {
  row <- impacted_roots[i, , drop = FALSE]
  run_root_abs <- file.path(repo_root, row$run_root[[1]])
  run_rscript(
    file.path(repo_root, 'tools', 'merge_reports', '20260314_family_qspec_root_signoff.R'),
    args = c(run_root_abs, repo_root),
    label = row$signoff_task_id[[1]]
  )
}, mc.cores = min(jobs, max(1L, nrow(impacted_roots))))

run_rscript(
  file.path(repo_root, 'tools', 'merge_reports', '20260314_build_family_qspec_signoff_views.R'),
  args = c(repo_root),
  env = sprintf('EXDQLM_FQSG_REBUILD_JOBS=%d', signoff_jobs),
  label = 'build_family_qspec_signoff_views'
)

parallel_apply(seq_len(nrow(impacted_roots)), function(i) {
  row <- impacted_roots[i, , drop = FALSE]
  run_root_abs <- file.path(repo_root, row$run_root[[1]])
  if (identical(row$root_kind[[1]], 'dynamic')) {
    run_rscript(
      file.path(repo_root, 'tools', 'merge_reports', '20260314_dynamic_vb_mcmc_report.R'),
      args = run_root_abs,
      label = row$review_task_id[[1]]
    )
  } else {
    run_rscript(
      file.path(repo_root, 'tools', 'merge_reports', '20260305_static_vb_mcmc_report.R'),
      env = sprintf('EXDQLM_STATIC_RUN_ROOT=%s', run_root_abs),
      label = row$review_task_id[[1]]
    )
  }
}, mc.cores = min(jobs, max(1L, nrow(impacted_roots))))

parallel_apply(seq_len(nrow(impacted_prior_rows)), function(i) {
  row <- impacted_prior_rows[i, , drop = FALSE]
  prepared_abs <- file.path(repo_root, row$prepared_root[[1]])
  out_root_abs <- file.path(repo_root, row$compare_root[[1]])
  fit_size <- as.integer(row$fit_size[[1]])
  tau <- as.character(row$tau[[1]])
  ridge_run_root <- file.path(repo_root, row$prepared_root[[1]], sprintf('validation_shrink_ridge_tt%d', fit_size))
  rhs_run_root <- file.path(repo_root, row$prepared_root[[1]], sprintf('validation_shrink_rhs_tt%d', fit_size))
  run_rscript(
    file.path(repo_root, 'tools', 'merge_reports', '20260308_static_shrinkage_compare_report.R'),
    env = c(
      sprintf('EXDQLM_STATIC_SHRINK_SIM_PATH=%s', file.path(prepared_abs, 'sim_output.rds')),
      sprintf('EXDQLM_STATIC_SHRINK_RIDGE_RUN_ROOT=%s', ridge_run_root),
      sprintf('EXDQLM_STATIC_SHRINK_RHS_RUN_ROOT=%s', rhs_run_root),
      sprintf('EXDQLM_STATIC_SHRINK_TAUS=%s', tau),
      sprintf('EXDQLM_STATIC_SHRINK_OUT_ROOT=%s', out_root_abs)
    ),
    label = row$barrier_id[[1]]
  )
}, mc.cores = min(jobs, max(1L, nrow(impacted_prior_rows))))

for (task_id in impacted_campaign_ids) {
  run_rscript(
    file.path(repo_root, 'tools', 'merge_reports', '20260312_family_qspec_campaign_aggregate.R'),
    args = c(task_id, repo_root),
    label = task_id
  )
}

for (task_id in impacted_global_ids) {
  run_rscript(
    file.path(repo_root, 'tools', 'merge_reports', '20260312_family_qspec_campaign_aggregate.R'),
    args = c(task_id, repo_root),
    label = task_id
  )
}

run_rscript(
  file.path(repo_root, 'tools', 'merge_reports', '20260314_build_family_qspec_scientific_snapshot.R'),
  args = repo_root,
  label = 'build_family_qspec_scientific_snapshot'
)

cat('Second-wave targeted policy refresh complete.\n')

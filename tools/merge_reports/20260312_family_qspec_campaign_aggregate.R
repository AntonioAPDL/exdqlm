#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (!length(args)) {
  stop("Usage: 20260312_family_qspec_campaign_aggregate.R <barrier_id> [repo_root]")
}
barrier_id <- args[[1]]
repo_root <- if (length(args) >= 2L) args[[2]] else "."
repo_root <- normalizePath(repo_root, mustWork = TRUE)

source(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_v2_common.R"))

root_catalog <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_root_catalog.tsv"))
dependency_edges <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_dependency_edges.tsv"))
comparison_barriers <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_comparison_barriers.tsv"))

barrier_row <- comparison_barriers[comparison_barriers$barrier_id == barrier_id, , drop = FALSE]
barrier_type <- if (nrow(barrier_row)) barrier_row$barrier_type[[1]] else if (barrier_id == "campaign__global_cross_family_summary") "global_summary" else "campaign_review"
out_root <- fq_barrier_output_root(barrier_id, repo_root)
if (is.na(out_root) || !nzchar(out_root)) {
  stop("No output root mapping for barrier_id: ", barrier_id)
}
dir.create(file.path(out_root, "tables"), recursive = TRUE, showWarnings = FALSE)

timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

rbind_fill_list <- function(dfs) {
  dfs <- dfs[!vapply(dfs, is.null, logical(1))]
  if (!length(dfs)) return(data.frame())
  all_names <- unique(unlist(lapply(dfs, names), use.names = FALSE))
  dfs <- lapply(dfs, function(df) {
    missing <- setdiff(all_names, names(df))
    if (length(missing)) {
      for (nm in missing) df[[nm]] <- NA
    }
    df[, all_names, drop = FALSE]
  })
  do.call(rbind, dfs)
}

dep_rows <- dependency_edges[dependency_edges$parent_task_id == barrier_id, , drop = FALSE]
if (!nrow(dep_rows)) {
  stop("No dependency edges found for barrier_id: ", barrier_id)
}

read_table_annotated <- function(root_row, rel_file) {
  path <- file.path(repo_root, root_row$run_root, "tables", rel_file)
  if (!file.exists(path)) {
    stop("Missing required root table for ", root_row$root_id, ": ", path)
  }
  empty_schema <- switch(
    rel_file,
    "metrics_summary.csv" = data.frame(
      inference = character(0),
      model = character(0),
      tau = numeric(0),
      rmse = numeric(0),
      coverage = numeric(0),
      mean_ci_width = numeric(0),
      stringsAsFactors = FALSE
    ),
    "pairwise_exal_vs_al.csv" = data.frame(
      tau = numeric(0),
      method = character(0),
      rmse_exal = numeric(0),
      rmse_al = numeric(0),
      mae_exal = numeric(0),
      mae_al = numeric(0),
      rmse_delta_exal_minus_al = numeric(0),
      mae_delta_exal_minus_al = numeric(0),
      stringsAsFactors = FALSE
    ),
    "runtime_diagnostics_summary.csv" = data.frame(
      model = character(0),
      tau = numeric(0),
      vb_runtime_sec = numeric(0),
      vb_file = character(0),
      mcmc_runtime_sec = numeric(0),
      mcmc_file = character(0),
      vb_converged = logical(0),
      vb_stop_reason = character(0),
      accept_rate = numeric(0),
      ess_sigma = numeric(0),
      ess_gamma = numeric(0),
      mcmc_gamma_kernel_exact = logical(0),
      mcmc_signoff_ready = logical(0),
      status = character(0),
      beta_prior = character(0),
      runtime_sec = numeric(0),
      stringsAsFactors = FALSE
    ),
    "acceptance_gate_summary.csv" = data.frame(
      model = character(0),
      tau = numeric(0),
      beta_prior = character(0),
      vb_converged = logical(0),
      vb_stop_reason = character(0),
      ess_sigma = numeric(0),
      ess_gamma = numeric(0),
      status = character(0),
      mcmc_gamma_kernel_exact = logical(0),
      mcmc_signoff_ready = logical(0),
      gate_vb_converged = logical(0),
      gate_mcmc_ess_sigma = logical(0),
      gate_mcmc_ess_gamma = logical(0),
      ld_trace_rows = integer(0),
      ld_xi_rel_drift_last = numeric(0),
      ld_xi_median_abs_tail = numeric(0),
      ld_xi_flip_rate_tail = numeric(0),
      ld_cov_condition_last = numeric(0),
      ld_hess_condition_last = numeric(0),
      ld_sigma_sd_tail = numeric(0),
      ld_sigma_range_tail = numeric(0),
      ld_sigma_flip_rate_tail = numeric(0),
      ld_gamma_sd_tail = numeric(0),
      ld_gamma_range_tail = numeric(0),
      ld_gamma_flip_rate_tail = numeric(0),
      ld_xi_mcse_max_last = numeric(0),
      ld_xi_mcse_mean_last = numeric(0),
      ld_xi_mcse_max_tail = numeric(0),
      ld_mode_grad_inf_norm_final = numeric(0),
      ld_mode_neg_hess_min_eig_final = numeric(0),
      ld_mode_neg_hess_condition_final = numeric(0),
      ld_local_mode_pass = logical(0),
      ld_candidate_local_pass_rate_tail = numeric(0),
      ld_committed_local_pass_rate_tail = numeric(0),
      ld_committed_stable_tail = logical(0),
      ld_candidate_grad_inf_median_tail = numeric(0),
      ld_committed_grad_inf_median_tail = numeric(0),
      ld_objective_gap_median_tail = numeric(0),
      ld_stabilized_rate_tail = numeric(0),
      ld_direct_commit_rate_tail = numeric(0),
      ld_damped_commit_rate_tail = numeric(0),
      ld_optim_fallback_rate = numeric(0),
      ld_numeric_hessian_rate = numeric(0),
      ld_identity_hessian_rate = numeric(0),
      ld_cov_floor_rate = numeric(0),
      ld_mode_fallback_rate = numeric(0),
      gate_vb_ld_stable = logical(0),
      gate_vb_ld_local_mode = logical(0),
      gate_mcmc_kernel_exact = logical(0),
      gate_accuracy = logical(0),
      overall_pass = logical(0),
      stringsAsFactors = FALSE
    ),
    "fit_summary.csv" = data.frame(
      inference = character(0),
      model = character(0),
      tau = numeric(0),
      beta_prior = character(0),
      runtime_sec = numeric(0),
      iter_like = integer(0),
      converged = logical(0),
      stop_reason = character(0),
      sigma_mean = numeric(0),
      gamma_mean = numeric(0),
      rhs_collapse_flag = logical(0),
      rhs_collapse_warning = character(0),
      fit_file = character(0),
      stringsAsFactors = FALSE
    ),
    data.frame()
  )
  df <- tryCatch(
    utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE),
    error = function(e) {
      msg <- conditionMessage(e)
      if (grepl("first five rows are empty", msg, fixed = TRUE) ||
          grepl("no lines available in input", msg, fixed = TRUE)) {
        return(empty_schema)
      }
      stop(e)
    }
  )
  n <- nrow(df)
  df$root_id <- rep(root_row$root_id, n)
  df$root_kind <- rep(root_row$root_kind, n)
  df$family <- rep(root_row$family, n)
  df$tau <- rep(root_row$tau, n)
  df$fit_size <- rep(root_row$fit_size, n)
  df$prior <- rep(root_row$prior, n)
  df$run_root <- rep(root_row$run_root, n)
  df
}

read_compare_table <- function(barrier_row, rel_file) {
  path <- file.path(repo_root, barrier_row$compare_root, "tables", rel_file)
  if (!file.exists(path)) {
    stop("Missing required compare table for ", barrier_row$barrier_id, ": ", path)
  }
  df <- utils::read.csv(path, stringsAsFactors = FALSE)
  n <- nrow(df)
  df$barrier_id <- rep(barrier_row$barrier_id, n)
  df$root_kind <- rep(barrier_row$root_kind, n)
  df$family <- rep(barrier_row$family, n)
  df$tau <- rep(barrier_row$tau, n)
  df$fit_size <- rep(barrier_row$fit_size, n)
  df$compare_root <- rep(barrier_row$compare_root, n)
  df
}

if (barrier_type == "campaign_review") {
  prereq_inventory <- data.frame()
  root_review_ids <- dep_rows$child_task_id[dep_rows$child_task_type == "root_review"]
  compare_ids <- dep_rows$child_task_id[dep_rows$child_task_type == "prior_compare"]

  root_rows <- root_catalog[root_catalog$review_task_id %in% root_review_ids, , drop = FALSE]
  if (!nrow(root_rows)) {
    stop("No root reviews resolved for campaign barrier: ", barrier_id)
  }

  root_states <- lapply(seq_len(nrow(root_rows)), function(i) fq_detect_root_review(root_rows[i, , drop = FALSE], repo_root))
  root_complete <- vapply(root_states, function(x) identical(x$state[[1]], "complete_reusable"), logical(1))
  if (!all(root_complete)) {
    stop("Campaign barrier not ready; incomplete root reviews: ", paste(root_rows$root_id[!root_complete], collapse = ", "))
  }
  prereq_inventory <- rbind(
    prereq_inventory,
    data.frame(
      prerequisite_id = root_rows$review_task_id,
      prerequisite_type = "root_review",
      root_id = root_rows$root_id,
      root_kind = root_rows$root_kind,
      family = root_rows$family,
      tau = root_rows$tau,
      fit_size = root_rows$fit_size,
      prior = root_rows$prior,
      location = root_rows$run_root,
      state = "complete_reusable",
      stringsAsFactors = FALSE
    )
  )

  compare_rows <- comparison_barriers[comparison_barriers$barrier_id %in% compare_ids, , drop = FALSE]
  if (nrow(compare_rows)) {
    compare_states <- lapply(seq_len(nrow(compare_rows)), function(i) fq_detect_prior_compare(compare_rows[i, , drop = FALSE], repo_root))
    compare_complete <- vapply(compare_states, function(x) identical(x$state[[1]], "complete_reusable"), logical(1))
    if (!all(compare_complete)) {
      stop("Campaign barrier not ready; incomplete prior compare outputs: ", paste(compare_rows$barrier_id[!compare_complete], collapse = ", "))
    }
    prereq_inventory <- rbind(
      prereq_inventory,
      data.frame(
        prerequisite_id = compare_rows$barrier_id,
        prerequisite_type = "prior_compare",
        root_id = NA_character_,
        root_kind = compare_rows$root_kind,
        family = compare_rows$family,
        tau = compare_rows$tau,
        fit_size = compare_rows$fit_size,
        prior = "ridge_vs_rhs",
        location = compare_rows$compare_root,
        state = "complete_reusable",
        stringsAsFactors = FALSE
      )
    )
  }

  utils::write.table(prereq_inventory, file.path(out_root, "tables", "prerequisite_inventory.tsv"), sep = "\t", row.names = FALSE, quote = FALSE)

  metrics_long <- rbind_fill_list(lapply(seq_len(nrow(root_rows)), function(i) read_table_annotated(root_rows[i, , drop = FALSE], "metrics_summary.csv")))
  utils::write.table(metrics_long, file.path(out_root, "tables", "metrics_summary_long.tsv"), sep = "\t", row.names = FALSE, quote = FALSE)

  if (barrier_id %in% c("campaign__static_paper", "campaign__static_shrink")) {
    pairwise_long <- rbind_fill_list(lapply(seq_len(nrow(root_rows)), function(i) read_table_annotated(root_rows[i, , drop = FALSE], "pairwise_exal_vs_al.csv")))
    runtime_long <- rbind_fill_list(lapply(seq_len(nrow(root_rows)), function(i) read_table_annotated(root_rows[i, , drop = FALSE], "runtime_diagnostics_summary.csv")))
    gates_long <- rbind_fill_list(lapply(seq_len(nrow(root_rows)), function(i) read_table_annotated(root_rows[i, , drop = FALSE], "acceptance_gate_summary.csv")))
    utils::write.table(pairwise_long, file.path(out_root, "tables", "pairwise_exal_vs_al_long.tsv"), sep = "\t", row.names = FALSE, quote = FALSE)
    utils::write.table(runtime_long, file.path(out_root, "tables", "runtime_diagnostics_summary_long.tsv"), sep = "\t", row.names = FALSE, quote = FALSE)
    utils::write.table(gates_long, file.path(out_root, "tables", "acceptance_gate_summary_long.tsv"), sep = "\t", row.names = FALSE, quote = FALSE)
  } else {
    fit_long <- rbind_fill_list(lapply(seq_len(nrow(root_rows)), function(i) read_table_annotated(root_rows[i, , drop = FALSE], "fit_summary.csv")))
    utils::write.table(fit_long, file.path(out_root, "tables", "fit_summary_long.tsv"), sep = "\t", row.names = FALSE, quote = FALSE)
  }

  if (barrier_id == "campaign__static_shrink") {
    compare_long <- rbind_fill_list(lapply(seq_len(nrow(compare_rows)), function(i) read_compare_table(compare_rows[i, , drop = FALSE], "rhs_vs_ridge_summary.csv")))
    utils::write.table(compare_long, file.path(out_root, "tables", "rhs_vs_ridge_summary_long.tsv"), sep = "\t", row.names = FALSE, quote = FALSE)
  }

  summary_df <- data.frame(
    barrier_id = barrier_id,
    generated_at = timestamp,
    prerequisite_count = nrow(prereq_inventory),
    root_review_count = nrow(root_rows),
    prior_compare_count = nrow(compare_rows),
    family_count = length(unique(root_rows$family)),
    tau_count = length(unique(root_rows$tau)),
    fit_size_count = length(unique(root_rows$fit_size)),
    metrics_rows = nrow(metrics_long),
    stringsAsFactors = FALSE
  )
  utils::write.table(summary_df, file.path(out_root, "tables", "campaign_summary.tsv"), sep = "\t", row.names = FALSE, quote = FALSE)

  writeLines(c(
    paste0("# ", barrier_id),
    "",
    paste0("- generated_at: `", timestamp, "`"),
    paste0("- root_review_count: `", nrow(root_rows), "`"),
    paste0("- prior_compare_count: `", nrow(compare_rows), "`"),
    paste0("- prerequisite_inventory: `tables/prerequisite_inventory.tsv`"),
    paste0("- campaign_summary: `tables/campaign_summary.tsv`")
  ), con = file.path(out_root, "report_summary.md"))
} else if (barrier_type == "global_summary") {
  dep_barrier_ids <- dep_rows$child_task_id
  prereq_inventory <- data.frame(
    prerequisite_id = dep_barrier_ids,
    prerequisite_type = dep_rows$child_task_type,
    root_id = NA_character_,
    root_kind = NA_character_,
    family = NA_character_,
    tau = NA_character_,
    fit_size = NA_integer_,
    prior = NA_character_,
    location = vapply(dep_barrier_ids, fq_barrier_output_root, character(1), repo_root = repo_root),
    state = NA_character_,
    stringsAsFactors = FALSE
  )
  summary_rows <- lapply(seq_along(dep_barrier_ids), function(i) {
    dep_id <- dep_barrier_ids[[i]]
    dep_row <- data.frame(barrier_id = dep_id, barrier_type = "campaign_review", stringsAsFactors = FALSE)
    det <- fq_detect_campaign_barrier(dep_row, repo_root)
    prereq_inventory$state[[i]] <<- det$state[[1]]
    if (!identical(det$state[[1]], "complete_reusable")) {
      stop("Global summary not ready; incomplete campaign aggregate: ", dep_id)
    }
    utils::read.delim(file.path(fq_barrier_output_root(dep_id, repo_root), "tables", "campaign_summary.tsv"), sep = "\t", stringsAsFactors = FALSE, check.names = FALSE)
  })
  utils::write.table(prereq_inventory, file.path(out_root, "tables", "prerequisite_inventory.tsv"), sep = "\t", row.names = FALSE, quote = FALSE)
  global_df <- rbind_fill_list(summary_rows)
  utils::write.table(global_df, file.path(out_root, "tables", "global_summary.tsv"), sep = "\t", row.names = FALSE, quote = FALSE)
  writeLines(c(
    "# campaign__global_cross_family_summary",
    "",
    paste0("- generated_at: `", timestamp, "`"),
    paste0("- campaign_count: `", nrow(global_df), "`"),
    paste0("- prerequisite_inventory: `tables/prerequisite_inventory.tsv`"),
    paste0("- global_summary: `tables/global_summary.tsv`")
  ), con = file.path(out_root, "report_summary.md"))
} else {
  stop("Unsupported barrier_type for aggregation: ", barrier_type)
}

cat(sprintf("Aggregation complete for %s under %s\n", barrier_id, out_root))

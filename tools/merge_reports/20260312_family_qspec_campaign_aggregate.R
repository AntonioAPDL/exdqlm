#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (!length(args)) {
  stop("Usage: 20260312_family_qspec_campaign_aggregate.R <barrier_id> [repo_root]", call. = FALSE)
}
barrier_id <- args[[1]]
repo_root <- if (length(args) >= 2L) args[[2]] else "."
repo_root <- normalizePath(repo_root, mustWork = TRUE)

source(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_v2_common.R"))

root_catalog <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_root_catalog.tsv"))
dependency_edges <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_dependency_edges.tsv"))
comparison_barriers <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_comparison_barriers.tsv"))

barrier_row <- comparison_barriers[comparison_barriers$barrier_id == barrier_id, , drop = FALSE]
barrier_type <- if (nrow(barrier_row)) barrier_row$barrier_type[[1]] else if (identical(barrier_id, "campaign__global_cross_family_summary")) "global_summary" else "campaign_review"
out_root <- fq_barrier_output_root(barrier_id, repo_root)
if (is.na(out_root) || !nzchar(out_root)) {
  stop("No output root mapping for barrier_id: ", barrier_id, call. = FALSE)
}
out_tables <- file.path(out_root, "tables")
dir.create(out_tables, recursive = TRUE, showWarnings = FALSE)
timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

rbind_fill_list <- function(dfs) {
  dfs <- dfs[!vapply(dfs, is.null, logical(1))]
  if (!length(dfs)) return(data.frame(stringsAsFactors = FALSE))
  cols <- unique(unlist(lapply(dfs, names), use.names = FALSE))
  dfs2 <- lapply(dfs, function(df) {
    miss <- setdiff(cols, names(df))
    if (length(miss)) {
      for (nm in miss) df[[nm]] <- rep(NA, nrow(df))
    }
    df[, cols, drop = FALSE]
  })
  do.call(rbind, dfs2)
}

read_root_table <- function(root_row, rel_file, required = TRUE) {
  path <- file.path(repo_root, root_row$run_root, "tables", rel_file)
  df <- fq_read_csv_safe(path)
  if (is.null(df)) {
    if (isTRUE(required)) {
      stop("Missing required root table for ", root_row$root_id, ": ", path, call. = FALSE)
    }
    df <- data.frame(stringsAsFactors = FALSE)
  }
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

read_compare_table <- function(barrier_row, rel_file, required = TRUE) {
  path <- file.path(repo_root, barrier_row$compare_root, "tables", rel_file)
  df <- fq_read_csv_safe(path)
  if (is.null(df)) {
    if (isTRUE(required)) {
      stop("Missing required compare table for ", barrier_row$barrier_id, ": ", path, call. = FALSE)
    }
    df <- data.frame(stringsAsFactors = FALSE)
  }
  n <- nrow(df)
  df$barrier_id <- rep(barrier_row$barrier_id, n)
  df$root_kind <- rep(barrier_row$root_kind, n)
  df$family <- rep(barrier_row$family, n)
  df$tau <- rep(barrier_row$tau, n)
  df$fit_size <- rep(barrier_row$fit_size, n)
  df$compare_root <- rep(barrier_row$compare_root, n)
  df
}

write_tsv <- function(df, name) {
  fq_write_tsv(df, file.path(out_tables, name))
}

combine_root_tables <- function(root_rows, rel_file, required = TRUE) {
  rbind_fill_list(lapply(seq_len(nrow(root_rows)), function(i) read_root_table(root_rows[i, , drop = FALSE], rel_file, required = required)))
}

normalize_model_pair_table <- function(df, root_kind) {
  if (!nrow(df)) {
    return(df)
  }
  out <- df
  if (!("rmse_extended" %in% names(out)) && "rmse_exal" %in% names(out)) {
    out$rmse_baseline <- out$rmse_al
    out$rmse_extended <- out$rmse_exal
  }
  if (!("mae_extended" %in% names(out)) && "mae_exal" %in% names(out)) {
    out$mae_baseline <- out$mae_al
    out$mae_extended <- out$mae_exal
  }
  if (!("rmse_delta_extended_minus_baseline" %in% names(out)) && "rmse_delta_exal_minus_al" %in% names(out)) {
    out$rmse_delta_extended_minus_baseline <- out$rmse_delta_exal_minus_al
  }
  if (!("mae_delta_extended_minus_baseline" %in% names(out)) && "mae_delta_exal_minus_al" %in% names(out)) {
    out$mae_delta_extended_minus_baseline <- out$mae_delta_exal_minus_al
  }
  if (!("signoff_grade_baseline" %in% names(out)) && "baseline_signoff_grade" %in% names(out)) {
    out$signoff_grade_baseline <- out$baseline_signoff_grade
  }
  if (!("signoff_grade_extended" %in% names(out)) && "extended_signoff_grade" %in% names(out)) {
    out$signoff_grade_extended <- out$extended_signoff_grade
  }
  if (!("comparison_eligible_baseline" %in% names(out))) {
    out$comparison_eligible_baseline <- NA
  }
  if (!("comparison_eligible_extended" %in% names(out))) {
    out$comparison_eligible_extended <- NA
  }
  if (!("method" %in% names(out)) && "inference" %in% names(out)) {
    out$method <- out$inference
  }
  if (!("inference" %in% names(out)) && "method" %in% names(out)) {
    out$inference <- out$method
  }
  if (!("model_baseline" %in% names(out))) {
    out$model_baseline <- if (identical(root_kind, "dynamic")) "dqlm" else "al"
  }
  if (!("model_extended" %in% names(out))) {
    out$model_extended <- if (identical(root_kind, "dynamic")) "exdqlm" else "exal"
  }
  out
}

summarise_signoff_counts <- function(method_long, algorithm_long, model_long, root_long, repair_long, metrics_all, metrics_eligible, pair_eligible, pair_excluded) {
  data.frame(
    method_rows = nrow(method_long),
    method_signoff_pass_count = sum(method_long$signoff_grade == "PASS", na.rm = TRUE),
    method_signoff_warn_count = sum(method_long$signoff_grade == "WARN", na.rm = TRUE),
    method_signoff_fail_count = sum(method_long$signoff_grade == "FAIL", na.rm = TRUE),
    method_comparison_eligible_count = sum(as.logical(method_long$comparison_eligible), na.rm = TRUE),
    algorithm_pair_rows = nrow(algorithm_long),
    algorithm_pair_pass_count = sum(algorithm_long$pair_signoff_grade == "PASS", na.rm = TRUE),
    algorithm_pair_warn_count = sum(algorithm_long$pair_signoff_grade == "WARN", na.rm = TRUE),
    algorithm_pair_fail_count = sum(algorithm_long$pair_signoff_grade == "FAIL", na.rm = TRUE),
    algorithm_pair_eligible_count = sum(as.logical(algorithm_long$pair_comparison_eligible), na.rm = TRUE),
    model_pair_rows = nrow(model_long),
    model_pair_pass_count = sum(model_long$pair_signoff_grade == "PASS", na.rm = TRUE),
    model_pair_warn_count = sum(model_long$pair_signoff_grade == "WARN", na.rm = TRUE),
    model_pair_fail_count = sum(model_long$pair_signoff_grade == "FAIL", na.rm = TRUE),
    model_pair_eligible_count = sum(as.logical(model_long$pair_comparison_eligible), na.rm = TRUE),
    root_signoff_rows = nrow(root_long),
    root_full_eligible_count = sum(as.logical(root_long$root_comparison_eligible_full), na.rm = TRUE),
    root_any_eligible_count = sum(as.logical(root_long$root_comparison_eligible_any), na.rm = TRUE),
    repair_target_count = nrow(repair_long),
    metric_rows_all = nrow(metrics_all),
    metric_rows_eligible = nrow(metrics_eligible),
    pairwise_rows_eligible = nrow(pair_eligible),
    pairwise_rows_excluded = nrow(pair_excluded),
    stringsAsFactors = FALSE
  )
}

safe_mean_num <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  x <- x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  mean(x)
}

summarise_vb_vs_mcmc <- function(vb_long) {
  if (!nrow(vb_long)) {
    return(data.frame(
      root_kind = character(0),
      family = character(0),
      model = character(0),
      comparison_rows = integer(0),
      eligible_rows = integer(0),
      mcmc_better_rmse_count = integer(0),
      vb_better_rmse_count = integer(0),
      tie_rmse_count = integer(0),
      mean_rmse_vb = numeric(0),
      mean_rmse_mcmc = numeric(0),
      mean_rmse_delta_mcmc_minus_vb = numeric(0),
      mean_mae_delta_mcmc_minus_vb = numeric(0),
      mean_bias_delta_mcmc_minus_vb = numeric(0),
      mean_corr_delta_mcmc_minus_vb = numeric(0),
      mean_coverage_delta_mcmc_minus_vb = numeric(0),
      mean_ci_width_delta_mcmc_minus_vb = numeric(0),
      mean_runtime_ratio_mcmc_vs_vb = numeric(0),
      stringsAsFactors = FALSE
    ))
  }
  key_df <- unique(vb_long[, c("root_kind", "family", "model"), drop = FALSE])
  key_df <- key_df[order(key_df$root_kind, key_df$family, key_df$model), , drop = FALSE]
  rows <- lapply(seq_len(nrow(key_df)), function(i) {
    rk <- key_df$root_kind[[i]]
    fm <- key_df$family[[i]]
    md <- key_df$model[[i]]
    sub <- vb_long[vb_long$root_kind == rk & vb_long$family == fm & vb_long$model == md, , drop = FALSE]
    delta <- suppressWarnings(as.numeric(sub$rmse_delta_mcmc_minus_vb))
    elig <- as.logical(sub$algorithm_pair_comparison_eligible %in% TRUE)
    data.frame(
      root_kind = rk,
      family = fm,
      model = md,
      comparison_rows = nrow(sub),
      eligible_rows = sum(elig, na.rm = TRUE),
      mcmc_better_rmse_count = sum(delta < 0, na.rm = TRUE),
      vb_better_rmse_count = sum(delta > 0, na.rm = TRUE),
      tie_rmse_count = sum(delta == 0, na.rm = TRUE),
      mean_rmse_vb = safe_mean_num(sub$rmse_vb),
      mean_rmse_mcmc = safe_mean_num(sub$rmse_mcmc),
      mean_rmse_delta_mcmc_minus_vb = safe_mean_num(sub$rmse_delta_mcmc_minus_vb),
      mean_mae_delta_mcmc_minus_vb = safe_mean_num(sub$mae_delta_mcmc_minus_vb),
      mean_bias_delta_mcmc_minus_vb = safe_mean_num(sub$bias_delta_mcmc_minus_vb),
      mean_corr_delta_mcmc_minus_vb = safe_mean_num(sub$corr_delta_mcmc_minus_vb),
      mean_coverage_delta_mcmc_minus_vb = safe_mean_num(sub$coverage_delta_mcmc_minus_vb),
      mean_ci_width_delta_mcmc_minus_vb = safe_mean_num(sub$mean_ci_width_delta_mcmc_minus_vb),
      mean_runtime_ratio_mcmc_vs_vb = safe_mean_num(sub$runtime_ratio_mcmc_vs_vb),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

if (identical(barrier_type, "campaign_review")) {
  dep_rows <- dependency_edges[dependency_edges$parent_task_id == barrier_id, , drop = FALSE]
  if (!nrow(dep_rows)) {
    stop("No dependency edges found for barrier_id: ", barrier_id, call. = FALSE)
  }

  root_review_ids <- dep_rows$child_task_id[dep_rows$child_task_type == "root_review"]
  compare_ids <- dep_rows$child_task_id[dep_rows$child_task_type == "prior_compare"]
  root_rows <- root_catalog[root_catalog$review_task_id %in% root_review_ids, , drop = FALSE]
  if (!nrow(root_rows)) {
    stop("No root reviews resolved for campaign barrier: ", barrier_id, call. = FALSE)
  }

  root_states <- lapply(seq_len(nrow(root_rows)), function(i) fq_detect_root_review(root_rows[i, , drop = FALSE], repo_root))
  root_complete <- vapply(root_states, function(x) identical(x$state[[1]], "complete_reusable"), logical(1))
  if (!all(root_complete)) {
    stop("Campaign barrier not ready; incomplete root reviews: ", paste(root_rows$root_id[!root_complete], collapse = ", "), call. = FALSE)
  }

  compare_rows <- comparison_barriers[comparison_barriers$barrier_id %in% compare_ids, , drop = FALSE]
  if (nrow(compare_rows)) {
    compare_states <- lapply(seq_len(nrow(compare_rows)), function(i) fq_detect_prior_compare(compare_rows[i, , drop = FALSE], repo_root))
    compare_complete <- vapply(compare_states, function(x) identical(x$state[[1]], "complete_reusable"), logical(1))
    if (!all(compare_complete)) {
      stop("Campaign barrier not ready; incomplete prior compare outputs: ", paste(compare_rows$barrier_id[!compare_complete], collapse = ", "), call. = FALSE)
    }
  }

  prereq_inventory <- data.frame(
    prerequisite_id = c(root_rows$review_task_id, compare_rows$barrier_id),
    prerequisite_type = c(rep("root_review", nrow(root_rows)), rep("prior_compare", nrow(compare_rows))),
    root_id = c(root_rows$root_id, rep(NA_character_, nrow(compare_rows))),
    root_kind = c(root_rows$root_kind, compare_rows$root_kind),
    family = c(root_rows$family, compare_rows$family),
    tau = c(root_rows$tau, compare_rows$tau),
    fit_size = c(root_rows$fit_size, compare_rows$fit_size),
    prior = c(root_rows$prior, rep("ridge_vs_rhs", nrow(compare_rows))),
    location = c(root_rows$run_root, compare_rows$compare_root),
    state = "complete_reusable",
    stringsAsFactors = FALSE
  )
  write_tsv(prereq_inventory, "prerequisite_inventory.tsv")

  metrics_summary_long <- combine_root_tables(root_rows, "metrics_summary.csv")
  method_signoff_long <- combine_root_tables(root_rows, "method_signoff_long.csv")
  algorithm_pair_signoff_long <- combine_root_tables(root_rows, "algorithm_pair_signoff.csv")
  model_pair_signoff_long <- combine_root_tables(root_rows, "model_pair_signoff.csv")
  root_signoff_summary_long <- combine_root_tables(root_rows, "root_signoff_summary.csv")
  repair_targets_long <- combine_root_tables(root_rows, "repair_targets.csv")

  write_tsv(metrics_summary_long, "metrics_summary_long.tsv")
  write_tsv(method_signoff_long, "method_signoff_long.tsv")
  write_tsv(algorithm_pair_signoff_long, "algorithm_pair_signoff_long.tsv")
  write_tsv(model_pair_signoff_long, "model_pair_signoff_long.tsv")
  write_tsv(root_signoff_summary_long, "root_signoff_summary_long.tsv")
  write_tsv(repair_targets_long, "repair_targets_long.tsv")

  fit_metrics_long <- data.frame(stringsAsFactors = FALSE)
  fit_metrics_eligible_long <- data.frame(stringsAsFactors = FALSE)
  pairwise_long <- data.frame(stringsAsFactors = FALSE)
  pairwise_excluded_long <- data.frame(stringsAsFactors = FALSE)
  pairwise_model_compare_long <- data.frame(stringsAsFactors = FALSE)
  pairwise_model_compare_excluded_long <- data.frame(stringsAsFactors = FALSE)
  vb_mcmc_long <- data.frame(stringsAsFactors = FALSE)
  vb_mcmc_eligible_long <- data.frame(stringsAsFactors = FALSE)
  vb_mcmc_excluded_long <- data.frame(stringsAsFactors = FALSE)
  runtime_long <- data.frame(stringsAsFactors = FALSE)
  gates_long <- data.frame(stringsAsFactors = FALSE)
  fit_summary_long <- data.frame(stringsAsFactors = FALSE)

  if (identical(barrier_id, "campaign__dynamic")) {
    fit_summary_long <- combine_root_tables(root_rows, "fit_summary.csv")
    method_map <- method_signoff_long[, c(
      "root_id", "inference", "model", "tau", "signoff_grade", "comparison_eligible",
      "convergence_certified", "execution_healthy", "signoff_reason"
    ), drop = FALSE]
    fit_metrics_long <- merge(
      metrics_summary_long,
      method_map,
      by = c("root_id", "inference", "model", "tau"),
      all.x = TRUE,
      sort = FALSE
    )
    fit_metrics_eligible_long <- fit_metrics_long[as.logical(fit_metrics_long$comparison_eligible %in% TRUE), , drop = FALSE]
    write_tsv(fit_summary_long, "fit_summary_long.tsv")
    pairwise_long <- combine_root_tables(root_rows, "pairwise_exdqlm_vs_dqlm.csv")
    pairwise_excluded_long <- combine_root_tables(root_rows, "pairwise_exdqlm_vs_dqlm_excluded.csv")
    pairwise_model_compare_long <- normalize_model_pair_table(pairwise_long, "dynamic")
    pairwise_model_compare_excluded_long <- normalize_model_pair_table(pairwise_excluded_long, "dynamic")
    write_tsv(pairwise_long, "pairwise_exdqlm_vs_dqlm_long.tsv")
    write_tsv(pairwise_excluded_long, "pairwise_exdqlm_vs_dqlm_excluded_long.tsv")
  } else {
    fit_metrics_long <- combine_root_tables(root_rows, "fit_metrics_by_task.csv")
    fit_metrics_eligible_long <- combine_root_tables(root_rows, "fit_metrics_by_task_eligible.csv")
    pairwise_long <- combine_root_tables(root_rows, "pairwise_exal_vs_al.csv")
    pairwise_excluded_long <- combine_root_tables(root_rows, "pairwise_exal_vs_al_excluded.csv")
    pairwise_model_compare_long <- normalize_model_pair_table(pairwise_long, unique(root_rows$root_kind)[[1]])
    pairwise_model_compare_excluded_long <- normalize_model_pair_table(pairwise_excluded_long, unique(root_rows$root_kind)[[1]])
    runtime_long <- combine_root_tables(root_rows, "runtime_diagnostics_summary.csv")
    gates_long <- combine_root_tables(root_rows, "acceptance_gate_summary.csv")
    write_tsv(pairwise_long, "pairwise_exal_vs_al_long.tsv")
    write_tsv(pairwise_excluded_long, "pairwise_exal_vs_al_excluded_long.tsv")
    write_tsv(runtime_long, "runtime_diagnostics_summary_long.tsv")
    write_tsv(gates_long, "acceptance_gate_summary_long.tsv")
  }

  write_tsv(pairwise_model_compare_long, "pairwise_model_compare_long.tsv")
  write_tsv(pairwise_model_compare_excluded_long, "pairwise_model_compare_excluded_long.tsv")

  vb_mcmc_long <- combine_root_tables(root_rows, "pairwise_vb_vs_mcmc.csv")
  vb_mcmc_eligible_long <- combine_root_tables(root_rows, "pairwise_vb_vs_mcmc_eligible.csv")
  vb_mcmc_excluded_long <- combine_root_tables(root_rows, "pairwise_vb_vs_mcmc_excluded.csv")

  write_tsv(fit_metrics_long, "fit_metrics_by_task_long.tsv")
  write_tsv(fit_metrics_eligible_long, "fit_metrics_by_task_eligible_long.tsv")
  write_tsv(vb_mcmc_long, "pairwise_vb_vs_mcmc_long.tsv")
  write_tsv(vb_mcmc_eligible_long, "pairwise_vb_vs_mcmc_eligible_long.tsv")
  write_tsv(vb_mcmc_excluded_long, "pairwise_vb_vs_mcmc_excluded_long.tsv")
  write_tsv(summarise_vb_vs_mcmc(vb_mcmc_long), "vb_vs_mcmc_summary.tsv")

  if (identical(barrier_id, "campaign__static_shrink") && nrow(compare_rows)) {
    rhs_vs_ridge_long <- rbind_fill_list(lapply(seq_len(nrow(compare_rows)), function(i) read_compare_table(compare_rows[i, , drop = FALSE], "rhs_vs_ridge_summary.csv")))
    coef_recovery_long <- rbind_fill_list(lapply(seq_len(nrow(compare_rows)), function(i) read_compare_table(compare_rows[i, , drop = FALSE], "coefficient_recovery_summary.csv")))
    coef_group_long <- rbind_fill_list(lapply(seq_len(nrow(compare_rows)), function(i) read_compare_table(compare_rows[i, , drop = FALSE], "coefficient_group_summary.csv")))
    write_tsv(rhs_vs_ridge_long, "rhs_vs_ridge_summary_long.tsv")
    write_tsv(coef_recovery_long, "coefficient_recovery_summary_long.tsv")
    write_tsv(coef_group_long, "coefficient_group_summary_long.tsv")
  }

  signoff_counts <- summarise_signoff_counts(
    method_long = method_signoff_long,
    algorithm_long = algorithm_pair_signoff_long,
    model_long = model_pair_signoff_long,
    root_long = root_signoff_summary_long,
    repair_long = repair_targets_long,
    metrics_all = fit_metrics_long,
    metrics_eligible = fit_metrics_eligible_long,
    pair_eligible = pairwise_model_compare_long,
    pair_excluded = pairwise_model_compare_excluded_long
  )

  summary_df <- cbind(
    data.frame(
      barrier_id = barrier_id,
      generated_at = timestamp,
      prerequisite_count = nrow(prereq_inventory),
      root_review_count = nrow(root_rows),
      prior_compare_count = nrow(compare_rows),
      family_count = length(unique(root_rows$family)),
      tau_count = length(unique(root_rows$tau)),
      fit_size_count = length(unique(root_rows$fit_size)),
      stringsAsFactors = FALSE
    ),
    signoff_counts
  )
  summary_df$vb_mcmc_rows_all <- nrow(vb_mcmc_long)
  summary_df$vb_mcmc_rows_eligible <- nrow(vb_mcmc_eligible_long)
  summary_df$vb_mcmc_rows_excluded <- nrow(vb_mcmc_excluded_long)
  write_tsv(summary_df, "campaign_summary.tsv")

  writeLines(c(
    paste0("# ", barrier_id),
    "",
    paste0("- generated_at: `", timestamp, "`"),
    paste0("- root_review_count: `", nrow(root_rows), "`"),
    paste0("- prior_compare_count: `", nrow(compare_rows), "`"),
    paste0("- prerequisite_inventory: `tables/prerequisite_inventory.tsv`"),
    paste0("- method_signoff_long: `tables/method_signoff_long.tsv`"),
    paste0("- algorithm_pair_signoff_long: `tables/algorithm_pair_signoff_long.tsv`"),
    paste0("- model_pair_signoff_long: `tables/model_pair_signoff_long.tsv`"),
    paste0("- root_signoff_summary_long: `tables/root_signoff_summary_long.tsv`"),
    paste0("- repair_targets_long: `tables/repair_targets_long.tsv`"),
    paste0("- fit_metrics_by_task_long: `tables/fit_metrics_by_task_long.tsv`"),
    paste0("- fit_metrics_by_task_eligible_long: `tables/fit_metrics_by_task_eligible_long.tsv`"),
    paste0("- pairwise_model_compare_long: `tables/pairwise_model_compare_long.tsv`"),
    paste0("- pairwise_model_compare_excluded_long: `tables/pairwise_model_compare_excluded_long.tsv`"),
    paste0("- pairwise_vb_vs_mcmc_long: `tables/pairwise_vb_vs_mcmc_long.tsv`"),
    paste0("- pairwise_vb_vs_mcmc_eligible_long: `tables/pairwise_vb_vs_mcmc_eligible_long.tsv`"),
    paste0("- pairwise_vb_vs_mcmc_excluded_long: `tables/pairwise_vb_vs_mcmc_excluded_long.tsv`"),
    paste0("- vb_vs_mcmc_summary: `tables/vb_vs_mcmc_summary.tsv`"),
    paste0("- campaign_summary: `tables/campaign_summary.tsv`")
  ), con = file.path(out_root, "report_summary.md"))
} else if (identical(barrier_type, "global_summary")) {
  dep_rows <- dependency_edges[dependency_edges$parent_task_id == barrier_id, , drop = FALSE]
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

  campaign_summaries <- lapply(seq_along(dep_barrier_ids), function(i) {
    dep_id <- dep_barrier_ids[[i]]
    dep_row <- data.frame(barrier_id = dep_id, barrier_type = "campaign_review", stringsAsFactors = FALSE)
    det <- fq_detect_campaign_barrier(dep_row, repo_root)
    prereq_inventory$state[[i]] <<- det$state[[1]]
    if (!identical(det$state[[1]], "complete_reusable")) {
      stop("Global summary not ready; incomplete campaign aggregate: ", dep_id, call. = FALSE)
    }
    fq_read_tsv(file.path(fq_barrier_output_root(dep_id, repo_root), "tables", "campaign_summary.tsv"))
  })
  write_tsv(prereq_inventory, "prerequisite_inventory.tsv")

  global_df <- rbind_fill_list(campaign_summaries)
  write_tsv(global_df, "global_summary.tsv")

  method_long <- rbind_fill_list(lapply(dep_barrier_ids, function(dep_id) fq_read_tsv(file.path(fq_barrier_output_root(dep_id, repo_root), "tables", "method_signoff_long.tsv"))))
  algorithm_long <- rbind_fill_list(lapply(dep_barrier_ids, function(dep_id) fq_read_tsv(file.path(fq_barrier_output_root(dep_id, repo_root), "tables", "algorithm_pair_signoff_long.tsv"))))
  model_long <- rbind_fill_list(lapply(dep_barrier_ids, function(dep_id) fq_read_tsv(file.path(fq_barrier_output_root(dep_id, repo_root), "tables", "model_pair_signoff_long.tsv"))))
  root_long <- rbind_fill_list(lapply(dep_barrier_ids, function(dep_id) fq_read_tsv(file.path(fq_barrier_output_root(dep_id, repo_root), "tables", "root_signoff_summary_long.tsv"))))
  repair_long <- rbind_fill_list(lapply(dep_barrier_ids, function(dep_id) fq_read_tsv(file.path(fq_barrier_output_root(dep_id, repo_root), "tables", "repair_targets_long.tsv"))))
  metrics_all <- rbind_fill_list(lapply(dep_barrier_ids, function(dep_id) fq_read_tsv(file.path(fq_barrier_output_root(dep_id, repo_root), "tables", "fit_metrics_by_task_long.tsv"))))
  metrics_eligible <- rbind_fill_list(lapply(dep_barrier_ids, function(dep_id) fq_read_tsv(file.path(fq_barrier_output_root(dep_id, repo_root), "tables", "fit_metrics_by_task_eligible_long.tsv"))))
  static_pair_eligible <- rbind_fill_list(lapply(dep_barrier_ids, function(dep_id) {
    path <- file.path(fq_barrier_output_root(dep_id, repo_root), "tables", "pairwise_exal_vs_al_long.tsv")
    if (file.exists(path)) fq_read_tsv(path) else data.frame(stringsAsFactors = FALSE)
  }))
  static_pair_excluded <- rbind_fill_list(lapply(dep_barrier_ids, function(dep_id) {
    path <- file.path(fq_barrier_output_root(dep_id, repo_root), "tables", "pairwise_exal_vs_al_excluded_long.tsv")
    if (file.exists(path)) fq_read_tsv(path) else data.frame(stringsAsFactors = FALSE)
  }))
  dynamic_pair_eligible <- rbind_fill_list(lapply(dep_barrier_ids, function(dep_id) {
    path <- file.path(fq_barrier_output_root(dep_id, repo_root), "tables", "pairwise_exdqlm_vs_dqlm_long.tsv")
    if (file.exists(path)) fq_read_tsv(path) else data.frame(stringsAsFactors = FALSE)
  }))
  dynamic_pair_excluded <- rbind_fill_list(lapply(dep_barrier_ids, function(dep_id) {
    path <- file.path(fq_barrier_output_root(dep_id, repo_root), "tables", "pairwise_exdqlm_vs_dqlm_excluded_long.tsv")
    if (file.exists(path)) fq_read_tsv(path) else data.frame(stringsAsFactors = FALSE)
  }))
  pair_eligible <- rbind_fill_list(lapply(dep_barrier_ids, function(dep_id) {
    path <- file.path(fq_barrier_output_root(dep_id, repo_root), "tables", "pairwise_model_compare_long.tsv")
    if (file.exists(path)) fq_read_tsv(path) else data.frame(stringsAsFactors = FALSE)
  }))
  pair_excluded <- rbind_fill_list(lapply(dep_barrier_ids, function(dep_id) {
    path <- file.path(fq_barrier_output_root(dep_id, repo_root), "tables", "pairwise_model_compare_excluded_long.tsv")
    if (file.exists(path)) fq_read_tsv(path) else data.frame(stringsAsFactors = FALSE)
  }))
  vb_mcmc_long <- rbind_fill_list(lapply(dep_barrier_ids, function(dep_id) {
    path <- file.path(fq_barrier_output_root(dep_id, repo_root), "tables", "pairwise_vb_vs_mcmc_long.tsv")
    if (file.exists(path)) fq_read_tsv(path) else data.frame(stringsAsFactors = FALSE)
  }))
  vb_mcmc_eligible_long <- rbind_fill_list(lapply(dep_barrier_ids, function(dep_id) {
    path <- file.path(fq_barrier_output_root(dep_id, repo_root), "tables", "pairwise_vb_vs_mcmc_eligible_long.tsv")
    if (file.exists(path)) fq_read_tsv(path) else data.frame(stringsAsFactors = FALSE)
  }))
  vb_mcmc_excluded_long <- rbind_fill_list(lapply(dep_barrier_ids, function(dep_id) {
    path <- file.path(fq_barrier_output_root(dep_id, repo_root), "tables", "pairwise_vb_vs_mcmc_excluded_long.tsv")
    if (file.exists(path)) fq_read_tsv(path) else data.frame(stringsAsFactors = FALSE)
  }))

  write_tsv(method_long, "method_signoff_long.tsv")
  write_tsv(algorithm_long, "algorithm_pair_signoff_long.tsv")
  write_tsv(model_long, "model_pair_signoff_long.tsv")
  write_tsv(root_long, "root_signoff_summary_long.tsv")
  write_tsv(repair_long, "repair_targets_long.tsv")
  write_tsv(metrics_all, "fit_metrics_by_task_long.tsv")
  write_tsv(metrics_eligible, "fit_metrics_by_task_eligible_long.tsv")
  write_tsv(static_pair_eligible, "pairwise_exal_vs_al_long.tsv")
  write_tsv(static_pair_excluded, "pairwise_exal_vs_al_excluded_long.tsv")
  write_tsv(dynamic_pair_eligible, "pairwise_exdqlm_vs_dqlm_long.tsv")
  write_tsv(dynamic_pair_excluded, "pairwise_exdqlm_vs_dqlm_excluded_long.tsv")
  write_tsv(pair_eligible, "pairwise_model_compare_long.tsv")
  write_tsv(pair_excluded, "pairwise_model_compare_excluded_long.tsv")
  write_tsv(vb_mcmc_long, "pairwise_vb_vs_mcmc_long.tsv")
  write_tsv(vb_mcmc_eligible_long, "pairwise_vb_vs_mcmc_eligible_long.tsv")
  write_tsv(vb_mcmc_excluded_long, "pairwise_vb_vs_mcmc_excluded_long.tsv")
  write_tsv(summarise_vb_vs_mcmc(vb_mcmc_long), "vb_vs_mcmc_summary.tsv")

  global_signoff_summary <- cbind(
    data.frame(
      barrier_id = barrier_id,
      generated_at = timestamp,
      campaign_count = nrow(global_df),
      stringsAsFactors = FALSE
    ),
    summarise_signoff_counts(
      method_long = method_long,
      algorithm_long = algorithm_long,
      model_long = model_long,
      root_long = root_long,
      repair_long = repair_long,
      metrics_all = metrics_all,
      metrics_eligible = metrics_eligible,
      pair_eligible = pair_eligible,
      pair_excluded = pair_excluded
    )
  )
  global_signoff_summary$vb_mcmc_rows_all <- nrow(vb_mcmc_long)
  global_signoff_summary$vb_mcmc_rows_eligible <- nrow(vb_mcmc_eligible_long)
  global_signoff_summary$vb_mcmc_rows_excluded <- nrow(vb_mcmc_excluded_long)
  write_tsv(global_signoff_summary, "global_signoff_summary.tsv")

  writeLines(c(
    "# campaign__global_cross_family_summary",
    "",
    paste0("- generated_at: `", timestamp, "`"),
    paste0("- campaign_count: `", nrow(global_df), "`"),
    paste0("- prerequisite_inventory: `tables/prerequisite_inventory.tsv`"),
    paste0("- global_summary: `tables/global_summary.tsv`"),
    paste0("- global_signoff_summary: `tables/global_signoff_summary.tsv`"),
    paste0("- pairwise_model_compare_long: `tables/pairwise_model_compare_long.tsv`"),
    paste0("- pairwise_model_compare_excluded_long: `tables/pairwise_model_compare_excluded_long.tsv`"),
    paste0("- pairwise_vb_vs_mcmc_long: `tables/pairwise_vb_vs_mcmc_long.tsv`"),
    paste0("- pairwise_vb_vs_mcmc_eligible_long: `tables/pairwise_vb_vs_mcmc_eligible_long.tsv`"),
    paste0("- pairwise_vb_vs_mcmc_excluded_long: `tables/pairwise_vb_vs_mcmc_excluded_long.tsv`"),
    paste0("- vb_vs_mcmc_summary: `tables/vb_vs_mcmc_summary.tsv`")
  ), con = file.path(out_root, "report_summary.md"))
} else {
  stop("Unsupported barrier_type for aggregation: ", barrier_type, call. = FALSE)
}

cat(sprintf("Aggregation complete for %s under %s\n", barrier_id, out_root))

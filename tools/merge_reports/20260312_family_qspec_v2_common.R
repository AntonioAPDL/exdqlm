fq_family_qspec_taus <- c("0.05", "0.25", "0.95")

fq_tau_tag <- function(x) {
  gsub("\\.", "p", sprintf("%.2f", as.numeric(x)))
}

fq_read_tsv <- function(path) {
  utils::read.delim(path, sep = "\t", stringsAsFactors = FALSE, check.names = FALSE)
}

fq_write_tsv <- function(df, path) {
  utils::write.table(df, path, sep = "\t", row.names = FALSE, quote = FALSE)
}

fq_path <- function(repo_root, rel_path) {
  if (is.na(rel_path) || !nzchar(rel_path)) {
    return(NA_character_)
  }
  file.path(repo_root, rel_path)
}

fq_read_csv_safe <- function(path) {
  if (!file.exists(path) || is.na(file.info(path)$size) || file.info(path)$size <= 0) {
    return(NULL)
  }
  tryCatch(utils::read.csv(path, stringsAsFactors = FALSE), error = function(e) NULL)
}

fq_status_has_event <- function(path, event) {
  if (!file.exists(path)) {
    return(FALSE)
  }
  lines <- readLines(path, warn = FALSE)
  any(grepl(sprintf("\\t%s(\\t|$)", event), lines))
}

fq_status_has_error <- function(path) {
  if (!file.exists(path)) {
    return(FALSE)
  }
  lines <- readLines(path, warn = FALSE)
  any(grepl("ERROR|FAIL|Execution halted", lines))
}

fq_safe_is_na <- function(x) {
  is.na(x) || identical(x, "")
}

fq_model_file_paths <- function(model_row, repo_root = ".") {
  run_root <- fq_path(repo_root, model_row$run_root)
  tau_lab <- fq_tau_tag(model_row$tau)
  model <- model_row$model
  list(
    run_root = run_root,
    vb_fit = file.path(run_root, "fits", "vb", sprintf("vb_%s_tau_%s_fit.rds", model, tau_lab)),
    mcmc_fit = file.path(run_root, "fits", "mcmc", sprintf("mcmc_%s_tau_%s_fit.rds", model, tau_lab)),
    vb_summary = file.path(run_root, "derived", sprintf("vb_%s_tau_%s_summary.rds", model, tau_lab)),
    mcmc_summary = file.path(run_root, "derived", sprintf("mcmc_%s_tau_%s_summary.rds", model, tau_lab)),
    status_tsv = file.path(run_root, "logs", sprintf("%s_tau_%s.status.tsv", model, tau_lab)),
    pipeline_summary = file.path(run_root, "tables", "pipeline_task_summary.csv"),
    run_config = file.path(run_root, "tables", "run_config.rds")
  )
}

fq_pipeline_row <- function(path, model, tau) {
  df <- fq_read_csv_safe(path)
  if (is.null(df) || !all(c("model", "tau") %in% names(df))) {
    return(NULL)
  }
  idx <- which(df$model == model & abs(as.numeric(df$tau) - as.numeric(tau)) < 1e-8)
  if (!length(idx)) {
    return(NULL)
  }
  df[idx[1], , drop = FALSE]
}

fq_detect_model_path <- function(model_row, repo_root = ".") {
  files <- fq_model_file_paths(model_row, repo_root)
  pipeline_row <- fq_pipeline_row(files$pipeline_summary, model_row$model, model_row$tau)
  vb_fit_exists <- file.exists(files$vb_fit)
  mcmc_fit_exists <- file.exists(files$mcmc_fit)
  vb_summary_exists <- file.exists(files$vb_summary)
  mcmc_summary_exists <- file.exists(files$mcmc_summary)
  status_has_vb_done <- fq_status_has_event(files$status_tsv, "VB_DONE")
  status_has_mcmc_done <- fq_status_has_event(files$status_tsv, "MCMC_DONE")
  status_has_error <- fq_status_has_error(files$status_tsv)
  pipeline_done <- FALSE
  pipeline_error <- FALSE
  if (!is.null(pipeline_row)) {
    pipeline_done <- identical(as.character(pipeline_row$status[[1]]), "done") &&
      (fq_safe_is_na(pipeline_row$error[[1]]) || !nzchar(trimws(as.character(pipeline_row$error[[1]]))))
    pipeline_error <- !fq_safe_is_na(pipeline_row$error[[1]]) && nzchar(trimws(as.character(pipeline_row$error[[1]])))
  }

  any_artifact <- any(c(
    vb_fit_exists,
    mcmc_fit_exists,
    vb_summary_exists,
    mcmc_summary_exists,
    file.exists(files$status_tsv),
    file.exists(files$pipeline_summary),
    file.exists(files$run_config)
  ))

  state <- if (vb_fit_exists && mcmc_fit_exists && (mcmc_summary_exists || status_has_mcmc_done || pipeline_done)) {
    "complete_reusable"
  } else if (vb_fit_exists && !mcmc_fit_exists) {
    "partial_reusable"
  } else if (!vb_fit_exists && mcmc_fit_exists) {
    "partial_stale"
  } else if (any_artifact && (status_has_error || pipeline_error)) {
    "partial_stale"
  } else if (any_artifact) {
    "partial_stale"
  } else {
    "missing"
  }

  recommended_action <- if (state == "complete_reusable") {
    "skip"
  } else if (state == "partial_reusable") {
    "resume_mcmc_from_vb"
  } else if (state == "missing") {
    "fresh_vb_then_mcmc"
  } else {
    "fresh_vb_then_mcmc"
  }

  data.frame(
    vb_fit_exists = isTRUE(vb_fit_exists),
    mcmc_fit_exists = isTRUE(mcmc_fit_exists),
    vb_summary_exists = isTRUE(vb_summary_exists),
    mcmc_summary_exists = isTRUE(mcmc_summary_exists),
    status_has_vb_done = isTRUE(status_has_vb_done),
    status_has_mcmc_done = isTRUE(status_has_mcmc_done),
    status_has_error = isTRUE(status_has_error),
    pipeline_done = isTRUE(pipeline_done),
    pipeline_error = isTRUE(pipeline_error),
    state = state,
    recommended_action = recommended_action,
    stringsAsFactors = FALSE
  )
}

fq_required_postprocess_files <- function(root_row, repo_root = ".") {
  run_root <- fq_path(repo_root, root_row$run_root)
  req <- c(
    file.path(run_root, "tables", "fit_summary.csv"),
    file.path(run_root, "tables", "vb_convergence_summary.csv"),
    file.path(run_root, "tables", "vb_ld_diagnostics_summary.csv"),
    file.path(run_root, "tables", "mcmc_diagnostics_summary.csv"),
    file.path(run_root, "tables", "metrics_summary.csv")
  )
  if (root_row$root_kind != "dynamic") {
    req <- c(req, file.path(run_root, "tables", "rhs_diagnostics_summary.csv"))
  }
  req
}

fq_required_review_files <- function(root_row, repo_root = ".") {
  run_root <- fq_path(repo_root, root_row$run_root)
  if (root_row$root_kind == "dynamic") {
    return(c(
      fq_required_signoff_files(root_row, repo_root),
      fq_required_postprocess_files(root_row, repo_root),
      file.path(run_root, "tables", "fit_metrics_by_task.csv"),
      file.path(run_root, "tables", "fit_metrics_by_task_eligible.csv"),
      file.path(run_root, "tables", "pairwise_vb_vs_mcmc.csv"),
      file.path(run_root, "tables", "pairwise_vb_vs_mcmc_eligible.csv"),
      file.path(run_root, "tables", "pairwise_vb_vs_mcmc_excluded.csv"),
      file.path(run_root, "tables", "pairwise_exdqlm_vs_dqlm.csv"),
      file.path(run_root, "tables", "pairwise_exdqlm_vs_dqlm_excluded.csv"),
      file.path(run_root, "tables", "acceptance_gate_summary.csv"),
      file.path(run_root, "tables", "report_summary.md")
    ))
  }
  c(
    fq_required_signoff_files(root_row, repo_root),
    file.path(run_root, "tables", "pairwise_vb_vs_mcmc.csv"),
    file.path(run_root, "tables", "pairwise_vb_vs_mcmc_eligible.csv"),
    file.path(run_root, "tables", "pairwise_vb_vs_mcmc_excluded.csv"),
    file.path(run_root, "tables", "pairwise_exal_vs_al.csv"),
    file.path(run_root, "tables", "pairwise_exal_vs_al_excluded.csv"),
    file.path(run_root, "tables", "runtime_diagnostics_summary.csv"),
    file.path(run_root, "tables", "acceptance_gate_summary.csv"),
    file.path(run_root, "tables", "fit_metrics_by_task.csv"),
    file.path(run_root, "tables", "fit_metrics_by_task_eligible.csv"),
    file.path(run_root, "tables", "report_summary.md")
  )
}

fq_required_signoff_files <- function(root_row, repo_root = ".") {
  run_root <- fq_path(repo_root, root_row$run_root)
  c(
    file.path(run_root, "tables", "method_signoff_long.csv"),
    file.path(run_root, "tables", "algorithm_pair_signoff.csv"),
    file.path(run_root, "tables", "model_pair_signoff.csv"),
    file.path(run_root, "tables", "root_signoff_summary.csv"),
    file.path(run_root, "tables", "repair_targets.csv")
  )
}

fq_detect_file_group <- function(required_files, repo_root = ".") {
  exists <- file.exists(required_files)
  data.frame(
    complete = all(exists),
    any_present = any(exists),
    missing_count = sum(!exists),
    stringsAsFactors = FALSE
  )
}

fq_detect_root_postprocess <- function(root_row, repo_root = ".") {
  req <- fq_required_postprocess_files(root_row, repo_root)
  det <- fq_detect_file_group(req, repo_root)
  state <- if (det$complete) "complete_reusable" else if (det$any_present) "partial_reusable" else "missing"
  data.frame(
    state = state,
    required_files = paste(req, collapse = ";"),
    missing_count = det$missing_count,
    stringsAsFactors = FALSE
  )
}

fq_detect_root_review <- function(root_row, repo_root = ".") {
  req <- fq_required_review_files(root_row, repo_root)
  det <- fq_detect_file_group(req, repo_root)
  state <- if (det$complete) "complete_reusable" else if (det$any_present) "partial_reusable" else "missing"
  data.frame(
    state = state,
    required_files = paste(req, collapse = ";"),
    missing_count = det$missing_count,
    stringsAsFactors = FALSE
  )
}

fq_detect_root_signoff <- function(root_row, repo_root = ".") {
  req <- fq_required_signoff_files(root_row, repo_root)
  det <- fq_detect_file_group(req, repo_root)
  state <- if (det$complete) "complete_reusable" else if (det$any_present) "partial_reusable" else "missing"
  data.frame(
    state = state,
    required_files = paste(req, collapse = ";"),
    missing_count = det$missing_count,
    stringsAsFactors = FALSE
  )
}

fq_detect_prior_compare <- function(barrier_row, repo_root = ".") {
  out_root <- fq_path(repo_root, barrier_row$compare_root)
  req <- c(
    file.path(out_root, "tables", "coefficient_recovery_summary.csv"),
    file.path(out_root, "tables", "coefficient_group_summary.csv"),
    file.path(out_root, "tables", "rhs_vs_ridge_summary.csv"),
    file.path(out_root, "tables", "report_summary.md")
  )
  det <- fq_detect_file_group(req, repo_root)
  state <- if (det$complete) "complete_reusable" else if (det$any_present) "partial_reusable" else "missing"
  data.frame(
    out_root = out_root,
    state = state,
    required_files = paste(req, collapse = ";"),
    missing_count = det$missing_count,
    stringsAsFactors = FALSE
  )
}

fq_barrier_output_root <- function(barrier_id, repo_root = ".") {
  if (barrier_id == "campaign__static_paper") {
    return(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_campaign_review__static_paper"))
  }
  if (barrier_id == "campaign__static_shrink") {
    return(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_campaign_review__static_shrink"))
  }
  if (barrier_id == "campaign__dynamic") {
    return(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_campaign_review__dynamic"))
  }
  if (barrier_id == "campaign__global_cross_family_summary") {
    return(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_global_cross_family_summary"))
  }
  NA_character_
}

fq_detect_campaign_barrier <- function(barrier_row, repo_root = ".") {
  out_root <- fq_barrier_output_root(barrier_row$barrier_id, repo_root)
  table_name <- if (barrier_row$barrier_type == "global_summary") "global_summary.tsv" else "campaign_summary.tsv"
  req <- c(
    file.path(out_root, "tables", "prerequisite_inventory.tsv"),
    file.path(out_root, "tables", table_name),
    file.path(out_root, "report_summary.md")
  )
  det <- fq_detect_file_group(req, repo_root)
  state <- if (det$complete) "complete_reusable" else if (det$any_present) "partial_reusable" else "missing"
  data.frame(
    out_root = out_root,
    state = state,
    required_files = paste(req, collapse = ";"),
    missing_count = det$missing_count,
    stringsAsFactors = FALSE
  )
}

fq_scan_legacy_roots <- function(repo_root = ".", root_catalog, comparison_barriers) {
  canonical_run_roots <- unique(root_catalog$run_root)
  canonical_compare_roots <- unique(comparison_barriers$compare_root[comparison_barriers$barrier_type == "prior_compare" & nzchar(comparison_barriers$compare_root)])
  base_dirs <- c(
    file.path(repo_root, "results", "function_testing_20260309_static_paper_family_qspec"),
    file.path(repo_root, "results", "function_testing_20260309_static_shrinkage_family_qspec"),
    file.path(repo_root, "results", "function_testing_20260309_dynamic_dlm_family_qspec")
  )
  candidate_dirs <- character()
  for (base_dir in base_dirs) {
    if (!dir.exists(base_dir)) {
      next
    }
    dirs <- list.dirs(base_dir, recursive = TRUE, full.names = TRUE)
    dirs <- dirs[normalizePath(dirs, winslash = "/", mustWork = FALSE) != normalizePath(base_dir, winslash = "/", mustWork = FALSE)]
    dir_base <- basename(dirs)
    dirs <- dirs[dir_base %in% c("compare_ridge_vs_rhs_family_qspec") | grepl("^validation_", dir_base)]
    dirs <- sub(paste0("^", normalizePath(repo_root, winslash = "/", mustWork = FALSE), "/"), "", normalizePath(dirs, winslash = "/", mustWork = FALSE))
    candidate_dirs <- c(candidate_dirs, dirs)
  }
  candidate_dirs <- unique(candidate_dirs)
  if (!length(candidate_dirs)) {
    return(data.frame())
  }

  keep <- !(candidate_dirs %in% canonical_run_roots | candidate_dirs %in% canonical_compare_roots)
  legacy_dirs <- candidate_dirs[keep]
  if (!length(legacy_dirs)) {
    return(data.frame())
  }

  rows <- lapply(legacy_dirs, function(rel_dir) {
    abs_dir <- file.path(repo_root, rel_dir)
    metrics <- file.path(abs_dir, "tables", "metrics_summary.csv")
    compare <- file.path(abs_dir, "tables", "rhs_vs_ridge_summary.csv")
    any_artifact <- length(list.files(abs_dir, recursive = TRUE, all.files = FALSE, no.. = TRUE)) > 0
    state <- if (file.exists(metrics) || file.exists(compare)) "complete_out_of_scope" else if (any_artifact) "partial_stale" else "missing"
    tau_match <- regmatches(rel_dir, regexpr("tau_[0-9]p[0-9]+", rel_dir))
    data.frame(
      unit_id = paste0("legacy__", gsub("/", "__", rel_dir)),
      unit_type = if (grepl("compare_ridge_vs_rhs_family_qspec$", rel_dir)) "legacy_prior_compare" else "legacy_root",
      root_id = NA_character_,
      task_id = NA_character_,
      barrier_id = NA_character_,
      root_kind = if (grepl("validation_paper_", rel_dir)) "static_paper" else if (grepl("validation_shrink_", rel_dir)) "static_shrink" else if (grepl("validation_dynamic_", rel_dir)) "dynamic" else "unknown",
      family = if (grepl("/normal/", rel_dir)) "normal" else if (grepl("/laplace/", rel_dir)) "laplace" else if (grepl("/gausmix/", rel_dir)) "gausmix" else "unknown",
      tau = if (length(tau_match) && nzchar(tau_match)) sub("tau_", "", gsub("p", ".", tau_match, fixed = TRUE)) else NA_character_,
      fit_size = NA_integer_,
      prior = if (grepl("_rhs_", rel_dir)) "rhs" else if (grepl("_ridge_", rel_dir)) "ridge" else "default",
      model = NA_character_,
      scope = "out_of_scope",
      state = state,
      recommended_action = if (state == "complete_out_of_scope") "keep_excluded" else "ignore_or_clean_after_review",
      location = rel_dir,
      notes = "Observed family-qspec artifact outside the canonical 0.05/0.25/0.95 relaunch manifest.",
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

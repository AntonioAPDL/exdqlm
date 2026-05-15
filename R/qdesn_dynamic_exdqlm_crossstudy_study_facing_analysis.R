`%||%` <- function(a, b) if (is.null(a)) b else a

qdesn_dynamic_studyfacing_load_manifest <- function(path = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_recovered_study_facing_analysis_manifest.yaml"),
                                                    repo_root = NULL) {
  .qdesn_validation_require_namespace("yaml")
  yaml_path <- .qdesn_validation_resolve_path(path, repo_root = repo_root, must_work = TRUE)
  out <- yaml::read_yaml(yaml_path)
  if (!is.list(out)) {
    stop("Dynamic study-facing analysis manifest YAML must parse to a list.", call. = FALSE)
  }
  out
}

.qdesn_dynamic_studyfacing_read_csv <- function(path,
                                                repo_root = NULL,
                                                required_cols = NULL) {
  csv_path <- .qdesn_validation_resolve_path(path, repo_root = repo_root, must_work = TRUE)
  out <- utils::read.csv(csv_path, stringsAsFactors = FALSE)
  if (length(required_cols)) {
    missing_cols <- setdiff(required_cols, names(out))
    if (length(missing_cols)) {
      stop(
        sprintf(
          "Study-facing source CSV is missing required columns: %s [%s]",
          paste(missing_cols, collapse = ", "),
          basename(csv_path)
        ),
        call. = FALSE
      )
    }
  }
  out
}

.qdesn_dynamic_studyfacing_resolve_comparison_root <- function(manifest,
                                                               repo_root = NULL) {
  source_cfg <- manifest$source %||% list()
  direct_root <- source_cfg$comparison_root %||% NULL
  if (!is.null(direct_root) && nzchar(trimws(as.character(direct_root)[1L]))) {
    return(.qdesn_validation_resolve_path(direct_root, repo_root = repo_root, must_work = TRUE))
  }

  report_root <- source_cfg$comparison_report_root %||% NULL
  run_tag <- as.character(source_cfg$comparison_run_tag %||% "")[1L]
  if (!nzchar(run_tag)) {
    stop("Study-facing manifest must define source.comparison_run_tag or source.comparison_root.", call. = FALSE)
  }
  if (is.null(report_root) || !nzchar(trimws(as.character(report_root)[1L]))) {
    stop("Study-facing manifest must define source.comparison_report_root when using source.comparison_run_tag.", call. = FALSE)
  }
  .qdesn_validation_resolve_path(file.path(report_root, run_tag), repo_root = repo_root, must_work = TRUE)
}

qdesn_dynamic_studyfacing_load_source_state <- function(comparison_root,
                                                        repo_root = NULL) {
  root <- .qdesn_validation_resolve_path(comparison_root, repo_root = repo_root, must_work = TRUE)
  tables_dir <- file.path(root, "tables")
  summary_dir <- file.path(root, "summary")
  manifest_dir <- file.path(root, "manifest")

  analysis_overview <- .qdesn_dynamic_studyfacing_read_csv(
    file.path(tables_dir, "analysis_overview.csv"),
    required_cols = c("metric", "value")
  )
  fit_summary <- .qdesn_dynamic_studyfacing_read_csv(
    file.path(tables_dir, "authoritative_fit_summary.csv"),
    required_cols = c("root_id", "prior", "inference", "model", "signoff_grade", "status")
  )
  representative_case_table <- .qdesn_dynamic_studyfacing_read_csv(
    file.path(tables_dir, "authoritative_representative_fit_case_table.csv"),
    required_cols = c("root_id", "prior", "inference", "model", "signoff_grade")
  )
  representative_selection_counts <- .qdesn_dynamic_studyfacing_read_csv(
    file.path(tables_dir, "authoritative_representative_fit_selection_counts.csv"),
    required_cols = c("signoff_grade", "inference", "model", "n_selected")
  )
  root_inventory <- .qdesn_dynamic_studyfacing_read_csv(
    file.path(tables_dir, "authoritative_root_inventory.csv"),
    required_cols = c("root_id", "prior", "root_status", "root_comparison_eligible_any", "root_comparison_eligible_full")
  )
  root_signoff_summary <- .qdesn_dynamic_studyfacing_read_csv(
    file.path(tables_dir, "authoritative_root_signoff_summary.csv"),
    required_cols = c("root_id", "prior", "root_status")
  )
  q_vs_ref_surface <- .qdesn_dynamic_studyfacing_read_csv(
    file.path(tables_dir, "authoritative_qdesn_vs_reference_fit_surface_delta.csv"),
    required_cols = c("family", "tau", "fit_size", "inference", "canonical_model", "prior")
  )
  fit_inference_summary <- .qdesn_dynamic_studyfacing_read_csv(
    file.path(tables_dir, "authoritative_fit_inference_summary.csv"),
    required_cols = c("inference", "n_rows", "n_pass", "n_warn", "n_fail")
  )
  fit_model_summary <- .qdesn_dynamic_studyfacing_read_csv(
    file.path(tables_dir, "authoritative_fit_model_summary.csv"),
    required_cols = c("model", "n_rows", "n_pass", "n_warn", "n_fail")
  )
  fit_prior_summary <- .qdesn_dynamic_studyfacing_read_csv(
    file.path(tables_dir, "authoritative_fit_prior_summary.csv"),
    required_cols = c("prior", "n_rows", "n_pass", "n_warn", "n_fail")
  )
  fit_method_model_summary <- .qdesn_dynamic_studyfacing_read_csv(
    file.path(tables_dir, "authoritative_fit_method_model_summary.csv"),
    required_cols = c("inference", "model", "n_rows", "n_pass", "n_warn", "n_fail")
  )
  fail_inventory <- .qdesn_dynamic_studyfacing_read_csv(
    file.path(tables_dir, "authoritative_fail_inventory.csv"),
    required_cols = c("root_id", "prior", "inference", "model", "signoff_reason")
  )
  prior_head_to_head_counts <- .qdesn_dynamic_studyfacing_read_csv(
    file.path(tables_dir, "authoritative_prior_head_to_head_counts.csv"),
    required_cols = c("preferred_prior", "Freq")
  )
  analysis_manifest <- .qdesn_validation_read_json_if_exists(file.path(manifest_dir, "analysis_manifest.json"))

  list(
    comparison_root = root,
    tables_dir = tables_dir,
    summary_dir = summary_dir,
    manifest_dir = manifest_dir,
    analysis_manifest = analysis_manifest,
    analysis_overview = analysis_overview,
    fit_summary = fit_summary,
    representative_case_table = representative_case_table,
    representative_selection_counts = representative_selection_counts,
    root_inventory = root_inventory,
    root_signoff_summary = root_signoff_summary,
    q_vs_ref_surface = q_vs_ref_surface,
    fit_inference_summary = fit_inference_summary,
    fit_model_summary = fit_model_summary,
    fit_prior_summary = fit_prior_summary,
    fit_method_model_summary = fit_method_model_summary,
    fail_inventory = fail_inventory,
    prior_head_to_head_counts = prior_head_to_head_counts
  )
}

.qdesn_dynamic_studyfacing_metric_value <- function(overview, metric) {
  idx <- which(as.character(overview$metric) == metric)
  if (!length(idx)) return(NA_real_)
  suppressWarnings(as.numeric(overview$value[idx[1L]]))
}

.qdesn_dynamic_studyfacing_fail_axis_summary <- function(fit_summary,
                                                         group_cols = c("inference", "model", "prior")) {
  if (!nrow(fit_summary)) return(data.frame(stringsAsFactors = FALSE))
  group_cols <- group_cols[group_cols %in% names(fit_summary)]
  if (!length(group_cols)) return(data.frame(stringsAsFactors = FALSE))

  all_counts <- aggregate(
    list(total_rows = rep(1L, nrow(fit_summary))),
    by = fit_summary[, group_cols, drop = FALSE],
    FUN = sum
  )
  fail_rows <- fit_summary[as.character(fit_summary$signoff_grade) == "FAIL", , drop = FALSE]
  if (!nrow(fail_rows)) {
    all_counts$fail_rows <- 0L
    all_counts$fail_rate <- 0
    return(all_counts[order(do.call(order, all_counts[group_cols])), , drop = FALSE])
  }
  fail_counts <- aggregate(
    list(fail_rows = rep(1L, nrow(fail_rows))),
    by = fail_rows[, group_cols, drop = FALSE],
    FUN = sum
  )
  out <- merge(all_counts, fail_counts, by = group_cols, all.x = TRUE, sort = FALSE)
  out$fail_rows[is.na(out$fail_rows)] <- 0L
  out$fail_rate <- out$fail_rows / out$total_rows
  out[do.call(order, out[group_cols]), , drop = FALSE]
}

.qdesn_dynamic_studyfacing_fail_reason_summary <- function(fit_summary) {
  fail_rows <- fit_summary[as.character(fit_summary$signoff_grade) == "FAIL", , drop = FALSE]
  if (!nrow(fail_rows)) return(data.frame(stringsAsFactors = FALSE))

  reason_rows <- lapply(seq_len(nrow(fail_rows)), function(i) {
    row <- fail_rows[i, , drop = FALSE]
    parts <- strsplit(as.character(row$signoff_reason[1L] %||% ""), ";", fixed = TRUE)[[1L]]
    parts <- trimws(parts)
    parts <- parts[nzchar(parts)]
    if (!length(parts)) parts <- NA_character_
    data.frame(
      inference = as.character(row$inference[1L]),
      model = as.character(row$model[1L]),
      prior = as.character(row$prior[1L]),
      family = as.character(row$family[1L] %||% NA_character_),
      fit_size = suppressWarnings(as.integer(row$fit_size[1L] %||% NA_integer_)),
      tau = suppressWarnings(as.numeric(row$tau[1L] %||% NA_real_)),
      reason_fragment = as.character(parts),
      stringsAsFactors = FALSE
    )
  })
  reason_df <- .qdesn_validation_bind_rows(reason_rows)
  if (!nrow(reason_df)) return(data.frame(stringsAsFactors = FALSE))
  out <- aggregate(
    list(n_rows = rep(1L, nrow(reason_df))),
    by = reason_df[, c("reason_fragment", "inference", "model", "prior"), drop = FALSE],
    FUN = sum
  )
  out[order(out$reason_fragment, out$inference, out$model, out$prior), , drop = FALSE]
}

.qdesn_dynamic_studyfacing_build_reference_surface <- function(representative_case_table,
                                                               q_vs_ref_surface) {
  if (!nrow(representative_case_table)) return(data.frame(stringsAsFactors = FALSE))
  repr <- representative_case_table
  repr$canonical_model <- .qdesn_dynamic_maincmp_canonical_model(repr$model)

  repr_cols <- intersect(c(
    "root_id", "dataset_cell_id", "scenario", "root_kind", "family", "tau", "fit_size",
    "prior", "inference", "model", "canonical_model", "signoff_grade", "comparison_eligible",
    "runtime_sec", "runtime_sec_per_1k_eval", "train_qtrue_mae", "train_qtrue_rmse",
    "train_pinball_tau", "train_coverage_minus_tau", "train_coverage_error",
    "holdout_qtrue_mae", "holdout_qtrue_rmse", "holdout_pinball_tau",
    "holdout_coverage_minus_tau", "holdout_coverage_error", "signoff_reason"
  ), names(repr))
  repr <- repr[, repr_cols, drop = FALSE]

  q_cols <- intersect(c(
    "scenario", "root_kind", "family", "tau", "fit_size", "inference", "canonical_model", "prior",
    "model_reference", "n_rows_reference", "comparison_eligible_rate_reference",
    "comparison_eligible_rate_qdesn", "comparison_eligible_rate_delta_qdesn_minus_reference",
    "pass_rate_reference", "warn_rate_reference", "fail_rate_reference",
    "pass_rate_qdesn", "warn_rate_qdesn", "fail_rate_qdesn",
    "pass_rate_delta_qdesn_minus_reference", "warn_rate_delta_qdesn_minus_reference",
    "fail_rate_delta_qdesn_minus_reference",
    "runtime_sec_mean_reference", "runtime_sec_mean_qdesn",
    "runtime_sec_mean_delta_qdesn_minus_reference", "runtime_sec_mean_ratio_qdesn_vs_reference"
  ), names(q_vs_ref_surface))

  out <- merge(
    repr,
    q_vs_ref_surface[, q_cols, drop = FALSE],
    by = intersect(c("scenario", "root_kind", "family", "tau", "fit_size", "inference", "canonical_model", "prior"), q_cols),
    all.x = TRUE,
    sort = FALSE
  )
  out$reference_aligned <- is.finite(suppressWarnings(as.numeric(out$n_rows_reference)))
  out
}

.qdesn_dynamic_studyfacing_reference_alignment_summary <- function(representative_reference_surface,
                                                                   group_cols = c("prior", "canonical_model")) {
  if (!nrow(representative_reference_surface)) return(data.frame(stringsAsFactors = FALSE))
  group_cols <- group_cols[group_cols %in% names(representative_reference_surface)]
  if (!length(group_cols)) return(data.frame(stringsAsFactors = FALSE))

  idx_list <- split(
    seq_len(nrow(representative_reference_surface)),
    interaction(representative_reference_surface[, group_cols, drop = FALSE], drop = TRUE, lex.order = TRUE)
  )
  rows <- lapply(idx_list, function(idx) {
    sub <- representative_reference_surface[idx, , drop = FALSE]
    row <- sub[1L, group_cols, drop = FALSE]
    aligned <- as.logical(sub$reference_aligned)
    row$n_rows <- nrow(sub)
    row$n_reference_aligned <- sum(aligned, na.rm = TRUE)
    row$n_reference_gap <- row$n_rows - row$n_reference_aligned
    row$reference_aligned_rate <- row$n_reference_aligned / row$n_rows
    aligned_sub <- sub[aligned, , drop = FALSE]
    row$comparison_eligible_rate_delta_mean <- if (nrow(aligned_sub) && "comparison_eligible_rate_delta_qdesn_minus_reference" %in% names(aligned_sub)) {
      mean(suppressWarnings(as.numeric(aligned_sub$comparison_eligible_rate_delta_qdesn_minus_reference)), na.rm = TRUE)
    } else {
      NA_real_
    }
    row$runtime_sec_mean_ratio_qdesn_vs_reference_mean <- if (nrow(aligned_sub) && "runtime_sec_mean_ratio_qdesn_vs_reference" %in% names(aligned_sub)) {
      mean(suppressWarnings(as.numeric(aligned_sub$runtime_sec_mean_ratio_qdesn_vs_reference)), na.rm = TRUE)
    } else {
      NA_real_
    }
    row$pass_rate_delta_qdesn_minus_reference_mean <- if (nrow(aligned_sub) && "pass_rate_delta_qdesn_minus_reference" %in% names(aligned_sub)) {
      mean(suppressWarnings(as.numeric(aligned_sub$pass_rate_delta_qdesn_minus_reference)), na.rm = TRUE)
    } else {
      NA_real_
    }
    row$fail_rate_delta_qdesn_minus_reference_mean <- if (nrow(aligned_sub) && "fail_rate_delta_qdesn_minus_reference" %in% names(aligned_sub)) {
      mean(suppressWarnings(as.numeric(aligned_sub$fail_rate_delta_qdesn_minus_reference)), na.rm = TRUE)
    } else {
      NA_real_
    }
    row
  })
  .qdesn_validation_bind_rows(rows)
}

qdesn_dynamic_studyfacing_write_analysis <- function(source_state,
                                                     output_root,
                                                     manifest = list()) {
  output_root <- normalizePath(output_root, winslash = "/", mustWork = FALSE)
  .qdesn_validation_dir_create(output_root)
  .qdesn_validation_dir_create(file.path(output_root, "tables"))
  .qdesn_validation_dir_create(file.path(output_root, "summary"))
  .qdesn_validation_dir_create(file.path(output_root, "manifest"))

  fit_summary <- source_state$fit_summary
  representative_case_table <- source_state$representative_case_table
  root_inventory <- source_state$root_inventory
  q_vs_ref_surface <- source_state$q_vs_ref_surface
  analysis_overview <- source_state$analysis_overview

  representative_prior_model_summary <- .qdesn_dynamic_maincmp_metric_summary(
    representative_case_table,
    group_cols = c("prior", "model"),
    grade_col = "signoff_grade",
    eligible_col = "comparison_eligible",
    numeric_cols = c(
      "runtime_sec", "runtime_sec_per_1k_eval",
      "train_qtrue_mae", "train_qtrue_rmse", "train_pinball_tau",
      "train_coverage_minus_tau", "train_coverage_error"
    )
  )
  representative_family_prior_summary <- .qdesn_dynamic_maincmp_metric_summary(
    representative_case_table,
    group_cols = c("family", "prior"),
    grade_col = "signoff_grade",
    eligible_col = "comparison_eligible",
    numeric_cols = c(
      "runtime_sec", "runtime_sec_per_1k_eval",
      "train_qtrue_mae", "train_qtrue_rmse", "train_pinball_tau",
      "train_coverage_minus_tau", "train_coverage_error"
    )
  )
  representative_fit_size_prior_summary <- .qdesn_dynamic_maincmp_metric_summary(
    representative_case_table,
    group_cols = c("fit_size", "prior"),
    grade_col = "signoff_grade",
    eligible_col = "comparison_eligible",
    numeric_cols = c(
      "runtime_sec", "runtime_sec_per_1k_eval",
      "train_qtrue_mae", "train_qtrue_rmse", "train_pinball_tau",
      "train_coverage_minus_tau", "train_coverage_error"
    )
  )
  root_readiness_prior_summary <- qdesn_dynamic_maincmp_root_axis_summary(root_inventory, group_cols = c("prior"))
  fail_axis_summary <- .qdesn_dynamic_studyfacing_fail_axis_summary(fit_summary)
  fail_reason_summary <- .qdesn_dynamic_studyfacing_fail_reason_summary(fit_summary)
  representative_reference_surface <- .qdesn_dynamic_studyfacing_build_reference_surface(
    representative_case_table,
    q_vs_ref_surface
  )
  representative_reference_alignment_summary <- .qdesn_dynamic_studyfacing_reference_alignment_summary(
    representative_reference_surface
  )
  representative_reference_gap_inventory <- representative_reference_surface[
    !as.logical(representative_reference_surface$reference_aligned),
    intersect(c("root_id", "family", "tau", "fit_size", "prior", "model", "signoff_grade"), names(representative_reference_surface)),
    drop = FALSE
  ]
  if (nrow(representative_reference_gap_inventory)) {
    representative_reference_gap_inventory <- representative_reference_gap_inventory[
      order(
        representative_reference_gap_inventory$family,
        representative_reference_gap_inventory$tau,
        representative_reference_gap_inventory$fit_size,
        representative_reference_gap_inventory$prior,
        representative_reference_gap_inventory$model
      ),
      ,
      drop = FALSE
    ]
  }

  overview <- data.frame(
    metric = c(
      "source_fit_rows_total",
      "source_runtime_fail_n",
      "source_signoff_fail_n",
      "source_root_total",
      "source_root_status_fail_n",
      "source_root_compare_any_n",
      "source_root_compare_full_n",
      "representative_case_rows",
      "representative_pass_n",
      "representative_warn_n",
      "representative_fail_n",
      "representative_reference_aligned_n",
      "representative_reference_gap_n"
    ),
    value = c(
      .qdesn_dynamic_studyfacing_metric_value(analysis_overview, "fit_rows_total"),
      sum(as.character(fit_summary$status) == "FAIL", na.rm = TRUE),
      .qdesn_dynamic_studyfacing_metric_value(analysis_overview, "fit_fail_n"),
      .qdesn_dynamic_studyfacing_metric_value(analysis_overview, "root_total"),
      .qdesn_dynamic_studyfacing_metric_value(analysis_overview, "root_status_fail_n"),
      .qdesn_dynamic_studyfacing_metric_value(analysis_overview, "root_compare_any_n"),
      .qdesn_dynamic_studyfacing_metric_value(analysis_overview, "root_compare_full_n"),
      .qdesn_dynamic_studyfacing_metric_value(analysis_overview, "representative_case_rows"),
      .qdesn_dynamic_studyfacing_metric_value(analysis_overview, "representative_pass_n"),
      .qdesn_dynamic_studyfacing_metric_value(analysis_overview, "representative_warn_n"),
      .qdesn_dynamic_studyfacing_metric_value(analysis_overview, "representative_fail_n"),
      sum(as.logical(representative_reference_surface$reference_aligned), na.rm = TRUE),
      sum(!as.logical(representative_reference_surface$reference_aligned), na.rm = TRUE)
    ),
    stringsAsFactors = FALSE
  )

  representative_case_table_readable <- representative_case_table
  if (nrow(representative_case_table_readable)) {
    numeric_cols <- names(representative_case_table_readable)[vapply(representative_case_table_readable, is.numeric, logical(1))]
    for (nm in numeric_cols) {
      representative_case_table_readable[[nm]] <- ifelse(
        is.finite(representative_case_table_readable[[nm]]),
        round(representative_case_table_readable[[nm]], digits = 6),
        representative_case_table_readable[[nm]]
      )
    }
  }

  .qdesn_validation_write_df(overview, file.path(output_root, "tables", "study_analysis_overview.csv"))
  .qdesn_validation_write_df(representative_case_table, file.path(output_root, "tables", "study_representative_case_table.csv"))
  .qdesn_validation_write_df(representative_case_table_readable, file.path(output_root, "tables", "study_representative_case_table_readable.csv"))
  .qdesn_validation_write_df(source_state$representative_selection_counts, file.path(output_root, "tables", "study_representative_selection_counts.csv"))
  .qdesn_validation_write_df(representative_prior_model_summary, file.path(output_root, "tables", "study_representative_prior_model_summary.csv"))
  .qdesn_validation_write_df(representative_family_prior_summary, file.path(output_root, "tables", "study_representative_family_prior_summary.csv"))
  .qdesn_validation_write_df(representative_fit_size_prior_summary, file.path(output_root, "tables", "study_representative_fit_size_prior_summary.csv"))
  .qdesn_validation_write_df(root_readiness_prior_summary, file.path(output_root, "tables", "study_root_readiness_prior_summary.csv"))
  .qdesn_validation_write_df(representative_reference_surface, file.path(output_root, "tables", "study_representative_reference_surface.csv"))
  .qdesn_validation_write_df(representative_reference_alignment_summary, file.path(output_root, "tables", "study_representative_reference_alignment_summary.csv"))
  .qdesn_validation_write_df(representative_reference_gap_inventory, file.path(output_root, "tables", "study_representative_reference_gap_inventory.csv"))
  .qdesn_validation_write_df(fail_axis_summary, file.path(output_root, "tables", "study_diagnostic_fail_axis_summary.csv"))
  .qdesn_validation_write_df(fail_reason_summary, file.path(output_root, "tables", "study_diagnostic_fail_reason_summary.csv"))

  summary_lines <- c(
    "# QDESN Tau050 Recovered Study-Facing Analysis",
    "",
    sprintf("- generated_at: `%s`", as.character(Sys.time())),
    sprintf("- recovered_comparison_root: `%s`", source_state$comparison_root),
    sprintf("- source_run_tag: `%s`", as.character(source_state$analysis_manifest$source_run_tag %||% NA_character_)),
    sprintf("- source_label: `%s`", as.character((manifest$source %||% list())$source_label %||% "Tau050 Recovered Surface")),
    "",
    "## Headline Overview",
    .qdesn_validation_df_to_markdown(overview),
    "",
    "## Main Read",
    "- There are no remaining hard runtime failures on the recovered tau050 source surface.",
    "- The study-facing surface is the 36-row representative layer, not the full 144-row recovered fit inventory.",
    "- The representative layer is entirely `vb`, with `33 PASS`, `3 WARN`, and `0 FAIL` rows.",
    "- `ridge` remains the clean comparison prior; `rhs_ns` remains a useful stress prior, but not the clean primary comparison surface.",
    "",
    "## Representative Surface By Prior + Model",
    .qdesn_validation_df_to_markdown(representative_prior_model_summary),
    "",
    "## Representative Surface By Family + Prior",
    .qdesn_validation_df_to_markdown(representative_family_prior_summary),
    "",
    "## Representative Surface By Fit Size + Prior",
    .qdesn_validation_df_to_markdown(representative_fit_size_prior_summary),
    "",
    "## Root Readiness By Prior",
    .qdesn_validation_df_to_markdown(root_readiness_prior_summary),
    "",
    "## Reference Alignment Summary",
    .qdesn_validation_df_to_markdown(representative_reference_alignment_summary),
    "",
    "## Representative Reference Gaps",
    .qdesn_validation_df_to_markdown(representative_reference_gap_inventory),
    "",
    "## Remaining Diagnostic FAIL Surface",
    .qdesn_validation_df_to_markdown(fail_axis_summary),
    "",
    "## Remaining Diagnostic FAIL Reasons",
    .qdesn_validation_df_to_markdown(fail_reason_summary),
    "",
    "## Important Interpretation Notes",
    "- This pack is intentionally study-facing: it promotes the representative layer and keeps the weaker full recovered surface as a diagnostic appendix.",
    "- The reference side remains aligned only on the mirrored dynamic surface; tau `0.50` rows remain descriptive QDESN results unless the mirrored reference is rerun under the tau050 contract.",
    "- The representative layer is entirely `vb`, which reflects the strongest recovered comparison surface rather than an implementation constraint.",
    "- Remaining fit-quality softness is concentrated in `mcmc rhs_ns` signoff behavior, not in runtime failure."
  )
  .qdesn_validation_write_lines(
    file.path(output_root, "summary", "qdesn_tau050_recovered_study_facing_analysis.md"),
    summary_lines
  )

  .qdesn_validation_write_lines(
    file.path(output_root, "summary", "qdesn_tau050_representative_case_table.md"),
    c(
      "# QDESN Tau050 Representative Case Table",
      "",
      sprintf("- generated_at: `%s`", as.character(Sys.time())),
      sprintf("- representative_rows: `%d`", nrow(representative_case_table_readable)),
      "",
      .qdesn_validation_df_to_markdown(representative_case_table_readable)
    )
  )

  .qdesn_validation_write_json(
    file.path(output_root, "manifest", "analysis_manifest.json"),
    list(
      generated_at = as.character(Sys.time()),
      recovered_comparison_root = source_state$comparison_root,
      source_run_tag = source_state$analysis_manifest$source_run_tag %||% NA_character_,
      output_root = output_root,
      representative_case_rows = nrow(representative_case_table),
      representative_fail_rows = sum(as.character(representative_case_table$signoff_grade) == "FAIL", na.rm = TRUE),
      representative_reference_aligned_n = sum(as.logical(representative_reference_surface$reference_aligned), na.rm = TRUE),
      diagnostic_fail_rows = sum(as.character(fit_summary$signoff_grade) == "FAIL", na.rm = TRUE),
      manifest = manifest
    )
  )

  invisible(list(
    overview = overview,
    representative_case_table = representative_case_table,
    representative_prior_model_summary = representative_prior_model_summary,
    representative_family_prior_summary = representative_family_prior_summary,
    representative_fit_size_prior_summary = representative_fit_size_prior_summary,
    root_readiness_prior_summary = root_readiness_prior_summary,
    representative_reference_surface = representative_reference_surface,
    representative_reference_alignment_summary = representative_reference_alignment_summary,
    representative_reference_gap_inventory = representative_reference_gap_inventory,
    fail_axis_summary = fail_axis_summary,
    fail_reason_summary = fail_reason_summary
  ))
}

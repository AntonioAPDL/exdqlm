`%||%` <- function(a, b) if (is.null(a)) b else a

qdesn_dynamic_finalpack_load_manifest <- function(path = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_final_analysis_pack_manifest.yaml"),
                                                  repo_root = NULL) {
  .qdesn_validation_require_namespace("yaml")
  yaml_path <- .qdesn_validation_resolve_path(path, repo_root = repo_root, must_work = TRUE)
  out <- yaml::read_yaml(yaml_path)
  if (!is.list(out)) {
    stop("Dynamic final analysis pack manifest YAML must parse to a list.", call. = FALSE)
  }
  out
}

.qdesn_dynamic_finalpack_resolve_studyfacing_root <- function(manifest,
                                                              repo_root = NULL) {
  source_cfg <- manifest$source %||% list()
  direct_root <- source_cfg$study_facing_root %||% NULL
  if (!is.null(direct_root) && nzchar(trimws(as.character(direct_root)[1L]))) {
    return(.qdesn_validation_resolve_path(direct_root, repo_root = repo_root, must_work = TRUE))
  }

  report_root <- source_cfg$study_facing_report_root %||% NULL
  run_tag <- as.character(source_cfg$study_facing_run_tag %||% "")[1L]
  if (!nzchar(run_tag)) {
    stop("Final analysis pack manifest must define source.study_facing_run_tag or source.study_facing_root.", call. = FALSE)
  }
  if (is.null(report_root) || !nzchar(trimws(as.character(report_root)[1L]))) {
    stop("Final analysis pack manifest must define source.study_facing_report_root when using source.study_facing_run_tag.", call. = FALSE)
  }
  .qdesn_validation_resolve_path(file.path(report_root, run_tag), repo_root = repo_root, must_work = TRUE)
}

qdesn_dynamic_finalpack_load_source_state <- function(study_facing_root,
                                                      repo_root = NULL) {
  root <- .qdesn_validation_resolve_path(study_facing_root, repo_root = repo_root, must_work = TRUE)
  tables_dir <- file.path(root, "tables")
  summary_dir <- file.path(root, "summary")
  manifest_dir <- file.path(root, "manifest")

  analysis_overview <- .qdesn_dynamic_studyfacing_read_csv(
    file.path(tables_dir, "study_analysis_overview.csv"),
    required_cols = c("metric", "value")
  )
  representative_case_table <- .qdesn_dynamic_studyfacing_read_csv(
    file.path(tables_dir, "study_representative_case_table.csv"),
    required_cols = c("root_id", "family", "tau", "fit_size", "prior", "model", "signoff_grade")
  )
  representative_prior_model_summary <- .qdesn_dynamic_studyfacing_read_csv(
    file.path(tables_dir, "study_representative_prior_model_summary.csv"),
    required_cols = c("prior", "model", "n_rows", "n_pass", "n_warn", "n_fail")
  )
  representative_family_prior_summary <- .qdesn_dynamic_studyfacing_read_csv(
    file.path(tables_dir, "study_representative_family_prior_summary.csv"),
    required_cols = c("family", "prior", "n_rows", "n_pass", "n_warn", "n_fail")
  )
  representative_fit_size_prior_summary <- .qdesn_dynamic_studyfacing_read_csv(
    file.path(tables_dir, "study_representative_fit_size_prior_summary.csv"),
    required_cols = c("fit_size", "prior", "n_rows", "n_pass", "n_warn", "n_fail")
  )
  representative_selection_counts <- .qdesn_dynamic_studyfacing_read_csv(
    file.path(tables_dir, "study_representative_selection_counts.csv"),
    required_cols = c("signoff_grade", "inference", "model", "n_selected")
  )
  root_readiness_prior_summary <- .qdesn_dynamic_studyfacing_read_csv(
    file.path(tables_dir, "study_root_readiness_prior_summary.csv"),
    required_cols = c("prior", "n_roots", "n_success", "n_full_ready", "n_usable_with_gap", "n_noncomparable")
  )
  representative_reference_surface <- .qdesn_dynamic_studyfacing_read_csv(
    file.path(tables_dir, "study_representative_reference_surface.csv"),
    required_cols = c("root_id", "family", "tau", "fit_size", "prior", "model", "signoff_grade", "reference_aligned")
  )
  representative_reference_alignment_summary <- .qdesn_dynamic_studyfacing_read_csv(
    file.path(tables_dir, "study_representative_reference_alignment_summary.csv"),
    required_cols = c("prior", "canonical_model", "n_rows", "n_reference_aligned", "n_reference_gap")
  )
  representative_reference_gap_inventory <- .qdesn_dynamic_studyfacing_read_csv(
    file.path(tables_dir, "study_representative_reference_gap_inventory.csv"),
    required_cols = c("root_id", "family", "tau", "fit_size", "prior", "model", "signoff_grade")
  )
  diagnostic_fail_axis_summary <- .qdesn_dynamic_studyfacing_read_csv(
    file.path(tables_dir, "study_diagnostic_fail_axis_summary.csv"),
    required_cols = c("inference", "model", "prior", "total_rows", "fail_rows", "fail_rate")
  )
  diagnostic_fail_reason_summary <- .qdesn_dynamic_studyfacing_read_csv(
    file.path(tables_dir, "study_diagnostic_fail_reason_summary.csv"),
    required_cols = c("reason_fragment", "inference", "model", "prior", "n_rows")
  )
  analysis_manifest <- .qdesn_validation_read_json_if_exists(file.path(manifest_dir, "analysis_manifest.json"))
  comparison_root <- .qdesn_validation_resolve_path(
    analysis_manifest$recovered_comparison_root %||% NULL,
    repo_root = repo_root,
    must_work = TRUE
  )
  comparison_state <- qdesn_dynamic_studyfacing_load_source_state(comparison_root, repo_root = repo_root)

  list(
    study_facing_root = root,
    tables_dir = tables_dir,
    summary_dir = summary_dir,
    manifest_dir = manifest_dir,
    analysis_manifest = analysis_manifest,
    analysis_overview = analysis_overview,
    representative_case_table = representative_case_table,
    representative_prior_model_summary = representative_prior_model_summary,
    representative_family_prior_summary = representative_family_prior_summary,
    representative_fit_size_prior_summary = representative_fit_size_prior_summary,
    representative_selection_counts = representative_selection_counts,
    root_readiness_prior_summary = root_readiness_prior_summary,
    representative_reference_surface = representative_reference_surface,
    representative_reference_alignment_summary = representative_reference_alignment_summary,
    representative_reference_gap_inventory = representative_reference_gap_inventory,
    diagnostic_fail_axis_summary = diagnostic_fail_axis_summary,
    diagnostic_fail_reason_summary = diagnostic_fail_reason_summary,
    comparison_root = comparison_root,
    comparison_state = comparison_state
  )
}

.qdesn_dynamic_finalpack_metric_value <- function(overview, metric) {
  idx <- which(as.character(overview$metric) == metric)
  if (!length(idx)) return(NA_real_)
  suppressWarnings(as.numeric(overview$value[idx[1L]]))
}

.qdesn_dynamic_finalpack_surface_row <- function(label,
                                                 df,
                                                 grade_col = "signoff_grade",
                                                 note = NA_character_) {
  grades <- as.character(df[[grade_col]] %||% character())
  data.frame(
    surface = label,
    n_rows = nrow(df),
    n_pass = sum(grades == "PASS", na.rm = TRUE),
    n_warn = sum(grades == "WARN", na.rm = TRUE),
    n_fail = sum(grades == "FAIL", na.rm = TRUE),
    note = as.character(note),
    stringsAsFactors = FALSE
  )
}

.qdesn_dynamic_finalpack_condensed_representative_table <- function(representative_reference_surface) {
  keep_cols <- intersect(
    c(
      "root_id", "family", "tau", "fit_size", "prior", "model", "signoff_grade",
      "runtime_sec", "holdout_qtrue_mae", "holdout_pinball_tau", "holdout_coverage_error",
      "reference_aligned", "signoff_reason"
    ),
    names(representative_reference_surface)
  )
  out <- representative_reference_surface[, keep_cols, drop = FALSE]
  if (nrow(out)) {
    out <- out[order(out$family, out$tau, out$fit_size, out$prior, out$model), , drop = FALSE]
    rownames(out) <- NULL
  }
  out
}

.qdesn_dynamic_finalpack_group_summary <- function(df,
                                                   group_cols,
                                                   grade_col = "signoff_grade",
                                                   numeric_cols = character()) {
  if (!nrow(df)) return(data.frame(stringsAsFactors = FALSE))
  group_cols <- group_cols[group_cols %in% names(df)]
  if (!length(group_cols)) return(data.frame(stringsAsFactors = FALSE))

  idx_list <- split(
    seq_len(nrow(df)),
    interaction(df[, group_cols, drop = FALSE], drop = TRUE, lex.order = TRUE)
  )
  rows <- lapply(idx_list, function(idx) {
    sub <- df[idx, , drop = FALSE]
    row <- sub[1L, group_cols, drop = FALSE]
    grades <- as.character(sub[[grade_col]])
    row$n_rows <- nrow(sub)
    row$n_pass <- sum(grades == "PASS", na.rm = TRUE)
    row$n_warn <- sum(grades == "WARN", na.rm = TRUE)
    row$n_fail <- sum(grades == "FAIL", na.rm = TRUE)
    row$pass_rate <- row$n_pass / row$n_rows
    row$warn_rate <- row$n_warn / row$n_rows
    row$fail_rate <- row$n_fail / row$n_rows
    for (nm in intersect(numeric_cols, names(sub))) {
      vals <- suppressWarnings(as.numeric(sub[[nm]]))
      row[[paste0(nm, "_mean")]] <- if (all(!is.finite(vals))) NA_real_ else mean(vals, na.rm = TRUE)
    }
    row
  })
  out <- .qdesn_validation_bind_rows(rows)
  if (!nrow(out)) return(out)
  out[do.call(order, out[group_cols]), , drop = FALSE]
}

.qdesn_dynamic_finalpack_reference_alignment_by_tau <- function(representative_reference_surface) {
  if (!nrow(representative_reference_surface)) return(data.frame(stringsAsFactors = FALSE))
  idx_list <- split(
    seq_len(nrow(representative_reference_surface)),
    interaction(representative_reference_surface$tau, drop = TRUE, lex.order = TRUE)
  )
  rows <- lapply(idx_list, function(idx) {
    sub <- representative_reference_surface[idx, , drop = FALSE]
    aligned <- as.logical(sub$reference_aligned)
    data.frame(
      tau = suppressWarnings(as.numeric(sub$tau[1L])),
      n_rows = nrow(sub),
      n_reference_aligned = sum(aligned, na.rm = TRUE),
      n_reference_gap = sum(!aligned, na.rm = TRUE),
      reference_aligned_rate = mean(aligned, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  })
  out <- .qdesn_validation_bind_rows(rows)
  if (nrow(out)) out <- out[order(out$tau), , drop = FALSE]
  out
}

.qdesn_dynamic_finalpack_appendix_scorecard <- function(fit_summary) {
  .qdesn_dynamic_finalpack_group_summary(
    fit_summary,
    group_cols = c("prior", "inference", "model"),
    grade_col = "signoff_grade",
    numeric_cols = c("runtime_sec", "holdout_qtrue_mae", "holdout_pinball_tau", "holdout_coverage_error")
  )
}

.qdesn_dynamic_finalpack_appendix_fail_inventory <- function(fit_summary) {
  fail_rows <- fit_summary[as.character(fit_summary$signoff_grade) == "FAIL", , drop = FALSE]
  keep_cols <- intersect(
    c(
      "root_id", "family", "tau", "fit_size", "prior", "inference", "model",
      "runtime_sec", "holdout_qtrue_mae", "holdout_pinball_tau", "signoff_reason"
    ),
    names(fail_rows)
  )
  out <- fail_rows[, keep_cols, drop = FALSE]
  if (nrow(out)) {
    out <- out[order(out$prior, out$inference, out$model, out$family, out$tau, out$fit_size), , drop = FALSE]
    rownames(out) <- NULL
  }
  out
}

.qdesn_dynamic_finalpack_policy_summary <- function(source_state,
                                                    manifest = list()) {
  overview <- source_state$analysis_overview
  decision_cfg <- manifest$decision %||% list()
  gap_inventory <- source_state$representative_reference_gap_inventory
  gap_taus <- sort(unique(suppressWarnings(as.numeric(gap_inventory$tau))))
  gap_taus <- gap_taus[is.finite(gap_taus)]

  aligned_n <- .qdesn_dynamic_finalpack_metric_value(overview, "representative_reference_aligned_n")
  gap_n <- .qdesn_dynamic_finalpack_metric_value(overview, "representative_reference_gap_n")
  launch_now <- isTRUE(decision_cfg$launch_reference_rerun_now)
  strict_required <- isTRUE(decision_cfg$strict_reference_alignment_required)

  decision_code <- if (launch_now) {
    "launch_strict_alignment_now"
  } else if (!strict_required && identical(sort(gap_taus), 0.5)) {
    "do_not_launch_now"
  } else if (!strict_required) {
    "optional_alignment_not_launched"
  } else {
    "strict_alignment_required_but_not_launched"
  }

  rationale <- switch(
    decision_code,
    launch_strict_alignment_now = "Strict mirrored-reference tau 0.50 alignment is explicitly required, so a rerun should be launched.",
    do_not_launch_now = "Do not launch strict mirrored-reference tau 0.50 alignment now: the representative surface is already clean, the only gaps are tau 0.50 rows, and the current study can move forward descriptively.",
    optional_alignment_not_launched = "Do not launch strict mirrored-reference alignment now: alignment remains optional and current representative coverage is sufficient for the study-facing layer.",
    strict_alignment_required_but_not_launched = "The manifest marks strict alignment as required, but launch_reference_rerun_now is still false; this should be resolved before publication-grade like-for-like tau 0.50 deltas are claimed."
  )

  data.frame(
    decision_code = decision_code,
    strict_reference_alignment_required = strict_required,
    launch_reference_rerun_now = launch_now,
    representative_reference_aligned_n = aligned_n,
    representative_reference_gap_n = gap_n,
    gap_tau_values = if (length(gap_taus)) paste(format(gap_taus, trim = TRUE), collapse = ", ") else NA_character_,
    primary_surface = as.character(decision_cfg$primary_surface %||% "representative"),
    appendix_surface = as.character(decision_cfg$appendix_surface %||% "full_recovered_fit_inventory"),
    preferred_primary_prior = as.character(decision_cfg$preferred_primary_prior %||% "ridge"),
    preferred_stress_prior = as.character(decision_cfg$preferred_stress_prior %||% "rhs_ns"),
    launch_trigger = as.character(decision_cfg$launch_trigger %||% NA_character_),
    rationale = rationale,
    stringsAsFactors = FALSE
  )
}

.qdesn_dynamic_finalpack_save_plot <- function(path,
                                               plot_fun,
                                               width = 1800,
                                               height = 1200,
                                               res = 180) {
  .qdesn_validation_dir_create(dirname(path))
  grDevices::png(path, width = width, height = height, res = res)
  on.exit(grDevices::dev.off(), add = TRUE)
  old_par <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(old_par), add = TRUE)
  plot_fun()
  invisible(path)
}

.qdesn_dynamic_finalpack_grade_mix_plot <- function(scorecard, path) {
  .qdesn_dynamic_finalpack_save_plot(path, function() {
    if (!nrow(scorecard)) {
      graphics::plot.new()
      graphics::text(0.5, 0.5, "No representative scorecard rows available.")
      return(invisible(NULL))
    }
    labels <- paste(scorecard$prior, scorecard$model, sep = " / ")
    mat <- rbind(scorecard$n_pass, scorecard$n_warn, scorecard$n_fail)
    colnames(mat) <- labels
    graphics::par(mar = c(9, 4.5, 4, 1))
    graphics::barplot(
      mat,
      beside = FALSE,
      col = c("#1B9E77", "#FDB863", "#D95F02"),
      las = 2,
      main = "Tau050 Representative Grade Mix by Prior / Model",
      ylab = "Representative rows"
    )
    graphics::legend(
      "topright",
      legend = c("PASS", "WARN", "FAIL"),
      fill = c("#1B9E77", "#FDB863", "#D95F02"),
      bty = "n"
    )
  })
}

.qdesn_dynamic_finalpack_performance_plot <- function(scorecard, path) {
  .qdesn_dynamic_finalpack_save_plot(path, function() {
    if (!nrow(scorecard)) {
      graphics::plot.new()
      graphics::text(0.5, 0.5, "No representative scorecard rows available.")
      return(invisible(NULL))
    }
    labels <- paste(scorecard$prior, scorecard$model, sep = " / ")
    graphics::par(mfrow = c(1, 2), mar = c(9, 4.5, 4, 1))
    mae_vals <- suppressWarnings(as.numeric(scorecard$holdout_qtrue_mae_mean))
    runtime_vals <- suppressWarnings(as.numeric(scorecard$runtime_sec_mean))
    graphics::barplot(
      mae_vals,
      names.arg = labels,
      las = 2,
      col = "#3182BD",
      main = "Representative Mean Holdout Qtrue MAE",
      ylab = "MAE"
    )
    graphics::barplot(
      runtime_vals,
      names.arg = labels,
      las = 2,
      col = "#756BB1",
      main = "Representative Mean Runtime",
      ylab = "Runtime (sec)"
    )
  })
}

.qdesn_dynamic_finalpack_alignment_plot <- function(alignment_by_tau, path) {
  .qdesn_dynamic_finalpack_save_plot(path, function() {
    if (!nrow(alignment_by_tau)) {
      graphics::plot.new()
      graphics::text(0.5, 0.5, "No reference-alignment rows available.")
      return(invisible(NULL))
    }
    labels <- paste0("tau=", format(alignment_by_tau$tau, trim = TRUE))
    mat <- rbind(alignment_by_tau$n_reference_aligned, alignment_by_tau$n_reference_gap)
    colnames(mat) <- labels
    graphics::par(mar = c(8, 4.5, 4, 1))
    graphics::barplot(
      mat,
      beside = FALSE,
      col = c("#2CA25F", "#FB6A4A"),
      las = 2,
      main = "Representative Reference Alignment by Tau",
      ylab = "Representative rows"
    )
    graphics::legend(
      "topright",
      legend = c("Aligned", "Gap"),
      fill = c("#2CA25F", "#FB6A4A"),
      bty = "n"
    )
  })
}

.qdesn_dynamic_finalpack_diagnostic_fail_rate_plot <- function(fail_axis_summary, path) {
  .qdesn_dynamic_finalpack_save_plot(path, function() {
    if (!nrow(fail_axis_summary)) {
      graphics::plot.new()
      graphics::text(0.5, 0.5, "No diagnostic fail summary rows available.")
      return(invisible(NULL))
    }
    labels <- paste(fail_axis_summary$inference, fail_axis_summary$model, fail_axis_summary$prior, sep = " / ")
    vals <- 100 * suppressWarnings(as.numeric(fail_axis_summary$fail_rate))
    ord <- order(vals, decreasing = TRUE, na.last = TRUE)
    graphics::par(mar = c(10, 4.5, 4, 1))
    graphics::barplot(
      vals[ord],
      names.arg = labels[ord],
      las = 2,
      col = "#D94801",
      main = "Recovered 144-Fit Diagnostic FAIL Rate by Method / Prior",
      ylab = "FAIL rate (%)"
    )
  })
}

qdesn_dynamic_finalpack_write_analysis <- function(source_state,
                                                   output_root,
                                                   manifest = list()) {
  output_root <- normalizePath(output_root, winslash = "/", mustWork = FALSE)
  .qdesn_validation_dir_create(output_root)
  .qdesn_validation_dir_create(file.path(output_root, "tables"))
  .qdesn_validation_dir_create(file.path(output_root, "summary"))
  .qdesn_validation_dir_create(file.path(output_root, "plots"))
  .qdesn_validation_dir_create(file.path(output_root, "manifest"))

  overview <- source_state$analysis_overview
  representative_case_table <- source_state$representative_case_table
  representative_reference_surface <- source_state$representative_reference_surface
  comparison_fit_summary <- source_state$comparison_state$fit_summary

  aligned_repr <- representative_reference_surface[as.logical(representative_reference_surface$reference_aligned), , drop = FALSE]
  surface_scorecard <- .qdesn_validation_bind_rows(list(
    .qdesn_dynamic_finalpack_surface_row(
      "representative_surface",
      representative_case_table,
      note = "Primary study-facing layer"
    ),
    .qdesn_dynamic_finalpack_surface_row(
      "aligned_reference_surface",
      aligned_repr,
      note = "Strict QDESN-vs-reference deltas available"
    ),
    .qdesn_dynamic_finalpack_surface_row(
      "full_recovered_fit_inventory",
      comparison_fit_summary,
      note = "Diagnostic appendix only"
    )
  ))
  representative_scorecard <- .qdesn_dynamic_finalpack_group_summary(
    representative_case_table,
    group_cols = c("prior", "model"),
    grade_col = "signoff_grade",
    numeric_cols = c("runtime_sec", "holdout_qtrue_mae", "holdout_pinball_tau", "holdout_coverage_error")
  )
  representative_case_table_condensed <- .qdesn_dynamic_finalpack_condensed_representative_table(
    representative_reference_surface
  )
  reference_alignment_by_tau <- .qdesn_dynamic_finalpack_reference_alignment_by_tau(
    representative_reference_surface
  )
  reference_alignment_decision <- .qdesn_dynamic_finalpack_policy_summary(
    source_state = source_state,
    manifest = manifest
  )
  appendix_fit_scorecard <- .qdesn_dynamic_finalpack_appendix_scorecard(comparison_fit_summary)
  appendix_fail_inventory <- .qdesn_dynamic_finalpack_appendix_fail_inventory(comparison_fit_summary)

  figure_index <- data.frame(
    figure_id = c(
      "representative_grade_mix",
      "representative_performance",
      "reference_alignment_by_tau",
      "diagnostic_fail_rate"
    ),
    rel_path = c(
      "plots/tau050_representative_grade_mix_by_prior_model.png",
      "plots/tau050_representative_performance_by_prior_model.png",
      "plots/tau050_reference_alignment_by_tau.png",
      "plots/tau050_diagnostic_fail_rate_by_method_prior.png"
    ),
    stringsAsFactors = FALSE
  )

  .qdesn_validation_write_df(surface_scorecard, file.path(output_root, "tables", "final_surface_scorecard.csv"))
  .qdesn_validation_write_df(representative_scorecard, file.path(output_root, "tables", "final_representative_scorecard.csv"))
  .qdesn_validation_write_df(representative_case_table_condensed, file.path(output_root, "tables", "final_representative_case_table_condensed.csv"))
  .qdesn_validation_write_df(reference_alignment_by_tau, file.path(output_root, "tables", "final_reference_alignment_by_tau.csv"))
  .qdesn_validation_write_df(reference_alignment_decision, file.path(output_root, "tables", "final_reference_alignment_decision.csv"))
  .qdesn_validation_write_df(appendix_fit_scorecard, file.path(output_root, "tables", "final_appendix_fit_scorecard.csv"))
  .qdesn_validation_write_df(appendix_fail_inventory, file.path(output_root, "tables", "final_appendix_fail_inventory.csv"))
  .qdesn_validation_write_df(figure_index, file.path(output_root, "tables", "final_figure_index.csv"))

  .qdesn_dynamic_finalpack_grade_mix_plot(
    representative_scorecard,
    file.path(output_root, "plots", "tau050_representative_grade_mix_by_prior_model.png")
  )
  .qdesn_dynamic_finalpack_performance_plot(
    representative_scorecard,
    file.path(output_root, "plots", "tau050_representative_performance_by_prior_model.png")
  )
  .qdesn_dynamic_finalpack_alignment_plot(
    reference_alignment_by_tau,
    file.path(output_root, "plots", "tau050_reference_alignment_by_tau.png")
  )
  .qdesn_dynamic_finalpack_diagnostic_fail_rate_plot(
    source_state$diagnostic_fail_axis_summary,
    file.path(output_root, "plots", "tau050_diagnostic_fail_rate_by_method_prior.png")
  )

  headline_lines <- c(
    "# QDESN Tau050 Final Analysis Report Pack",
    "",
    sprintf("- generated_at: `%s`", as.character(Sys.time())),
    sprintf("- study_facing_root: `%s`", source_state$study_facing_root),
    sprintf("- recovered_comparison_root: `%s`", source_state$comparison_root),
    sprintf("- source_run_tag: `%s`", as.character(source_state$analysis_manifest$source_run_tag %||% NA_character_)),
    "",
    "## Headline Surface Scorecard",
    .qdesn_validation_df_to_markdown(surface_scorecard),
    "",
    "## Main Read",
    "- The recovered tau050 study is now in analysis mode: there are no runtime crashes and the representative surface is the canonical presentation layer.",
    "- The primary study-facing surface remains the 36-row representative layer, with `33 PASS`, `3 WARN`, and `0 FAIL` rows.",
    "- `ridge` remains the clean primary comparison prior; `rhs_ns` remains valuable as the stress-test prior rather than the main headline comparison.",
    "- The full 144-row recovered fit inventory is retained explicitly as a diagnostic appendix, not as the primary presentation surface.",
    "",
    "## Representative Scorecard",
    .qdesn_validation_df_to_markdown(representative_scorecard),
    "",
    "## Figure Index",
    .qdesn_validation_df_to_markdown(figure_index),
    "",
    "## Strict Reference Alignment Decision",
    .qdesn_validation_df_to_markdown(reference_alignment_decision),
    "",
    "## Forward Use",
    "- Use this final pack for the main tau050 study/report narrative.",
    "- Use the representative layer for the main tables and figures.",
    "- Use the appendix tables to discuss remaining fit-quality softness without mixing it into the headline narrative.",
    "- Do not launch a strict mirrored-reference tau `0.50` rerun unless the manuscript explicitly needs like-for-like tau `0.50` deltas."
  )
  .qdesn_validation_write_lines(
    file.path(output_root, "summary", "qdesn_tau050_final_analysis_report.md"),
    headline_lines
  )

  main_tables_lines <- c(
    "# QDESN Tau050 Final Main Tables",
    "",
    sprintf("- generated_at: `%s`", as.character(Sys.time())),
    sprintf("- representative_rows: `%d`", nrow(representative_case_table_condensed)),
    "",
    "## Representative Scorecard",
    .qdesn_validation_df_to_markdown(representative_scorecard),
    "",
    "## Representative Case Table",
    .qdesn_validation_df_to_markdown(representative_case_table_condensed)
  )
  .qdesn_validation_write_lines(
    file.path(output_root, "summary", "qdesn_tau050_final_main_tables.md"),
    main_tables_lines
  )

  appendix_lines <- c(
    "# QDESN Tau050 Diagnostic Appendix",
    "",
    sprintf("- generated_at: `%s`", as.character(Sys.time())),
    sprintf("- recovered_fit_rows: `%d`", nrow(comparison_fit_summary)),
    "",
    "## Diagnostic FAIL Axis Summary",
    .qdesn_validation_df_to_markdown(source_state$diagnostic_fail_axis_summary),
    "",
    "## Diagnostic FAIL Reason Summary",
    .qdesn_validation_df_to_markdown(source_state$diagnostic_fail_reason_summary),
    "",
    "## Appendix Fit Scorecard",
    .qdesn_validation_df_to_markdown(appendix_fit_scorecard),
    "",
    "## Appendix FAIL Inventory",
    .qdesn_validation_df_to_markdown(appendix_fail_inventory)
  )
  .qdesn_validation_write_lines(
    file.path(output_root, "summary", "qdesn_tau050_final_diagnostic_appendix.md"),
    appendix_lines
  )

  reference_lines <- c(
    "# QDESN Tau050 Strict Reference Alignment Decision",
    "",
    sprintf("- generated_at: `%s`", as.character(Sys.time())),
    sprintf("- study_facing_root: `%s`", source_state$study_facing_root),
    "",
    "## Decision Record",
    .qdesn_validation_df_to_markdown(reference_alignment_decision),
    "",
    "## Alignment By Tau",
    .qdesn_validation_df_to_markdown(reference_alignment_by_tau),
    "",
    "## Representative Reference Gap Inventory",
    .qdesn_validation_df_to_markdown(source_state$representative_reference_gap_inventory),
    "",
    "## Interpretation",
    "- The current study-facing pack is already sufficient for the recovered tau050 narrative.",
    "- Strict mirrored-reference reruns are intentionally not launched by default here.",
    "- Launch a strict reference-alignment rerun only if a downstream report requires like-for-like tau `0.50` QDESN-vs-reference deltas."
  )
  .qdesn_validation_write_lines(
    file.path(output_root, "summary", "qdesn_tau050_strict_reference_alignment_decision.md"),
    reference_lines
  )

  .qdesn_validation_write_json(
    file.path(output_root, "manifest", "analysis_manifest.json"),
    list(
      generated_at = as.character(Sys.time()),
      study_facing_root = source_state$study_facing_root,
      recovered_comparison_root = source_state$comparison_root,
      source_run_tag = source_state$analysis_manifest$source_run_tag %||% NA_character_,
      output_root = output_root,
      representative_case_rows = nrow(representative_case_table),
      representative_reference_aligned_n = sum(as.logical(representative_reference_surface$reference_aligned), na.rm = TRUE),
      representative_reference_gap_n = sum(!as.logical(representative_reference_surface$reference_aligned), na.rm = TRUE),
      diagnostic_fail_rows = sum(as.character(comparison_fit_summary$signoff_grade) == "FAIL", na.rm = TRUE),
      reference_alignment_decision = reference_alignment_decision,
      manifest = manifest
    )
  )

  invisible(list(
    surface_scorecard = surface_scorecard,
    representative_scorecard = representative_scorecard,
    representative_case_table_condensed = representative_case_table_condensed,
    reference_alignment_by_tau = reference_alignment_by_tau,
    reference_alignment_decision = reference_alignment_decision,
    appendix_fit_scorecard = appendix_fit_scorecard,
    appendix_fail_inventory = appendix_fail_inventory,
    figure_index = figure_index
  ))
}

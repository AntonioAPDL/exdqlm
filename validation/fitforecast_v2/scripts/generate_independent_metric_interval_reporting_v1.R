#!/usr/bin/env Rscript

args_raw <- commandArgs(trailingOnly = TRUE)
repo_arg <- grep("^--repo-root=", args_raw, value = TRUE)
repo_root <- if (length(repo_arg)) sub("^--repo-root=", "", repo_arg[[1L]]) else getwd()
repo_root <- normalizePath(repo_root, winslash = "/", mustWork = TRUE)
setwd(repo_root)

source(file.path(repo_root, "validation", "fitforecast_v2", "R", "utils.R"))
ffv2_source_all(file.path(repo_root, "validation", "fitforecast_v2"))

output_dir <- imir_v1_output_dir(repo_root)
article_dir <- file.path(output_dir, "article_assets")
figure_dir <- file.path(article_dir, "figures", "independent_simulation")
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

roles <- imir_v1_read_roles(repo_root)
plot_data <- imir_v1_prepare_plot_data(roles)
checks <- imir_v1_contract_checks(plot_data)
if (!all(checks$pass)) {
  stop(sprintf("Reporting input audit failed: %s",
               paste(checks$check[!checks$pass], collapse = ", ")), call. = FALSE)
}

source_path <- imir_v1_source_path(repo_root)
source_sha256 <- ffv2_file_sha256(source_path)
pilot_closeout <- file.path(
  repo_root, "reports", "shared_fitforecast_v2_orchestration",
  "independent_metric_interval_coupling_pilot_v1_20260825_000726", "closeout"
)
pilot_files <- c(
  "decision_manifest.json", "closeout_checks.csv", "paired_coupling_comparison.csv",
  "primary_replay_vs_v10.csv", "article_overlap_sensitivity.csv"
)
pilot_paths <- file.path(pilot_closeout, pilot_files)
if (!all(file.exists(pilot_paths))) {
  stop("Completed coupling-pilot closeout evidence is incomplete.", call. = FALSE)
}

ffv2_write_csv(plot_data, file.path(output_dir, "plot_ready_metric_intervals.csv"))
ffv2_write_csv(checks, file.path(output_dir, "input_contract_checks.csv"))
ffv2_write_csv(imir_v1_contract_ledger(), file.path(output_dir, "estimator_contract_ledger.csv"))
ffv2_write_csv(imir_v1_implementation_ledger(),
               file.path(output_dir, "implementation_contract_ledger.csv"))
figure_spec <- imir_v1_figure_spec()
ffv2_write_csv(figure_spec, file.path(output_dir, "figure_specification.csv"))

figure_paths <- character(0)
for (i in seq_len(nrow(figure_spec))) {
  inference <- figure_spec$inference[[i]]
  metric_role <- figure_spec$metric_role[[i]]
  plot <- imir_v1_plot_metric_intervals(plot_data, inference, metric_role)
  pdf_path <- file.path(
    figure_dir, imir_v1_figure_filename(inference, metric_role, "pdf")
  )
  png_path <- file.path(
    figure_dir, imir_v1_figure_filename(inference, metric_role, "png")
  )
  imir_v1_save_plot(
    plot, pdf_path, png_path,
    width = figure_spec$width_inches[[i]],
    height = figure_spec$height_inches[[i]],
    dpi = figure_spec$png_dpi[[i]]
  )
  figure_paths <- c(figure_paths, pdf_path, png_path)
}

caption_text <- function(inference, metric_role) {
  interval_text <- if (inference == "mcmc") {
    "equal-tailed 95\\% posterior intervals"
  } else {
    "equal-tailed approximate 95\\% variational posterior intervals"
  }
  paste0(
    if (inference == "mcmc") "MCMC" else "Variational Bayes",
    " posterior uncertainty for ", tolower(imir_v1_metric_labels[[metric_role]]),
    " in the single-quantile simulation study. Horizontal segments show ", interval_text,
    "; crosses mark posterior means. Each panel uses its own horizontal scale, and lower values are better. ",
    "Bands condition on the fixed simulated data set, evaluation grid, and case-specific model specification."
  )
}

write_wrapper <- function(inference) {
  lines <- character(0)
  for (metric_role in names(imir_v1_metric_labels)) {
    stem <- sub("[.]pdf$", "", imir_v1_figure_filename(inference, metric_role, "pdf"))
    label <- sprintf("fig:simulation-500obs-%s-%s-intervals", inference,
                     imir_v1_metric_file_labels[[metric_role]])
    lines <- c(lines,
      "\\begin{figure}[!htbp]",
      "\\centering",
      sprintf("\\includegraphics[width=0.98\\textwidth]{figures/independent_simulation/%s.pdf}", stem),
      sprintf("\\caption{%s}", caption_text(inference, metric_role)),
      sprintf("\\label{%s}", label),
      "\\end{figure}", "")
  }
  if (length(lines) && !nzchar(tail(lines, 1L))) {
    lines <- head(lines, -1L)
  }
  path <- file.path(article_dir, sprintf(
    "qdesn_validation_500obs_%s_metric_interval_figures.tex", inference
  ))
  writeLines(lines, path, useBytes = TRUE)
  path
}

wrapper_paths <- c(write_wrapper("mcmc"), write_wrapper("vb"))
prose_path <- file.path(article_dir,
                        "qdesn_validation_500obs_metric_interval_contract_clarification.tex")
writeLines(c(
  "The displayed bands are posterior distributions of the draw-wise aggregate criteria under each model's native conditional-quantile construction. Q--DESN and exQ--DESN preserve the fitted posterior readout-draw identity across rolling origins and forecast leads. DQLM and exDQLM combine the origin--lead latent quantile marginals produced by the rolling state-update interface using the pre-specified product coupling. The resulting intervals are valid for these stated model-specific contracts; they do not impose a common cross-origin copula, and their widths should therefore be interpreted as native posterior uncertainty rather than as a model-free measure of repeated-simulation variability.",
  "",
  "A paired coupling sensitivity analysis preserved every finite origin--lead marginal distribution and left the posterior metric means unchanged to numerical precision. Interval widths were sensitive to the imposed dependence in the representative cells, but no tested winner--runner-up interval-overlap conclusion changed. The native intervals are consequently retained, with the coupling analysis serving as sensitivity evidence rather than as a replacement estimator."
), prose_path, useBytes = TRUE)

pilot_summary <- data.frame(
  item = c(
    "planned_jobs", "completed_jobs", "failed_jobs", "replay_sources",
    "material_coupling_comparisons", "overlap_conclusion_changes",
    "heavy_binary_count", "deterministic_replay_tolerance",
    "fresh_chain_equivalence_standard", "refit_required"
  ),
  value = c(
    "33", "33", "0", "11", "22", "0", "0",
    format(imir_v1_deterministic_tolerance, scientific = TRUE),
    "statistical_not_bitwise", "FALSE"
  ),
  stringsAsFactors = FALSE
)
ffv2_write_csv(pilot_summary, file.path(output_dir, "coupling_pilot_interpretation.csv"))
paired <- ffv2_read_csv(file.path(pilot_closeout, "paired_coupling_comparison.csv"))
overlap_sensitivity <- ffv2_read_csv(
  file.path(pilot_closeout, "article_overlap_sensitivity.csv")
)
fresh_replay <- imir_v1_fresh_chain_equivalence(ffv2_read_csv(
  file.path(pilot_closeout, "primary_replay_vs_v10.csv")
))
pilot_checks <- ffv2_read_csv(file.path(pilot_closeout, "closeout_checks.csv"))
ffv2_write_csv(paired, file.path(output_dir, "coupling_paired_comparison.csv"))
ffv2_write_csv(overlap_sensitivity,
               file.path(output_dir, "coupling_overlap_sensitivity.csv"))
ffv2_write_csv(fresh_replay, file.path(output_dir, "fresh_chain_replay_equivalence.csv"))
ffv2_write_csv(pilot_checks, file.path(output_dir, "coupling_pilot_original_checks.csv"))

decision <- list(
  schema_version = imir_v1_schema,
  reporting_id = imir_v1_reporting_id,
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  source_promotion_id = imir_v1_source_promotion_id,
  source_interval_sha256 = source_sha256,
  decision = "RETAIN_V10_NATIVE_INTERVALS_WITH_EXPLICIT_COUPLING_DISCLOSURE",
  implementation_error_found = FALSE,
  refit_required = FALSE,
  coherent_trajectory_campaign_required = FALSE,
  article_metric_replacement_authorized = FALSE,
  article_figure_and_methods_clarification_authorized = TRUE,
  deterministic_replay_tolerance = imir_v1_deterministic_tolerance,
  fresh_chain_replay_rule = "statistical_equivalence_not_bitwise_identity",
  rationale = c(
    "all 216 article-role intervals are finite, ordered, and uniquely mapped",
    "the portable same-draw replay reproduced all 270 source-metric summaries",
    "the implementations match their declared native model-specific coupling contracts",
    "paired alternative couplings preserve means but change widths",
    "no tested winner-runner overlap conclusion changed"
  ),
  deterministic_rows_within_1e6 = sum(fresh_replay$deterministic_all_summary_match),
  deterministic_rows_total = nrow(fresh_replay),
  fresh_chain_equivalent_rows = sum(fresh_replay$fresh_chain_statistical_equivalence),
  fresh_chain_equivalent_rows_total = nrow(fresh_replay),
  maximum_standardized_mean_difference = max(fresh_replay$standardized_mean_difference),
  minimum_interval_overlap_fraction = min(fresh_replay$interval_overlap_fraction),
  material_coupling_comparisons = sum(paired$severity == "MATERIAL"),
  overlap_conclusion_changes = sum(overlap_sensitivity$overlap_conclusion_changed),
  figures = 6L,
  figure_files = 12L,
  article_wrappers = 2L,
  article_prose_assets = 1L,
  integration_owner = "ARTICLE_QDESN_INTEGRATION"
)
decision_path <- file.path(output_dir, "decision_manifest.json")
ffv2_write_json(decision, decision_path)

tracked_inputs <- c(
  file.path(output_dir, "plot_ready_metric_intervals.csv"),
  file.path(output_dir, "input_contract_checks.csv"),
  file.path(output_dir, "estimator_contract_ledger.csv"),
  file.path(output_dir, "implementation_contract_ledger.csv"),
  file.path(output_dir, "figure_specification.csv"),
  file.path(output_dir, "coupling_pilot_interpretation.csv"),
  file.path(output_dir, "coupling_paired_comparison.csv"),
  file.path(output_dir, "coupling_overlap_sensitivity.csv"),
  file.path(output_dir, "fresh_chain_replay_equivalence.csv"),
  file.path(output_dir, "coupling_pilot_original_checks.csv"),
  decision_path, figure_paths, wrapper_paths, prose_path
)
ledger <- imir_v1_file_ledger(tracked_inputs, output_dir)
ffv2_write_csv(ledger, file.path(output_dir, "reporting_file_ledger.csv"))

article_assets <- c(figure_paths[grepl("[.]pdf$", figure_paths)], wrapper_paths, prose_path)
article_manifest <- imir_v1_file_ledger(article_assets, article_dir)
article_manifest$article_destination <- ifelse(
  startsWith(article_manifest$relative_path, "figures/"),
  article_manifest$relative_path,
  file.path("tables", basename(article_manifest$relative_path))
)
ffv2_write_csv(article_manifest, file.path(output_dir, "article_asset_manifest.csv"))

cat(sprintf("REPORTING_READY output=%s figures=%d rows=%d decision=%s\n",
            output_dir, length(figure_paths) / 2L, nrow(plot_data), decision$decision))

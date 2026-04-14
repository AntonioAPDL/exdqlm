#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_original288_exactspec_multiseed_helpers_20260412.R")

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)

paths <- paths_original288_exactspec_multiseed()

selection <- utils::read.csv(paths$selection, stringsAsFactors = FALSE, check.names = FALSE)
selection$base_row_id <- seq_len(nrow(selection))
selected <- utils::read.csv(paths$full_selected, stringsAsFactors = FALSE, check.names = FALSE)
manifest <- utils::read.csv(paths$full_manifest, stringsAsFactors = FALSE, check.names = FALSE)

if (nrow(selected) != nrow(selection)) {
  stop(sprintf("selected winner table has %d rows but selection has %d rows", nrow(selected), nrow(selection)))
}

manifest_keep <- manifest[, c("row_id", "candidate_fit_path", "health_path", "metrics_path", "draws_path"), drop = FALSE]
selected <- merge(
  selected,
  manifest_keep,
  by = "row_id",
  all.x = TRUE,
  sort = FALSE
)
selected <- selected[order(selected$base_row_id), , drop = FALSE]

refreshed <- merge(
  selection,
  selected,
  by = c("base_row_id", "original_case_key"),
  all.x = TRUE,
  sort = FALSE,
  suffixes = c("_baseline", "_selected")
)
refreshed <- refreshed[order(refreshed$base_row_id), , drop = FALSE]

# Preserve the accepted-selection row metadata exactly as the baseline context.
# The replay contributes selected-seed result fields, but it should not erase
# cluster-defining columns such as block/model/inference during the merge.
for (nm in names(selection)) {
  baseline_nm <- paste0(nm, "_baseline")
  if (baseline_nm %in% names(refreshed)) {
    refreshed[[nm]] <- refreshed[[baseline_nm]]
  }
}

refreshed$selected_source_type <- "exactspec_multiseed_relaunch_20260412"
refreshed$selected_source_subtype <- "selected_seed"
refreshed$selected_candidate <- refreshed$candidate_label
refreshed$selected_variant_tag <- run_tag_original288_exactspec_multiseed()
refreshed$selected_fit_path <- refreshed$candidate_fit_path
refreshed$selected_health_path <- refreshed$health_path
refreshed$selected_summary_path <- refreshed$metrics_path
refreshed$source_path <- refreshed$metrics_path
refreshed$gate_overall <- refreshed$gate_current
refreshed$healthy <- refreshed$healthy_current
refreshed$runtime_sec <- refreshed$runtime_sec_current
refreshed$improved_over_baseline <- refreshed$accepted_compare == "better_than_accepted"
refreshed$selection_mode <- "exactspec_multiseed_selected"
refreshed$selection_reason <- sprintf(
  "Replay exact prior row spec with only n.burn=5000, n.mcmc=20000, stored_posterior_draws=20000, and deterministic 4-seed selection under %s.",
  run_tag_original288_exactspec_multiseed()
)
refreshed$metric_sim_path_override <- NA_character_
refreshed$comparison_note <- sprintf(
  "selected_seed_slot=%02d; selected_seed=%d; gate=%s; crps=%.8f; primary_accuracy=%.8f",
  as.integer(refreshed$seed_slot),
  as.integer(refreshed$seed),
  as.character(refreshed$gate_current),
  as.numeric(refreshed$crps_metric),
  as.numeric(refreshed$primary_accuracy_metric)
)

selection_cols <- c(
  "block","root_kind","family","tau","fit_size","prior_semantics","model","inference","method","root_id",
  "original_scenario_key","original_case_key","baseline_signoff_path","baseline_fit_path","baseline_fit_path_exists",
  "baseline_gate_overall","baseline_healthy","baseline_status","baseline_signoff_reason","comparison_eligible",
  "convergence_certified","execution_healthy","selected_source_type","selected_source_subtype","selected_candidate",
  "selected_variant_tag","selected_fit_path","selected_health_path","selected_summary_path","source_path",
  "gate_overall","healthy","runtime_sec","improved_over_baseline","selection_mode","selection_reason",
  "metric_sim_path_override","comparison_note"
)
for (nm in selection_cols) {
  if (!nm %in% names(refreshed)) refreshed[[nm]] <- NA
}

refreshed_out <- refreshed[, selection_cols, drop = FALSE]
utils::write.csv(refreshed_out, paths$exactspec_selection, row.names = FALSE)

selection_summary <- aggregate(
  list(
    total = rep(1L, nrow(refreshed_out)),
    healthy = refreshed_out$healthy,
    pass = refreshed$gate_current == "PASS",
    warn = refreshed$gate_current == "WARN",
    fail = refreshed$gate_current == "FAIL",
    improved = refreshed$accepted_compare == "better_than_accepted"
  ),
  by = list(block = refreshed_out$block, model = refreshed_out$model, inference = refreshed_out$inference),
  FUN = function(x) sum(x, na.rm = TRUE)
)
utils::write.csv(selection_summary, paths$exactspec_selection_summary, row.names = FALSE)

rc <- system2(
  "Rscript",
  args = c(
    "tools/merge_reports/LOCAL_original288_tablebacked_cluster_comparison_20260411.R",
    sprintf("--selection=%s", paths$exactspec_selection),
    "--dynamic_update=",
    sprintf("--output_dir=%s", paths$comparison_output_dir),
    sprintf("--report=%s", paths$comparison_report)
  )
)
if (!is.null(rc) && rc != 0L) stop(sprintf("comparison refresh failed with code %s", rc))

fmt_int_exactspec <- function(x) {
  ifelse(is.na(x), "NA", format(as.integer(x), trim = TRUE, scientific = FALSE))
}

fmt_pct_exactspec <- function(x) {
  ifelse(is.na(x), "NA", sprintf("%.1f%%", 100 * x))
}

fmt_num_exactspec <- function(x, digits = 3) {
  ifelse(is.na(x), "NA", sprintf(paste0("%.", digits, "f"), x))
}

fmt_ratio_exactspec <- function(x) {
  ifelse(is.na(x), "NA", sprintf("%.2fx", x))
}

markdown_table_exactspec <- function(df) {
  header <- paste0("| ", paste(names(df), collapse = " | "), " |")
  rule <- paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|")
  rows <- apply(df, 1, function(row) paste0("| ", paste(row, collapse = " | "), " |"))
  c(header, rule, rows)
}

metric_long <- utils::read.csv(
  file.path(paths$comparison_output_dir, "original288_tablebacked_metric_long_20260411.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
meta <- utils::read.csv(
  file.path(paths$comparison_output_dir, "original288_tablebacked_metric_meta_20260411.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
static_model_cluster_summary <- utils::read.csv(
  file.path(paths$comparison_output_dir, "original288_static_model_cluster_summary_20260411.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
dynamic_model_cluster_summary <- utils::read.csv(
  file.path(paths$comparison_output_dir, "original288_dynamic_model_cluster_summary_20260411.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
dynamic_model_cluster_by_tau <- utils::read.csv(
  file.path(paths$comparison_output_dir, "original288_dynamic_model_cluster_by_tau_20260411.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
static_algorithm_cluster_summary <- utils::read.csv(
  file.path(paths$comparison_output_dir, "original288_static_algorithm_cluster_summary_20260411.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
dynamic_algorithm_cluster_summary <- utils::read.csv(
  file.path(paths$comparison_output_dir, "original288_dynamic_algorithm_cluster_summary_20260411.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

error_rows <- metric_long[!is.na(metric_long$metric_error) & nzchar(metric_long$metric_error), , drop = FALSE]
if (nrow(error_rows)) {
  error_summary <- aggregate(
    list(count = rep(1L, nrow(error_rows))),
    by = list(metric_error = error_rows$metric_error),
    FUN = sum
  )
  error_summary$share_of_rows <- error_summary$count / max(1L, nrow(metric_long))
  error_summary <- error_summary[order(-error_summary$count, error_summary$metric_error), , drop = FALSE]
} else {
  error_summary <- data.frame(metric_error = character(), count = integer(), share_of_rows = numeric(), stringsAsFactors = FALSE)
}

static_model_report <- static_model_cluster_summary
static_model_report$better <- sprintf(
  "%s / %s",
  fmt_int_exactspec(static_model_report$better_accuracy),
  fmt_int_exactspec(static_model_report$available_accuracy)
)
static_model_report$better_share <- fmt_pct_exactspec(static_model_report$better_accuracy_share)
static_model_report$healthier <- sprintf(
  "%s / %s",
  fmt_int_exactspec(static_model_report$healthier),
  fmt_int_exactspec(static_model_report$n)
)
static_model_report$healthier_share <- fmt_pct_exactspec(static_model_report$healthier_share)
static_model_report$delta_mean <- fmt_num_exactspec(static_model_report$delta_mean, 3)
static_model_report$runtime_ratio <- fmt_ratio_exactspec(static_model_report$runtime_ratio_median)
static_model_report <- static_model_report[, c(
  "block", "prior_semantics", "inference", "better", "better_share",
  "healthier", "healthier_share", "delta_mean", "runtime_ratio"
)]

dynamic_model_report <- dynamic_model_cluster_summary
dynamic_model_report$better <- sprintf(
  "%s / %s",
  fmt_int_exactspec(dynamic_model_report$better_accuracy),
  fmt_int_exactspec(dynamic_model_report$available_accuracy)
)
dynamic_model_report$better_share <- fmt_pct_exactspec(dynamic_model_report$better_accuracy_share)
dynamic_model_report$healthier <- sprintf(
  "%s / %s",
  fmt_int_exactspec(dynamic_model_report$healthier),
  fmt_int_exactspec(dynamic_model_report$n)
)
dynamic_model_report$healthier_share <- fmt_pct_exactspec(dynamic_model_report$healthier_share)
dynamic_model_report$delta_mean <- fmt_num_exactspec(dynamic_model_report$delta_mean, 3)
dynamic_model_report$runtime_ratio <- fmt_ratio_exactspec(dynamic_model_report$runtime_ratio_median)
dynamic_model_report <- dynamic_model_report[, c(
  "inference", "better", "better_share", "healthier",
  "healthier_share", "delta_mean", "runtime_ratio"
)]

dynamic_tau_report <- dynamic_model_cluster_by_tau
dynamic_tau_report$better <- sprintf(
  "%s / %s",
  fmt_int_exactspec(dynamic_tau_report$better_accuracy),
  fmt_int_exactspec(dynamic_tau_report$available_accuracy)
)
dynamic_tau_report$better_share <- fmt_pct_exactspec(dynamic_tau_report$better_accuracy_share)
dynamic_tau_report$healthier <- sprintf(
  "%s / %s",
  fmt_int_exactspec(dynamic_tau_report$healthier),
  fmt_int_exactspec(dynamic_tau_report$n)
)
dynamic_tau_report$healthier_share <- fmt_pct_exactspec(dynamic_tau_report$healthier_share)
dynamic_tau_report$delta_mean <- fmt_num_exactspec(dynamic_tau_report$delta_mean, 3)
dynamic_tau_report$runtime_ratio <- fmt_ratio_exactspec(dynamic_tau_report$runtime_ratio_median)
dynamic_tau_report <- dynamic_tau_report[, c(
  "inference", "tau_label", "better", "better_share", "healthier",
  "healthier_share", "delta_mean", "runtime_ratio"
)]

static_algorithm_report <- static_algorithm_cluster_summary
static_algorithm_report$better <- sprintf(
  "%s / %s",
  fmt_int_exactspec(static_algorithm_report$better_accuracy),
  fmt_int_exactspec(static_algorithm_report$available_accuracy)
)
static_algorithm_report$better_share <- fmt_pct_exactspec(static_algorithm_report$better_accuracy_share)
static_algorithm_report$healthier <- sprintf(
  "%s / %s",
  fmt_int_exactspec(static_algorithm_report$healthier),
  fmt_int_exactspec(static_algorithm_report$n)
)
static_algorithm_report$healthier_share <- fmt_pct_exactspec(static_algorithm_report$healthier_share)
static_algorithm_report$delta_mean <- fmt_num_exactspec(static_algorithm_report$delta_mean, 3)
static_algorithm_report$runtime_ratio <- fmt_ratio_exactspec(static_algorithm_report$runtime_ratio_median)
static_algorithm_report <- static_algorithm_report[, c(
  "block", "prior_semantics", "model", "better", "better_share",
  "healthier", "healthier_share", "delta_mean", "runtime_ratio"
)]

dynamic_algorithm_report <- dynamic_algorithm_cluster_summary
dynamic_algorithm_report$better <- sprintf(
  "%s / %s",
  fmt_int_exactspec(dynamic_algorithm_report$better_accuracy),
  fmt_int_exactspec(dynamic_algorithm_report$available_accuracy)
)
dynamic_algorithm_report$better_share <- fmt_pct_exactspec(dynamic_algorithm_report$better_accuracy_share)
dynamic_algorithm_report$healthier <- sprintf(
  "%s / %s",
  fmt_int_exactspec(dynamic_algorithm_report$healthier),
  fmt_int_exactspec(dynamic_algorithm_report$n)
)
dynamic_algorithm_report$healthier_share <- fmt_pct_exactspec(dynamic_algorithm_report$healthier_share)
dynamic_algorithm_report$delta_mean <- fmt_num_exactspec(dynamic_algorithm_report$delta_mean, 3)
dynamic_algorithm_report$runtime_ratio <- fmt_ratio_exactspec(dynamic_algorithm_report$runtime_ratio_median)
dynamic_algorithm_report <- dynamic_algorithm_report[, c(
  "model", "better", "better_share", "healthier",
  "healthier_share", "delta_mean", "runtime_ratio"
)]

static_mcmc <- subset(static_model_cluster_summary, inference == "mcmc")
static_vb <- subset(static_model_cluster_summary, inference == "vb")
dynamic_mcmc <- subset(dynamic_model_cluster_summary, inference == "mcmc")
dynamic_vb <- subset(dynamic_model_cluster_summary, inference == "vb")

static_mcmc_better <- sum(static_mcmc$better_accuracy, na.rm = TRUE)
static_mcmc_available <- sum(static_mcmc$available_accuracy, na.rm = TRUE)
static_vb_better <- sum(static_vb$better_accuracy, na.rm = TRUE)
static_vb_available <- sum(static_vb$available_accuracy, na.rm = TRUE)
dynamic_mcmc_better <- sum(dynamic_mcmc$better_accuracy, na.rm = TRUE)
dynamic_mcmc_available <- sum(dynamic_mcmc$available_accuracy, na.rm = TRUE)
dynamic_vb_better <- sum(dynamic_vb$better_accuracy, na.rm = TRUE)
dynamic_vb_available <- sum(dynamic_vb$available_accuracy, na.rm = TRUE)

if (nrow(error_summary)) {
  error_report <- error_summary
  error_report$count <- fmt_int_exactspec(error_report$count)
  error_report$share_of_rows <- fmt_pct_exactspec(error_report$share_of_rows)
} else {
  error_report <- data.frame(metric_error = "none", count = "0", share_of_rows = "0.0%", stringsAsFactors = FALSE)
}

report_lines <- c(
  "# Original288 Table-Backed Cluster Comparison (Exact-Spec Replay, 2026-04-14)",
  "",
  "This note refreshes the fit-performance comparison after the completed exact-spec multiseed replay. It reuses the recent table-backed comparison framework, but now evaluates the replay-selected winners rather than the earlier accepted `v9` snapshot.",
  "",
  "## Scope",
  "",
  "- start from the corrected `rhs_ns` comparison selection (`288` rows)",
  "- preserve each row's prior winning local spec and replay under the standardized exact-spec controls",
  "- select one winner per row from the deterministic `4`-seed replay",
  "- compare within inference (`al` vs `exal`, `dqlm` vs `exdqlm`) and within model (`vb` vs `mcmc`) on fit-performance metrics",
  "",
  "## Replay Rule",
  "",
  "- preserve row-local kernels, proposals, joint/non-joint choices, adapt/no-adapt settings, refresh cadence, widths, and initialization strategy",
  "- change only `n.burn = 5000`, `n.mcmc = 20000`, stored posterior draws `= 20000`, and the deterministic `4`-seed selection rule",
  "",
  "## Data Quality",
  "",
  sprintf("- selected rows: `%d`", meta$selection_rows[[1]]),
  sprintf("- metric rows built: `%d`", meta$metric_rows[[1]]),
  sprintf("- metric extraction errors: `%d`", meta$metric_errors[[1]]),
  sprintf("- static model pairs: `%d`", meta$static_model_pairs[[1]]),
  sprintf("- dynamic model pairs: `%d`", meta$dynamic_model_pairs[[1]]),
  "",
  markdown_table_exactspec(error_report),
  "",
  "## Main Results",
  "",
  sprintf("- static `mcmc`: `exal` has better primary accuracy in `%d / %d` scenario pairs (`%.1f%%`)", static_mcmc_better, static_mcmc_available, 100 * static_mcmc_better / max(1, static_mcmc_available)),
  sprintf("- static `vb`: `exal` has better primary accuracy in `%d / %d` scenario pairs (`%.1f%%`)", static_vb_better, static_vb_available, 100 * static_vb_better / max(1, static_vb_available)),
  sprintf("- dynamic `mcmc`: `exdqlm` has better primary accuracy in `%d / %d` comparable scenario pairs (`%.1f%%`)", dynamic_mcmc_better, dynamic_mcmc_available, 100 * dynamic_mcmc_better / max(1, dynamic_mcmc_available)),
  sprintf("- dynamic `vb`: `exdqlm` has better primary accuracy in `%d / %d` comparable scenario pairs (`%.1f%%`)", dynamic_vb_better, dynamic_vb_available, 100 * dynamic_vb_better / max(1, dynamic_vb_available)),
  "",
  "## Static Model Comparison Within Inference",
  "",
  markdown_table_exactspec(static_model_report),
  "",
  "## Dynamic Model Comparison Within Inference",
  "",
  markdown_table_exactspec(dynamic_model_report),
  "",
  "## Dynamic Model Comparison By Tau",
  "",
  markdown_table_exactspec(dynamic_tau_report),
  "",
  "## Algorithm Comparison Within Model",
  "",
  "Static:",
  "",
  markdown_table_exactspec(static_algorithm_report),
  "",
  "Dynamic:",
  "",
  markdown_table_exactspec(dynamic_algorithm_report),
  "",
  "## Interpretation",
  "",
  "- this exact-spec replay does **not** support the older static claim that `exal` is better than `al` overall within `mcmc` on the current primary-accuracy metric",
  "- the static side is broadly unfavorable for `exal` in this replay: `5 / 54` better pairs in `mcmc` and `7 / 54` in `vb`",
  "- the dynamic side is only partially comparable because `36` replay rows failed metric extraction with the same computationally singular error, leaving `9 / 18` comparable model pairs in each dynamic inference lane",
  "- within the comparable dynamic `mcmc` pairs, `exdqlm` is mixed but not hopeless (`3 / 9` better), with the strongest pocket at `tau = 0p25`",
  "- dynamic `vb` is unfavorable on the current primary-accuracy metric in this replay (`0 / 9` better pairs)",
  "- within-model inference comparisons now lean toward `mcmc` more than the older accepted-state comparison did: dynamic `exdqlm` has `8 / 9` available pairs where `mcmc` beats `vb` on the current primary-accuracy metric",
  "- this pass is reproducible and directly tied to the completed exact-spec replay outputs rather than a mixed accepted-state carryforward snapshot",
  "",
  "## Outputs",
  "",
  sprintf("- `%s`", file.path(paths$comparison_output_dir, "original288_tablebacked_metric_long_20260411.csv")),
  sprintf("- `%s`", file.path(paths$comparison_output_dir, "original288_static_model_pair_comparison_20260411.csv")),
  sprintf("- `%s`", file.path(paths$comparison_output_dir, "original288_dynamic_model_pair_comparison_20260411.csv")),
  sprintf("- `%s`", file.path(paths$comparison_output_dir, "original288_static_algorithm_pair_comparison_20260411.csv")),
  sprintf("- `%s`", file.path(paths$comparison_output_dir, "original288_dynamic_algorithm_pair_comparison_20260411.csv")),
  sprintf("- `%s`", file.path(paths$comparison_output_dir, "original288_static_model_cluster_summary_20260411.csv")),
  sprintf("- `%s`", file.path(paths$comparison_output_dir, "original288_dynamic_model_cluster_summary_20260411.csv"))
)

writeLines(report_lines, con = paths$comparison_report)

cat(sprintf(
  "REFRESH exactspec_selection=%s rows=%d comparison_report=%s\n",
  paths$exactspec_selection,
  nrow(refreshed_out),
  paths$comparison_report
))

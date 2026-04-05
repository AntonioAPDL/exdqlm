#!/usr/bin/env Rscript

source("tools/merge_reports/LOCAL_validation_campaign_comparison_helpers_20260405.R")

comparison_long_path <- "tools/merge_reports/LOCAL_validation_campaign_comparison_long_v1_20260405.csv"

summary_by_model_path <- "tools/merge_reports/LOCAL_validation_campaign_summary_by_model_v1_20260405.csv"
summary_by_inference_path <- "tools/merge_reports/LOCAL_validation_campaign_summary_by_inference_v1_20260405.csv"
summary_by_root_kind_path <- "tools/merge_reports/LOCAL_validation_campaign_summary_by_root_kind_v1_20260405.csv"
summary_by_family_path <- "tools/merge_reports/LOCAL_validation_campaign_summary_by_family_v1_20260405.csv"
summary_by_tau_path <- "tools/merge_reports/LOCAL_validation_campaign_summary_by_tau_v1_20260405.csv"
summary_by_method_path <- "tools/merge_reports/LOCAL_validation_campaign_summary_by_method_v1_20260405.csv"
summary_by_prior_path <- "tools/merge_reports/LOCAL_validation_campaign_summary_by_prior_semantics_v1_20260405.csv"

mcmc_diag_path <- "tools/merge_reports/LOCAL_validation_campaign_mcmc_diagnostics_by_method_v1_20260405.csv"
vb_diag_path <- "tools/merge_reports/LOCAL_validation_campaign_vb_diagnostics_by_method_v1_20260405.csv"

static_broad_path <- "tools/merge_reports/LOCAL_validation_campaign_static_broad_comparison_v1_20260405.csv"
dynamic_broad_path <- "tools/merge_reports/LOCAL_validation_campaign_dynamic_broad_comparison_v1_20260405.csv"
broad_comparison_table_path <- "tools/merge_reports/LOCAL_validation_campaign_broad_comparison_table_v1_20260405.csv"

model_pair_path <- "tools/merge_reports/LOCAL_validation_campaign_model_pair_comparison_v1_20260405.csv"
model_pair_summary_path <- "tools/merge_reports/LOCAL_validation_campaign_model_pair_summary_v1_20260405.csv"
inference_pair_path <- "tools/merge_reports/LOCAL_validation_campaign_inference_pair_comparison_v1_20260405.csv"
inference_pair_summary_path <- "tools/merge_reports/LOCAL_validation_campaign_inference_pair_summary_v1_20260405.csv"

comparison_long <- read.csv(comparison_long_path, check.names = FALSE, stringsAsFactors = FALSE)

write.csv(vc_group_gate_summary_20260405(comparison_long, "model"), summary_by_model_path, row.names = FALSE, na = "")
write.csv(vc_group_gate_summary_20260405(comparison_long, "inference"), summary_by_inference_path, row.names = FALSE, na = "")
write.csv(vc_group_gate_summary_20260405(comparison_long, "root_kind"), summary_by_root_kind_path, row.names = FALSE, na = "")
write.csv(vc_group_gate_summary_20260405(comparison_long, "family"), summary_by_family_path, row.names = FALSE, na = "")
write.csv(vc_group_gate_summary_20260405(comparison_long, "tau_label"), summary_by_tau_path, row.names = FALSE, na = "")
write.csv(
  vc_group_gate_summary_20260405(comparison_long, c("root_kind", "inference", "model")),
  summary_by_method_path,
  row.names = FALSE,
  na = ""
)
write.csv(
  vc_group_gate_summary_20260405(subset(comparison_long, prior_semantics != ""), "prior_semantics"),
  summary_by_prior_path,
  row.names = FALSE,
  na = ""
)

mcmc_metrics <- c(
  "ess_sigma_per1k", "ess_gamma_per1k", "acf1_sigma", "acf1_gamma",
  "geweke_sigma", "geweke_gamma", "half_drift_sigma",
  "half_drift_gamma", "accept_keep", "runtime_sec"
)
vb_metrics <- c(
  "vb_trace_length", "vb_elbo_tail_rel_range", "vb_elbo_tail_rel_drift",
  "vb_sigma_tail_rel_range", "vb_gamma_tail_rel_range",
  "vb_ld_candidate_local_pass_rate_tail", "vb_ld_stabilized_rate_tail",
  "runtime_sec"
)

mcmc_diag <- vc_group_numeric_summary_20260405(
  subset(comparison_long, inference == "mcmc"),
  c("root_kind", "model"),
  mcmc_metrics
)
if (nrow(mcmc_diag)) {
  mcmc_subset <- subset(comparison_long, inference == "mcmc")
  parts <- split(mcmc_subset, interaction(mcmc_subset[c("root_kind", "model")], drop = TRUE, lex.order = TRUE))
  mcmc_rates <- do.call(rbind, lapply(parts, function(chunk) {
    data.frame(
      root_kind = chunk$root_kind[1],
      model = chunk$model[1],
      healthy_rate = round(100 * mean(vc_truthy_20260405(chunk$healthy), na.rm = TRUE), 1),
      stringsAsFactors = FALSE
    )
  }))
  mcmc_diag <- merge(mcmc_diag, mcmc_rates, by = c("root_kind", "model"), all.x = TRUE, sort = FALSE)
}
write.csv(mcmc_diag, mcmc_diag_path, row.names = FALSE, na = "")

vb_diag <- vc_group_numeric_summary_20260405(
  subset(comparison_long, inference == "vb"),
  c("root_kind", "model"),
  vb_metrics
)
if (nrow(vb_diag)) {
  vb_subset <- subset(comparison_long, inference == "vb")
  parts <- split(vb_subset, interaction(vb_subset[c("root_kind", "model")], drop = TRUE, lex.order = TRUE))
  vb_conv <- lapply(parts, function(chunk) {
    base <- chunk[1, c("root_kind", "model"), drop = FALSE]
    data.frame(
      base,
      vb_converged_rate = round(100 * mean(vc_truthy_20260405(chunk$vb_converged), na.rm = TRUE), 1),
      vb_ld_local_mode_pass_rate = round(100 * mean(vc_truthy_20260405(chunk$vb_ld_local_mode_pass), na.rm = TRUE), 1),
      vb_ld_committed_stable_tail_rate = round(100 * mean(vc_truthy_20260405(chunk$vb_ld_committed_stable_tail), na.rm = TRUE), 1),
      stringsAsFactors = FALSE
    )
  })
  vb_conv <- do.call(rbind, vb_conv)
  vb_diag <- merge(vb_diag, vb_conv, by = c("root_kind", "model"), all.x = TRUE, sort = FALSE)
}
write.csv(vb_diag, vb_diag_path, row.names = FALSE, na = "")

static <- subset(comparison_long, root_kind != "dynamic")
static_id <- c("scenario_key", "run_root_rel", "scope_label", "root_kind", "family", "tau_label", "fit_size", "prior_semantics")
static_wide <- reshape(
  static[, c(static_id, "method_id", "gate_overall", "runtime_sec", "selected_pool", "selected_candidate"), drop = FALSE],
  idvar = static_id,
  timevar = "method_id",
  direction = "wide"
)
static_wide <- static_wide[order(
  static_wide$root_kind,
  static_wide$family,
  static_wide$tau_label,
  static_wide$fit_size,
  static_wide$prior_semantics,
  static_wide$scope_label
), ]
write.csv(static_wide, static_broad_path, row.names = FALSE, na = "")

dynamic <- subset(comparison_long, root_kind == "dynamic")
dynamic_out <- dynamic[, c(
  "case_key", "scenario_key", "run_root_rel", "family", "tau_label", "fit_size",
  "inference", "model", "selected_pool", "selected_candidate",
  "gate_overall", "runtime_sec", "signoff_reason", "selection_reason"
)]
dynamic_out <- dynamic_out[order(dynamic_out$family, dynamic_out$tau_label, dynamic_out$fit_size), ]
write.csv(dynamic_out, dynamic_broad_path, row.names = FALSE, na = "")

broad_comparison_table <- comparison_long[, c(
  "case_key", "scenario_key", "run_root_rel", "scope_label", "root_kind",
  "family", "tau_label", "fit_size", "prior_semantics", "inference", "model",
  "selected_pool", "selected_candidate", "selected_variant_tag",
  "gate_overall", "healthy", "runtime_sec", "diagnostic_source_type",
  "signoff_reason", "selection_reason"
)]
broad_comparison_table <- broad_comparison_table[order(
  broad_comparison_table$root_kind,
  broad_comparison_table$run_root_rel,
  broad_comparison_table$inference,
  broad_comparison_table$model
), ]
write.csv(broad_comparison_table, broad_comparison_table_path, row.names = FALSE, na = "")

model_pair <- reshape(
  static[, c(static_id, "inference", "model", "gate_overall", "gate_rank_num", "runtime_sec", "selected_pool", "selected_candidate"), drop = FALSE],
  idvar = c(static_id, "inference"),
  timevar = "model",
  direction = "wide"
)
model_pair <- subset(model_pair, !is.na(gate_overall.al) & !is.na(gate_overall.exal))
model_pair$gate_delta_exal_minus_al <- model_pair$gate_rank_num.al - model_pair$gate_rank_num.exal
model_pair$gate_comparison <- ifelse(
  model_pair$gate_delta_exal_minus_al > 0, "exal_better",
  ifelse(model_pair$gate_delta_exal_minus_al < 0, "al_better", "tie")
)
model_pair$runtime_ratio_exal_over_al <- round(model_pair$runtime_sec.exal / model_pair$runtime_sec.al, 6)
model_pair$faster_method <- ifelse(
  model_pair$runtime_sec.exal < model_pair$runtime_sec.al, "exal",
  ifelse(model_pair$runtime_sec.exal > model_pair$runtime_sec.al, "al", "tie")
)
model_pair <- model_pair[order(
  model_pair$root_kind,
  model_pair$family,
  model_pair$tau_label,
  model_pair$fit_size,
  model_pair$prior_semantics,
  model_pair$scope_label,
  model_pair$inference
), ]
write.csv(model_pair, model_pair_path, row.names = FALSE, na = "")

model_pair_summary_parts <- list(
  data.frame(
    root_kind = "overall",
    inference = "all",
    total_pairs = nrow(model_pair),
    exal_better = sum(model_pair$gate_comparison == "exal_better"),
    al_better = sum(model_pair$gate_comparison == "al_better"),
    tie = sum(model_pair$gate_comparison == "tie"),
    exal_faster = sum(model_pair$faster_method == "exal"),
    al_faster = sum(model_pair$faster_method == "al"),
    median_runtime_ratio_exal_over_al = round(stats::median(model_pair$runtime_ratio_exal_over_al, na.rm = TRUE), 6),
    stringsAsFactors = FALSE
  )
)
parts <- split(model_pair, interaction(model_pair[c("root_kind", "inference")], drop = TRUE, lex.order = TRUE))
model_pair_summary_parts <- c(model_pair_summary_parts, lapply(parts, function(chunk) {
  data.frame(
    root_kind = chunk$root_kind[1],
    inference = chunk$inference[1],
    total_pairs = nrow(chunk),
    exal_better = sum(chunk$gate_comparison == "exal_better"),
    al_better = sum(chunk$gate_comparison == "al_better"),
    tie = sum(chunk$gate_comparison == "tie"),
    exal_faster = sum(chunk$faster_method == "exal"),
    al_faster = sum(chunk$faster_method == "al"),
    median_runtime_ratio_exal_over_al = round(stats::median(chunk$runtime_ratio_exal_over_al, na.rm = TRUE), 6),
    stringsAsFactors = FALSE
  )
}))
model_pair_summary <- do.call(rbind, model_pair_summary_parts)
write.csv(model_pair_summary, model_pair_summary_path, row.names = FALSE, na = "")

inference_pair <- reshape(
  static[, c(static_id, "model", "inference", "gate_overall", "gate_rank_num", "runtime_sec", "selected_pool", "selected_candidate"), drop = FALSE],
  idvar = c(static_id, "model"),
  timevar = "inference",
  direction = "wide"
)
inference_pair <- subset(inference_pair, !is.na(gate_overall.vb) & !is.na(gate_overall.mcmc))
inference_pair$gate_delta_mcmc_minus_vb <- inference_pair$gate_rank_num.vb - inference_pair$gate_rank_num.mcmc
inference_pair$gate_comparison <- ifelse(
  inference_pair$gate_delta_mcmc_minus_vb > 0, "mcmc_better",
  ifelse(inference_pair$gate_delta_mcmc_minus_vb < 0, "vb_better", "tie")
)
inference_pair$runtime_ratio_mcmc_over_vb <- round(inference_pair$runtime_sec.mcmc / inference_pair$runtime_sec.vb, 6)
inference_pair$faster_method <- ifelse(
  inference_pair$runtime_sec.mcmc < inference_pair$runtime_sec.vb, "mcmc",
  ifelse(inference_pair$runtime_sec.mcmc > inference_pair$runtime_sec.vb, "vb", "tie")
)
inference_pair <- inference_pair[order(
  inference_pair$root_kind,
  inference_pair$family,
  inference_pair$tau_label,
  inference_pair$fit_size,
  inference_pair$prior_semantics,
  inference_pair$scope_label,
  inference_pair$model
), ]
write.csv(inference_pair, inference_pair_path, row.names = FALSE, na = "")

inference_pair_summary_parts <- list(
  data.frame(
    root_kind = "overall",
    model = "all",
    total_pairs = nrow(inference_pair),
    mcmc_better = sum(inference_pair$gate_comparison == "mcmc_better"),
    vb_better = sum(inference_pair$gate_comparison == "vb_better"),
    tie = sum(inference_pair$gate_comparison == "tie"),
    mcmc_faster = sum(inference_pair$faster_method == "mcmc"),
    vb_faster = sum(inference_pair$faster_method == "vb"),
    median_runtime_ratio_mcmc_over_vb = round(stats::median(inference_pair$runtime_ratio_mcmc_over_vb, na.rm = TRUE), 6),
    stringsAsFactors = FALSE
  )
)
parts <- split(inference_pair, interaction(inference_pair[c("root_kind", "model")], drop = TRUE, lex.order = TRUE))
inference_pair_summary_parts <- c(inference_pair_summary_parts, lapply(parts, function(chunk) {
  data.frame(
    root_kind = chunk$root_kind[1],
    model = chunk$model[1],
    total_pairs = nrow(chunk),
    mcmc_better = sum(chunk$gate_comparison == "mcmc_better"),
    vb_better = sum(chunk$gate_comparison == "vb_better"),
    tie = sum(chunk$gate_comparison == "tie"),
    mcmc_faster = sum(chunk$faster_method == "mcmc"),
    vb_faster = sum(chunk$faster_method == "vb"),
    median_runtime_ratio_mcmc_over_vb = round(stats::median(chunk$runtime_ratio_mcmc_over_vb, na.rm = TRUE), 6),
    stringsAsFactors = FALSE
  )
}))
inference_pair_summary <- do.call(rbind, inference_pair_summary_parts)
write.csv(inference_pair_summary, inference_pair_summary_path, row.names = FALSE, na = "")

cat("Wrote final comparison summary tables and pairwise comparisons.\n")

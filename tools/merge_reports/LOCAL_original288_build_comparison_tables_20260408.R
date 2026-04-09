#!/usr/bin/env Rscript

source("tools/merge_reports/LOCAL_original288_comparison_helpers_20260408.R")

comparison_long_path <- "tools/merge_reports/LOCAL_original288_comparison_long_v1_20260408.csv"

broad_comparison_table_path <- "tools/merge_reports/LOCAL_original288_broad_comparison_table_v1_20260408.csv"
static_scenario_path <- "tools/merge_reports/LOCAL_original288_static_scenario_comparison_v1_20260408.csv"
dynamic_scenario_path <- "tools/merge_reports/LOCAL_original288_dynamic_scenario_comparison_v1_20260408.csv"

summary_by_block_path <- "tools/merge_reports/LOCAL_original288_comparison_summary_by_block_v1_20260408.csv"
summary_by_model_path <- "tools/merge_reports/LOCAL_original288_comparison_summary_by_model_v1_20260408.csv"
summary_by_inference_path <- "tools/merge_reports/LOCAL_original288_comparison_summary_by_inference_v1_20260408.csv"
summary_by_method_path <- "tools/merge_reports/LOCAL_original288_comparison_summary_by_method_v1_20260408.csv"
summary_by_family_path <- "tools/merge_reports/LOCAL_original288_comparison_summary_by_family_v1_20260408.csv"
summary_by_tau_path <- "tools/merge_reports/LOCAL_original288_comparison_summary_by_tau_v1_20260408.csv"
summary_by_prior_path <- "tools/merge_reports/LOCAL_original288_comparison_summary_by_prior_semantics_v1_20260408.csv"

static_model_pair_path <- "tools/merge_reports/LOCAL_original288_static_model_pair_comparison_v1_20260408.csv"
static_model_pair_summary_path <- "tools/merge_reports/LOCAL_original288_static_model_pair_summary_v1_20260408.csv"
static_inference_pair_path <- "tools/merge_reports/LOCAL_original288_static_inference_pair_comparison_v1_20260408.csv"
static_inference_pair_summary_path <- "tools/merge_reports/LOCAL_original288_static_inference_pair_summary_v1_20260408.csv"
dynamic_model_pair_path <- "tools/merge_reports/LOCAL_original288_dynamic_model_pair_comparison_v1_20260408.csv"
dynamic_model_pair_summary_path <- "tools/merge_reports/LOCAL_original288_dynamic_model_pair_summary_v1_20260408.csv"
dynamic_inference_pair_path <- "tools/merge_reports/LOCAL_original288_dynamic_inference_pair_comparison_v1_20260408.csv"
dynamic_inference_pair_summary_path <- "tools/merge_reports/LOCAL_original288_dynamic_inference_pair_summary_v1_20260408.csv"

mcmc_diag_path <- "tools/merge_reports/LOCAL_original288_mcmc_diagnostics_by_method_v1_20260408.csv"
vb_diag_path <- "tools/merge_reports/LOCAL_original288_vb_diagnostics_by_method_v1_20260408.csv"
warn_inventory_path <- "tools/merge_reports/LOCAL_original288_warn_inventory_v1_20260408.csv"
fail_inventory_path <- "tools/merge_reports/LOCAL_original288_fail_inventory_v1_20260408.csv"

comparison_long <- read.csv(comparison_long_path, check.names = FALSE, stringsAsFactors = FALSE)

pair_runtime_ratio <- function(num, den) {
  ifelse(is.na(num) | is.na(den) | den == 0, NA_real_, round(num / den, 6))
}

write.csv(
  o288_group_gate_summary_20260408(comparison_long, "block"),
  summary_by_block_path,
  row.names = FALSE,
  na = ""
)
write.csv(
  o288_group_gate_summary_20260408(comparison_long, "model"),
  summary_by_model_path,
  row.names = FALSE,
  na = ""
)
write.csv(
  o288_group_gate_summary_20260408(comparison_long, "inference"),
  summary_by_inference_path,
  row.names = FALSE,
  na = ""
)
write.csv(
  o288_group_gate_summary_20260408(comparison_long, c("block", "model", "inference")),
  summary_by_method_path,
  row.names = FALSE,
  na = ""
)
write.csv(
  o288_group_gate_summary_20260408(comparison_long, "family"),
  summary_by_family_path,
  row.names = FALSE,
  na = ""
)
write.csv(
  o288_group_gate_summary_20260408(comparison_long, "tau_label"),
  summary_by_tau_path,
  row.names = FALSE,
  na = ""
)
write.csv(
  o288_group_gate_summary_20260408(subset(comparison_long, prior_semantics != ""), "prior_semantics"),
  summary_by_prior_path,
  row.names = FALSE,
  na = ""
)

broad_comparison_table <- comparison_long[, c(
  "case_key", "scenario_key", "scope_label", "block", "root_kind",
  "family", "tau_label", "fit_size", "prior_semantics", "inference", "model",
  "method_id", "selected_pool", "selected_pool_group", "selected_candidate",
  "selected_variant_tag", "selected_source_subtype", "gate_overall", "healthy",
  "runtime_sec", "diagnostic_source_type", "signoff_reason", "selection_reason",
  "selected_fit_path_rel", "selected_health_path_rel", "selected_summary_path_rel"
)]
broad_comparison_table <- broad_comparison_table[order(
  broad_comparison_table$block,
  broad_comparison_table$family,
  broad_comparison_table$tau_label,
  broad_comparison_table$fit_size,
  broad_comparison_table$prior_semantics,
  broad_comparison_table$inference,
  broad_comparison_table$model
), ]
write.csv(broad_comparison_table, broad_comparison_table_path, row.names = FALSE, na = "")

static <- subset(comparison_long, root_kind != "dynamic")
dynamic <- subset(comparison_long, root_kind == "dynamic")

static_id <- c("scenario_key", "scope_label", "block", "root_kind", "family", "tau_label", "fit_size", "prior_semantics")
dynamic_id <- c("scenario_key", "scope_label", "block", "root_kind", "family", "tau_label", "fit_size", "prior_semantics")

static_wide <- reshape(
  static[, c(static_id, "method_id", "gate_overall", "healthy", "runtime_sec", "selected_pool", "selected_candidate"), drop = FALSE],
  idvar = static_id,
  timevar = "method_id",
  direction = "wide"
)
static_wide <- static_wide[order(
  static_wide$block,
  static_wide$family,
  static_wide$tau_label,
  static_wide$fit_size,
  static_wide$prior_semantics
), ]
write.csv(static_wide, static_scenario_path, row.names = FALSE, na = "")

dynamic_wide <- reshape(
  dynamic[, c(dynamic_id, "method_id", "gate_overall", "healthy", "runtime_sec", "selected_pool", "selected_candidate"), drop = FALSE],
  idvar = dynamic_id,
  timevar = "method_id",
  direction = "wide"
)
dynamic_wide <- dynamic_wide[order(
  dynamic_wide$family,
  dynamic_wide$tau_label,
  dynamic_wide$fit_size
), ]
write.csv(dynamic_wide, dynamic_scenario_path, row.names = FALSE, na = "")

static_model_pair <- reshape(
  static[, c(static_id, "inference", "model", "gate_overall", "healthy", "gate_rank_num", "runtime_sec", "selected_pool", "selected_candidate"), drop = FALSE],
  idvar = c(static_id, "inference"),
  timevar = "model",
  direction = "wide"
)
static_model_pair <- subset(static_model_pair, !is.na(gate_overall.al) & !is.na(gate_overall.exal))
static_model_pair$gate_delta_exal_minus_al <- static_model_pair$gate_rank_num.al - static_model_pair$gate_rank_num.exal
static_model_pair$gate_comparison <- ifelse(
  static_model_pair$gate_delta_exal_minus_al > 0, "exal_better",
  ifelse(static_model_pair$gate_delta_exal_minus_al < 0, "al_better", "tie")
)
static_model_pair$runtime_ratio_exal_over_al <- pair_runtime_ratio(static_model_pair$runtime_sec.exal, static_model_pair$runtime_sec.al)
static_model_pair$faster_method <- ifelse(
  is.na(static_model_pair$runtime_sec.exal) | is.na(static_model_pair$runtime_sec.al), NA_character_,
  ifelse(static_model_pair$runtime_sec.exal < static_model_pair$runtime_sec.al, "exal",
    ifelse(static_model_pair$runtime_sec.exal > static_model_pair$runtime_sec.al, "al", "tie")
  )
)
write.csv(static_model_pair, static_model_pair_path, row.names = FALSE, na = "")

static_model_pair_summary <- do.call(rbind, c(
  list(data.frame(
    block = "overall",
    inference = "all",
    total_pairs = nrow(static_model_pair),
    exal_better = sum(static_model_pair$gate_comparison == "exal_better", na.rm = TRUE),
    al_better = sum(static_model_pair$gate_comparison == "al_better", na.rm = TRUE),
    tie = sum(static_model_pair$gate_comparison == "tie", na.rm = TRUE),
    exal_faster = sum(static_model_pair$faster_method == "exal", na.rm = TRUE),
    al_faster = sum(static_model_pair$faster_method == "al", na.rm = TRUE),
    median_runtime_ratio_exal_over_al = round(stats::median(static_model_pair$runtime_ratio_exal_over_al, na.rm = TRUE), 6),
    stringsAsFactors = FALSE
  )),
  lapply(split(static_model_pair, interaction(static_model_pair[c("block", "inference")], drop = TRUE, lex.order = TRUE)), function(chunk) {
    data.frame(
      block = chunk$block[1],
      inference = chunk$inference[1],
      total_pairs = nrow(chunk),
      exal_better = sum(chunk$gate_comparison == "exal_better", na.rm = TRUE),
      al_better = sum(chunk$gate_comparison == "al_better", na.rm = TRUE),
      tie = sum(chunk$gate_comparison == "tie", na.rm = TRUE),
      exal_faster = sum(chunk$faster_method == "exal", na.rm = TRUE),
      al_faster = sum(chunk$faster_method == "al", na.rm = TRUE),
      median_runtime_ratio_exal_over_al = round(stats::median(chunk$runtime_ratio_exal_over_al, na.rm = TRUE), 6),
      stringsAsFactors = FALSE
    )
  })
))
write.csv(static_model_pair_summary, static_model_pair_summary_path, row.names = FALSE, na = "")

static_inference_pair <- reshape(
  static[, c(static_id, "model", "inference", "gate_overall", "healthy", "gate_rank_num", "runtime_sec", "selected_pool", "selected_candidate"), drop = FALSE],
  idvar = c(static_id, "model"),
  timevar = "inference",
  direction = "wide"
)
static_inference_pair <- subset(static_inference_pair, !is.na(gate_overall.vb) & !is.na(gate_overall.mcmc))
static_inference_pair$gate_delta_mcmc_minus_vb <- static_inference_pair$gate_rank_num.vb - static_inference_pair$gate_rank_num.mcmc
static_inference_pair$gate_comparison <- ifelse(
  static_inference_pair$gate_delta_mcmc_minus_vb > 0, "mcmc_better",
  ifelse(static_inference_pair$gate_delta_mcmc_minus_vb < 0, "vb_better", "tie")
)
static_inference_pair$runtime_ratio_mcmc_over_vb <- pair_runtime_ratio(static_inference_pair$runtime_sec.mcmc, static_inference_pair$runtime_sec.vb)
static_inference_pair$faster_method <- ifelse(
  is.na(static_inference_pair$runtime_sec.mcmc) | is.na(static_inference_pair$runtime_sec.vb), NA_character_,
  ifelse(static_inference_pair$runtime_sec.mcmc < static_inference_pair$runtime_sec.vb, "mcmc",
    ifelse(static_inference_pair$runtime_sec.mcmc > static_inference_pair$runtime_sec.vb, "vb", "tie")
  )
)
write.csv(static_inference_pair, static_inference_pair_path, row.names = FALSE, na = "")

static_inference_pair_summary <- do.call(rbind, c(
  list(data.frame(
    block = "overall",
    model = "all",
    total_pairs = nrow(static_inference_pair),
    mcmc_better = sum(static_inference_pair$gate_comparison == "mcmc_better", na.rm = TRUE),
    vb_better = sum(static_inference_pair$gate_comparison == "vb_better", na.rm = TRUE),
    tie = sum(static_inference_pair$gate_comparison == "tie", na.rm = TRUE),
    mcmc_faster = sum(static_inference_pair$faster_method == "mcmc", na.rm = TRUE),
    vb_faster = sum(static_inference_pair$faster_method == "vb", na.rm = TRUE),
    median_runtime_ratio_mcmc_over_vb = round(stats::median(static_inference_pair$runtime_ratio_mcmc_over_vb, na.rm = TRUE), 6),
    stringsAsFactors = FALSE
  )),
  lapply(split(static_inference_pair, interaction(static_inference_pair[c("block", "model")], drop = TRUE, lex.order = TRUE)), function(chunk) {
    data.frame(
      block = chunk$block[1],
      model = chunk$model[1],
      total_pairs = nrow(chunk),
      mcmc_better = sum(chunk$gate_comparison == "mcmc_better", na.rm = TRUE),
      vb_better = sum(chunk$gate_comparison == "vb_better", na.rm = TRUE),
      tie = sum(chunk$gate_comparison == "tie", na.rm = TRUE),
      mcmc_faster = sum(chunk$faster_method == "mcmc", na.rm = TRUE),
      vb_faster = sum(chunk$faster_method == "vb", na.rm = TRUE),
      median_runtime_ratio_mcmc_over_vb = round(stats::median(chunk$runtime_ratio_mcmc_over_vb, na.rm = TRUE), 6),
      stringsAsFactors = FALSE
    )
  })
))
write.csv(static_inference_pair_summary, static_inference_pair_summary_path, row.names = FALSE, na = "")

dynamic_model_pair <- reshape(
  dynamic[, c(dynamic_id, "inference", "model", "gate_overall", "healthy", "gate_rank_num", "runtime_sec", "selected_pool", "selected_candidate"), drop = FALSE],
  idvar = c(dynamic_id, "inference"),
  timevar = "model",
  direction = "wide"
)
dynamic_model_pair <- subset(dynamic_model_pair, !is.na(gate_overall.dqlm) & !is.na(gate_overall.exdqlm))
dynamic_model_pair$gate_delta_exdqlm_minus_dqlm <- dynamic_model_pair$gate_rank_num.dqlm - dynamic_model_pair$gate_rank_num.exdqlm
dynamic_model_pair$gate_comparison <- ifelse(
  dynamic_model_pair$gate_delta_exdqlm_minus_dqlm > 0, "exdqlm_better",
  ifelse(dynamic_model_pair$gate_delta_exdqlm_minus_dqlm < 0, "dqlm_better", "tie")
)
dynamic_model_pair$runtime_ratio_exdqlm_over_dqlm <- pair_runtime_ratio(dynamic_model_pair$runtime_sec.exdqlm, dynamic_model_pair$runtime_sec.dqlm)
dynamic_model_pair$faster_method <- ifelse(
  is.na(dynamic_model_pair$runtime_sec.exdqlm) | is.na(dynamic_model_pair$runtime_sec.dqlm), NA_character_,
  ifelse(dynamic_model_pair$runtime_sec.exdqlm < dynamic_model_pair$runtime_sec.dqlm, "exdqlm",
    ifelse(dynamic_model_pair$runtime_sec.exdqlm > dynamic_model_pair$runtime_sec.dqlm, "dqlm", "tie")
  )
)
write.csv(dynamic_model_pair, dynamic_model_pair_path, row.names = FALSE, na = "")

dynamic_model_pair_summary <- do.call(rbind, c(
  list(data.frame(
    block = "overall",
    inference = "all",
    total_pairs = nrow(dynamic_model_pair),
    exdqlm_better = sum(dynamic_model_pair$gate_comparison == "exdqlm_better", na.rm = TRUE),
    dqlm_better = sum(dynamic_model_pair$gate_comparison == "dqlm_better", na.rm = TRUE),
    tie = sum(dynamic_model_pair$gate_comparison == "tie", na.rm = TRUE),
    exdqlm_faster = sum(dynamic_model_pair$faster_method == "exdqlm", na.rm = TRUE),
    dqlm_faster = sum(dynamic_model_pair$faster_method == "dqlm", na.rm = TRUE),
    median_runtime_ratio_exdqlm_over_dqlm = round(stats::median(dynamic_model_pair$runtime_ratio_exdqlm_over_dqlm, na.rm = TRUE), 6),
    stringsAsFactors = FALSE
  )),
  lapply(split(dynamic_model_pair, dynamic_model_pair$inference, drop = TRUE), function(chunk) {
    data.frame(
      block = "dynamic",
      inference = chunk$inference[1],
      total_pairs = nrow(chunk),
      exdqlm_better = sum(chunk$gate_comparison == "exdqlm_better", na.rm = TRUE),
      dqlm_better = sum(chunk$gate_comparison == "dqlm_better", na.rm = TRUE),
      tie = sum(chunk$gate_comparison == "tie", na.rm = TRUE),
      exdqlm_faster = sum(chunk$faster_method == "exdqlm", na.rm = TRUE),
      dqlm_faster = sum(chunk$faster_method == "dqlm", na.rm = TRUE),
      median_runtime_ratio_exdqlm_over_dqlm = round(stats::median(chunk$runtime_ratio_exdqlm_over_dqlm, na.rm = TRUE), 6),
      stringsAsFactors = FALSE
    )
  })
))
write.csv(dynamic_model_pair_summary, dynamic_model_pair_summary_path, row.names = FALSE, na = "")

dynamic_inference_pair <- reshape(
  dynamic[, c(dynamic_id, "model", "inference", "gate_overall", "healthy", "gate_rank_num", "runtime_sec", "selected_pool", "selected_candidate"), drop = FALSE],
  idvar = c(dynamic_id, "model"),
  timevar = "inference",
  direction = "wide"
)
dynamic_inference_pair <- subset(dynamic_inference_pair, !is.na(gate_overall.vb) & !is.na(gate_overall.mcmc))
dynamic_inference_pair$gate_delta_mcmc_minus_vb <- dynamic_inference_pair$gate_rank_num.vb - dynamic_inference_pair$gate_rank_num.mcmc
dynamic_inference_pair$gate_comparison <- ifelse(
  dynamic_inference_pair$gate_delta_mcmc_minus_vb > 0, "mcmc_better",
  ifelse(dynamic_inference_pair$gate_delta_mcmc_minus_vb < 0, "vb_better", "tie")
)
dynamic_inference_pair$runtime_ratio_mcmc_over_vb <- pair_runtime_ratio(dynamic_inference_pair$runtime_sec.mcmc, dynamic_inference_pair$runtime_sec.vb)
dynamic_inference_pair$faster_method <- ifelse(
  is.na(dynamic_inference_pair$runtime_sec.mcmc) | is.na(dynamic_inference_pair$runtime_sec.vb), NA_character_,
  ifelse(dynamic_inference_pair$runtime_sec.mcmc < dynamic_inference_pair$runtime_sec.vb, "mcmc",
    ifelse(dynamic_inference_pair$runtime_sec.mcmc > dynamic_inference_pair$runtime_sec.vb, "vb", "tie")
  )
)
write.csv(dynamic_inference_pair, dynamic_inference_pair_path, row.names = FALSE, na = "")

dynamic_inference_pair_summary <- do.call(rbind, c(
  list(data.frame(
    block = "overall",
    model = "all",
    total_pairs = nrow(dynamic_inference_pair),
    mcmc_better = sum(dynamic_inference_pair$gate_comparison == "mcmc_better", na.rm = TRUE),
    vb_better = sum(dynamic_inference_pair$gate_comparison == "vb_better", na.rm = TRUE),
    tie = sum(dynamic_inference_pair$gate_comparison == "tie", na.rm = TRUE),
    mcmc_faster = sum(dynamic_inference_pair$faster_method == "mcmc", na.rm = TRUE),
    vb_faster = sum(dynamic_inference_pair$faster_method == "vb", na.rm = TRUE),
    median_runtime_ratio_mcmc_over_vb = round(stats::median(dynamic_inference_pair$runtime_ratio_mcmc_over_vb, na.rm = TRUE), 6),
    stringsAsFactors = FALSE
  )),
  lapply(split(dynamic_inference_pair, dynamic_inference_pair$model, drop = TRUE), function(chunk) {
    data.frame(
      block = "dynamic",
      model = chunk$model[1],
      total_pairs = nrow(chunk),
      mcmc_better = sum(chunk$gate_comparison == "mcmc_better", na.rm = TRUE),
      vb_better = sum(chunk$gate_comparison == "vb_better", na.rm = TRUE),
      tie = sum(chunk$gate_comparison == "tie", na.rm = TRUE),
      mcmc_faster = sum(chunk$faster_method == "mcmc", na.rm = TRUE),
      vb_faster = sum(chunk$faster_method == "vb", na.rm = TRUE),
      median_runtime_ratio_mcmc_over_vb = round(stats::median(chunk$runtime_ratio_mcmc_over_vb, na.rm = TRUE), 6),
      stringsAsFactors = FALSE
    )
  })
))
write.csv(dynamic_inference_pair_summary, dynamic_inference_pair_summary_path, row.names = FALSE, na = "")

mcmc_metrics <- c(
  "runtime_sec", "n_keep", "n_burn", "n_mcmc", "ess_sigma", "ess_gamma",
  "ess_sigma_per1k", "ess_gamma_per1k", "acf1_sigma", "acf1_gamma",
  "geweke_sigma", "geweke_gamma", "half_drift_sigma", "half_drift_gamma",
  "accept_keep", "accept_burn", "accept_overall"
)
vb_metrics <- c(
  "runtime_sec", "vb_trace_length", "vb_elbo_tail_rel_range",
  "vb_elbo_tail_rel_drift", "vb_sigma_tail_rel_range", "vb_gamma_tail_rel_range",
  "vb_s_tail_rel_range", "vb_delta_state_last", "vb_delta_sigma_last",
  "vb_delta_gamma_last", "vb_delta_s_last", "vb_ld_trace_rows",
  "vb_ld_candidate_local_pass_rate_tail", "vb_ld_committed_local_pass_rate_tail",
  "vb_ld_mode_fallback_rate", "vb_ld_stabilized_rate_tail"
)

mcmc_diag <- o288_group_numeric_summary_20260408(
  subset(comparison_long, inference == "mcmc"),
  c("block", "model", "inference"),
  mcmc_metrics
)
if (nrow(mcmc_diag)) {
  mcmc_subset <- subset(comparison_long, inference == "mcmc")
  mcmc_rates <- do.call(rbind, lapply(split(mcmc_subset, interaction(mcmc_subset[c("block", "model", "inference")], drop = TRUE, lex.order = TRUE)), function(chunk) {
    data.frame(
      block = chunk$block[1],
      model = chunk$model[1],
      inference = chunk$inference[1],
      healthy_rate = round(100 * mean(o288_truthy_20260408(chunk$healthy), na.rm = TRUE), 1),
      pass_rate = round(100 * mean(chunk$gate_overall == "PASS", na.rm = TRUE), 1),
      warn_rate = round(100 * mean(chunk$gate_overall == "WARN", na.rm = TRUE), 1),
      fail_rate = round(100 * mean(chunk$gate_overall == "FAIL", na.rm = TRUE), 1),
      stringsAsFactors = FALSE
    )
  }))
  mcmc_diag <- merge(mcmc_diag, mcmc_rates, by = c("block", "model", "inference"), all.x = TRUE, sort = FALSE)
}
write.csv(mcmc_diag, mcmc_diag_path, row.names = FALSE, na = "")

vb_diag <- o288_group_numeric_summary_20260408(
  subset(comparison_long, inference == "vb"),
  c("block", "model", "inference"),
  vb_metrics
)
if (nrow(vb_diag)) {
  vb_subset <- subset(comparison_long, inference == "vb")
  vb_rates <- do.call(rbind, lapply(split(vb_subset, interaction(vb_subset[c("block", "model", "inference")], drop = TRUE, lex.order = TRUE)), function(chunk) {
    data.frame(
      block = chunk$block[1],
      model = chunk$model[1],
      inference = chunk$inference[1],
      healthy_rate = round(100 * mean(o288_truthy_20260408(chunk$healthy), na.rm = TRUE), 1),
      vb_converged_rate = round(100 * mean(o288_truthy_20260408(chunk$vb_converged), na.rm = TRUE), 1),
      vb_ld_local_mode_pass_rate = round(100 * mean(o288_truthy_20260408(chunk$vb_ld_local_mode_pass), na.rm = TRUE), 1),
      vb_ld_committed_stable_tail_rate = round(100 * mean(o288_truthy_20260408(chunk$vb_ld_committed_stable_tail), na.rm = TRUE), 1),
      stringsAsFactors = FALSE
    )
  }))
  vb_diag <- merge(vb_diag, vb_rates, by = c("block", "model", "inference"), all.x = TRUE, sort = FALSE)
}
write.csv(vb_diag, vb_diag_path, row.names = FALSE, na = "")

warn_inventory <- subset(comparison_long, gate_overall == "WARN", select = c(
  "case_key", "scenario_key", "block", "root_kind", "family", "tau_label",
  "fit_size", "prior_semantics", "inference", "model", "method_id",
  "selected_pool", "selected_candidate", "selected_variant_tag",
  "gate_overall", "healthy", "runtime_sec", "diagnostic_source_type",
  "signoff_reason", "selection_reason", "selected_health_path_rel"
))
warn_inventory <- warn_inventory[order(
  warn_inventory$block,
  warn_inventory$family,
  warn_inventory$tau_label,
  warn_inventory$fit_size,
  warn_inventory$prior_semantics,
  warn_inventory$inference,
  warn_inventory$model
), ]
write.csv(warn_inventory, warn_inventory_path, row.names = FALSE, na = "")

fail_inventory <- subset(comparison_long, gate_overall == "FAIL", select = c(
  "case_key", "scenario_key", "block", "root_kind", "family", "tau_label",
  "fit_size", "prior_semantics", "inference", "model", "method_id",
  "selected_pool", "selected_candidate", "selected_variant_tag",
  "gate_overall", "healthy", "runtime_sec", "diagnostic_source_type",
  "signoff_reason", "selection_reason", "selected_health_path_rel"
))
fail_inventory <- fail_inventory[order(
  fail_inventory$block,
  fail_inventory$family,
  fail_inventory$tau_label,
  fail_inventory$fit_size,
  fail_inventory$prior_semantics,
  fail_inventory$inference,
  fail_inventory$model
), ]
write.csv(fail_inventory, fail_inventory_path, row.names = FALSE, na = "")

cat("Wrote original288 comparison summary tables, pairwise tables, and inventories.\n")

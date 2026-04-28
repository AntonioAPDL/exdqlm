#!/usr/bin/env Rscript

source("tools/merge_reports/LOCAL_refreshed288_comparison_helpers_20260427.R")

comparison_long_path <- rf288_output_path_20260427("comparison_long")

broad_comparison_table_path <- rf288_output_path_20260427("broad_comparison_table")
static_scenario_path <- rf288_output_path_20260427("static_scenario_comparison")
dynamic_scenario_path <- rf288_output_path_20260427("dynamic_scenario_comparison")

summary_by_block_path <- rf288_output_path_20260427("comparison_summary_by_block")
summary_by_model_path <- rf288_output_path_20260427("comparison_summary_by_model")
summary_by_inference_path <- rf288_output_path_20260427("comparison_summary_by_inference")
summary_by_method_path <- rf288_output_path_20260427("comparison_summary_by_method")
summary_by_family_path <- rf288_output_path_20260427("comparison_summary_by_family")
summary_by_tau_path <- rf288_output_path_20260427("comparison_summary_by_tau")
summary_by_prior_path <- rf288_output_path_20260427("comparison_summary_by_prior_semantics")

static_model_pair_path <- rf288_output_path_20260427("static_model_pair_comparison")
static_model_pair_summary_path <- rf288_output_path_20260427("static_model_pair_summary")
static_inference_pair_path <- rf288_output_path_20260427("static_inference_pair_comparison")
static_inference_pair_summary_path <- rf288_output_path_20260427("static_inference_pair_summary")
dynamic_model_pair_path <- rf288_output_path_20260427("dynamic_model_pair_comparison")
dynamic_model_pair_summary_path <- rf288_output_path_20260427("dynamic_model_pair_summary")
dynamic_inference_pair_path <- rf288_output_path_20260427("dynamic_inference_pair_comparison")
dynamic_inference_pair_summary_path <- rf288_output_path_20260427("dynamic_inference_pair_summary")

mcmc_diag_path <- rf288_output_path_20260427("mcmc_diagnostics_by_method")
vb_diag_path <- rf288_output_path_20260427("vb_diagnostics_by_method")
warn_inventory_path <- rf288_output_path_20260427("warn_inventory")
fail_inventory_path <- rf288_output_path_20260427("fail_inventory")

comparison_long <- rf288_read_csv_20260427(comparison_long_path)

rf288_write_csv_20260427(
  rf288_group_gate_summary_20260427(comparison_long, "block"),
  summary_by_block_path
)
rf288_write_csv_20260427(
  rf288_group_gate_summary_20260427(comparison_long, "model"),
  summary_by_model_path
)
rf288_write_csv_20260427(
  rf288_group_gate_summary_20260427(comparison_long, "inference"),
  summary_by_inference_path
)
rf288_write_csv_20260427(
  rf288_group_gate_summary_20260427(comparison_long, c("block", "model", "inference")),
  summary_by_method_path
)
rf288_write_csv_20260427(
  rf288_group_gate_summary_20260427(comparison_long, "family"),
  summary_by_family_path
)
rf288_write_csv_20260427(
  rf288_group_gate_summary_20260427(comparison_long, "tau_label"),
  summary_by_tau_path
)
rf288_write_csv_20260427(
  rf288_group_gate_summary_20260427(comparison_long, "prior_semantics"),
  summary_by_prior_path
)

broad_cols <- c(
  "row_id",
  "case_key",
  "scenario_key",
  "block",
  "root_kind",
  "family",
  "tau_label",
  "fit_size",
  "prior_semantics",
  "inference",
  "model",
  "method_id",
  "gate_overall",
  "healthy",
  "runtime_sec",
  "crps",
  "primary_accuracy",
  "q_rmse",
  "coverage95",
  "coverage95_gap",
  "mean_ci_width",
  "cie",
  "beta_rmse_mean",
  "beta_coverage_gap",
  "metric_source",
  "metric_error",
  "error_current",
  "health_path",
  "metrics_path",
  "candidate_fit_path"
)
broad_comparison_table <- rf288_ensure_columns_20260427(comparison_long, broad_cols)
broad_comparison_table <- broad_comparison_table[order(
  broad_comparison_table$block,
  broad_comparison_table$root_kind,
  broad_comparison_table$family,
  broad_comparison_table$tau_label,
  broad_comparison_table$fit_size,
  broad_comparison_table$prior_semantics,
  broad_comparison_table$inference,
  broad_comparison_table$model,
  broad_comparison_table$row_id
), ]
rf288_write_csv_20260427(broad_comparison_table, broad_comparison_table_path)

static <- subset(comparison_long, block == "static")
dynamic <- subset(comparison_long, block == "dynamic")

static_id <- c("scenario_key", "block", "root_kind", "family", "tau_label", "fit_size", "prior_semantics")
dynamic_id <- c("scenario_key", "block", "root_kind", "family", "tau_label", "fit_size", "prior_semantics")
wide_value_cols <- c(
  "gate_overall",
  "healthy",
  "runtime_sec",
  "crps",
  "q_rmse",
  "coverage95_gap",
  "mean_ci_width",
  "cie",
  "beta_rmse_mean",
  "beta_coverage_gap"
)

static_wide <- reshape(
  static[, c(static_id, "method_id", wide_value_cols), drop = FALSE],
  idvar = static_id,
  timevar = "method_id",
  direction = "wide"
)
static_wide <- static_wide[order(
  static_wide$block,
  static_wide$root_kind,
  static_wide$family,
  static_wide$tau_label,
  static_wide$fit_size,
  static_wide$prior_semantics
), ]
rf288_write_csv_20260427(static_wide, static_scenario_path)

dynamic_wide <- reshape(
  dynamic[, c(dynamic_id, "method_id", wide_value_cols), drop = FALSE],
  idvar = dynamic_id,
  timevar = "method_id",
  direction = "wide"
)
dynamic_wide <- dynamic_wide[order(
  dynamic_wide$family,
  dynamic_wide$tau_label,
  dynamic_wide$fit_size
), ]
rf288_write_csv_20260427(dynamic_wide, dynamic_scenario_path)

pair_value_cols <- c(
  "gate_overall",
  "healthy",
  "gate_rank_num",
  "runtime_sec",
  "crps",
  "q_rmse",
  "coverage95_gap",
  "mean_ci_width",
  "cie",
  "beta_rmse_mean",
  "beta_coverage_gap"
)

static_model_pair <- reshape(
  static[, c(static_id, "inference", "model", pair_value_cols), drop = FALSE],
  idvar = c(static_id, "inference"),
  timevar = "model",
  direction = "wide"
)
static_model_pair <- subset(static_model_pair, !is.na(gate_overall.al) & !is.na(gate_overall.exal))
static_model_pair$gate_delta_exal_minus_al <- static_model_pair$gate_rank_num.exal - static_model_pair$gate_rank_num.al
static_model_pair$gate_comparison <- rf288_gate_comparison_20260427(
  static_model_pair$gate_rank_num.exal,
  static_model_pair$gate_rank_num.al,
  "exal",
  "al"
)
static_model_pair$runtime_ratio_exal_over_al <- rf288_runtime_ratio_20260427(
  static_model_pair$runtime_sec.exal,
  static_model_pair$runtime_sec.al
)
static_model_pair$faster_method <- rf288_faster_method_20260427(
  static_model_pair$runtime_sec.exal,
  static_model_pair$runtime_sec.al,
  "exal",
  "al"
)
static_model_pair$crps_delta_exal_minus_al <- static_model_pair$crps.exal - static_model_pair$crps.al
static_model_pair$q_rmse_delta_exal_minus_al <- static_model_pair$q_rmse.exal - static_model_pair$q_rmse.al
static_model_pair$coverage95_gap_delta_exal_minus_al <- static_model_pair$coverage95_gap.exal - static_model_pair$coverage95_gap.al
rf288_write_csv_20260427(static_model_pair, static_model_pair_path)
rf288_write_csv_20260427(
  rf288_pair_summary_20260427(
    static_model_pair,
    c("block", "inference"),
    c("exal_better", "al_better", "tie", "missing"),
    c("exal", "al", "tie"),
    "runtime_ratio_exal_over_al"
  ),
  static_model_pair_summary_path
)

static_inference_pair <- reshape(
  static[, c(static_id, "model", "inference", pair_value_cols), drop = FALSE],
  idvar = c(static_id, "model"),
  timevar = "inference",
  direction = "wide"
)
static_inference_pair <- subset(static_inference_pair, !is.na(gate_overall.vb) & !is.na(gate_overall.mcmc))
static_inference_pair$gate_delta_mcmc_minus_vb <- static_inference_pair$gate_rank_num.mcmc - static_inference_pair$gate_rank_num.vb
static_inference_pair$gate_comparison <- rf288_gate_comparison_20260427(
  static_inference_pair$gate_rank_num.mcmc,
  static_inference_pair$gate_rank_num.vb,
  "mcmc",
  "vb"
)
static_inference_pair$runtime_ratio_mcmc_over_vb <- rf288_runtime_ratio_20260427(
  static_inference_pair$runtime_sec.mcmc,
  static_inference_pair$runtime_sec.vb
)
static_inference_pair$faster_method <- rf288_faster_method_20260427(
  static_inference_pair$runtime_sec.mcmc,
  static_inference_pair$runtime_sec.vb,
  "mcmc",
  "vb"
)
static_inference_pair$crps_delta_mcmc_minus_vb <- static_inference_pair$crps.mcmc - static_inference_pair$crps.vb
static_inference_pair$q_rmse_delta_mcmc_minus_vb <- static_inference_pair$q_rmse.mcmc - static_inference_pair$q_rmse.vb
static_inference_pair$coverage95_gap_delta_mcmc_minus_vb <- static_inference_pair$coverage95_gap.mcmc - static_inference_pair$coverage95_gap.vb
rf288_write_csv_20260427(static_inference_pair, static_inference_pair_path)
rf288_write_csv_20260427(
  rf288_pair_summary_20260427(
    static_inference_pair,
    c("block", "model"),
    c("mcmc_better", "vb_better", "tie", "missing"),
    c("mcmc", "vb", "tie"),
    "runtime_ratio_mcmc_over_vb"
  ),
  static_inference_pair_summary_path
)

dynamic_model_pair <- reshape(
  dynamic[, c(dynamic_id, "inference", "model", pair_value_cols), drop = FALSE],
  idvar = c(dynamic_id, "inference"),
  timevar = "model",
  direction = "wide"
)
dynamic_model_pair <- subset(dynamic_model_pair, !is.na(gate_overall.dqlm) & !is.na(gate_overall.exdqlm))
dynamic_model_pair$gate_delta_exdqlm_minus_dqlm <- dynamic_model_pair$gate_rank_num.exdqlm - dynamic_model_pair$gate_rank_num.dqlm
dynamic_model_pair$gate_comparison <- rf288_gate_comparison_20260427(
  dynamic_model_pair$gate_rank_num.exdqlm,
  dynamic_model_pair$gate_rank_num.dqlm,
  "exdqlm",
  "dqlm"
)
dynamic_model_pair$runtime_ratio_exdqlm_over_dqlm <- rf288_runtime_ratio_20260427(
  dynamic_model_pair$runtime_sec.exdqlm,
  dynamic_model_pair$runtime_sec.dqlm
)
dynamic_model_pair$faster_method <- rf288_faster_method_20260427(
  dynamic_model_pair$runtime_sec.exdqlm,
  dynamic_model_pair$runtime_sec.dqlm,
  "exdqlm",
  "dqlm"
)
dynamic_model_pair$crps_delta_exdqlm_minus_dqlm <- dynamic_model_pair$crps.exdqlm - dynamic_model_pair$crps.dqlm
dynamic_model_pair$q_rmse_delta_exdqlm_minus_dqlm <- dynamic_model_pair$q_rmse.exdqlm - dynamic_model_pair$q_rmse.dqlm
dynamic_model_pair$coverage95_gap_delta_exdqlm_minus_dqlm <- dynamic_model_pair$coverage95_gap.exdqlm - dynamic_model_pair$coverage95_gap.dqlm
rf288_write_csv_20260427(dynamic_model_pair, dynamic_model_pair_path)
rf288_write_csv_20260427(
  rf288_pair_summary_20260427(
    dynamic_model_pair,
    c("block", "inference"),
    c("exdqlm_better", "dqlm_better", "tie", "missing"),
    c("exdqlm", "dqlm", "tie"),
    "runtime_ratio_exdqlm_over_dqlm"
  ),
  dynamic_model_pair_summary_path
)

dynamic_inference_pair <- reshape(
  dynamic[, c(dynamic_id, "model", "inference", pair_value_cols), drop = FALSE],
  idvar = c(dynamic_id, "model"),
  timevar = "inference",
  direction = "wide"
)
dynamic_inference_pair <- subset(dynamic_inference_pair, !is.na(gate_overall.vb) & !is.na(gate_overall.mcmc))
dynamic_inference_pair$gate_delta_mcmc_minus_vb <- dynamic_inference_pair$gate_rank_num.mcmc - dynamic_inference_pair$gate_rank_num.vb
dynamic_inference_pair$gate_comparison <- rf288_gate_comparison_20260427(
  dynamic_inference_pair$gate_rank_num.mcmc,
  dynamic_inference_pair$gate_rank_num.vb,
  "mcmc",
  "vb"
)
dynamic_inference_pair$runtime_ratio_mcmc_over_vb <- rf288_runtime_ratio_20260427(
  dynamic_inference_pair$runtime_sec.mcmc,
  dynamic_inference_pair$runtime_sec.vb
)
dynamic_inference_pair$faster_method <- rf288_faster_method_20260427(
  dynamic_inference_pair$runtime_sec.mcmc,
  dynamic_inference_pair$runtime_sec.vb,
  "mcmc",
  "vb"
)
dynamic_inference_pair$crps_delta_mcmc_minus_vb <- dynamic_inference_pair$crps.mcmc - dynamic_inference_pair$crps.vb
dynamic_inference_pair$q_rmse_delta_mcmc_minus_vb <- dynamic_inference_pair$q_rmse.mcmc - dynamic_inference_pair$q_rmse.vb
dynamic_inference_pair$coverage95_gap_delta_mcmc_minus_vb <- dynamic_inference_pair$coverage95_gap.mcmc - dynamic_inference_pair$coverage95_gap.vb
rf288_write_csv_20260427(dynamic_inference_pair, dynamic_inference_pair_path)
rf288_write_csv_20260427(
  rf288_pair_summary_20260427(
    dynamic_inference_pair,
    c("block", "model"),
    c("mcmc_better", "vb_better", "tie", "missing"),
    c("mcmc", "vb", "tie"),
    "runtime_ratio_mcmc_over_vb"
  ),
  dynamic_inference_pair_summary_path
)

diag_metrics <- c("runtime_sec", rf288_metric_cols_20260427())

mcmc_gate <- rf288_group_gate_summary_20260427(
  subset(comparison_long, inference == "mcmc"),
  c("block", "model", "inference")
)
mcmc_numeric <- rf288_group_numeric_summary_20260427(
  subset(comparison_long, inference == "mcmc"),
  c("block", "model", "inference"),
  diag_metrics
)
mcmc_diag <- merge(mcmc_gate, mcmc_numeric, by = c("block", "model", "inference"), all = TRUE, sort = FALSE)
rf288_write_csv_20260427(mcmc_diag, mcmc_diag_path)

vb_gate <- rf288_group_gate_summary_20260427(
  subset(comparison_long, inference == "vb"),
  c("block", "model", "inference")
)
vb_numeric <- rf288_group_numeric_summary_20260427(
  subset(comparison_long, inference == "vb"),
  c("block", "model", "inference"),
  diag_metrics
)
vb_diag <- merge(vb_gate, vb_numeric, by = c("block", "model", "inference"), all = TRUE, sort = FALSE)
rf288_write_csv_20260427(vb_diag, vb_diag_path)

inventory_cols <- rf288_inventory_columns_20260427()

warn_inventory <- rf288_ensure_columns_20260427(
  subset(comparison_long, gate_overall == "WARN"),
  inventory_cols
)
warn_inventory <- warn_inventory[order(
  warn_inventory$block,
  warn_inventory$root_kind,
  warn_inventory$family,
  warn_inventory$tau_label,
  warn_inventory$fit_size,
  warn_inventory$prior_semantics,
  warn_inventory$inference,
  warn_inventory$model,
  warn_inventory$row_id
), ]
rf288_write_csv_20260427(warn_inventory, warn_inventory_path)

fail_inventory <- rf288_ensure_columns_20260427(
  subset(comparison_long, gate_overall == "FAIL"),
  inventory_cols
)
fail_inventory <- fail_inventory[order(
  fail_inventory$block,
  fail_inventory$root_kind,
  fail_inventory$family,
  fail_inventory$tau_label,
  fail_inventory$fit_size,
  fail_inventory$prior_semantics,
  fail_inventory$inference,
  fail_inventory$model,
  fail_inventory$row_id
), ]
rf288_write_csv_20260427(fail_inventory, fail_inventory_path)

cat("Wrote refreshed288 comparison tables, pairwise tables, diagnostics, and inventories.\n")

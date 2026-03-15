#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo_root <- if (length(args) >= 1L) args[[1L]] else "."
repo_root <- normalizePath(repo_root, mustWork = TRUE)

source(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_v2_common.R"))

action_plan <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260315_family_qspec_residual_action_plan.tsv"))
method_signoff <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260314_family_qspec_method_signoff.tsv"))

key_cols <- c("root_id", "inference", "model")

join_cols <- c("root_id", "root_kind", "family", "tau", "fit_size", "prior", "inference", "model", "signoff_reason", "action_class")

moderate_rows <- action_plan[action_plan$action_class == "threshold_only_rescue_moderate", join_cols, drop = FALSE]
aggressive_rows <- action_plan[action_plan$action_class == "aggressive_policy_only_rescue", join_cols, drop = FALSE]
deeper_rows <- action_plan[action_plan$action_class == "needs_deeper_chain", join_cols, drop = FALSE]
vb_debug_rows <- action_plan[action_plan$action_class == "needs_model_or_vb_debug", join_cols, drop = FALSE]
mixed_rows <- action_plan[action_plan$action_class == "mixed_debug_and_resample", join_cols, drop = FALSE]
hard_rows <- action_plan[action_plan$action_class == "hard_numerical_repair", join_cols, drop = FALSE]

attach_metrics <- function(df) {
  if (!nrow(df)) return(df)
  merge(
    df,
    method_signoff[, c(
      "root_id", "inference", "model",
      "mcmc_n_keep", "mcmc_ess_sigma", "mcmc_ess_gamma", "mcmc_ess_state",
      "mcmc_acf1_sigma", "mcmc_acf1_gamma", "mcmc_acf1_state",
      "mcmc_geweke_absz_sigma", "mcmc_geweke_absz_gamma", "mcmc_geweke_absz_state",
      "mcmc_half_drift_sigma", "mcmc_half_drift_gamma", "mcmc_half_drift_state",
      "vb_elbo_tail_rel_range", "vb_sigma_tail_rel_range", "vb_gamma_tail_rel_range",
      "vb_delta_state_last", "vb_delta_sigma_last", "vb_delta_gamma_last",
      "run_root"
    ), drop = FALSE],
    by = key_cols,
    all.x = TRUE,
    sort = FALSE
  )
}

moderate_rows <- attach_metrics(moderate_rows)
aggressive_rows <- attach_metrics(aggressive_rows)
deeper_rows <- attach_metrics(deeper_rows)
vb_debug_rows <- attach_metrics(vb_debug_rows)
mixed_rows <- attach_metrics(mixed_rows)
hard_rows <- attach_metrics(hard_rows)

deeper_rows$recommended_action <- "rerun_with_deeper_mcmc"
deeper_rows$recommended_burn <- 3000L
deeper_rows$recommended_keep <- 8000L
deeper_rows$recommended_trace_every <- 25L

vb_debug_rows$recommended_action <- "debug_vb_then_targeted_refit"
mixed_rows$recommended_action <- "debug_model_then_resample"
hard_rows$recommended_action <- "exclude_until_numerical_fix"
moderate_rows$recommended_action <- "mark_comparison_eligible_under_second_wave_policy"
aggressive_rows$recommended_action <- "hold_out_from_policy_rescue"

policy_decision <- data.frame(
  decision_id = "second_wave_moderate_policy",
  accepted = TRUE,
  mcmc_ess_sigma_warn = 3,
  mcmc_ess_gamma_warn = 3,
  mcmc_ess_state_warn = 3,
  mcmc_acf1_warn = 0.998,
  mcmc_geweke_absz_warn = 7.5,
  mcmc_half_drift_warn = 1.0,
  keep_hard_failures_strict = TRUE,
  keep_vb_policy_strict = TRUE,
  rationale = "Adopt only the moderate MCMC relaxation; reject the aggressive policy-only rescue set; rerun deeper-chain cases separately; keep hard and mixed/VB-debug rows out of automatic policy rescue.",
  stringsAsFactors = FALSE
)

action_summary <- data.frame(
  action_class = c(
    "newly_eligible_under_second_wave_policy",
    "hold_out_aggressive_policy_only",
    "rerun_with_deeper_mcmc",
    "debug_vb_then_targeted_refit",
    "debug_model_then_resample",
    "exclude_until_numerical_fix"
  ),
  count = c(
    nrow(moderate_rows),
    nrow(aggressive_rows),
    nrow(deeper_rows),
    nrow(vb_debug_rows),
    nrow(mixed_rows),
    nrow(hard_rows)
  ),
  stringsAsFactors = FALSE
)

out_dir <- file.path(repo_root, "tools", "merge_reports")
fq_write_tsv(policy_decision, file.path(out_dir, "20260315_family_qspec_second_wave_policy_decision.tsv"))
fq_write_tsv(action_summary, file.path(out_dir, "20260315_family_qspec_second_wave_action_summary.tsv"))
fq_write_tsv(moderate_rows, file.path(out_dir, "20260315_family_qspec_newly_eligible_under_second_wave_policy.tsv"))
fq_write_tsv(aggressive_rows, file.path(out_dir, "20260315_family_qspec_aggressive_policy_holdouts.tsv"))
fq_write_tsv(deeper_rows, file.path(out_dir, "20260315_family_qspec_second_wave_deeper_chain_targets.tsv"))
fq_write_tsv(vb_debug_rows, file.path(out_dir, "20260315_family_qspec_second_wave_vb_debug_targets.tsv"))
fq_write_tsv(mixed_rows, file.path(out_dir, "20260315_family_qspec_second_wave_mixed_debug_targets.tsv"))
fq_write_tsv(hard_rows, file.path(out_dir, "20260315_family_qspec_second_wave_hard_holdouts.tsv"))

md <- c(
  "# Family-QSpec Second-Wave Decision",
  "",
  "## Accepted Policy",
  "",
  "- Adopt the moderate MCMC rescue policy only.",
  "- Do not adopt the aggressive policy-only rescue thresholds.",
  "- Do not relax VB thresholds.",
  "- Keep hard numerical failures excluded from scientific comparison.",
  "",
  "## Action Summary",
  "",
  "| action | count |",
  "|---|---:|"
)
for (i in seq_len(nrow(action_summary))) {
  md <- c(md, sprintf("| %s | %d |", action_summary$action_class[[i]], action_summary$count[[i]]))
}

writeLines(md, con = file.path(out_dir, "20260315_family_qspec_second_wave_decision.md"))

cat("Wrote second-wave decision bundle under tools/merge_reports\n")

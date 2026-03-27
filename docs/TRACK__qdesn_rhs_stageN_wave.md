# TRACK: QDESN RHS Stage-N Targeted Drift Repair Wave

- run_tag: `stageNrepair-20260325-150856__git-d81c311`
- manifest: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/config/validation/qdesn_rhs_stageN_manifest.yaml`
- analysis_root: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageNrepair-20260325-150856__git-d81c311`
- results_root: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/results/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageNrepair-20260325-150856__git-d81c311`
- base_defaults: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/config/validation/qdesn_mcmc_compare_rhs_stageM_repair_winner.yaml`
- guardrail_lock: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/config/validation/qdesn_rhs_guardrail_lock.yaml`
- guardrailed_base_materialized: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageNrepair-20260325-150856__git-d81c311/config/base_guardrailed_defaults.yaml`
- failed_grid: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/config/validation/qdesn_rhs_stageN_blocker_grid.csv`
- canary_grid: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/config/validation/qdesn_rhs_stageN_blocker_grid.csv`
- full_grid: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/config/validation/qdesn_rhs_stageM_expansion_grid.csv`
- mr1_winner: `NR1_longer_chain_plus_adapt`
- mr2_pass: `true`
- mr3_attempted: `true`
- mr3_pass: `false`
- promoted_for_next_wave: `false`

## MR1 Profile Matrix

| stage_id | profile_id | description | n_pairs | n_pair_pass | n_pair_warn | n_pair_fail | n_pair_eligible | all_finite_ok | all_domain_ok | all_finite_domain_ok | mcmc_signoff_pass | mcmc_signoff_warn | mcmc_signoff_fail | mcmc_signoff_grade_worst | mcmc_signoff_reason_worst | mcmc_min_ess_rhs_min | mcmc_max_geweke_absz_rhs_max | mcmc_max_half_drift_rhs_max | runtime_ratio_median | mcmc_fit_runtime_seconds_mean | n_trace_unavailable_total | gate_pass | gate_zero_fail | gate_all_eligible | gate_finite_domain | gate_no_trace_unavailable | report_root | results_root |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| MR1 | NR1_base_replay | Replay Stage-M winner on Stage-N blocker roots. | 2 | 0 | 2 | 0 | 2 | TRUE | TRUE | TRUE | 0 | 2 | 0 | WARN | chain_marginal_but_usable | 193.371 | 1.789 | 0.225 | 29.603 | 771.071 | 0 | TRUE | TRUE | TRUE | TRUE | TRUE | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageNrepair-20260325-150856__git-d81c311/mr1/NR1_base_replay/20260325-150913__git-d81c311 | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/results/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageNrepair-20260325-150856__git-d81c311/mr1/NR1_base_replay/20260325-150913__git-d81c311 |
| MR1 | NR1_longer_chain | Longer burn/keep on blocker roots. | 2 | 0 | 2 | 0 | 2 | TRUE | TRUE | TRUE | 0 | 2 | 0 | WARN | chain_marginal_but_usable | 222.648 | 2.136 | 0.057 | 36.247 | 1039.444 | 0 | TRUE | TRUE | TRUE | TRUE | TRUE | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageNrepair-20260325-150856__git-d81c311/mr1/NR1_longer_chain/20260325-153652__git-d81c311 | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/results/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageNrepair-20260325-150856__git-d81c311/mr1/NR1_longer_chain/20260325-153652__git-d81c311 |
| MR1 | NR1_longer_chain_plus_adapt | Longer chain with longer RHS width adaptation warmup. | 2 | 1 | 1 | 0 | 2 | TRUE | TRUE | TRUE | 1 | 1 | 0 | WARN | chain_marginal_but_usable | 301.549 | 1.640 | 0.111 | 42.634 | 1155.197 | 0 | TRUE | TRUE | TRUE | TRUE | TRUE | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageNrepair-20260325-150856__git-d81c311/mr1/NR1_longer_chain_plus_adapt/20260325-161330__git-d81c311 | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/results/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageNrepair-20260325-150856__git-d81c311/mr1/NR1_longer_chain_plus_adapt/20260325-161330__git-d81c311 |
| MR1 | NR1_longer_chain_plus_adapt_blocktight | Longer chain + adaptation + tighter transformed RHS global block. | 2 | 1 | 1 | 0 | 2 | TRUE | TRUE | TRUE | 1 | 1 | 0 | WARN | chain_marginal_but_usable | 261.080 | 2.189 | 0.070 | 48.059 | 1321.765 | 0 | TRUE | TRUE | TRUE | TRUE | TRUE | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageNrepair-20260325-150856__git-d81c311/mr1/NR1_longer_chain_plus_adapt_blocktight/20260325-165355__git-d81c311 | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/results/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageNrepair-20260325-150856__git-d81c311/mr1/NR1_longer_chain_plus_adapt_blocktight/20260325-165355__git-d81c311 |

## MR2 Canary Summary

| stage_id | profile_id | description | n_pairs | n_pair_pass | n_pair_warn | n_pair_fail | n_pair_eligible | all_finite_ok | all_domain_ok | all_finite_domain_ok | mcmc_signoff_pass | mcmc_signoff_warn | mcmc_signoff_fail | mcmc_signoff_grade_worst | mcmc_signoff_reason_worst | mcmc_min_ess_rhs_min | mcmc_max_geweke_absz_rhs_max | mcmc_max_half_drift_rhs_max | runtime_ratio_median | mcmc_fit_runtime_seconds_mean | n_trace_unavailable_total | gate_pass | gate_zero_fail | gate_all_eligible | gate_finite_domain | gate_no_trace_unavailable | report_root | results_root |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| MR2 | MR2_canary_reconfirm | Blocker reconfirm (2 roots) with NR1 winner. | 2 | 0 | 2 | 0 | 2 | TRUE | TRUE | TRUE | 0 | 2 | 0 | WARN | chain_marginal_but_usable | 348.717 | 2.11 | 0.088 | 42.119 | 1126.622 | 0 | TRUE | TRUE | TRUE | TRUE | TRUE | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageNrepair-20260325-150856__git-d81c311/mr2_canary/20260325-173953__git-d81c311 | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/results/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageNrepair-20260325-150856__git-d81c311/mr2_canary/20260325-173953__git-d81c311 |

## MR3 Full Summary

| stage_id | profile_id | description | n_pairs | n_pair_pass | n_pair_warn | n_pair_fail | n_pair_eligible | all_finite_ok | all_domain_ok | all_finite_domain_ok | mcmc_signoff_pass | mcmc_signoff_warn | mcmc_signoff_fail | mcmc_signoff_grade_worst | mcmc_signoff_reason_worst | mcmc_min_ess_rhs_min | mcmc_max_geweke_absz_rhs_max | mcmc_max_half_drift_rhs_max | runtime_ratio_median | mcmc_fit_runtime_seconds_mean | n_trace_unavailable_total | gate_pass | gate_zero_fail | gate_all_eligible | gate_finite_domain | gate_no_trace_unavailable | report_root | results_root |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| MR3 | MR3_full_reconfirm | Full 36-root reconfirmation with NR1 winner. | 36 | 2 | 33 | 1 | 35 | TRUE | TRUE | TRUE | 2 | 33 | 1 | FAIL | geweke_drift | 210.439 | 3 | 0.227 | 44.231 | 1130.961 | 0 | FALSE | FALSE | FALSE | TRUE | TRUE | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageNrepair-20260325-150856__git-d81c311/mr3_full/20260325-181919__git-d81c311 | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/results/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageNrepair-20260325-150856__git-d81c311/mr3_full/20260325-181919__git-d81c311 |

## Decision
- mr1_winner: `NR1_longer_chain_plus_adapt`
- mr2_pass: `true`
- mr3_attempted: `true`
- mr3_pass: `false`
- promoted_for_next_wave: `false`

## Post-Run Interpretation (2026-03-26)

Stage-N is operationally complete and stable:

- execution status: `SUCCESS 46/46`;
- no finite/domain regressions;
- collapse guardrail behavior remains healthy.

Promotion was blocked only by one strict MR3 signoff failure:

- root:
  `scenario-sin_asym_small__tau-0p05__prior-rhs__seed-231__res-tiny_d1_n8`
- reason:
  `geweke_drift`.

This confirms the remaining gap is a narrow RHS MCMC drift closure problem,
not a broader pipeline/collapse issue.

Next-stage plan:
- `docs/TRACK__qdesn_rhs_stageO_plan.md`

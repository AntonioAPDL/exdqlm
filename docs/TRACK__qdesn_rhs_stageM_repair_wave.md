# TRACK: QDESN RHS Stage-M Repair Wave

- run_tag: `stageMrepair-supervised-20260324-172932__git-d81c311`
- manifest: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/config/validation/qdesn_rhs_stageM_repair_manifest.yaml`
- analysis_root: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageMrepair-supervised-20260324-172932__git-d81c311`
- results_root: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/results/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageMrepair-supervised-20260324-172932__git-d81c311`
- base_defaults: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/config/validation/qdesn_mcmc_compare_rhs_stageJKL_promoted.yaml`
- guardrail_lock: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/config/validation/qdesn_rhs_guardrail_lock.yaml`
- guardrailed_base_materialized: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageMrepair-supervised-20260324-172932__git-d81c311/config/base_guardrailed_defaults.yaml`
- failed_grid: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/config/validation/qdesn_rhs_stageM_failed_roots_seed123.csv`
- canary_grid: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/config/validation/qdesn_rhs_stageM_seed123_grid.csv`
- full_grid: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/config/validation/qdesn_rhs_stageM_expansion_grid.csv`
- mr1_winner: `MR1_longer_chain_plus_adapt`
- mr2_pass: `true`
- mr3_attempted: `true`
- mr3_pass: `false`
- promoted_for_next_wave: `false`

## MR1 Profile Matrix

| stage_id | profile_id | description | n_pairs | n_pair_pass | n_pair_warn | n_pair_fail | n_pair_eligible | all_finite_ok | all_domain_ok | all_finite_domain_ok | mcmc_signoff_pass | mcmc_signoff_warn | mcmc_signoff_fail | mcmc_signoff_grade_worst | mcmc_signoff_reason_worst | mcmc_min_ess_rhs_min | mcmc_max_geweke_absz_rhs_max | mcmc_max_half_drift_rhs_max | runtime_ratio_median | mcmc_fit_runtime_seconds_mean | n_trace_unavailable_total | gate_pass | gate_zero_fail | gate_all_eligible | gate_finite_domain | gate_no_trace_unavailable | report_root | results_root |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| MR1 | MR1_base_replay | Replay current guardrailed Stage-M defaults on failed roots. | 2 | 0 | 1 | 1 | 1 | TRUE | TRUE | TRUE | 0 | 1 | 1 | FAIL | geweke_drift | 145.519 | 4.575 | 0.250 | 14.783 | 423.644 | 0 | FALSE | FALSE | FALSE | TRUE | TRUE | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageMrepair-supervised-20260324-172932__git-d81c311/mr1/MR1_base_replay/20260324-172954__git-d81c311 | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/results/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageMrepair-supervised-20260324-172932__git-d81c311/mr1/MR1_base_replay/20260324-172954__git-d81c311 |
| MR1 | MR1_longer_chain | Longer RHS chain on failed roots. | 2 | 0 | 2 | 0 | 2 | TRUE | TRUE | TRUE | 0 | 2 | 0 | WARN | chain_marginal_but_usable | 287.821 | 1.836 | 0.204 | 22.961 | 609.474 | 0 | TRUE | TRUE | TRUE | TRUE | TRUE | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageMrepair-supervised-20260324-172932__git-d81c311/mr1/MR1_longer_chain/20260324-174607__git-d81c311 | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/results/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageMrepair-supervised-20260324-172932__git-d81c311/mr1/MR1_longer_chain/20260324-174607__git-d81c311 |
| MR1 | MR1_longer_chain_plus_mixing | Longer chain plus stronger transformed RHS block mixing. | 2 | 0 | 1 | 1 | 1 | TRUE | TRUE | TRUE | 0 | 1 | 1 | FAIL | geweke_drift | 164.903 | 1.616 | 0.118 | 22.181 | 679.327 | 0 | FALSE | FALSE | FALSE | TRUE | TRUE | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageMrepair-supervised-20260324-172932__git-d81c311/mr1/MR1_longer_chain_plus_mixing/20260324-180822__git-d81c311 | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/results/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageMrepair-supervised-20260324-172932__git-d81c311/mr1/MR1_longer_chain_plus_mixing/20260324-180822__git-d81c311 |
| MR1 | MR1_longer_chain_plus_adapt | Profile 3 plus longer adaptation warmup and stronger tau freeze. | 2 | 1 | 1 | 0 | 2 | TRUE | TRUE | TRUE | 1 | 1 | 0 | WARN | chain_marginal_but_usable | 263.732 | 0.776 | 0.117 | 27.823 | 811.098 | 0 | TRUE | TRUE | TRUE | TRUE | TRUE | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageMrepair-supervised-20260324-172932__git-d81c311/mr1/MR1_longer_chain_plus_adapt/20260324-183300__git-d81c311 | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/results/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageMrepair-supervised-20260324-172932__git-d81c311/mr1/MR1_longer_chain_plus_adapt/20260324-183300__git-d81c311 |

## MR2 Canary Summary

| stage_id | profile_id | description | n_pairs | n_pair_pass | n_pair_warn | n_pair_fail | n_pair_eligible | all_finite_ok | all_domain_ok | all_finite_domain_ok | mcmc_signoff_pass | mcmc_signoff_warn | mcmc_signoff_fail | mcmc_signoff_grade_worst | mcmc_signoff_reason_worst | mcmc_min_ess_rhs_min | mcmc_max_geweke_absz_rhs_max | mcmc_max_half_drift_rhs_max | runtime_ratio_median | mcmc_fit_runtime_seconds_mean | n_trace_unavailable_total | gate_pass | gate_zero_fail | gate_all_eligible | gate_finite_domain | gate_no_trace_unavailable | report_root | results_root |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| MR2 | MR2_canary_reconfirm | Canary reconfirm (12 roots, seed 123) with MR1 winner. | 12 | 2 | 10 | 0 | 12 | TRUE | TRUE | TRUE | 3 | 9 | 0 | WARN | chain_marginal_but_usable | 164.597 | 2.855 | 0.212 | 28.85 | 809.945 | 0 | TRUE | TRUE | TRUE | TRUE | TRUE | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageMrepair-supervised-20260324-172932__git-d81c311/mr2_canary/20260324-190205__git-d81c311 | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/results/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageMrepair-supervised-20260324-172932__git-d81c311/mr2_canary/20260324-190205__git-d81c311 |

## MR3 Full Summary

| stage_id | profile_id | description | n_pairs | n_pair_pass | n_pair_warn | n_pair_fail | n_pair_eligible | all_finite_ok | all_domain_ok | all_finite_domain_ok | mcmc_signoff_pass | mcmc_signoff_warn | mcmc_signoff_fail | mcmc_signoff_grade_worst | mcmc_signoff_reason_worst | mcmc_min_ess_rhs_min | mcmc_max_geweke_absz_rhs_max | mcmc_max_half_drift_rhs_max | runtime_ratio_median | mcmc_fit_runtime_seconds_mean | n_trace_unavailable_total | gate_pass | gate_zero_fail | gate_all_eligible | gate_finite_domain | gate_no_trace_unavailable | report_root | results_root |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| MR3 | MR3_full_reconfirm | Full Stage-M expansion (36 roots) with MR1 winner. | 36 | 1 | 33 | 2 | 34 | TRUE | TRUE | TRUE | 2 | 32 | 2 | FAIL | geweke_drift | 100.649 | 4.332 | 0.261 | 28.853 | 879.426 | 0 | FALSE | FALSE | FALSE | TRUE | TRUE | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageMrepair-supervised-20260324-172932__git-d81c311/mr3_full/20260324-215620__git-d81c311 | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/results/qdesn_mcmc_validation/rhs_stageM_repair_wave/stageMrepair-supervised-20260324-172932__git-d81c311/mr3_full/20260324-215620__git-d81c311 |

## Decision
- mr1_winner: `MR1_longer_chain_plus_adapt`
- mr2_pass: `true`
- mr3_attempted: `true`
- mr3_pass: `false`
- promoted_for_next_wave: `false`

## Post-Run Forensics (2026-03-25)

Stage-M repair run completed end-to-end with all roots executed (`SUCCESS 56`,
`FAIL 0` at execution level), but strict MR3 quality gate failed on MCMC
diagnostics:

- `n_pair_fail = 2 / 36`
- `n_pair_eligible = 34 / 36`
- finite/domain checks: all `TRUE`
- trace-unavailable count: `0`
- worst failure reason: `geweke_drift`

Blocking roots (MR3):

1. `scenario-level_shift_small__tau-0p05__prior-rhs__seed-231__res-tiny_d1_n8`
   - MCMC signoff: `FAIL` (`geweke_drift`)
   - core drift signal: `mcmc_max_geweke_absz_core = 3.299` (RHS max `2.396`)
2. `scenario-toy_sine_small__tau-0p25__prior-rhs__seed-123__res-tiny_d1_n8`
   - MCMC signoff: `FAIL` (`geweke_drift`)
   - RHS drift signal: `mcmc_max_geweke_absz_rhs = 4.332`

Interpretation:
- this is no longer a collapse/finiteness issue;
- ESS and half-drift are generally acceptable;
- residual blocker is localized Geweke drift on two roots.

## Next Wave Plan (Stage-N: Targeted Geweke Repair)

Scope constraints (unchanged):

1. static validation only (no benchmark path);
2. `readout.input_mode = raw_y_lags`, `decomposition.enabled = false`;
3. RHS tau-init guardrails remain locked (numeric resolved init, collapse diagnostics persisted).

Execution order:

1. Freeze Stage-M evidence as baseline:
   - keep this run as frozen comparator:
     `stageMrepair-supervised-20260324-172932__git-d81c311`.
2. Run Stage-NR1 targeted matrix on only the 2 blocking roots:
   - baseline winner replay (`MR1_longer_chain_plus_adapt`);
   - longer burn/keep profile;
   - longer adaptation + stronger transformed RHS block profile;
   - (optional) targeted multi-start profile if the first three do not clear drift.
3. Apply strict targeted gate:
   - `n_pair_fail = 0`,
   - all pair-comparison eligible,
   - finite/domain all `TRUE`,
   - trace-unavailable `= 0`.
4. Promote Stage-NR1 winner to Stage-NR2 full reconfirmation:
   - rerun 36-root MR3 grid once.
5. Promotion decision:
   - if Stage-NR2 passes strict gate: write promoted static-validation defaults;
   - if Stage-NR2 fails: keep Stage-M winner as non-promoted baseline and escalate
     to kernel-level changes (multichain gate and/or alternative RHS global move).

## Checklist (Post Stage-M)

- [x] Stage-M repair run completed and archived.
- [x] MR3 blockers isolated to two roots with diagnostics.
- [ ] Stage-NR1 targeted matrix config + grid prepared.
- [ ] Stage-NR1 launched and winner selected.
- [ ] Stage-NR2 (36-root) reconfirmation launched with Stage-N winner.
- [ ] Promotion decision and defaults/tracker update finalized.

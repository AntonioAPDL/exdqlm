# TRACK: QDESN RHS Stage-M Wave

- run_tag: `stageMwave-20260323-180913__git-88c0369`
- analysis_root: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/rhs_stageM_wave/stageMwave-20260323-180913__git-88c0369`
- results_root: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/results/qdesn_mcmc_validation/rhs_stageM_wave/stageMwave-20260323-180913__git-88c0369`
- promoted_defaults: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/config/validation/qdesn_mcmc_compare_rhs_stageJKL_promoted.yaml`
- guardrail_lock: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/config/validation/qdesn_rhs_guardrail_lock.yaml`
- guardrailed_defaults: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/config/validation/qdesn_mcmc_compare_rhs_stageM_guardrailed.yaml`
- canary_grid: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/config/validation/qdesn_rhs_stageM_seed123_grid.csv`
- full_grid: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/config/validation/qdesn_rhs_stageM_expansion_grid.csv`
- canary_pass: `false`
- full_attempted: `false`
- full_pass: `false`
- promoted_for_next_wave: `false`

## Canary Summary

| stage_id | n_pairs | n_pair_fail | n_pair_eligible | all_finite_ok | all_domain_ok | all_finite_domain_ok | mcmc_signoff_grade_worst | mcmc_signoff_reason_worst | mcmc_min_ess_rhs_min | mcmc_max_geweke_absz_rhs_max | mcmc_max_half_drift_rhs_max | runtime_ratio_median | n_trace_unavailable_total | gate_pass | gate_zero_fail | gate_all_eligible | gate_finite_domain | gate_no_trace_unavailable | report_root |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| M1_canary | 12 | 2 | 10 | TRUE | TRUE | TRUE | FAIL | geweke_drift | 82.665 | 4.559 | 0.436 | 15.304 | 0 | FALSE | FALSE | FALSE | TRUE | TRUE | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/rhs_stageM_wave/stageMwave-20260323-180913__git-88c0369/canary/20260323-180922__git-88c0369 |

## Decision
- canary_pass: `false`
- full_attempted: `false`
- full_pass: `false`
- promoted_for_next_wave: `false`

## Next Action

- Follow static repair workflow documented at:
  - `docs/TRACK__qdesn_rhs_stageM_repair_plan.md`
- Failed-root-only seed-123 grid prepared at:
  - `config/validation/qdesn_rhs_stageM_failed_roots_seed123.csv`

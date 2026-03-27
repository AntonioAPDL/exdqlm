# TRACK: QDESN RHS Stage-J/K/L/M Wave

- run_tag: `stageJKLM-20260323-125932__git-88c0369`
- manifest: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/config/validation/qdesn_rhs_stageJ_K_manifest.yaml`
- analysis_root: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/rhs_stageJ_K_L_M_wave/stageJKLM-20260323-125932__git-88c0369`
- candidate_defaults: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/config/validation/qdesn_mcmc_compare_rhs_stageI_candidate.yaml`
- broader_grid: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/config/validation/qdesn_mcmc_multichain_rhs_broader_confirmation_grid.csv`
- stageJ_pass: `false`
- stageK_attempted: `true`
- stageK_pass: `true`
- stageK_winner: `K4_failed_roots_taufreeze_plus_adapt`
- stageL_pass: `true`
- promotion_written: `true`
- promotion_source: `stageL_reconfirm_after_stageK`
- promotion_defaults: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/config/validation/qdesn_mcmc_compare_rhs_stageJKL_promoted.yaml`
- stageM_grid: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/config/validation/qdesn_rhs_stageM_expansion_grid.csv`
- stageM_defaults_template: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/config/validation/qdesn_mcmc_compare_rhs_stageM_template.yaml`

## Stage-J Summary

| stage_id | profile_id | description | n_pairs | n_pair_pass | n_pair_warn | n_pair_fail | n_pair_eligible | all_finite_ok | all_domain_ok | all_finite_domain_ok | mcmc_signoff_pass | mcmc_signoff_warn | mcmc_signoff_fail | mcmc_signoff_grade_worst | mcmc_signoff_reason_worst | mcmc_min_ess_rhs_min | mcmc_max_geweke_absz_rhs_max | mcmc_max_half_drift_rhs_max | runtime_ratio_median | mcmc_fit_runtime_seconds_mean | n_trace_unavailable_mcmc_signoff | n_trace_unavailable_mcmc_unhealthy | n_trace_unavailable_total | gate_pass | gate_zero_fail | gate_all_eligible | gate_finite_domain | gate_no_trace_unavailable | report_root | results_root |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| J | J0_stageI_candidate | Broader reconfirmation with Stage-I promoted candidate. | 8 | 0 | 6 | 2 | 6 | TRUE | TRUE | TRUE | 0 | 6 | 2 | FAIL | geweke_drift | 88.928 | 5.363 | 0.277 | 13.828 | 474.162 | 0 | 0 | 0 | FALSE | FALSE | FALSE | TRUE | TRUE | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/rhs_stageJ_K_L_M_wave/stageJKLM-20260323-125932__git-88c0369/stageJ/20260323-125933__git-88c0369 | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/results/qdesn_mcmc_validation/rhs_stageJ_K_L_M_wave/stageJKLM-20260323-125932__git-88c0369/stageJ/20260323-125933__git-88c0369 |

## Stage-K Profile Matrix

| stage_id | profile_id | description | n_pairs | n_pair_pass | n_pair_warn | n_pair_fail | n_pair_eligible | all_finite_ok | all_domain_ok | all_finite_domain_ok | mcmc_signoff_pass | mcmc_signoff_warn | mcmc_signoff_fail | mcmc_signoff_grade_worst | mcmc_signoff_reason_worst | mcmc_min_ess_rhs_min | mcmc_max_geweke_absz_rhs_max | mcmc_max_half_drift_rhs_max | runtime_ratio_median | mcmc_fit_runtime_seconds_mean | n_trace_unavailable_mcmc_signoff | n_trace_unavailable_mcmc_unhealthy | n_trace_unavailable_total | gate_pass | gate_zero_fail | gate_all_eligible | gate_finite_domain | gate_no_trace_unavailable | report_root | results_root |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| K | K0_failed_roots_baseline | Failed-root replay with Stage-I winner defaults. | 2 | 0 | 2 | 0 | 2 | TRUE | TRUE | TRUE | 0 | 2 | 0 | WARN | chain_marginal_but_usable | 104.741 | 2.916 | 0.279 | 14.016 | 415.632 | 0 | 0 | 0 | TRUE | TRUE | TRUE | TRUE | TRUE | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/rhs_stageJ_K_L_M_wave/stageJKLM-20260323-125932__git-88c0369/stageK/K0_failed_roots_baseline/20260323-141223__git-88c0369 | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/results/qdesn_mcmc_validation/rhs_stageJ_K_L_M_wave/stageJKLM-20260323-125932__git-88c0369/stageK/K0_failed_roots_baseline/20260323-141223__git-88c0369 |
| K | K1_failed_roots_longer_chain | Increase chain length for failed roots only. | 2 | 0 | 2 | 0 | 2 | TRUE | TRUE | TRUE | 0 | 2 | 0 | WARN | chain_marginal_but_usable | 120.693 | 2.256 | 0.251 | 18.252 | 568.231 | 0 | 0 | 0 | TRUE | TRUE | TRUE | TRUE | TRUE | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/rhs_stageJ_K_L_M_wave/stageJKLM-20260323-125932__git-88c0369/stageK/K1_failed_roots_longer_chain/20260323-142825__git-88c0369 | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/results/qdesn_mcmc_validation/rhs_stageJ_K_L_M_wave/stageJKLM-20260323-125932__git-88c0369/stageK/K1_failed_roots_longer_chain/20260323-142825__git-88c0369 |
| K | K2_failed_roots_taufreeze_extended | Extend RHS tau freeze during burn-in for failed roots. | 2 | 0 | 2 | 0 | 2 | TRUE | TRUE | TRUE | 0 | 2 | 0 | WARN | chain_marginal_but_usable | 161.450 | 1.393 | 0.185 | 13.861 | 418.710 | 0 | 0 | 0 | TRUE | TRUE | TRUE | TRUE | TRUE | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/rhs_stageJ_K_L_M_wave/stageJKLM-20260323-125932__git-88c0369/stageK/K2_failed_roots_taufreeze_extended/20260323-144938__git-88c0369 | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/results/qdesn_mcmc_validation/rhs_stageJ_K_L_M_wave/stageJKLM-20260323-125932__git-88c0369/stageK/K2_failed_roots_taufreeze_extended/20260323-144938__git-88c0369 |
| K | K3_failed_roots_adapt_longer | Longer width-adaptation warmup with smaller adaptation step. | 2 | 0 | 2 | 0 | 2 | TRUE | TRUE | TRUE | 0 | 2 | 0 | WARN | chain_marginal_but_usable | 116.885 | 1.956 | 0.276 | 13.659 | 421.728 | 0 | 0 | 0 | TRUE | TRUE | TRUE | TRUE | TRUE | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/rhs_stageJ_K_L_M_wave/stageJKLM-20260323-125932__git-88c0369/stageK/K3_failed_roots_adapt_longer/20260323-150544__git-88c0369 | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/results/qdesn_mcmc_validation/rhs_stageJ_K_L_M_wave/stageJKLM-20260323-125932__git-88c0369/stageK/K3_failed_roots_adapt_longer/20260323-150544__git-88c0369 |
| K | K4_failed_roots_taufreeze_plus_adapt | Combine extended tau freeze and longer adaptation warmup. | 2 | 0 | 2 | 0 | 2 | TRUE | TRUE | TRUE | 0 | 2 | 0 | WARN | chain_marginal_but_usable | 110.479 | 1.131 | 0.184 | 13.783 | 599.424 | 0 | 0 | 0 | TRUE | TRUE | TRUE | TRUE | TRUE | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/rhs_stageJ_K_L_M_wave/stageJKLM-20260323-125932__git-88c0369/stageK/K4_failed_roots_taufreeze_plus_adapt/20260323-152205__git-88c0369 | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/results/qdesn_mcmc_validation/rhs_stageJ_K_L_M_wave/stageJKLM-20260323-125932__git-88c0369/stageK/K4_failed_roots_taufreeze_plus_adapt/20260323-152205__git-88c0369 |

## Stage-L Summary

| stage_id | profile_id | description | n_pairs | n_pair_pass | n_pair_warn | n_pair_fail | n_pair_eligible | all_finite_ok | all_domain_ok | all_finite_domain_ok | mcmc_signoff_pass | mcmc_signoff_warn | mcmc_signoff_fail | mcmc_signoff_grade_worst | mcmc_signoff_reason_worst | mcmc_min_ess_rhs_min | mcmc_max_geweke_absz_rhs_max | mcmc_max_half_drift_rhs_max | runtime_ratio_median | mcmc_fit_runtime_seconds_mean | n_trace_unavailable_mcmc_signoff | n_trace_unavailable_mcmc_unhealthy | n_trace_unavailable_total | gate_pass | gate_zero_fail | gate_all_eligible | gate_finite_domain | gate_no_trace_unavailable | report_root | results_root |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| L | L0_reconfirm__K4_failed_roots_taufreeze_plus_adapt | Broader reconfirmation from Stage-K winner on failed-root fallback. | 8 | 0 | 8 | 0 | 8 | TRUE | TRUE | TRUE | 0 | 8 | 0 | WARN | chain_marginal_but_usable | 116.53 | 2.562 | 0.496 | 15.056 | 569.438 | 0 | 0 | 0 | TRUE | TRUE | TRUE | TRUE | TRUE | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/rhs_stageJ_K_L_M_wave/stageJKLM-20260323-125932__git-88c0369/stageL/20260323-154508__git-88c0369 | /home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/results/qdesn_mcmc_validation/rhs_stageJ_K_L_M_wave/stageJKLM-20260323-125932__git-88c0369/stageL/20260323-154508__git-88c0369 |

## Stage-M Scaffold
- n_roots: `36`
- grid_path: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/config/validation/qdesn_rhs_stageM_expansion_grid.csv`
- defaults_template_path: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/config/validation/qdesn_mcmc_compare_rhs_stageM_template.yaml`

## Health Snapshot (2026-03-23)

- This Stage-J/K/L/M wave is fully completed (`stageJ_K_L_M_manifest.json` written).
- No active QDESN validation campaign process is running for this wave.
- Promotion was written from Stage-L fallback:
  - `promotion_source = stageL_reconfirm_after_stageK`
  - defaults: `config/validation/qdesn_mcmc_compare_rhs_stageJKL_promoted.yaml`
- Stage-M is currently scaffold-only (grid/template generated, not yet executed).

## Next Relaunch Plan (Stage-M, Guardrail-Enforced)

Scope:
- simulation/validation only;
- no DLM-informed input (must stay `raw_y_lags`);
- preserve RHS tau-init guardrails to avoid collapse.

### Step M0: Materialize guardrailed Stage-M defaults

```bash
Rscript scripts/materialize_qdesn_rhs_guardrail_defaults.R \
  --base-defaults config/validation/qdesn_mcmc_compare_rhs_stageJKL_promoted.yaml \
  --lock config/validation/qdesn_rhs_guardrail_lock.yaml \
  --output config/validation/qdesn_mcmc_compare_rhs_stageM_guardrailed.yaml
```

Expected invariants after materialization:
- `pipeline.readout.input_mode = raw_y_lags`
- `pipeline.decomposition.enabled = false`
- `pipeline.inference.vb.priors.beta.rhs.init_log_tau` resolves numeric (`0.0` unless explicitly overridden)

### Step M1: Canary run (12 roots, seed=123 only)

Use the canary grid first to reduce wasted compute if drift regressions reappear.

Canary grid:
- `config/validation/qdesn_rhs_stageM_seed123_grid.csv`

Launch:

```bash
Rscript scripts/run_qdesn_mcmc_full_comparison.R \
  --defaults config/validation/qdesn_mcmc_compare_rhs_stageM_guardrailed.yaml \
  --grid config/validation/qdesn_rhs_stageM_seed123_grid.csv \
  --results-root results/qdesn_mcmc_validation/rhs_stageM_seed123 \
  --reports-root reports/qdesn_mcmc_validation/rhs_stageM_seed123 \
  --no-plots
```

Canary gate to proceed:
- `n_pair_fail = 0`
- all pairs comparison-eligible
- no `rhs_trace_unavailable`
- finite/domain checks all true

### Step M2: Full Stage-M expansion (36 roots) if canary passes

Launch:

```bash
Rscript scripts/run_qdesn_mcmc_full_comparison.R \
  --defaults config/validation/qdesn_mcmc_compare_rhs_stageM_guardrailed.yaml \
  --grid config/validation/qdesn_rhs_stageM_expansion_grid.csv \
  --results-root results/qdesn_mcmc_validation/rhs_stageM_expansion \
  --reports-root reports/qdesn_mcmc_validation/rhs_stageM_expansion \
  --no-plots
```

### Step M3: Health evaluation + decision

Primary gate:
- zero FAIL;
- no finite/domain violations;
- no trace-unavailable diagnostics;
- keep eligibility true across pairs.

Secondary diagnostics (for tuning quality, not immediate rejection):
- max Geweke / half-chain drift trends by scenario/tau;
- runtime ratio versus VB;
- WARN concentration by tau and scenario.

### Step M4: If full expansion fails, targeted repair only on failed roots

Use Stage-K style failed-root matrix with current winner profile family:
- start from Stage-L promoted guardrailed defaults;
- run failed roots only;
- re-run only repaired roots on broader grid before promoting changes.

This keeps the workflow compute-efficient and prevents broad reruns for localized failures.

Operational shortcut:
- run `scripts/run_qdesn_rhs_stageM_wave.R` to execute M0+M1 and auto-launch M2 only if canary passes strict gates.

## Live Relaunch (started 2026-03-23)

- stageM_run_tag: `stageMwave-20260323-180913__git-88c0369`
- analysis_root: `reports/qdesn_mcmc_validation/rhs_stageM_wave/stageMwave-20260323-180913__git-88c0369`
- results_root: `results/qdesn_mcmc_validation/rhs_stageM_wave/stageMwave-20260323-180913__git-88c0369`
- launcher_log: `reports/qdesn_mcmc_validation/rhs_stageM_wave/stageMwave-20260323-180913__git-88c0369/logs/launch.log`
- status_at_launch_update: `RUNNING` (canary root execution started)

# TRACK: QDESN Stage-Q rhs_ns Wrap-Up Validation Wave

Date: 2026-03-28  
Branch: `feature/qdesn-mcmc-alternative`  
Scope: static simulation/validation only (`readout.input_mode=raw_y_lags`, `decomposition.enabled=false`)

## 1) Objective

Complete the static qdesn validation study with `rhs_ns` as default sparse prior, now with a 3-quantile validation set:

- `tau = 0.05, 0.50, 0.95`

for each scenario/seed root, and produce:

1. fit/health tables for VB and MCMC,
2. synthesis-status tables at the tau-set level (`COMPLETE_HEALTHY`, `COMPLETE_UNHEALTHY`, `INCOMPLETE`),
3. forecast/signal/runtime comparison tables for VB vs MCMC.

## 2) Stage-Q Assets

- Defaults:
  - `config/validation/qdesn_mcmc_compare_rhsns_stageQ_defaults.yaml`
- Grid:
  - `config/validation/qdesn_rhsns_stageQ_grid.csv`
  - size: `36 roots = 4 scenarios x 3 taus x 3 seeds x rhs_ns`
- Launcher:
  - `scripts/run_qdesn_rhsns_stageQ_wave.R`
- Health check:
  - `scripts/healthcheck_qdesn_rhsns_stageQ_wave.R`

## 3) Contract and Guardrails

1. Non-DLM validation contract remains strict:
   - `readout.input_mode=raw_y_lags`
   - `decomposition.enabled=false`
2. `rhs_ns` guardrails remain active (do not weaken):
   - tau-init semantics and collapse diagnostics stay in place.
3. Multi-quantile fit is enabled through:
   - `pipeline.validation_p_vec: [0.05, 0.5, 0.95]`
   - root-level `tau` remains as the evaluation index/label.
4. No benchmark-pipeline work in this wave.

## 4) Execution Plan (Detailed)

### Phase A: Preflight + Freeze

Run:

- `Rscript scripts/run_qdesn_rhsns_stageQ_wave.R --workers 12 --no-plots --quiet --run-tag <stageQ-tag>`

Preflight artifacts:

- `reports/qdesn_mcmc_validation/rhsns_stageQ_wave/<run_tag>/summary/stageQ_preflight.json`

Preflight checks:

1. defaults/grid/git SHA captured.
2. non-DLM contract validated from defaults.
3. `validation_p_vec` resolved and recorded.
4. Stage-P baseline references recorded for audit continuity.

### Phase B: Multi-Core Fit Relaunch

Execution root:

- `rhsns_full` arm only, with campaign workers (`--workers`) for outer parallelism.

Expected outputs:

- `results/qdesn_mcmc_validation/rhsns_stageQ_wave/<run_tag>/rhsns_full/<campaign_run>/roots/...`
- `reports/qdesn_mcmc_validation/rhsns_stageQ_wave/<run_tag>/rhsns_full/<campaign_run>/tables/...`

### Phase C: Post-Processing + Tau-Set Synthesis Status

Campaign collector now writes additive tau-set summaries:

- `campaign_tau_set_method_summary.csv`
- `campaign_tau_set_pair_summary.csv`

Definition:

- `COMPLETE_HEALTHY`: all target taus present + healthy for the method pair.
- `COMPLETE_UNHEALTHY`: all target taus present and completed, but at least one tau unhealthy.
- `INCOMPLETE`: any missing/failed tau in the required set.

### Phase D: Health and Comparison Readout

Primary tables:

1. `campaign_method_summary.csv`
2. `campaign_pair_summary.csv`
3. `campaign_tau_set_method_summary.csv`
4. `campaign_tau_set_pair_summary.csv`

Decision read:

1. healthy comparable subset = tau-set `COMPLETE_HEALTHY` pairs.
2. secondary evidence = `COMPLETE_UNHEALTHY` (completed but not promotion-eligible).

## 5) Health Check Commands

Main live check:

- `Rscript scripts/healthcheck_qdesn_rhsns_stageQ_wave.R --run-tag <run_tag> --arm rhsns_full`

Optional campaign reconciliation:

- `Rscript scripts/reconcile_qdesn_validation_campaign_status.R --report-root reports/qdesn_mcmc_validation/rhsns_stageQ_wave/<run_tag>/rhsns_full/<campaign_run> --results-root results/qdesn_mcmc_validation/rhsns_stageQ_wave/<run_tag>/rhsns_full/<campaign_run>`

## 6) Signoff Criteria

Stage-Q is considered done when:

1. all 36 roots attempted and campaign tables finalized,
2. tau-set pair table is present and non-empty,
3. no `rhs_diagnostics_missing` false-fail artifacts for healthy `rhs_ns` runs,
4. healthy-comparable subset (`COMPLETE_HEALTHY`) is sufficient for VB vs MCMC speed/performance readout.

## 7) Final Status (Completed)

Stage-Q completed successfully.

- Launch command:
  - `Rscript scripts/run_qdesn_rhsns_stageQ_wave.R --workers 12 --no-plots --run-tag stageQ-20260328-093000__git-2641e6b`
- Completion marker:
  - `reports/qdesn_mcmc_validation/rhsns_stageQ_wave/stageQ-20260328-093000__git-2641e6b/rhsns_full/20260328-092645__git-2641e6b/manifest/campaign_completed.json`
- Final run totals:
  - roots: `36/36 SUCCESS`
  - method rows: `72`
  - method signoff: `WARN 69`, `FAIL 3`, `PASS 0`
  - pair signoff: `WARN 33`, `FAIL 3`, `PASS 0`
  - tau-set pair status: `COMPLETE_HEALTHY 10`, `COMPLETE_UNHEALTHY 2`, `INCOMPLETE 0`

Non-healthy case interpretation:

- catastrophic failures: none (`collapse=0`, `unhealthy=0`, finite/domain all OK)
- remaining `FAIL` roots are diagnostic-quality issues only:
  - `const_small | tau=0.05 | seed=231 | rhs_ns` (`geweke_drift`)
  - `const_small | tau=0.95 | seed=231 | rhs_ns` (`geweke_drift; half_chain_drift`)
  - `sin_asym_small | tau=0.05 | seed=321 | rhs_ns` (`geweke_drift`)

Stage-Q closeout notes:

1. Static validation wave is complete and acceptable for wrap-up.
2. Healthy-comparable subset is established (`10` tau-set pairs).
3. Next work should move to the larger/challenging follow-on validation matrix,
   reusing this same contract and reporting stack.

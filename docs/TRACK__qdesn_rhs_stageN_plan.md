# TRACK: QDESN RHS Stage-N Plan (Post Stage-M)

Date: 2026-03-25  
Branch: `feature/qdesn-mcmc-alternative`  
Scope: static simulation/validation only (guardrail-locked, non-DLM)

## Baseline Context

Frozen baseline:
- Stage-M repair run tag:
  `stageMrepair-supervised-20260324-172932__git-d81c311`
- status:
  execution complete (`SUCCESS 56/56`) with strict MR3 gate failure.

MR3 blockers:
1. `scenario-level_shift_small__tau-0p05__prior-rhs__seed-231__res-tiny_d1_n8`
2. `scenario-toy_sine_small__tau-0p25__prior-rhs__seed-123__res-tiny_d1_n8`

Primary failing reason:
- `geweke_drift` (not collapse/finiteness).

## Stage-N Objective

Resolve the two remaining drift blockers under unchanged guardrails, then
reconfirm on the full 36-root grid before any default promotion.

## Non-Negotiable Guardrails

1. `pipeline.readout.input_mode = raw_y_lags`
2. `pipeline.decomposition.enabled = false`
3. RHS tau-init semantics remain numeric and guardrailed.
4. Collapse diagnostics remain active/persisted.

## Stage-N Execution

Manifest:
- `config/validation/qdesn_rhs_stageN_manifest.yaml`

Blocker grid:
- `config/validation/qdesn_rhs_stageN_blocker_grid.csv`

NR1 profile matrix:
- `config/validation/qdesn_rhs_stageN_profiles.yaml`

Runner:
- `scripts/run_qdesn_rhs_stageN_wave.R`

Pipeline order:
1. NR1: blocker-only profile matrix (4 profiles).
2. NR2: blocker reconfirm with NR1 winner (same 2 roots).
3. NR3: full 36-root reconfirm with NR1 winner.

Gate for each stage:
- zero pair FAIL
- all pair comparison-eligible
- finite/domain all true
- zero trace-unavailable

## Promotion Rule

Promote candidate defaults only if NR3 strict gate passes.
If NR3 fails, keep Stage-M winner as non-promoted baseline and continue with
targeted kernel-level escalation.

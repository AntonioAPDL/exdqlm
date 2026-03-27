# TRACK: QDESN RHS Stage-O Wave (Paused Snapshot)

Date: 2026-03-27  
Branch: `feature/qdesn-mcmc-alternative`  
Scope: static simulation/validation only (guardrail-locked, non-DLM)

## Run Identity

- run_tag: `stageO-20260326-081449__git-d81c311`
- manifest: `config/validation/qdesn_rhs_stageO_manifest.yaml`
- analysis_root:
  `reports/qdesn_mcmc_validation/rhs_stageO_wave/stageO-20260326-081449__git-d81c311`
- results_root:
  `results/qdesn_mcmc_validation/rhs_stageO_wave/stageO-20260326-081449__git-d81c311`
- status at pause check: `Active process = no` (checked on 2026-03-27 04:28 EDT)

## Phase Progress At Pause

| Phase | Expected | Started | Running | Success | Fail | Done | % Complete |
|---|---:|---:|---:|---:|---:|---:|---:|
| O1 | 3 | 3 | 0 | 3 | 0 | 3 | 100.0% |
| O2 | 5 | 0 | 0 | 0 | 0 | 0 | 0.0% |
| O3 | 6 | 6 | 0 | 6 | 0 | 6 | 100.0% |
| O4 | 36 | 6 | 6 | 0 | 0 | 0 | 0.0% |

Operational interpretation:
- `O2` was intentionally skipped by policy (`skip_o2_if_o1_clean = true`).
- Completed roots: `9`
- Incomplete roots left from O4 launch: `6`
- Root status distribution at pause: `SUCCESS 9, RUNNING 6`

## Stalled-Run Evidence

- O4 artifact writes for the 6 active roots stopped around:
  `2026-03-26 09:21:39 EDT`
- No additional O4 file progress was observed through:
  `2026-03-27 04:28 EDT`
- Decision: run was treated as stalled and explicitly stopped to avoid
  wasting compute while RHS-prior model changes are prepared.

## O4 Roots Left In RUNNING State (at stop time)

1. `scenario-const_small__tau-0p05__prior-rhs__seed-123__res-tiny_d1_n8`
2. `scenario-const_small__tau-0p25__prior-rhs__seed-123__res-tiny_d1_n8`
3. `scenario-level_shift_small__tau-0p05__prior-rhs__seed-123__res-tiny_d1_n8`
4. `scenario-sin_asym_small__tau-0p05__prior-rhs__seed-123__res-tiny_d1_n8`
5. `scenario-toy_sine_small__tau-0p05__prior-rhs__seed-123__res-tiny_d1_n8`
6. `scenario-toy_sine_small__tau-0p25__prior-rhs__seed-123__res-tiny_d1_n8`

## Guardrail Reminder (Still Required)

1. Keep RHS tau-init/collapse guardrails active.
2. Keep non-DLM validation contract:
   - `pipeline.readout.input_mode = raw_y_lags`
   - `pipeline.decomposition.enabled = false`
3. Keep `init_log_tau` numeric-resolved semantics (`null` means unset fallback).

## Resume Point After RHS-Prior Model Changes

Use a **new** Stage-O run tag (fresh launch, no reuse of stalled O4 state):

```bash
Rscript scripts/run_qdesn_rhs_stageO_wave.R --no-plots
```

Health check:

```bash
Rscript scripts/healthcheck_qdesn_rhs_stageO_wave.R --run-tag <new_stageO_run_tag>
```


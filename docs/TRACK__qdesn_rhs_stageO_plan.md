# TRACK: QDESN RHS Stage-O Drift-Closure Plan (Optimal/Compute-Efficient)

Date: 2026-03-26  
Branch: `feature/qdesn-mcmc-alternative`  
Scope: static simulation/validation only (guardrail-locked, non-DLM)

## Why Stage-O Exists

Stage-N finished with strong execution health but failed strict promotion gate:

- execution: `46/46 SUCCESS`, `0 FAIL`;
- MR3 strict gate: `n_pair_fail=1`, `n_pair_eligible=35/36`;
- single blocker root:
  `scenario-sin_asym_small__tau-0p05__prior-rhs__seed-231__res-tiny_d1_n8`;
- blocker reason: `geweke_drift` (not collapse/finiteness).

Operational conclusion:
- this is now a narrow MCMC mixing/drift closure problem, not a pipeline stability problem.

## Stage-O Objective

Close the single remaining drift blocker with minimal extra compute and promote
RHS MCMC defaults only after one clean 36-root reconfirmation.

## Non-Negotiable Constraints

1. Keep RHS tau-init/collapse guardrails unchanged and active.
2. Keep non-DLM validation contract:
   - `pipeline.readout.input_mode = raw_y_lags`
   - `pipeline.decomposition.enabled = false`
3. Do not relax signoff thresholds to force a pass.
4. Promote defaults only after strict gate success on full reconfirmation.

## Optimal Strategy (Racing + Narrow Escalation)

Instead of another full broad sweep, Stage-O uses a tight funnel:

1. single-blocker racing on candidate kernels/settings;
2. short robustness check on nearby stress set;
3. single full reconfirmation only for the winner.

This minimizes wasted full-grid compute and isolates causal fixes.

## Stage-O Phases

### O0: Freeze Baseline + Forensics

Inputs to freeze:
- baseline defaults:
  `config/validation/qdesn_mcmc_compare_rhs_stageN_repair_winner.yaml`
- guardrail lock:
  `config/validation/qdesn_rhs_guardrail_lock.yaml`
- blocker root id:
  `scenario-sin_asym_small__tau-0p05__prior-rhs__seed-231__res-tiny_d1_n8`

Deliverable:
- immutable Stage-O baseline manifest with blocker root and Stage-N references.

### O1: Cheap Stochasticity Probe (Single Root)

Purpose:
- determine whether blocker is highly seed/start sensitive under current winner.

Run:
- 3 repeated single-root runs under Stage-N winner settings.
- no parameter changes yet; only chain/start randomness differs.

Gate:
- if `0/3 FAIL`: skip directly to O3 (no new tuning needed);
- otherwise proceed to O2 matrix.

### O2: Single-Root Candidate Matrix (Main Optimization Step)

Evaluate 5 candidates on the blocker root only:

1. `O2_A_baseline_replay`
2. `O2_B_adapt_heavier`
   - increase adaptation warmup;
   - slightly smaller adaptation step size;
   - slightly longer tau freeze during burn.
3. `O2_C_block_conservative`
   - tighter transformed RHS block widths;
   - extra transformed block passes;
   - larger `max_steps_out`/`max_shrink`.
4. `O2_D_long_chain_fallback`
   - longer burn/keep with O2_C geometry.
5. `O2_E_multistart_plus_C`
   - 4 short pilot starts (`init_from_vb` + perturbations),
   - select best pilot by drift score,
   - run full chain with O2_C geometry.

Selection rule (lexicographic):
1. zero pair FAIL;
2. comparison eligible true;
3. lower worst drift statistic (`geweke_absz`, `half_drift`);
4. higher minimum ESS across RHS key summaries;
5. lower runtime ratio.

### O3: Local Robustness Set (Compute-Limited)

Run winner from O2 on a 6-root stress set:
- `sin_asym_small`, taus `{0.05, 0.25}`, seeds `{123, 231, 321}`.

Gate:
- `pair_fail = 0`
- all eligible
- all finite/domain true
- no trace-unavailable

If O3 fails, return to O2 and choose next candidate.

### O4: Single Full Reconfirmation (36 Roots)

Run O3 winner once on full Stage-M expansion grid (36 roots).

Promotion gate (strict):
- execution `FAIL = 0`;
- pair `FAIL = 0`;
- all eligible;
- finite/domain all true;
- no trace-unavailable.

Runtime guardrail:
- median runtime ratio must not exceed Stage-N winner by more than 20%.

### O5: Escalation Only If Needed

If O4 fails, do not broaden search blindly.
Escalate only on transformed RHS block kernel design, e.g.:

- delayed-rejection on transformed (`log_tau`, `log_c2`) block;
- occasional independent proposal for transformed RHS block.

## Stage-O Required Artifacts

Planned files:

- `config/validation/qdesn_rhs_stageO_blocker_grid.csv`
- `config/validation/qdesn_rhs_stageO_stress6_grid.csv`
- `config/validation/qdesn_rhs_stageO_profiles.yaml`
- `config/validation/qdesn_rhs_stageO_manifest.yaml`
- `scripts/run_qdesn_rhs_stageO_wave.R`
- `scripts/healthcheck_qdesn_rhs_stageO_wave.R`
- `docs/TRACK__qdesn_rhs_stageO_wave.md`

## Implementation Status (2026-03-26)

Implemented artifacts:

- `config/validation/qdesn_rhs_stageO_blocker_grid.csv`
- `config/validation/qdesn_rhs_stageO_stress6_grid.csv`
- `config/validation/qdesn_rhs_stageO_o1_profiles.yaml`
- `config/validation/qdesn_rhs_stageO_o2_profiles.yaml`
- `config/validation/qdesn_rhs_stageO_manifest.yaml`
- `scripts/run_qdesn_rhs_stageO_wave.R`
- `scripts/healthcheck_qdesn_rhs_stageO_wave.R`

Default launch controls:
- `outer_workers: 6`
- `threads_per_worker: 1`

Launch:

```bash
Rscript scripts/run_qdesn_rhs_stageO_wave.R --no-plots
```

Health check:

```bash
Rscript scripts/healthcheck_qdesn_rhs_stageO_wave.R --run-tag <stageO_run_tag>
```

Latest execution snapshot:

- run_tag:
  `stageO-20260326-081449__git-d81c311`
- analysis_root:
  `reports/qdesn_mcmc_validation/rhs_stageO_wave/stageO-20260326-081449__git-d81c311`
- results_root:
  `results/qdesn_mcmc_validation/rhs_stageO_wave/stageO-20260326-081449__git-d81c311`
- state:
  paused/stopped on 2026-03-27 after stall in O4 (6 roots remained RUNNING).
- detailed handoff tracker:
  `docs/TRACK__qdesn_rhs_stageO_wave.md`

## Decision Policy

Promotion is binary:
- promote only if O4 strict gate passes;
- otherwise remain on Stage-N winner defaults and continue Stage-O escalation.

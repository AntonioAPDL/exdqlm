# TRACK: QDESN RHS Stage-M Repair Plan (Static Validation)

Date: 2026-03-23  
Branch: `feature/qdesn-mcmc-alternative`  
Scope: static simulation/validation only (no benchmark execution, no real pipeline promotion)

## 1) Current Snapshot

Stage-M canary run:
- run_tag: `stageMwave-20260323-180913__git-88c0369`
- canary roots: `12`
- canary strict gate: `FAIL`
- key gate counters:
  - `n_pair_fail = 2`
  - `n_pair_eligible = 10 / 12`
  - finite/domain checks: all true
  - trace-unavailable: `0`
- worst MCMC reason: `geweke_drift`

Failed roots from canary:
1. `level_shift_small`, `tau=0.25`, `rhs`, `seed=123`, `tiny_d1_n8`
2. `sin_asym_small`, `tau=0.50`, `rhs`, `seed=123`, `tiny_d1_n8`

Implication:
- this is a chain-mixing/signoff issue on specific roots;
- it is not a collapse/finiteness issue.

## 2) Non-Negotiable Guardrails

All relaunches in this plan must preserve:
1. `pipeline.readout.input_mode = raw_y_lags`
2. `pipeline.decomposition.enabled = false`
3. `vb.priors.beta.rhs.init_log_tau` resolves numeric (`0.0` unless explicit numeric override)
4. collapse diagnostics active and persisted (`tau`, `E_invV_med`, `beta_l2`, `beta_small_frac_1e4`, collapse flags)
5. no silent semantic changes to RHS init behavior

Reference:
- `docs/TRACK__rhs_tau_init_collapse_guardrails.md`
- `config/validation/qdesn_rhs_guardrail_lock.yaml`

## 3) Objective And Gates

Primary objective:
- recover canary strict gate on static validation while keeping guardrails intact.

Primary gate (required):
1. `n_pair_fail = 0`
2. all pairs `pair_comparison_eligible = TRUE`
3. finite/domain checks all true
4. trace-unavailable count `= 0`

Secondary diagnostics (tracked, not hard-blocking by themselves):
1. worst MCMC reason distribution
2. Geweke and half-drift tails
3. runtime ratio versus VB

## 4) Efficient Relaunch Strategy

Use a 3-phase progression. Do not rerun broad grids until failed-root repair clears.

### Phase MR1: Failed-Root-Only Repair Matrix

Grid:
- only the 2 failing roots from Stage-M canary.

Profiles:
1. `MR1_base_replay`
   - exact current Stage-M guardrailed defaults (reproducibility baseline).
2. `MR1_longer_chain`
   - increase RHS `n_burn`, `n_mcmc`.
3. `MR1_longer_chain_plus_mixing`
   - longer chain + narrower transformed RHS block widths + extra transformed block passes.
4. `MR1_longer_chain_plus_adapt`
   - profile 3 + longer width-adaptation warmup with conservative step size.

Winner rule:
- gate pass first (`0 FAIL`, all eligible, finite/domain true, no trace-unavailable);
- tie-break by lower worst Geweke and lower worst half-drift;
- runtime ratio only as third tie-break.

### Phase MR2: Canary Reconfirm (12 roots, seed 123)

Run full canary grid with MR1 winner defaults.

Decision:
- if canary strict gate passes, proceed to MR3;
- if canary fails, do one additional failed-root-only iteration with tighter matrix focused on remaining blockers.

### Phase MR3: Full Stage-M Expansion (36 roots)

Run only after MR2 pass.

Decision:
- if full gate passes: propose promoted static-validation candidate defaults;
- if full gate fails: no promotion, isolate failing subset and reopen MR1 on that subset.

## 5) Checklist

- [x] Freeze Stage-M canary evidence and failed-root list.
- [x] Confirm guardrail-resolved defaults artifact exists.
- [ ] Create failed-root-only grid for MR1.
- [ ] Create MR1 profile matrix config.
- [ ] Launch MR1 failed-root matrix.
- [ ] Select MR1 winner under strict gate and tie-break rules.
- [ ] Launch MR2 canary with MR1 winner.
- [ ] Evaluate MR2 strict gate.
- [ ] If MR2 pass, launch MR3 full expansion.
- [ ] Evaluate MR3 strict gate and promotion decision.
- [ ] Update tracker docs with results and final decision.

## 6) Operational Notes

1. Keep static-only scope:
   - no DLM-informed input;
   - no benchmark workflow branching in this wave.
2. Keep run artifacts separated by phase:
   - `reports/qdesn_mcmc_validation/rhs_stageM_repair_wave/<run_tag>/...`
3. Persist all manifests and table outputs before moving phases.

## 7) Expected Outcome

Best-case:
- MR1 fixes both blockers;
- MR2 canary passes;
- MR3 full expansion is attempted immediately.

Conservative-case:
- MR1 fixes one blocker;
- MR2 still fails on one root;
- one additional targeted MR1 iteration needed before broad rerun.

# REPORT: QDESN Validation Repair Wave 2 (2026-03-31)

Date: 2026-03-31  
Branch: `feature/qdesn-mcmc-alternative`  
Run tag: `qdesn-validation-repair-wave2-20260331__git-49c96b4`

## 1) Purpose

Execute the first post-audit structural repair candidate under a strict staged funnel:

1. hard-root canary;
2. severe quartet only if the canary improves materially;
3. full 6-root harness only if the severe quartet improves materially.

This wave is the first direct implementation of the Phase 2 audit conclusion that the next patch should target shared `gamma/sigma` traversal behavior in the static `exal` MCMC core.

## 2) What Changed

Package code:

- `R/exal_inference_config.R`
- `R/exal_mcmc_fit.R`

Test coverage:

- `tests/testthat/test-exal-mcmc.R`

Execution scaffolding:

- `config/validation/qdesn_validation_repair_wave2_manifest.yaml`
- `scripts/run_qdesn_validation_repair_wave2.R`

New kernel control:

- `mcmc_control$slice$core_update_mode = "gamma_sigma_gamma"`

New candidate behavior:

- preserve the narrower sigma movement associated with the `R2`-style drift-stable regime;
- add an extra gamma refresh inside each core pass:
  `gamma -> sigma -> gamma`
- keep the default historical mode untouched:
  `sigma_then_gamma`

## 3) Validation Scope

Profiles:

- `R0_legacy_anchor`
- `R4_gamma_sigma_bridge`

Stages:

- `S1_canary`
- `S2_severe_quartet`
- `S3_full_six`

Actual progression:

- `S1_canary` ran
- `S2_severe_quartet` did not run
- `S3_full_six` did not run

Reason:

- the candidate failed the canary gate, so the staged funnel stopped immediately by design

## 4) Operational Health

The wave was operationally clean.

- stage execution: `COMPLETED`
- operational pass: `TRUE`
- timeouts: `0`
- runner errors: `0`
- finite/domain regressions: none
- collapse regressions: none

Key supervisor outputs:

- overall summary:
  `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave2/qdesn-validation-repair-wave2-20260331__git-49c96b4/summary/repair_wave2_results.md`
- stage status:
  `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave2/qdesn-validation-repair-wave2-20260331__git-49c96b4/status/S1_canary_status.json`
- canary transition:
  `reports/qdesn_mcmc_validation/qdesn_validation_repair_wave2/qdesn-validation-repair-wave2-20260331__git-49c96b4/stages/S1_canary/screen_runs/qdesn-validation-repair-wave2-20260331__git-49c96b4__S1_canary/tables/phase35_transitions_R4_gamma_sigma_bridge.csv`

## 5) Canary Result

Target root:

- `dlm_constV_bigW @ tau=0.05 exal ridge`

Comparison against the anchor:

| metric | anchor | bridge candidate | delta | read |
|---|---:|---:|---:|---|
| signoff | `FAIL` | `FAIL` | none | candidate did not clear the hard root |
| min ESS core | `6.25` | `4.06` | `-2.19` | worse |
| max Geweke core | `10.74` | `1.22` | `-9.53` | much better |
| max half drift core | `0.53` | `0.98` | `+0.45` | materially worse |
| runtime (s) | `2.452` | `3.445` | `+0.993` | about `1.40x` |

Gate result:

- `gate_pass = FALSE`
- `gate_reason = canary_not_improved_enough`

Why the gate failed:

- the candidate stayed `FAIL`;
- the candidate reduced Geweke sharply, but it did not improve the root in the required overall direction;
- ESS dropped;
- half-drift worsened substantially;
- the candidate therefore failed the intended Phase 2 target:
  improve mixing without recreating drift instability

## 6) Main Takeaways

1. The canary did exactly what it was supposed to do: stop a bad candidate before we spent compute on the severe quartet or full harness.
2. The new bridge mode is a real structural traversal change, but it is still too local a change to solve the hard root.
3. The result strengthens the Phase 2 audit conclusion that the blocker is not fixed by minor traversal reshuffling around the current local kernel.
4. This candidate improved one dimension of chain quality (`Geweke`) while worsening the two that mattered for the gate (`ESS` and `half_drift`).
5. The next candidate should come from a different family than the bridge mode.

## 7) Recommended Next Move

Do next:

1. keep the Wave 2 scaffolding and legacy anchor;
2. treat `gamma_sigma_gamma` as tested but not promotable;
3. move to the next candidate family, not another bridge/width variation;
4. prioritize one of:
   - a more substantive shared-core reparameterization / blocked move;
   - a readout conditioning / preconditioning patch targeted at `tiny_d1_n8`;
5. keep the same staged funnel:
   canary first, then quartet, then full 6-root harness only if the canary wins.

Do not do next:

- do not rerun the severe quartet for this bridge candidate;
- do not promote the bridge mode into defaults;
- do not restart broad QDESN validation from this result.

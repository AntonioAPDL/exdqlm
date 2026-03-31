# PLAN: QDESN Validation Phase 4 Split-Prior Zero-FAIL Screen (2026-03-31)

Date: 2026-03-31  
Branch: `feature/qdesn-mcmc-alternative`  
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1) Purpose

Run the next broad repair wave as a split-prior zero-FAIL screen that:

1. uses the best current transformed-sigma candidate as the baseline anchor;
2. stops treating ridge and `rhs_ns` as one knob set;
3. targets `FAIL -> WARN` as a valid success direction;
4. avoids rerunning families that already failed as lead ideas;
5. uses the server efficiently without reintroducing orchestration risk.

## 2) Main Findings We Are Building On

From the completed Family-B screen:

- the strongest shared-core pattern is transformed sigma plus gamma-focused extra-pass tuning;
- that pattern helped the severe quartet but stalled on the full 6-root harness;
- the remaining `FAIL` roots split naturally into ridge and `rhs_ns` subproblems;
- global QR was not a winner, but ridge-only QR still looks promising;
- standalone bridge and standalone conditioning families are already exhausted.

That means the next wave should be:

- transformed-sigma-based;
- split by prior family;
- zero-FAIL-oriented;
- staged on the severe quartet first.

## 3) Zero-FAIL Objective

Success definition for this wave:

- `WARN` is acceptable;
- the primary target is to eliminate `FAIL` rows;
- a candidate does not need to create all `PASS` rows to be useful;
- the first concrete milestone is reducing the fixed 6-root harness below the current `5 FAIL` level;
- the preferred milestone is `<= 3 FAIL`;
- the stretch milestone is `0 FAIL`.

## 4) What We Are Not Retesting

Explicitly out of scope:

- standalone `gamma_sigma_gamma` bridge reruns;
- standalone diagonal conditioning;
- standalone QR-whitening as the lead idea;
- global one-profile-for-all-priors tuning;
- old `X10` / `X3` / `X8` promotion reruns;
- longer chains alone as the main lever.

These ideas already taught us what they can teach.

## 5) Main Pain Clusters To Target

### Ridge cluster

`dlm_constV_bigW @ tau=0.05 exal ridge`

- main blockers: `geweke_drift`, `half_chain_drift`
- best clue: QR support and sigma-focused transformed-sigma tuning each helped locally

`dlm_constV_smallW @ tau=0.95 exal ridge`

- main blockers: `low_ess`, `high_autocorrelation`, `geweke_drift`
- best clue: this root likely wants ridge-only ESS recovery, not the same treatment as `bigW`

### RHS-NS cluster

`dlm_ar1V @ tau=0.95 exal rhs_ns`

- main blockers: `geweke_drift`, `half_chain_drift`, residual rhs instability

`dlm_constV_smallW @ tau=0.95 exal rhs_ns`

- main blockers: `low_ess`, `high_autocorrelation`, `half_chain_drift`

`dlm_constV_bigW @ tau=0.95 al rhs_ns`

- main blocker: rhs-side `geweke_drift` only

Interpretation:

- ridge wants its own geometry/mixing help;
- `rhs_ns` wants a mix of core stabilization and rhs-path cleanup;
- one global profile is no longer the right abstraction.

## 6) Candidate Family

The new family is:

- split-prior transformed-sigma hybrids

Shared baseline:

- transformed sigma stays on;
- no standalone bridge;
- no global QR;
- no historical pre-repair anchor.

The baseline anchor is now the current best working profile:

- `R0_current_best_anchor`
- exact `R8_logsigma_gamma_focus` behavior

All new candidates must beat that anchor.

## 7) Candidate Schedule

### Baseline anchor

`R0_current_best_anchor`

- exact transformed-sigma gamma-focus baseline from Family-B
- included only as the live comparison anchor

### New hybrid candidates

`R15_split_prior_hybrid`

- ridge: sigma-focused transformed-sigma tuning
- `rhs_ns`: current best gamma-focused transformed-sigma tuning
- purpose: clean split between ridge and `rhs_ns` without QR

`R16_split_prior_hybrid_ridge_qr`

- same as `R15`
- add QR whitening only for ridge
- purpose: help the ridge hard roots without dragging `rhs_ns`

`R17_split_prior_hybrid_ridge_qr_pass1`

- ridge: QR whitening plus one extra ridge-only core pass
- `rhs_ns`: same as `R15`
- purpose: target the small-`W` ridge low-ESS/high-ACF root

`R18_split_prior_rhsns_overlay`

- ridge: same as `R15`
- `rhs_ns`: stronger freeze/adapt/block-pass overlay
- purpose: attack the residual `rhs_ns` fail cluster directly

`R19_split_prior_rhsns_overlay_ridge_qr`

- combine `R18` rhs-path overlay with ridge-only QR
- purpose: best broad hybrid guess across both remaining subclusters

`R20_split_prior_rhsns_multistart_ridge_qr`

- same as `R19`
- add one mild `rhs_ns` multistart edge layer
- purpose: expensive but high-value test for the residual rhs-heavy failures

`R21_split_prior_ridge_chain_qr`

- ridge: QR plus modest ridge-only chain extension
- `rhs_ns`: same as `R15`
- purpose: test whether the remaining ridge ESS problem is now close enough that a modest ridge-only runtime increase can remove `FAIL`

## 8) Stage Design

### Stage S1: severe quartet broad screen

Scope:

- anchor + all new split-prior candidates
- 4 roots in `all_four`

Why start here:

- the old hard-canary stage was too narrow;
- the best Family-B profile cleared the quartet but not the full 6-root harness;
- the severe quartet is now the right first filter.

Advance rule:

- only advance candidates that beat the current-best anchor on the severe quartet;
- require at least one net severe-root improvement;
- keep the top `4` survivors.

### Stage S2: fixed 6-root zero-FAIL screen

Scope:

- anchor + the top `4` quartet survivors
- the fixed 6-root micro-pilot harness

Advance rule:

- this is the decision stage;
- use it to identify whether any candidate reduces the fail set below the current-best anchor;
- preferred threshold is `<= 4 FAIL`;
- stretch threshold is `<= 3 FAIL`.

## 9) Resource Plan

Server capacity:

- `64` CPU cores available

Execution plan:

- keep profile execution sequential at the supervisor level for robustness;
- use `campaign_workers = 4` inside each campaign;
- use `threads_per_worker = 1`;
- keep plots off;
- keep per-profile timeout protection on.

Why this is efficient:

- stage 1 is broad but only uses 4 roots;
- stage 2 uses the full fixed 6-root harness only for survivors;
- the root-level worker model is already proven stable;
- this keeps overnight compute focused on useful combinations instead of rerunning dead families.

## 10) Logging Requirements

This wave must leave a clean artifact trail:

- per-stage candidate-selection tables;
- per-stage MCMC config summaries;
- per-profile execution tables;
- root-level transitions and diag-shift tables;
- correct transformed-sigma telemetry in the fit summaries.

That telemetry fix is part of this implementation because the previous Family-B run proved the configs were reaching the runner but the saved control object was not recording them fully.

## 11) Success Criteria

This wave is a success if it gives us any of these:

1. one candidate with fewer full-6 `FAIL` roots than the current-best anchor;
2. a clear ridge winner and a clear `rhs_ns` winner that should be merged into a follow-on patch;
3. a clean rejection of split-prior tuning as the next lead idea, which would justify moving to a deeper blocked/shared-core redesign.

## 12) Main Files

Plan and tracker:

- `docs/REPORT__qdesn_validation_phase3_family_b_screen_20260331.md`
- `docs/PLAN__qdesn_validation_phase4_split_prior_screen_20260331.md`
- `docs/TRACK__qdesn_validation_repair_20260331.md`

Automation:

- `scripts/run_qdesn_validation_phase4_split_prior_screen.R`
- `config/validation/qdesn_validation_phase4_split_prior_screen_manifest.yaml`

## 13) Bottom-Line Recommendation

This is the right next wave.

It keeps the best transformed-sigma pattern, stops repeating the families that already failed, turns the objective into the right one (`FAIL` removal, not universal `PASS`), and finally tests the repair idea that the current evidence is pointing to:

- split ridge and `rhs_ns`,
- keep transformed sigma,
- add ridge-specific geometry help,
- add `rhs_ns`-specific path cleanup,
- and let the full 6-root harness decide.

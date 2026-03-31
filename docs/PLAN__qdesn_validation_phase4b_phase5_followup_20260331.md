# PLAN: QDESN Validation Phase 4B + Phase 5 Follow-Up (2026-03-31)

Date: 2026-03-31  
Branch: `feature/qdesn-mcmc-alternative`  
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1) Purpose

Turn the completed Phase 4 split-prior result into the next efficient repair program.

This follow-up has two linked goals:

1. confirm whether `R18_split_prior_rhsns_overlay` is now the correct operational baseline on the full fixed 6-root harness;
2. search only the still-unresolved core-mixing space instead of repeating dead families.

## 2) Current Read

Phase 4 gave one real improvement:

- `R18_split_prior_rhsns_overlay` reduced the severe quartet from `4 FAIL` to `3 FAIL`
- runtime inflation was low enough to stay operationally attractive
- the improved root was `dlm_ar1V @ tau=0.95 exal rhs_ns`, which moved from `FAIL` to `WARN`

That means:

- the `rhs_ns` overlay from `R18` is worth keeping;
- the remaining blocker is no longer “all split-prior tuning”;
- the remaining blocker is now the narrower core-triad:
  - `dlm_constV_bigW @ tau=0.05 exal ridge`
  - `dlm_constV_smallW @ tau=0.95 exal ridge`
  - `dlm_constV_smallW @ tau=0.95 exal rhs_ns`

## 3) What We Are Not Repeating

Out of scope for this follow-up:

- rerunning the full Phase 4 schedule;
- rerunning dead QR-led families;
- rerunning mild multistart as a lead idea;
- rerunning chain-only or ridge-only chain extension as the main lever;
- reopening the branch-wide validation ladder.

These are already well characterized enough for now.

## 4) Program Structure

### Phase 4B: full-6 confirmation

Compare only:

- `R0_current_best_anchor`
- `R18_split_prior_rhsns_overlay`

Scope:

- the fixed 6-root micro-pilot harness from the closeout lineage

Purpose:

- check whether the `R18` quartet win survives contact with the sentinels;
- determine whether `R18` should become the new operational baseline for the next screens.

Success condition:

- `R18` reduces the full-6 fail count below the anchor, with `WARN` acceptable and runtime still controlled.

### Phase 5: core-triad screen

Keep `R18` as the baseline profile and screen only the remaining unresolved roots.

Root set:

1. `dlm_constV_bigW @ tau=0.05 exal ridge`
2. `dlm_constV_smallW @ tau=0.95 exal ridge`
3. `dlm_constV_smallW @ tau=0.95 exal rhs_ns`

Purpose:

- isolate the real remaining problem;
- tune only the active core-mixing levers;
- avoid burning compute on already-fixed or already-exhausted roots.

## 5) Phase 4B Design

### Profiles

`R0_current_best_anchor`

- exact current-best transformed-sigma gamma-focus baseline

`R18_split_prior_rhsns_overlay`

- exact best Phase 4 split-prior overlay

### Gate

Treat `WARN` as acceptable.

`R18` is considered a usable full-6 baseline if:

- `total_fail_n <= 4`
- `sentinel_fail_n <= 1`
- `runtime_inflation <= 0.35`
- `fail_reduction >= 0.20`
- `severe_improved_n >= 1`

If `R18` misses the gate, the result is still scientifically useful, but `R18` should remain a local Phase 4 result rather than the new baseline.

## 6) Phase 5 Design

### Baseline

`R30_r18_baseline`

- exact `R18` behavior

### Candidate family

All Phase 5 candidates are descendants of `R18`.

Common rules:

- keep transformed sigma enabled;
- keep the successful `rhs_ns` overlay structure from `R18`;
- do not reintroduce QR as the lead idea;
- do not use multistart as the lead idea;
- do not use chain-length inflation as the lead idea.

### Candidate schedule

`R31_r18_rhsns_pass2`

- keep ridge identical to `R18`
- increase `rhs_ns` core passes from `1 -> 2`
- target: `constV_smallW exal rhs_ns`

`R32_r18_rhsns_softpass2`

- same `rhs_ns` extra-pass idea as `R31`
- soften `rhs_ns` core widths modestly
- target: improve ESS without worsening half-drift

`R33_r18_ridge_pass1_balanced`

- keep `rhs_ns` identical to `R18`
- give ridge one extra core pass with only mild width changes
- target: both ridge roots without the cost of a chain-length step

`R34_r18_ridge_pass2_soft`

- keep `rhs_ns` identical to `R18`
- give ridge two softer passes
- target: the persistent drift/Geweke ridge canary

`R35_r18_combined_balanced`

- combine `R31`-style rhs help with `R33`-style ridge help
- target: simultaneous improvement across the full triad

`R36_r18_combined_soft`

- combine `R32`-style rhs help with `R34`-style ridge help
- target: the highest-coverage core-mixing variant in the wave

## 7) Phase 5 Stage Ladder

### Stage S1: core-triad broad screen

Profiles:

- `R30` baseline
- `R31` through `R36`

Roots:

- the exact 3-root unresolved core-triad only

Advance rule:

- keep the top `2` survivors
- require:
  - `total_fail_n <= 2`
  - `runtime_inflation <= 0.60`
  - `fail_reduction >= 0.34`
  - `severe_improved_n >= 1`

### Stage S2: full-6 confirmation for triad survivors

Profiles:

- `R30` baseline
- top `2` Stage-S1 survivors

Roots:

- the full fixed 6-root harness

Advance rule:

- keep the top `1` final candidate
- require:
  - `total_fail_n <= 4`
  - `sentinel_fail_n <= 1`
  - `runtime_inflation <= 0.50`
  - `fail_reduction >= 0.20`
  - `severe_improved_n >= 1`

If nothing passes, the follow-up still succeeds as a narrowing exercise and tells us to leave configuration-only tuning behind.

## 8) Resource Plan

Use the already-proven staged runner and per-campaign worker model.

Phase 4B:

- supervisor level: sequential
- `campaign_workers = 4`
- `threads_per_worker = 1`
- no plots

Phase 5:

- supervisor level: sequential
- `campaign_workers = 3`
- `threads_per_worker = 1`
- no plots

This keeps the search broad enough to be informative while staying well inside the server capacity already proven stable in earlier screens.

## 9) Logging And Artifact Requirements

Both follow-up waves must preserve the current study standards:

- per-stage selection summaries
- per-stage MCMC config summaries
- per-profile execution tables
- per-profile rank tables
- root-level transition tables
- result summaries at the workspace root

The implementation will reuse the generic staged runner so these artifacts remain directly comparable with Phases 3 and 4.

## 10) Success Criteria

This follow-up is successful if it gives any of the following:

1. `R18` wins the full-6 confirmation and becomes the new baseline;
2. one Phase 5 triad candidate reduces the unresolved triad from `3 FAIL` to `<= 2 FAIL` and survives the full-6 check;
3. the full-6 follow-up proves that only the `rhs_ns` overlay is worth keeping, which cleanly narrows the next true code-change family.

## 11) Bottom-Line Recommendation

This is the right next move.

It keeps the one Phase 4 improvement that clearly worked, applies the user’s real objective (`WARN` is acceptable, remove `FAIL`), and narrows the next screen to the exact unresolved roots instead of replaying already-rejected families.

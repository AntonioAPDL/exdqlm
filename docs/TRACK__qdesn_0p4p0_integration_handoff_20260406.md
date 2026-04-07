# TRACK: QDESN 0.4.0 Integration Handoff

Date: 2026-04-06
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`
Supersedes as day-to-day handoff: `docs/TRACK__qdesn_dynamic_exdqlm_crossstudy_validation.md`

## 1) Purpose

Provide the concise continuation point for QDESN validation and development on the
`0.4.0`-synced integration branch.

This branch already contains:

- the updated shared `0.4.0` base;
- QDESN compatibility work merged on top of that base.

This handoff exists so we do **not** have to treat the older branch-local validation tracker as the
main working document on this branch.

## 2) Authoritative Carry-Forward State

Authoritative prior branch:

- branch:
  - `feature/qdesn-mcmc-alternative`
- worktree:
  - `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`
- final closeout commit:
  - `1591bd5`

Authoritative completed dynamic validation run:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-full-20260406-163041__git-85760fe`
- campaign summary:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_validation/qdesn-dynamic-exdqlm-crossstudy-full-20260406-163041__git-85760fe/20260406-163050__git-85760fe/summary/qdesn_dynamic_crossstudy_summary.md`
- comparison summary:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_validation/qdesn-dynamic-exdqlm-crossstudy-full-20260406-163041__git-85760fe/20260406-163050__git-85760fe/comparison_vs_reference/comparison_summary.md`

Authoritative completed-state summary:

- dynamic exdqlm-aligned scope:
  - confirmed and completed
- root execution:
  - `36/36 SUCCESS`
- fit rows:
  - `144/144`
- fit signoff mix:
  - `29 PASS`
  - `69 WARN`
  - `46 FAIL`
- root comparison readiness:
  - `31/36` comparison-eligible-any
  - `11/36` comparison-eligible-full
- recommendation:
  - `COMPARISON_READY_WITH_DOCUMENTED_DYNAMIC_FAIL_BAND`

## 3) What Is Settled

These points should be treated as settled carry-forward knowledge unless the `0.4.0` integration
branch disproves them:

- the intended comparison-facing study is the **dynamic** exdqlm-aligned surface;
- the static exdqlm cross-study is historical side work, not the main deliverable;
- the canonical dynamic reference surface currently mirrored is:
  - scenario:
    - `dlm_constV_smallW`
  - families:
    - `gausmix`, `laplace`, `normal`
  - taus:
    - `0.05`, `0.25`, `0.95`
  - fit horizons:
    - `lastTT500`, `lastTT5000`
- the mirrored QDESN matrix is:
  - `18` dynamic cells
  - `2` priors
  - `36` roots
  - `144` fit rows
- the orchestration/root-stall problem was already fixed before the successful dynamic run;
- the remaining blocker after the completed run is **fit-level comparison quality**, not basic
  execution stability.

## 4) Current Best Read Of Remaining Scientific Debt

Carry-forward fail-band summary from the completed dynamic run:

- total remaining fit `FAIL` rows:
  - `46 / 144`
- best high-level read:
  - `rhs_ns` is healthier than `ridge`
  - `al` is healthier than `exal`
  - `lastTT500` is healthier than `lastTT5000`

Most problematic carry-forward slices:

- `normal`, `tau=0.95`, `lastTT5000`, `ridge`
- `laplace`, `tau=0.05`, `lastTT5000`, `ridge`
- `laplace`, `tau=0.95`, `lastTT5000`, `ridge`
- `normal`, `tau=0.05`, `lastTT5000`, `ridge`

## 5) Recommended Move-Forward On This Branch

Do **not** resume from the older branch by assumption alone.

Because this branch includes the `0.4.0` shared-base integration, the next correct sequence is:

1. confirm the dynamic helper stack still runs cleanly on this branch;
2. reproduce the dynamic smoke contract first on this branch;
3. only then decide whether the completed broad dynamic run should be:
   - accepted as carry-forward evidence only, or
   - rerun/revalidated on this branch;
4. if the broad dynamic surface is rerun on this branch, treat the old result as the baseline
   reference and focus follow-up only on the documented `46`-row fail band.

## 6) Working Rules

- keep the study on the **dynamic** exdqlm-aligned surface;
- do not reopen the static cross-study as the primary deliverable;
- do not restart broad exploratory family search without first confirming integration-branch
  parity on the dynamic smoke path;
- prefer concise branch-local carry-forward notes over reusing older branch-specific live-run
  trackers as the primary handoff surface.

## 7) Read First On This Branch

1. `docs/TRACK__qdesn_0p4p0_integration_handoff_20260406.md`
2. `docs/TRACK__qdesn_dynamic_exdqlm_crossstudy_validation.md`
3. `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_implementation_and_smoke_20260406.md`
4. `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_validation_20260406.md`
5. `docs/REPORT__qdesn_exdqlm_dynamic_scope_correction_20260406.md`

## 8) Immediate Next Decision

For continued QDESN work on this branch, the immediate decision should be:

- **update/validate the dynamic runner stack against the `0.4.0` integration branch first**

not:

- reopen the old static study, or
- jump straight into another debt-only cleanup wave without branch-parity validation.

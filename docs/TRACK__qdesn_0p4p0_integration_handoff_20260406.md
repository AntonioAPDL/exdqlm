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

## 2) Source Of Truth Hierarchy

For continuation work on this integration branch, use the following evidence order:

1. this handoff tracker:
   - `docs/TRACK__qdesn_0p4p0_integration_handoff_20260406.md`
2. the detailed historical dynamic relaunch tracker:
   - `docs/TRACK__qdesn_dynamic_exdqlm_crossstudy_validation.md`
3. the completed dynamic campaign outputs on the predecessor branch/worktree:
   - campaign summary:
     - `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_validation/qdesn-dynamic-exdqlm-crossstudy-full-20260406-163041__git-85760fe/20260406-163050__git-85760fe/summary/qdesn_dynamic_crossstudy_summary.md`
   - comparison summary:
     - `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_validation/qdesn-dynamic-exdqlm-crossstudy-full-20260406-163041__git-85760fe/20260406-163050__git-85760fe/comparison_vs_reference/comparison_summary.md`
   - campaign progress table:
     - `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_validation/qdesn-dynamic-exdqlm-crossstudy-full-20260406-163041__git-85760fe/20260406-163050__git-85760fe/tables/campaign_progress.csv`
4. the checked-in dynamic grid and runner assets on this branch:
   - `config/validation/qdesn_dynamic_exdqlm_crossstudy_grid.csv`
   - `R/qdesn_dynamic_exdqlm_crossstudy.R`
   - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R`

## 3) Branch/Worktree Lineage

Current active continuation point:

- branch:
  - `feature/qdesn-mcmc-alternative-0p4p0-integration`
- worktree:
  - `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`
- role:
  - synced continuation branch after incorporating the updated shared `0.4.0` base plus QDESN
    compatibility work

Predecessor branch used for the latest completed validation campaign:

- branch:
  - `feature/qdesn-mcmc-alternative`
- worktree:
  - `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`
- final validation tracker closeout commit:
  - `1591bd5`

Important boundary:

- the old worktree is historical reference only for this continuation step;
- it should be read for evidence, not modified;
- this integration branch is now the active QDESN validation/development base.

## 4) Authoritative Carry-Forward State

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
  - `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_validation/qdesn-dynamic-exdqlm-crossstudy-full-20260406-163041__git-85760fe/20260406-163050__git-85760fe/summary/qdesn_dynamic_crossstudy_summary.md`
- comparison summary:
  - `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_validation/qdesn-dynamic-exdqlm-crossstudy-full-20260406-163041__git-85760fe/20260406-163050__git-85760fe/comparison_vs_reference/comparison_summary.md`

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

Latest completed campaigns to carry forward:

- corrected smoke validation:
  - `qdesn-dynamic-exdqlm-crossstudy-smoke-20260406-threadsfix__git-eb141cc`
  - `4/4 SUCCESS` roots
  - `16` fit rows
  - `6 PASS / 8 WARN / 2 FAIL`
- full dynamic mirrored campaign:
  - `qdesn-dynamic-exdqlm-crossstudy-full-20260406-163041__git-85760fe`
  - `36/36 SUCCESS` roots
  - `144` fit rows
  - `29 PASS / 69 WARN / 46 FAIL`

## 5) What Is Settled

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

## 6) Current In-Scope Case Set

Canonical in-scope grid on this branch:

- source file:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_grid.csv`
- root count:
  - `36`

Current case lattice:

- scenario:
  - `dlm_constV_smallW`
- root kind:
  - `dynamic`
- families:
  - `gausmix`
  - `laplace`
  - `normal`
- taus:
  - `0.05`
  - `0.25`
  - `0.95`
- fit horizons:
  - `500`
  - `5000`
- priors:
  - `ridge`
  - `rhs_ns`

Per-root fit methods in scope:

- `vb/exal`
- `mcmc/exal`
- `vb/al`
- `mcmc/al`

Therefore:

- root cases:
  - `1 x 3 x 3 x 2 x 2 = 36`
- fit-level rows:
  - `36 x 4 = 144`

## 7) Health Convention Used Here

Preserved fit-level convention from the completed campaign:

- `PASS`
  - fit signoff grade is healthy-comparable
- `WARN`
  - fit is usable but still flagged for review
- `FAIL`
  - fit is not comparison-eligible under the current signoff rules

Root/case-level status for this handoff is derived from the campaign root summary fields:

- `PASS / healthy`
  - `root_status = SUCCESS` and `root_comparison_eligible_full = TRUE`
- `WARN / needs review`
  - `root_status = SUCCESS`, `root_comparison_eligible_any = TRUE`, and
    `root_comparison_eligible_full = FALSE`
- `FAIL / broken or inconsistent for comparison`
  - `root_status = FAIL`, or
  - `root_status = SUCCESS` with `root_comparison_eligible_any = FALSE`
- `PENDING / not yet rerun here`
  - the case has carry-forward evidence from the predecessor branch, but has not yet been rerun on
    `feature/qdesn-mcmc-alternative-0p4p0-integration`

## 8) Current Case Inventory

### 8.1 Carry-forward completed-state inventory from the predecessor branch

Root execution status:

- complete:
  - `36/36`
- execution healthy:
  - `36/36 SUCCESS`
- execution failures:
  - `0/36`

Root comparison-health inventory:

- `PASS / healthy`:
  - `11/36`
- `WARN / needs review`:
  - `20/36`
- `FAIL / not comparison-ready`:
  - `5/36`

Fit-level comparison-health inventory:

- `PASS`:
  - `29/144`
- `WARN`:
  - `69/144`
- `FAIL`:
  - `46/144`

### 8.2 Exact root cases by category

#### PASS / healthy (`11`)

- `gausmix`, `tau=0.05`, `fit_size=500`, `rhs_ns`
- `gausmix`, `tau=0.05`, `fit_size=5000`, `rhs_ns`
- `gausmix`, `tau=0.25`, `fit_size=500`, `ridge`
- `gausmix`, `tau=0.25`, `fit_size=5000`, `ridge`
- `gausmix`, `tau=0.95`, `fit_size=500`, `rhs_ns`
- `laplace`, `tau=0.25`, `fit_size=500`, `ridge`
- `laplace`, `tau=0.25`, `fit_size=5000`, `ridge`
- `normal`, `tau=0.05`, `fit_size=5000`, `rhs_ns`
- `normal`, `tau=0.25`, `fit_size=500`, `ridge`
- `normal`, `tau=0.25`, `fit_size=5000`, `ridge`
- `normal`, `tau=0.95`, `fit_size=500`, `rhs_ns`

#### WARN / needs review (`20`)

- `gausmix`, `tau=0.05`, `fit_size=500`, `ridge`
- `gausmix`, `tau=0.05`, `fit_size=5000`, `ridge`
- `gausmix`, `tau=0.25`, `fit_size=500`, `rhs_ns`
- `gausmix`, `tau=0.25`, `fit_size=5000`, `rhs_ns`
- `gausmix`, `tau=0.95`, `fit_size=500`, `ridge`
- `gausmix`, `tau=0.95`, `fit_size=5000`, `ridge`
- `gausmix`, `tau=0.95`, `fit_size=5000`, `rhs_ns`
- `laplace`, `tau=0.05`, `fit_size=500`, `ridge`
- `laplace`, `tau=0.05`, `fit_size=500`, `rhs_ns`
- `laplace`, `tau=0.05`, `fit_size=5000`, `rhs_ns`
- `laplace`, `tau=0.25`, `fit_size=500`, `rhs_ns`
- `laplace`, `tau=0.95`, `fit_size=500`, `ridge`
- `laplace`, `tau=0.95`, `fit_size=500`, `rhs_ns`
- `laplace`, `tau=0.95`, `fit_size=5000`, `rhs_ns`
- `normal`, `tau=0.05`, `fit_size=500`, `ridge`
- `normal`, `tau=0.05`, `fit_size=500`, `rhs_ns`
- `normal`, `tau=0.25`, `fit_size=500`, `rhs_ns`
- `normal`, `tau=0.25`, `fit_size=5000`, `rhs_ns`
- `normal`, `tau=0.95`, `fit_size=500`, `ridge`
- `normal`, `tau=0.95`, `fit_size=5000`, `rhs_ns`

#### FAIL / not comparison-ready (`5`)

- `laplace`, `tau=0.05`, `fit_size=5000`, `ridge`
- `laplace`, `tau=0.25`, `fit_size=5000`, `rhs_ns`
- `laplace`, `tau=0.95`, `fit_size=5000`, `ridge`
- `normal`, `tau=0.05`, `fit_size=5000`, `ridge`
- `normal`, `tau=0.95`, `fit_size=5000`, `ridge`

### 8.3 Pending on this integration branch

Branch-local rerun status on `feature/qdesn-mcmc-alternative-0p4p0-integration`:

- rerun here:
  - `0/36`
- pending rerun here:
  - `36/36`

Interpretation:

- all `36` root cases have carry-forward evidence from the predecessor branch;
- none have yet been rerun on this synced `0.4.0` integration branch;
- therefore every case is still `PENDING` for branch-local parity/revalidation, even though the
  predecessor branch completed the full campaign successfully.

## 9) Current Best Read Of Remaining Scientific Debt

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

Best high-level axis read from the completed run:

- `rhs_ns` is healthier than `ridge`
- `al` is healthier than `exal`
- `lastTT500` is healthier than `lastTT5000`
- the hardest band is concentrated in long-horizon `ridge` cases

## 10) Recommended Move-Forward On This Branch

Do **not** resume from the older branch by assumption alone.

Because this branch includes the `0.4.0` shared-base integration, the next correct sequence is:

1. confirm the dynamic helper stack still runs cleanly on this branch;
2. reproduce the dynamic smoke contract first on this branch;
3. only then decide whether the completed broad dynamic run should be:
   - accepted as carry-forward evidence only, or
   - rerun/revalidated on this branch;
4. if the broad dynamic surface is rerun on this branch, treat the old result as the baseline
   reference and focus follow-up only on the documented `46`-row fail band.
5. keep the first rerun scope narrow:
   - smoke/parity first
   - then broad rerun only if branch-level parity is confirmed
6. if rerun parity is good, prioritize debt cleanup on the `5` fail roots and the broader
   long-horizon `ridge` fail band before reopening any broader search.

## 11) Working Rules

- keep the study on the **dynamic** exdqlm-aligned surface;
- do not reopen the static cross-study as the primary deliverable;
- do not restart broad exploratory family search without first confirming integration-branch
  parity on the dynamic smoke path;
- prefer concise branch-local carry-forward notes over reusing older branch-specific live-run
  trackers as the primary handoff surface.

## 12) Read First On This Branch

1. `docs/TRACK__qdesn_0p4p0_integration_handoff_20260406.md`
2. `docs/TRACK__qdesn_dynamic_exdqlm_crossstudy_validation.md`
3. `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_implementation_and_smoke_20260406.md`
4. `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_validation_20260406.md`
5. `docs/REPORT__qdesn_exdqlm_dynamic_scope_correction_20260406.md`

## 13) Immediate Next Decision

For continued QDESN work on this branch, the immediate decision should be:

- **update/validate the dynamic runner stack against the `0.4.0` integration branch first**

not:

- reopen the old static study, or
- jump straight into another debt-only cleanup wave without branch-parity validation.

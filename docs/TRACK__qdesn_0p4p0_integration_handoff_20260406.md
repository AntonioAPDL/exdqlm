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

Preserved fit-level convention:

- `PASS`
  - healthy-comparable
- `WARN`
  - usable with review
- `FAIL`
  - not comparison-eligible under the current signoff rules

Root/case-level status on this branch is derived from the completed branch-local rerun:

- `PASS / healthy`
  - `root_status = SUCCESS`
  - `root_comparison_eligible_full = TRUE`
- `WARN / needs review`
  - `root_status = SUCCESS`
  - `root_comparison_eligible_any = TRUE`
  - `root_comparison_eligible_full = FALSE`
- `FAIL / broken or inconsistent`
  - `root_status = FAIL`, or
  - `root_status = SUCCESS` with `root_comparison_eligible_any = FALSE`

## 8) Current Branch-Local Validation State

Completed branch-local smoke/parity rerun:

- `qdesn-dynamic-exdqlm-crossstudy-smoke-rerun-20260406-214100__git-288390b`
- `4/4 SUCCESS` roots
- `16` fit rows
- `7 PASS / 8 WARN / 1 FAIL`

Completed branch-local broad rerun:

- `qdesn-dynamic-exdqlm-crossstudy-full-rerun-20260406-215700__git-288390b`
- `36/36` roots completed
- `34/36 SUCCESS`
- `2/36 FAIL`
- `144/144` fit rows emitted
- `37 PASS / 65 WARN / 42 FAIL`
- `33/36` comparison-eligible-any
- `8/36` comparison-eligible-full
- recommendation:
  - `HOLD_QDESN_DYNAMIC_EXDQLM_WITH_GAPS`

Current branch-local root inventory:

- `PASS / healthy`:
  - `8/36`
- `WARN / needs review`:
  - `24/36`
- `FAIL / broken or inconsistent`:
  - `4/36`
    - `2` outright root failures
    - `2` successful but noneligible roots

Current branch-local fit inventory:

- `PASS`:
  - `37/144`
- `WARN`:
  - `65/144`
- `FAIL`:
  - `42/144`

## 9) Promotion Decision After The Broad Rerun

No new **global** baseline promotion is justified yet.

Reason:

- the branch-local rerun improved:
  - fit FAIL rows:
    - `46 -> 42`
  - roots with any usable comparison:
    - `31 -> 33`
- but regressed on:
  - outright root execution:
    - `36/36 SUCCESS -> 34/36 SUCCESS`
  - fully comparison-ready roots:
    - `11 -> 8`

Working decision:

- keep the current dynamic cross-study defaults as the branch-local default baseline
- allow only stage-local promotion when a challenger clearly improves the source baseline on its
  targeted residual slice

## 10) Remaining Scientific Debt

Current residual fail surface:

- fit FAIL rows:
  - `42`
- fail-carrying roots:
  - `28`

Dominant remaining patterns:

- long-horizon `gausmix` MCMC `exal` crash and drift pockets
- long-horizon `ridge` residual instability pockets on `laplace/normal`, mostly VB tail with a
  small `mcmc exal` drift pocket
- long-horizon `rhs_ns` residual fail pockets on `laplace/normal`
- short-horizon mixed `laplace/normal` tail pockets

Best high-level axis read remains:

- `rhs_ns` is healthier than `ridge`
- `al` is healthier than `exal`
- `fit_size=500` is healthier than `fit_size=5000`

## 11) Recommended Move-Forward On This Branch

The next move is no longer another full rerun.

The next move is a targeted fail-closure wave that:

1. starts from the completed branch-local broad rerun as the source baseline
2. targets only the remaining fail and noneligible pockets
3. uses challenger-only local profiles
4. promotes only when a challenger beats the source baseline on that stage

Targeted fail-closure assets:

- report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_rerun_closeout_and_residual_inventory_20260406.md`
- plan:
  - `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_targeted_fail_closure_wave_20260406.md`
- manifest:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave_manifest.yaml`
- runner:
  - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave.R`
- detached launcher:
  - `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave.R`
- healthcheck:
  - `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave.R`

Targeted fit-fail closure preflight is now validated on this branch:

- prepare-only run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-fitfail-20260407-000441__git-0f80d87`
- verified stage sizes:
  - `S1=5`
  - `S2=5`
  - `S3=6`
  - `S4=4`
  - `S5=8`
- verified coverage:
  - `28/28` fail-carrying roots
  - `42/42` fail rows
- preflight:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_fit_fail_closure_wave/qdesn-dynamic-exdqlm-crossstudy-fitfail-20260407-000441__git-0f80d87/launch/qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_preflight.md`

## 12) Working Rules

- keep the study on the **dynamic** exdqlm-aligned surface
- keep the current defaults as the source baseline unless a local challenger clearly wins
- do not reopen the static cross-study as the main deliverable
- do not spend compute on another broad rerun right now
- do not reopen generic tuning search for one universal rescue profile

## 13) Immediate Next Decision

For continued QDESN work on this branch, the immediate decision is now:

- **run the targeted fit-fail closure wave**
- **summarize the resulting branch-local PASS / WARN / FAIL inventory after it completes**
- **only then decide which local stage winners, if any, deserve promotion**

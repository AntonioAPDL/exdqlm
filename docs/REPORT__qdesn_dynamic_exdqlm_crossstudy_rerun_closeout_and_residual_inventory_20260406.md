# REPORT: QDESN Dynamic exdqlm Cross-Study Rerun Closeout and Residual Inventory

Date: 2026-04-06  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Executive Read

The branch-local broad dynamic rerun on the synced `0.4.0` base is complete and scientifically
useful, but it is not a clean full closeout.

Completed branch-local rerun:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-full-rerun-20260406-215700__git-288390b`
- scope:
  - mirrored dynamic exdqlm surface
  - `36` roots
  - `144` fit rows
- execution:
  - `34/36 SUCCESS`
  - `2/36 FAIL`
  - `144/144` fit rows emitted
- fit signoff:
  - `37 PASS`
  - `65 WARN`
  - `42 FAIL`
- root comparison readiness:
  - `33/36` comparison-eligible-any
  - `8/36` comparison-eligible-full
- recommendation:
  - `HOLD_QDESN_DYNAMIC_EXDQLM_WITH_GAPS`

## 2) What Improved

Relative to the predecessor broad dynamic run on `feature/qdesn-mcmc-alternative`:

- fit-level FAIL rows improved:
  - `46 -> 42`
- roots with any usable comparison improved:
  - `31 -> 33`
- total per-fit improvements:
  - `24`

High-value improvements were concentrated in local MCMC behavior rather than broad root-status
stability:

- multiple long-horizon `mcmc` rows improved from `FAIL -> WARN`
- several long-horizon `mcmc` rows improved from `WARN -> PASS`
- the strongest net gains were on:
  - `gausmix @ tau=0.25`
  - `laplace` long-horizon MCMC rows
  - `normal` long-horizon MCMC `al` rows

## 3) What Regressed

The rerun is not globally promotable over the predecessor baseline because improvement was mixed:

- root execution regressed:
  - `36/36 SUCCESS -> 34/36 SUCCESS`
- fully comparison-ready roots regressed:
  - `11 -> 8`
- total per-fit regressions:
  - `12`

The two outright failed roots were both long-horizon `gausmix` cases:

- `gausmix`, `tau=0.05`, `fit_size=5000`, `ridge`
- `gausmix`, `tau=0.25`, `fit_size=5000`, `rhs_ns`

The failure mechanism was local `mcmc_exal` numerical breakage rather than orchestration:

- `exal_mcmc_fit::latent_v returned 1 invalid draws`
- follow-on signoff:
  - `missing_chain_diagnostics`

## 4) Current Health Convention

Fit-level convention is preserved exactly:

- `PASS`
  - healthy-comparable
- `WARN`
  - usable with review
- `FAIL`
  - not comparison-eligible under the current signoff rules

Root-level inventory for this report uses the existing campaign summary fields:

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

## 5) Current Residual Inventory

Root-level inventory:

- `PASS / healthy`:
  - `8`
- `WARN / needs review`:
  - `24`
- `FAIL / broken or inconsistent`:
  - `4`
    - `2` outright root failures
    - `2` successful but noneligible roots

Fit-level inventory:

- `PASS`:
  - `37/144`
- `WARN`:
  - `65/144`
- `FAIL`:
  - `42/144`

Residual fail-root surface:

- fail rows:
  - `42`
- roots carrying at least one fail row:
  - `28`

Axis summary of the remaining fail band:

- family:
  - `gausmix: 17`
  - `normal: 13`
  - `laplace: 12`
- fit size:
  - `5000: 25`
  - `500: 17`
- prior:
  - `ridge: 24`
  - `rhs_ns: 18`
- likelihood:
  - `exal: 28`
  - `al: 14`
- inference:
  - `vb: 23`
  - `mcmc: 19`

Root-level residual split:

- outright failed roots:
  - `2`
- successful but noneligible roots:
  - `2`
- comparison-eligible-any but still not full-ready:
  - `24`

## 6) Which Ideas Worked Best

The broad rerun confirms the same main scientific direction as the predecessor dynamic run:

- the current default `0.4.0`-integrated runner stack is operationally usable on the intended
  dynamic surface;
- `rhs_ns` remains healthier than `ridge` at the broad comparison level;
- `al` remains healthier than `exal`;
- the best carry-forward improvements still come from local MCMC rescue behavior, especially on
  long-horizon rows.

High-value surviving patterns worth reusing:

- ridge longer-chain rescue around the `R512/R612` neighborhood
- softer ridge geometry around the `0.51 / 0.19` gamma-sigma band
- rhs local soft-freeze rescue around the surviving `freeze90` pattern
- staged local rescue rather than one new global retune

## 7) Which Ideas Did Not Help

The rerun also made the weak directions clearer:

- a second broad global rerun did not clear the remaining fail surface
- broad retuning is now lower value than targeted residual rescue
- the main unresolved pockets are not random:
  - long-horizon `gausmix` MCMC `exal`
  - long-horizon `ridge` residual instability, mostly VB tail plus a small `mcmc exal` drift pocket
  - long-horizon `rhs_ns` residual fail pockets
  - short-horizon mixed laplace/normal tail pockets

So the next move should not be another full rerun and should not reopen generic tuning search.

## 8) Highest-Expected-Value Directions

The targeted residual surface can be covered cleanly in five stages:

| Stage | Scope | Roots |
|---|---|---:|
| `S1` | `gausmix`, `fit_size=5000` fail band | `5` |
| `S2` | `gausmix`, `fit_size=500` fail band | `5` |
| `S3` | long-horizon `ridge` residual band on `laplace/normal` | `6` |
| `S4` | long-horizon `rhs_ns` fail band on `laplace/normal` | `4` |
| `S5` | short-horizon mixed `laplace/normal` tail band | `8` |

Together these cover:

- `28/28` fail-carrying roots
- without reopening already healthy full-ready roots

## 9) Baseline Promotion Decision

No new broad baseline promotion is justified yet.

Reason:

- the branch-local rerun improved the fail-row count and any-ready coverage,
- but it also introduced:
  - `2` outright root failures
  - lower full-ready coverage (`11 -> 8`)

Decision:

- keep the current dynamic cross-study defaults as the branch-local default baseline
- allow only stage-local promotion when a challenger clearly beats this baseline on its targeted
  residual slice

## 10) Recommended Next Move

Run a dedicated dynamic fit-fail closure wave that:

- uses the completed branch-local broad rerun as the source baseline
- reruns only the residual fail pockets
- uses challenger-only stage-local profiles
- promotes a stage-local baseline only when it beats the source baseline for that stage

Primary plan:

- `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_targeted_fail_closure_wave_20260406.md`

Primary implementation:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave_manifest.yaml`
- `scripts/run_qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave.R`
- `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave.R`
- `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave.R`

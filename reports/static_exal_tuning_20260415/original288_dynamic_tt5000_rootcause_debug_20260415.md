# Dynamic TT5000 Root-Cause Debug Checkpoint

Date: 2026-04-15

## Purpose

This note records the current root-cause investigation state for the unresolved
`dynamic / TT5000` replay pocket. The goal is to keep the debugging path
durable, reproducible, and explicit before any new relaunch.

## Confirmed Findings

### 1. The original replay was not fully exact-spec

The exact-spec replay helper was silently drifting older dynamic MCMC rows away
from their historical semantics:

- source configs that had **no explicit** `init_from_vb` or `init_from_isvb`
  flags were being replayed with `init_from_vb = TRUE`
- source configs that had `mh$adapt_interval` but **no explicit**
  `mh$adapt` field were being replayed with `mh_adapt = FALSE` due to partial
  matching of `mh$adapt` against `mh$adapt_interval`

This affected a large share of the dynamic `TT5000` replay rows.

### 2. The `computationally singular` failure was real and package-level

Representative `TT5000` VB and MCMC rows both failed inside the dynamic
VB/VB-init path before the main MCMC chain meaningfully started.

The direct crash path was:

- `exdqlmLDVB() -> .run_dynamic_dqlm_cavi() -> dlm_df() -> solve.default()`
- `exdqlmMCMC() -> VB init -> .run_dynamic_dqlm_cavi() -> dlm_df() -> solve.default()`

The most concrete bug identified there was in `dlm_df()`:

- the smoother used the wrong transition index in the backward pass
- it also used a raw `solve(R)` on matrices that can be nearly singular

### 3. The singular smoother bug is patched locally

The package repo now has a local patch that:

- corrects the smoother indexing in `dlm_df()`
- replaces the raw inverse with SVD-based regularized inversion
- adds shared dynamic covariance/variance regularization helpers
- threads those helpers through the dynamic R-side filter/smoother code paths

Current local package files:

- `R/utils.R`
- `R/exdqlmISVB.R`
- `R/exdqlmLDVB.R`
- `R/exdqlmMCMC.R`
- `tests/testthat/test-dlm-df-smoother-regression.R`

### 3b. The remaining `chi_nonfinite` failure was also package-level

After the `dlm_df()` fix, the representative `TT5000` dQLM MCMC failure moved
from the singular smoother into the first latent-`u_t` update:

- `dqlm_mcmc_pre_uts (iter=1) invalid state before chi update`
- then, in the earlier unfixed branch, downstream
  `dqlm_mcmc_uts (iter=1) chi has non-finite values`

The direct source was the **dynamic dQLM MCMC FFBS sampler** inside
`exdqlmMCMC()`:

- the `dqlm.ind = TRUE` state-sampling branch still used the old raw dynamic
  filter/backward-sampler
- that branch still relied on unregularized covariance propagation,
  raw SVD inversion of `R`, and raw square roots of sampled smoother covariances
- this allowed the sampled state path to become non-finite before `u_t` was
  updated

That branch is now patched to use the same regularized covariance contract as
the already-hardened dynamic smoother paths.

### 4. The replay wiring drift is patched locally

The validation repo now has local patches so regenerated configs preserve
historical semantics instead of silently rewriting them:

- legacy MCMC rows with no explicit init flags now preserve legacy
  `init_from_isvb = TRUE`
- the replay no longer forces `init_from_vb = TRUE` for those rows
- `mh$adapt` is only set when it exists explicitly in the source config

Current local validation files:

- `tools/merge_reports/LOCAL_original288_exactspec_multiseed_helpers_20260412.R`
- `tools/merge_reports/LOCAL_original288_exactspec_multiseed_run_row_20260412.R`
- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_run_row_20260414.R`

The exact-spec prepare was rerun, and representative regenerated config
`full_row_1017_run_config.rds` now shows:

- `init_from_vb = NA`
- `init_from_isvb = TRUE`
- `legacy_mcmc_init_default = TRUE`
- `mh_adapt = NA`
- `mh_adapt_interval = 25`

## Current Validation State

### What is fixed

- the direct `computationally singular` crash in `dlm_df()` has been addressed
  in the local package patch
- the stale unregularized dynamic dQLM MCMC FFBS branch has been addressed in
  the local package patch
- regenerated validation configs now preserve historical init/adapt semantics

### What is not yet fixed

The full `TT5000` validation pocket is **not yet declared repaired end to end**.

What remains open is validation readiness, not the original immediate crash:

- the exact-spec helper/config lineage now looks correct
- the package-level dynamic smoother/state-sampler paths are materially more
  stable
- but the narrow dynamic `TT5000` repair lane has **not** yet been relaunched
  from this patched checkpoint
- a full exact-spec/historical repair rerun is still needed before the dynamic
  comparison hole can be called closed

### Additional signal

- representative bounded VB rerun no longer failed immediately on the old
  singular-solve path; it ran long enough to hit the external timeout
- representative TT5000 dQLM MCMC probe on the hard case
  `full_row_1017_run_config.rds`, with VB init disabled to isolate the MCMC
  state sampler, now completes `1` burn iteration plus `1` kept iteration in
  about `16` seconds with:
  - finite `theta`
  - finite `map.standard.forecast.errors`
  - no `chi_nonfinite` / pre-`u_t` crash
- representative TT5000 exDQLM MCMC probe on
  `full_row_1021_run_config.rds`, also with VB init disabled, now completes the
  same short run in about `16` seconds with finite `theta` and finite map
  forecast errors
- representative legacy-init short probe on `full_row_1017_run_config.rds`
  enters the `ISVB` initialization phase and no longer crashes immediately on
  the old singular path; the bounded run times out while still working
- representative exDQLM VB short probe on `full_row_0877_run_config.rds`
  likewise runs without reproducing the old immediate singular crash, but did
  not finish inside the external timeout window
- targeted package regression checks now pass for:
  - `tests/testthat/test-dlm-df-smoother-regression.R`
  - `tests/testthat/test-dynamic-dqlm-mcmc-regression.R`
  - `tests/testthat/test-dqlm-reduced-paths.R`
  - `tests/testthat/test-dqlm-vb-sim-smoke.R`
  - `tests/testthat/test-ffbs-indexing-parity.R`
  - `tests/testthat/test-mcmc-backend-routing.R`
  - `tests/testthat/test-mcmc-dynamic-strict-parity.R`

## Interpretation

This is no longer a vague “everything is broken” state.

The dynamic `TT5000` problem currently looks like a stack of two issues:

1. replay/config lineage drift that pushed older rows into the wrong init/adapt
   semantics
2. a real package-level numerical bug in `dlm_df()` / dynamic smoothing
3. a second real package-level numerical bug in the dynamic dQLM MCMC FFBS
   branch used before the first `u_t` update

Both package-level numerical bugs are now patched locally. The remaining risk is
whether the **full exact-spec TT5000 validation workflow** now behaves well
enough end to end to justify resuming the narrow repair lane.

## Relaunch Decision

No new repair relaunch has been started from this checkpoint.

That is intentional: the package-level fixes now look materially better, but the
next safe move is still a **small post-fix validation smoke**, not an immediate
full rerun. Launching the whole repair lane without that last checkpoint would
still be avoidable risk.

## Next Safe Step

The next step should now be narrow and validation-first:

1. run a tiny post-fix smoke over representative dynamic `TT5000` rows across:
   - `dqlm / mcmc`
   - `exdqlm / mcmc`
   - `dqlm / vb`
   - `exdqlm / vb`
2. confirm those rows now avoid the old immediate singular / non-finite
   failures under the current exact-spec helper wiring
3. if the smoke remains stable, relaunch the narrow dynamic `TT5000` repair lane
4. refresh the replay-based comparison once repaired rows are available

# PLAN: QDESN Static exdqlm Cross-Study Wave 3 Fit-Fail Closure

Date: 2026-04-04  
Branch: `feature/qdesn-mcmc-alternative`

## 1) Goal

Close the remaining static cross-study scientific debt as efficiently as possible by:

1. keeping the shared static QDESN setup as the default baseline;
2. fixing any code-path debt that is falsely creating `FAIL` rows;
3. using local tuning only on the specific slices that still need it;
4. pushing every remaining case to at least `PASS` or `WARN`.

This is **not** another search for one generic profile that works everywhere.

## 2) Current Baseline And Promotion Rule

Shared default baseline:

- keep the shared static defaults as the default baseline
- the branch now includes an explicit `rhs_ns` diagnostics-path fix so the default baseline is
  evaluated without the old helper bug
- the fix is now validated on a representative `rhs_ns` smoke root:
  - both VB rows recover rhs diagnostics cleanly
  - with fresh run status, both rows downgrade from false `FAIL` to usable `WARN`

Completed local promotion from Wave-2 Stage 1:

- local ridge rescue reference:
  - `D410_ridge_rescue_reference`

Current non-promotion:

- no completed rhs-local profile from Wave-2 Stage 1 justified promotion over the shared default

Promotion rule for this wave:

- the shared default remains the default everywhere
- any local profile is promoted only for its own stage/slice if it clearly lowers the targeted
  stage FAIL count versus the shared default

## 3) Current Remaining FAIL Surface

Wave-1 source baseline:

- `72` roots materialized
- `66` root `SUCCESS`
- `6` root `FAIL`
- `130` fit `FAIL` rows

Remaining fit-level FAIL buckets:

1. `rhs_ns` VB diagnostics-path FAILs
   - `66` rows
   - `33` roots
2. ridge `exal/mcmc` stability FAILs
   - `24` rows
   - `24` roots
3. `rhs_ns` `mcmc` stability FAILs
   - `40` rows
   - `30` roots

Important interpretation:

- the old hard-fail band is still real in the source baseline, but Wave-2 Stage 1 already showed
  that it is no longer the central unresolved problem
- the remaining work is mostly fit-level closure, not root-level rescue

## 4) What Improved And What Did Not

What improved:

- Wave-2 Stage 1 rescued the `6/6` hard-fail probe roots in every completed profile
- `D410` emerged as the best completed local ridge rescue clue
- the fail surface is now well enough understood to split by debt type rather than by family

What did not help enough:

- `D420_softgamma_geometry`
- `D430_rhssoft_freeze90`
- `D440_crossover_softgamma_rhssoft`
- `D450_rhs_diagnostics_probe`

These should not be rerun unchanged.

## 5) Wave 3 Structure

Checked-in manifest:

- `config/validation/qdesn_static_exdqlm_crossstudy_fit_fail_closure_wave_manifest.yaml`

### Stage 1: `S1_rhs_vb_diagnostics_closure`

Purpose:

- verify that the `rhs_ns` diagnostics-path fix removes the false VB FAIL bucket under the shared
  default baseline

Root set:

- all `33` `rhs_ns` roots with source `rhs_diagnostics_missing` FAILs

Profiles:

- `F500_anchor_patched`

Expected outcome:

- the shared default should become the effective local baseline for this stage if it clears the
  false `rhs_diagnostics_missing` bucket on the full `33`-root slice

### Stage 2: `S2_ridge_exal_mcmc_closure`

Purpose:

- close the remaining ridge `exal/mcmc` FAIL slice using local ridge rescue candidates only

Root set:

- all `24` ridge `exal/mcmc` fail roots

Profiles:

- `F500_anchor_patched`
- `F510_ridge_rescue_reference`
- `F520_ridge_chain1200_laplace_focus`

### Stage 3: `S3_rhs_mcmc_tt100_closure`

Purpose:

- close the short-horizon `rhs_ns` `mcmc` FAIL slice with local rhs tuning

Root set:

- the `16` `rhs_ns` `mcmc` fail roots with `tt=100`

Profiles:

- `F500_anchor_patched`
- `F610_rhs_tt100_conservative_block`
- `F620_rhs_tt100_chain1200`

### Stage 4: `S4_rhs_mcmc_tt1000_closure`

Purpose:

- close the longer-horizon `rhs_ns` `mcmc` FAIL slice with local rhs tuning

Root set:

- the `14` `rhs_ns` `mcmc` fail roots with `tt=1000`

Profiles:

- `F500_anchor_patched`
- `F630_rhs_tt1000_conservative_block`
- `F640_rhs_tt1000_chain1200`

## 6) Why Each Candidate Is Included

| profile | why included |
|---|---|
| `F500_anchor_patched` | default shared baseline after the rhs-family diagnostics fix |
| `F510_ridge_rescue_reference` | best completed local ridge rescue from Wave-2 Stage 1 |
| `F520_ridge_chain1200_laplace_focus` | ridge hard-band hedge for the still-hard laplace `tt=1000` slice |
| `F610_rhs_tt100_conservative_block` | tighter rhs transformed-block schedule for the denser short-horizon rhs fail slice |
| `F620_rhs_tt100_chain1200` | isolates chain extension on the same short-horizon rhs slice |
| `F630_rhs_tt1000_conservative_block` | tighter rhs transformed-block schedule on the longer-horizon rhs slice |
| `F640_rhs_tt1000_chain1200` | isolates chain extension on the longer-horizon rhs slice |

## 7) Explicit Exclusions

These are intentionally excluded because they are already understood to be weak, redundant, or
misaligned with the remaining debt:

- no relaunch of the full `72`-root static surface
- no continuation of Wave-2 Stage 2 on the older `36`-root debt frame
- no exact rerun of:
  - `D420_softgamma_geometry`
  - `D430_rhssoft_freeze90`
  - `D440_crossover_softgamma_rhssoft`
  - `D450_rhs_diagnostics_probe`
- no reopening of the finished dynamic DLM tuning program

## 8) Compute Plan

Server policy:

- logical CPUs: `64`
- nested parallelism: `disabled`
- per-fit threads: `1`
- `postpred_threads`: `1`
- plots during campaign: `disabled`

Worker policy:

- default if no competing QDESN jobs: `8`
- fallback if other QDESN jobs are active: `6`
- hard cap: `8`

Expected footprint:

- Stage 1:
  - `33 roots x 1 profile = 33` root campaigns
- Stage 2:
  - `24 roots x 3 profiles = 72` root campaigns
- Stage 3:
  - `16 roots x 3 profiles = 48` root campaigns
- Stage 4:
  - `14 roots x 3 profiles = 42` root campaigns
- total:
  - `195` root campaigns

This is broad enough to close real remaining debt, but it is still much narrower than another
full-surface relaunch.

## 9) Outputs That Define “Done”

Required outputs:

1. preflight manifest + markdown
2. source fail-bucket inventory tables
3. stage grids and per-profile config materializations
4. stage profile metrics + ranking + recommendation summaries
5. stage execution status table
6. local baseline map
7. integrated fit-fail closure summary
8. completed manifest with stage-local promotion decisions

## 10) Acceptance Criteria

Operational success:

1. prepare-only passes cleanly
2. all four stages run to completion
3. stage metrics are directly comparable against the source baseline
4. local baseline recommendations are emitted explicitly

Scientific success is local, not global:

- Stage 1 succeeds if the patched shared default removes the false `rhs_diagnostics_missing` VB
  FAIL bucket
- Stage 2 succeeds if a ridge local profile reduces the ridge `exal/mcmc` FAIL count versus the
  shared default
- Stage 3 and Stage 4 succeed if a local rhs profile reduces the target `rhs_ns mcmc` FAIL count
  on that stage’s slice versus the shared default

Recommended end states:

- `PROMOTE_<profile>_AS_<stage>_LOCAL_BASELINE`
- or `KEEP_F500_anchor_patched_AS_<stage>_BASELINE`

## 11) Bottom Line

This wave is the right next move because it matches the real remaining problem:

- fix the false rhs-family diagnostics FAILs once
- keep the shared baseline as default
- apply local tuning only where completed evidence says it has real upside
- do not spend compute searching for a generic profile where the debt is already slice-specific

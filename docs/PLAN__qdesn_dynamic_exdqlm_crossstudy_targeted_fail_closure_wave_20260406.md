# PLAN: QDESN Dynamic exdqlm Cross-Study Targeted Fail-Closure Wave

Date: 2026-04-06  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Objective

Close the remaining dynamic cross-study fail surface on the synced `0.4.0` base without reopening
the full 36-root matrix.

Working rule:

- keep the current dynamic cross-study defaults as the source baseline
- do not search for a new one-size-fits-all global configuration
- allow only stage-local tuning where the residual evidence says it is justified

## 2) Source Baseline

Source run:

- `qdesn-dynamic-exdqlm-crossstudy-full-rerun-20260406-215700__git-288390b`

Source residual inventory:

- fit FAIL rows:
  - `42`
- fail-carrying roots:
  - `28`
- outright root failures:
  - `2`
- successful but noneligible roots:
  - `2`

## 3) Design Principles

1. do not rerun fully healthy roots
2. do not rerun the full `36`-root matrix
3. keep the current broad defaults as the source baseline
4. use challenger-only stages
5. compare every challenger directly against the completed branch-local source baseline
6. promote only if the challenger is clearly better on the targeted fail surface

## 4) Stage Layout

| Stage | Target surface | Roots | Why it exists |
|---|---|---:|---|
| `S1_gausmix_tt5000_fail_band` | `gausmix`, `fit_size=5000`, all fail rows | `5` | highest-value long-horizon crash and drift pocket |
| `S2_gausmix_tt500_fail_band` | `gausmix`, `fit_size=500`, all fail rows | `5` | short-horizon gausmix tail/noneligible pocket |
| `S3_ridge_tt5000_vb_tail_band` | `laplace/normal`, `fit_size=5000`, `ridge`, all fail rows | `6` | long-horizon ridge residual pocket, mostly VB-tail plus two MCMC exal drift rows |
| `S4_rhs_tt5000_fail_band` | `laplace/normal`, `fit_size=5000`, `rhs_ns`, all fail rows | `4` | long-horizon rhs local fail pocket |
| `S5_short_horizon_mixed_tail` | `laplace/normal`, `fit_size=500`, all fail rows | `8` | remaining short-horizon mixed tail pocket |

Coverage:

- `28/28` fail-carrying roots
- `42/42` fail rows included through stage selectors

## 5) Candidate Profiles

### Gausmix local rescue

| Profile | Purpose | Why included |
|---|---|---|
| `K510_gmix_balanced_rescue` | longer-chain ridge rescue + mild rhs soft-freeze rescue | safest high-value local MCMC carry-forward |
| `K520_gmix_softgamma_rescue` | softer ridge geometry + longer rhs local rescue | strongest plausible follow-up for gausmix exal drift/crash |

### Ridge VB tail rescue

| Profile | Purpose | Why included |
|---|---|---|
| `K530_ridge_vb_guard` | moderate ridge VB extension | cheapest direct answer to `vb_converged_false` tail fails |
| `K540_ridge_vb_guard_plus_softgamma` | stronger ridge VB guard plus softer ridge MCMC geometry | covers mixed long-horizon ridge rows that are not purely VB-only |

### RHS long-horizon local rescue

| Profile | Purpose | Why included |
|---|---|---|
| `K550_rhs_softfreeze_local` | mild rhs-only local rescue | lowest-risk rhs-specific follow-up |
| `K560_rhs_softfreeze_long` | longer-chain rhs-only rescue | strongest rhs-specific hedge still justified by prior evidence |

### Short-horizon mixed cleanup

| Profile | Purpose | Why included |
|---|---|---|
| `K570_mixed_short_guard` | ridge VB guard + rhs soft-freeze | efficient mixed short-horizon rescue |
| `K580_mixed_short_guard_plus_softgamma` | stronger mixed rescue including soft ridge geometry | only broader mixed candidate retained for the short tail |

## 6) Why These Candidates And Not Others

Explicitly excluded:

- another full `36`-root rerun
- a generic global retuning search
- re-testing obviously weak or already-retired families
- reopening healthy full-ready roots
- restore-RHS-init experiments:
  - the current defaults on this branch already include those init fields

This wave is therefore intentionally narrow:

- `10` challenger profile campaigns total
- `56` root-campaigns total
- all tied to already-observed residual gaps

## 7) Selection Rule

Per stage, compare each challenger against the completed branch-local source baseline using:

1. lower targeted FAIL rows
2. lower targeted FAIL roots
3. lower root-status FAIL count
4. lower noneligible-root count
5. higher comparison-eligible-full count
6. higher comparison-eligible-any count
7. lower total FAIL rows
8. higher PASS count
9. lower runtime as a final tie-break

If no challenger beats the source baseline on that stage, keep `SOURCE_BASELINE`.

## 8) Operational Plan

1. update trackers and closeout docs first
2. validate the staged wave in `prepare-only`
3. commit and push the documentation and orchestration changes
4. launch the wave in one detached supervised overnight batch
5. after completion, summarize stage-local `PASS / WARN / FAIL` outcomes and only then decide on
   stage-local promotion

## 9) Primary Assets

- report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_rerun_closeout_and_residual_inventory_20260406.md`
- canonical tracker:
  - `docs/TRACK__qdesn_0p4p0_integration_handoff_20260406.md`
- detailed tracker:
  - `docs/TRACK__qdesn_dynamic_exdqlm_crossstudy_validation.md`
- manifest:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave_manifest.yaml`
- runner:
  - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave.R`
- detached launcher:
  - `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave.R`
- healthcheck:
  - `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave.R`

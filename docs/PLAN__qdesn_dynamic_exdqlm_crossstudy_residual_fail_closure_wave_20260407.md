# PLAN: QDESN Dynamic exdqlm Cross-Study Residual Fail Closure Wave

Date: 2026-04-07  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Objective

Continue from the current branch-local validation state after the completed targeted fit-fail
closure wave.

Working rule:

- keep the current dynamic defaults as the global baseline
- carry forward only the local stage results that clearly improved the source baseline
- use a conservative local working control where a stage improved only ambiguously
- spend overnight compute only on the remaining fail surface

## 2) Effective Source State

The new overnight wave does **not** start from the broad rerun directly.

It starts from the merged effective baseline state built from:

- source broad rerun:
  - `qdesn-dynamic-exdqlm-crossstudy-full-rerun-20260406-215700__git-288390b`
- completed targeted wave:
  - `qdesn-dynamic-exdqlm-crossstudy-fitfail-20260407-000615__git-54c5009`

Effective carry-forward map:

| Prior Stage | Effective Source For New Wave | Why |
|---|---|---|
| `S1_gausmix_tt5000_fail_band` | `SOURCE_BASELINE` | challengers were worse on fail rows |
| `S2_gausmix_tt500_fail_band` | `K510_gmix_balanced_rescue` | clear improvement |
| `S3_ridge_tt5000_vb_tail_band` | `K540_ridge_vb_guard_plus_softgamma` | clear improvement |
| `S4_rhs_tt5000_fail_band` | `K550_rhs_softfreeze_local` | safer carry-forward control than `K560` |
| `S5_short_horizon_mixed_tail` | `K580_mixed_short_guard_plus_softgamma` | clear improvement |

Effective source inventory:

- fit FAIL rows:
  - `26`
- fail-carrying roots:
  - `17`
- root-status FAILs:
  - `2`
- compare-any roots:
  - `35`
- compare-full roots:
  - `19`
- successful-but-noneligible roots:
  - `0`

## 3) Design Principles

1. do not rerun the full `36`-root matrix
2. do not reopen already healthy roots
3. do not rerun exact weak profiles that already lost
4. search broadly only inside the surviving local neighborhoods
5. prioritize the remaining root-fail and long-horizon exal fail pockets first
6. keep a stable worker cap of `6`
7. promote only if a challenger clearly beats the effective source state for that stage

## 4) Stage Layout

Prepare-only validation confirmed the following residual stage sizes:

| Stage | Scope | Roots | Source FAIL Rows | Profiles |
|---|---|---:|---:|---:|
| `R1_gausmix_tt5000_residual` | `gausmix`, `fit_size=5000` | `5` | `9` | `4` |
| `R2_gausmix_tt500_residual` | `gausmix`, `fit_size=500` | `3` | `5` | `3` |
| `R3_ridge_tt5000_singleton_residual` | `normal`, `tau=0.95`, `fit_size=5000`, `ridge` | `1` | `2` | `3` |
| `R4_rhs_tt5000_residual` | `laplace/normal`, `fit_size=5000`, `rhs_ns` | `4` | `6` | `3` |
| `R5_short_horizon_mixed_residual` | `laplace/normal`, `fit_size=500` | `4` | `4` | `3` |

Total planned overnight breadth:

- target roots:
  - `17`
- target FAIL rows:
  - `26`
- challenger profiles:
  - `16`
- root-campaigns:
  - `56`

## 5) Candidate Families

### R1: Gausmix long-horizon residual

| Profile | Why included |
|---|---|
| `L610_gmix_long_vbguard_local` | cheapest broad gausmix-long escalation from the surviving `K510` neighborhood |
| `L620_gmix_long_vbguard_softgamma` | ridge softgamma plus rhs extension for mixed VB and MCMC failures |
| `L630_gmix_long_deep_rescue` | deepest overnight hedge for the two remaining gausmix root-fail cases |
| `L640_gmix_long_split_diag` | separates ridge and rhs behavior to test whether the long pocket is really mixed or split by prior |

### R2: Gausmix short-horizon residual

| Profile | Why included |
|---|---|
| `L650_gmix_short_vbguard_local` | cheapest direct answer to the remaining short ridge VB-tail rows |
| `L660_gmix_short_vbguard_softgamma` | tests whether short ridge residuals need geometry as well as VB guard |
| `L670_gmix_short_diag_mix` | broader short-horizon hedge while staying close to `K510` and `K580` |

### R3: Ridge long-horizon singleton

| Profile | Why included |
|---|---|
| `L710_ridge_long_chain_guard` | deeper ridge chain with strong VB guard |
| `L720_ridge_long_softgamma_plus` | strongest plausible single-root cleanup candidate |
| `L730_ridge_long_softgamma_deep` | extra chain-depth hedge kept because the stage is cheap |

### R4: RHS long-horizon residual

| Profile | Why included |
|---|---|
| `L740_rhs_long_vbguard_local` | safest follow-on from `K550` |
| `L750_rhs_long_vbguard_mid` | moderate rhs depth increase while preserving the safer geometry |
| `L760_rhs_long_vbguard_deep` | strongest overnight rhs-specific hedge still worth testing |

### R5: Short-horizon mixed residual

| Profile | Why included |
|---|---|
| `L770_short_mixed_local_mcmc` | cheapest post-`K580` follow-up |
| `L780_short_mixed_mid_mcmc` | moderate depth increase on both priors |
| `L790_short_mixed_softgamma_plus` | broadest short mixed residual hedge retained for overnight learning value |

## 6) Explicit Exclusions

Do **not** spend overnight compute on:

- another full dynamic rerun
- exact reruns of `K520`, `K530`, `K560`, or `K570`
- any static cross-study work
- any new one-size-fits-all global tuning search
- already healthy full-ready roots

## 7) Selection Rule

Per stage, compare each challenger against the effective source state using:

1. lower targeted FAIL rows
2. lower targeted FAIL roots
3. lower root-status FAIL count
4. lower noneligible-root count
5. higher comparison-eligible-full count
6. higher comparison-eligible-any count
7. lower total FAIL rows
8. higher PASS count
9. lower runtime as tie-break

If no challenger clearly beats the effective source state, keep that stage on its current source
selection.

## 8) Operational Plan

1. record the Wave-1 closeout and the effective carry-forward map in the trackers
2. validate the new residual-wave manifest in `prepare-only`
3. commit and push the doc and orchestration changes
4. launch the overnight run in one detached supervised batch
5. evaluate the new branch-local fail surface only after the wave completes

## 9) Primary Assets

- closeout report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_fit_fail_wave1_closeout_and_wave2_inventory_20260407.md`
- canonical handoff tracker:
  - `docs/TRACK__qdesn_0p4p0_integration_handoff_20260406.md`
- detailed dynamic tracker:
  - `docs/TRACK__qdesn_dynamic_exdqlm_crossstudy_validation.md`
- manifest:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_residual_fail_closure_wave_manifest.yaml`
- runner:
  - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave.R`
- detached launcher:
  - `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave.R`
- healthcheck:
  - `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave.R`

## 10) Ready-To-Launch Read

Prepare-only status:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-residualfail-20260407-025317__git-2078ff9`
- source mode:
  - `prior_fitfail_wave`
- verified source fail surface:
  - `26` FAIL rows on `17` roots
- verified stage sizes:
  - `5 / 3 / 1 / 4 / 4`
- verified total root-campaigns:
  - `56`

Decision:

- the overnight residual wave is validated and ready to launch

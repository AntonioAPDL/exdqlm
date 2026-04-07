# PLAN: QDESN Dynamic exdqlm Cross-Study Final Fail Closure Wave

Date: 2026-04-07  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Objective

Continue from the completed residual-wave state and spend overnight compute only on the final two
remaining fit-level FAIL rows.

Working rule:

- keep the current merged local baseline map as the source baseline
- promote a new local winner only if it clearly improves the exact remaining fail row and does not
  regress its nearby guard roots
- search only inside the surviving rhs-specific `mcmc_exal` neighborhoods
- do not reopen cleared gausmix or ridge pockets

## 2) Effective Source State

The new wave starts from the completed residual-wave local baseline map:

- source run:
  - `qdesn-dynamic-exdqlm-crossstudy-residualfail-20260407-025827__git-eed98f2`
- source mode:
  - `prior_fitfail_wave`
- source report root:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_residual_fail_closure_wave`

Current source inventory:

- fit FAIL rows:
  - `2`
- fail-carrying roots:
  - `2`
- root-status FAILs:
  - `0`

Exact remaining fail rows:

| Root | FAIL Row | Reason | Current Local Baseline |
|---|---|---|---|
| `root__dynamic__dlm_constV_smallW__normal__tau_0p05__lasttt_5000__qdesn_rhs_ns` | `mcmc_exal` | `geweke_drift; half_chain_drift` | `L760_rhs_long_vbguard_deep` |
| `root__dynamic__dlm_constV_smallW__normal__tau_0p95__lasttt_500__qdesn_rhs_ns` | `mcmc_exal` | `geweke_drift` | `L770_short_mixed_local_mcmc` |

## 3) Design Principles

1. do not rerun the full `36`-root matrix
2. do not reopen the already cleared `R1`, `R2`, or `R3` pockets
3. do not rerun dominated profiles:
   - `L740`, `L750`, `L780`, `L790`
4. keep the search rhs-specific and mcmc-specific
5. include nearby guard roots so a local fix is not accepted if it breaks the surrounding pocket
6. keep a stable worker cap of `6`
7. keep the existing detached launcher / healthcheck path for reproducibility

## 4) Stage Layout

The final wave uses two stages, each with one exact target row and three nearby guard roots:

| Stage | Exact Target | Guard Roots | Planned Profiles |
|---|---|---:|---:|
| `F1_rhs_long_normal_tail_final` | `normal tau=0.05 fit_size=5000 rhs_ns mcmc_exal` | `3` | `5` |
| `F2_rhs_short_normal_tail_final` | `normal tau=0.95 fit_size=500 rhs_ns mcmc_exal` | `3` | `5` |

Total planned overnight breadth:

- target fail rows:
  - `2`
- target fail roots:
  - `2`
- staged roots executed with guards:
  - `8`
- challenger profiles:
  - `10`
- root-campaigns:
  - `40`

## 5) Candidate Families

### F1: Long-horizon rhs normal lower-tail cleanup

Source local baseline:

- `L760_rhs_long_vbguard_deep`

Candidate profiles:

| Profile | Why included |
|---|---|
| `M810_rhs_long_freeze120_chain1400` | first pure chain-depth follow-up from `L760`; tests whether the remaining drift is mostly chain-length limited |
| `M820_rhs_long_freeze125_chain1500` | deeper version kept because the stage is small and the remaining row still shows both Geweke and half-chain drift |
| `M830_rhs_long_narrow1400` | same deeper chain, but slightly narrower rhs transformed-block widths to improve long-run mixing stability |
| `M840_rhs_long_narrow1500_diag5` | strongest rhs-only hedge: deeper chain plus narrower transformed blocks and one extra transformed pass |
| `M850_rhs_long_burnheavy1300` | burn-focused alternative to separate burn-in stabilization from total chain-length effects |

### F2: Short-horizon rhs normal upper-tail cleanup

Source local baseline:

- `L770_short_mixed_local_mcmc`

Candidate profiles:

| Profile | Why included |
|---|---|
| `M910_short_rhs_freeze100_chain1100` | smallest rhs-only escalation from `L770`; tests whether the last Geweke miss needs only modest depth |
| `M920_short_rhs_freeze105_chain1200` | deeper follow-up if the short remaining row is still chain-length limited |
| `M930_short_rhs_narrow1100` | moderate chain increase plus narrower rhs widths to attack short-horizon drift without reopening ridge geometry |
| `M940_short_rhs_narrow1200_diag5` | strongest short rhs hedge: deeper chain, narrower rhs widths, and one extra transformed pass |
| `M950_short_rhs_freeze110_chain1000` | freeze-only variant retained for learning value in case warmup stabilization matters more than added keep draws |

## 6) Explicit Exclusions

Do **not** spend overnight compute on:

- another broad rerun
- any new gausmix search
- any new ridge search
- `L740`, `L750`, `L780`, or `L790`
- generic all-prior or all-family tuning

## 7) Selection Rule

Per stage, compare each challenger against the current merged local baseline using:

1. lower targeted FAIL rows
2. lower targeted FAIL roots
3. lower root-status FAIL count
4. lower noneligible-root count
5. higher comparison-eligible-full count
6. higher comparison-eligible-any count
7. lower total FAIL rows across the stage guard set
8. higher PASS count
9. lower runtime as tie-break

If no challenger clearly beats the source state, keep the current local baseline.

## 8) Reproducibility Rules

1. keep all source/run tags in the manifest
2. validate with `prepare-only` before any real launch
3. use the existing detached launcher and healthcheck scripts
4. record the live launch metadata in the trackers after launch
5. commit doc + manifest changes before launch and the launch metadata after launch

## 9) Primary Assets

- closeout report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_residual_fail_wave2_closeout_and_wave3_inventory_20260407.md`
- canonical handoff tracker:
  - `docs/TRACK__qdesn_0p4p0_integration_handoff_20260406.md`
- detailed dynamic tracker:
  - `docs/TRACK__qdesn_dynamic_exdqlm_crossstudy_validation.md`
- manifest:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_final_fail_closure_wave_manifest.yaml`
- runner:
  - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave.R`
- detached launcher:
  - `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave.R`
- healthcheck:
  - `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave.R`

## 10) Ready-To-Launch Read

This wave is ready to proceed if `prepare-only` confirms:

- source mode:
  - `prior_fitfail_wave`
- source fail surface:
  - `2` FAIL rows on `2` roots
- stage sizes:
  - `4 / 4`
- total root-campaigns:
  - `40`

Decision:

- if preflight matches the expected final residual surface, launch the final overnight wave in one
  detached supervised batch

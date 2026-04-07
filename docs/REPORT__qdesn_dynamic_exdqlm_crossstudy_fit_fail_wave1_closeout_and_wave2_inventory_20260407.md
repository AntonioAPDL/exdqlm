# REPORT: QDESN Dynamic exdqlm Cross-Study Fit-Fail Wave 1 Closeout and Wave 2 Residual Inventory

Date: 2026-04-07  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## Status Note

This report is preserved as the historical closeout for targeted Wave 1.

It is not the current branch-level status summary. For the current authoritative baseline and
comparison-ready state, use:

- `docs/TRACK__qdesn_0p4p0_integration_handoff_20260406.md`
- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_root_override_reconciliation_20260407.md`
- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_main_comparison_outputs_20260407.md`

## 1) Executive Read

The first targeted dynamic fit-fail closure wave completed cleanly and produced real local
improvements, but not every stage recommendation should be promoted blindly.

Completed wave:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-fitfail-20260407-000615__git-54c5009`
- source baseline:
  - `qdesn-dynamic-exdqlm-crossstudy-full-rerun-20260406-215700__git-288390b`
- execution:
  - `5/5` stages complete
  - `10/10` challenger profiles complete
  - `56/56` root-campaigns executed

Main decision:

- promote only the stage winners that **clearly** improved the source baseline
- keep `S1` on source baseline
- treat `S4` as unresolved for scientific promotion and carry forward the safer local control
  instead of the raw stage recommendation

## 2) What Improved

Clear stage-local wins:

- `S2_gausmix_tt500_fail_band`
  - promote:
    - `K510_gmix_balanced_rescue`
  - source targeted fail rows:
    - `8`
  - promoted targeted fail rows:
    - `5`
  - source targeted fail roots:
    - `5`
  - promoted targeted fail roots:
    - `3`
  - full-ready roots:
    - `0 -> 2`

- `S3_ridge_tt5000_vb_tail_band`
  - promote:
    - `K540_ridge_vb_guard_plus_softgamma`
  - source targeted fail rows:
    - `10`
  - promoted targeted fail rows:
    - `2`
  - source targeted fail roots:
    - `6`
  - promoted targeted fail roots:
    - `1`
  - full-ready roots:
    - `0 -> 5`

- `S5_short_horizon_mixed_tail`
  - promote:
    - `K580_mixed_short_guard_plus_softgamma`
  - source targeted fail rows:
    - `9`
  - promoted targeted fail rows:
    - `4`
  - source targeted fail roots:
    - `8`
  - promoted targeted fail roots:
    - `4`
  - full-ready roots:
    - `0 -> 4`

Net effect of the conservative carry-forward map used for planning:

- source broad rerun fail rows:
  - `42`
- carry-forward fail rows:
  - `26`
- improvement:
  - `-16` rows (`-38.1%`)
- source fail roots:
  - `28`
- carry-forward fail roots:
  - `17`
- improvement:
  - `-11` roots (`-39.3%`)
- source root-status FAILs:
  - `2`
- carry-forward root-status FAILs:
  - `2`
- compare-any roots:
  - `33 -> 35`
- compare-full roots:
  - `8 -> 19`
- successful-but-noneligible roots:
  - `2 -> 0`

## 3) What Still Fails

The remaining fail surface under the conservative carry-forward map is:

- fit FAIL rows:
  - `26`
- fail-carrying roots:
  - `17`
- root-status FAIL roots:
  - `2`

Remaining fail rows by pocket:

| Pocket | Scope | Roots | FAIL Rows |
|---|---|---:|---:|
| `P1` | `gausmix`, `fit_size=5000` | `5` | `9` |
| `P2` | `gausmix`, `fit_size=500` | `3` | `5` |
| `P3` | `normal`, `tau=0.95`, `fit_size=5000`, `ridge` | `1` | `2` |
| `P4` | `laplace/normal`, `fit_size=5000`, `rhs_ns` | `4` | `6` |
| `P5` | `laplace/normal`, `fit_size=500` | `4` | `4` |

Residual fail rows by axis:

- family:
  - `gausmix: 14`
  - `normal: 9`
  - `laplace: 3`
- fit size:
  - `5000: 17`
  - `500: 9`
- prior:
  - `rhs_ns: 14`
  - `ridge: 12`
- likelihood:
  - `exal: 20`
  - `al: 6`
- inference:
  - `mcmc: 15`
  - `vb: 11`

Dominant remaining fail reasons:

- `half_chain_drift`
  - `7`
- `geweke_drift; half_chain_drift`
  - `4`
- `vb_converged_false; core_parameter_tail_unstable`
  - `4`
- `vb_converged_false; elbo_tail_unstable; core_parameter_tail_unstable`
  - `4`
- `rhs_parameter_tail_unstable`
  - `3`
- `geweke_drift`
  - `2`
- `missing_chain_diagnostics`
  - `2`

Remaining outright root-status FAILs:

- `root__dynamic__dlm_constV_smallW__gausmix__tau_0p05__lasttt_5000__qdesn_ridge`
- `root__dynamic__dlm_constV_smallW__gausmix__tau_0p25__lasttt_5000__qdesn_rhs_ns`

## 4) Which Ideas Worked Best

Highest-value surviving ideas:

- `K510_gmix_balanced_rescue`
  - strongest short-horizon gausmix rescue
- `K540_ridge_vb_guard_plus_softgamma`
  - strongest long-horizon ridge rescue
- `K580_mixed_short_guard_plus_softgamma`
  - strongest short-horizon mixed cleanup
- `K550_rhs_softfreeze_local`
  - safest long-horizon rhs working control

Interpretation:

- local tuning remains the right strategy
- ridge long-horizon improvement comes from pairing stronger VB guard with softer MCMC geometry
- short-horizon cleanup benefits from mixed ridge-vb plus rhs-local rescue
- broad global reruns are now lower value than residual-only follow-up

## 5) Which Ideas Did Not Help

Weak or non-promotable directions from Wave 1:

- `S1` challengers did not beat source on the primary fail-row metric
  - `K510_gmix_balanced_rescue: 9 -> 10`
  - `K520_gmix_softgamma_rescue: 9 -> 10`
- `K520_gmix_softgamma_rescue`
  - also introduced a root failure on the long-horizon gausmix stage
- `K560_rhs_softfreeze_long`
  - reduced long-horizon rhs fail rows `6 -> 5`
  - but introduced an extra root failure
  - this is not a clear promotion under the current decision rule

## 6) Promotion Decision

Clear promotions adopted:

- `S2_gausmix_tt500_fail_band`
  - `K510_gmix_balanced_rescue`
- `S3_ridge_tt5000_vb_tail_band`
  - `K540_ridge_vb_guard_plus_softgamma`
- `S5_short_horizon_mixed_tail`
  - `K580_mixed_short_guard_plus_softgamma`

Keep source baseline:

- `S1_gausmix_tt5000_fail_band`

Conservative unresolved-stage carry-forward for planning:

- `S4_rhs_tt5000_fail_band`
  - use `K550_rhs_softfreeze_local` as the effective working control for the next wave
  - do **not** treat `K560_rhs_softfreeze_long` as a clear scientific promotion

Effective carry-forward baseline map for Wave 2 planning:

| Stage | Carry-Forward Baseline |
|---|---|
| `S1_gausmix_tt5000_fail_band` | `SOURCE_BASELINE` |
| `S2_gausmix_tt500_fail_band` | `K510_gmix_balanced_rescue` |
| `S3_ridge_tt5000_vb_tail_band` | `K540_ridge_vb_guard_plus_softgamma` |
| `S4_rhs_tt5000_fail_band` | `K550_rhs_softfreeze_local` |
| `S5_short_horizon_mixed_tail` | `K580_mixed_short_guard_plus_softgamma` |

## 7) Highest-Expected-Value Directions

The next best overnight compute should stay inside the residual pockets only:

1. `P1 gausmix tt5000`
   - highest-value remaining cluster
   - still contains both remaining root-status FAILs
   - mixed VB-tail plus MCMC drift/missing-diagnostic failures

2. `P4 rhs tt5000`
   - still unresolved after the safer `K550` control
   - mix of rhs-specific VB-tail and MCMC exal drift rows

3. `P2 gausmix tt500`
   - improved, but residual short-horizon gausmix ridge VB failures remain

4. `P5 short mixed`
   - improved strongly under `K580`, but several short-horizon MCMC exal rows remain

5. `P3 ridge tt5000 singleton`
   - only one root left
   - cheap overnight singleton cleanup

## 8) Recommended Next Move

Run a second residual-only overnight wave that:

- starts from the conservative carry-forward map above
- targets only the `26` remaining FAIL rows on `17` roots
- searches broadly **inside** the surviving local neighborhoods
- does not reopen full-matrix reruns
- does not reuse clearly weak exact profiles as challengers

Primary follow-on plan:

- `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_residual_fail_closure_wave_20260407.md`

Primary implementation:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_residual_fail_closure_wave_manifest.yaml`
- `scripts/run_qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave.R`
- `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave.R`
- `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave.R`

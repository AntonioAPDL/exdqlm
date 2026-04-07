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

Completed targeted fit-fail closure wave:

- `qdesn-dynamic-exdqlm-crossstudy-fitfail-20260407-000615__git-54c5009`
- `5/5` stages complete
- `10/10` challenger profiles complete
- `56/56` root-campaigns executed

Clear stage-local promotions from the targeted wave:

- `S2_gausmix_tt500_fail_band`
  - `K510_gmix_balanced_rescue`
- `S3_ridge_tt5000_vb_tail_band`
  - `K540_ridge_vb_guard_plus_softgamma`
- `S5_short_horizon_mixed_tail`
  - `K580_mixed_short_guard_plus_softgamma`

Conservative carry-forward decision:

- keep `S1` on `SOURCE_BASELINE`
- do **not** promote `K560_rhs_softfreeze_long` as a clear winner
- use `K550_rhs_softfreeze_local` as the effective working control for the next rhs long-horizon
  residual wave

Current effective branch-local root inventory after applying the conservative carry-forward map:

- `PASS / healthy`:
  - `19/36`
- `WARN / needs review`:
  - `15/36`
- `FAIL / broken or inconsistent`:
  - `2/36`
    - `2` outright root failures
    - `0` successful but noneligible roots

Current effective branch-local fit inventory:

- `PASS`:
  - not summarized as a new global campaign; use the effective residual source counts below
- `WARN`:
  - not summarized as a new global campaign; use the effective residual source counts below
- `FAIL`:
  - `26/144`

Primary closeout report for this decision:

- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_fit_fail_wave1_closeout_and_wave2_inventory_20260407.md`

## 9) Promotion Decision After Wave 1

No new **global** baseline promotion is justified yet.

But several **local** promotions are justified.

Decision rule carried forward:

- keep the global dynamic defaults as the default baseline
- promote only the local winners that clearly beat the source on their stage
- for ambiguous stages, keep source or carry forward only the safer local control for the next wave
  without calling it a scientific promotion

## 10) Remaining Scientific Debt

Effective residual fail surface after the conservative carry-forward map:

- fit FAIL rows:
  - `26`
- fail-carrying roots:
  - `17`
- root-status FAIL roots:
  - `2`

Dominant remaining patterns:

- long-horizon `gausmix` residual pocket
  - `5` roots
  - `9` FAIL rows
  - still contains both remaining root failures
- short-horizon `gausmix` residual pocket
  - `3` roots
  - `5` FAIL rows
- long-horizon `rhs_ns` residual pocket
  - `4` roots
  - `6` FAIL rows
- short-horizon mixed `laplace/normal` pocket
  - `4` roots
  - `4` FAIL rows
- long-horizon ridge singleton
  - `1` root
  - `2` FAIL rows

Best high-level axis read remains:

- `rhs_ns` is healthier than `ridge`
- `al` is healthier than `exal`
- `fit_size=500` is healthier than `fit_size=5000`

## 11) Recommended Move-Forward On This Branch

The next move is no longer another full rerun and no longer another first-wave targeted fit-fail
screen.

The next move is a **second residual-only overnight wave** that:

1. starts from the merged local baseline state created by the completed targeted wave
2. targets only the remaining `26` FAIL rows on `17` roots
3. explores broadly, but only inside the surviving high-value local neighborhoods
4. promotes only if a challenger clearly beats that effective source state

Wave-2 residual assets:

- plan:
  - `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_residual_fail_closure_wave_20260407.md`
- report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_fit_fail_wave1_closeout_and_wave2_inventory_20260407.md`
- manifest:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_residual_fail_closure_wave_manifest.yaml`
- runner:
  - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave.R`
- detached launcher:
  - `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave.R`
- healthcheck:
  - `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave.R`

Wave-2 residual preflight is now validated on this branch:

- prepare-only run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-residualfail-20260407-025317__git-2078ff9`
- verified stage sizes:
  - `R1=5`
  - `R2=3`
  - `R3=1`
  - `R4=4`
  - `R5=4`
- verified coverage:
  - `17/17` fail-carrying roots
  - `26/26` fail rows
- planned challenger profiles:
  - `16`
- planned root-campaigns:
  - `56`
- preflight:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_residual_fail_closure_wave/qdesn-dynamic-exdqlm-crossstudy-residualfail-20260407-025317__git-2078ff9/launch/qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_preflight.md`

Wave-2 residual overnight run completed cleanly:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-residualfail-20260407-025827__git-eed98f2`
- stop reason:
  - `completed_requested_scope`
- execution:
  - `5/5` stages complete
  - `16/16` profiles complete
  - `56/56` root-campaigns executed
- stage-local promotions:
  - `R1 -> L640_gmix_long_split_diag`
  - `R2 -> L670_gmix_short_diag_mix`
  - `R3 -> L720_ridge_long_softgamma_plus`
  - `R4 -> L760_rhs_long_vbguard_deep`
  - `R5 -> L770_short_mixed_local_mcmc`
- remaining branch-local residual:
  - `2` fit FAIL rows
  - `2` fail-carrying roots
  - `0` root-status FAILs
- authoritative summary:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_residual_fail_closure_wave/qdesn-dynamic-exdqlm-crossstudy-residualfail-20260407-025827__git-eed98f2/summary/qdesn_dynamic_crossstudy_fit_fail_closure_results.md`
- promoted local baseline map:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_residual_fail_closure_wave/qdesn-dynamic-exdqlm-crossstudy-residualfail-20260407-025827__git-eed98f2/tables/local_baseline_map.csv`

Current effective local baseline map:

| Residual Stage | Active Local Baseline |
|---|---|
| `R1_gausmix_tt5000_residual` | `L640_gmix_long_split_diag` |
| `R2_gausmix_tt500_residual` | `L670_gmix_short_diag_mix` |
| `R3_ridge_tt5000_singleton_residual` | `L720_ridge_long_softgamma_plus` |
| `R4_rhs_tt5000_residual` | `L760_rhs_long_vbguard_deep` |
| `R5_short_horizon_mixed_residual` | `L770_short_mixed_local_mcmc` |

## 12) Working Rules

- keep the study on the **dynamic** exdqlm-aligned surface
- keep the current defaults as the source baseline unless a local challenger clearly wins
- use the conservative effective local baseline map as the source for residual-only follow-up
- do not reopen the static cross-study as the main deliverable
- do not spend compute on another broad rerun right now
- do not reopen generic tuning search for one universal rescue profile

## 13) Final-Wave Closeout And Current Decision

The final rhs-only cleanup wave completed cleanly:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-finalfail-20260407-133928__git-512e982`
- stop reason:
  - `completed_requested_scope`
- execution:
  - `2/2` stages complete
  - `10/10` profiles complete
  - `40/40` root-campaigns executed
- authoritative wave summary:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_final_fail_closure_wave/qdesn-dynamic-exdqlm-crossstudy-finalfail-20260407-133928__git-512e982/summary/qdesn_dynamic_crossstudy_fit_fail_closure_results.md`

Stage-level winners inside that wave were:

- `F1 -> M850_rhs_long_burnheavy1300`
- `F2 -> M940_short_rhs_narrow1200_diag5`

But those stage-local winners were **not** adopted as new global working baselines.

Why not:

- the final wave correctly cleared the exact targeted rhs rows inside each stage;
- however, after reconciling the selected winners back into the full `36`-root mirrored dynamic
  surface, they did **not** beat the prior merged baseline on the overall fail inventory;
- `M850` is globally neutral:
  - full-study fit FAIL rows remain `2`
  - fail-carrying roots remain `2`
  - compare-full roots remain `34/36`
- `M940` is globally worse:
  - full-study fit FAIL rows rise from `2` to `3`
  - fail-carrying roots remain `2`
  - compare-full roots remain `34/36`

Therefore the authoritative branch-local effective baseline map remains the prior residual-wave map:

| Residual Stage | Authoritative Local Baseline |
|---|---|
| `R1_gausmix_tt5000_residual` | `L640_gmix_long_split_diag` |
| `R2_gausmix_tt500_residual` | `L670_gmix_short_diag_mix` |
| `R3_ridge_tt5000_singleton_residual` | `L720_ridge_long_softgamma_plus` |
| `R4_rhs_tt5000_residual` | `L760_rhs_long_vbguard_deep` |
| `R5_short_horizon_mixed_residual` | `L770_short_mixed_local_mcmc` |

Current authoritative branch-local comparison state:

- fit signoff mix:
  - `77 PASS`
  - `65 WARN`
  - `2 FAIL`
- fail-carrying roots:
  - `2 / 36`
- root-status FAILs:
  - `0 / 36`
- roots with any usable comparison:
  - `36 / 36`
- fully comparison-ready roots:
  - `34 / 36`

Exact remaining documented fit-level FAIL rows under the authoritative baseline:

- `root__dynamic__dlm_constV_smallW__normal__tau_0p05__lasttt_5000__qdesn_rhs_ns`
  - `mcmc_exal`
  - `geweke_drift; half_chain_drift`
- `root__dynamic__dlm_constV_smallW__normal__tau_0p95__lasttt_500__qdesn_rhs_ns`
  - `mcmc_exal`
  - `geweke_drift`

## 14) Immediate Next Decision

The active next phase is now:

- **move into main comparison analysis on the authoritative branch-local baseline**
- treat the final-wave results as useful targeted evidence, but **not** as promoted new defaults
- keep the remaining `2 / 144` fit FAIL rows explicitly documented as a tiny residual gap
- defer any additional micro-wave unless zero-fit-FAIL certification is required later

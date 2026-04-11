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

## 2) Current Branch-Local Active Study

The current branch-local active study is now the **effective-w300 zero-FAIL reconciled comparison
baseline**.

Key branch-local docs:

- rerun plan:
  - `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_rerun_20260407.md`
- rerun setup and smoke report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_setup_and_smoke_20260407.md`
- failure investigation:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_failure_investigation_20260408.md`
- historical execution relaunch queue:
  - `docs/TRACK__qdesn_dynamic_exdqlm_crossstudy_effective_w300_relaunch_queue_20260408.md`
- Wave 1 historical closeout:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_wave1_closeout_and_wave2_inventory_20260408.md`
- final residual closeout and zero-FAIL reconciliation:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_final_residual_closeout_and_zero_fail_reconciliation_20260408.md`
- authoritative comparison outputs:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_main_comparison_outputs_20260408.md`

Key contract:

- reported fit sizes `500` and `5000` mean **effective post-washout train size**
- enforced source totals:
  - `813`
  - `5313`
- shared MCMC depth:
  - burn-in `1000`
  - kept iterations `2000`
- posterior metric draw budget:
  - `1000`

Current status:

- broad effective-w300 rerun:
  - `qdesn-dynamic-exdqlm-crossstudy-full-20260407-233147__git-cdfd1a9`
  - outcome:
    - `30/36 SUCCESS`
    - `6/36 FAIL`
- failed-root relaunch:
  - `qdesn-dynamic-exdqlm-crossstudy-failedrelaunch-20260408-012443__git-bcdb438`
  - outcome:
    - `6/6 SUCCESS`
    - `0` repeated root execution failures
- Wave 1 fail-closure:
  - `qdesn-dynamic-exdqlm-crossstudy-effectivew300-fitfail-20260408-040402__git-8005f87`
  - promoted-source state:
    - `4` fit FAIL rows
    - `36/36` comparison-eligible-any
    - `32/36` comparison-eligible-full
- final residual wave:
  - `qdesn-dynamic-exdqlm-crossstudy-effectivew300-finalresid-20260408-162642__git-5ed0d19`
  - selected stage winners:
    - `R1 -> R820_ridge_combo224_soft2600`
    - `R2 -> R950_rhs_long_guard256_diag3200`
  - stage-winner state:
    - `2` fit FAIL rows
    - `1` root-status FAIL
- exact-root reconciliation:
  - `laplace tau=0.95 rhs_ns -> R910_rhs_long_guard224_narrow2800`
  - `normal tau=0.25 rhs_ns -> R930_rhs_long_guard224_diag3000`
- authoritative comparison pack:
  - analysis commit:
    - `cc6f0f5`
  - run tag:
    - `qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-200857__git-cc6f0f5`
  - key rolled state:
    - `68 PASS`
    - `76 WARN`
    - `0 FAIL`
    - `0/36` root-status FAILs
    - `36/36` comparison-eligible-any
    - `36/36` comparison-eligible-full

Completed follow-on architecture rerun:

- purpose:
  - evaluate a richer shared DESN architecture across the full effective-w300 case lattice without
    changing the source-window or metric contract
- plan:
  - `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_deepdesn_rerun_20260408.md`
- checked-in defaults:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_defaults.yaml`
- checked-in grid:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_grid.csv`
- DESN profile:
  - `deep_d3_n100x3_skip100_w300_m30`
- expected size:
  - `36` roots
  - `144` fit rows
- preflight:
  - full-batch `prepare-only` passes under the new campaign namespace
- setup/launch report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_deepdesn_setup_and_launch_20260408.md`
- live full run:
  - `qdesn-dynamic-exdqlm-crossstudy-full-20260408-211621__git-8527b4a`
- completed broad-state read:
  - `27 PASS`
  - `48 WARN`
  - `69 FAIL`
  - `34/36 SUCCESS`
  - `2/36 FAIL`
  - `30/36` comparison-eligible-any
  - `5/36` comparison-eligible-full
- completed-state report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_deepdesn_closeout_and_fail_surface_20260409.md`
- promotion decision:
  - no whole-root deep-DESN promotion into the authoritative branch baseline yet
  - localized fit-level wins exist in `rhs_ns / vb`, but they are not yet whole-root promotable

Active deep-DESN repair wave:

- plan:
  - `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_wave_20260409.md`
- launch report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_setup_and_launch_20260409.md`
- manifest:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_wave_manifest.yaml`
- wrappers:
  - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_wave.R`
  - `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_wave.R`
  - `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_wave.R`
- prepare-only:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-fitfail-20260409-010359__git-36c7c9e`
  - passes
- verified stage sizes:
  - `D1: 6 roots / 12 target FAIL rows / 4 profiles`
  - `D2: 6 roots / 16 target FAIL rows / 5 profiles`
  - `D3: 9 roots / 18 target FAIL rows / 4 profiles`
  - `D4: 9 roots / 22 target FAIL rows / 5 profiles`
- planned challenger scope:
  - `18` profiles
  - `135` root-campaigns
  - `540` fit executions
- live run:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-fitfail-20260409-010419__git-36c7c9e`
- detached session:
  - `qdesn_dynxff_0409_010421`
- launch-state read:
  - `0/4` stages complete
  - `0/18` profiles complete
  - detached session live

Deep-DESN Wave 1 closeout and current residual continuation:

- closeout report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_wave1_closeout_and_wave2_inventory_20260409.md`
- Wave 1 stage outcomes:
  - `D1 -> D120_ridge_lower_vb384`
  - `D2 -> D250_ridge_upper_combo512_diag3400`
  - `D3 -> D330_rhs_short_balanced3000`
  - `D4 -> SOURCE_BASELINE`
- exact-root promotions already justified by completed evidence:
  - `gausmix tau=0.05 fit_size=500 rhs_ns -> D310_rhs_short_drift2600`
  - `gausmix tau=0.05 fit_size=5000 ridge -> D140_ridge_lower_vb512`
  - `laplace tau=0.05 fit_size=5000 ridge -> D140_ridge_lower_vb512`
- promoted deep-DESN working source:
  - `59 PASS`
  - `62 WARN`
  - `23 FAIL`
  - `35/36 SUCCESS`
  - `1/36 FAIL`
  - `34/36` comparison-eligible-any
  - `26/36` comparison-eligible-full
- residual concentration:
  - `22/23` FAIL rows are in `rhs_ns`, `fit_size=5000`
  - the only remaining non-`rhs_ns` row is:
    - `normal tau=0.25 fit_size=500 ridge mcmc_exal`
  - the only remaining root-status FAIL is:
    - `gausmix tau=0.95 fit_size=5000 rhs_ns`
- important gap fixed in branch code:
  - zero-byte wave CSVs now read safely
  - future fit-fail waves now preserve schema when writing empty local-baseline tables

Validated deep-DESN final residual wave:

- plan:
  - `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_wave_20260409.md`
- manifest:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_wave_manifest.yaml`
- wrappers:
  - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_wave.R`
  - `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_wave.R`
  - `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_wave.R`
- committed-state `prepare-only`:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-finalresid-20260409-preflight`
  - passes
- verified stage sizes:
  - `E1: 3 roots / 10 target FAIL rows / 5 profiles`
  - `E2: 6 roots / 12 target FAIL rows / 5 profiles`
  - `E3: 1 root / 1 target FAIL row / 4 profiles`
- planned challenger scope:
  - `14` profiles
  - `49` root-campaigns
  - `196` fit executions
- launch report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_setup_and_launch_20260409.md`
- live run:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-finalresid-20260409-183058__git-26bdaad`
- detached session:
  - `qdesn_dynxff_0409_183058`
- immediate launch-state read:
  - `0/3` stages complete
  - `0/14` profiles complete
  - current stage/profile:
    - `E1_rhs_long_gausmix_mixed / E410_rhs_long_gausmix_guard320_balanced3200`
  - detached session live

Relaunch after storage unblock:

- relaunch reason:
  - the first detached launch encountered `/home` storage exhaustion and should now be treated as
    historical launch evidence only
- relaunch report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_relaunch_20260410.md`
- current live run:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-finalresid-20260409-204957__git-c116dc3`
- current detached session:
  - `qdesn_dynxff_0409_204957`
- current live state:
  - `1 / 3` stages complete
  - `5 / 14` profiles complete
  - current stage/profile:
    - `E2_rhs_long_laplace_normal_mcmc / E510_rhs_long_general_balanced3200`
  - completed stage:
    - `E1_rhs_long_gausmix_mixed`
  - selected stage-local winner:
    - `E410_rhs_long_gausmix_guard320_balanced3200`

Wave 2 closeout and validated Wave 3 continuation:

- closeout report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_wave2_closeout_and_wave3_inventory_20260410.md`
- completed relaunch:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-finalresid-20260409-204957__git-c116dc3`
- completed stage-local promotions:
  - `E410_rhs_long_gausmix_guard320_balanced3200`
  - `E520_rhs_long_general_diag3400`
  - `E620_ridge_mid_diag3000`
- exact-root promotion carried forward:
  - `laplace tau=0.05 fit_size=5000 rhs_ns -> E530_rhs_long_general_guard320_burn3600`
- promoted deep-DESN working source:
  - `71 PASS / 59 WARN / 14 FAIL`
  - `36 / 36` root execution `SUCCESS`
  - `0 / 36` root execution `FAIL`
  - `36 / 36` comparison-eligible-any
  - `27 / 36` comparison-eligible-full
- residual concentration:
  - all remaining FAIL rows are long-horizon `rhs_ns` `mcmc` at `fit_size=5000`
  - `gausmix = 6`, `laplace = 3`, `normal = 5`
- validated next wave:
  - plan:
    - `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rhs_long_mcmc_wave_20260410.md`
  - manifest:
    - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rhs_long_mcmc_wave_manifest.yaml`
  - committed-state prepare-only run:
    - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-rhslongmcmc-20260410-163103__git-ceab523`
  - verified stage sizes:
    - `F1: 3 roots / 6 target FAIL rows / 4 profiles`
    - `F2: 3 roots / 3 target FAIL rows / 4 profiles`
    - `F3: 2 roots / 4 target FAIL rows / 4 profiles`
    - `F4: 1 root / 1 target FAIL row / 3 profiles`
  - planned scope:
    - `15` profiles / `35` root-campaigns / `140` fit executions
  - live launch report:
    - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rhs_long_mcmc_setup_and_launch_20260410.md`
  - live run:
    - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-rhslongmcmc-20260410-163031__git-ceab523`
  - detached session:
    - `qdesn_dynxff_0410_163032`
  - immediate launch state:
    - `0 / 4` stages complete
    - `0 / 15` profiles complete
    - current stage/profile:
      - `F1_rhs_long_gausmix_mcmc / F410_rhs_long_gausmix_guard320_recenter3600`

## 3) Source Of Truth Hierarchy

For continuation work on this integration branch, use the following evidence order:

1. this handoff tracker:
   - `docs/TRACK__qdesn_0p4p0_integration_handoff_20260406.md`
2. the final residual closeout and zero-FAIL reconciliation report:
   - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_final_residual_closeout_and_zero_fail_reconciliation_20260408.md`
3. the authoritative effective-w300 comparison outputs report:
   - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_main_comparison_outputs_20260408.md`
4. the active effective-w300 posterior-draw rerun docs:
   - `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_rerun_20260407.md`
   - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_setup_and_smoke_20260407.md`
   - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_failure_investigation_20260408.md`
   - `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_failed_root_relaunch_20260408.md`
   - `docs/TRACK__qdesn_dynamic_exdqlm_crossstudy_effective_w300_relaunch_queue_20260408.md`
   - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_wave1_closeout_and_wave2_inventory_20260408.md`
   - `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_final_residual_wave_20260408.md`
   - `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_deepdesn_rerun_20260408.md`
   - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_deepdesn_setup_and_launch_20260408.md`
   - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_deepdesn_closeout_and_fail_surface_20260409.md`
   - `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_wave_20260409.md`
   - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_setup_and_launch_20260409.md`
   - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_wave1_closeout_and_wave2_inventory_20260409.md`
   - `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_wave_20260409.md`
   - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_setup_and_launch_20260409.md`
5. the detailed historical dynamic relaunch tracker:
   - `docs/TRACK__qdesn_dynamic_exdqlm_crossstudy_validation.md`
6. the authoritative effective-w300 zero-FAIL comparison pack:
   - summary:
     - `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-200857__git-cc6f0f5/summary/qdesn_dynamic_main_comparison_analysis.md`
   - 144-row case table:
     - `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-200857__git-cc6f0f5/tables/authoritative_fit_case_table_readable.csv`
   - QDESN-vs-reference summary:
     - `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-200857__git-cc6f0f5/comparison_vs_reference/comparison_summary.md`
7. the completed dynamic campaign outputs on the predecessor branch/worktree:
   - campaign summary:
     - `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_validation/qdesn-dynamic-exdqlm-crossstudy-full-20260406-163041__git-85760fe/20260406-163050__git-85760fe/summary/qdesn_dynamic_crossstudy_summary.md`
   - comparison summary:
     - `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_validation/qdesn-dynamic-exdqlm-crossstudy-full-20260406-163041__git-85760fe/20260406-163050__git-85760fe/comparison_vs_reference/comparison_summary.md`
   - campaign progress table:
     - `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_validation/qdesn-dynamic-exdqlm-crossstudy-full-20260406-163041__git-85760fe/20260406-163050__git-85760fe/tables/campaign_progress.csv`
8. the checked-in dynamic grid and runner assets on this branch:
   - `config/validation/qdesn_dynamic_exdqlm_crossstudy_grid.csv`
   - `R/qdesn_dynamic_exdqlm_crossstudy.R`
   - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R`

## 4) Branch/Worktree Lineage

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

## 5) Authoritative Carry-Forward State

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

## 6) What Is Settled

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

## 7) Current In-Scope Case Set

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

## 8) Health Convention Used Here

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

## 9) Current Branch-Local Validation State

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

## 10) Promotion Decision After Wave 1

No new **global** baseline promotion is justified yet.

But several **local** promotions are justified.

Decision rule carried forward:

- keep the global dynamic defaults as the default baseline
- promote only the local winners that clearly beat the source on their stage
- for ambiguous stages, keep source or carry forward only the safer local control for the next wave
  without calling it a scientific promotion

## 11) Remaining Scientific Debt

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

## 12) Recommended Move-Forward On This Branch

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

## 13) Working Rules

- keep the study on the **dynamic** exdqlm-aligned surface
- keep the current defaults as the source baseline unless a local challenger clearly wins
- use the conservative effective local baseline map as the source for residual-only follow-up
- do not reopen the static cross-study as the main deliverable
- do not spend compute on another broad rerun right now
- do not reopen generic tuning search for one universal rescue profile

## 14) Final-Wave Reconciliation And Authoritative Promotion Update

The final rhs-only cleanup wave still should **not** be treated as a stage-wide global promotion.

That part of the earlier decision remains correct:

- `M850` was only globally neutral as a full `F1` stage swap
- `M940` was globally worse as a full `F2` stage swap

However, the branch now has a stronger and more precise conclusion:

- both candidates are clear improvements on their **exact remaining failing roots**
- the stage-wide rejection does **not** mean the exact-root fits should be rejected
- local scenario-specific tuning is the intended rule for this branch

Authoritative branch-local baseline is therefore now:

Stage-level local map:

| Residual Stage | Authoritative Local Baseline |
|---|---|
| `R1_gausmix_tt5000_residual` | `L640_gmix_long_split_diag` |
| `R2_gausmix_tt500_residual` | `L670_gmix_short_diag_mix` |
| `R3_ridge_tt5000_singleton_residual` | `L720_ridge_long_softgamma_plus` |
| `R4_rhs_tt5000_residual` | `L760_rhs_long_vbguard_deep` |
| `R5_short_horizon_mixed_residual` | `L770_short_mixed_local_mcmc` |

Exact-root overrides:

| Root | Promoted Profile | Why |
|---|---|---|
| `root__dynamic__dlm_constV_smallW__normal__tau_0p05__lasttt_5000__qdesn_rhs_ns` | `M850_rhs_long_burnheavy1300` | clears the remaining long-horizon rhs `mcmc_exal` fail row and restores full readiness on the exact target root |
| `root__dynamic__dlm_constV_smallW__normal__tau_0p95__lasttt_500__qdesn_rhs_ns` | `M940_short_rhs_narrow1200_diag5` | clears the remaining short-horizon rhs `mcmc_exal` fail row and is cleaner than `M950` on the target-root non-fail rows |

## 15) Current Authoritative Validation State

Current authoritative branch-local comparison state is now:

- fit signoff mix:
  - `76 PASS`
  - `68 WARN`
  - `0 FAIL`
- fail-carrying roots:
  - `0 / 36`
- root-status FAILs:
  - `0 / 36`
- roots with any usable comparison:
  - `36 / 36`
- fully comparison-ready roots:
  - `36 / 36`

Validation/tuning read:

- the residual fail band is now closed
- no remaining scientific `FAIL` rows require another overnight repair wave
- further validation compute is no longer the mainline task on this branch

Authoritative reconciliation report:

- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_root_override_reconciliation_20260407.md`

## 16) Main Comparison Analysis Outputs (2026-04-07)

The authoritative comparison-analysis pack has been regenerated from the reconciled baseline above.

Authoritative analysis run:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-214041__git-5c3762f`
- report root:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-214041__git-5c3762f`
- summary:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-214041__git-5c3762f/summary/qdesn_dynamic_main_comparison_analysis.md`
- 144-row case table:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-214041__git-5c3762f/summary/qdesn_dynamic_main_comparison_case_table.md`
- QDESN-vs-reference summary:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-214041__git-5c3762f/comparison_vs_reference/comparison_summary.md`
- root override map:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-214041__git-5c3762f/tables/authoritative_root_override_map.csv`
- explicit q-true fit summaries:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-214041__git-5c3762f/tables/authoritative_fit_inference_summary.csv`
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-214041__git-5c3762f/tables/authoritative_fit_model_summary.csv`
- direct per-fit case table csv:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-214041__git-5c3762f/tables/authoritative_fit_case_table.csv`
- implementation/interpretation report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_main_comparison_outputs_20260407.md`

Current authoritative study state, as rendered in the comparison pack:

- fit signoff mix:
  - `76 PASS`
  - `68 WARN`
  - `0 FAIL`
- root status:
  - `0 / 36` root-status FAILs
- root readiness:
  - `36 / 36` comparison-eligible-any
  - `36 / 36` comparison-eligible-full

High-value comparison takeaways now documented in the pack:

- `ridge` remains the cleaner signoff prior overall:
  - `53 PASS / 19 WARN / 0 FAIL`
- `rhs_ns` is now fully comparison-eligible as well:
  - `23 PASS / 49 WARN / 0 FAIL`
- the refreshed committed-SHA pack now makes the primary fitted-path validation metrics explicit:
  - `qtrue_mae`
  - `qtrue_rmse`
  - `qtrue_bias`
  - `qtrue_corr`
  - `qtrue_median_ae`
  - `qtrue_p90_ae`
  - `pinball_tau`
  - `coverage`
  - `coverage_minus_tau`
  - `coverage_error`
  - `runtime_sec_per_1k_eval`
- `vb/al` remains the healthiest and fastest broad method-model slice:
  - `29 PASS / 7 WARN / 0 FAIL`
- the fitted/train path is now treated as the primary evaluation window because the dynamic
  defaults still use `holdout_n = 1`
- dedicated tables now summarize those metrics by inference, model, prior, family, tau, and
  inference+model
- the pack now also includes a non-aggregated 144-row per-fit case table for case-by-case review
- `mcmc/exal` remains the softest area scientifically, but is now all non-fail:
  - `1 PASS / 35 WARN / 0 FAIL`
  - mean runtime about `30.76 s`
- the new metric framing also clarifies an important tradeoff:
  - `vb` is cleaner and faster overall
  - `mcmc` is often better on train-path oracle recovery
  - `al` is cleaner and better fit-performing than `exal`

Current next move:

- proceed with the main comparison interpretation and downstream comparison-facing reporting from
  this authoritative zero-fail pack
- do **not** launch another validation repair wave by default

## 17) Deep-DESN Challenger Follow-On: F-Wave Closeout And Normalized Multiseed Planning (2026-04-11)

The later deep-DESN exploratory continuation is now closed through the completed rhs-long MCMC
wave and has been carried forward into a planning freeze.

Completed rhs-long MCMC wave:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-rhslongmcmc-20260410-163031__git-ceab523`
- stage status:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rhs_long_mcmc_wave/qdesn-dynamic-exdqlm-crossstudy-deepdesn-rhslongmcmc-20260410-163031__git-ceab523/tables/stage_execution_status.csv`
- closeout report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_wave3_closeout_and_normalized_multiseed_inventory_20260411.md`

Completed stage decisions:

- `F1 -> KEEP_SOURCE_BASELINE`
- `F2 -> KEEP_SOURCE_BASELINE`
- `F3 -> PROMOTE_F630_rhs_long_normal_lower_guard320_recenter4000`
- `F4 -> KEEP_SOURCE_BASELINE`

Working deep-DESN challenger source after the justified `F630` promotion:

- `71 PASS / 60 WARN / 13 FAIL`
- `36 / 36` root execution `SUCCESS`
- `0 / 36` root execution `FAIL`
- `36 / 36` comparison-eligible-any
- `27 / 36` comparison-eligible-full

Residual interpretation:

- all remaining FAIL rows are long-horizon `rhs_ns` `mcmc` at `fit_size = 5000`
- there is no remaining execution debt
- there is no remaining ridge or short-horizon fail lane

Decision from the investigation:

- do **not** default to another geometry-only deep-DESN residual wave
- instead, investigate and stage a normalized multiseed relaunch built on the post-`F630` source

Current planning docs:

- closeout/inventory:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_wave3_closeout_and_normalized_multiseed_inventory_20260411.md`
- staged relaunch plan:
  - `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_normalized_multiseed_relaunch_20260411.md`

Important engineering note:

- the current dynamic validation path does not yet have a first-class per-profile multiseed
  selection layer;
- the next implementation step is therefore seed plumbing plus canary validation, not the big
  relaunch itself.

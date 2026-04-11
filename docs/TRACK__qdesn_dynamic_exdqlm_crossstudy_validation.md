# TRACK: QDESN Dynamic exdqlm Cross-Study Validation

Date: 2026-04-06
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`
Repo: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`
Reference repo: `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs`

## 1) Mission

Build the QDESN counterpart to the **dynamic** exdqlm validation study on the same recovered
dynamic dataset surface, using:

- likelihoods:
  - `exal`
  - `al`
- methods:
  - `vb`
  - `mcmc`
- QDESN priors:
  - `ridge`
  - `rhs_ns`

This tracker is for the corrected dynamic comparison-facing program.

## Integration-Branch Handoff Note (2026-04-06)

On `feature/qdesn-mcmc-alternative-0p4p0-integration`, the preferred working handoff document is:

- `docs/TRACK__qdesn_0p4p0_integration_handoff_20260406.md`

Reason:

- this file is the long-form historical tracker for the original relaunch effort;
- the new integration branch needs a concise branch-local continuation note that carries forward the
  validated dynamic results from old-branch commit `1591bd5` without pretending this branch has
  already rerun them.

## Effective-W300 Posterior-Draw Rerun Note (2026-04-08)

The branch-local effective-w300 rerun program is now complete and reconciled to a zero-FAIL
comparison baseline.

Core contract:

- effective fit sizes:
  - `500`
  - `5000`
- enforced source totals:
  - `813`
  - `5313`
- shared MCMC depth:
  - burn-in `1000`
  - kept iterations `2000`
- posterior metric draws:
  - `1000`

Effective-w300 completion chain:

- broad rerun:
  - `qdesn-dynamic-exdqlm-crossstudy-full-20260407-233147__git-cdfd1a9`
  - outcome:
    - `30/36 SUCCESS`
    - `6/36 FAIL`
- implementation failure repair:
  - report:
    - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_failure_investigation_20260408.md`
- failed-root relaunch:
  - `qdesn-dynamic-exdqlm-crossstudy-failedrelaunch-20260408-012443__git-bcdb438`
  - outcome:
    - `6/6 SUCCESS`
    - `0` repeated root execution failures
- Wave 1 scientific fail-closure:
  - `qdesn-dynamic-exdqlm-crossstudy-effectivew300-fitfail-20260408-040402__git-8005f87`
  - promoted-source state:
    - `4` fit FAIL rows
    - `0/36` root-status FAILs
    - `36/36` comparison-eligible-any
    - `32/36` comparison-eligible-full
- final residual wave:
  - `qdesn-dynamic-exdqlm-crossstudy-effectivew300-finalresid-20260408-162642__git-5ed0d19`
  - stage winners:
    - `R1 -> R820_ridge_combo224_soft2600`
    - `R2 -> R950_rhs_long_guard256_diag3200`
  - stage-winner residual:
    - `2` fit FAIL rows
    - `1` root-status FAIL
- exact-root rhs reconciliation:
  - report:
    - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_final_residual_closeout_and_zero_fail_reconciliation_20260408.md`
  - exact promotions:
    - `laplace tau=0.95 rhs_ns -> R910_rhs_long_guard224_narrow2800`
    - `normal tau=0.25 rhs_ns -> R930_rhs_long_guard224_diag3000`
- authoritative zero-FAIL comparison pack:
  - run tag:
    - `qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-200857__git-cc6f0f5`
  - report:
    - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_main_comparison_outputs_20260408.md`
  - summary:
    - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-200857__git-cc6f0f5/summary/qdesn_dynamic_main_comparison_analysis.md`
  - case table:
    - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-200857__git-cc6f0f5/tables/authoritative_fit_case_table_readable.csv`
  - rolled state:
    - `68 PASS`
    - `76 WARN`
    - `0 FAIL`
    - `0/36` root-status FAILs
    - `36/36` comparison-eligible-any
    - `36/36` comparison-eligible-full

## Effective-W300 Deep-DESN Rerun Note (2026-04-08)

A new full-rerun architecture experiment is now prepared on this integration branch using a richer
shared DESN profile applied to every case.

Purpose:

- test whether a materially larger/deeper DESN improves the full effective-w300 validation surface
  without changing the source-total contract or the posterior-metric evaluation layer.

New shared DESN profile:

- `deep_d3_n100x3_skip100_w300_m30`
- `D = 3`
- `n = [100, 100, 100]`
- `n_tilde = [100, 100]`
- `m = 30`
- `alpha = [0.2, 0.2, 0.2]`
- `rho = [0.95, 0.95, 0.95]`
- `act_f = [tanh, tanh, tanh]`
- `act_k = [identity, identity, identity]`
- `pi_w = [0.1, 0.1, 0.1]`
- `pi_in = [1.0, 1.0, 1.0]`
- `washout = 300`

Checked-in rerun assets:

- plan:
  - `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_deepdesn_rerun_20260408.md`
- defaults:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_defaults.yaml`
- grid:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_grid.csv`
- materializer:
  - `scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_grid.R`
- runner:
  - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_validation.R`
- launcher:
  - `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_validation.R`
- healthcheck:
  - `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_validation.R`

Checked-in setup state:

- canonical deep-DESN grid materialized:
  - `36` roots
  - `18` unique dataset cells
- full-batch `prepare-only`:
  - passes
- setup/launch report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_deepdesn_setup_and_launch_20260408.md`

Committed-state full launch:

- setup commit:
  - `8527b4a`
- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-full-20260408-211621__git-8527b4a`
- detached session:
  - `qdesn_dynx_0408_211621`
- early health snapshot:
  - `36` selected roots
  - `6` materialized
  - `6 RUNNING`
  - `0 FAIL`

Interpretation rule:

- the current zero-FAIL effective-w300 pack remains authoritative until the deep-DESN rerun
  completes and is judged against it.

## Effective-W300 Deep-DESN Completed-State Repair Note (2026-04-09)

The broad deep-DESN rerun is now complete and should be treated as a **challenger source**, not as
the new authoritative branch baseline.

Completed deep-DESN broad rerun:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-full-20260408-211621__git-8527b4a`
- closeout report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_deepdesn_closeout_and_fail_surface_20260409.md`
- key rolled state:
  - `27 PASS`
  - `48 WARN`
  - `69 FAIL`
  - `34/36 SUCCESS`
  - `2/36 FAIL`
  - `30/36` comparison-eligible-any
  - `5/36` comparison-eligible-full

Promotion decision after the broad rerun:

- whole-root promotions into the authoritative branch baseline:
  - `0`
- reason:
  - there are localized fit-level metric wins, but no whole deep-DESN root currently dominates the
    authoritative simple-DESN source cleanly enough to promote
- localized upside observed:
  - `18` fit rows on `11` roots improve both `train_qtrue_mae` and `train_pinball_tau` without
    worsening signoff
  - all of those wins are in `rhs_ns / vb`

New active repair phase:

- plan:
  - `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_wave_20260409.md`
- manifest:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_wave_manifest.yaml`
- wrappers:
  - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_wave.R`
  - `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_wave.R`
  - `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_wave.R`

Prepare-only validation:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-fitfail-20260409-010359__git-36c7c9e`
- result:
  - pass
- verified stage plan:
  - `D1: 6 roots / 12 target FAIL rows / 4 profiles`
  - `D2: 6 roots / 16 target FAIL rows / 5 profiles`
  - `D3: 9 roots / 18 target FAIL rows / 4 profiles`
  - `D4: 9 roots / 22 target FAIL rows / 5 profiles`
- planned scope:
  - `18` challenger profiles
  - `135` root-campaigns
  - `540` fit executions
- launch report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_setup_and_launch_20260409.md`

Live overnight run:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-fitfail-20260409-010419__git-36c7c9e`
- detached session:
  - `qdesn_dynxff_0409_010421`
- immediate health:
  - `0/4` stages complete
  - `0/18` profiles complete
  - detached session live
  - first active stage/profile:
    - `D1_ridge_lower_tail_vb / D110_ridge_lower_vb320`

Interpretation:

- keep the current simple-DESN zero-FAIL effective-w300 pack authoritative;
- use the completed broad deep-DESN rerun as the source state for a localized deep-DESN repair
  wave;
- promote only clear stage winners from that localized wave.

## Effective-W300 Deep-DESN Wave 1 Closeout And Final Residual Note (2026-04-09)

Wave 1 is now complete and should be treated as a **working deep-DESN challenger-source repair
step**, not as a new authoritative branch baseline.

Wave 1 closeout:

- closeout report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_wave1_closeout_and_wave2_inventory_20260409.md`
- completed wave:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-fitfail-20260409-010419__git-36c7c9e`
- stage outcomes:
  - `D1 -> D120_ridge_lower_vb384`
  - `D2 -> D250_ridge_upper_combo512_diag3400`
  - `D3 -> D330_rhs_short_balanced3000`
  - `D4 -> SOURCE_BASELINE`

Important reproducibility note:

- Wave 1 left a zero-byte `local_baseline_map.csv` and empty `D4` stage tables;
- the branch-local generic dynamic fit-fail reader/runner has now been hardened so zero-byte CSVs
  are treated safely and future waves preserve table schema when no local baseline rows are
  written.

Promoted deep-DESN working source before the next wave:

- stage winners carried forward:
  - `D120`
  - `D250`
  - `D330`
- exact-root promotions already justified by completed evidence:
  - `gausmix tau=0.05 fit_size=500 rhs_ns -> D310_rhs_short_drift2600`
  - `gausmix tau=0.05 fit_size=5000 ridge -> D140_ridge_lower_vb512`
  - `laplace tau=0.05 fit_size=5000 ridge -> D140_ridge_lower_vb512`

Current working deep-DESN challenger state:

- `59 PASS`
- `62 WARN`
- `23 FAIL`
- `35/36 SUCCESS`
- `1/36 FAIL`
- `34/36` comparison-eligible-any
- `26/36` comparison-eligible-full

Residual concentration:

- `22/23` FAIL rows are now in `rhs_ns`, `fit_size=5000`
- the last non-`rhs_ns` debt is one uncovered:
  - `normal tau=0.25 fit_size=500 ridge mcmc_exal`
- the only remaining root-status FAIL is:
  - `gausmix tau=0.95 fit_size=5000 rhs_ns`

Validated next wave:

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
- verified stage plan:
  - `E1: 3 roots / 10 target FAIL rows / 5 profiles`
  - `E2: 6 roots / 12 target FAIL rows / 5 profiles`
  - `E3: 1 root / 1 target FAIL row / 4 profiles`
- planned scope:
  - `14` challenger profiles
  - `49` root-campaigns
  - `196` fit executions
- launch report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_setup_and_launch_20260409.md`

Live overnight run:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-finalresid-20260409-183058__git-26bdaad`
- detached session:
  - `qdesn_dynxff_0409_183058`
- immediate health:
  - `0/3` stages complete
  - `0/14` profiles complete
  - current stage/profile:
    - `E1_rhs_long_gausmix_mixed / E410_rhs_long_gausmix_guard320_balanced3200`
  - detached session live

Relaunch after storage unblock:

- relaunch reason:
  - first detached launch hit `/home` storage exhaustion (`No space left on device`)
- relaunch report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_relaunch_20260410.md`
- current live run:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-finalresid-20260409-204957__git-c116dc3`
- current detached session:
  - `qdesn_dynxff_0409_204957`
- current live health snapshot:
  - `1 / 3` stages complete
  - `5 / 14` profiles complete
  - current stage/profile:
    - `E2_rhs_long_laplace_normal_mcmc / E510_rhs_long_general_balanced3200`
  - `E1_rhs_long_gausmix_mixed` completed and recommends:
    - `PROMOTE_E410_rhs_long_gausmix_guard320_balanced3200_AS_E1_rhs_long_gausmix_mixed_LOCAL_BASELINE`

Current monitoring convention:

- treat `...183058__git-26bdaad` as the historical first launch;
- treat `...204957__git-c116dc3` as the active live residual-wave source of truth.

Interpretation:

- do **not** reopen solved `D1`, `D2`, or `D3` neighborhoods;
- do **not** reuse `D410`;
- spend the next overnight batch only on the residual `rhs_ns fit_size=5000` pocket plus the one
  uncovered ridge singleton.

Wave 2 closeout and Wave 3 inventory:

- closeout report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_wave2_closeout_and_wave3_inventory_20260410.md`
- completed final-residual relaunch:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-finalresid-20260409-204957__git-c116dc3`
- completed stage-local promotions:
  - `E1 -> E410_rhs_long_gausmix_guard320_balanced3200`
  - `E2 -> E520_rhs_long_general_diag3400`
  - `E3 -> E620_ridge_mid_diag3000`
- justified exact-root promotion:
  - `laplace tau=0.05 fit_size=5000 rhs_ns -> E530_rhs_long_general_guard320_burn3600`
- promoted deep-DESN working source after these updates:
  - `71 PASS`
  - `59 WARN`
  - `14 FAIL`
  - `36 / 36` root execution `SUCCESS`
  - `0 / 36` root execution `FAIL`
  - `36 / 36` comparison-eligible-any
  - `27 / 36` comparison-eligible-full
- residual fail concentration:
  - all `14` remaining FAIL rows are `rhs_ns`, `fit_size=5000`, `mcmc`
  - family split:
    - `gausmix = 6`
    - `laplace = 3`
    - `normal = 5`
  - no remaining ridge fail lane
  - no remaining short-horizon fail lane
  - no remaining root-status FAIL

Validated next wave:

- plan:
  - `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rhs_long_mcmc_wave_20260410.md`
- manifest:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rhs_long_mcmc_wave_manifest.yaml`
- wrappers:
  - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rhs_long_mcmc_wave.R`
  - `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rhs_long_mcmc_wave.R`
  - `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rhs_long_mcmc_wave.R`
- committed-state prepare-only validation run:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-rhslongmcmc-20260410-163103__git-ceab523`
- verified stage sizes:
  - `F1_rhs_long_gausmix_mcmc: 3 roots / 6 target FAIL rows / 4 profiles`
  - `F2_rhs_long_laplace_exal: 3 roots / 3 target FAIL rows / 4 profiles`
  - `F3_rhs_long_normal_lower_mcmc: 2 roots / 4 target FAIL rows / 4 profiles`
  - `F4_rhs_long_normal_upper_exal: 1 root / 1 target FAIL row / 3 profiles`
- planned scope:
  - `15` profiles
  - `35` root-campaigns
  - `140` fit executions
- live launch report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rhs_long_mcmc_setup_and_launch_20260410.md`
- live run:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-rhslongmcmc-20260410-163031__git-ceab523`
- detached session:
  - `qdesn_dynxff_0410_163032`
- immediate live health:
  - `0 / 4` stages complete
  - `0 / 15` profiles complete
  - current stage/profile:
    - `F1_rhs_long_gausmix_mcmc / F410_rhs_long_gausmix_guard320_recenter3600`
  - detached session live
  - `0` root execution error files

## 2) Current Status

Status of this long-form tracker: **historical relaunch record**.

For the current branch-local effective-w300 comparison-analysis state, use the note above plus:

- `docs/TRACK__qdesn_0p4p0_integration_handoff_20260406.md`
- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_final_residual_closeout_and_zero_fail_reconciliation_20260408.md`
- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_main_comparison_outputs_20260408.md`
- `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_rerun_20260407.md`
- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_setup_and_smoke_20260407.md`
- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_failure_investigation_20260408.md`
- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_wave1_closeout_and_wave2_inventory_20260408.md`
- `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_failed_root_relaunch_20260408.md`
- `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_fail_closure_wave_20260408.md`
- `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_final_residual_wave_20260408.md`
- `docs/TRACK__qdesn_dynamic_exdqlm_crossstudy_effective_w300_relaunch_queue_20260408.md`

The remainder of this section preserves the earlier integration-branch relaunch history.

Scope correction summary:

- the completed `qdesn_static_exdqlm_crossstudy_*` program was scientifically valid as a static
  analog study;
- it was not the intended deliverable if the goal is direct comparison against the exdqlm dynamic
  validation surface;
- the next required move is therefore a dynamic exdqlm-aligned relaunch.

Implementation update:

- the corrected dynamic helper stack is now implemented;
- the canonical dynamic grid was materialized directly from the exdqlm reference tree and checked
  in as:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_grid.csv`
- prepare-only passed for:
  - smoke batch
  - full batch
- the first real smoke run exposed a YAML scalar coercion bug on `external_data.y_column`;
- that bug is now fixed in both config and shared config normalization;
- a second runtime issue then exposed child BLAS oversubscription;
- that thread-cap issue is now fixed in the shared pipeline launcher path;
- the corrected smoke run finished with:
  - `4/4 SUCCESS` roots,
  - `16` fit rows,
  - `6 PASS / 8 WARN / 2 FAIL`,
  - recommendation:
    - `COMPARISON_READY_WITH_DOCUMENTED_DYNAMIC_FAIL_BAND`

Authoritative implementation report:

- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_implementation_and_smoke_20260406.md`

Carry-forward broad-launch closeout from predecessor branch/worktree:

- implementation commit:
  - `85760fe`
- predecessor branch/worktree closeout commit:
  - `1591bd5`
- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-full-20260406-163041__git-85760fe`
- final execution:
  - `36/36 SUCCESS` roots
  - `144/144` fit rows emitted
  - `0` root execution failures
- final fit signoff mix:
  - `29 PASS`
  - `69 WARN`
  - `46 FAIL`
- final root comparison readiness:
  - `31/36` comparison-eligible-any
  - `11/36` comparison-eligible-full
- recommendation:
  - `COMPARISON_READY_WITH_DOCUMENTED_DYNAMIC_FAIL_BAND`

Integration-branch continuation rule:

- use `docs/TRACK__qdesn_0p4p0_integration_handoff_20260406.md` as the canonical day-to-day
  status tracker on this branch;
- treat this file as the detailed historical tracker for the dynamic relaunch program;
- branch-level smoke/parity was confirmed on the `0.4.0` integration branch via:
  - `qdesn-dynamic-exdqlm-crossstudy-smoke-rerun-20260406-214100__git-288390b`
  - `4/4 SUCCESS` roots
  - `16` fit rows
  - `7 PASS / 8 WARN / 1 FAIL`
- the branch-local broad rerun also completed on this branch via:
  - `qdesn-dynamic-exdqlm-crossstudy-full-rerun-20260406-215700__git-288390b`
  - `34/36 SUCCESS`
  - `2/36 FAIL`
  - `37 PASS / 65 WARN / 42 FAIL`
  - `33/36` comparison-eligible-any
  - `8/36` comparison-eligible-full
  - recommendation:
    - `HOLD_QDESN_DYNAMIC_EXDQLM_WITH_GAPS`
- the first targeted fit-fail closure wave is now complete on this branch:
  - `qdesn-dynamic-exdqlm-crossstudy-fitfail-20260407-000615__git-54c5009`
  - `5/5` stages complete
  - `10/10` challenger profiles complete
  - clear local promotions:
    - `K510_gmix_balanced_rescue`
    - `K540_ridge_vb_guard_plus_softgamma`
    - `K580_mixed_short_guard_plus_softgamma`
  - conservative unresolved-stage carry-forward:
    - `S4` uses `K550_rhs_softfreeze_local` as working control for the next wave
  - effective residual source state after Wave 1:
    - `26` FAIL rows
    - `17` fail-carrying roots
    - `2` root-status FAILs
    - `35` comparison-eligible-any roots
    - `19` comparison-eligible-full roots
- primary closeout report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_fit_fail_wave1_closeout_and_wave2_inventory_20260407.md`
- the next branch-local validation milestone is therefore a **second residual-only overnight
  wave**, not another smoke gate, not another broad rerun, and not a generic global retuning
  search.
- that second residual wave is now validated in prepare-only on this branch:
  - `qdesn-dynamic-exdqlm-crossstudy-residualfail-20260407-025317__git-2078ff9`
  - source mode:
    - `prior_fitfail_wave`
  - verified source coverage:
    - `17/17` fail-carrying roots
    - `26/26` FAIL rows
  - verified stage sizes:
    - `5 / 3 / 1 / 4 / 4`
  - challenger profile count:
    - `16`
  - planned root-campaigns:
    - `56`
  - plan:
    - `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_residual_fail_closure_wave_20260407.md`
  - manifest:
    - `config/validation/qdesn_dynamic_exdqlm_crossstudy_residual_fail_closure_wave_manifest.yaml`
- the detached overnight residual-wave launch is now live on this branch:
  - `qdesn-dynamic-exdqlm-crossstudy-residualfail-20260407-025827__git-eed98f2`
  - initial healthcheck:
    - launcher live
    - runner `RUNNING`
    - current stage:
      - `R1_gausmix_tt5000_residual`
    - current profile:
      - `L610_gmix_long_vbguard_local`

## 3) Current Best Read Of The Target Dynamic Surface

Observed live reference surface on disk:

- root family:
  - `function_testing_20260309_dynamic_dlm_family_qspec`
- scenario currently observed:
  - `dlm_constV_smallW`
- families:
  - `gausmix`
  - `laplace`
  - `normal`
- taus:
  - `0.05`
  - `0.25`
  - `0.95`
- dynamic fit horizons:
  - `lastTT500`
  - `lastTT5000`

Observed reference dataset-cell count:

- `18`

Hard rule:

- do not trust this by memory alone;
- materialize the canonical reference grid directly from the live reference roots before any real
  launch.

## 4) Correct QDESN Analog Grid

If the observed `18`-cell dynamic surface is confirmed:

- `18` dynamic dataset cells
- `2` QDESN priors
- total roots:
  - `36`

Per root fit matrix:

- `vb/exal`
- `mcmc/exal`
- `vb/al`
- `mcmc/al`

Expected fit rows:

- `144`

## 5) What Is Explicitly Out Of Scope

- no further compute on the static cross-study as the primary validation target;
- no direct reuse of `config/validation/qdesn_dynamic_family_prior_grid.csv` as the launch grid;
- no broad search for one generic tuning profile before the dynamic-aligned baseline run exists;
- no reopening of the closed dynamic certification family search.

## 6) Read First

1. `docs/REPORT__qdesn_exdqlm_dynamic_scope_correction_20260406.md`
2. `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_validation_20260406.md`
3. `docs/TRACK__qdesn_static_exdqlm_crossstudy_validation.md`
4. `docs/PLAN__qdesn_validation_final_r512_certification_20260403.md`
5. `config/validation/qdesn_dynamic_family_prior_grid.csv`
6. `config/validation/qdesn_static_exdqlm_crossstudy_grid.csv`

## 7) Core Assets

Implemented:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_defaults.yaml`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_grid.csv`
- `scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_grid.R`
- `R/qdesn_dynamic_exdqlm_crossstudy.R`
- `scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R`
- `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_validation.R`
- `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_validation.R`

Validated campaign artifacts:

- smoke prepare-only:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_validation/qdesn-dynamic-exdqlm-crossstudy-smoke-20260406-155404__git-eb141cc/launch/qdesn_dynamic_exdqlm_crossstudy_preflight.md`
- full prepare-only:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_validation/qdesn-dynamic-exdqlm-crossstudy-full-20260406-155404__git-eb141cc/launch/qdesn_dynamic_exdqlm_crossstudy_preflight.md`
- corrected smoke run:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_validation/qdesn-dynamic-exdqlm-crossstudy-smoke-20260406-threadsfix__git-eb141cc/20260406-161217__git-eb141cc/summary/qdesn_dynamic_crossstudy_summary.md`
- full campaign summary:
  - `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_validation/qdesn-dynamic-exdqlm-crossstudy-full-20260406-163041__git-85760fe/20260406-163050__git-85760fe/summary/qdesn_dynamic_crossstudy_summary.md`
- full comparison summary:
  - `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_validation/qdesn-dynamic-exdqlm-crossstudy-full-20260406-163041__git-85760fe/20260406-163050__git-85760fe/comparison_vs_reference/comparison_summary.md`
- full campaign progress table:
  - `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_validation/qdesn-dynamic-exdqlm-crossstudy-full-20260406-163041__git-85760fe/20260406-163050__git-85760fe/tables/campaign_progress.csv`

## 8) Move-Forward Rules

1. reconstruct the canonical dynamic reference surface from disk first;
2. write a checked-in grid only after the reconstruction matches expectations;
3. run a narrow smoke batch before the broad batch launch if the external dynamic path is new;
4. use prepare-only before any real launch batch;
5. launch the broad dynamic analog before any local debt-only follow-up;
6. only after the broad dynamic analog completes should local tuning be considered;
7. on this integration branch, confirm parity with at least the dynamic smoke contract before
   treating the predecessor-branch result as branch-local evidence.
8. once the smoke contract is confirmed on this branch, launch the full rerun as one detached
   supervised batch instead of splitting it into many manual sub-campaigns.

## 9) Success Criteria

The predecessor-branch broad launch remains valid as historical evidence, but this branch now has
its own completed smoke and broad rerun evidence.

This integration branch should therefore treat the following as the immediate validation gates:

1. preserve the completed branch-local broad rerun as the source baseline;
2. update trackers and closeout docs to reflect the completed branch-local rerun state;
3. run a targeted residual fail-closure wave over the remaining fail and noneligible pockets;
4. promote a stage-local winner only if it clearly beats the completed branch-local source
   baseline on that targeted slice;
5. after the targeted wave completes, rebuild the branch-local `PASS / WARN / FAIL` inventory from
   actual outputs and decide on any further cleanup.

## 10) Latest Update (2026-04-07)

The final rhs-only cleanup wave is complete, and the branch is now ready to move into main
comparison analysis.

Completed final wave:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-finalfail-20260407-133928__git-512e982`
- result:
  - `2/2` stages complete
  - `10/10` profiles complete
  - `40/40` root-campaigns executed
- stage-local winners reported by the wave:
  - `F1 -> M850_rhs_long_burnheavy1300`
  - `F2 -> M940_short_rhs_narrow1200_diag5`

Important reconciliation result:

- the stage-local winners clear the exact target rows inside the wave;
- as full 4-root stage swaps, they do **not** produce clear full-study improvements;
- but when evaluated as **exact-root local promotions**, both do clearly improve the previously
  failing scenarios.

Authoritative branch-local baseline is therefore now:

- `R1 -> L640_gmix_long_split_diag`
- `R2 -> L670_gmix_short_diag_mix`
- `R3 -> L720_ridge_long_softgamma_plus`
- `R4 -> L760_rhs_long_vbguard_deep`
- `R5 -> L770_short_mixed_local_mcmc`
- plus exact-root overrides:
  - `root__dynamic__dlm_constV_smallW__normal__tau_0p05__lasttt_5000__qdesn_rhs_ns -> M850_rhs_long_burnheavy1300`
  - `root__dynamic__dlm_constV_smallW__normal__tau_0p95__lasttt_500__qdesn_rhs_ns -> M940_short_rhs_narrow1200_diag5`

Current authoritative branch-local full-study state:

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

Move-forward rule:

- do not launch another residual wave by default
- proceed from the authoritative zero-fail baseline above
- use root-specific local tuning only where the evidence already shows it is clearly better
- treat further validation compute as optional confirmation work, not unresolved fail closure

## 11) Main Comparison Analysis Pack (2026-04-07)

The main comparison-analysis pack has now been regenerated from the authoritative reconciled
baseline on this branch.

Analysis run:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-214041__git-5c3762f`
- report root:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-214041__git-5c3762f`
- summary:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-214041__git-5c3762f/summary/qdesn_dynamic_main_comparison_analysis.md`
- 144-row case-table summary:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-214041__git-5c3762f/summary/qdesn_dynamic_main_comparison_case_table.md`
- comparison summary:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-214041__git-5c3762f/comparison_vs_reference/comparison_summary.md`
- overview table:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-214041__git-5c3762f/tables/analysis_overview.csv`
- method/model table:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-214041__git-5c3762f/tables/authoritative_fit_method_model_summary.csv`
- explicit q-true fit tables:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-214041__git-5c3762f/tables/authoritative_fit_inference_summary.csv`
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-214041__git-5c3762f/tables/authoritative_fit_model_summary.csv`
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-214041__git-5c3762f/tables/authoritative_fit_family_summary.csv`
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-214041__git-5c3762f/tables/authoritative_fit_tau_summary.csv`
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-214041__git-5c3762f/tables/authoritative_fit_method_model_compact.csv`
- direct per-fit case tables:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-214041__git-5c3762f/tables/authoritative_fit_case_table.csv`
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-214041__git-5c3762f/tables/authoritative_fit_case_table_readable.csv`
- QDESN-vs-reference axis deltas:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-214041__git-5c3762f/tables/authoritative_qdesn_vs_reference_fit_axis_delta.csv`
- root override map:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-214041__git-5c3762f/tables/authoritative_root_override_map.csv`
- reconciliation report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_root_override_reconciliation_20260407.md`

Pack-level findings:

- authoritative full-study state is now:
  - `76 PASS`
  - `68 WARN`
  - `0 FAIL`
  - `0 / 36` root-status FAILs
  - `36 / 36` comparison-eligible-any roots
  - `36 / 36` comparison-eligible-full roots
- `ridge` remains the cleaner branch-local prior on signoff:
  - `53 PASS / 19 WARN / 0 FAIL`
- `rhs_ns` is now fully comparison-eligible as well:
  - `23 PASS / 49 WARN / 0 FAIL`
- `vb/al` is the healthiest and fastest broad method-model combination:
  - `29 PASS / 7 WARN / 0 FAIL`
  - mean runtime about `2.83 s`
- `mcmc/exal` is still the softest area scientifically and the slowest broad combination, but it
  no longer carries FAIL rows:
  - `1 PASS / 35 WARN / 0 FAIL`
  - mean runtime about `30.76 s`
- the refreshed committed-SHA pack now treats the fitted/train path as the primary validation
  window because `holdout_n = 1`
- the refreshed pack now makes the `qhat`-vs-`q_true` goodness-of-fit metrics explicit and
  recomputes them from saved artifacts plus source truth:
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
- those metrics are now summarized by inference, model, prior, family, tau, and inference+model
- the pack now includes a non-aggregated 144-row per-fit case table for direct case-by-case review
- VB vs MCMC runtime ratios range from about `2.18x` to `14.14x` across prior/model/horizon
  slices
- direct QDESN-vs-reference signoff/readiness deltas are now computed with normalized model labels:
  - `al <-> dqlm`
  - `exal <-> exdqlm`
- reference runtime remains unavailable in the mirrored reference summaries, so direct runtime
  deltas versus exdqlm are still `NA`

Recommended use:

- use this pack as the authoritative branch-local source for downstream main comparison analysis
- do not launch another tuning wave by default from this state
- treat validation/tuning on this branch as effectively complete unless explicit confirmation reruns
  are later requested

## 12) Deep-DESN Challenger Continuation And Normalized Multiseed Investigation (2026-04-11)

This section records the later deep-DESN challenger continuation work on the integration branch.
It does **not** replace the authoritative simple-DESN zero-FAIL branch-local baseline above.

Completed deep-DESN rhs-long MCMC wave:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-rhslongmcmc-20260410-163031__git-ceab523`
- closeout report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_wave3_closeout_and_normalized_multiseed_inventory_20260411.md`
- summary:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rhs_long_mcmc_wave/qdesn-dynamic-exdqlm-crossstudy-deepdesn-rhslongmcmc-20260410-163031__git-ceab523/summary/qdesn_dynamic_crossstudy_fit_fail_closure_results.md`

Completed `F`-wave stage decisions:

- `F1_rhs_long_gausmix_mcmc -> KEEP_SOURCE_BASELINE`
- `F2_rhs_long_laplace_exal -> KEEP_SOURCE_BASELINE`
- `F3_rhs_long_normal_lower_mcmc -> PROMOTE_F630_rhs_long_normal_lower_guard320_recenter4000`
- `F4_rhs_long_normal_upper_exal -> KEEP_SOURCE_BASELINE`

Working deep-DESN challenger source after promoting `F630`:

- `71 PASS`
- `60 WARN`
- `13 FAIL`
- `36 / 36` root execution `SUCCESS`
- `0 / 36` root execution `FAIL`
- `36 / 36` comparison-eligible-any
- `27 / 36` comparison-eligible-full

Residual concentration after `F630`:

- all `13` remaining FAIL rows are:
  - `rhs_ns`
  - `fit_size = 5000`
  - `mcmc`
- residual family/model split:
  - `gausmix al = 3`
  - `gausmix exal = 3`
  - `laplace exal = 3`
  - `normal al = 2`
  - `normal exal = 2`
- there are no remaining root-status FAILs

Investigation result:

- another geometry-only residual wave is **not** the default next move;
- the higher-value continuation is now a **normalized multiseed relaunch investigation** built on
  the post-`F630` source.

New planning source of truth:

- closeout/inventory report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_wave3_closeout_and_normalized_multiseed_inventory_20260411.md`
- staged relaunch plan:
  - `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_normalized_multiseed_relaunch_20260411.md`

Current rule:

- freeze the deep-DESN challenger source at the post-`F630` state for planning purposes;
- do not launch the big normalized multiseed rerun until seed plumbing, selection logic,
  posterior-draw semantics, and storage handling are explicitly implemented and canary-validated.

## 13) Normalized Multiseed Implementation State (2026-04-11)

The normalized multiseed relaunch infrastructure is now implemented on this branch and validated at
the code-load and `prepare-only` levels.

Implementation report:

- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_normalized_multiseed_implementation_and_preflight_20260411.md`

Implemented assets:

- defaults:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_normalized_multiseed_defaults.yaml`
- canary grid:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_normalized_multiseed_canary_grid.csv`
- canary grid materializer:
  - `scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_normalized_multiseed_canary_grid.R`
- full wrappers:
  - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_normalized_multiseed_validation.R`
  - `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_normalized_multiseed_validation.R`
  - `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_normalized_multiseed_validation.R`
- canary wrappers:
  - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_normalized_multiseed_canary_validation.R`
  - `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_normalized_multiseed_canary_validation.R`
  - `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_normalized_multiseed_canary_validation.R`

Implementation highlights:

- MCMC now supports `4` deterministic seed replicates per method with:
  - DESN seed
  - MCMC RNG seed
  - VB warm-start seed
  - synthesis seed
- best-seed selection is now recorded by:
  - signoff grade first
  - then `forecast_CRPS_mean`
  - then runtime
  - then seed replicate id
- root-level and campaign-level `mcmc_seed_selection.csv` outputs are now supported
- non-winning heavy seed artifacts are now pruned
- staged effective-w300 source inventory is now reused when already materialized
- reference inventory parsing now tolerates missing raw reference `sim_output.rds` files

Normalized contract now wired:

- VB / posterior draws:
  - `posterior_metric_draws = 20000`
  - `sampling.nd_draws = 20000`
  - `synthesis.n_samp = 20000`
- MCMC:
  - `n_burn = 5000`
  - `n_mcmc = 20000`
  - `thin = 1`
- parallelism:
  - outer workers `1`
  - inner seed workers `4`

Validated preflight state:

- code load:
  - passes
- helper checks:
  - passes
- canary `prepare-only`:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-normseed-canary-preflight-20260411`
  - passes
- full `prepare-only`:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-normseed-full-preflight-20260411`
  - passes

Current launch rule:

- the normalized multiseed relaunch surface is now implementation-ready;
- no canary execution run or full relaunch has been started in this tracker update;
- launch remains a deliberate next step after committing and pushing the implementation state.

Live normalized multiseed canary launch:

- setup/launch report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_normalized_multiseed_canary_setup_and_launch_20260411.md`
- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-normseed-canary-20260411-181806__git-fd274f0`
- detached session:
  - `qdesn_dynx_0411_181807`
- launch state:
  - `6` selected roots
  - `1 / 6` materialized
  - `1 RUNNING`
  - `0 SUCCESS`
  - `0 FAIL`
  - `0` root execution errors
- current opening root:
  - `root__dynamic__dlm_constV_smallW__gausmix__tau_0p05__lasttt_500__qdesn_ridge`
- current opening method observed:
  - `exal | vb`
- canary purpose:
  - validate live multiseed execution, winner selection, pruning, and normalized storage/runtime
    behavior before any full relaunch

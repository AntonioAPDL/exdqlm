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

## Effective-W300 Posterior-Draw Rerun Note (2026-04-07)

There is now a new branch-local rerun program for the same dynamic surface with a stronger metric
contract:

- plan:
  - `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_rerun_20260407.md`
- setup and smoke report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_setup_and_smoke_20260407.md`
- live relaunch queue:
  - `docs/TRACK__qdesn_dynamic_exdqlm_crossstudy_effective_w300_relaunch_queue_20260408.md`
- failure investigation:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_failure_investigation_20260408.md`
- failed-root relaunch plan:
  - `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_failed_root_relaunch_20260408.md`
- defaults:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_defaults.yaml`

Current contract:

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

Current validation state of this new rerun:

- prepare-only passed for:
  - smoke
  - full
- corrected smoke run:
  - `qdesn-dynamic-exdqlm-crossstudy-smoke-20260407-231231__git-812cb58`
  - `4/4 SUCCESS`
  - `8 PASS / 6 WARN / 2 FAIL`
  - exact `train_n_eval` verified on the completed `500` roots:
    - `500`
  - exact `X_train` size verified from live pipeline logs on the `5000` roots:
    - `5000`
- completed full rerun from committed state:
  - commit:
    - `cdfd1a9`
  - run tag:
    - `qdesn-dynamic-exdqlm-crossstudy-full-20260407-233147__git-cdfd1a9`
  - outcome:
    - `30/36 SUCCESS`
    - `6/36 FAIL`
- failure investigation conclusion:
  - failures are implementation / numerical failures, not merely weak-signoff cases
  - primary cause:
    - `mcmc_al` latent-`v` GIG invalid draws
  - secondary cause:
    - failed-fit summary rows not always written
- failed-root relaunch from repaired state:
  - repaired commit:
    - `bcdb438`
  - run tag:
    - `qdesn-dynamic-exdqlm-crossstudy-failedrelaunch-20260408-012443__git-bcdb438`
  - scope:
    - `6`
  - outcome:
    - `6/6 SUCCESS`
    - `24/24` fit summaries written
    - `0` repeated root execution failures
- authoritative repaired comparison pack:
  - run tag:
    - `qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-015614__git-554809e`
  - summary:
    - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-015614__git-554809e/summary/qdesn_dynamic_main_comparison_analysis.md`
  - report:
    - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_main_comparison_outputs_20260408.md`
  - 144-row case table:
    - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-015614__git-554809e/tables/authoritative_fit_case_table_readable.csv`
  - current rolled state:
    - `40 PASS`
    - `69 WARN`
    - `35 FAIL`
    - `0/36` root-status FAILs
    - `34/36` comparison-eligible-any
    - `16/36` comparison-eligible-full

## 2) Current Status

Status of this long-form tracker: **historical relaunch record**.

For the current branch-local effective-w300 comparison-analysis state, use the note above plus:

- `docs/TRACK__qdesn_0p4p0_integration_handoff_20260406.md`
- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_main_comparison_outputs_20260408.md`
- `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_rerun_20260407.md`
- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_setup_and_smoke_20260407.md`
- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_failure_investigation_20260408.md`
- `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_failed_root_relaunch_20260408.md`
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

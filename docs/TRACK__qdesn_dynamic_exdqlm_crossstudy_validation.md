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

## 2) Current Status

Status: **carry-forward dynamic relaunch implementation and broad dynamic run are completed on the
predecessor QDESN branch; this integration branch now treats that result as the authoritative
baseline and current rerun target**

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
- branch-level smoke/parity is now confirmed on the `0.4.0` integration branch via:
  - `qdesn-dynamic-exdqlm-crossstudy-smoke-rerun-20260406-214100__git-288390b`
  - `4/4 SUCCESS` roots
  - `16` fit rows
  - `7 PASS / 8 WARN / 1 FAIL`
- the detached supervised **full** rerun is now live on this branch via:
  - `qdesn-dynamic-exdqlm-crossstudy-full-rerun-20260406-215700__git-288390b`
  - tmux session:
    - `qdesn_dynx_rerun_0406_215700`
  - launch metadata:
    - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_validation/qdesn-dynamic-exdqlm-crossstudy-full-rerun-20260406-215700__git-288390b/launch/launcher_session.json`
- the next branch-local validation milestone is therefore the **completed** full rerun, not
  another smoke gate.

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

The predecessor-branch broad launch is already complete and usable as carry-forward evidence.

This integration branch should treat the following as its immediate validation gates:

1. the canonical dynamic reference grid is materialized and validated;
2. the QDESN dynamic analog runner can still consume those external dynamic inputs on the `0.4.0`
   integration base;
3. prepare-only passes cleanly on this branch;
4. the narrow real smoke batch closes successfully on this branch;
5. the detached broad rerun is launched on this branch after smoke closes cleanly;
6. only after that full rerun completes should any fail-band cleanup decision be taken.

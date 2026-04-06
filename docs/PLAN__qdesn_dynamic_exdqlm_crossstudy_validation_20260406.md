# PLAN: QDESN Dynamic exdqlm-Aligned Validation Relaunch (2026-04-06)

Date: 2026-04-06
Branch: `feature/qdesn-mcmc-alternative`
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`
Reference repo: `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs`

## 1) Goal

Replace the mis-scoped static cross-study with the validation study that was actually wanted from
the beginning:

- fit **QDESN** on the same **dynamic** exdqlm validation datasets;
- preserve:
  - families
  - taus
  - dynamic fit horizons
  - inference methods
  - likelihood families
- add the QDESN prior axis:
  - `ridge`
  - `rhs_ns`
- produce direct QDESN-vs-exdqlm comparison outputs on the same dynamic dataset cells.

## 2) Scope Correction

This relaunch is a correction, not a continuation of the static cross-study.

The static cross-study remains a completed side study and must be preserved for auditability, but
it is no longer the primary deliverable for this comparison program.

## 3) Canonical Dynamic Reference Surface

### 3.1 Current observed dynamic family-qspec reference surface

The currently observed reference surface on disk is:

- root family:
  - `function_testing_20260309_dynamic_dlm_family_qspec`
- scenario:
  - `dlm_constV_smallW`
- families:
  - `gausmix`
  - `laplace`
  - `normal`
- taus:
  - `0.05`
  - `0.25`
  - `0.95`
- fit horizons:
  - `lastTT500`
  - `lastTT5000`

Current observed dataset-cell count:

- `18`

### 3.2 Hard rule

Do not hard-code the final launch grid from memory.

Instead:

1. materialize the canonical dynamic grid directly from the live reference results tree;
2. verify the discovered grid against the expected family/tau/horizon contract;
3. stop immediately if the discovered surface differs materially from the planned one.

## 4) QDESN Analog Grid

Assuming the observed `18`-cell dynamic surface is confirmed:

- QDESN priors:
  - `ridge`
  - `rhs_ns`
- QDESN roots:
  - `18 x 2 = 36`

Per root, run:

- `vb/exal`
- `mcmc/exal`
- `vb/al`
- `mcmc/al`

Expected total fit rows:

- `36 x 4 = 144`

## 5) Comparison Contract

For each dynamic reference dataset cell:

- same family
- same tau
- same fit horizon
- same inference method
- same likelihood

compare:

- QDESN result for `ridge`
- QDESN result for `rhs_ns`
- against the exdqlm dynamic reference result on that same cell

Outputs must preserve the QDESN prior axis explicitly rather than collapsing across priors.

Required join keys:

- `scenario_id`
- `family`
- `tau`
- `fit_horizon`
- `likelihood`
- `fit_method`
- `beta_prior_type`

Hard rule:

- the relaunched QDESN study must be keyed so that a single dynamic exdqlm cell can be joined
  cleanly against both QDESN priors without any manual reconciliation step.

## 6) What Must Change In Code

The current static cross-study machinery is not the right runner for this work.

We need a new external-dynamic helper stack:

- defaults:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_defaults.yaml`
- canonical grid materializer:
  - `scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_grid.R`
- checked-in dynamic grid:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_grid.csv`
- helper layer:
  - `R/qdesn_dynamic_exdqlm_crossstudy.R`
- runner:
  - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R`
- healthcheck:
  - `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_validation.R`

## 7) Why The Existing QDESN Dynamic Grid Should Not Be Reused Directly

The current dynamic certification grid:

- is scenario-based, not family-based;
- uses `tau = 0.50` rather than `0.25`;
- was built for the QDESN certification program, not for exdqlm-aligned dataset mirroring.

Therefore:

- reuse the dynamic orchestration style and proven dynamic defaults patterns where sensible;
- do **not** reuse the current `qdesn_dynamic_family_prior_grid.csv` as the launch grid for this
  relaunch.

## 8) Batch Launch Strategy

### Stage A: Scope correction and preflight

1. write the scope-correction report and new dynamic-aligned tracker;
2. mark the static cross-study as a completed side study, not the primary deliverable;
3. materialize the canonical dynamic reference grid from the exdqlm results tree;
4. validate:
   - family coverage
   - tau coverage
   - fit-horizon coverage
   - reference artifact presence

### Stage B: Implementation

1. build the new dynamic external-data helper and runner;
2. write prepare-only validation;
3. write one-root and one-family smoke capability;
4. wire comparison-table generation into campaign closeout.

### Stage C: Launch

Recommended launch policy:

- `threads = 1`
- `postpred_threads = 1`
- default workers: `6`
- fall back to `4` if other heavy jobs are active
- hard cap: `8`

Why:

- each root contains four fits including MCMC;
- the external dynamic path is more valuable than maximal CPU saturation;
- the first broad dynamic analog run should favor reliability and clean reporting.

Recommended batch structure:

1. Batch 0: discovery-only materialization
   - build the canonical exdqlm dynamic grid directly from the reference worktree;
   - stop if the discovered surface is not exactly what the run contract expects.
2. Batch 1: narrow smoke
   - one family
   - one tau
   - both fit horizons
   - both priors
   - total:
     - `4` roots
   - purpose:
     - validate the external dynamic QDESN path end to end before the full batch.
3. Batch 2: broad dynamic analog
   - all discovered dynamic cells
   - both priors
   - total expected roots:
     - `36`
   - purpose:
     - produce the actual QDESN-vs-exdqlm dynamic comparison surface.
4. Batch 3: debt-only follow-up, only if needed
   - restrict to the observed fail band from Batch 2;
   - no whole-surface relaunch unless a structural runner bug is found.

### Stage D: Post-launch move-forward logic

1. if the broad dynamic analog run is comparison-ready, stop and close out;
2. if a narrow FAIL band remains, launch a targeted debt-only follow-up on that band;
3. do not reopen broad search families unless the broad dynamic analog reveals a structural runner
   mismatch.

## 9) Efficiency Rules

1. no broad static reruns;
2. no reuse of the misaligned static cross-study as the target deliverable;
3. no reuse of the scenario-based dynamic certification grid as the cross-study launch grid;
4. no generic “one tuning solves everything” search at first launch;
5. use the current best dynamic-certified QDESN defaults as the shared starting baseline;
6. allow local tuning only after the true dynamic exdqlm-aligned fail surface is observed.

Additional efficiency boundary:

- do not start with local rescue waves;
- first establish the clean dynamic baseline map on the exact mirrored exdqlm surface;
- only then open targeted local repairs if a narrow residual fail band remains.

## 10) Trackers To Update

Must update:

- `docs/TRACK__qdesn_mcmc_validation_plan.md`
- `docs/TRACK__qdesn_validation_repair_20260331.md`
- `docs/TRACK__qdesn_static_exdqlm_crossstudy_validation.md`

Must add:

- `docs/REPORT__qdesn_exdqlm_dynamic_scope_correction_20260406.md`
- `docs/TRACK__qdesn_dynamic_exdqlm_crossstudy_validation.md`
- this plan file

## 11) Acceptance Criteria

Preflight acceptance:

- canonical dynamic reference grid materializes cleanly from disk;
- discovered dynamic cells match the checked-in grid;
- reference report roots contain the required comparison tables;
- no rows from the static-only surface leak into the dynamic launch grid.

Campaign completion acceptance:

- all planned QDESN dynamic roots materialize;
- all root outputs receive explicit root status;
- QDESN grouped summaries are written;
- exdqlm grouped reference summaries are written;
- QDESN-vs-exdqlm comparison tables are written;
- a final recommendation is emitted.

Scientific completion categories:

- `COMPARISON_READY_QDESN_DYNAMIC_EXDQLM_COMPLETE`
- `COMPARISON_READY_WITH_DOCUMENTED_DYNAMIC_FAIL_BAND`
- `HOLD_QDESN_DYNAMIC_EXDQLM_WITH_GAPS`

## 12) Definition Of Done

This corrected program is done only when:

1. QDESN has been run on the same dynamic exdqlm dataset cells intended for comparison;
2. QDESN-vs-exdqlm comparison outputs exist on that exact dynamic surface;
3. the resulting outputs are strong enough to support the intended dynamic side-by-side study.

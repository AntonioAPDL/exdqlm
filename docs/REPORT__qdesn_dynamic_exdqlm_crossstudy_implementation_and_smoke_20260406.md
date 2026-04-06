# REPORT: QDESN Dynamic exdqlm Cross-Study Implementation And Smoke (2026-04-06)

Date: 2026-04-06
Branch: `feature/qdesn-mcmc-alternative`
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`
Reference repo: `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs`

## 1) Purpose

Implement the corrected dynamic exdqlm-aligned QDESN validation program, validate it end to end on
the mirrored dynamic surface, and clear the implementation blockers before the broad relaunch.

## 2) What Was Implemented

Implemented assets:

- defaults:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_defaults.yaml`
- canonical grid:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_grid.csv`
- helper layer:
  - `R/qdesn_dynamic_exdqlm_crossstudy.R`
- grid materializer:
  - `scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_grid.R`
- runner:
  - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R`
- detached launcher:
  - `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_validation.R`
- healthcheck:
  - `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_validation.R`

The implemented runner now:

- reconstructs the canonical exdqlm dynamic reference surface from disk;
- stages QDESN inputs from the reference dynamic results tree;
- runs `vb/mcmc x exal/al` for each mirrored QDESN root;
- writes campaign-level QDESN summaries;
- writes side-by-side comparison tables against the exdqlm dynamic reference surface.

## 3) Confirmed Dynamic Reference Surface

Recovered directly from the live exdqlm results tree:

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

Recovered dynamic dataset cells:

- `18`

Mirrored QDESN grid:

- dataset cells:
  - `18`
- QDESN priors:
  - `2`
- total QDESN roots:
  - `36`
- total fit rows:
  - `144`

## 4) Implementation Blockers Found And Fixed

### 4.1 YAML scalar coercion on `y_column`

Observed smoke failure:

- the dynamic smoke runner passed `columns.y = "TRUE"` into `pipeline_real_main.R`;
- the pipeline then failed with:
  - `Target column 'TRUE' not found. Header: y`

Root cause:

- `y_column: y` in YAML was parsed as boolean `TRUE` under YAML 1.1 scalar rules.

Fix applied:

- quoted the defaults entry:
  - `y_column: "y"`
- hardened the shared config builder in:
  - `R/qdesn_static_exdqlm_crossstudy.R`
- new guard behavior:
  - logical `TRUE` on `external_data.y_column` now falls back to `"y"` with an explicit warning
    instead of silently poisoning the run config.

### 4.2 Child BLAS oversubscription

Observed runtime issue:

- each `pipeline_real_main.R` child was spawning dozens of threads;
- a `4`-worker smoke therefore oversubscribed the machine badly.

Fix applied:

- capped child threads in:
  - `R/run_esn_pipeline.R`
- applied environment caps:
  - `OMP_NUM_THREADS`
  - `OPENBLAS_NUM_THREADS`
  - `MKL_NUM_THREADS`
  - `VECLIB_MAXIMUM_THREADS`
  - `NUMEXPR_NUM_THREADS`
  - `BLAS_NUM_THREADS`
- final behavior:
  - child fits now run with a one-thread cap and no longer explode into large BLAS thread pools.

## 5) Validation Evidence

### 5.1 Prepare-only

Prepare-only passed for both batch scopes:

- smoke:
  - `qdesn-dynamic-exdqlm-crossstudy-smoke-20260406-155404__git-eb141cc`
- full:
  - `qdesn-dynamic-exdqlm-crossstudy-full-20260406-155404__git-eb141cc`

### 5.2 Real smoke run

Authoritative validated smoke run:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-smoke-20260406-threadsfix__git-eb141cc`

Smoke outcome:

- selected roots:
  - `4`
- materialized roots:
  - `4/4`
- root status:
  - `4 SUCCESS`
  - `0 FAIL`
- fit rows:
  - `16`
- fit signoff mix:
  - `6 PASS`
  - `8 WARN`
  - `2 FAIL`
- recommendation:
  - `COMPARISON_READY_WITH_DOCUMENTED_DYNAMIC_FAIL_BAND`

Important interpretation:

- the corrected runner is operationally sound on the intended dynamic surface;
- the remaining smoke issues are scientific signoff debt, not orchestration or staging failure.

## 6) Smoke Read

The smoke was intentionally narrow:

- family:
  - `normal`
- tau:
  - `0.25`
- fit sizes:
  - `500`
  - `5000`
- priors:
  - `ridge`
  - `rhs_ns`

Key read:

- all four smoke roots completed successfully;
- ridge was fully comparison-eligible on both smoke horizons;
- the only smoke `FAIL` rows were:
  - `rhs_ns / exal / mcmc @ lastTT500`
  - `rhs_ns / exal / vb @ lastTT5000`

That is acceptable for the broad relaunch because:

- it leaves the runner contract intact;
- it produces valid comparison outputs;
- it gives a clear first residual fail band if the full broad run also shows rhs-heavy exAL debt.

## 7) Move-Forward Decision

Decision:

- proceed with the broad dynamic exdqlm-aligned relaunch.

Why:

1. the dynamic surface is now confirmed from disk;
2. the checked-in mirrored QDESN grid is correct;
3. prepare-only passed on both smoke and full scopes;
4. the real smoke batch completed successfully;
5. the implementation blockers were fixed at the root rather than worked around.

## 8) Next Step

Next operational step:

- update trackers with the implementation-and-smoke state;
- commit and push the implementation;
- launch the full `36`-root dynamic cross-study through the detached supervised path.

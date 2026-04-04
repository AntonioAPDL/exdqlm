# REPORT: QDESN Static exdqlm Cross-Study Investigation (2026-04-04)

Date: 2026-04-04  
Primary repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`  
Primary branch: `feature/qdesn-mcmc-alternative`  
Reference repo: `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs`  
Reference branch: `validation/rerun-after-0.4.0-sync`

## 1) Executive Decision

The cross-study goal is clear and implementable.

The correct QDESN counterpart to the exdqlm static validation study is:

- a **static-only initial launch** on the same `gausmix / normal / laplace` dataset cells used in
  the exdqlm signoff surface;
- with QDESN fits run under:
  - likelihood families: `exal`, `al`
  - inference methods: `vb`, `mcmc`
  - priors: `ridge`, `rhs_ns`
- using a deterministic analog grid derived directly from the exdqlm signoff roots on disk;
- with dynamic row-15 kept out of the initial launch as a separate sidecar problem.

This is not a re-run of the dynamic QDESN certification study. It is a separate, static,
cross-worktree validation program.

## 2) What The exdqlm Study Surface Really Is

### 2.1 Publishable static signoff surface

Recovered directly from the reference worktree signoff roots:

- paper signoff roots: `18`
- shrink signoff roots: `36`
- total signoff roots: `54`
- total fit rows: `216`
- total VB-vs-MCMC algorithm-pair rows: `108`
- total AL-vs-exAL model-pair rows: `108`

Underlying unique static dataset cells:

- `36` total unique dataset cells
- `18` paper cells:
  - `3 families x 3 taus x 2 fit_sizes`
- `18` shrink cells:
  - the same dataset-cell lattice, but with two reference prior variants on disk

Axes:

- root kinds:
  - `static_paper`
  - `static_shrink`
- families:
  - `gausmix`
  - `laplace`
  - `normal`
- taus:
  - `0.05`
  - `0.25`
  - `0.95`
- fit sizes / time horizons:
  - `100`
  - `1000`

### 2.2 What is not the same thing as the final signoff surface

The stale exAL MCMC debt slice discussed in the reference tracker is:

- `72` rows total
- `54` current RHS-NS refresh rows
- `18` legacy RHS comparison rows

That `72`-row debt slice is a refresh/recovery program, not the same thing as the final unique
static dataset lattice.

### 2.3 Current-vs-legacy semantics

The reference study repeatedly treats current-vs-legacy as a provenance and comparison-contract
issue, not as a distinct dataset issue.

Recovered rule:

- current static refresh rows are intended to represent the current `rhs_ns` scope
- legacy overlap rows preserve old `rhs` comparison semantics
- overlapping rows can share path layout but still differ in intended prior semantics

This matters for QDESN because the analog study must preserve this provenance explicitly in
metadata and reporting rather than pretending the historical split never existed.

### 2.4 Explicit exclusions

The on-disk static roots also include `gausmix @ tau=0.50`, but those rows sit outside the final
signoff surface:

- they have fit summaries
- they do not have the full signoff stack used by the final study

Therefore:

- `gausmix @ tau=0.50` must be excluded from the QDESN cross-study launch

Dynamic row `15` is also tracked separately in the reference study and should remain a sidecar
problem until the static analog is closed cleanly.

## 3) What The QDESN Analog Should Be

### 3.1 Correct analog choice

The right initial analog is:

- **static only**
- **no dynamic row-15 sidecar in the first launch**
- **no reopening of the dynamic DLM tuning/certification surface**

### 3.2 QDESN analog grid

One QDESN root should correspond to:

- one unique exdqlm static dataset cell
- one QDESN prior choice

Therefore the initial QDESN analog grid is:

- `36` dataset cells
- `2` QDESN priors (`ridge`, `rhs_ns`)
- total QDESN roots: `72`

Per QDESN root, run:

- `vb/exal`
- `mcmc/exal`
- `vb/al`
- `mcmc/al`

Expected total QDESN fit rows:

- `72 roots x 4 fits = 288`

Expected QDESN comparison tables:

- VB-vs-MCMC algorithm-pair rows:
  - `72 roots x 2 likelihood families = 144`
- AL-vs-exAL model-pair rows:
  - `72 roots x 2 inference methods = 144`

### 3.3 What can and cannot be mirrored exactly

Can be mirrored exactly:

- dataset families
- taus
- fit sizes / horizon lengths
- root-kind split (`static_paper` vs `static_shrink`)
- exact source simulated datasets via `sim_output.rds`
- exogenous design matrix `extras$X`

Cannot be mirrored exactly without qualification:

- legacy `rhs` prior rows
  - QDESN target priors are `ridge` and `rhs_ns`, not `rhs`
- the static exdqlm “fit the whole dataset directly” contract
  - QDESN real-mode currently requires a one-step holdout (`H_forecast >= 1`)

The resulting rule is:

- QDESN will preserve reference prior provenance as metadata:
  - `source_reference_priors`
  - `source_current_rhsns_member`
  - `source_legacy_rhs_member`
- but the actual QDESN prior axis is:
  - `ridge`
  - `rhs_ns`

## 4) Important Unavoidable Difference

QDESN real-mode does not fit an entirely holdout-free static job through the existing pipeline.

The practical workaround is:

- use the exact reference dataset for each root
- hold out the last observation only
- evaluate the primary static comparison surface on the training fit by joining:
  - `df_pred_tr$q_pred`
  - to the stored true quantile series from `sim_output.rds`

This is a small but real contract difference and must be documented in all comparison outputs.

## 5) QDESN Lessons That Must Be Hard Rules Here

Carried forward from the completed QDESN validation program:

1. exact-runner parity matters more than local pilot wins
2. staged and deterministic manifests are mandatory
3. operational health must be tracked separately from scientific quality
4. comparison tables are first-class deliverables, not optional extras
5. broad relaunches should not replace debt accounting
6. WARN is documentable; FAIL is the real repair boundary
7. baseline and provenance semantics must be frozen in files, not left implicit

The cross-study should therefore use:

- deterministic grid materialization
- prepare-only validation
- explicit preflight manifests
- explicit comparison-vs-reference outputs
- a healthcheck script separate from the runner

## 6) Reuse Decision

The generic QDESN dynamic-wave machinery is reusable only in pattern, not directly in runner form.

What can be reused:

- manifest/preflight/prepare-only style
- healthcheck/reporting style
- signoff helpers from `R/qdesn_mcmc_validation.R`
- comparison/report-root conventions

What could not be reused directly:

- the toy/dynamic root runner in `R/qdesn_mcmc_validation.R`
  - it generates internal toy data
  - it is not an external-static dataset runner

Therefore the correct architecture is:

- a new external-static cross-study helper layer
- a deterministic grid materializer
- a dedicated runner wrapper
- a dedicated healthcheck wrapper

## 7) Comparison Outputs That Define Success

The study is considered comparison-ready when it produces:

- root-level fit summaries
- VB-vs-MCMC pair tables
- AL-vs-exAL model-pair tables
- root signoff summaries
- grouped QDESN summaries by root kind / family / tau / fit size / prior
- grouped reference summaries from the exdqlm surface
- QDESN-vs-reference surface tables
- an integrated campaign recommendation

The recommendation categories are:

- `COMPARISON_READY_QDESN_STATIC_CROSSSTUDY_COMPLETE`
- `COMPARISON_READY_WITH_DOCUMENTED_FAIL_BAND`
- `HOLD_QDESN_STATIC_CROSSSTUDY_WITH_GAPS`

## 8) Bottom Line

The cross-study scope is clear enough to implement now.

The right first launch is:

- static only
- `72` QDESN roots
- exact reuse of the exdqlm signoff datasets
- deterministic prepare-only + preflight
- no dynamic row-15 sidecar in the initial launch
- no reopening of the dynamic DLM tuning program

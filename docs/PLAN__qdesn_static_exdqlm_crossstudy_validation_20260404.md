# PLAN: QDESN Static exdqlm Cross-Study Validation (2026-04-04)

Date: 2026-04-04  
Branch: `feature/qdesn-mcmc-alternative`  
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1) Goal

Run the QDESN counterpart to the exdqlm static validation study on the same recovered static
dataset surface:

- families: `gausmix`, `laplace`, `normal`
- taus: `0.05`, `0.25`, `0.95`
- fit sizes: `100`, `1000`
- root kinds: `static_paper`, `static_shrink`

using QDESN fits with:

- likelihood families: `exal`, `al`
- inference methods: `vb`, `mcmc`
- priors: `ridge`, `rhs_ns`

## 2) Why This Is The Right Next Program

The dynamic QDESN certification program is closed:

- `R512_r412_pass2_chain1000` is certified on the dynamic matrix
- the dynamic tuning question is no longer the blocker

The unresolved comparison task is different:

- build the QDESN analog on the same static exdqlm datasets
- do it with the same validation discipline learned from the QDESN dynamic work

This is therefore a cross-study validation program, not another tuning wave.

## 3) Scope Decision

Initial launch scope:

- **include**
  - static signoff surface only
  - `static_paper`
  - `static_shrink`
  - `gausmix`, `laplace`, `normal`
  - taus `0.05`, `0.25`, `0.95`
  - fit sizes `100`, `1000`
  - QDESN priors `ridge`, `rhs_ns`
- **exclude**
  - `gausmix @ tau=0.50`
  - dynamic row-15 sidecar
  - any reopening of the dynamic DLM QDESN tuning program

## 4) Analog Grid Specification

Recovered reference static dataset cells:

- `36` unique cells total
  - `18` paper cells
  - `18` shrink cells

QDESN root mapping:

- `1` QDESN root per dataset cell per QDESN prior
- `36 x 2 = 72` QDESN roots

Per-root fit matrix:

- `vb/exal`
- `mcmc/exal`
- `vb/al`
- `mcmc/al`

Expected totals:

- roots: `72`
- fit rows: `288`
- VB-vs-MCMC algorithm-pair rows: `144`
- AL-vs-exAL model-pair rows: `144`

Metadata preserved from the exdqlm study:

- `source_reference_priors`
- `source_reference_root_count`
- `source_current_rhsns_member`
- `source_legacy_rhs_member`

## 5) Compute Plan

Server policy:

- machine: `64` logical CPUs, large memory
- no nested parallelism
- `threads = 1`
- `postpred_threads = 1`

Chosen default launch policy:

- default workers: `6`
- if conflicting heavy QDESN jobs are active: reduce to `4`
- hard cap: `16`

Why `6` is the default:

- each root contains four fits and includes MCMC work
- the static cross-study uses external data staging plus real-mode pipeline execution
- the goal is stable overnight throughput, not maximal saturation
- `6` workers keeps the job comfortably parallel without crowding the host

## 6) Validation Workflow

1. recover the canonical grid directly from the exdqlm signoff roots
2. validate the reference contract
3. validate the checked-in grid against the canonical recovered grid
4. run `--prepare-only`
5. run a one-root smoke if needed for confidence on the external-static path
6. launch the full campaign
7. run healthcheck
8. generate grouped QDESN summaries plus QDESN-vs-reference comparison outputs

## 7) Files To Use

Core assets:

- defaults:
  - `config/validation/qdesn_static_exdqlm_crossstudy_defaults.yaml`
- grid:
  - `config/validation/qdesn_static_exdqlm_crossstudy_grid.csv`
- grid materializer:
  - `scripts/materialize_qdesn_static_exdqlm_crossstudy_grid.R`
- helper layer:
  - `R/qdesn_static_exdqlm_crossstudy.R`
- runner:
  - `scripts/run_qdesn_static_exdqlm_crossstudy_validation.R`
- healthcheck:
  - `scripts/healthcheck_qdesn_static_exdqlm_crossstudy_validation.R`

## 8) Output Contract

Per campaign, write:

- outer report root and outer results root keyed by run tag
- inner campaign report/results roots keyed by timestamp + git sha
- preflight manifest and markdown
- campaign fit summary
- campaign pairwise VB-vs-MCMC table
- campaign model-pair signoff table
- campaign root signoff summary
- grouped QDESN campaign summaries
- grouped reference summaries
- QDESN-vs-reference surface delta table
- integrated campaign summary
- launch manifest

## 9) Acceptance Criteria

Preflight / prepare-only acceptance:

- reference inventory matches the static signoff contract
- grid matches the canonical recovered grid
- `72` enabled QDESN roots
- `36` unique dataset cells
- no `tau=0.50` rows in the launch grid
- dynamic row-15 not included

Campaign completion acceptance:

- all planned roots materialized
- all root outputs have explicit root status
- comparison tables are written
- comparison summary is written
- final recommendation is emitted

Scientific completion categories:

- `COMPARISON_READY_QDESN_STATIC_CROSSSTUDY_COMPLETE`
- `COMPARISON_READY_WITH_DOCUMENTED_FAIL_BAND`
- `HOLD_QDESN_STATIC_CROSSSTUDY_WITH_GAPS`

## 10) Stop Rules

Stop immediately if:

- the canonical recovered grid disagrees with the checked-in grid
- the recovered reference inventory fails contract counts
- the external static dataset staging is inconsistent with `sim_output.rds`
- a smoke root reveals a structural mismatch in the external real-mode pipeline path

Do not launch the full campaign if any of those fail.

## 11) Risk Register

### Dataset-path mismatch risk

- mitigation:
  - derive grid rows from live signoff roots
  - validate `sim_output.rds` and fit-input directories during preflight

### Static-vs-dynamic scope confusion risk

- mitigation:
  - hard-code the initial scope as static-only
  - explicitly exclude dynamic row-15 from the launch contract

### Prior-semantics mismatch risk

- mitigation:
  - preserve current-vs-legacy provenance as metadata
  - keep QDESN actual prior axis explicit as `ridge` / `rhs_ns`

### False apples-to-apples risk

- mitigation:
  - document the one-step-holdout real-mode constraint clearly
  - keep training-fit comparison as the primary static comparison surface

### Resource overrun risk

- mitigation:
  - single-thread fits
  - conservative worker policy
  - prepare-only first

### Incomplete comparison-table risk

- mitigation:
  - comparison outputs are built into campaign closeout, not left for ad hoc follow-up

## 12) Definition Of Done

This program is done when:

- the static QDESN analog campaign has run on the recovered signoff surface,
- grouped QDESN and reference summaries exist,
- QDESN-vs-reference comparison tables exist,
- the campaign emits a final recommendation,
- and the resulting outputs are strong enough to serve as the QDESN counterpart to the exdqlm
  static validation study.

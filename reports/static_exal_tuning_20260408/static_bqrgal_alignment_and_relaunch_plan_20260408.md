# Static BQRGAL Alignment And Relaunch Plan

Date: 2026-04-08

## Purpose

This note freezes the current accepted original-`288` validation state and
defines the next relaunch as a separate, paper-aligned static benchmark rather
than another mutation of the legacy `original288` study.

The goal is to preserve the current broader validation result while making the
static comparison against the local `bqrgal-examples` benchmark genuinely
apples-to-apples.

## Freeze Decision

The following state is now frozen as the current broader validation baseline:

- accepted carry-forward baseline: `v7`
- accepted health: `282 / 288`
- unresolved rows: `6 / 288`
- unresolved tail shape:
  - all `6` unresolved rows are `dynamic`
  - all `6` unresolved rows are `exdqlm :: mcmc`

Frozen artifacts:

- `tools/merge_reports/LOCAL_original288_carryforward_selection_v7_20260407.csv`
- `tools/merge_reports/LOCAL_original288_row_health_v7_20260407.csv`
- `tools/merge_reports/LOCAL_original288_health_summary_v7_20260407.csv`
- `tools/merge_reports/LOCAL_original288_comparison_long_v1_20260408.csv`
- `tools/merge_reports/LOCAL_original288_broad_comparison_table_v1_20260408.csv`
- `tools/merge_reports/LOCAL_original288_static_model_pair_summary_v1_20260408.csv`
- `tools/merge_reports/LOCAL_original288_dynamic_model_pair_summary_v1_20260408.csv`

Interpretation:

- `original288 / v7` remains the authoritative result for the broader
  validation study
- it should no longer be treated as the paper-aligned static benchmark
- new paper alignment work should proceed in a new workstream with new outputs

## Why A New Static Benchmark Is Needed

The current accepted study and the local `bqrgal-examples` code overlap only
partially.

### What matches well

The current `static_paper` data-generating family is very close to the
`bqrgal-examples` synthetic static simulation:

| feature | local `bqrgal-examples` | current `static_paper` |
|---|---|---|
| covariate dimension | `8` slopes | `8` slopes |
| covariance decay | `rho = 0.5` | `rho = 0.5` |
| signal pattern | `[3, 1.5, 0, 0, 2, 0, 0, 0]` | same |
| normal scale | `3` | `3` |
| laplace scale | `3` | `3` |
| gausmix sigmas | `1, sqrt(5)` | same |
| families kept for paper comparison | `normal`, `laplace`, `gausmix` | same |

### What does not match

The accepted broader study is not the same experiment:

| feature | local `bqrgal-examples` | current accepted study |
|---|---|---|
| static taus | `0.05, 0.25, 0.50` | `0.05, 0.25, 0.95` |
| static sample size | `n = 100` | `TT = 100, 1000` |
| data layout | replicated train/test simulation | large master simulation with subsampled fit inputs |
| fitting | long-budget MCMC AL vs GAL | mixed VB and MCMC accepted carry-forward |
| GAL gamma kernel | `slice` | current accepted static configs are mostly `laplace_rw` |
| budget | `150000 / 50000 / 20` | current inspected static base config uses `2000 / 1000 / 1` |
| evaluation | CIE / RMSE / coverage / interval score | `PASS / WARN / FAIL` + runtime |

This means the current accepted static comparison is valid as a broader
validation study, but not as a faithful reproduction of the
`bqrgal-examples` benchmark.

## Slice-Sampling Compatibility Read

The slice kernels are close enough in form that we can deliberately align them.

### Local `bqrgal-examples`

The local benchmark uses:

- `run_gal_mcmc(..., ga_sampler = "slice", verbose = FALSE)`
- `tuning$step_size = 0.01` in the simulation scripts
- `bgal(..., ga_sampler = "slice")`
- a bounded univariate stepping-out slice sampler `uniSlice`

Relevant files:

- `/home/jaguir26/local/src/bqrgal-examples/data-examples/run_gal_mcmc.R`
- `/home/jaguir26/local/src/bqrgal-examples/bqrgal/R/bgal.R`
- `/home/jaguir26/local/src/bqrgal-examples/bqrgal/R/bqrgal-updates.R`

### Current exdqlm / exal implementation

The current static exAL implementation supports:

- `mh.proposal = "slice"` and `mh.proposal = "slice_eta"`
- bounded univariate slice updates via `.exdqlm_uni_slice_bounded()`
- separate RW-based kernels such as `laplace_rw`

Relevant files:

- `/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/R/exal_static_mcmc.R`
- `/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/R/utils.R`

### Compatibility conclusion

The two slice samplers are not the same codebase, but they are compatible in
the sense that:

- both are bounded univariate stepping-out slice samplers
- both use width-based interval expansion
- both support unlimited stepping-out via `Inf`
- both are intended for the gamma-type nonconjugate update rather than a joint
  sigma-gamma random walk

For the paper-aligned relaunch, the compatibility target should therefore be:

- `mh.proposal = "slice"`
- `slice.width = 0.01`
- `slice.max.steps = Inf`
- no `laplace_rw`
- no global eta jumps
- no refresh extras
- no row-local repair knobs in the core benchmark lane

That gives the cleanest conceptual match to the local benchmark.

## Implementation Decision

During implementation, one extra compatibility issue became important:

- the local `bqrgal-examples` benchmark fits AL and GAL with a Laplace / lasso
  coefficient prior
- the current local exdqlm static stack does not expose the same benchmark
  path as a first-class paper-aligned configuration

Because of that, the implemented paper-aligned benchmark uses the local
`bqrgal` reference engine directly for the core and extension lanes.

This is deliberate.

It means:

- the paper-aligned benchmark is genuinely aligned to the local benchmark where
  possible
- the broader `original288 / v7` validation remains a separate exdqlm
  continuation study
- the new benchmark should be described as:
  - `al` vs `exal`
  - engine:
    `bqrgal_reference`
  - metrics:
    paper metrics plus local health gates and runtime

This avoids claiming an apples-to-apples paper match for a local exdqlm static
configuration that is not actually prior-matched.

## Workstream Split

The next phase should be split into three workstreams.

### Workstream A: Frozen broader validation

Scope:

- keep `original288 / v7` unchanged
- keep the current dynamic unresolved tail inventory
- keep the current static shrinkage and dynamic comparison outputs

Purpose:

- preserve the broader validation study as a historical result
- avoid retrofitting paper-benchmark claims onto a non-paper study

### Workstream B: Paper-aligned static benchmark

Scope:

- static only
- families: `normal`, `laplace`, `gausmix`
- taus: `0.05`, `0.25`, `0.50`
- models: `al`, `exal`
- inference: MCMC only
- sample-size lanes:
  - core paper-matched lane: `n = 100`
  - extension lane: `n = 1000`

Purpose:

- reproduce the benchmark style of `bqrgal-examples`
- extend it with a clearly labeled `n = 1000` lane
- add our health-gate and runtime reporting without losing the paper metrics

### Workstream C: Broader validation continuation

Scope:

- dynamic unresolved tail
- static shrinkage family
- any future broader `0.50` study redesign if needed

Purpose:

- keep the large validation program alive
- but stop mixing its goals with the paper-aligned static benchmark

## Paper-Aligned Benchmark Design

### Core lane

This is the strict apples-to-apples target.

| item | value |
|---|---|
| lane label | `paper_matched_core` |
| families | `normal`, `laplace`, `gausmix` |
| taus | `0.05`, `0.25`, `0.50` |
| training size | `n = 100` |
| train replications | `100` |
| test replications | `100` |
| test size | `100` |
| models | `al`, `exal` |
| inference | `mcmc` only |
| AL budget | total iter `150000`, burn `50000`, thin `20` |
| exAL budget | mapped to `n.burn = 50000`, `n.mcmc = 5000`, `thin = 20` |
| exAL kernel | `slice` |
| exAL slice controls | width `0.01`, max steps `Inf` |
| extra repairs | none in core lane |

### Extension lane

This is intentionally not a direct paper match.

| item | value |
|---|---|
| lane label | `extension_n1000` |
| families | `normal`, `laplace`, `gausmix` |
| taus | `0.05`, `0.25`, `0.50` |
| training size | `n = 1000` |
| train/test replication structure | same as core lane |
| models | `al`, `exal` |
| inference | `mcmc` only |
| kernel / budget | same as core lane unless a later extension doc says otherwise |
| labeling rule | must always be reported as `extension` or `not directly paper-matched` |

## Evaluation Bundle

The new benchmark should report both the paper-style metrics and our validation
metrics.

### Paper-style metrics to reproduce

- correct inclusion and exclusion
- beta RMSE
- beta coverage
- prediction interval score

### Additional validation metrics to retain

- `PASS / WARN / FAIL`
- runtime
- chain diagnostics
- method-level inventories of `WARN` / `FAIL`

## Reproducibility Rules

The new benchmark should not be launched until the following are all in place.

1. A dedicated simulation script that generates replicated train/test datasets
   in the benchmark style rather than subsampled master-simulation slices.
2. A dedicated benchmark manifest that records:
   - family
   - tau
   - lane label
   - sample size
   - train/test replication counts
   - model
   - kernel
   - budget
   - seed policy
3. A dedicated evaluation script that emits:
   - CIE
   - RMSE
   - coverage
   - interval score
   - health gates
   - runtime
4. An execution note template and an audit checklist.

## Proposed Launch Order

### Phase 0: freeze and prepare

- freeze `original288 / v7`
- record the current workstream split
- define the new benchmark grid in machine-readable form

### Phase 1: implementation pilot

- implement the new replicated static simulator
- implement AL and exAL benchmark runners
- implement the evaluation bundle
- run a very small pilot:
  - one family
  - all three taus
  - core `n = 100` lane only
  - a small replication count just to verify end-to-end correctness

### Phase 2: full paper-matched core lane

- full `n = 100` replicated benchmark
- no local rescue knobs
- slice-only exAL
- long-budget MCMC

### Phase 3: extension lane

- launch `n = 1000`
- keep the same metric bundle
- clearly label it as an extension and not a direct paper match

## Decision Rules Before Full Launch

The full paper-aligned run should not launch unless all of the following are
confirmed:

- tau grid is `0.05 / 0.25 / 0.50`
- no `0.95` rows remain in the paper benchmark manifest
- no `laplace_rw` rows remain in the exAL paper benchmark manifest
- the simulator produces replicated train/test data rather than fit-input
  subsamples from a master `n = 7000` draw
- the long-budget mapping is explicit and audited
- the evaluation bundle reproduces the paper metrics and our health metrics

## Implementation Status

The benchmark stack has now been implemented and validated:

- replicated static simulator
- benchmark manifest builder
- AL / exAL row runner using the local `bqrgal` reference engine
- evaluation bundle for:
  - CIE
  - RMSE
  - coverage
  - interval score
  - health gates
  - runtime
- launch / supervisor / monitor scripts
- smoke validation through a real `exal` row

The execution record for the implemented stack is maintained separately in:

- `reports/static_exal_tuning_20260408/static_bqrgal_aligned_execution_20260408.md`

## Recommended Next Move

The next move is to launch the implemented benchmark stack from the audited
execution note, keeping:

- the core `n = 100` lane as the paper-matched comparison target
- the `n = 1000` lane as an explicit extension
- the broader `original288 / v7` validation frozen and tracked separately

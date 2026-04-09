# Static BQRGAL-Aligned Execution

Date: 2026-04-08

## Purpose

This note records the implemented paper-aligned static benchmark stack that
will run alongside, but separately from, the frozen broader `original288 / v7`
validation study.

The benchmark is intended to be the closest practical apples-to-apples match
to the local `bqrgal-examples` static simulation study, while also adding:

- local `PASS / WARN / FAIL` health gates
- runtime tracking
- an explicit `n = 1000` extension lane

## Engine Decision

The implemented benchmark uses the local `bqrgal` reference engine.

Why:

- the local `bqrgal-examples` benchmark fits AL and GAL with a Laplace / lasso
  coefficient prior
- the current local exdqlm static stack does not expose the same
  paper-aligned prior path as a first-class benchmark mode

Therefore this benchmark should be read as:

- models:
  `al` vs `exal`
- engine:
  `bqrgal_reference`
- scope:
  paper-aligned static benchmark, not the frozen broader `original288` study

## Implemented Benchmark Files

Tracked source files:

- `tools/merge_reports/LOCAL_static_bqrgal_aligned_helpers_20260408.R`
- `tools/merge_reports/LOCAL_static_bqrgal_aligned_prepare_20260408.R`
- `tools/merge_reports/LOCAL_static_bqrgal_aligned_run_row_20260408.R`
- `tools/merge_reports/LOCAL_static_bqrgal_aligned_evaluate_20260408.R`
- `tools/merge_reports/LOCAL_static_bqrgal_aligned_launch_20260408.sh`
- `tools/merge_reports/LOCAL_static_bqrgal_aligned_supervisor_20260408.sh`
- `tools/merge_reports/LOCAL_static_bqrgal_aligned_monitor_20260408.sh`

Tracked machine-readable benchmark artifacts:

- `tools/merge_reports/LOCAL_static_bqrgal_aligned_manifest_20260408.csv`
- `tools/merge_reports/LOCAL_static_bqrgal_aligned_schedule_20260408.csv`
- `tools/merge_reports/LOCAL_static_bqrgal_aligned_stage_counts_20260408.csv`
- `tools/merge_reports/LOCAL_static_bqrgal_aligned_audit_20260408.csv`

Implementation note:

- these files live under repo paths that are broadly ignored for scratch/output
  work
- they are intentionally force-tracked here because they are benchmark
  source-of-truth artifacts rather than disposable local outputs

## Benchmark Shape

Phase split:

- `phase1_paper_matched_core`:
  `1800` rows
- `phase2_extension_n1000`:
  `1800` rows

Total manifest:

- `3600` rows

Core paper-matched lane:

- families:
  `normal`, `laplace`, `gausmix`
- taus:
  `0.05`, `0.25`, `0.50`
- training size:
  `n = 100`
- train replications:
  `100`
- test replications:
  `100`
- test size:
  `100`
- models:
  `al`, `exal`
- inference:
  MCMC only

Extension lane:

- same families and taus
- same replication structure
- `n = 1000`
- always interpreted as an extension rather than a direct paper match

## Paper-Matched Controls

Implemented paper-match controls:

- AL budget:
  `n_iter = 150000`, `n_burn = 50000`, `n_thin = 20`
- exAL budget:
  same long-budget MCMC settings
- beta prior keyword:
  `laplace`
- exAL gamma sampler:
  `slice`
- exAL slice width:
  `0.01`
- step-out cap:
  package default `m = Inf` inside the local `bqrgal` slice implementation

The runner now explicitly sources:

- `/home/jaguir26/local/src/bqrgal-examples/data-examples/run_gal_mcmc.R`

and the bootstrap now explicitly checks that both:

- the local `bqrgal` package source
- the local `run_gal_mcmc.R` wrapper

exist before launching.

## Validation Completed

Prelaunch validation completed successfully:

- package dependencies installed into the benchmark-local library
- local `bqrgal` package installed with:
  `R CMD INSTALL --preclean`
- manifest prepare completed
- evaluator produced a clean `0 / 3600` prelaunch summary
- `bash -n` passed for launch, supervisor, and monitor scripts
- launcher `--prepare-only=1 --skip-prepare=1` passed
- launcher `--dry-run=1 --skip-prepare=1` passed for the core lane
- a real smoke row completed through the committed runner path

Machine-readable audit at validation time:

- manifest rows:
  `3600`
- core rows:
  `1800`
- extension rows:
  `1800`
- missing inputs:
  `0`

Smoke validation read:

- lane:
  `paper_matched_core`
- family:
  `normal`
- tau:
  `0.05`
- model:
  `exal`
- status:
  `done`
- artifacts written:
  row status, health CSV, metrics CSV, compact fit object

## Planned Launch Sessions

The benchmark launch is intended to run in tmux under:

- supervisor:
  `static-bqrgal-aligned-20260408`
- monitor:
  `static-bqrgal-aligned-monitor-20260408`

Launch mode:

- full sequential launch
- `phase1_paper_matched_core` first
- `phase2_extension_n1000` second
- default parallelism from launcher policy unless explicitly overridden

## Interpretation Guardrails

This benchmark is meant to answer static paper-aligned questions.

It should not be used to overwrite or reinterpret:

- the frozen broader `original288 / v7` dynamic tail
- the broader static shrinkage validation story
- the original `0.05 / 0.25 / 0.95` broader validation grid

Those remain separate workstreams.

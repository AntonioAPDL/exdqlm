# Benchmark Data Pipeline

This repo now includes a script-driven benchmark ingestion workflow for:

- Monash Forecasting Archive
- Official M4 dataset

The workflow keeps Monash and official M4 as separate source families and
explicitly excludes Monash M4 duplicates from the Monash main pool.

## Repo Layout

- `config/benchmarks/`
  Benchmark defaults and dataset registry.
- `data-raw/benchmarks/`
  Immutable raw downloads and extracted Monash archive members.
- `data-processed/benchmarks/`
  Canonical metadata, panel partitions, split definitions, and quality logs.
- `figures/benchmarks/generated/`
  Dataset-level summary plots and selected time-series panels.
- `reports/benchmarks/generated/`
  Compact markdown report and figure index.
- `logs/benchmarks/`
  Download manifests and processing provenance.

## End-to-End Commands

Run the steps from the repo root:

```bash
Rscript --vanilla scripts/benchmark_download.R
Rscript --vanilla scripts/benchmark_build.R
Rscript --vanilla scripts/benchmark_analyze.R
```

Or run the full pipeline:

```bash
Rscript --vanilla scripts/benchmark_pipeline.R
```

Optional override config:

```bash
Rscript --vanilla scripts/benchmark_pipeline.R --config path/to/override.yaml
```

## Output Schema

Processed outputs are organized around three canonical artifacts:

- `series_metadata`
  One row per series with provenance, frequency, horizon, and quality fields.
- `panel/<dataset>.rds`
  One row per observation with `dataset`, `source_family`, `series_id`,
  `split`, `t_index`, `timestamp`, and `y`.
- `split_definitions`
  One row per series with train/validation/test boundaries and split protocol.

## Reproducibility Notes

- Raw downloads are not overwritten unless `--overwrite` is passed.
- Download manifests include source URL, local path, checksums, and timestamps.
- The registry keeps Monash and M4 in separate benchmark pools.
- Official M4 test sets are preserved exactly.
- Monash validation/test splits are explicit metadata, not hidden assumptions.

## Q-DESN Benchmark Evaluation

The repo now also includes a benchmark-side evaluation layer for the current
Q-DESN synthesized forecast workflow.

Pilot run:

```bash
Rscript --vanilla scripts/benchmark_qdesn_run.R --config config/benchmarks/qdesn_synth_pilot.yaml
```

Larger run:

```bash
Rscript --vanilla scripts/benchmark_qdesn_run.R --config config/benchmarks/qdesn_synth.yaml
```

Regenerate the markdown report for an existing run directory:

```bash
Rscript --vanilla scripts/benchmark_qdesn_report.R --run_dir results/benchmarks/qdesn_synth/<run_name>
```

Audit RHS collapse patterns for a completed debug run:

```bash
Rscript --vanilla scripts/benchmark_qdesn_collapse_audit.R --run_dir results/benchmarks/qdesn_synth/<run_name>
```

These scripts evaluate the synthesized forecast produced by multiple Q-DESN
quantile fits, compare it against baseline models, and write machine-readable
tables plus a compact markdown summary under `results/benchmarks/qdesn_synth/`.

Benchmark Q-DESN runs are pinned to the `exal_static_LDVB()` readout path.
The benchmark config normalizer now enforces `readout_approximation:
laplace_delta`; Gaussian moment-matching configurations are rejected.

The current benchmark runner now includes:

- dataset-level candidate selection on stored validation splits using a flexible
  config-driven candidate grid;
- quantile-level candidate diagnostics, so each benchmarked Q-DESN candidate is
  now tracked by component-quantile pinball, empirical coverage error, and PIT
  deviation in addition to synthesized validation CRPS;
- route-aware candidate families so short-, medium-, and long-history series can
  use separate Q-DESN search spaces under one benchmark protocol;
- a candidate registry saved to each run manifest;
- multi-seed Q-DESN synthesis, where each candidate can pool predictive draws
  over a fixed `seed_set` rather than relying on one reservoir realization;
- explicit RHS-aware Q-DESN benchmarking, with `beta_prior_type = "rhs"` set in
  the benchmark configs, tau-aware candidate blocks in YAML, and saved RHS
  diagnostic tables that flag near-bound and collapse-like shrinkage behavior;
- optional internal recalibration on the fitting segment tail, applied before
  final test scoring and recorded in saved audit artifacts;
- explicit M4 comparability tables with `Naive2`, `OWA`, and `MSIS(95%)`
  relative summaries;
- stronger classical baselines, including `theta`, `ses`, `holt`, `damped`,
  `comb`, `ets`, and `auto_arima` when configured;
- audit diagnostics for saved synthesized-Q-DESN forecast artifacts, including
  PIT summaries, 95% coverage summaries, and fan-chart figures.

## Current Research Status

- The benchmark workflow and scripts are operational. The current freeze on
  broader reruns is a research gate, not a benchmark-plumbing failure.
- Broad routed synthesis reruns are intentionally paused while the pinned
  tourism shoulder issue is isolated with targeted debug configs and audits.
- Repo-wide model defaults live in `config/defaults.yaml`. Some benchmark YAMLs
  intentionally override those defaults with pinned research/debug RHS settings;
  those overrides should be read as experiment-specific profiles, not package
  defaults.
- The scored benchmark object is the synthesized forecast, but candidate
  selection intentionally also applies component-quantile health guards. The
  goal is to promote healthy synthesis, not merely the lowest synthesized score
  from an unhealthy component ladder.
- The `testthat` suite mainly validates ingestion, plumbing, numerical
  invariants, and toy smoke runs. Scientific health on hard routed benchmark
  slices is established through the saved benchmark audits and trackers, not
  through unit tests alone.

The main full config, `config/benchmarks/qdesn_synth.yaml`, uses a block-based
candidate grid so D=1 and D=2 families can be edited independently without
rewriting the benchmark runner. It is designed as a deterministic research
protocol, not a randomly sampled search. Vector-valued fields such as `n`,
`alpha`, or `seed_set` should be expressed as nested YAML lists inside the grid
blocks. In YAML files, quote the `n` key as `"n"` to avoid YAML 1.1 boolean
parsing.

The pilot config, `config/benchmarks/qdesn_synth_pilot.yaml`, is the fast
validation run. It exercises the full route-aware / seed-robust / RHS-aware /
recalibrated benchmark path on a small deterministic subset before a larger
benchmark is launched.

The lighter development config, `config/benchmarks/qdesn_synth_dev.yaml`, is
the preferred benchmark-dev profile when candidate blocks or RHS settings are
being changed frequently. It keeps the quantile diagnostics and RHS guardrails
active, aligns the RHS/VB defaults with `config/defaults.yaml`, and uses
deterministic budgets over a broader raw DESN candidate space. In practice this
is still a substantial run once the broadened search is active, so it should be
treated as a benchmark-development profile rather than a near-instant smoke
test.

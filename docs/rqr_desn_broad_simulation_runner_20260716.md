# RQR-DESN Broad Simulation Runner

Date: 2026-07-16

Status: package-side runner implementation. This does not authorize article
updates.

## Purpose

The broad runner consumes the seed-repaired frozen manifest:

```text
config/rqr_desn/rqr_desn_broad_simulation_frozen_20260716_v2.R
```

It materializes the no-fit denominator if needed, executes selected scenario
rows, writes one terminal status file per scenario, and aggregates interval
metrics, fit summaries, MCMC diagnostics, VB diagnostics, and explicit failures.

## Main Scripts

```text
scripts/run_rqr_desn_broad_simulation.R
scripts/healthcheck_rqr_desn_broad_simulation.R
```

The runner is resumable: completed rows and, by default, failed terminal rows are
not rerun unless `--force true` or `--rerun-failures true` is supplied.

## Interpretation Contract

The run remains an RQR interval-readout study:

- the estimand is a central prediction interval;
- `coverage_level` is not a quantile level;
- no response likelihood is claimed;
- no response predictive samples are generated;
- dynamic DESN cases use an explicit teacher-forced design matrix;
- VB remains a sidecar unless separately calibrated.

The manifest `seed` is used as the algorithm seed for the scenario row. To keep
comparisons fair across coverage, learning-rate, and prior variants, the runner
derives shared deterministic DGP/design seeds from stage, family, replicate, and
design identifiers.

## Overnight Launch Pattern

After parse/tests/smoke gates pass, launch from the repository root:

```bash
R_BIN=/data/jaguir26/local/opt/R/4.6.0/bin/R
RSCRIPT=/data/jaguir26/local/opt/R/4.6.0/bin/Rscript

"$RSCRIPT" scripts/run_rqr_desn_broad_simulation.R \
  --install-package true \
  --workers 4
```

Use `tmux` for the actual overnight run and monitor with:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  scripts/healthcheck_rqr_desn_broad_simulation.R \
  --output-dir <run-dir>
```

## Promotion Guard

The runner writes `closeout.md`, but that closeout is still package-side
simulation evidence. The article should only be touched after a separate
reader-facing decision compares the completed results against the article's
methodological needs and confirms that the claims remain scoped to interval
readouts.

# QDESN Tau050 Dataset Audit Plots Plan

## Goal

Build a flat, temp-root dataset audit pack for the **generated tau050 source datasets**
so the raw observed series can be visually inspected before drawing more conclusions
from the downstream fit comparisons.

The pack should make it easy to review every dataset one by one by:

- writing all outputs into a single flat temp folder
- avoiding nested subfolders for the PNGs
- giving each dataset one combined PNG with:
  - the full observed series
  - a highlighted zoom on the last 100 observations
- sorting files lexically with numeric prefixes

## Source Of Truth

Use the canonical tau050 refreshed-main source run as the dataset source:

- `results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation/qdesn-dynamic-exdqlm-crossstudy-tau050-full-20260416-212700__git-15fe674/20260416-212707__git-15fe674`

Use the recovered main comparison report only as a reference layer for optional labels:

- root readiness label
- fail-fit counts

No new fitting compute is needed for this audit pack. It is a read-only visualization
layer over the already generated source datasets.

## Deliverable Shape

The output should be a single temp folder under `/tmp` containing:

- `000__run_metadata.json`
- `000__preflight.md`
- `000__dataset_index.csv`
- `000__dataset_audit_manifest.json`
- `000__dataset_audit_summary.md`
- `000__completion_metadata.json`
- `001__...png` through `036__...png`

No dataset PNG should be placed in subfolders.

## Plot Design

Each dataset PNG should contain two panels:

1. full observed series
   - light grid
   - strong readable line
   - last-100 region shaded
   - last-100 start marker

2. last-100 zoom
   - points plus line
   - lowess smooth
   - explicit local scale

Each plot should be titled with:

- dataset order
- family
- tau
- fit size
- prior
- total length

And subtitled with:

- dataset cell id
- root id
- recovered readiness label
- fail-fit count

## Implementation

Add a manifest-driven dataset-audit module with:

- package module in `R/`
- generic runner in `scripts/`
- tau050 wrapper in `scripts/`
- tau050 manifest in `config/validation/`
- focused config/render test in `tests/testthat/`

The runner should support:

- `--prepare-only`
- `--output-root`
- `--max-workers`

## Efficiency

The work is embarrassingly parallel across datasets, so rendering should use a modest
parallel worker cap while keeping each process single-threaded.

Default target:

- `36` datasets
- `6` rendering workers
- no nested output tree

## Decision Use

This pack is meant to answer a simple question cleanly:

> do the generated source datasets themselves look healthy, interpretable, and worth
> trusting as the basis for the tau050 study comparisons?

It is an audit surface, not a replacement for the study-facing comparison pack.


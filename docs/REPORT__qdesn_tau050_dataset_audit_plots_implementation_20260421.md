# QDESN Tau050 Dataset Audit Plots Implementation

## Scope

Implemented a reproducible, flat-output audit pack for the generated tau050 source
datasets so every dataset can be inspected visually without navigating a deep report
tree.

The implementation is intentionally lightweight:

- read-only over the existing generated datasets
- no refitting
- one combined PNG per dataset
- a single temp-root output folder with no dataset subfolders

## What Was Added

### Package module

- `R/qdesn_dynamic_exdqlm_crossstudy_dataset_audit_plots.R`

Main responsibilities:

- load and validate the dataset-audit manifest
- resolve the canonical source run and recovered comparison roots
- discover all source roots and build a 36-dataset inventory
- read `observed.csv` and `source_metadata.json` for each dataset
- join optional recovered-comparison labels:
  - `readiness_label`
  - `fail_fit_n`
- render one flat PNG per dataset with:
  - full-series panel
  - last-100 zoom panel
- write flat output metadata and summary files into the same folder

### Runners

- `scripts/run_qdesn_dynamic_exdqlm_crossstudy_dataset_audit_plots.R`
- `scripts/run_qdesn_dynamic_exdqlm_crossstudy_tau050_dataset_audit_plots.R`

These follow the repo’s manifest-driven pattern while adapting the output layout to
the user-review need:

- default output parent is `/tmp`
- `--prepare-only` support
- `--output-root` override
- `--max-workers` override
- no nested plot folders

### Manifest

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_dataset_audit_manifest.yaml`

Pinned choices:

- source run:
  - tau050 refreshed-main source surface
- comparison reference:
  - canonical recovered main comparison root
- plotting window:
  - `n_last = 100`
- output parent:
  - `/tmp`
- execution:
  - `max_workers = 6`

### Test

- `tests/testthat/test-qdesn-dynamic-tau050-dataset-audit-config.R`

The focused test checks that:

- the manifest resolves correctly
- the full inventory contains `36` datasets
- flat PNG filenames are unique and path-safe
- a single PNG can be rendered successfully into a temp folder

## Why This Design

The user needs to browse the datasets themselves quickly and visually. The most
review-friendly shape is not a nested report tree, but a single folder where the PNGs
can be opened sequentially in lexical order.

That is why the implementation deliberately writes:

- a flat set of numbered PNGs
- a small set of `000__...` metadata files that sort first

instead of the deeper `tables/`, `summary/`, `plots/`, `manifest/` layout used by the
other analysis packs.

## Validation Before Full Render

The intended validation sequence is:

```bash
Rscript -e 'testthat::test_local(filter = "qdesn-dynamic-tau050-dataset-audit-config", reporter = "summary")'
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_tau050_dataset_audit_plots.R --prepare-only
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_tau050_dataset_audit_plots.R
```

## Expected Deliverable

The canonical output is a temp-root folder under `/tmp` containing:

- numbered flat PNGs for all 36 datasets
- a flat CSV index
- manifest/summary metadata
- no dataset subfolders


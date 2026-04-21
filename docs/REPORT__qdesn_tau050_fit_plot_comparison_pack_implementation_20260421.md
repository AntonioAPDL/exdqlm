# QDESN Tau050 Fit Plot Comparison Pack Implementation

## Scope

Implemented a manifest-driven visual comparison pack for the recovered tau050 study
to compare fitted behavior over the **last 100 training observations** on a small,
curated subset of roots rather than the full 144-fit surface.

The implementation keeps the recovered comparison tables as the metric source of
truth and regenerates only the plot artifacts needed for the visual comparison.

## What Was Added

### Package module

- `R/qdesn_dynamic_exdqlm_crossstudy_fit_plot_pack.R`

Main responsibilities:

- load and validate the fit-plot pack manifest
- resolve the canonical source run and recovered comparison roots
- build the selected case table and source fit scorecard
- rebuild fit jobs from saved `fit_request.json`
- apply plot-only overrides:
  - `diagnostics.plots = TRUE`
  - `forecast.train_last_window = 100`
  - `forecast.fore_last_window = 100`
  - `threads_per_proc = 1`
- run the selected fits in parallel with a modest worker cap
- collect `train_mu_band.png` outputs
- assemble the markdown comparison pack and supporting CSVs

### Runners

- `scripts/run_qdesn_dynamic_exdqlm_crossstudy_fit_plot_pack.R`
- `scripts/run_qdesn_dynamic_exdqlm_crossstudy_tau050_fit_plot_pack.R`

These follow the same pattern as the other tau050 report/analysis runners:

- manifest-driven
- `--prepare-only` support
- clean launch metadata
- canonical output root under `reports/`

### Manifest

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_fit_plot_pack_manifest.yaml`

Pinned choices:

- source run:
  - recovered tau050 refreshed-main source surface
- comparison source of truth:
  - recovered main comparison analysis root
- selected cases:
  - `clean_ridge_short`
  - `stress_rhs_short`
- plotting window:
  - `train_last_window = 100`
- execution:
  - `max_workers = 4`
  - `threads_per_proc = 1`

### Test

- `tests/testthat/test-qdesn-dynamic-tau050-fit-plot-pack-config.R`

The focused test checks that:

- the manifest resolves correctly
- both selected cases exist in the authoritative recovered comparison tables
- each case expands to the full 4-fit comparison surface

## Why This Design

The recovered tau050 pack does **not** retain enough lightweight per-timepoint fit
objects to rebuild the last-window train overlays directly from tables alone.
The clean solution is to rerun a very small subset from the original saved
`fit_request.json` files while keeping:

- the metric narrative anchored to the recovered comparison tables
- the compute surface small and auditable
- the output structure consistent with the rest of the repo

## Validation Before Launch

The implementation passed:

```bash
Rscript -e 'testthat::test_local(filter = "qdesn-dynamic-tau050-fit-plot-pack-config", reporter = "summary")'
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_tau050_fit_plot_pack.R --prepare-only
```

## Canonical Launch State

Implementation was committed before launch so the canonical run is pinned to a clean
SHA:

- implementation commit: `686b741`

The canonical fit-plot pack was then launched from that clean implementation state.

## Post-Launch Hardening

During report assembly, the first run exposed two lightweight framework issues:

- the fit-plot pack logger called `.qdesn_validation_write_lines()` with reversed
  arguments
- the final summary/manifest writer also called the shared write helpers with
  reversed arguments

The fit reruns themselves completed and produced the expected plot artifacts, but
the markdown closeout did not. The module was then hardened to:

- fix the shared write-helper call order
- add safer per-job error rows during parallel collection
- add an `--assemble-only` runner path so an existing rerun root can be finalized
  without paying the fit compute again

That hardening lets the fit-plot pack behave like the rest of the repo’s
reproducible report layers: compute once, then reassemble cleanly if needed.

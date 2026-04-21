# QDESN Tau050 Fit Plot Comparison Pack Plan

## Goal

Build a small, study-facing visual comparison pack for the recovered tau050 study that
compares the fitted-trace behavior over the **last 100 training observations** for a
small subset of roots rather than the full 144-fit surface.

The pack should make it easy to compare:

- `VB` vs `MCMC`
- `AL` vs `EXAL`
- `ridge` vs `rhs_ns` through curated case selection

while staying reproducible and disciplined about compute.

## Why A Small Curated Pack

The lightweight recovered artifacts do not retain the full per-timepoint fitted-trace
objects needed to rebuild the original train-window fit plots directly. The clean way
to recover those visuals is to rerun a **small subset** of fits from the saved
`fit_request.json` files with plotting enabled and the train window widened to `100`.

That keeps the work:

- faithful to the original fit requests
- reproducible from repo state
- small enough to audit
- much cheaper than a broad relaunch

## Selected Cases

The comparison pack should use two roots:

1. `clean_ridge_short`
   - root: `root__dynamic__dlm_constV_smallW__gausmix__tau_0p25__lasttt_500__qdesn_ridge`
   - purpose: clean `ridge` benchmark with all four fit variants available

2. `stress_rhs_short`
   - root: `root__dynamic__dlm_constV_smallW__laplace__tau_0p25__lasttt_500__qdesn_rhs_ns`
   - purpose: harder `rhs_ns` benchmark where the `VB` vs `MCMC` contrast is sharper

These two roots give:

- a cleaner `ridge` surface
- a stressed `rhs_ns` surface
- all four panels per root:
  - `VB / AL`
  - `VB / EXAL`
  - `MCMC / AL`
  - `MCMC / EXAL`

## Implementation

Add a manifest-driven pack with:

- package module in `R/`
- generic runner in `scripts/`
- tau050 wrapper in `scripts/`
- tau050 manifest in `config/validation/`
- focused config test in `tests/testthat/`

The runner should:

1. load the canonical recovered comparison tables as the source of truth for metrics
2. load the saved `fit_request.json` for each selected fit
3. rerun each fit with:
   - `diagnostics.plots = TRUE`
   - `forecast.train_last_window = 100`
   - `forecast.fore_last_window = 100`
   - `threads_per_proc = 1`
4. execute the fit grid in parallel with a modest worker cap
5. collect `figs/train_mu_band.png`
6. assemble a report with:
   - selected case table
   - source fit scorecard
   - rerun status
   - image grid for each root

## Deliverables

- canonical report root under:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_fit_plot_pack/`
- markdown summary:
  - `summary/qdesn_tau050_fit_plot_comparison_pack.md`
- tables:
  - selected case table
  - source fit scorecard
  - rerun status
  - figure index
  - case contrast summary

## Decision Use

This pack is intended to support narrative comparison work after recovery, not to
replace the canonical recovered comparison tables. The recovered comparison outputs
remain the metric source of truth; this pack adds a visual layer for a small subset
of representative time-series cases.

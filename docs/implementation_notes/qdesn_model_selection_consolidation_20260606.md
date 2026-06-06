# Q-DESN Model Selection Consolidation

Date: 2026-06-06

## Objective

Make `qdesn_model_selection()` the single authoritative public entry point for
package-level Q-DESN model selection while preserving legacy compatibility.

## Current Public Contract

`qdesn_model_selection()` is now a facade:

- modern staged configs with `model_selection$stages` dispatch to the v2 engine;
- legacy configs with `model_selection$esn_space` dispatch to the historical
  ESN-pipeline selector;
- explicit `engine = "v2"` or `engine = "legacy"` overrides auto-detection.

The v2 engine is the preferred path for new work.

## Why V2 Is Authoritative

The v2 engine is more congruent with current Q-DESN development because it
supports:

- staged candidate grids;
- explicit candidate lists through
  `model_selection$stages[[i]]$candidate_grid$candidates`;
- current DESN normalization (`D`, `n`, `n_tilde`, `m`, `alpha`, `rho`, seed);
- origin-mode scoring;
- current VB readout controls;
- ridge, RHS, and RHS_NS beta-prior construction;
- synthesis and optional calibration diagnostics;
- reproducible progress tracking files.

The legacy path remains available only to avoid breaking older configs that
still use `model_selection$esn_space`.

## CLI Status

`scripts/qdesn_model_selection_main.R` now uses the same authoritative facade.

Important updates:

- `--engine auto|v2|legacy` controls dispatch.
- The default dataset registry is
  `config/model_selection/datasets.yaml`.
- The model-selection registry can forward through `datasets_source`, so it can
  reuse the shared `config/datasets.yaml` without duplicating dataset paths.
- For v2 configs, the runner merges:
  1. `config/defaults.yaml`;
  2. `config/model_selection/defaults.yaml` `base_cfg_overrides`;
  3. the selected spec YAML `base_cfg_overrides`;
  4. the selected spec YAML direct fields.

## PriceFM Boundary

The article-side PriceFM selector is not the package model-selection engine. It
is currently an artifact registry adapter: it selects among already completed
PriceFM median grid cells using fold-specific validation metrics and then
materializes promoted quantile grids.

The package `qdesn_model_selection()` should become the fit-selection source of
truth for future PriceFM searches only after the PriceFM fold/horizon contract
is represented in a package-compatible config:

- region/fold scope;
- validation/test split semantics;
- horizon-aware scoring;
- current PriceFM covariates/window materialization;
- requested Q-DESN methods and prior family;
- validation-only selection with test metrics as audit fields.

Until then, keep the article selector as a PriceFM-specific bridge, not a second
generic Q-DESN selector.

## Validation

Focused package tests:

```sh
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript -e \
  'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-qdesn-model-selection-authoritative.R")'
```

The script parses successfully with:

```sh
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript -e \
  'parse(file="scripts/qdesn_model_selection_main.R"); cat("parse ok\n")'
```

The local R library used for this pass does not have `optparse` installed, so a
runtime `--help` invocation of the CLI could not be completed in this
environment. The script-level dependency is now declared in `Suggests`.

Runtime packages used by the model-selection API are declared in `Imports`
where required for ordinary package loading, including `digest`, `dplyr`,
`jsonlite`, `purrr`, `readr`, `tibble`, and `yaml`. Legacy parallel/CLI-only
dependencies that are not installed in the local validation library remain
declared in `Suggests`, including `future`, `future.apply`, and `optparse`.

## Future PriceFM Migration Checklist

- Build a package-compatible PriceFM v2 config generator.
- Add a dry-run mode that materializes candidate grids without fitting.
- Add horizon-aware scoring to package model selection if needed for
  apples-to-apples PriceFM folds.
- Keep validation-only selection and test-as-audit semantics.
- Preserve the article registry/promotion outputs so existing PriceFM reports
  remain reproducible.

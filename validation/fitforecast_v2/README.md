# exDQLM/DQLM Dynamic Fit + Forecast v2 Validation

Date: 2026-05-15

This directory contains the exDQLM/DQLM side of the shared Q-DESN/exDQLM
dynamic fit + forecast validation study. It is tracked research
infrastructure, not package API. The package build excludes this directory via
`.Rbuildignore`.

The study consumes a frozen shared dynamic source registry and produces
storage-light fit and forecast summaries. It does not generate source data and
it does not retain full successful model objects.

## Contract

- Package branch: `validation/shared-fitforecast-v2-1.0.0`
- Package version: `1.0.0`
- Required R runtime: R 4.6.0 or newer
- Shared source root:
  `/data/jaguir26/local/src/shared_dynamic_fit_forecast_validation/sources`
- Scenario:
  `dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast`
- Train origin: source index `9000`
- Forecast block: source indices `9001:10000`
- TT500 train window: source indices `8501:9000`
- TT5000 train window: source indices `4001:9000`
- Primary forecast protocol: rolling origin, no refit, state/lag update through
  each origin.
- Primary lead grid: `Hmax=30`, `origin_stride=30`.
- Primary article-facing interface: one row per atomic run and forecast lead,
  with repeated fit metrics plus lead-level forecast metrics.
- Legacy aggregate forecast windows retained for compatibility:
  `9001:9100` and `9001:10000`.

## Main Commands

Runtime preflight:

```sh
Rscript -e 'cat(R.version.string, "\n"); stopifnot(getRversion() >= "4.6.0")'
```

Dry-run preparation without writing run artifacts:

```sh
Rscript validation/fitforecast_v2/scripts/prepare_exdqlm_dynamic_fitforecast_v2_validation.R --dry-run
```

Prepare manifests after the shared source registry exists:

```sh
Rscript validation/fitforecast_v2/scripts/prepare_exdqlm_dynamic_fitforecast_v2_validation.R
```

Verify source windows:

```sh
Rscript validation/fitforecast_v2/scripts/verify_exdqlm_dynamic_fitforecast_v2_source_windows.R
```

Dry-run the smoke launch:

```sh
Rscript scripts/run_shared_fitforecast_v2_dryrun_preflight.R
Rscript validation/fitforecast_v2/scripts/launch_exdqlm_dynamic_fitforecast_v2_validation.R --phase smoke --dry-run
Rscript validation/fitforecast_v2/scripts/launch_exdqlm_dynamic_fitforecast_v2_validation.R --phase pilot --dry-run
```

Run the validation-harness tests:

```sh
Rscript -e 'testthat::test_dir("validation/fitforecast_v2/tests/testthat")'
```

## Launch Policy

No compute phase runs unless:

```sh
EXDQLM_FFV2_LAUNCH_APPROVED=true
```

The full study is staged:

1. `smoke`
2. `pilot`
3. `vb_full`
4. `mcmc_tt500`
5. `mcmc_tt5000`

The final TT5000 MCMC stage is intentionally gated because previous TT5000
MCMC rows were the dominant runtime risk.

## Implementation Map

- `config/shared_source_contract.yaml`: cross-study source-window contract.
- `config/exdqlm_dynamic_fitforecast_v2_defaults.yaml`: exDQLM/DQLM grid,
  budgets, staged worker policy, smoke rows, and retention policy.
- `R/source_registry.R`: source discovery, source hashing, window verification,
  and 72-row manifest construction.
- `R/row_runner.R`: one-row fit plus rolling-origin forecast execution, compact
  artifact writing, and runtime failure capture.
- `R/metrics.R`: fit, rolling-lead, and compatibility window scalar metrics.
- `R/storage_audit.R`: storage-light retention gate for forbidden binary
  payloads under run roots.
- `R/shared_interface.R`: article/Q-DESN merge-facing metric export.
- `scripts/*.R`: prepare, verify, staged launch, per-row runner,
  healthcheck, and shared-interface export.
- `tests/testthat`: non-compute contract tests for source windows, manifest
  shape, stage filters, H=1000 forecast API, artifact schemas, storage policy,
  and shared-interface schema.

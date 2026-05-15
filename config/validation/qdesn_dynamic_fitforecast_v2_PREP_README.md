# Q-DESN Dynamic Fit + Forecast v2 Prep

Date: 2026-05-15

This branch prepares the Q-DESN validation layer on top of the exdqlm 0.5.0 fit+forecast baseline. It is intended for the next shared dynamic validation study, not for consuming old fit-only outputs.

## Branch Contract

- Worktree: `/data/jaguir26/local/src/exdqlm__wt__qdesn_fitforecast_0p5p0`
- Branch: `feature/qdesn-fitforecast-validation-0p5p0`
- Base: `origin/validation/fit-forecast-shared-dynamic-0.5.0`
- Source study id: `dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast`

The branch keeps the 0.5.0 exDQLM forecast validation baseline and layers the Q-DESN validation code, RHS/RHS-NS readout controls, storage-light launchers, and source-window verification on top.

## Data Contract

The v2 study uses a fresh dynamic source bundle rather than appending to the old 7000-row fit-only source.

- `TT_total = 12000`
- `TT_warmup = 2000`
- `TT_main = 10000`
- train origin: source index `9000`
- forecast block: source indices `9001:10000`
- TT500 effective training window: source indices `8501:9000`
- TT5000 effective training window: source indices `4001:9000`
- Q-DESN lag/washout context: `lag_max = 12`, `washout = 300`
- Q-DESN materialized raw TT500 window: `8189:10000` (`1812` rows)
- Q-DESN materialized raw TT5000 window: `3689:10000` (`6312` rows)

The materializer records `source_index`, `split_role`, `effective_train`, and `forecast_eval` in every `selection_indices.csv`. The verification API checks that train and forecast rows are contiguous and aligned to the predeclared source indices.

## Main Files

- `config/validation/qdesn_dynamic_fitforecast_v2_candidate_dataset_manifest.yaml`
- `config/validation/qdesn_dynamic_fitforecast_v2_materialization_defaults.yaml`
- `config/validation/qdesn_dynamic_fitforecast_v2_storage_light_defaults.yaml`
- `scripts/run_qdesn_dynamic_fitforecast_v2_source_refresh.R`
- `scripts/verify_qdesn_dynamic_fitforecast_v2_source_windows.R`
- `scripts/launch_qdesn_dynamic_fitforecast_v2_validation.R`
- `scripts/healthcheck_qdesn_dynamic_fitforecast_v2_validation.R`
- `tests/testthat/test-qdesn-dynamic-fitforecast-source-windows.R`
- `tests/testthat/test-exdqlm-forecast-horizon-inputs.R`

## Storage Contract

The launch defaults remain storage-light:

- Retain scalar metrics, compact fit summaries, status CSVs, manifests, and compact quantile/path summaries.
- Do not retain full successful `forecast_objects.rds` payloads as the analysis artifact of record.
- Keep any large full objects only for explicit debugging, and prune them after diagnostics are materialized.

## Safe First Commands

Dry-run only; does not generate sources:

```sh
Rscript scripts/run_qdesn_dynamic_fitforecast_v2_source_refresh.R
```

Generate and materialize the frozen v2 source registry after both validation chats agree:

```sh
Rscript scripts/run_qdesn_dynamic_fitforecast_v2_source_refresh.R --execute
```

Verify source windows after materialization:

```sh
Rscript scripts/verify_qdesn_dynamic_fitforecast_v2_source_windows.R
```

Launch a wiring smoke only after the source registry is frozen:

```sh
Rscript scripts/launch_qdesn_dynamic_fitforecast_v2_validation.R --phase smoke
```

Run a read-only health check:

```sh
Rscript scripts/healthcheck_qdesn_dynamic_fitforecast_v2_validation.R
```

## Verification Run During Prep

The prep pass used these checks:

```sh
Rscript -e 'pkgload::load_all(".", quiet=FALSE)'
Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-exdqlm-forecast-horizon-inputs.R"); testthat::test_file("tests/testthat/test-qdesn-dynamic-fitforecast-source-windows.R")'
Rscript scripts/run_qdesn_dynamic_fitforecast_v2_source_refresh.R
Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-static-class-generics.R")'
Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-qdesn-fit-mcmc-precision-beta-api.R"); testthat::test_file("tests/testthat/test-qdesn-prior-defaults.R")'
Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-exal-inference-config.R")'
```

All listed checks completed with zero failures.

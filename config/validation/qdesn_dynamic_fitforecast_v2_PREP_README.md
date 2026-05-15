# Q-DESN Dynamic Fit + Forecast v2 Prep

Date: 2026-05-15

This branch prepares the Q-DESN validation layer on top of the exdqlm 1.0.0 fit+forecast baseline. It is intended for the next shared dynamic validation study, not for consuming old fit-only outputs.

## Branch Contract

- Worktree: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`
- Branch: `validation/shared-fitforecast-v2-1.0.0`
- Base: `d8aa14f105730d16f6e77b5f19dbdcac145c9581`
- Source study id: `dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast`

The branch keeps the exDQLM 1.0.0 package baseline and layers the Q-DESN validation code, RHS/RHS-NS readout controls, storage-light launchers, and source-window verification on top.

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
Rscript scripts/launch_qdesn_dynamic_fitforecast_v2_validation.R --phase smoke --dry-run
Rscript scripts/launch_qdesn_dynamic_fitforecast_v2_validation.R --phase smoke --prepare-only
QDESN_FFV2_LAUNCH_APPROVED=true \
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

## Launch Readiness Gate Added 2026-05-15

The branch is past implementation prep, source generation, source-window verification, and prepare-only preflight. It is not yet approved for the detached smoke or the full fit+forecast launch.

Evidence from the readiness and source audit:

- Active runtime is `/data/jaguir26/local/opt/R/4.6.0/bin/Rscript`.
- `R.version.string` is `R version 4.6.0 (2026-04-24)`.
- The source-refresh dry-run still exits before writing unless `--execute` is supplied.
- The shared source registry has been materialized at `/data/jaguir26/local/src/shared_dynamic_fit_forecast_validation/sources/dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast`.
- `config/validation/qdesn_dynamic_fitforecast_v2_full_grid.csv` is present with 36 Q-DESN roots.
- `config/validation/qdesn_dynamic_fitforecast_v2_source_window_verification.csv` is present with 18 PASS rows.
- `results/qdesn_mcmc_validation/dynamic_fitforecast_v2_qdesn_sources/materialized_source_inventory.csv` is present with 18 materialized source windows.

Completed before smoke/full launch:

1. Add a runtime guard to the detached launch/preflight path so it records and enforces `Rscript`, `R_HOME`, R version, and `.libPaths()`. It should fail if the shell resolves an older `/usr/bin/Rscript`.
2. Rewire `scripts/launch_qdesn_dynamic_fitforecast_v2_validation.R` so `mcmc_tt500` selects only `fit_size == 500` and `mcmc_tt5000` selects only `fit_size == 5000`. The current wrapper advertises these phases but only changes `--methods mcmc`.
3. Update the v2 metric/reporting contract away from legacy fit-only labels such as `primary_window: train` and `holdout_role: secondary_single_point`. The study should report effective train fit metrics plus forecast metrics at H=100 and H=1000 from the 9001:10000 forecast block.
4. Add an end-to-end no-leakage audit that confirms fitted Q-DESN train indices match the effective train rows after lag/washout and forecast rows begin at source index 9001.
5. Keep the storage-light contract as a smoke gate: successful cases should retain compact summaries and not full successful `forecast_objects.rds`, `.rda`, or `.RData` payloads by default.

The completed non-fitting sequence was:

```sh
Rscript scripts/run_qdesn_dynamic_fitforecast_v2_source_refresh.R --execute
Rscript scripts/verify_qdesn_dynamic_fitforecast_v2_source_windows.R
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R --defaults config/validation/qdesn_dynamic_fitforecast_v2_storage_light_defaults.yaml --grid config/validation/qdesn_dynamic_fitforecast_v2_full_grid.csv --batch smoke --allow-grid-subset --prepare-only
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R --defaults config/validation/qdesn_dynamic_fitforecast_v2_storage_light_defaults.yaml --grid config/validation/qdesn_dynamic_fitforecast_v2_full_grid.csv --batch full --methods vb --allow-grid-subset --prepare-only
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R --defaults config/validation/qdesn_dynamic_fitforecast_v2_storage_light_defaults.yaml --grid config/validation/qdesn_dynamic_fitforecast_v2_full_grid.csv --batch full --methods mcmc --fit-sizes 500 --allow-grid-subset --prepare-only
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R --defaults config/validation/qdesn_dynamic_fitforecast_v2_storage_light_defaults.yaml --grid config/validation/qdesn_dynamic_fitforecast_v2_full_grid.csv --batch full --methods mcmc --fit-sizes 5000 --allow-grid-subset --prepare-only
```

The next explicit-approval sequence is:

```sh
Rscript scripts/launch_qdesn_dynamic_fitforecast_v2_validation.R --phase smoke --dry-run
Rscript scripts/launch_qdesn_dynamic_fitforecast_v2_validation.R --phase smoke --prepare-only
QDESN_FFV2_LAUNCH_APPROVED=true \
  Rscript scripts/launch_qdesn_dynamic_fitforecast_v2_validation.R --phase smoke
Rscript scripts/healthcheck_qdesn_dynamic_fitforecast_v2_validation.R
Rscript scripts/export_qdesn_dynamic_fitforecast_v2_shared_interface.R --campaign-report-root <campaign-report-root>
```

Treat the smoke as wiring, runtime, storage, and source-index evidence only. It is not MCMC-quality evidence.

Real Q-DESN compute is now approval-gated. Any non-prepare launch refuses to
start unless `QDESN_FFV2_LAUNCH_APPROVED=true` is set. TT5000/full additionally
requires `QDESN_FFV2_TT5000_APPROVED=true`. The aborted partial smoke tag
`qdesn-dynamic-fitforecast-v2-smoke-20260515-184752__git-5de7a28` is invalid
and must not be used by Article-Q-DESN.

## Canonical Implementation Plan

The canonical Q-DESN implementation tracker is:

`config/validation/qdesn_dynamic_fitforecast_v2_IMPLEMENTATION_PLAN.md`

That plan supersedes the rough checklist below whenever there is a conflict. Its key decision is compatibility-first:

- restore/adapt the known Q-DESN pipeline entrypoint contract for the pre-launch path;
- add strict runtime, source-index, launcher-filter, horizon-summary, and storage-light tests around it;
- defer a broad package-native rewrite until artifact parity and numerical smoke parity can be proven.

This README remains the local operator guide. The implementation plan is the source of truth for rewiring order, tests, documentation requirements, reproducibility manifests, launch gates, and definition of ready.

## Detailed Cleanup Plan Before Launch

Do this before source generation, smoke, or full launch:

1. Runtime and preflight guard.
   - Enforce R 4.6.0 or newer.
   - Record `Sys.which("Rscript")`, `R_HOME`, `R.version.string`, `.libPaths()`, and R library environment variables.
   - Fail fast if launch resolves `/usr/bin/Rscript`.

2. Pipeline entrypoint compatibility.
   - `R/run_esn_pipeline.R` dispatches to `scripts/pipeline_real_main.R` and `scripts/pipeline_sim_main.R`.
   - Those files are currently absent in this worktree.
   - Restore the latest compatible Q-DESN pipeline entrypoints or replace `run_esn_pipeline_from_cfg()` with a package-native equivalent that writes the same artifact contract.
   - Add a non-skipping tiny pipeline test; the current pipeline test skipped because fixture data are absent.

3. Launcher phase filtering.
   - Add generic runner filters such as `--fit-sizes`.
   - Wire `mcmc_tt500` to `--methods mcmc --fit-sizes 500`.
   - Wire `mcmc_tt5000` to `--methods mcmc --fit-sizes 5000`.
   - Keep selected-grid CSVs as the auditable record.

4. Effective-train/no-leakage audit.
   - Confirm the realized fitted training rows match the intended post-lag/post-washout effective train window.
   - Ensure compact path alignment uses the effective train indices, not a broader shared reservoir index.
   - Add method-level index alignment output and healthcheck gates.

5. Fit+forecast metric schema.
   - Preserve existing `holdout_*` columns as backward-compatible aliases for the full H=1000 forecast block.
   - Add explicit forecast horizon summaries for H=100 and H=1000 from compact forecast paths.
   - Make article-facing tables consume CSV summaries, not full `forecast_objects.rds`.

6. Storage-light smoke gate.
   - Successful cases should keep compact summaries and prune full successful `forecast_objects.rds`.
   - Healthcheck must report retained heavy payload counts and bytes.

7. Source registry and launch sequence.
   - Generate shared source registry once after both validation chats agree.
   - Verify source windows.
   - Run prepare-only preflight.
   - Run smoke.
   - Run healthcheck and storage audit.
   - Only then request approval for staged full launch.

New tests to add:

- `test-qdesn-validation-runtime-guard.R`
- `test-qdesn-dynamic-fitforecast-launcher-filters.R`
- `test-qdesn-pipeline-entrypoints.R`
- `test-qdesn-dynamic-fitforecast-no-leakage.R`
- `test-qdesn-dynamic-fitforecast-horizon-summaries.R`

The staged full launch should remain:

1. VB full.
2. MCMC TT500.
3. MCMC TT5000.

Do not use an unfiltered all-at-once `full` phase for the first scientific campaign.

## Implementation Status Added 2026-05-15

The launch-prep rewiring from the canonical implementation plan is implemented and covered by focused tests:

- R 4.6.0 runtime guard and runtime/git/file-hash manifests.
- Restored compatibility pipeline entrypoints.
- Explicit `--fit-sizes` filtering for `mcmc_tt500` and `mcmc_tt5000`.
- Compact train/forecast index-alignment manifests.
- H=100 and H=1000 forecast horizon summaries.
- Storage-light pruning gated on compact outputs and index-alignment readiness.
- Healthcheck visibility for index alignment, horizon summaries, retained heavy artifacts, disk, and memory.

Verified safe checks:

```sh
Rscript -e 'pkgload::load_all(".", quiet=FALSE)'
Rscript -e 'pkgload::load_all(".", quiet=TRUE); files <- c("tests/testthat/test-qdesn-validation-runtime-guard.R", "tests/testthat/test-qdesn-dynamic-fitforecast-launcher-filters.R", "tests/testthat/test-qdesn-pipeline-entrypoints.R", "tests/testthat/test-pipeline-inference-validation.R", "tests/testthat/test-qdesn-dynamic-fitforecast-source-windows.R", "tests/testthat/test-exdqlm-forecast-horizon-inputs.R", "tests/testthat/test-qdesn-dynamic-fitforecast-no-leakage.R", "tests/testthat/test-qdesn-dynamic-fitforecast-horizon-summaries.R", "tests/testthat/test-qdesn-dynamic-fitforecast-storage-light.R", "tests/testthat/test-qdesn-fit-mcmc-precision-beta-api.R", "tests/testthat/test-qdesn-prior-defaults.R"); for (f in files) testthat::test_file(f, reporter="summary")'
Rscript scripts/run_qdesn_dynamic_fitforecast_v2_source_refresh.R
Rscript scripts/run_qdesn_dynamic_fitforecast_v2_source_refresh.R --execute
Rscript scripts/verify_qdesn_dynamic_fitforecast_v2_source_windows.R
```

Generated source/preflight evidence:

- Shared v2 source root: `/data/jaguir26/local/src/shared_dynamic_fit_forecast_validation/sources/dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast`
- Q-DESN materialized source inventory: `results/qdesn_mcmc_validation/dynamic_fitforecast_v2_qdesn_sources/materialized_source_inventory.csv`
- Q-DESN v2 grid: `config/validation/qdesn_dynamic_fitforecast_v2_full_grid.csv`
- Q-DESN source-window verification: `config/validation/qdesn_dynamic_fitforecast_v2_source_window_verification.csv`
- Source-window verification: `18 PASS / 0 FAIL`
- Grid shape: `36` roots = 3 families x 3 taus x 2 fit sizes x 2 priors
- Latest preflight grid SHA-256: `371e9e843a76d6a0a45b94014c361d37fa6131465f0f71071c98429ce587b4c7`
- Shared source footprint at generation time: about `33M`
- Materialized Q-DESN source footprint at generation time: about `8.7M`

Prepare-only preflight evidence:

```sh
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R --defaults config/validation/qdesn_dynamic_fitforecast_v2_storage_light_defaults.yaml --grid config/validation/qdesn_dynamic_fitforecast_v2_full_grid.csv --batch smoke --allow-grid-subset --prepare-only
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R --defaults config/validation/qdesn_dynamic_fitforecast_v2_storage_light_defaults.yaml --grid config/validation/qdesn_dynamic_fitforecast_v2_full_grid.csv --batch full --methods vb --allow-grid-subset --prepare-only
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R --defaults config/validation/qdesn_dynamic_fitforecast_v2_storage_light_defaults.yaml --grid config/validation/qdesn_dynamic_fitforecast_v2_full_grid.csv --batch full --methods mcmc --fit-sizes 500 --allow-grid-subset --prepare-only
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R --defaults config/validation/qdesn_dynamic_fitforecast_v2_storage_light_defaults.yaml --grid config/validation/qdesn_dynamic_fitforecast_v2_full_grid.csv --batch full --methods mcmc --fit-sizes 5000 --allow-grid-subset --prepare-only
```

Prepare-only run tags:

| Phase | Run tag | Selected roots | Selected cells | Methods | Fit sizes |
|---|---:|---:|---:|---|---|
| smoke | `qdesn-dynamic-exdqlm-crossstudy-smoke-20260515-051821__git-1417a82` | 2 | 2 | `vb,mcmc` | `500,5000` |
| `vb_full` | `qdesn-dynamic-exdqlm-crossstudy-full-20260515-051826__git-1417a82` | 36 | 18 | `vb` | `500,5000` |
| `mcmc_tt500` | `qdesn-dynamic-exdqlm-crossstudy-full-20260515-051831__git-1417a82` | 18 | 9 | `mcmc` | `500` |
| `mcmc_tt5000` | `qdesn-dynamic-exdqlm-crossstudy-full-20260515-051836__git-1417a82` | 18 | 9 | `mcmc` | `5000` |

Still not run:

- detached smoke launch;
- full scientific validation launch.

Next safe launch gate, after explicit approval:

```sh
Rscript scripts/launch_qdesn_dynamic_fitforecast_v2_validation.R --phase smoke
Rscript scripts/healthcheck_qdesn_dynamic_fitforecast_v2_validation.R
```

# exDQLM/DQLM c13 MCMC 500-Observation Refresh Plan

Date: 2026-07-04

## Objective

Run a matched exDQLM/DQLM MCMC refresh for the 500-observation rolling-origin simulation table using the same current-best c13 dynamic specification that repaired the exDQLM/DQLM VB rows.

This lane is validation-only until it completes and is materialized. It must not overwrite or silently replace Article-facing rows before the complete 18-cell by 30-lead grid is done/PASS and promoted through the handoff script.

## Current Evidence

- Worktree: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`
- Branch: `validation/shared-fitforecast-v2-1.0.0`
- Package baseline: exdqlm 1.0.0
- Current-best VB run tag: `20260702_exdqlm_dqlm_vb_c0_discount_screen`
- Current-best VB candidate: `c13_trend100_season1_df0995s099`
- Current-best VB calibration: `clock_c13_trend100_season1_df0995s099`
- c13 VB cells complete: 18 exDQLM/DQLM model/family/quantile cells
- c13 MCMC cells before this lane: 0 current-best c13 MCMC cells
- Superseded dry-run/smoke tag: `20260704_exdqlm_dqlm_c13_mcmc_500obs_refresh`
- Gate tag: `20260704_exdqlm_dqlm_c13_mcmc_500obs_refresh_v2`
- Full production tag: `20260704_exdqlm_dqlm_c13_mcmc_500obs_full_v1`

## Fixed Protocol

- Source registry hash: `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`
- Families: `gausmix`, `laplace`, `normal`
- Quantiles: `0.05`, `0.25`, `0.50`
- Model variants: `dqlm`, `exdqlm`
- Inference: `mcmc`
- Fit size: 500
- Fit window: source indices `8501:9000`
- Forecast block: source indices `9001:10000`
- Rolling forecast protocol: `rolling_origin_no_refit_state_update`
- Maximum lead: 30
- Origin stride: 30
- Expected cells: 18
- Expected lead rows: 540
- Expected scored origin/lead targets per cell: 1000

## c13 Specification

- Candidate id: `c13_trend100_season1_df0995s099`
- Calibration id: `clock_c13_trend100_season1_df0995s099`
- Trend C0 scale: 100
- Seasonal C0 scale: 1
- Discount factors: `0.995,0.99`
- Discount dimensions: `2,4`
- Latent clock mode: `post_warmup_source_index`
- Dynamic model period/harmonics: inherited from each frozen source metadata record

## MCMC Budget and Telemetry

- Burn-in: 5000
- Kept MCMC iterations: 20000
- Thin: 1
- VB initialization: enabled for full and pilot rows
- Stored draws: 2000
- Forecast draws: 2000
- Worker threads per row: 1
- Progress cadence: every 50 iterations
- Trace cadence: every 50 iterations
- Heartbeat interval: 1800 seconds
- Stale threshold: 1800 seconds
- Storage policy: compact successful artifacts only; no routine successful `.rds`, `.rda`, or `.RData` retention

Smoke rows intentionally use tiny budgets and `init_from_vb = false`. Pilot rows use tiny budgets and `init_from_vb = true`. Smoke and pilot rows are non-overlapping in the gate run so both gates exercise their own intended budgets. The production run is prepared separately with `--full-only`, so all 18 production rows remain pending and use the full MCMC budget above.

## Implemented Entry Points

- Prepare lane:
  `validation/fitforecast_v2/scripts/prepare_exdqlm_dqlm_c13_mcmc_500obs_refresh.R`
- Launch existing staged wrapper:
  `validation/fitforecast_v2/scripts/launch_exdqlm_dynamic_fitforecast_v2_validation.R`
- Healthcheck existing wrapper:
  `validation/fitforecast_v2/scripts/healthcheck_exdqlm_dynamic_fitforecast_v2_validation.R`
- Audit lane:
  `validation/fitforecast_v2/scripts/audit_exdqlm_dqlm_c13_mcmc_500obs_refresh.R`
- Strict handoff materializer:
  `validation/fitforecast_v2/scripts/materialize_exdqlm_dqlm_c13_mcmc_500obs_handoff.R`
- Shared helper:
  `validation/fitforecast_v2/R/exdqlm_c13_mcmc_refresh.R`

## Gate Sequence

1. Dry-run gate prepare.
2. Real gate prepare.
3. Dry-run smoke command expansion.
4. Run smoke with `EXDQLM_FFV2_LAUNCH_APPROVED=true`.
5. Healthcheck and audit with `--allow-incomplete`.
6. Run pilot with `EXDQLM_FFV2_LAUNCH_APPROVED=true`.
7. Healthcheck and audit with `--allow-incomplete`.
8. Prepare a separate full-only production run with `--full-only`.
9. Dry-run full `mcmc_tt500` command expansion and confirm 18 selected rows.
10. Launch full `mcmc_tt500` in the background with one core per row and BLAS/OpenMP threads forced to 1.
11. Periodic healthchecks until all rows are done/PASS or explicit failures are documented.
12. Run strict audit without `--allow-incomplete` on the full production run.
13. Materialize handoff only if the strict audit passes.
14. Update Article-Q-DESN tables only from the materialized handoff, not from raw run directories.

## Reproducible Commands

Dry-run prepare:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/prepare_exdqlm_dqlm_c13_mcmc_500obs_refresh.R \
  --dry-run \
  --workers 18
```

Real prepare:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/prepare_exdqlm_dqlm_c13_mcmc_500obs_refresh.R \
  --workers 18
```

Full-only production prepare:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/prepare_exdqlm_dqlm_c13_mcmc_500obs_refresh.R \
  --full-only \
  --workers 18
```

Smoke dry-run:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/launch_exdqlm_dynamic_fitforecast_v2_validation.R \
  --manifest validation/fitforecast_v2/runs/20260704_exdqlm_dqlm_c13_mcmc_500obs_refresh_v2/manifests/row_manifest.csv \
  --phase smoke \
  --validation-stage all \
  --dry-run
```

Smoke launch:

```bash
EXDQLM_FFV2_LAUNCH_APPROVED=true \
OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 \
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/launch_exdqlm_dynamic_fitforecast_v2_validation.R \
  --manifest validation/fitforecast_v2/runs/20260704_exdqlm_dqlm_c13_mcmc_500obs_refresh_v2/manifests/row_manifest.csv \
  --phase smoke \
  --validation-stage all \
  --workers 1
```

Pilot launch:

```bash
EXDQLM_FFV2_LAUNCH_APPROVED=true \
OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 \
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/launch_exdqlm_dynamic_fitforecast_v2_validation.R \
  --manifest validation/fitforecast_v2/runs/20260704_exdqlm_dqlm_c13_mcmc_500obs_refresh_v2/manifests/row_manifest.csv \
  --phase pilot \
  --validation-stage all \
  --workers 4
```

Full launch:

```bash
EXDQLM_FFV2_LAUNCH_APPROVED=true \
OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 \
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/launch_exdqlm_dynamic_fitforecast_v2_validation.R \
  --manifest validation/fitforecast_v2/runs/20260704_exdqlm_dqlm_c13_mcmc_500obs_full_v1/manifests/row_manifest.csv \
  --phase mcmc_tt500 \
  --validation-stage all \
  --workers 18
```

Healthcheck:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/healthcheck_exdqlm_dynamic_fitforecast_v2_validation.R \
  --manifest validation/fitforecast_v2/runs/20260704_exdqlm_dqlm_c13_mcmc_500obs_full_v1/manifests/row_manifest.csv
```

Strict audit:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/audit_exdqlm_dqlm_c13_mcmc_500obs_refresh.R \
  --manifest validation/fitforecast_v2/runs/20260704_exdqlm_dqlm_c13_mcmc_500obs_full_v1/manifests/row_manifest.csv
```

Materialize handoff:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/materialize_exdqlm_dqlm_c13_mcmc_500obs_handoff.R \
  --manifest validation/fitforecast_v2/runs/20260704_exdqlm_dqlm_c13_mcmc_500obs_full_v1/manifests/row_manifest.csv
```

## Article Rule

Article-Q-DESN may consume this lane only after `validation/fitforecast_v2/promotions/exdqlm_dqlm_c13_mcmc_500obs_authoritative_20260704/` exists with a strict materialization manifest. Before that, raw run directories are exploratory validation evidence, not article-facing truth.

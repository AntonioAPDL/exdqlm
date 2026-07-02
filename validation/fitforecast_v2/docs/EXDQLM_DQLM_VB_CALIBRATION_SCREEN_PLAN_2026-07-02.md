# exDQLM/DQLM VB Calibration Screen Plan

Date: 2026-07-02

Scope: shared fit+forecast validation harness only. Do not modify the core
exdqlm 1.0.0 package API. Do not launch MCMC from this lane.

## Objective

Find exDQLM/DQLM VB specifications that are no longer artificially weak in the
500-point training-window simulation comparison. The current clock-aligned run
proves that the old exDQLM/DQLM results were partly misaligned, but it is not
yet a final promotion candidate.

The next step should be a staged VB-only calibration screen, with MCMC still
blocked until a candidate passes the VB gates.

## Evidence From The Audit

Current diagnostic run:

```text
validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_clock_aligned_vb_calibration
```

Current branch and commit:

```text
validation/shared-fitforecast-v2-1.0.0
737d2e4 Record clock-aligned VB calibration results
```

Run health:

- dry-run source windows: `PASS 18`
- prepared manifest rows: `72`
- unique spec IDs: `72 of 72`
- completed rows: `8`
- completed health gates: `PASS 8`
- pending rows: `64`
- storage audit: `PASS`, `0` forbidden `.rds`, `.rda`, or `.RData` payloads
- shared interface rows: `240`

The clock-aligned run improved old exDQLM/DQLM results substantially:

- targeted fit RMSE ratios versus the old run: about `0.06` to `0.30`
- targeted forecast RMSE ratios versus the old run: about `0.06` to `0.27`

That is a real correction, but not a final calibration.

## DGP And Model Structure Check

The frozen source metadata is consistent across all families and quantiles:

- `TT_warmup = 2000`
- `TT_main = 10000`
- `period = 90`
- `harmonics = 1, 2`
- source C0 scale recorded in metadata: `0.01`
- state noise standard deviations: `5e-03, 2e-05, 4e-03, 4e-03, 3e-03, 3e-03`
- forecast block: `9001:10000`
- rolling forecast: `Hmax = 30`, `origin_stride = 30`

The validation model builder already uses the correct structural family:

- level plus slope trend block
- two seasonal harmonic blocks from `seasMod(p = 90, h = c(1, 2))`
- post-warmup latent clock for new prepared runs
- row-level provenance for `calibration_id`, clock, C0 scales, discount labels,
  model spec hash, and source hashes

Therefore, the optimal next move is not to change the period, harmonics, source
registry, or exdqlm package implementation. The next screen should calibrate
the dynamic prior and discount settings.

## Root Diagnosis

The current model uses the deterministic DGP initial state propagated to the
training start, with very tight prior covariance (`trend_C0_scale = 0.01`,
`seasonal_C0_scale = 0.01`). That is too confident for a latent path that has
already evolved through about 10,500 latent time steps before the 500-point
training window begins.

This is visible in the path summaries:

- normal tau `0.50`, DQLM:
  - first 50 fit RMSE: `17.329`
  - middle 50 fit RMSE: `4.721`
  - last 50 fit RMSE: `0.998`
- normal tau `0.50`, exDQLM:
  - first 50 fit RMSE: `17.367`
  - middle 50 fit RMSE: `4.403`
  - last 50 fit RMSE: `1.234`
- normal tau `0.25`, DQLM:
  - first 50 fit RMSE: `18.572`
  - middle 50 fit RMSE: `3.596`
  - last 50 fit RMSE: `1.358`

The model catches up, which argues against a wrong seasonal period/harmonic
structure. The main problem is adaptation at the beginning of the fit window.

The laplace tau `0.05` exDQLM row has a different problem:

- DQLM fit RMSE: `4.192`
- exDQLM fit RMSE: `8.267`
- DQLM forecast RMSE: `5.856`
- exDQLM forecast RMSE: `9.669`
- exDQLM VB status: `stopped` at the `300` iteration cap
- exDQLM fit bias: `8.073`
- exDQLM forecast bias: `8.957`

That row needs both prior-adaptation screening and VB stability screening.

## Current Metric Snapshot

Clock-aligned completed rows:

| Family | Tau | Variant | Fit RMSE | Fit Check | Forecast RMSE | Forecast Check | VB Fit Status |
|---|---:|---|---:|---:|---:|---:|---|
| gausmix | 0.50 | DQLM | 2.513 | 5.270 | 4.306 | 5.770 | converged, 30 iter |
| gausmix | 0.50 | exDQLM | 2.536 | 5.269 | 4.326 | 5.770 | converged, 139 iter |
| laplace | 0.05 | DQLM | 4.192 | 1.611 | 5.856 | 1.927 | converged, 119 iter |
| laplace | 0.05 | exDQLM | 8.267 | 1.736 | 9.669 | 2.159 | stopped, 300 iter |
| laplace | 0.50 | exDQLM | 1.466 | 4.425 | 3.589 | 5.328 | smoke budget, 15 iter |
| normal | 0.25 | DQLM | 6.402 | 3.574 | 3.046 | 3.402 | smoke budget, 50 iter |
| normal | 0.50 | DQLM | 6.224 | 4.631 | 2.643 | 4.119 | converged, 38 iter |
| normal | 0.50 | exDQLM | 6.162 | 4.607 | 2.656 | 4.124 | converged, 129 iter |

Comparison to the Q-DESN VB promotion artifacts shows the calibration goal:

- gausmix tau `0.50`: exDQLM/DQLM fit RMSE is about `1.2x` Q-DESN VB, but
  forecast RMSE is about `2.7x`.
- laplace tau `0.05`: DQLM fit RMSE beats Q-DESN VB, but forecast is about
  `1.25x`; exDQLM is weaker on both.
- normal tau `0.50`: forecast RMSE is close to Q-DESN VB, but fit RMSE is
  about `2.5x`, mostly because of the early-window transient.

## Why This Plan Is Better Than A Direct Full Relaunch

A direct full VB relaunch across a large grid would be wasteful because the
forecast step dominates runtime. In the current full VB rows, the package fit
often completed in tens to a few hundred seconds, but total fit+forecast rows
took about 10 to 15 minutes.

The harness supports `validation-stage = fit-only`, and successful fit rows
write compact fit summaries and handoff manifests. Therefore the efficient
screen is:

1. Fit-only prior-adaptation screen.
2. Forecast only for candidates that pass fit gates.
3. Full-budget fit+forecast confirmation for finalists.
4. MCMC only after a separate promotion audit.

This keeps the screen fast, failure-explicit, and storage-light.

## Recommended Candidate Axes

Do not screen period or harmonics in the first pass. They are known from the
source design and are already wired correctly.

Primary axes:

- `trend_C0_scale`: controls how quickly the level/slope can adapt at the
  beginning of the training window.
- `seasonal_C0_scale`: controls initial seasonal phase/amplitude flexibility.
- `df_value`: discount factors for trend and seasonal state blocks.
- `model_variant`: DQLM and exDQLM should both be screened, but they should be
  ranked separately because the laplace tail behavior differs.

Candidate grid for stage A:

| Candidate | trend_C0_scale | seasonal_C0_scale | df_value | dim_df | Purpose |
|---|---:|---:|---|---|---|
| c00_baseline | 0.01 | 0.01 | 0.98,0.98 | 2,4 | current diagnostic reference |
| c01_trend1_season001 | 1 | 0.01 | 0.98,0.98 | 2,4 | isolate trend adaptation |
| c02_trend10_season001 | 10 | 0.01 | 0.98,0.98 | 2,4 | stronger trend adaptation |
| c03_trend100_season001 | 100 | 0.01 | 0.98,0.98 | 2,4 | diffuse trend, tight seasonal |
| c04_trend10_season01 | 10 | 0.1 | 0.98,0.98 | 2,4 | modest seasonal adaptation |
| c05_trend100_season01 | 100 | 0.1 | 0.98,0.98 | 2,4 | diffuse trend, modest seasonal |
| c06_trend100_season1 | 100 | 1 | 0.98,0.98 | 2,4 | balanced diffuse prior |
| c07_trend400_season1 | 400 | 1 | 0.98,0.98 | 2,4 | stress-test early transient |
| c08_trend10_season1_df099 | 10 | 1 | 0.99,0.98 | 2,4 | smoother trend evolution |
| c09_trend100_season1_df099 | 100 | 1 | 0.99,0.98 | 2,4 | diffuse trend plus smoother trend discount |
| c10_trend100_season10_df099 | 100 | 10 | 0.99,0.98 | 2,4 | more seasonal flexibility |
| c11_trend100_season1_df0995 | 100 | 1 | 0.995,0.98 | 2,4 | highly persistent trend |
| c12_trend100_season10_df0995 | 100 | 10 | 0.995,0.98 | 2,4 | persistent trend, flexible seasonal |
| c13_trend100_season1_df0995s099 | 100 | 1 | 0.995,0.99 | 2,4 | persistent trend and seasonal |
| c14_trend400_season10_df0995 | 400 | 10 | 0.995,0.98 | 2,4 | diffuse-prior stress candidate |
| c15_trend1000_season10_df0995 | 1000 | 10 | 0.995,0.98 | 2,4 | upper-bound prior diffusion check |

The grid is intentionally small enough for a first screen and wide enough to
detect the main prior-adaptation pattern.

## Proposed Build Plan

### Build 01: Candidate Registry

Add a tracked candidate registry:

```text
validation/fitforecast_v2/config/exdqlm_dqlm_vb_calibration_screen_candidates_20260702.csv
```

Required columns:

- `candidate_id`
- `calibration_id`
- `trend_C0_scale`
- `seasonal_C0_scale`
- `df_value`
- `dim_df`
- `notes`

Every row must generate a unique `calibration_id` and `model_spec_hash`.

### Build 02: Expanded Screen Manifest

Implement a validation-harness-only prepare script:

```text
validation/fitforecast_v2/scripts/prepare_exdqlm_dqlm_vb_calibration_screen.R
```

The script should:

- read the frozen source registry through the existing defaults
- restrict the first screen to `fit_size = 500`, `inference = vb`
- expand base rows by candidate registry rows
- write one storage-light run root
- preserve the existing row config/status/metrics/log/heartbeat contract
- add candidate provenance columns to the manifest and shared interface
- refuse stale `/home/jaguir26/local/src` paths
- refuse duplicate `(source_cell, model_variant, candidate_id)` rows

Proposed run tag:

```text
20260702_exdqlm_dqlm_vb_c0_discount_screen
```

Proposed run root:

```text
validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen
```

### Build 03: Fit-Only Sentinel Screen

First launch only the diagnostic sentinel cells:

- normal tau `0.25`, DQLM
- normal tau `0.50`, DQLM and exDQLM
- laplace tau `0.05`, DQLM and exDQLM
- gausmix tau `0.50`, DQLM and exDQLM

Use:

- `validation-stage = fit-only`
- VB max iterations: `150` for the first pass
- stored draws: `300` to `500`
- workers: `16` to `24`, depending on current machine load

Fit-only pass gates:

- no runtime failures
- no forbidden binary payloads retained
- normal-family first-50 fit RMSE reduced by at least `50%` versus current
  clock-aligned baseline
- laplace tau `0.05` exDQLM fit RMSE reduced by at least `30%`
- no sentinel row worsens fit check loss by more than `15%`
- VB rows reaching max iteration are marked for final-budget retest, not
  promoted directly

### Build 04: Forecast Confirmation For Top Candidates

Select at most `4` to `6` candidates from the fit-only screen.

Run all 9 family/tau cells for both model variants under VB:

- fit size: `500`
- inference: `vb`
- validation stage: `all`
- forecast draws: `500` for screen confirmation
- rolling-origin contract unchanged: `Hmax = 30`, `origin_stride = 30`

Forecast gates:

- no failed rows
- storage audit PASS
- shared interface export PASS
- no row has forecast RMSE more than `1.5x` Q-DESN VB unless fit/check metrics
  clearly justify preserving it as a diagnostic baseline
- every candidate must improve the current clock-aligned forecast RMSE for the
  weak sentinel cells
- lead-level metrics must contain all `30` leads and the final partial origin
  behavior must remain valid

### Build 05: Finalist Full-Budget VB Confirmation

Select `1` to `2` finalists.

Run full-budget VB:

- VB max iterations: `300` or `500` for rows that previously capped
- forecast draws: `2000`
- stored draws: `2000`
- all 9 family/tau cells
- DQLM and exDQLM ranked separately

Promotion gates:

- all rows `done`
- storage audit PASS
- no active stale paths
- shared interface exported
- source registry hashes match the frozen source registry
- no catastrophic fit/forecast errors
- no unresolved row whose VB log ends at max iteration with unstable metrics

### Build 06: MCMC Promotion Decision

Do not launch MCMC automatically.

MCMC becomes eligible only after the full-budget VB confirmation identifies a
candidate that is materially better than the current clock-aligned baseline and
diagnostically competitive with Q-DESN VB for the same source cells.

The MCMC launch plan should be a separate document and should reuse the winning
VB handoffs for initialization.

## Why Not Maintain Separate Independent Branches

The current shared validation branch already contains:

- exdqlm 1.0.0 baseline compatibility
- shared source registry and hashes
- rolling-origin forecast contract
- telemetry/status/healthcheck infrastructure
- storage-light policy
- Q-DESN promotion artifacts
- exDQLM/DQLM clock-aligned provenance and interface schema

Creating a separate calibration branch would increase article-facing confusion.
Use the same branch and add a staged calibration-screen lane under
`validation/fitforecast_v2`.

## Required Tests Before Any Launch

Before launching the fit-only screen:

```bash
Rscript - <<'RS'
suppressPackageStartupMessages(library(testthat))
suppressPackageStartupMessages(pkgload::load_all('.', quiet = TRUE))
testthat::test_dir('validation/fitforecast_v2/tests/testthat', reporter = 'summary')
RS
```

Add tests for:

- candidate registry schema
- candidate expansion row counts
- unique spec IDs and model hashes
- candidate provenance in row configs and shared interface
- fit-only launch selection
- forecast-only or all-stage reuse behavior
- storage policy in candidate run roots
- stale path rejection

## Next Safe Implementation Step

Implement Build 01 and Build 02 only, then run dry-run manifest checks. Do not
launch the screen until the dry-run proves:

- expected candidate rows are present
- all candidate hashes are unique
- all source windows pass
- row configs carry the intended C0 and discount values
- no `/home/jaguir26/local/src` paths are active

After that, launch only Build 03 fit-only sentinels.


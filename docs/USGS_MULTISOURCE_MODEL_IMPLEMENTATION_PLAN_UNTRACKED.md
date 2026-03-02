# USGS Multisource Q-DESN Plan (Untracked Working Note)

## Objective
Build a production pipeline where the target is USGS discharge observations and predictors include:
- precipitation retrospective
- precipitation forecast
- soil-moisture retrospective
- soil-moisture forecast
- USGS/NWS/NWM streamflow forecast guidance

The system should support offline learning and online updates as new data arrives.

## What is already wired and stable in this repo
- The core VB-LD Q-DESN fitting path is already integrated for both offline and online modes.
- Offline/online branch is controlled by `cfg$vb$online$enabled` and runs through the same pipeline scripts.
- Single-quantile parity workflow is already available and uses a strict apples-to-apples runner.

## Current data reality (must be acknowledged before implementation)
In `exdqlm`, the registered real dataset currently points to:
- `/data/muscat_data/jaguir26/data/data_USGS_ppt_soil.csv`
- columns: `USGS`, `ppt`, `soil`
- no date column and no explicit forecast/reanalysis split

This means the repo does not yet contain a canonical, model-ready merged table with:
- retrospective vs forecast feature provenance
- cycle/issue-time metadata
- lead-time metadata
- validity timestamps for all streams

## Upstream data sources that appear available in website repo
From `/data/muscat_data/jaguir26/antonio-aguirre.github.io`:
- USGS/NWS/NWM forecast JSON artifact: `assets/data/forecasts/big_trees_latest.json`
- GEFS precip/soil forecast JSON artifact: `assets/data/forecasts/gefs_big_trees_latest.json`
- climate retrospective CSV: `climate_daily_ppt_soil.csv`
- soil retrospective/ongoing assets under `soil_moisture_data/`

These can be used to build the unified modeling table for `exdqlm`.

## Required canonical schema (proposed)
Create one canonical table keyed by `valid_time` with strict metadata columns:
- `valid_time` (UTC ISO timestamp or date)
- `target_usgs_obs`
- `ppt_retro`
- `soil_retro`
- `ppt_fcst` (forecast value valid at `valid_time`)
- `soil_fcst`
- `flow_fcst_p10`, `flow_fcst_p50`, `flow_fcst_p90` (or full quantile set)
- `source_cycle_time_pptsoil` (for forecast features)
- `source_cycle_time_flow`
- `lead_hours_pptsoil` / `lead_hours_flow`
- `data_quality_flags`

Rules:
- Never use features at `valid_time=t` that were issued after `t`.
- Keep retrospective and forecast features separate (no silent overwrite).
- Missing forecast values are allowed but must be explicit `NA`.

## Synchronization strategy
1. Define model cadence first (daily at fixed local hour is simplest).
2. For each prediction origin `t0`, materialize a feature vector using only data available up to `t0`.
3. Resolve mixed cadences (USGS high-frequency vs daily forecast/reanalysis) by an explicit aggregation policy:
- recommended starting point: daily mean/median/max for USGS depending on target definition
- keep aggregation deterministic and fixed in config
4. Store lagged features after synchronization, not before.

## Historical depth needed
Goal: enough history to learn seasonal + event dynamics.
- Minimum practical start: >= 3 years
- Preferred for robust dynamics and extremes: 10+ years
- If GEFS retrospective/hindcast is used as predictors, train only on periods where equivalent hindcast features exist or explicitly handle feature-regime shifts.

## Implementation phases
Phase 0: Data contract freeze
- Lock canonical schema and timestamp/lead semantics.
- Add schema validator and fail-fast checks.

Phase 1: Build canonical dataset generator
- New script to ingest retrospective + forecast streams and emit one aligned table.
- Write manifest with source file hashes and generation timestamp.

Phase 2: Integrate into `exdqlm` real pipeline
- Add dataset entry in `config/datasets.yaml` for canonical table.
- Set `columns` mapping in config for target + predictors.
- Keep existing offline behavior untouched.

Phase 3: Backtest and online simulation
- Rolling-origin evaluation with strict as-of feature availability.
- Single-quantile first (`p_vec: [0.5]`) for parity/robustness.
- Enable online schedule only after offline baseline is stable.

Phase 4: Operational updater
- Scheduled refresh of canonical dataset.
- Trigger model update/inference.
- Write compact outputs consumed by website plotting layer.

## Suggested initial model spec
- Start with `p_vec: [0.5]` and expand later.
- Inputs:
  - lagged USGS observations
  - lagged retro precip/soil
  - current/near-term forecast precip/soil leads
  - flow forecast summary features (p10/p50/p90 and/or spread)
- Keep RHS prior and current VB-LD machinery unchanged.

## Quality and risk checks
- Leakage checks:
  - enforce `feature_issue_time <= prediction_origin`
- Coverage checks:
  - report missingness by predictor block and lead
- Drift checks:
  - monitor distribution shifts in forecast inputs vs training period
- Operational checks:
  - if new cycle is incomplete, keep last successful model artifacts

## Open decisions to resolve before coding
1. Target definition: daily mean USGS flow vs daily max vs other.
2. Primary operating cadence/timezone for origin generation.
3. Exact forecast lead set to include (e.g., 1-10 days).
4. Whether to use only flow forecast quantiles or include deterministic artifacts.
5. Minimum back-history requirement for first production model.

## Immediate next actions (recommended)
1. Build a one-off data inventory report with temporal coverage for each stream.
2. Prototype canonical join for a short date range and run leakage checks.
3. Register canonical dataset in `config/datasets.yaml` and run one real-mode offline fit.
4. Run online-vs-offline comparison at `p=0.5` on the canonical dataset.

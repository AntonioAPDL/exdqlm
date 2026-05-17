# Shared Fit + Forecast v3 Primary Launch Plan

Status: prepared, not launched.

This plan is for the rolling-origin v3 validation benchmark on the exdqlm 1.0.0
baseline. The article-facing protocol is `rolling_origin_no_refit_state_update`
with `Hmax = 30` and `origin_stride = 30`. Full compute must not start until the
dry-run, smoke, and pilot gates below pass and a human explicitly approves the
next stage.

## Active Worktree

- Worktree: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`
- Branch: `validation/shared-fitforecast-v2-1.0.0`
- Package version: `1.0.0`
- Required R: `/data/jaguir26/local/opt/R/4.6.0/bin/Rscript`

## Stage Order

| Stage | Scope | Launch condition | Default workers |
|---|---|---|---:|
| source verification | source registry/window/hash checks only | always before compute | 0 |
| prepare-only/dry-run | manifests, selected rows, commands | before smoke | 0 |
| smoke | tiny VB-only paired Q-DESN and exDQLM/DQLM check | after dry-run PASS | 1 + 1 |
| micro-pilot | TT500 paired VB/MCMC wiring check | after smoke PASS | 2 + 2 |
| VB primary | all VB rows | after pilot PASS | 16 exDQLM, 24 Q-DESN |
| TT500 MCMC primary | all TT500 MCMC rows | after VB primary PASS | 8 exDQLM, 16 Q-DESN |
| TT5000 MCMC primary | all TT5000 MCMC rows | separate approval only | 4 exDQLM, 8 Q-DESN |

All model workers export one BLAS/OpenMP thread per process.

## Required Zero-Compute Check

```sh
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript scripts/run_shared_fitforecast_v2_dryrun_preflight.R
```

Expected outputs:

- `reports/shared_fitforecast_v2_orchestration/<run_label>/dryrun_preflight_summary.json`
- `reports/shared_fitforecast_v2_orchestration/<run_label>/dryrun_preflight_summary.md`
- exDQLM/DQLM row manifest under
  `validation/fitforecast_v2/runs/<dryrun_tag>/manifests/row_manifest.csv`
- Q-DESN prepare-only manifests under
  `reports/qdesn_mcmc_validation/dynamic_fitforecast_v2_validation/<run_tag>/launch/`

The dry-run status must be `PASS`.

## Smoke Plan

Plan only:

```sh
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript scripts/orchestrate_shared_fitforecast_v2_validation.R \
  --mode plan \
  --plan smoke \
  --max-active-workers 4
```

Execute only after reviewing the plan:

```sh
SHARED_FFV2_ORCHESTRATOR_APPROVED=true \
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript scripts/orchestrate_shared_fitforecast_v2_validation.R \
  --mode execute \
  --plan smoke \
  --max-active-workers 4 \
  --poll-minutes 5
```

Expected closeout:

- every selected smoke row terminal status is success/done;
- storage audit has zero forbidden successful `.rds`, `.rda`, or `.RData` payloads;
- progress and heartbeat files exist;
- shared interface rows are nonzero where lead metrics are produced.

## Micro-Pilot Plan

Plan only:

```sh
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript scripts/orchestrate_shared_fitforecast_v2_validation.R \
  --mode plan \
  --plan pilot \
  --max-active-workers 8
```

Execute only after smoke closeout:

```sh
SHARED_FFV2_ORCHESTRATOR_APPROVED=true \
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript scripts/orchestrate_shared_fitforecast_v2_validation.R \
  --mode execute \
  --plan pilot \
  --max-active-workers 8 \
  --poll-minutes 5
```

The pilot is intentionally small and TT500-focused. It verifies that MCMC, VB
warm-start reuse, rolling-origin lead metrics, healthchecks, and storage pruning
all work before primary compute.

## Primary VB + TT500 Plan

Plan only:

```sh
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript scripts/orchestrate_shared_fitforecast_v2_validation.R \
  --mode plan \
  --plan vb-and-tt500 \
  --max-active-workers 48 \
  --exdqlm-vb-workers 16 \
  --qdesn-vb-workers 24 \
  --exdqlm-mcmc-tt500-workers 8 \
  --qdesn-mcmc-tt500-workers 16
```

Execute only after pilot closeout:

```sh
SHARED_FFV2_ORCHESTRATOR_APPROVED=true \
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript scripts/orchestrate_shared_fitforecast_v2_validation.R \
  --mode execute \
  --plan vb-and-tt500 \
  --max-active-workers 48 \
  --exdqlm-vb-workers 16 \
  --qdesn-vb-workers 24 \
  --exdqlm-mcmc-tt500-workers 8 \
  --qdesn-mcmc-tt500-workers 16 \
  --poll-minutes 10
```

## TT5000 Gate

TT5000 MCMC is blocked until the user explicitly approves it after reviewing
TT500 results. It requires both orchestrator approval and TT5000 approval:

```sh
SHARED_FFV2_ORCHESTRATOR_APPROVED=true \
SHARED_FFV2_TT5000_APPROVED=true \
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript scripts/orchestrate_shared_fitforecast_v2_validation.R \
  --mode execute \
  --plan all-approved \
  --max-active-workers 48 \
  --poll-minutes 10
```

## Hard Stops

Stop and repair before advancing if any stage reports:

- stale `/home/jaguir26/local/src` paths;
- source registry hash or source window failure;
- missing lead-level forecast metrics for successful fit+forecast rows;
- missing progress or heartbeat files;
- stalled or interrupted telemetry without a terminal failure row;
- retained successful `.rds`, `.rda`, or `.RData` payloads;
- shared interface rows with a protocol other than
  `rolling_origin_no_refit_state_update`;
- mixed superseded fixed-origin v2 outputs in article-facing interfaces.

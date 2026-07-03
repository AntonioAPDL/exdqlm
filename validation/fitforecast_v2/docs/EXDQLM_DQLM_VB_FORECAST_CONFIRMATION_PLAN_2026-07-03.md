# exDQLM/DQLM VB Forecast Confirmation Plan

Date: 2026-07-03

Worktree:
`/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`

Branch:
`validation/shared-fitforecast-v2-1.0.0`

Current HEAD at planning audit:
`6bd70dc Honor DQLM VB max_iter in calibration screens`

## Purpose

Confirm whether the best exDQLM/DQLM VB calibration-screen candidates improve
rolling-origin forecast performance enough to justify promotion, article-facing
table updates, and any later MCMC follow-up.

This plan is deliberately narrower than a full relaunch. The fit-only screen has
already identified a small set of promising candidates. The correct next move is
forecast-only confirmation using retained fit handoffs, not another broad fit
run and not MCMC.

## Current Evidence

Calibration run root:

```text
validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen
```

Key files:

```text
validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/manifests/row_manifest.csv
validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/manifests/sentinel_top3_by_cell_fit_rmse.csv
validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/interfaces/exdqlm_dqlm_dynamic_fitforecast_v2_shared_interface.csv
validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/storage/cleanup_non_top3_fit_handoffs_20260703.csv
```

Post-cleanup healthcheck:

- row states: `fit_done 112`, `pending 176`
- health gates: `PASS 112`
- shared interface rows: `112`
- storage policy: `PASS`
- forbidden `.rds`, `.rda`, `.RData` payloads: `0`
- retained top-3 fit handoffs: `21`
- missing retained top-3 fit handoffs: `0`
- retained top-3 handoff storage: about `3.154 GiB`

The static manifest still has `status = pending` for many rows because it is a
launch manifest, not the authoritative post-run status source. Authoritative
status is in row status files and the healthcheck summaries.

## Selected Forecast-Confirmation Rows

The forecast-confirmation set is exactly the top three candidates by fit RMSE
within each observed model/family/tau/fit-size cell from the fit-only screen:

```text
67,68,78,83,84,94,97,98,110,113,124,126,228,230,238,260,268,270,276,284,286
```

Selection summary:

| Model | Family | Tau | Rows |
| --- | --- | ---: | ---: |
| DQLM | gausmix | 0.50 | 3 |
| exDQLM | gausmix | 0.50 | 3 |
| DQLM | laplace | 0.05 | 3 |
| exDQLM | laplace | 0.05 | 3 |
| DQLM | normal | 0.25 | 3 |
| DQLM | normal | 0.50 | 3 |
| exDQLM | normal | 0.50 | 3 |

Note: laplace `tau = 0.05` is included for confirmation because the fit-only
screen retained top candidates, but this cell remains diagnostically weak. It
should not be treated as solved unless forecast confirmation is materially
better than the current baseline and has stable diagnostics.

## Forecast Protocol

All selected row configs share:

- `validation_stage = forecast-only` for the next run
- `forecast_protocol = rolling_origin_no_refit_state_update`
- `state_update_method = deterministic_plugin_filter_train_median_latent_moments`
- `max_lead_configured = 30`
- `origin_stride = 30`
- `forecast_draws = 500`
- `stored_draws = 500`
- `handoff.prune_fit_on_success = FALSE`

Rolling-origin workload:

- origin count: `34`
- scored origin/lead/target pairs per row: `1000`
- selected rows: `21`
- total scored forecast points: `21000`
- source target range: `9001:10000`
- source origin range: `9000:9990`

With `S = Hmax = 30`, the rolling grid covers the forecast block exactly once
without duplicate target source indices. Early leads have 34 scored origins;
leads 26 to 30 have 33 scored origins due to the forecast-block edge.

## Why This Is the Optimal Next Step

### Alternative A: Forecast all 112 fit-only rows

Rejected.

Reasons:

- Most candidate handoffs were intentionally pruned after the fit-only screen.
- Forecasting all rows would require refitting many non-finalist candidates.
- It would spend compute on candidates that already lost the fit screen.
- It would produce more article-facing clutter rather than a clearer decision.

### Alternative B: Launch MCMC now

Rejected.

Reasons:

- MCMC should only follow a candidate that is competitive under VB on both fit
  and forecast.
- Current evidence is fit-only; forecast behavior can overturn fit rankings.
- MCMC would be expensive and premature, especially for weak laplace-left-tail
  cells.

### Alternative C: Start a new broader exDQLM/DQLM screen immediately

Rejected for normal and gausmix; deferred for laplace `tau = 0.05`.

Reasons:

- normal and gausmix have clear fit-screen improvements and should be forecasted
  before expanding the search.
- laplace `tau = 0.05` likely needs a targeted tail-specific screen, but that
  should be planned after seeing whether any retained laplace candidates rescue
  forecast performance.

### Alternative D: Forecast-confirm top-3 retained candidates

Recommended.

Reasons:

- Uses already-paid fit work.
- Requires no refit.
- Keeps storage-light behavior.
- Gives direct fit plus rolling-origin forecast evidence.
- Produces a small, interpretable candidate set for promotion decisions.

## Required Gates Before Launch

Run these checks immediately before any actual forecast-only launch:

```bash
git status --short --branch
df -h .
ps -eo pid,ppid,stat,etime,pcpu,pmem,cmd --sort=-pcpu | \
  rg '20260702_exdqlm_dqlm_vb_c0_discount_screen|launch_exdqlm_dynamic_fitforecast_v2_validation|run_exdqlm_dynamic_fitforecast_v2_row|fitforecast_v2'
Rscript validation/fitforecast_v2/scripts/healthcheck_exdqlm_dynamic_fitforecast_v2_validation.R \
  --manifest validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/manifests/row_manifest.csv
```

Expected pre-launch evidence:

- branch clean or only explicitly planned documentation changes
- no active worker for this run root
- all 21 selected fit handoffs exist
- healthcheck still reports `fit_done 112` and `PASS 112`
- storage audit still reports no forbidden binary payloads

## Dry-Run Command

```bash
ids="67,68,78,83,84,94,97,98,110,113,124,126,228,230,238,260,268,270,276,284,286"

Rscript validation/fitforecast_v2/scripts/launch_exdqlm_dynamic_fitforecast_v2_validation.R \
  --manifest validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/manifests/row_manifest.csv \
  --phase vb_full \
  --validation-stage forecast-only \
  --row-ids "$ids" \
  --workers 6 \
  --dry-run
```

Expected dry-run:

- `selected_rows: 21`
- all commands use `--validation-stage 'forecast-only'`
- no row outside the 21 retained top-3 set

## Recommended Launch Command

Use a moderate worker count first. Forecast-only rows read large fit handoffs
and perform rolling state updates; using too many workers can create memory and
I/O pressure. Start with `6` workers unless the machine is otherwise idle.

```bash
ids="67,68,78,83,84,94,97,98,110,113,124,126,228,230,238,260,268,270,276,284,286"

EXDQLM_FFV2_LAUNCH_APPROVED=true Rscript validation/fitforecast_v2/scripts/launch_exdqlm_dynamic_fitforecast_v2_validation.R \
  --manifest validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/manifests/row_manifest.csv \
  --phase vb_full \
  --validation-stage forecast-only \
  --row-ids "$ids" \
  --workers 6
```

Do not use `--force` unless a row is known to have a stale failed forecast-only
status and the failure has been diagnosed.

## Post-Launch Audit

After launch, run:

```bash
Rscript validation/fitforecast_v2/scripts/healthcheck_exdqlm_dynamic_fitforecast_v2_validation.R \
  --manifest validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/manifests/row_manifest.csv
```

Expected success:

- the 21 selected rows move from fit-only completion to `done`
- health gates remain `PASS`
- shared interface includes forecast metrics for selected rows
- forecast lead metrics exist for selected rows
- storage audit remains PASS
- no routine `.rds`, `.rda`, or `.RData` payload retention

Important outputs:

```text
validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/interfaces/exdqlm_dqlm_dynamic_fitforecast_v2_shared_interface.csv
validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/forecast_lead_metrics/
validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/manifests/status_counts.csv
validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/manifests/telemetry_summary.csv
validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/storage/storage_audit.csv
```

## Decision Rules After Forecast Confirmation

Promote a candidate only if:

- row status is `done`
- health gate is `PASS`
- fit metrics remain competitive
- forecast metrics improve or are competitive against the current article-facing
  exDQLM/DQLM baseline and Q-DESN comparison target
- lead-level forecast behavior is not pathological across `1:30`
- provenance fields are present:
  `candidate_id`, `screen_stage`, source registry hash, branch, commit,
  package version, run tag, forecast window metadata

Do not promote a candidate if:

- forecast-only fails or requires refit due to missing handoff
- forecast lead metrics are missing
- Hmax/stride/window metadata is missing
- it only improves fit but worsens rolling-origin forecast materially
- laplace `tau = 0.05` remains unstable or noncompetitive

## Next Branches of Work

### If normal and gausmix candidates forecast well

Promote the best VB candidate per model/family/tau cell and update the
article-facing validation tables from the shared interface. Consider MCMC only
for promoted candidates.

### If normal and gausmix fit improves but forecast does not

Audit the rolling state-update path and dynamic model evolution/discount
choices before any further broad screen.

### If laplace `tau = 0.05` remains weak

Prepare a separate left-tail screen. Candidate dimensions should focus on:

- stronger/looser trend variance alternatives
- tail-specific discount factors
- sigma/gamma prior behavior
- evolution matrix alignment with the period/harmonic DGP
- smaller finalist set before any MCMC

### If all exDQLM/DQLM VB remains clearly worse than Q-DESN

Do not spend MCMC broadly. Keep one representative DQLM/exDQLM benchmark if
needed for article comparison, and document Q-DESN dominance.

## Storage Policy

Keep:

- source/config/manifests/logs/status/health/metrics
- shared interface
- forecast lead metrics
- top-3 fit handoffs until forecast confirmation is complete
- cleanup ledgers

Delete only after explicit post-confirmation approval:

- non-promoted top-3 fit handoffs
- transient handoffs for candidates not selected for final promotion

Never delete:

- source registry or source hashes
- promoted article-facing interfaces
- logs needed to diagnose failed rows
- cleanup ledgers

## Open Questions Before Actual Launch

1. Should laplace `tau = 0.05` be forecasted now as part of the top-3 set, or
   excluded and handled only in a dedicated tail screen?
2. Should the launch use `6` workers as recommended, or a smaller count if other
   active work is consuming memory/I/O?
3. After forecast confirmation, should non-promoted top-3 handoffs be pruned
   immediately, or retained until article tables are updated?

Default recommendation:

- include laplace `tau = 0.05` in this confirmation because its handoffs are
  retained and the incremental cost is bounded
- use `6` workers
- defer pruning retained handoffs until the forecast audit and promotion
  decision are complete

## Implementation Ledger

### 2026-07-03 Forecast-Only Confirmation Launch

Pre-launch gates:

- branch: `validation/shared-fitforecast-v2-1.0.0`
- HEAD: `a4fcb74 Plan exDQLM DQLM VB forecast confirmation`
- selected top-3 rows: `21`
- retained fit handoffs present: `21 of 21`
- retained fit handoff storage: about `3.154 GiB`
- pre-launch healthcheck: `fit_done 112`, `pending 176`, `PASS 112`
- storage audit: `PASS`, forbidden `.rds`, `.rda`, `.RData` payloads: `0`

Dry-run command:

```bash
ids="67,68,78,83,84,94,97,98,110,113,124,126,228,230,238,260,268,270,276,284,286"

Rscript validation/fitforecast_v2/scripts/launch_exdqlm_dynamic_fitforecast_v2_validation.R \
  --manifest validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/manifests/row_manifest.csv \
  --phase vb_full \
  --validation-stage forecast-only \
  --row-ids "$ids" \
  --workers 6 \
  --dry-run
```

Dry-run result:

- `selected_rows: 21`
- every generated row command used `--validation-stage 'forecast-only'`
- row IDs matched the retained top-3 set

Approved launch command:

```bash
ids="67,68,78,83,84,94,97,98,110,113,124,126,228,230,238,260,268,270,276,284,286"

EXDQLM_FFV2_LAUNCH_APPROVED=true Rscript validation/fitforecast_v2/scripts/launch_exdqlm_dynamic_fitforecast_v2_validation.R \
  --manifest validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/manifests/row_manifest.csv \
  --phase vb_full \
  --validation-stage forecast-only \
  --row-ids "$ids" \
  --workers 6
```

Launch result:

- wrapper exit code: `0`
- selected rows completed: `21`
- selected row statuses: `done 21`
- selected row health gates: `PASS 21`
- selected rows with forecast summaries: `21`
- selected rows with forecast lead metrics: `21`
- no live workers for this run root after completion

Post-launch healthcheck:

- row states: `done 21`, `fit_done 91`, `pending 176`
- health gates: `PASS 112`
- telemetry states: `completed 21`, `fit_done 91`, `pending 176`
- storage audit: `PASS`
- forbidden payloads: `0`
- shared interface rows: `721`

Generated summary files:

```text
validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/manifests/top3_forecast_confirmation_summary_20260703.csv
validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/manifests/top3_forecast_confirmation_lead_summary_20260703.csv
```

Forecast-confirmation winners by H1000 forecast MAE within selected cells:

| Model | Family | Tau | Candidate | Fit RMSE | H1000 forecast MAE | H1000 check loss |
| --- | --- | ---: | --- | ---: | ---: | ---: |
| DQLM | gausmix | 0.50 | `c13_trend100_season1_df0995s099` | 1.598 | 1.840 | 5.541 |
| DQLM | laplace | 0.05 | `c13_trend100_season1_df0995s099` | 4.591 | 3.644 | 1.868 |
| DQLM | normal | 0.25 | `c13_trend100_season1_df0995s099` | 2.404 | 2.513 | 3.371 |
| DQLM | normal | 0.50 | `c13_trend100_season1_df0995s099` | 1.923 | 1.109 | 4.022 |
| exDQLM | gausmix | 0.50 | `c13_trend100_season1_df0995s099` | 1.595 | 1.859 | 5.542 |
| exDQLM | laplace | 0.05 | `c00_baseline` | 8.261 | 8.946 | 2.158 |
| exDQLM | normal | 0.50 | `c13_trend100_season1_df0995s099` | 1.988 | 1.125 | 4.023 |

Interpretation for the next decision:

- `c13_trend100_season1_df0995s099` is the dominant retained candidate across
  gausmix and normal cells for both DQLM and exDQLM.
- DQLM laplace `tau = 0.05` improved among retained candidates but remains
  materially worse than normal/gausmix in quantile MAE.
- exDQLM laplace `tau = 0.05` remains weak; the best retained exDQLM laplace
  forecast candidate is still the baseline.
- MCMC should not be launched broadly from this evidence. If MCMC is pursued,
  it should be restricted to promoted VB winners after comparison against
  Q-DESN and the existing article-facing DQLM/exDQLM baselines.

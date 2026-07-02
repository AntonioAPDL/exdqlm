# exDQLM/DQLM Clock-Aligned Calibration Plan

Date: 2026-07-02

Scope: validation harness only. Do not modify the core exdqlm 1.0.0 package API for this task.

## Diagnosis

The shared DGP saves the post-warmup latent path as the target quantile:

- `TT_warmup = 2000`
- `TT_main = 10000`
- source `q_true = mu`
- period `90`
- harmonics `1, 2`

The previous exDQLM/DQLM validation model used the right state structure, but initialized the model clock at the source training index only. Because the source path has already discarded the 2000 warmup states, the dynamic model must initialize the first fitted row at:

```text
latent_clock_start_source_index = TT_warmup + train_start_source_index
```

For the TT500 window `8501:9000`, this means the first fitted row uses latent clock index `10501`.

## Implemented Contract

New prepared runs use:

```yaml
models:
  calibration_id: clock_postwarmup_metaC0_df098_v1
  latent_clock_mode: post_warmup_source_index
```

Historical row configs without `latent_clock_mode` keep the old `source_index_only` behavior. This avoids silently reinterpreting old run roots.

The row config, manifest, metrics, and shared interface now carry:

- `calibration_id`
- `model_spec_hash`
- `latent_clock_mode`
- `latent_clock_start_source_index`
- `latent_clock_offset`
- `dynamic_model_period`
- `dynamic_model_harmonics`
- `model_C0_scale`
- `trend_C0_scale`
- `seasonal_C0_scale`
- `df_value`
- `dim_df`

## VB-First Calibration Gates

Do not launch MCMC until the VB gate passes.

Gate 1: source and manifest dry-run

```bash
cd /data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0
Rscript validation/fitforecast_v2/scripts/prepare_exdqlm_dynamic_fitforecast_v2_validation.R \
  --dry-run \
  --run-tag 20260702_exdqlm_dqlm_clock_aligned_vb_calibration_dryrun
```

Gate 2: prepare a storage-light run root

```bash
Rscript validation/fitforecast_v2/scripts/prepare_exdqlm_dynamic_fitforecast_v2_validation.R \
  --run-tag 20260702_exdqlm_dqlm_clock_aligned_vb_calibration
```

Gate 3: smoke VB only

```bash
EXDQLM_FFV2_LAUNCH_APPROVED=true \
Rscript validation/fitforecast_v2/scripts/launch_exdqlm_dynamic_fitforecast_v2_validation.R \
  --manifest validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_clock_aligned_vb_calibration/manifests/row_manifest.csv \
  --phase smoke \
  --inferences vb \
  --fit-sizes 500
```

Gate 4: targeted VB cells

Start with:

- normal, tau 0.50, TT500, DQLM and exDQLM
- laplace, tau 0.05, TT500, DQLM and exDQLM
- gausmix, tau 0.50, TT500, DQLM and exDQLM

Use the prepared manifest and selectors:

```bash
EXDQLM_FFV2_LAUNCH_APPROVED=true \
Rscript validation/fitforecast_v2/scripts/launch_exdqlm_dynamic_fitforecast_v2_validation.R \
  --manifest validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_clock_aligned_vb_calibration/manifests/row_manifest.csv \
  --phase vb_full \
  --families normal,laplace,gausmix \
  --taus 0.50,0.05 \
  --fit-sizes 500 \
  --inferences vb \
  --model-variants dqlm,exdqlm \
  --workers 6
```

For exact per-cell control, prefer `--row-ids` or `--spec-ids` after inspecting
the prepared manifest. The selector command above intentionally includes the
cross-product of the listed families and taus; use exact IDs if that is broader
than intended.

Executed targeted row IDs:

```bash
EXDQLM_FFV2_LAUNCH_APPROVED=true \
Rscript validation/fitforecast_v2/scripts/launch_exdqlm_dynamic_fitforecast_v2_validation.R \
  --manifest validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_clock_aligned_vb_calibration/manifests/row_manifest.csv \
  --phase vb_full \
  --row-ids 17,19,25,27,65,67 \
  --inferences vb \
  --fit-sizes 500 \
  --workers 6
```

Gate 5: broad VB calibration only after targeted cells improve

Candidate screening dimensions:

- clock mode fixed at `post_warmup_source_index`
- trend C0 scale: `0.01`, `1`, `10`, `100`
- seasonal C0 scale: `0.01`, `1`, `10`, `100`
- discount pairs: `0.98,0.98`, `0.995,0.98`, `0.995,0.95`, `0.99,0.90`

Each candidate must use a unique `calibration_id` and therefore a unique `model_spec_hash`.

Gate 6: MCMC promotion

Only promote cells whose VB fit and rolling-origin forecast metrics are competitive with Q-DESN or materially improve over the pre-calibration exDQLM/DQLM baseline.

## Article Policy

Until a clock-aligned run passes the VB and MCMC promotion gates, the existing exDQLM/DQLM TT500 article-facing rows should be treated as pre-calibration evidence. They should not be interpreted as the best attainable DQLM/exDQLM comparison.

## Execution Evidence

Run tag:

```text
20260702_exdqlm_dqlm_clock_aligned_vb_calibration
```

Run root:

```text
/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_clock_aligned_vb_calibration
```

Dry-run and prepare evidence:

- dry-run source rows: `18`
- dry-run manifest rows: `72`
- source window status: `PASS 18`
- prepared manifest rows: `72`
- unique spec IDs: `72 of 72`
- stale `/home/jaguir26/local/src` paths: `0`
- TT500 latent clock check: train start `8501` plus warmup `2000` gives `10501`
- TT5000 latent clock check: train start `4001` plus warmup `2000` gives `6001`

Smoke gate:

- row `43`: laplace, tau `0.50`, TT500, exDQLM VB, `done`, `PASS`, runtime `61.3s`
- row `57`: normal, tau `0.25`, TT500, DQLM VB, `done`, `PASS`, runtime `76.0s`

Targeted VB gate:

- row `17`: gausmix, tau `0.50`, TT500, DQLM VB, `done`, `PASS`, runtime `748.6s`
- row `19`: gausmix, tau `0.50`, TT500, exDQLM VB, `done`, `PASS`, runtime `716.4s`
- row `25`: laplace, tau `0.05`, TT500, DQLM VB, `done`, `PASS`, runtime `651.8s`
- row `27`: laplace, tau `0.05`, TT500, exDQLM VB, `done`, `PASS`, runtime `884.4s`
- row `65`: normal, tau `0.50`, TT500, DQLM VB, `done`, `PASS`, runtime `726.9s`
- row `67`: normal, tau `0.50`, TT500, exDQLM VB, `done`, `PASS`, runtime `618.0s`

Formal healthcheck:

- status counts: `done 8`, `pending 64`
- health gates: `PASS 8`
- telemetry states: `completed 8`, `pending 64`
- storage audit: `PASS`, `180` files, `8,642,385` bytes, `0` forbidden payloads
- shared interface rows: `240`

Evidence paths:

- status counts: `validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_clock_aligned_vb_calibration/manifests/status_counts.csv`
- telemetry summary: `validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_clock_aligned_vb_calibration/manifests/telemetry_summary.csv`
- storage audit: `validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_clock_aligned_vb_calibration/storage/storage_audit.csv`
- shared interface: `validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_clock_aligned_vb_calibration/interfaces/exdqlm_dqlm_dynamic_fitforecast_v2_shared_interface.csv`
- completed metric summary: `validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_clock_aligned_vb_calibration/manifests/completed_vb_metric_summary.csv`

## Result Interpretation

The clock-aligned correction is a real improvement over the pre-calibration run: targeted fit RMSE ratios are approximately `0.06` to `0.30` of the old values, and forecast RMSE ratios are approximately `0.06` to `0.27` of the old values for the inspected cells.

This is diagnostic success, not final promotion. The laplace tau `0.05` exDQLM VB cell still has weak absolute fit and forecast errors relative to the other targeted cells. Do not promote this calibration directly to MCMC without a broader VB screening step.

## Storage Policy

The existing storage-light contract remains active:

- scalar metrics
- compact fit/forecast path summaries
- lead-level rolling-origin summaries
- configs/manifests/logs/status/progress/heartbeats
- no routine successful `.rds`, `.rda`, or `.RData` retention

## Next Safe Command

The next safe work item is a broad VB-only calibration screen based on Gate 5. Keep MCMC blocked until the VB screen identifies one or more competitive candidate specifications.

Recommended next command family:

```bash
# Prepare candidate-specific run roots with unique calibration_id/model_spec_hash values,
# then launch VB-only TT500 rows for the candidate grid.
# Do not launch MCMC from this calibration task without a separate promotion audit.
```

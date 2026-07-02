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
  --phase smoke \
  --inferences vb \
  --fit-sizes 500 \
  --run-tag 20260702_exdqlm_dqlm_clock_aligned_vb_calibration
```

Gate 4: targeted VB cells

Start with:

- normal, tau 0.50, TT500, DQLM and exDQLM
- laplace, tau 0.05, TT500, DQLM and exDQLM
- gausmix, tau 0.50, TT500, DQLM and exDQLM

Use `--families`, `--taus`, `--fit-sizes 500`, `--inferences vb`, and `--model-variants dqlm,exdqlm`.

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

## Storage Policy

The existing storage-light contract remains active:

- scalar metrics
- compact fit/forecast path summaries
- lead-level rolling-origin summaries
- configs/manifests/logs/status/progress/heartbeats
- no routine successful `.rds`, `.rda`, or `.RData` retention

## Next Safe Command

After tests pass, the next safe command is the dry-run in Gate 1. Do not launch MCMC from this calibration task without a separate promotion audit.

# QDESN Validation Storage Efficiency Review

- generated_at: 2026-04-28
- worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`
- active validation run: `qdesn-dynamic-p90-steepertrend-n300m50-full-20260424-172949__git-366ca13`
- campaign results root: `results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation/qdesn-dynamic-p90-steepertrend-n300m50-full-20260424-172949__git-366ca13/20260424-172958__git-366ca13`

## Review Question

Can future QDESN validation launches avoid storing the full pipeline output while still preserving everything needed for:

- final comparison tables,
- VB vs MCMC / EXAL vs AL / RHS-NS vs ridge summaries,
- numerical-failure and diagnostic signoff,
- fit-overlay figures with quantile uncertainty bands,
- reproducibility and later audit?

Short answer: yes. The current storage footprint is dominated by one artifact class, `models/forecast_objects.rds`, while the comparison analysis mostly needs compact summaries and path-level posterior bands that can be written directly as small CSV/RDS artifacts.

## Current Storage Footprint

Measured on the current p90 steeper-trend n300/m50 run:

| Artifact group | Footprint | Count | Notes |
|---|---:|---:|---|
| Full campaign results root | 150 GiB | 36 roots / 144 fits | Current active validation output tree. |
| `.rds` files | 149.690 GiB | 360 files | Almost all storage. |
| `forecast_objects.rds` | 149.687 GiB | 144 files | Dominant payload. |
| `.csv` files | 0.246 GiB | 1150 files | Fit summaries, traces, manifests, path data. |
| Reports root | 138 MiB | many | Tables, figures, launch docs. |

By fit size:

| Fit size | `forecast_objects.rds` count | Total GiB | Mean GiB per fit |
|---:|---:|---:|---:|
| 500 | 72 | 22.5 | 0.312 |
| 5000 | 72 | 127.2 | 1.77 |

By method/model:

| Fit size | Inference | Model | Count | Total GiB | Mean GiB |
|---:|---|---|---:|---:|---:|
| 500 | MCMC | AL | 18 | 7.82 | 0.435 |
| 500 | MCMC | EXAL | 18 | 7.83 | 0.435 |
| 500 | VB | AL | 18 | 3.41 | 0.189 |
| 500 | VB | EXAL | 18 | 3.41 | 0.189 |
| 5000 | MCMC | AL | 18 | 34.5 | 1.92 |
| 5000 | MCMC | EXAL | 18 | 34.5 | 1.92 |
| 5000 | VB | AL | 18 | 29.1 | 1.62 |
| 5000 | VB | EXAL | 18 | 29.1 | 1.62 |

## Why `forecast_objects.rds` Is So Large

The current config correctly sets:

- `pipeline.outputs.keep_draws: no`
- `pipeline.outputs.keep_mcmc_vb_init: no`
- `mcmc.store_latent_draws: no`
- `mcmc.store_rhs_draws: no`

However, `keep_draws: no` currently does not suppress the main train posterior predictive matrices saved inside `forecast_objects.rds`. In `scripts/pipeline_sim_main.R`, each fit still stores:

- `yrep_tr`: train predictive draws,
- `mu_draws_tr`: train latent quantile/mean draws,
- `yrep_fc` and `mu_draws_fc`,
- `param_draws`,
- the full fitted object under `fit_train$fit`,
- `forecast_full`.

For one small TT500 VB/AL object:

| Component | Approx object size |
|---|---:|
| whole object | 208.84 MiB |
| `yrep_tr` | 76.29 MiB |
| `mu_draws_tr` | 76.29 MiB |
| `param_draws` | 27.77 MiB |
| `fit_train$fit` | 25.85 MiB |
| `df_pred_tr` | 1.94 MiB |
| `df_mu_tr` | 0.05 MiB |

For one small TT500 MCMC/AL object:

| Component | Approx object size |
|---|---:|
| whole object | 477.59 MiB |
| `fit_train$fit$samp.beta` | 276.64 MiB |
| `yrep_tr` | 76.29 MiB |
| `mu_draws_tr` | 76.29 MiB |
| `param_draws` | 28.43 MiB |
| `fit_train$fit$X` | 7.05 MiB |
| `df_pred_tr` | 1.94 MiB |
| `df_mu_tr` | 0.05 MiB |

The TT5000 objects are large mainly because `yrep_tr` and `mu_draws_tr` scale with `T * posterior_draws`, currently about `5000 * 20000` per matrix.

## What The Current Comparison Actually Uses

### Scalar Comparison Tables

The p90 closeout analysis primarily reads root/campaign fit-summary CSVs:

- `roots/*/tables/fit_summary.csv`
- optional campaign-level `campaign_fit_summary.csv`

The closeout grouping and pairwise comparisons are computed from columns already present in these fit-summary tables:

- root identifiers and surface axes,
- prior, inference, model,
- status, finite/domain checks,
- signoff grade and reason,
- runtime,
- train/holdout qtrue metrics,
- pinball and coverage metrics,
- posterior metric summaries.

For these tables, the full RDS objects are not needed if the CSV summaries are already final and repaired.

### Fit Overlay Figures

The fit-overlay plots currently reopen `forecast_objects.rds`, but only need a tiny subset:

- `df_mu_tr`: `h`, `mu`, `lo`, `hi`, `y`, plus `q_true` where available,
- `df_pred_tr`: `q_pred`, `q_true`, `y` if included,
- `fit_train$meta$keep_idx`,
- `fit_request.json` / source `series_wide.csv` to recover `source_t` and `q_true`.

The overlay does not need the full posterior draw matrices. A compact per-fit path table would replace the RDS dependency.

Recommended compact path artifact:

`tables/fit_quantile_path_train.csv`

Required columns:

- `h`
- `source_t`
- `source_index`
- `p0`
- `y`
- `q_true`
- `q_pred`
- `mu`
- `lo`
- `hi`
- `band_type`

Optional columns:

- `method`
- `model`
- `prior`
- `root_id`
- `fit_size`
- `family`
- `tau`

This table should be small even for TT5000.

### Final Repair / Signoff

The repair script currently reopens `forecast_objects.rds` to regenerate:

- `health_summary.csv`,
- `signoff_summary.csv`,
- `fit_summary_row.csv`,
- `progress_trace.csv`,
- `chain_summary.csv`,
- root-level summary tables.

For future runs, those should be written correctly at fit time and treated as first-class outputs. The repair script can remain as a legacy fallback for old/full-output runs, but the lean-output path should not require full RDS repair.

### Main Cross-Study Comparison

The broader main comparison analysis can recompute metrics directly from `forecast_objects.rds`, but the final metrics it needs are the same scalar metrics already emitted in `fit_summary_row.csv` / `fit_summary.csv`.

Future analyses should use the authoritative fit-summary table as the primary input and only use RDS as a legacy fallback or debug path.

## Essential Artifacts To Keep

These should be kept for every future validation launch:

| Artifact | Reason |
|---|---|
| root manifests and fit requests | Reproducibility and exact input/config audit. |
| source data references and source datasets | Required to reproduce and visually audit the simulated surface. |
| `observed.csv` and `q_true.csv` | Tiny and useful for local root validation. |
| `health_summary.csv` | Runtime/numerical status and scalar diagnostics. |
| `signoff_summary.csv` | PASS/WARN/FAIL logic and reasons. |
| `fit_summary_row.csv` | Main unit-level comparison row. |
| root `fit_summary.csv` | Four-method table per root. |
| root `root_signoff_summary.csv` | Root-level readiness. |
| `progress_trace.csv` | VB/MCMC diagnostic trace needed for signoff and debugging. |
| `chain_summary.csv` | MCMC ESS/ACF/Geweke/half-drift diagnostics. |
| timing CSV/JSON | Runtime and stage audit. |
| final campaign tables and figures | Main scientific comparison deliverables. |
| compact fit path table | Fit-overlay figures without full draw matrices. |

## Artifacts That Can Usually Be Avoided

These do not need to be kept for every successful validation fit:

| Artifact | Why it can be dropped in lean mode |
|---|---|
| full `forecast_objects.rds` | Dominates disk; scalar metrics and path bands can be emitted separately. |
| `yrep_tr` full draw matrix | Used to compute qhat/pinball/coverage; metrics can be computed during the fit and saved. |
| `mu_draws_tr` full draw matrix | Used to compute bands/metric posterior summaries; store `mu`, `lo`, `hi` and scalar summaries instead. |
| MCMC `samp.beta` matrix | Needed for diagnostics only before summarization; store `chain_summary` and selected scalar traces. |
| full `param_draws` | Useful for deep debug, not needed for standard comparison. |
| full `fit_train$fit` | Useful for forensic reruns, not needed after summaries/plots are materialized. |

## Recommended Future Storage Profiles

### `full_debug`

Current behavior. Keep full `forecast_objects.rds` for every fit.

Use only for:

- developing new metrics,
- debugging a numerical failure,
- small pilot/smoke runs.

### `analysis`

Recommended default for full validation launches.

Behavior:

- compute full posterior draws in memory as needed,
- write all scalar summaries,
- write compact train/holdout path tables,
- write traces and chain summaries,
- do not persist full `forecast_objects.rds` for successful fits,
- optionally keep full RDS only for failed fits and a small representative sample.

### `minimal_archive`

Post-closeout mode.

Behavior:

- keep campaign/root summaries, figures, manifests, logs, compact scorecards,
- delete or avoid all full fit binary payloads,
- rely on source datasets + seeds + configs for exact regeneration.

## Proposed Implementation Plan

1. Finalize the current launch first.

   Run final repair/closeout before deleting any current `forecast_objects.rds`, because the current repair path still depends on those files.

2. Add a validation storage contract to defaults.

   Suggested YAML:

   ```yaml
   pipeline:
     outputs:
       save: yes
       keep_draws: no
       keep_mcmc_vb_init: no
       retention_profile: analysis
       save_forecast_objects: no
       save_compact_fit_paths: yes
       save_metric_summaries: yes
       retain_full_rds:
         failures: yes
         representative: yes
         representative_max_per_surface: 1
   ```

3. Write compact artifacts during the pipeline run.

   Add tables such as:

   - `tables/fit_quantile_path_train.csv`
   - `tables/fit_quantile_path_holdout.csv`
   - `tables/posterior_metric_summary.csv` if any scalar metrics are not already in `fit_summary_row.csv`

4. Make collectors prefer compact artifacts.

   `collect_pipeline_run_summary()` should first read:

   - status/runtime/timing files,
   - health/signoff/fit-summary CSVs,
   - compact path tables,
   - progress/chain summaries.

   It should read `forecast_objects.rds` only as a fallback for legacy runs.

5. Update plot code.

   Fit overlay generation should first use `fit_quantile_path_train.csv`. It should only fall back to `forecast_objects.rds` if the compact path table is missing.

6. Update repair code.

   The repair script should be split into:

   - compact repair: rebuild root/campaign tables from CSV summaries,
   - legacy repair: reopen full RDS and regenerate missing summaries.

7. Add tests.

   Required tests:

   - full-output and lean-output summaries match on a small fixture,
   - overlay figures render without `forecast_objects.rds`,
   - campaign collection works after deleting full RDS payloads,
   - final closeout refuses to run if compact summaries are incomplete,
   - cleanup scripts do not delete active/current launches before closeout.

## Implemented Analysis-Retention Contract

The validation wrapper now supports an explicit analysis-retention mode for future launches.

Config fields:

```yaml
pipeline:
  outputs:
    retention_profile: analysis
    save_forecast_objects: no
    save_compact_fit_paths: yes
    retain_full_rds_on_failure: yes
```

Behavior:

- successful fits still compute posterior samples in memory for metrics and bands;
- each successful fit writes compact path tables:
  - `tables/fit_quantile_path_train.csv`
  - `tables/fit_quantile_path_holdout.csv`
- `fit_summary_row.csv` records these compact path locations;
- closeout overlay plots read compact path tables first and only fall back to `forecast_objects.rds` for legacy outputs;
- successful `forecast_objects.rds` payloads are pruned when `save_forecast_objects: no`;
- failed fits keep their full RDS by default for forensic debugging;
- each fit writes `manifest/output_retention.json` with the retention mode, compact path rows, pruned bytes, and final RDS existence.

This keeps the existing high-draw posterior metrics intact while avoiding persistent storage of the full posterior draw matrices and full fit object for successful validation runs.

## Cleanup Support

The cleanup script now accepts scoped cleanup:

```bash
bash scripts/cleanup_qdesn_validation_rds_payloads.sh \
  --scope-root results/qdesn_mcmc_validation/<campaign>/<run> \
  --run-label <label>
```

The default remains dry-run only. Execute mode still requires `--execute` and still blocks if live QDESN sessions or manual-review `.RData` files are detected. Scoped cleanup is the recommended mode for this campaign because it prevents broad deletion across unrelated validation work.

For the current p90 n300/m50 run, the safe order remains:

1. run final repair/closeout while full RDS files still exist,
2. generate/verify compact fit path tables and final overlay figures,
3. dry-run scoped cleanup and inspect the manifest,
4. execute scoped cleanup only after the closeout artifacts are confirmed.

## Current Run Cleanup Result

The current p90 n300/m50 campaign was cleaned with scoped cleanup after compact train/holdout fit-path tables were materialized.

| Check | Result |
|---|---:|
| Compact train path tables | 144 / 144 |
| Compact holdout path tables | 144 / 144 |
| Full `forecast_objects.rds` files remaining in current run | 0 |
| Current run results root after cleanup | about 430 MiB |
| Deleted payload files | 360 |
| Deleted payload footprint | 149.69 GiB |
| Observed `/home` free-space delta | 149.69 GiB |
| Post-cleanup fit-overlay figures | 24 / 24 successful |
| Global binary dry-run candidates after cleanup | 0 |
| Old non-baseline progress traces deleted | 9 |
| Old progress-trace footprint deleted | 0.39 GiB |

Key audit artifacts:

- materialization audit: `results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation/qdesn-dynamic-p90-steepertrend-n300m50-full-20260424-172949__git-366ca13/20260424-172958__git-366ca13/compact_fit_path_materialization/20260428-195604/compact_fit_path_materialization_audit.csv`
- latest closeout root: `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_closeout_analysis/qdesn-dynamic-p90-steepertrend-n300m50-closeout-analysis-20260428-201418__git-f282f63`
- dry-run cleanup summary: `reports/qdesn_mcmc_validation/storage_cleanup/qdesn_p90_n300m50_scoped_payload_cleanup_dryrun_20260428/cleanup_summary.md`
- executed cleanup summary: `reports/qdesn_mcmc_validation/storage_cleanup/qdesn_p90_n300m50_scoped_payload_cleanup_execute_20260428/cleanup_summary.md`
- post-cleanup zero-payload verification: `reports/qdesn_mcmc_validation/storage_cleanup/qdesn_p90_n300m50_postcleanup_zero_verification_20260428/cleanup_summary.md`
- global binary dry-run: `reports/qdesn_mcmc_validation/storage_cleanup/qdesn_validation_global_payload_cleanup_dryrun_20260428/cleanup_summary.md`
- old progress trace cleanup: `reports/qdesn_mcmc_validation/storage_cleanup/qdesn_validation_old_progress_trace_cleanup_20260428/cleanup_summary.md`
- post-cleanup overlay pack: `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_fit_overlay_pack/qdesn-p90-n300m50-fit-overlay-postcleanup-20260428/summary/qdesn_dynamic_p90_steepertrend_n300m50_fit_overlay_pack.md`

## Official Baseline Registration

The cleaned p90 steeper-trend n300/m50 campaign is now the official QDESN
dynamic baseline for future relaunches with new QDESN specifications.

- baseline config: `config/validation/qdesn_dynamic_p90_steepertrend_n300m50_official_baseline.yaml`
- baseline report: `docs/BASELINE__qdesn_dynamic_p90_steepertrend_n300m50_20260428.md`

Future launches should use the baseline closeout tables for comparison, keep
`retention_profile: analysis` by default, and preserve compact train/holdout
fit-path tables so fit-overlay uncertainty figures remain reproducible without
full successful `forecast_objects.rds` payloads.

## Expected Savings

For the current 144-fit p90 n300/m50 run:

| Strategy | Expected saved space |
|---|---:|
| Delete all `forecast_objects.rds` after final closeout | about 149.7 GiB |
| Future `analysis` mode that never persists full successful RDS | about 149.7 GiB avoided for this run size |
| Keep only compact CSV summaries + path bands | likely under 1 GiB for this campaign |
| Keep a small set of representative full RDS debug payloads | configurable; likely 5-15 GiB depending retention count |

## Main Risk

The only real tradeoff is future metric flexibility. If we delete or never store full posterior draw matrices, we cannot later invent a brand-new draw-level metric without rerunning the fit.

Mitigation:

- compute and store rich scalar posterior summaries now,
- keep compact path bands for visualization,
- retain full RDS for failures and a small representative sample,
- keep exact configs, source datasets, seeds, and git SHA so full fits are reproducible if deeper forensics are needed.

## Recommendation

Adopt `retention_profile: analysis` as the default for future full validation launches after the current run is finalized. This should preserve the scientific comparison workflow while avoiding nearly all of the current 150 GiB run footprint.

The immediate safe sequence is:

1. run final repair/closeout for the current launch,
2. archive/verify all final comparison tables and fit-overlay figures,
3. prune current `forecast_objects.rds` with a documented cleanup manifest if space is needed,
4. implement lean-output support before the next full 144-fit relaunch.

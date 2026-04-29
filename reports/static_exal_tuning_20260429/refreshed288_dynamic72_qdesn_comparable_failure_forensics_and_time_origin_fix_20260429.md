# Dynamic 72 Q-DESN-Comparable Smoke Forensics And Time-Origin Fix

## Executive Finding

The v1 smoke blocker was not primarily a corrupted dataset, disk/storage issue, or generic exDQLM numerical failure.

The root cause was a dynamic time-origin mismatch. The canonical Q-DESN-comparable DQLM/exDQLM fits correctly used the retained tail windows (`fit_input_lastTT500` and `fit_input_lastTT5000`), but the fitted dynamic model prior still restarted the trend and seasonal state at source index `1`. The actual fitting windows start at source index `6501` for `TT500` and `2001` for `TT5000`.

This made the first fitted signal badly misaligned with `q_true`, especially for `TT500`, and then surfaced as broad poor-fit metrics, exDQLM sigma/gamma ESS warnings, one exDQLM sigma/gamma ESS failure, and expensive TT5000 MCMC rows that were manually stopped after the smoke gate had already failed.

## Run Under Review

| Item | Value |
| --- | --- |
| v1 smoke run tag | `20260429_p90_dynamic72_qdesn_comparable_v1` |
| v1 run root | `tools/merge_reports/full288_refreshed288_20260429_p90_dynamic72_qdesn_comparable_v1` |
| Dynamic dataset | `dlm_constV_p90_m0amp_highnoise_steepertrend_v1` |
| Intended dynamic surface | `18 datasets x 2 models x 2 engines = 72 rows` |
| v1 smoke surface | `12 VB + 12 MCMC dynamic rows` |
| Full 72 launch | Not started |

## Every Problem Row Reviewed

| Row | Case | v1 Status | Gate | Evidence | Root Cause Assessment | Action |
| ---: | --- | --- | --- | --- | --- | --- |
| 20 | `gausmix tau=0.50 TT500 exdqlm mcmc` | `done` | `WARN` | `ess_sigma_per1k=6.49`, `ess_gamma_per1k=5.65`, `acf1_gamma=0.989`, `q_rmse=47.10` | Chain ran, but fit started from the wrong dynamic time origin; sigma/gamma mixing warning is downstream of poor early adaptation. | Relaunch under source-index aligned dynamic model before adding repair overlays. |
| 44 | `laplace tau=0.50 TT500 exdqlm mcmc` | `done` | `FAIL` | `ess_sigma_per1k=4.45`, `ess_gamma_per1k=3.64`, `acf1_gamma=0.993`, `q_rmse=38.69` | Same time-origin mismatch, with the strongest exDQLM sigma/gamma sampler-health symptom. | First row to re-check after v2 smoke; only add stronger exDQLM repair controls if it still fails. |
| 68 | `normal tau=0.50 TT500 exdqlm mcmc` | `done` | `WARN` | `ess_sigma_per1k=10.78`, `ess_gamma_per1k=9.93`, `acf1_gamma=0.980`, `q_rmse=40.97` | Same time-origin mismatch; gamma was just below the PASS ESS threshold. | Relaunch under source-index aligned dynamic model. |
| 22 | `gausmix tau=0.50 TT5000 dqlm mcmc` | `failed_runtime` | `FAIL` | Manual stop after `7918.54 sec`; no metrics/health output | Operational stop, not a numerical exception; likely also affected by the same source-origin mismatch and long TT5000 runtime. | Relaunch only after v2 smoke passes; keep MCMC workers conservative. |
| 24 | `gausmix tau=0.50 TT5000 exdqlm mcmc` | `failed_runtime` | `FAIL` | Manual stop after `7918.81 sec`; no metrics/health output | Operational stop, not a numerical exception; same origin-risk plus exDQLM cost. | Relaunch only after v2 smoke passes; watch sigma/gamma ESS. |
| 46 | `laplace tau=0.50 TT5000 dqlm mcmc` | `failed_runtime` | `FAIL` | Manual stop after `7917.99 sec`; no metrics/health output | Operational stop, not a numerical exception; same origin-risk plus long TT5000 runtime. | Relaunch only after v2 smoke passes. |
| 48 | `laplace tau=0.50 TT5000 exdqlm mcmc` | `failed_runtime` | `FAIL` | Manual stop after `7918.86 sec`; no metrics/health output | Operational stop, not a numerical exception; same origin-risk plus exDQLM cost. | Relaunch only after v2 smoke passes; row 44 informs repair need. |
| 70 | `normal tau=0.50 TT5000 dqlm mcmc` | `failed_runtime` | `FAIL` | Manual stop after `5886.45 sec`; no metrics/health output | Operational stop, not a numerical exception; same origin-risk plus long TT5000 runtime. | Relaunch only after v2 smoke passes. |
| 72 | `normal tau=0.50 TT5000 exdqlm mcmc` | `failed_runtime` | `FAIL` | Manual stop after `5858.55 sec`; no metrics/health output | Operational stop, not a numerical exception; same origin-risk plus exDQLM cost. | Relaunch only after v2 smoke passes. |

## Why This Was Not Just An exDQLM Warmup Problem

The completed DQLM MCMC rows passed sampler health, but the fits were also poor under v1:

| Row | Case | Gate | q RMSE | CRPS |
| ---: | --- | --- | ---: | ---: |
| 18 | `gausmix tau=0.50 TT500 dqlm mcmc` | `PASS` | `45.48` | `26.46` |
| 42 | `laplace tau=0.50 TT500 dqlm mcmc` | `PASS` | `38.18` | `22.65` |
| 66 | `normal tau=0.50 TT500 dqlm mcmc` | `PASS` | `40.15` | `22.25` |

The dynamic VB rows also passed health but had similarly poor q RMSE:

| Row | Case | Gate | q RMSE | CRPS |
| ---: | --- | --- | ---: | ---: |
| 17 | `gausmix tau=0.50 TT500 dqlm vb` | `PASS` | `46.06` | `26.69` |
| 41 | `laplace tau=0.50 TT500 dqlm vb` | `PASS` | `38.61` | `22.87` |
| 65 | `normal tau=0.50 TT500 dqlm vb` | `PASS` | `40.94` | `22.69` |

This points to a shared dynamic-model setup issue rather than a narrow exAL sigma/gamma sampler issue.

## Historical Baseline Clarification

The earlier `20260422_p90_full288_baseline_v1` looked much better for these row labels, with q RMSE around `4.7` to `6.5`, but its retained plot summaries for representative dynamic rows had `7000` rows with `source_index=1:7000`.

That older run was therefore not the same Q-DESN-comparable tail-window contract. The current v1 smoke correctly used only `fit_input_lastTT500` / `fit_input_lastTT5000`, but exposed the model-origin mismatch that the full-root fit had hidden.

| Representative Row | Older q RMSE | Older Plot Rows | Older Source Index Span |
| ---: | ---: | ---: | --- |
| 17 | `6.50` | `7000` | `1:7000` |
| 18 | `6.51` | `7000` | `1:7000` |
| 20 | `6.54` | `7000` | `1:7000` |
| 44 | `5.45` | `7000` | `1:7000` |
| 68 | `4.67` | `7000` | `1:7000` |

## Fix Implemented

The dynamic model builder now supports source-index aligned starts:

| File | Change |
| --- | --- |
| `tools/merge_reports/20260305_dynamic_dgp_model_helpers.R` | Added `dynamic_dgp_propagate_model_m0()` and `start_index` support in `build_dynamic_dgp_matched_model()`. The model prior mean is propagated to the state immediately before the first retained source observation. |
| `tools/merge_reports/LOCAL_refreshed288_run_row_20260422_p90_full288.R` | Reads the first `t` value from the dynamic `series_wide.csv` and passes it as `source_index_start` into the dynamic model builder. |
| `tools/merge_reports/LOCAL_refreshed288_helpers_20260422_p90_full288.R` | Records `dynamic_model_time_origin=source_index` and `dynamic_model_time_origin_column=t` in regenerated configs for reproducibility. |
| `tools/merge_reports/LOCAL_refreshed288_verify_dynamic_time_origin_20260429.R` | Adds a reproducible time-origin verification report for all 18 dynamic source windows. |
| `tools/merge_reports/LOCAL_refreshed288_launch_20260429_dynamic72_qdesn_comparable_timeorigin_v2.sh` | Adds a localized v2 relaunch wrapper with conservative MCMC worker defaults. |
| `tests/testthat/test-dynamic-dgp-resume-rebuild.R` | Adds a unit test for source-index `m0` propagation and preservation of `C0`. |

The fix intentionally does not propagate `C0` from root index `1` to the late window. Propagating root uncertainty across thousands of unobserved trend transitions would explode the prior covariance and change the baseline statistical contract. The correction is limited to the deterministic DGP-matched mean state origin.

## Verification

| Check | Result |
| --- | --- |
| Q-DESN effective-tail window verification | `18/18 PASS`, max numeric difference `0` |
| Dynamic time-origin verification | `18/18 improved`, median first-signal abs error reduced from `29.0647` to `6.9011` |
| v2 manifest preparation | `288` total rows, `72` dynamic rows, `0` missing dataset inputs |
| v2 dynamic config metadata | `dynamic_model_time_origin=source_index`, `dynamic_model_time_origin_column=t` |

Time-origin verification artifacts:

| Artifact | Path |
| --- | --- |
| CSV | `reports/static_exal_tuning_20260429/refreshed288_dynamic72_time_origin_verification_20260429_p90_dynamic72_qdesn_comparable_v2_timeorigin.csv` |
| Markdown | `reports/static_exal_tuning_20260429/refreshed288_dynamic72_time_origin_verification_20260429_p90_dynamic72_qdesn_comparable_v2_timeorigin.md` |

## Solution Options Considered

| Option | Decision | Reason |
| --- | --- | --- |
| Add stronger exDQLM sigma/gamma warmups immediately | Rejected for baseline v2 | The evidence shows DQLM and VB fit quality were also poor, so this would treat a symptom first. |
| Use the full 7000-root dynamic data again | Rejected | It reproduces older good metrics but violates the Q-DESN-comparable effective-window fairness rule. |
| Give DQLM/exDQLM the Q-DESN washout prefix | Rejected | Q-DESN needs washout/lags, but DQLM/exDQLM should fit only the effective `500`/`5000` observations. |
| Align the dynamic model prior mean to the canonical source index | Chosen | It preserves the tail-window fairness rule while removing the incorrect local-origin restart. |

## Localized Relaunch Recommendation

Use the v2 wrapper, not the v1 wrapper:

```bash
tools/merge_reports/LOCAL_refreshed288_launch_20260429_dynamic72_qdesn_comparable_timeorigin_v2.sh smoke
```

If v2 smoke passes, proceed to dynamic-only full:

```bash
tools/merge_reports/LOCAL_refreshed288_launch_20260429_dynamic72_qdesn_comparable_timeorigin_v2.sh full
```

If row `44` or another exDQLM row still fails after source-origin alignment, create a separate documented repair overlay. Do not silently strengthen theta/latent/precision controls in the baseline v2 run.

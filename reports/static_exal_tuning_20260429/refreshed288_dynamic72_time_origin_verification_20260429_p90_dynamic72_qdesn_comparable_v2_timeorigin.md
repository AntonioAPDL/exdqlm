# Dynamic Time-Origin Verification

- Generated: `2026-04-29 19:29:31 EDT`
- Run tag: `20260429_p90_dynamic72_qdesn_comparable_v2_timeorigin`
- Registry: `/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/LOCAL_refreshed288_dataset_registry_20260429_p90_dynamic72_qdesn_comparable_v1.csv`
- Overall status: `PASS`

## Purpose

This check verifies that canonical tail-window dynamic fits start the DQLM/exDQLM model at the same source time as the data window. It compares the first one-step model signal under the old local-origin convention (`start_index = 1`) against the source-index aligned convention (`start_index = first t in series_wide.csv`).

The fix does not add Q-DESN washout observations. It only aligns the model prior mean to the canonical source index of the existing `fit_input_lastTT500` or `fit_input_lastTT5000` window.

## Summary

| Check | Value |
| --- | ---: |
| Dynamic windows checked | 18 |
| Rows improved by source alignment | 18 |
| Median local-origin first-signal abs error | 29.0647 |
| Median source-aligned first-signal abs error | 6.9011 |
| Overall status | `PASS` |

## Row-Level Evidence

| Dataset | Source Start | q_true First | Local Signal | Aligned Signal | Local Abs Err | Aligned Abs Err | Status |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `dynamic::gausmix::0p05::500` | 6501 | 165.0551 | 69.9212 | 156.0620 | 95.1339 | 8.9931 | `pass` |
| `dynamic::gausmix::0p05::5000` | 2001 | 97.8711 | 69.9212 | 93.0620 | 27.9499 | 4.8091 | `pass` |
| `dynamic::gausmix::0p25::500` | 6501 | 165.0551 | 69.9212 | 156.0620 | 95.1339 | 8.9931 | `pass` |
| `dynamic::gausmix::0p25::5000` | 2001 | 97.8711 | 69.9212 | 93.0620 | 27.9499 | 4.8091 | `pass` |
| `dynamic::gausmix::0p50::500` | 6501 | 165.0551 | 69.9212 | 156.0620 | 95.1339 | 8.9931 | `pass` |
| `dynamic::gausmix::0p50::5000` | 2001 | 97.8711 | 69.9212 | 93.0620 | 27.9499 | 4.8091 | `pass` |
| `dynamic::laplace::0p05::500` | 6501 | 100.7111 | 70.5316 | 99.5038 | 30.1795 | 1.2073 | `pass` |
| `dynamic::laplace::0p05::5000` | 2001 | 51.3676 | 70.5316 | 50.0038 | 19.1640 | 1.3638 | `pass` |
| `dynamic::laplace::0p25::500` | 6501 | 100.7111 | 70.5316 | 99.5038 | 30.1795 | 1.2073 | `pass` |
| `dynamic::laplace::0p25::5000` | 2001 | 51.3676 | 70.5316 | 50.0038 | 19.1640 | 1.3638 | `pass` |
| `dynamic::laplace::0p50::500` | 6501 | 100.7111 | 70.5316 | 99.5038 | 30.1795 | 1.2073 | `pass` |
| `dynamic::laplace::0p50::5000` | 2001 | 51.3676 | 70.5316 | 50.0038 | 19.1640 | 1.3638 | `pass` |
| `dynamic::normal::0p05::500` | 6501 | 149.9948 | 67.7968 | 121.9080 | 82.1980 | 28.0868 | `pass` |
| `dynamic::normal::0p05::5000` | 2001 | 82.9863 | 67.7968 | 67.9080 | 15.1894 | 15.0782 | `pass` |
| `dynamic::normal::0p25::500` | 6501 | 149.9948 | 67.7968 | 121.9080 | 82.1980 | 28.0868 | `pass` |
| `dynamic::normal::0p25::5000` | 2001 | 82.9863 | 67.7968 | 67.9080 | 15.1894 | 15.0782 | `pass` |
| `dynamic::normal::0p50::500` | 6501 | 149.9948 | 67.7968 | 121.9080 | 82.1980 | 28.0868 | `pass` |
| `dynamic::normal::0p50::5000` | 2001 | 82.9863 | 67.7968 | 67.9080 | 15.1894 | 15.0782 | `pass` |

## Interpretation

The old local-origin convention is a poor match for late windows because it restarts the trend and seasonal state at the root initial state. The aligned convention propagates the DGP-matched prior mean to the state immediately before the first retained source observation, preserving the same tail-window observations and the same compact retention policy.

CSV details: `/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/reports/static_exal_tuning_20260429/refreshed288_dynamic72_time_origin_verification_20260429_p90_dynamic72_qdesn_comparable_v2_timeorigin.csv`

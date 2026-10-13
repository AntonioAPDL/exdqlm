# Independent Q-DESN Rolling-Readout v4 Closeout

## Decision

The campaign is complete with decision
`ROLLING_READOUT_SCREEN_GAIN_FAILED_DISJOINT_ORIGIN_VALIDATION`.
No article result is changed and no sealed source index in 9001--10000 was
opened.

The five-arm screen selected `rolling_1000`, which narrowly improved the
expanding-fixed anchor. On the disjoint validation origins, rolling N=1000 had
a median Q-DESN/exDQLM forecast-MAE ratio of 0.9666 but won 8 of 16 cells. It
therefore missed the predeclared 9-of-16 requirement by one cell, and no
additional chains were scheduled.

| Surface | Rolling N=1000 result |
|---|---:|
| Screen median Q-DESN/exDQLM MAE ratio | 1.0364 |
| Screen exDQLM wins | 6/12 |
| Expanding-fixed anchor ratio | 1.0406 |
| Validation median Q-DESN/exDQLM MAE ratio | 0.9666 |
| Validation exDQLM wins | 8/16 |
| Validation median rolling/static Q-DESN MAE ratio | 0.8902 |
| Validation static-Q-DESN wins | 11/16 |
| Validation median Q-DESN/exDQLM check-loss ratio | 1.0038 |
| Validation exDQLM check-loss wins | 7/16 |
| Worst validation Q-DESN/exDQLM MAE ratio | 1.5573 |

## Temporal diagnosis

The response is fold-dependent rather than horizon-offset-dependent. Every
offset wins exactly two of four folds against exDQLM. Median MAE ratios by fold
are 0.6645 (S1), 0.8583 (S2), 1.2916 (S3), and 1.0320 (S4). Rolling N=1000
therefore fixes stale-readout behavior relative to static Q-DESN but does not
provide a uniformly competitive readout across temporal regimes.

This evidence rejects two inefficient next steps: another broad static DESN
screen and a denser search over fixed window lengths. The next justified model
change is an explicit time-varying or discounted readout, developed on internal
origins and compared with the frozen rolling N=1000 and exDQLM controls. The
sealed article window must remain untouched until that protocol is frozen.

## Execution and recovery

The initial production run completed 60/60 screen fits with zero failures. Its
transition stopped before ranking because imported and new summaries had
different metadata columns. The recovery campaign verified the original
source against Git commit `68a3c0ce`, verified all configurations, statuses,
evidence manifests, package files, and frozen inputs, imported all 60 screen
fits, and reran zero models. The repaired source is commit `bfad58f6`.

The recovery then completed 16/16 disjoint-origin validation fits. Across the
76 new scientific fits, all used exact M0
`m0_v_collapsed_support_logit`, all first-step guards passed, outputs were
finite, and no fitted-model binary payloads were retained. Validation gamma ESS
ranged from 75.97 upward with median 102.74; these diagnostics are disclosed
but were not used as predictive vetoes.

## Evidence

Superseded screen run, retained because the recovery manifests depend on it:

`validation/fitforecast_v2/local_trackers/independent_qdesn_rolling_readout_v4_20261009_045722__git-68a3c0ce`

Authoritative recovery and closeout:

`validation/fitforecast_v2/local_trackers/independent_qdesn_rolling_readout_v4_recovery_v1_20261009_052805__git-bfad58f6`

The authoritative closeout manifest, imported-screen manifest, stage-plan
hashes, cell-level comparisons, ranks, and diagnostic summaries all verify.

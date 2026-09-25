# Independent Q-DESN mean-readout-state v1 supersession

Status: `SUPERSEDED_BY_REDESIGNED_INDEPENDENT_PROTOCOL`

## Decision

The mean-readout-state v1 campaign is an incomplete diagnostic campaign and is
not an article-authoritative validation result. Its previous model contract
retains direct lagged responses and deterministic regressors in the readout,
whereas the redesigned independent evaluation requires a readout containing
only an intercept and reservoir states. Completing the old campaign would not
answer the redesigned scientific question.

No current-task process or tmux session remained at closeout. The campaign had
already stopped after an authority-compatibility failure, so no process was
killed or interrupted to apply this decision.

## Frozen state

The final health snapshot records:

| Stage | Successful | Failed | Incomplete |
|---|---:|---:|---:|
| Fit | 74 | 1 | 21 |
| Forecast | 26 | 0 | 20 |
| Total | 100 | 1 | 41 |

All 18 canary jobs completed. The failed fit was
`fit__imi_v1_source_087__c01`; it was rejected by the frozen-authority
compatibility contract. No partial metric, ranking, table, or figure is
eligible for article promotion.

The ignored runtime closeout is stored under:

```text
reports/shared_fitforecast_v2_orchestration/
  independent_mean_readout_state_forecast_v1_20260924_145807/
  closeout/superseded_protocol_v1
```

It contains the final job ledger, a SHA-256 manifest of retained partial
evidence, a machine-readable supersession summary, and a closeout hash ledger.
The original artifacts are retained in place; none were deleted.

## Retained implementation

The following infrastructure remains scientifically useful:

- native posterior-path recursive forecasting;
- mean-readout-state recursive forecasting;
- paired innovation support for estimator comparisons;
- state/readout dispersion exports;
- focused package and validation tests; and
- health, provenance, and artifact-manifest tooling.

These components may be ported to the redesigned protocol after review. The
old campaign configuration, candidate identities, and partial outcomes must
not be ported as scientific authority.

## Publication boundary

- Article metrics promoted: no.
- Article prose, figures, or tables changed: no.
- Shared-validation branch changed by this closeout: no.
- Article-v2 or Overleaf changed: no.
- Resumption permitted: no; a new dedicated protocol and branch are required.

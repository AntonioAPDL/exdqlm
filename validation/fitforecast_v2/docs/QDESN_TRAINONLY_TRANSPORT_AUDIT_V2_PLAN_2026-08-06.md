# Q-DESN Train-Only Transport Audit v2

## Objective

Determine whether the failed AL confirmation can be explained and repaired by a
train-only transport mechanism, and determine whether package 1.0.0 exposes a valid
fixed-parameter Q-DESN exAL diagnostic. This stage does not authorize article updates
or another broad parameter screen.

## AL audit

Every completed AL root is reconstructed from its exact `fit_request.json`, source CSV,
training-only scaling window, reservoir seed, decomposition configuration, and readout
contract. The audit records rank, condition number, feature correlation, standardized
train-to-forecast centroid and scale shifts, and reservoir saturation.

The retained fitted and rolling-origin paths are then evaluated under a deterministic
quantile-intercept correction. For a trailing training window of 90, 180, 360, or 500
effective observations, the shift is the empirical target quantile of `y - qhat`. No
forecast observations or oracle quantiles enter this correction. The uncorrected path is
retained as window zero.

An arm/window can proceed only if, against its paired parent under the same correction,
it achieves on both the frozen article and untouched confirmation sources:

- median forecast-MAE ratio at most 0.95;
- median fit-RMSE and forecast-check ratios at most 1.05;
- worst-seed forecast-MAE ratio at most 1.10.

## exAL audit

`exdqlmMCMC()` exposes `fix.gamma` and `fix.sigma`. The Q-DESN readout uses
`exal_mcmc_fit()`, whose package-1.0.0 API exposes neither fixed exAL gamma nor fixed
sigma; `al_fixed_gamma` is the AL special case and is not an exAL conditioning control.
The validation harness must not misrepresent exDQLM controls as Q-DESN capabilities.

## Decision outcomes

- `PREPARE_LEVEL_CALIBRATION_SMOKE`: a transferable AL arm/window passed all gates;
- `STOP_NO_TRANSFERABLE_MECHANISM`: no AL correction transferred and Q-DESN exAL has
  no supported fixed-parameter diagnostic. No model compute is launched.

## Reproduction

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  validation/fitforecast_v2/scripts/audit_qdesn_trainonly_transport_v2.R \
  --state-root reports/shared_fitforecast_v2_orchestration/qdesn_trainonly_followup_v1_20260805_205744 \
  --output-root validation/fitforecast_v2/promotions/qdesn_500obs_trainonly_transport_audit_v2_20260806
```

## Implemented closeout

The audit completed on 2026-08-06 with decision
`STOP_NO_TRANSFERABLE_MECHANISM`. It reconstructed all 18 AL designs and scored 90
train-only calibration evaluations (18 roots times five windows). No candidate passed
the two-source gate, so no fit, smoke, or article update was launched.

The uncorrected compact raw and compact state/residual designs improve median forecast
MAE on the untouched confirmation source (ratios 0.978 and 0.944, respectively), but
worsen it on the frozen article source (ratios 1.092 and 1.159). Trailing-window
intercept correction does not repair this contradiction. The best frozen-source
corrected ratio is 1.072, while the best untouched-source corrected ratio is 0.940;
no common arm/window improves both sources.

The deterministic reconstruction also identifies a concrete instability mechanism.
The compact raw designs have median condition numbers of 608 and 390 across the two
sources, while compact state/residual designs have condition numbers of 8,015 and
10,147. Their maximum absolute feature correlations range from 0.997 to 0.999. The
paired parent designs are much better conditioned (3.66 and 3.80) with maximum
absolute correlations of 0.671 and 0.717. This supports stopping the current transport
hypothesis rather than extending its parameter screen.

Authoritative evidence is stored at:

```text
validation/fitforecast_v2/promotions/qdesn_500obs_trainonly_transport_audit_v2_20260806/
```

The evidence directory contains the gate, exact per-root design diagnostics,
calibration paths and paired ratios, capability audit, empty candidate manifest, and a
SHA-256 file manifest. It contains no `.rds`, `.rda`, or `.RData` payloads.

Top-level evidence hashes are:

```text
transport_gate.json                 a395cab1bec0fb5e9b0a13588d2b1c8c874d72a86d2ac2ab2194c44404d34156
file_manifest.csv                   1f397351386a94c54e4d1c46e5b11e74df025f616a7e09889590cd8bd8c8281b
design_transport_summary.csv        08834ae17f3283563b890145ce5fe2b917b5741293ebce8bb3ec45ad309b3ef4
intercept_calibration_summary.csv   dbc56ee38f13db36bfa08a7a028909ebd3071691fd7babd68e714e5015279ebe
```

## Verification results

- Focused transport-audit tests: 8 expectations passed under R 4.6.0.
- Complete `validation/fitforecast_v2/tests/testthat` suite: passed under R 4.6.0,
  including all four deferred expressions.
- Promotion manifest: all recorded SHA-256 hashes verified.
- Active stale legacy home-root references in this stage: none.
- Heavy artifacts in this promotion: none.

The test commands were:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript -e \
  'source("validation/fitforecast_v2/R/utils.R"); \
   ffv2_source_all("validation/fitforecast_v2"); \
   testthat::test_file("validation/fitforecast_v2/tests/testthat/test-qdesn-trainonly-transport-audit-v2.R", reporter="stop")'

/data/jaguir26/local/opt/R/4.6.0/bin/Rscript -e \
  'suppressPackageStartupMessages(library(testthat)); \
   testthat::test_dir("validation/fitforecast_v2/tests/testthat", reporter="stop")'
```

The next scientifically valid step requires either a new, predeclared transport/model
hypothesis or an explicit package API change for a Q-DESN exAL fixed-parameter
diagnostic. Neither is authorized by this closeout.

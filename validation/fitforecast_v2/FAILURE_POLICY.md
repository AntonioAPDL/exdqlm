# Failure Policy

The first authoritative fit + forecast run is a measurement campaign, not a
repair campaign. Runtime and data-contract failures are blockers. Model-quality
diagnostics are retained as scientific evidence.

## Hard Stop

Stop before the next stage if any of these occur:

- shared source hash mismatch
- wrong source-index window
- stale `/home/jaguir26/local/src` path in an active manifest
- runtime crash
- non-finite required fitted or forecast values
- missing compact row artifact
- forbidden binary payload retained after a successful row
- stage filtering selects the wrong method or fit size
- Q-DESN launcher is invoked for real compute without
  `QDESN_FFV2_LAUNCH_APPROVED=true`
- Q-DESN `mcmc_tt5000` or `full` is invoked without the additional
  `QDESN_FFV2_TT5000_APPROVED=true`
- article-facing interface is missing source hash, forecast-origin/window,
  H=100, or H=1000 fields

## Preserve As Completed Diagnostic Result

Do not automatically repair or rerun only because of:

- MCMC mixing warning
- health gate `WARN`
- health gate `FAIL` caused by model behavior rather than runtime error
- wide intervals
- high quantile error
- poor calibration

The comparison table should carry the status and diagnostic grade.

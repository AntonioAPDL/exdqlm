# Independent mean-readout-state forecast campaign

This directory freezes the execution contract for the independent Q-DESN
forecast-estimator replay. The materializer resolves the exact historical
winner requests, stages immutable source data by SHA-256, and writes the full
96-fit and 46-forecast runtime plans under the ignored campaign report root.

The scientific contract is defined in
`validation/fitforecast_v2/docs/INDEPENDENT_QDESN_MEAN_READOUT_STATE_FORECAST_V3_IMPLEMENTATION_BLUEPRINT_2026-09-24.md`.
Runtime outputs are intentionally excluded from Git. Article integration and
publication remain the responsibility of the integration lane.

The materializer first stages all 96 retained historical native score-draw
files behind SHA-256 hashes. Each fit reconstruction then runs the native R
recursion once, writes compact native score/path evidence, and must reproduce
the staged forecast-MAE and check-loss summaries within `1e-6`. Forecast workers
verify the newly reconstructed artifacts by hash and independently recompute
their summaries; they do not repeat the same expensive native recursion. The
paired mean-readout-state candidate uses the exact exported posterior and
feature-basis capsules, deterministic R-generated innovations, and the isolated
streaming R implementation.

Innovation replay preserves the native split RNG contract: complete 30-step
origin blocks use the frozen forecast seed, while the truncated tail block uses
seed plus 31. If chain balancing selects a posterior subset, the full native RNG
stream is generated before the matching draw columns are selected. This keeps
the comparison paired without changing the scientific contract.

Reconstruction uses pipeline forecast mode `mixture`. That mode builds the same
rolling-origin lattice, tail coverage, metric draws, and compact 1,000-target
path consumed by this campaign. It deliberately skips the pipeline's separate
1,000-origin lead-one pass, which is used by other report surfaces but does not
enter this experiment. The full-source canary must reproduce the retained
native score/path contract within `1e-6` before the remaining jobs are released.

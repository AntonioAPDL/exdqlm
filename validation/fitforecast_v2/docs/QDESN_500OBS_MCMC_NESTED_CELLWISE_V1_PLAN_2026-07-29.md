# Q-DESN 500-Observation Nested Cellwise MCMC Calibration v1

- Stage base: `qdesn_dynamic_fitforecast_v2_500obs_mcmc_nested_cellwise_v1`
- Source registry SHA-256: `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`
- Scope: independent Q-DESN/exQ-DESN RHS validation only.
- Calibration unit: model variant x family x quantile x likelihood.
- Article policy: no raw discovery result is article-facing.

## Design

- 15 unresolved cells.
- 12 cell-specific designs per cell: 2 declared anchors and 10 novel compact designs.
- 2 reservoir-topology seeds per design.
- 2 MCMC seed replicates per root.
- The unmodified 1.0.0 multiseed adapter changes DESN and MCMC RNG seeds together; these are coupled stochastic replicates, not a factorial variance decomposition.
- Calibration origins 7000 and 8000; final origin 9000 is excluded from discovery.
- MCMC budget: 2,000 burn-in plus 8,000 retained iterations.
- Full planned discovery workload: 720 roots and 1,440 chain fits.

## Automatic gates

1. Frozen source hash and source-window verification.
2. Target-aware exact-repeat audit; repeats allowed only for declared anchors.
3. Prepare-only manifests for both calibration origins.
4. One-root smoke for each calibration origin.
5. Detached full launches with a combined outer-worker cap of 16.
6. Closeout must aggregate both origins and all seed replicates.
7. Final-origin confirmation is a separate, gated stage.

## Promotion

- Discovery candidates are compared with declared anchors rerun on the same calibration views.
- Final-origin parent metrics are provenance context, not discovery-stage denominators.
- Fit RMSE requires at least 3% replicated improvement.
- Forecast MAE requires at least 5% replicated improvement.
- Check loss requires at least 1% replicated improvement.
- Metric-wise envelopes remain diagnostic.
- Article rows require one coherent confirmed specification.

## Storage

- Keep scalar metrics, compact paths, manifests, logs, status, and seed summaries.
- Do not retain routine successful `.rds`, `.rda`, or `.RData` payloads.

## Commands

```bash
Rscript validation/fitforecast_v2/scripts/materialize_qdesn_mcmc_nested_cellwise_v1_20260729.R --workers 16
Rscript scripts/orchestrate_qdesn_500obs_mcmc_nested_cellwise_v1.R --prepare-only --smoke --skip-materialize --workers 16
Rscript scripts/orchestrate_qdesn_500obs_mcmc_nested_cellwise_v1.R --full --launch-approved --skip-materialize --skip-prepare --skip-smoke --workers 16
```

After both full campaigns are terminal, run the closeout with their exact run tags:

```bash
Rscript scripts/closeout_qdesn_500obs_mcmc_nested_cellwise_v1.R \
  --origin7000-run-tag <origin7000-run-tag> \
  --origin8000-run-tag <origin8000-run-tag>
```

# Q-DESN Nested Cellwise Final-Origin Confirmation v1

## Scope

- Independent Q-DESN and exQ-DESN validation only.
- exdqlm package baseline: 1.0.0.
- Source-registry SHA-256:
  `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`.
- Discovery evidence: origins 7000 and 8000.
- Frozen confirmation origin: 9000.
- Article updates are manual and require a completed confirmation closeout.

## Decision

The replicated discovery closeout selected four cell-specific designs. Three
improved their primary metric direction at both calibration origins without a
material regression. The Q-DESN AL Gaussian-mixture median design passed the
pooled gate but regressed at origin 7000, so it is retained as an instability
sentinel rather than a primary candidate.

## Confirmation Contract

- Training source indices: 8501--9000.
- Forecast source indices: 9001--10000.
- Rolling-origin maximum lead: 30.
- Rolling-origin stride: 30.
- No refitting across forecast origins.
- Four cells and two frozen reservoir seeds per cell: eight roots.
- Two coupled MCMC/DESN seed replicates per root: sixteen chain fits.
- Full budget: 5,000 burn-in and 20,000 retained MCMC iterations.
- Posterior metric draws: 200.
- Eight outer workers, one thread per worker, sequential seed replicates.

## Gates

1. All eight roots and all sixteen seed fits must reach a terminal state.
2. Source hashes, source windows, profile identities, and atomic specs must
   match the materialized contract.
3. Every fit, forecast-MAE, and check-loss metric must be finite.
4. Full-confirmation metrics must remain within 10% of discovery medians.
5. A coherent candidate may not regress any current parent-envelope metric by
   more than 5%.
6. The cell's primary metric must improve under its predeclared threshold.
7. Competitiveness against matched DQLM/exDQLM metrics is reported explicitly.
8. Chain diagnostics remain visible but do not silently suppress finite metric
   evidence.
9. No routine successful `.rds`, `.rda`, or `.RData` payload is retained.

## Stages

```bash
Rscript scripts/orchestrate_qdesn_500obs_mcmc_nested_final_origin_v1.R \
  --prepare-only

Rscript scripts/orchestrate_qdesn_500obs_mcmc_nested_final_origin_v1.R \
  --smoke --skip-materialize

Rscript scripts/orchestrate_qdesn_500obs_mcmc_nested_final_origin_v1.R \
  --full --launch-approved --skip-materialize --skip-prepare --skip-smoke
```

After the detached campaign becomes terminal:

```bash
Rscript scripts/closeout_qdesn_500obs_mcmc_nested_final_origin_v1.R \
  --run-tag <exact-run-tag>
```

No article value may change before this closeout is complete and reviewed.

## Prelaunch Evidence

The implementation was validated under R 4.6.0 on 2026-07-30.

- Targeted design test:
  `test-qdesn-mcmc-nested-final-origin-v1.R` passed.
- Regression test:
  `test-qdesn-mcmc-nested-cellwise-v1-design.R` passed.
- Full `validation/fitforecast_v2/tests/testthat` suite:
  passed, including all four deferred expressions.
- Prepare-only run tag:
  `qdesn-500obs-mcmc-nested-final-o9000-v1-prepare-20260730-160532__git-d705f8b`.
- Smoke run tag:
  `qdesn-500obs-mcmc-nested-final-o9000-v1-smoke-20260730-160604__git-d705f8b`.
- Smoke execution:
  one root, two MCMC seed replicates, root status `SUCCESS`.
- Smoke storage audit:
  zero retained `.rds`, `.rda`, `.RData`, or `__design.rds` payloads.

The smoke uses four burn-in and four retained iterations solely to exercise the
workflow. Its chain grade is not scientific evidence and cannot be promoted.

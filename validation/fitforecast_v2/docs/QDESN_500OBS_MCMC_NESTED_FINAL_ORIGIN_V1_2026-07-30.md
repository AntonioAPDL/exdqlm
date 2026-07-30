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
  `qdesn-500obs-mcmc-nested-final-o9000-v1-prepare-20260730-162948__git-6582f87`.
- Smoke run tag:
  `qdesn-500obs-mcmc-nested-final-o9000-v1-smoke-20260730-162708__git-6582f87`.
- Smoke execution:
  one root, two MCMC seed replicates, root status `SUCCESS`.
- Effective per-fit smoke budget:
  four burn-in, four retained iterations, and four predictive draws.
- Effective full preflight budget:
  5,000 burn-in, 20,000 retained iterations, and 200 predictive draws.
- Smoke storage audit:
  zero retained `.rds`, `.rda`, `.RData`, or `__design.rds` payloads.

The smoke uses four burn-in and four retained iterations solely to exercise the
workflow. Its chain grade is not scientific evidence and cannot be promoted.

## Invalidated Launch

The first full launch,
`qdesn-500obs-mcmc-nested-final-o9000-v1-full-20260730__git-6582f87`,
was stopped and marked `ABORTED_INVALID_CONTRACT`. Its per-fit requests used
100 posterior predictive draws because the exdqlm 1.0.0 shared adapter applies
the historically named `vb_sampling_nd_draws` field to MCMC as well. No output
from that run is consumable.

The materializer now sets all three draw controls to 200 for the full campaign
and to four for smoke. The orchestrator also reads both smoke `fit_request.json`
files and refuses continuation unless the effective per-fit budget is exactly
four and no model payload remains.

## Final Execution

The corrected full campaign completed on 2026-07-30 with run tag
`qdesn-500obs-mcmc-nested-final-o9000-v1-full-20260730__git-bd4da62`.
The child pipeline uses `pkgload::load_all(repo_root)`, so model code was loaded
from this exact worktree. Its `DESCRIPTION` records exdqlm 1.0.0; the closeout
hashes both `DESCRIPTION` and `scripts/pipeline_real_main.R`.

- Terminal successful roots: 8/8.
- Complete MCMC seed fits: 16/16.
- Complete replicated cells: 4/4.
- Q-DESN AL diagnostics: all six roots were `PASS` or `WARN`.
- exQ-DESN exAL diagnostics: both roots were `FAIL`, with finite metrics
  retained and reported under the non-suppressing diagnostic policy.
- Retained `.rds`, `.rda`, `.RData`, or `__design.rds` files: zero.

The authoritative closeout is:

```text
validation/fitforecast_v2/promotions/
  qdesn_500obs_mcmc_nested_final_origin9000_v1_closeout_20260730/
```

Its manifest is
`qdesn_500obs_mcmc_nested_final_origin9000_v1_closeout_20260730_manifest.json`,
and its readable decision record is `decision_report.md`.

## Final Results

| Model | Family | Tau | Fit RMSE | Forecast MAE H=1000 | Forecast check loss H=1000 | Fit/parent | MAE/parent | Check/parent |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| Q-DESN AL RHS | Gaussian mixture | 0.50 | 1.2996 | 2.7829 | 5.6724 | 1.057 | 1.010 | 1.007 |
| Q-DESN AL RHS | Laplace | 0.05 | 5.3978 | 4.8785 | 1.9069 | 1.014 | 1.037 | 1.010 |
| Q-DESN AL RHS | Gaussian | 0.05 | 2.8536 | 8.8692 | 1.2854 | 1.005 | 1.186 | 1.052 |
| exQ-DESN exAL RHS | Gaussian | 0.25 | 1.8378 | 3.7485 | 3.4341 | 1.045 | 1.202 | 1.020 |

Ratios below one improve on the current article-facing parent metric. Each
cell has four tightly replicated finite metric rows, but none improves even one
of the three parent metrics. Zero cells pass the frozen coherent-promotion
gate, zero cells are jointly competitive with the matched DQLM/exDQLM
envelope, and zero metric rows qualify for article refresh.

## Scientific Decision

The final decision is `NO_CONFIRMED_COHERENT_ARTICLE_REFRESH`. The apparent
gains at discovery origins 7000 and 8000 did not transfer to the frozen origin
9000. This is a genuine source-window transfer failure, not missing output or
Monte Carlo noise. The current article-facing parent rows remain authoritative,
and the authoritative article repository must not be changed from this
negative confirmation result.

Origin 9000 has now been evaluated. It must not be reused as an untouched
confirmation origin or become a new tuning target.

## Next Safe Scientific Step

1. Run a no-new-fit diagnostic of source-window and DGP heterogeneity across
   the discovery and confirmation windows.
2. Replace pooled two-origin candidate selection with a predeclared robust
   multi-origin rule that penalizes worst-origin regression.
3. Use VB or already-computed summaries for candidate triage where appropriate,
   but preserve MCMC confirmation because VB performance is not assumed to
   rank MCMC performance perfectly.
4. Reserve a fresh simulation replicate or source seed as the next untouched
   final confirmation sample.
5. Launch no additional MCMC screen until that protocol, its selection gates,
   and its new holdout are frozen and tested.

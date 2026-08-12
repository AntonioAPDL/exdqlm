# Independent Q-DESN lower-tail cellwise MCMC v1

Date: 2026-08-11

## Scope and authority

This protocol belongs only to the independent single-quantile Q-DESN/exQ-DESN
and DQLM/exDQLM simulation validation. It excludes joint-QDESN, PriceFM,
GloFAS, and all application campaigns.

The immutable article authority is promotion v6 at validation commit
`5a4e6ed210bd113d2d0459c6f6b47cde6439ffcb`. The source registry identity is
`edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`, and the
package baseline is exdqlm 1.0.0. Screening evidence cannot modify the article.

## Diagnosis

The remaining objective is not a global Q-DESN specification. It is a separate
calibration problem for every likelihood, family, quantile, and metric. Earlier
work already covered depth 1--4, large state spaces, input memory through 150,
alpha through 0.999, high rho, active recurrence, and RHS scales spanning
several orders of magnitude. Another Cartesian range expansion would repeat
failed work.

Fit rankings have transferred reasonably across development origins, while
forecast rankings have not. Candidate selection therefore uses genuine MCMC,
paired source blocks, fixed reservoir panels, and an untouched canonical-source
confirmation. VB may initialize MCMC but is never the promotion estimator.

## Targets

Tier A contains six immediate targets:

1. Q-DESN AL, Gaussian, p=0.05: fit RMSE, forecast MAE, and check loss.
2. exQ-DESN exAL, Laplace, p=0.05: fit RMSE.
3. exQ-DESN exAL, Gaussian mixture, p=0.25: forecast MAE.
4. exQ-DESN exAL, Gaussian mixture, p=0.05: fit RMSE.
5. exQ-DESN exAL, Gaussian, p=0.05: fit RMSE.
6. exQ-DESN exAL, Gaussian, p=0.25: forecast MAE.

Tier B contains the four AL fit-RMSE targets for Laplace and Gaussian mixture at
p=0.05 and p=0.25. Tier B cannot launch before Tier A closes. Median cells are
outside this campaign.

## Candidate contract

Each cell has its exact v6 metric parent plus eight new profiles:

- two local RHS-scale perturbations;
- one local readout-memory perturbation;
- one local input-memory perturbation;
- two active-recurrence multiscale mechanisms;
- two deterministic maximin designs from previously untried profile space.

The last two arms include high-alpha and capacity boundaries, but only as new
effective profile fingerprints. Every profile is checked against the complete
historical profile-signature ledger. Effective readout dimension is capped at
900 columns. Source, reservoir, and MCMC seeds are separate and predeclared.

## Stages

| Stage | Evidence | Maximum roots | Budget |
|---|---|---:|---:|
| Smoke | one AL and one exAL path | 2 | 4 + 4 |
| Runtime calibration | one representative root per Tier-A cell | 6 | 200 + 500 |
| Tier-A discovery | 8 candidates + parent, 6 cells, 2 sources | 108 | 1,000 + 3,000 |
| Tier-A replication | 3 candidates + parent, 6 cells, 1 new source | 24 | 1,000 + 3,000 |
| Tier-A sealed | 2 candidates + parent, 6 cells, 4 sealed sources | 72 | 1,000 + 3,000 |
| Canonical confirmation | one candidate per eligible metric, 3 chains | at most 24 | 5,000 + 20,000 |

Discovery ranks every declared target metric. A multi-metric cell advances the
union of its metric leaders, then fills remaining slots by robust worst-ratio
score. Mean and median paired improvements are reported separately.

## Promotion and stopping rules

A metric may be promoted for any strictly positive confirmed gain when all
three full-budget chains are finite and both their mean and median beat v6.
Diagnostic grades are reported but are not metric vetoes. Implementation
failure, nonfinite evidence, contract mismatch, provenance failure, or retained
forbidden payloads are hard vetoes.

The article continues to expose its metric-source envelope and must also retain
`metric_source_mixed`. A separate coherent-cell audit records the performance
of one specification on all three metrics. Posterior output is never recycled
into an undisclosed prior; warm starts may initialize a chain without changing
its posterior target.

If no candidate survives replication and sealed evaluation for a cell, that
cell closes as a negative result. Repeated canonical transfer failure closes
the search rather than triggering another nominally broader grid.

## Execution and storage

Each fit uses one operating-system thread. The launcher may use at most 20
dynamically selected idle CPUs and waits rather than oversubscribing the host.
Progress is emitted every 50 MCMC iterations; resource heartbeat and stale
evidence are recorded every 30 minutes.

Successful jobs retain scalar fit and forecast metrics, compact rolling paths,
status, logs, configuration, and hashes. Routine `.rds`, `.rda`, and `.RData`
fit payloads are deleted immediately under the declared storage policy. Every
stage is resumable by run tag and configuration hash.

## Prelaunch qualification

The deterministic materialization contains 10 targets, 10 exact v6 parent
controls, 80 new candidates, and 9,268 excluded historical signatures. The
candidate ledger has no historical overlap. It spans depth 1--4, input memory
1--150, alpha 0.00075--0.999, rho 0.10--0.995, RHS scales approximately
`1e-8`--`1e-3`, and effective readout dimension 11--898. The seven development
source blocks use 42 distinct latent/noise seeds. Their materialized registry
SHA-256 is
`db1323f4d9a4b3d5a93c08e675e39f8a5320cf7bf2ed1c03e4f0f2210fdb9411`;
this registry is development evidence and does not replace the canonical
article source identity stated above.

The prelaunch smoke run tag is `qdesn-ltcv1-precommit-smoke-20260811`. Its AL
and explicit exAL-M0 roots both completed, emitted finite fit and rolling-origin
forecast metrics, passed all 19 runtime checks, and retained no `.rds`, `.rda`,
or `.RData` payload. The focused campaign tests and the inherited M0 dispatch,
rolling-grid/state, source registry/window, artifact, storage, stage-filtering,
and shared-interface suites passed under R 4.6.0.

The repository-wide 160-file test directory was also executed. It is not green
at the immutable base: legacy synthesized-benchmark and VB simplification-ladder
tests fail in the current host environment, and several historical-result tests
warn or skip when their old local artifacts are absent. The two failing test
files were rerun without modification in the clean base worktree at
`5a4e6ed210bd113d2d0459c6f6b47cde6439ffcb` and reproduced the same failures.
They are therefore recorded as inherited baseline debt, not waived campaign
regressions. The new campaign, its inherited inference path, and its actual AL
and exAL-M0 smoke roots remain fully green.

## Operator workflow

Launch only from the clean, synchronized campaign branch:

```bash
WORKERS=20 \
  validation/fitforecast_v2/scripts/launch_qdesn_lower_tail_cellwise_mcmc_v1.sh
```

The launcher records its tmux session, run ID, run tag, state root, and stdout
log. It waits for the resource gate, dynamically pins one thread per worker to
20 idle CPUs, runs smoke, runtime calibration, and Tier-A discovery in order,
then materializes the 24-root replication plan and stops. It does not launch
replication, sealed evaluation, canonical confirmation, Tier B, or article
promotion automatically.

For a live stage, use the run tag and plan recorded under the state root:

```bash
Rscript validation/fitforecast_v2/scripts/healthcheck_qdesn_lower_tail_cellwise_mcmc_v1.R \
  --run-tag RUN_TAG \
  --plan PLAN.csv \
  --output HEALTH.csv
```

Relaunching the pipeline with the same run ID and run tag is the supported
resume path: completed roots with matching configuration hashes are skipped.

# Q-DESN Train-Only Follow-up v1

## Decision

The completed 90-root mechanism screen is frozen as discovery evidence. This
follow-up contains two separate experiments and cannot directly update the
article.

1. Confirm the two promising AL/Normal/0.05 mechanisms at the full MCMC budget
   on the frozen article source and one untouched source.
2. Diagnose the exAL/Gaussian-mixture/0.25 gamma--sigma sampler geometry while
   holding the DESN, RHS prior, source set, and MCMC draw budget fixed.

The `exdqlm` package remains version 1.0.0 and is not modified by this campaign.

## Frozen Inputs

- Discovery commit: `39037ee90f4ee68c2254b1f396079deba74eff96`.
- Discovery run: `qdesn_trainonly_mechanism_v1_20260805_160823`.
- Canonical source-registry identity: `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`.
- Development source-registry SHA-256: `af83f8704ca330a7d0fb7296c2cd8c4f9bf42b09c79851e2c75303de88a8b1e9`.
- Train window: source indices 8501--9000.
- Forecast block: source indices 9001--10000.
- Rolling forecast: maximum lead 30, origin stride 30, no refit per origin.

## Experiment A: AL Confirmation

Cell: Normal, tau 0.05, Q-DESN AL--RHS. The exact parent,
`compact_raw`, and `compact_state_resid` are run with three predeclared
reservoir seeds on each of two sources. The first source is the frozen article
trajectory; `dev04` is untouched by discovery. Each root uses 5,000 burn-in
iterations and 20,000 retained iterations, initialized once by VB.

Promotion requires complete finite metrics and hashes, at least 5% lower
forecast MAE overall and on the frozen source, no more than 5% degradation in
fit RMSE or forecast check loss, and a worst paired q90 ratio no larger than
1.10. Status and diagnostics are always retained. No article change is made
unless this gate passes.

## Experiment B: exAL Sampler Geometry

Cell: Gaussian mixture, tau 0.25, Q-DESN exAL--RHS. The exact current parent
DESN and `tau0 = 3e-4` are frozen. Three sampler arms use the same three
development sources and two reservoir seeds:

- `gsg_matched`: gamma--sigma--gamma ordering with matched widths;
- `gsg_dense`: wider gamma, narrower sigma, and four extra core passes;
- `gsg_multistart`: the dense geometry plus four deterministic pilot starts.

All arms use 1,000 burn-in and 3,000 retained iterations. Selection is based
first on gamma/sigma ESS per second and lag-1 autocorrelation, then on metric
stability. Metric improvement alone cannot promote this diagnostic to the
article. Any selected geometry must pass a later full-budget confirmation.

## Structured Comparators

The existing c13 DQLM and exDQLM specification is rerun for Normal/0.05 on the
same two confirmation sources. These four roots use 5,000 burn-in and 20,000
retained iterations and are supporting comparators, not a new calibration.

## Storage and Failure Policy

Successful roots retain scalar fit metrics, lead-level forecast metrics,
compact path summaries, logs, manifests, status, progress, and hashes. Routine
successful `.rds`, `.rda`, and `.RData` model payloads are forbidden. Failures
remain explicit; finite metrics are never silently discarded, and diagnostic
status is never converted into success.

## Stages

`contract -> source materialization/verification -> prepare-only -> smoke ->
resource gate -> parallel experiments -> storage audit -> closeout`

The 18 AL confirmation roots are executed in four source-valid bundles:
`al_raw` and `al_sr` use only the frozen article source, while
`al_raw_dev04` and `al_sr_dev04` use only the untouched confirmation source.
This split is operational rather than scientific. The validation runner rebuilds
each canonical grid from one dynamic source root before accepting a checked-in
grid, so combining the two source roots in one bundle would violate its
provenance contract. Pairing and final selection still aggregate all six paired
replicates per candidate arm.

The launcher requires a clean branch exactly synchronized with its Git
upstream. It never updates the article and never launches any 5,000-observation
stage.

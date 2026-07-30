# Q-DESN 500-Observation MCMC Remaining-Objective Audit

## Purpose

This audit fixes the scientific target before any topology/transport redesign is
implemented. It covers only the independent single-quantile validation study:

- Q-DESN with the AL working likelihood and regularized horseshoe prior;
- exQ-DESN with the exAL working likelihood and regularized horseshoe prior;
- matched DQLM and exDQLM MCMC comparators;
- Gaussian, Laplace, and Gaussian-mixture innovations;
- target levels 0.05, 0.25, and 0.50;
- the 500-observation fit window and the frozen rolling-origin protocol.

It does not authorize new computation. It does not cover ridge readouts, VB
dominance, the 5000-observation stage, joint-QDESN, GloFAS, PriceFM, or any
other application.

## Frozen Baseline

- Validation branch: `validation/shared-fitforecast-v2-1.0.0`.
- Frozen evidence commit:
  `a02b93bee8cb52c273d989f455f8e7e3fd962f69`.
- Package: `exdqlm` 1.0.0, source-loaded from the validation worktree.
- Source-registry SHA-256:
  `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`.
- Fit source indices: 8501--9000.
- Forecast source indices: 9001--10000.
- Rolling-origin maximum lead: 30.
- Rolling-origin stride: 30.
- No refitting across forecast origins.

The point-1 evidence-freeze bundle is
`validation/fitforecast_v2/promotions/qdesn_500obs_mcmc_nested_final_origin9000_v1_evidence_freeze_20260730/`.
It marks origin 9000 as exposed and freezes the corrected final run as negative
confirmation evidence only.

The same bundle is the machine-readable article authority overlay. It pins the
36-row, 108-value numerical authority from
`qdesn_dqlm_500obs_mcmc_metric_envelope_20260727`, the separate coherent
confirmation, and the latest no-change final-origin decision. Therefore a
consumer can distinguish the source of the displayed numbers from the latest
evaluated evidence without treating the negative 2026-07-30 result as a
replacement promotion.

## Models Being Calibrated

| Internal model key | Article label | Likelihood | Prior | Current role |
|---|---|---|---|---|
| `qdesn_al_rhs_ns` | Q-DESN AL--RHS | asymmetric Laplace | regularized horseshoe | calibration target |
| `qdesn_exal_rhs_ns` | exQ-DESN exAL--RHS | extended asymmetric Laplace | regularized horseshoe | calibration target |
| `dqlm_c13_mcmc` | DQLM | matched DQLM | package model prior | comparator |
| `exdqlm_c13_mcmc` | exDQLM | matched exDQLM | package model prior | comparator |

DQLM/exDQLM are not being tuned in the proposed Q-DESN topology experiment.
For each metric and family/quantile cell, the reference value is the smaller
matched DQLM/exDQLM value. A ratio below one favors Q-DESN; a ratio at most
1.05 is the proposed practical noninferiority region.

## Exact Lower-Tail Target State

The values below come from the frozen 2026-07-27 metric-envelope handoff. That
envelope is useful for diagnosis, but many rows combine metrics from different
Q-DESN specifications. It is not itself proof that one coherent model achieves
all three values.

| Model | Family | Tau | Fit/external | Forecast-MAE/external | Check/external | Current diagnosis |
|---|---|---:|---:|---:|---:|---|
| Q-DESN AL--RHS | Gaussian mixture | 0.05 | 1.227 | 0.856 | 1.003 | fit recovery |
| exQ-DESN exAL--RHS | Gaussian mixture | 0.05 | 1.413 | 0.676 | 1.002 | fit recovery |
| Q-DESN AL--RHS | Laplace | 0.05 | 1.453 | 0.480 | 0.959 | fit recovery |
| exQ-DESN exAL--RHS | Laplace | 0.05 | 1.760 | 0.219 | 0.943 | fit recovery |
| Q-DESN AL--RHS | Gaussian | 0.05 | 1.467 | 1.953 | 1.107 | fit and forecast transport |
| exQ-DESN exAL--RHS | Gaussian | 0.05 | 1.282 | 0.693 | 0.976 | fit recovery |
| Q-DESN AL--RHS | Gaussian mixture | 0.25 | 1.415 | 0.576 | 0.993 | fit recovery |
| exQ-DESN exAL--RHS | Gaussian mixture | 0.25 | 1.422 | 1.598 | 1.026 | fit and forecast transport |
| Q-DESN AL--RHS | Laplace | 0.25 | 1.318 | 0.436 | 0.965 | fit recovery |
| exQ-DESN exAL--RHS | Laplace | 0.25 | 1.010 | 0.385 | 0.963 | resolved within 5%; coherent confirmation exists |
| Q-DESN AL--RHS | Gaussian | 0.25 | 0.955 | 1.159 | 1.004 | forecast transport |
| exQ-DESN exAL--RHS | Gaussian | 0.25 | 0.751 | 1.412 | 1.012 | forecast transport |

Eleven of the twelve lower-tail model/family/quantile cells exceed 1.05 on at
least one primary metric. The exQ-DESN Laplace 0.25 cell is the one lower-tail
cell already inside the 5% envelope; its separate coherent confirmation also
passed the prespecified comparison gate.

## Priority Interpretation

The lower-tail problem is not uniformly poor performance:

1. Seven unresolved cells are principally fit-recovery problems. Several of
   these already forecast much better than DQLM/exDQLM, especially both
   Laplace 0.05 cells.
2. Four unresolved cells are principally forecast-transport problems:
   Q-DESN Gaussian 0.05, exQ-DESN Gaussian-mixture 0.25, and both Gaussian
   0.25 variants.
3. Q-DESN Gaussian 0.05 is the broadest failure because all three ratios exceed
   one and forecast MAE is almost twice the external benchmark.
4. exQ-DESN Laplace 0.05 has the largest fit gap, but its forecast metrics are
   already excellent. A useful redesign must improve fit without destroying
   that forecast advantage.
5. Median cells are secondary controls. The Laplace median cells already beat
   the external envelope on all three metrics. Gaussian and Gaussian-mixture
   medians retain forecast gaps, but the study's primary scientific objective
   is lower-tail competitiveness.

## What the Failed Final Confirmation Established

The nested discovery campaign used origins 7000 and 8000, 12 designs per cell,
15 cells, 720 roots, and 1,440 MCMC seed rows. The four selected candidates
were then evaluated at origin 9000 with full MCMC budgets.

All four candidates were worse than their current parent on every primary
metric:

| Model/family/tau | Fit/parent | MAE/parent | Check/parent |
|---|---:|---:|---:|
| Q-DESN AL, Gaussian mixture, 0.50 | 1.057 | 1.010 | 1.007 |
| Q-DESN AL, Laplace, 0.05 | 1.014 | 1.037 | 1.010 |
| Q-DESN AL, Gaussian, 0.05 | 1.005 | 1.186 | 1.052 |
| exQ-DESN exAL, Gaussian, 0.25 | 1.045 | 1.202 | 1.020 |

This was not a missing-output or short-chain failure: 8/8 roots and 16/16 seed
fits completed. It was a genuine transfer failure.

## Why the Discovery Rule Failed

Across the 15 discovery cells, rank stability between origins 7000 and 8000
was:

- fit RMSE Spearman correlation: median 0.923, minimum 0.685;
- forecast MAE Spearman correlation: median 0.063, minimum -0.958;
- forecast check-loss correlation: median -0.119, minimum -0.818;
- identical winning design: 7/15 cells for fit, 2/15 for forecast MAE, and
  0/15 for forecast check loss.

Fit rankings were moderately reproducible, but forecast rankings were almost
uninformative. Pooling two origins could therefore select a candidate whose
apparent forecast advantage was local to those windows.

## Reservoir-Topology Diagnosis

The package interprets `pi_w` as the probability that a recurrent edge is
nonzero. The validation profile adapter has so far repeated scalar layer
settings across all layers.

Across 1,695 rows from the existing MCMC profile files, representing 195 unique
scalar designs:

- median expected recurrent degree `n_each * pi_w` was 0.10;
- 94.36% of unique designs had expected recurrent degree below one;
- 38.46% had probability above 0.5 that a single recurrent matrix was entirely
  zero;
- the maximum expected recurrent degree was only 2.

The four final candidates used only two compact scalar profiles:

- `n=5`, `pi_w=0.0013`: expected recurrent edges 0.0325 and probability
  0.968 that `W` is entirely zero;
- `n=16`, `pi_w=0.0021`: expected recurrent edges 0.5376 and probability
  0.584 that `W` is entirely zero.

Reconstructing the package RNG sequence from all eight recorded reservoir seeds
gave `W_nonzero=0` for all eight reservoirs. One `n=5` reservoir also had
`Win_nonzero=0`. These were legal package fits, but they were effectively
direct-lag/readout models with leaky input features rather than meaningfully
recurrent reservoirs.

## Forecast-Path Diagnosis

At the final origin, median forecast-path correlations with the oracle path
were high, from 0.982 to 0.999, but systematic level/trend errors remained:

| Model/family/tau | Median bias | Error slope per 1000 indices | Lead-1 MAE | Lead-30 MAE |
|---|---:|---:|---:|---:|
| Q-DESN AL, Gaussian mixture, 0.50 | -2.812 | -2.969 | 2.711 | 2.837 |
| Q-DESN AL, Laplace, 0.05 | -2.745 | -6.562 | 4.970 | 5.249 |
| Q-DESN AL, Gaussian, 0.05 | -8.800 | -10.001 | 8.205 | 8.909 |
| exQ-DESN exAL, Gaussian, 0.25 | -3.236 | -4.621 | 3.324 | 3.337 |

The error is not mainly an accumulation from lead 1 to lead 30. It is a
calendar-time transport and level-adaptation problem across the forecast
window. Merely changing `Hmax`, running more iterations, or adding width while
retaining effectively zero recurrence does not target this mechanism.

## What Has Already Been Explored

Existing MCMC profile files span:

- depth 1--4;
- width 4--300;
- input lag order 1--150;
- scalar alpha 0.00043--0.4;
- scalar rho 0.29--0.97;
- RHS `tau0` from `2e-8` to `1e-3`.

Therefore the unresolved issue is not lack of nominal scalar range. The main
untested axis is topology-valid, layer-specific recurrent dynamics with
decoupled stochastic replication and replicated source trajectories.

## Precise Scientific Objective

The next experiment should attempt, but must not presume, to establish a
cell-specific Q-DESN or exQ-DESN specification that:

1. uses a nondegenerate, auditable reservoir topology;
2. is evaluated by genuine MCMC rather than selected solely by VB ranking;
3. has one coherent specification supplying fit RMSE, forecast MAE, and check
   loss for the cell;
4. is robust across predeclared development source replicates and origins;
5. has a one-sided upper comparison bound no larger than 1.05 for every
   primary metric against the matched DQLM/exDQLM benchmark;
6. strictly improves at least one forecast metric;
7. preserves finite path diagnostics, acceptable calendar-time bias/slope,
   reproducible provenance, and storage-light outputs;
8. is confirmed only on source replicates whose seeds were committed before
   fitting.

The scientific goal is strong lower-tail competitiveness, especially at 0.05
and then 0.25. It is not to force Q-DESN to win through repeated reuse of one
holdout, metric-wise cherry-picking, or selection of a favorable reservoir
seed. A defensible negative result remains preferable to an overfit positive
claim.

## Decision Boundary

No further implementation or compute should begin until the user approves the
problem definition above. The proposed topology/transport experiment should
then be developed in an isolated worktree, leaving this frozen closeout and the
current article tables unchanged until a coherent replicated confirmation
passes its declared gates.

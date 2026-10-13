# Independent Q-DESN representation screen v1

## Decision and scope

The completed posterior-forecast rescue is scientifically closed. All 17
targeted Q-DESN cells remained behind their likelihood-matched DQLM or exDQLM
comparator on both oracle-path fit RMSE and full-lattice forecast MAE. The
median Q-DESN/comparator ratios were 2.21 for fit RMSE and 3.06 for forecast
MAE. Posterior bands were not the dominant failure: their centers missed the
oracle path. No related IND job remains active.

This campaign therefore returns to representation selection. It does not
repeat the prior 5,472-job Normal-RHS search unchanged. That search already
covered depths 1--4, up to 1,200 states, lags through 150, broad leakage and
spectral radii, and `tau0` from 0.01 to 30. Its principal limitations were a
single 35-origin validation slice, family-level Normal selection, no paired
ridge control, and poor transfer to the final 971-origin lattice.

The new lane owns only the independent single-quantile validation worktree and
ignored run root. It does not update shared validation, Article-v2, Overleaf,
joint Q-DESN, PriceFM, or GloFAS.

## Scientific questions

1. Does a reservoir contain the dynamic signal when its readout receives a
   well-calibrated exact ridge prior?
2. When ridge succeeds but Normal-RHS fails, is the deficit attributable to
   shrinkage or VB rather than the reservoir representation?
3. Which structures transfer across blocked rolling-origin folds instead of
   winning on one short validation slice?
4. Do those structures retain their ranking under AL/exAL quantile VB and
   direct MCMC?

Ridge is a structural diagnostic and triage mechanism, not an article model.
All promotable Q-DESN rows continue to use RHS-NS.

## Fixed model contract

- Families: Gaussian, Laplace, and Gaussian mixture.
- Target levels: 0.05, 0.25, and 0.50.
- Teacher forcing occurs between rolling origins; forecasts recurse within
  each 30-step horizon.
- Readout columns are the intercept and every current reservoir layer only.
- Reservoir activation is `tanh`; lower-state readout transforms are identity.
- Every transition reducer satisfies `n_tilde[d] = n[d]`, forcing every
  `Q_d` to be the exact identity. Dimensionality reduction is forbidden.
- DQLM and exDQLM remain frozen comparators.
- exAL MCMC uses the exdqlm 1.1.1 M0 collapsed-slice transition.

## Candidate support

The design contains 300 deterministic new structures and 20 frozen anchors per
family. New structures are rejected against the historical signature ledger.
One common matrix seed is held fixed throughout the campaign. This isolates the
effects of architecture, memory, preprocessing, and prior scale while avoiding
an unplanned multiplication of the screening surface. Reservoir-seed
sensitivity is a separate post-selection question and is not mixed into this
campaign.

- depth: 1--4;
- width support: 20, 40, 75, 100, 150, 200, 300, 400, and 600 per layer;
- total states: at most 1,800;
- response lags: 15--300;
- leakage: 0.01--0.99;
- spectral radius: 0.20--0.999, with deliberate high-memory enrichment;
- exact recurrent, input, and interlayer fan-in controls;
- training-prefix-only mean/SD or median/MAD scaling;
- bounded and unbounded scaled inputs with gains 0.01--3.

Large reservoirs are explicitly represented, but they are not privileged.
Capacity must earn advancement under blocked fit and forecast evidence.

## Blocked validation

The article holdout 9001--10000 remains sealed until confirmation. Structural
and VB selection use two expanding-window folds entirely within 8501--9000:

| Fold | Fit endpoint | Origins | Complete targets |
|---|---:|---:|---:|
| `fold_8750` | 8750 | 8750--8840 | through 8870 |
| `fold_8870` | 8870 | 8870--8970 | through 9000 |

Every origin is teacher forced from observed history; each horizon is recursive.
Selection retains median and worst-fold scores and lead groups 1, 2--5, 6--15,
and 16--30. This directly addresses the old short-surface transfer failure.

## Stage graph

1. **Exact Normal-ridge geometry screen:** 960 structure jobs. Each job shares
   reservoir states across six ridge scales and reports both folds.
2. **Normal-RHS VB screen:** the 120 Pareto-diverse structures per family are
   evaluated over ten actual `tau0` values on both folds. Fifty structures per
   family advance; scale remains candidate specific.
3. **Quantile VB:** 150 family-level candidates are evaluated separately for
   AL and structured exAL at all three target levels on both folds. Ranking is
   cell specific and forecast first, with fit and worst-fold safeguards.
4. **Direct MCMC pilot:** eight diverse candidates in each of 18 cells receive
   one short chain on all 171 inner origins.
5. **Replication:** the best three candidates per cell receive two additional
   chains. Diagnostics are disclosed but do not veto finite score gains.
6. **Sealed confirmation:** one candidate per cell receives three full chains
   on 971 origins and both predeclared forecast estimators.

No global winner is allowed. No partial stage is article-promotable.

## Reproducibility and operations

The campaign pins source, historical-ledger, configuration, Git, package,
seed, and environment hashes. Workers are process-parallel and single
threaded. Atomic status files make every stage resumable. Fitted objects are
never retained; only compact CSV, compressed metric draws, JSON status, logs,
and manifests remain.

Muscat execution uses 15 workers on CPUs 32--46. The launcher verifies a clean
synchronized dedicated branch, exdqlm 1.1.1, exact identity reductions, source
hashes, memory, disk, and load before release. It runs one production canary
for each new inference path before bulk work.

## Decision rules

- A feature map that fails under both calibrated ridge and RHS is rejected as
  representationally inadequate.
- Ridge success with RHS failure triggers shrinkage refinement, not a larger
  reservoir by default.
- Advancement is Pareto and diversity preserving; family, target level,
  likelihood, structure, and `tau0` remain case specific.
- VB is not treated as a reliable MCMC ranking surrogate. It narrows the field,
  while direct short MCMC makes the final screening decision.
- Every finite strict per-cell improvement is eligible for coordinator review,
  however small. Publication remains a separate integration decision.

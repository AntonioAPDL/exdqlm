# Independent Q-DESN Corrected Broad Screen v4

Date: 2026-10-01

Scientific lane: independent single-quantile Q-DESN/DQLM validation

Status: implemented behind completed-v3 and operator-smoke gates

## Scientific decision

The corrected v3 canary established that the recursive forecast operator is
causal and numerically stable, but it did not identify a competitive dynamic
location model. Its six cell winners all used the dimension-aware RHS scale,
and only nine of 72 candidates beat the constant training-quantile benchmark.
The winning forecast paths had only a small fraction of the oracle path
amplitude. Conversely, source-scale `tau0` values of 1 and 100 often produced
unstable or catastrophically over-amplified forecasts, especially under exAL.

The next useful experiment is therefore not another extreme-scale rerun and
not a fit-RMSE screen. It is a complete, case-specific internal forecast screen
in the previously untested middle shrinkage region, jointly varying reservoir
geometry and RHS scale. The held-out 9001:10000 block remains untouched during
selection.

To keep the forecast scale interpretable, v4 also refits one frozen DQLM and
one frozen exDQLM specification in each family/quantile cell. These 18 VB
controls use the identical internal fit/development lattice as Q-DESN. They are
diagnostic controls, not candidates in the Q-DESN ranking.

## Fixed estimand and temporal contract

- Families: Normal, Laplace, and Gaussian mixture.
- Quantiles: 0.05, 0.25, and 0.50.
- Likelihoods: AL and exAL.
- Internal fit rows: 8501:8750.
- Internal development rows: 8751:9000.
- Broad origins: 8750:8970 at stride 5.
- Horizon: 30.
- Each new origin is teacher-forced with every observation available through
  that origin.
- Unknown observations inside one 30-step path are generated recursively and
  are never replaced by future truth.
- The response transport is fitted on 8501:8750 only and inverted before
  scoring.
- The primary objective is oracle-path forecast MAE from the corrected
  mean-conditional-location estimator. Pooled posterior-predictive check loss
  is secondary; oracle RMSE is tertiary. Fit scores are diagnostic only.

The validated v3 forecasting kernel is reused directly. Its status and result
schema labels are now read from each frozen job config, so v4 artifacts cannot
be mislabeled as v3 while preserving byte-for-byte v3 behavior for old jobs.

## Feature and reservoir contract

Every candidate has the same scientific feature definition:

- raw response lags enter the reservoir input;
- `mx=0` because this simulation has no exogenous regressors;
- the readout is exactly an intercept plus every reservoir layer;
- response lags, exogenous lags, and reservoir lags do not enter the readout
  directly;
- every `Q_d` is the exact identity;
- `tanh` is the reservoir activation and identity is the lower-layer readout
  activation;
- nonzero weights are uniform on [-1,1];
- topology is represented by exact recurrent and input fan-in controls;
- the matrix seed is fixed at 920001 across the screen.

The fixed seed isolates specification effects. Input centering/bounding/gain
and sparse fan-in remain part of the screened structure, as requested.

## Broad design

There are 18 family-by-quantile-by-likelihood cells. Each cell receives eight
distinct canonical structures and two RHS scales, for exactly 288 VB jobs.
Structures are selected deterministically from:

1. the corrected-v3 cell winner;
2. the current article-authority geometry when recoverable;
3. a predeclared unseen deep/high-memory design;
4. the best ridge internal-forecast structure;
5. a distinct ridge high-memory structure;
6. a distinct ridge long-lag structure;
7. the best RHS internal-forecast structure;
8. a distinct high-memory RHS structure, with deterministic diverse fill if a
   proposed role duplicates an earlier canonical design.

Canonical deduplication uses depth, layer widths, exact identity dimensions,
response lags, alpha, rho, input preprocessing/gain, exact fan-ins, and fixed
matrix seed. A complete acceptance/rejection audit is retained.

For every structure, the dimension-aware source-scale reference is

```text
tau0_ref = p0 / (p - p0) * sigma_y / sqrt(n_eff),
```

where the intercept is excluded from `p`. Since the response is standardized
inside the fit, the passed model scale is divided by the training response SD.
The broad arms are exactly `1.0 * tau0_ref` and `3.5 * tau0_ref`. This targets
the untested bridge between the stable but attenuated reference fits and the
smallest historical wide arm; it does not repeat the failed source-scale 1 or
100 experiment. The Normal RHS initialization is cold and matched to the same
design and tau for every quantile VB fit.

## Gates and staged follow-up

1. The exact completed-v3 decision, ranking, candidate manifest, source
   manifest, and predecessor RHS ranking must pass pinned SHA-256 checks.
2. Six operator-smoke jobs use the smallest predeclared reference-scale
   structure in each family/likelihood cell (at most 100 states). They must
   finish with finite metrics and exact identity projections before downstream
   compute can start. Smoke selection is intentionally independent of the
   scientific rank so a large winner cannot turn a mechanical gate into a
   production fit.
3. Eighteen matched DQLM/exDQLM controls must finish with finite metrics, 250
   fit rows, 45 origins, 1,350 origin/lead pairs, and no retained fit binary.
   Their frozen sources must exactly equal the v4 source rows and oracle paths.
4. The 288-job broad screen must be fully terminal, hash-valid, finite, and
   complete at 16 candidates per cell. Partial results cannot unlock the next
   stage.
5. A completed broad audit writes case-specific rankings, winners, baseline
   ratios, and forecast-path amplitude ratios. It never launches the next
   stage automatically.
6. Adaptive materialization is limited to the best two distinct structures per
   cell. Lower-tail cells test multipliers 0.35, 1.75, and 7; median cells test
   0.5 and 7. This yields exactly 96 nonduplicate jobs and prioritizes the
   0.05/0.25 targets without abandoning the median controls.
7. Finalists must be rescored on stride-one internal origins before direct
   MCMC. At most three diverse candidates per cell may receive a short chain;
   only one candidate per cell may receive three full confirmation chains.
   exAL uses `m0_v_collapsed_support_logit`.

VB remains a computational filter, not an assumed MCMC rank surrogate.
Diagnostic warnings are retained but do not veto finite metric gains unless
they reveal leakage, nonfinite output, corruption, an invalid model object, or
a violated forecast contract.

## Reproducibility and storage

Production materialization requires a clean committed dedicated branch. Each
job freezes its config hash, data hash, branch HEAD, random seed, structure,
tau coordinate, result paths, and artifact hashes. Resume skips a job only if
its config and every retained artifact still match. Workers load this
worktree's exdqlm 1.1.1 source with one R/BLAS/OpenMP thread each.

The background pipeline is sequential: operator smoke, matched comparators,
then the broad screen. A failed gate prevents later compute. The operator
supplies an explicit 15-CPU affinity list that excludes every occupied core,
including the live superseded predecessor chain.

Only CSV/CSV.GZ/JSON/log evidence is retained. Fitted-model `.rds`, `.rda`, and
`.RData` payloads are forbidden. Article-v2, shared validation, Overleaf, joint
validation, PriceFM, and GloFAS are outside this branch's write boundary.

## Interpretation rule

The broad screen answers whether corrected internal H30 selection plus an
intermediate, dimension-aware RHS scale restores dynamic amplitude and reduces
forecast error. It does not authorize article replacement. Article-facing
evaluation requires a frozen candidate set, stride-one internal rescore,
direct MCMC confirmation, and subsequent coordinator integration.

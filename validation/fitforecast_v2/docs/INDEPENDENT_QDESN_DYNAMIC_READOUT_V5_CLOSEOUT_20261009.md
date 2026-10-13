# Independent Q-DESN Dynamic-Readout v5 Closeout

## Decision

`DYNAMIC_READOUT_SCREEN_GAIN_FAILED_DISJOINT_ORIGIN_VALIDATION`

The exact-M0 initialized, exAL local-moment Gaussian assumed-density filter
completed its predeclared screen and disjoint-origin validation without an
implementation failure. A coefficient-discount half-life of 1000 observations
was selected in screening. It beat exDQLM on the primary validation comparison,
but did not improve the stronger frozen rolling-N=1000 Q-DESN control. The
confirmation stage was therefore not opened, no article metric was replaced,
and the sealed source-index block 9001--10000 remained unopened.

## Completed campaign

| Stage | Complete | Failed | Result |
|---|---:|---:|---|
| Screen | 24/24 | 0 | Half-life 1000 selected |
| Disjoint validation | 4/4 | 0 | Gate stopped |
| Confirmation | 0/0 | 0 | Correctly not generated |
| Total | 28/28 | 0 | Closed |

The screen compared six predeclared covariance-discount policies at three
origins in each of four temporal folds. The selected half-life improved the
paired median forecast-MAE ratio against rolling N=1000 to 0.9650, won 7/12
rolling comparisons, and won 6/12 exDQLM comparisons.

On four disjoint origins per fold, the selected policy produced:

| Validation criterion | Result |
|---|---:|
| Median paired Q-DESN/exDQLM forecast-MAE ratio | 0.9676 |
| Q-DESN forecast-MAE wins over exDQLM | 9/16 |
| Median paired dynamic/rolling-N=1000 MAE ratio | 1.0089 |
| Dynamic forecast-MAE wins over rolling N=1000 | 7/16 |
| Median paired Q-DESN/exDQLM check-loss ratio | 0.9967 |
| Q-DESN check-loss wins over exDQLM | 8/16 |
| Dynamic check-loss wins over rolling N=1000 | 9/16 |

The unpaired medians were 2.0673 for the dynamic readout, 2.1152 for rolling
N=1000, and 2.4047 for exDQLM. They do not supersede the predeclared paired
ratio criterion: medians are nonlinear, and the paired ratio gives every
fold-origin cell equal comparative weight.

## Diagnosis

The result is temporally heterogeneous rather than uniformly poor. Median
dynamic/exDQLM MAE ratios were 0.655 and 0.809 in folds S1 and S2, but 1.288
and 1.203 in S3 and S4. By within-fold offset, they were 0.863, 0.863, 1.060,
and 1.046 at offsets 25, 75, 150, and 220. The corresponding dynamic/rolling
ratios were 0.889, 0.950, 1.098, and 1.107.

This pattern repeats the temporal instability seen in earlier static and
rolling-readout work. A slowly discounted online readout can help early
origins, but sequential assumed-density updates accumulate enough drift to
lose the rolling-refit advantage later. More discounting did not solve that
problem: the more aggressive half-life 62.5 policy ranked last in screening.

All 88 first-step feature and prediction guards passed. Feature differences
were exactly zero; the largest prediction difference was
`5.40e-13` (`2.74e-15` relative). This rules out a material mismatch in
teacher forcing, recursive state construction, or first-step forecast
plumbing. The negative result therefore does not justify another local
half-life grid or a claim that coefficient drift is the missing root
mechanism.

## Scientific boundary and next action

The post-initialization estimator is an assumed-density approximation, not
exact-M0 MCMC. Even a positive result would have required a formally specified
dynamic Bayesian readout and fresh-DGP confirmation before article promotion.
Because it failed the stronger rolling-control gate, this line should close.

Retain rolling N=1000 as the best validated Q-DESN adaptation mechanism for
this target. Do not alter article tables, figures, prose, or authoritative
metrics from v5. The next scientific design should reassess the model class or
forecast objective using fresh DGP replication; it should not spend another
campaign on denser static-reservoir or coefficient-discount grids against the
already reused internal series.

## Reproducibility

- Worktree: `/data/jaguir26/local/src/exdqlm__wt__independent_qdesn_dynamic_readout_v5_20261009`
- Branch: `validation/independent-qdesn-dynamic-readout-v5-20261009`
- Frozen source commit: `48117fc6d0f0e478b9eeb5e08e9c33063ce13a33`
- Run: `validation/fitforecast_v2/local_trackers/independent_qdesn_dynamic_readout_v5_20261009_072036__git-48117fc6`
- Runtime: R 4.6.0, exdqlm 1.1.2, one numerical thread per worker
- Exact-M0 initialization: three chains and 600 retained draws per fold
- Evidence directories: 28
- Closeout manifest: 109 files, 2,478,744 bytes, all SHA-256 checks passed
- Full local run footprint: 11 MB
- Fitted-model `.rds`, `.rda`, or `.RData` payloads: 0
- Active campaign jobs: 0

The closeout manifest SHA-256 is
`a0a32a7790fd8cda24bd3a4c27c223fe0a0ba65a88092b58d42c612e4679564f`.
The full run remains ignored runtime evidence and must not be added to Git.

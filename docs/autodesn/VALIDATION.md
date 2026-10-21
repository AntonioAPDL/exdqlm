# Gaussian AutoDESN validation

Base: `integration/ind-forecast-300-500-shared-20261015`, commit
`94bd95784f413f3edde88a35cb991f2a56b6afef`. The default branch lacks the
current Q-DESN and Normal DESN implementations, so this isolated feature branch
builds on their shared integration branch. Existing readout inference code is
unchanged. A scalar-dimension correction in the shared feature builder permits
one-unit reservoirs; six multi-feature base/current comparisons produce
identical designs, reservoirs and state histories.

## Numerical and statistical target

- Accelerated coefficient-integrated scores agree with independent dense
  covariance calculations for ordinary, rank-deficient, wide, and intercept-only
  designs across multiple noise variances and ridge precisions.
- Splitting a duplicate candidate's old prior mass preserves its total posterior
  mass. Very large finite prior weights normalize without overflowing.
- Gaussian conditional means, precision factors and sampled covariance are checked
  independently. Finite-bank joint Gibbs draws are compared with dense numerical
  integration, not another implementation of the accelerated SVD formula.
- The dense oracle integrates observation variance and ridge precision on log
  scales, including both Jacobians. Grid refinement from 81 to 121 points per
  dimension changes estimates by `3.21e-11`; wider bounds with 161 points change
  them by `3.16e-9`.

| Quantity | Integrated oracle | Gibbs estimate | Batch Monte Carlo SE |
|---|---:|---:|---:|
| First-model probability | 0.606102 | 0.605704 | 0.000326 |
| Noise variance | 0.621294 | 0.621142 | 0.001647 |
| Ridge precision | 1.204389 | 1.206424 | 0.005769 |
| Intercept | 0.205955 | 0.205430 | 0.001373 |

Three chains each discard 1,500 sweeps and retain 5,500. Starting variance and
precision differ across chains. The declared target-test tolerance is
`max(0.025, 5 * MCSE)`. Both rank-normalized folded split R-hats are below 1.001.

## Causality, forecast contracts and API checks

Tests cover exact design parity with `qdesn_fit_vb(fit_readout = FALSE)`, common
score rows, one proper intercept, prefix-only preprocessing, future-target
perturbations, preservation of reservoir weights and states, identity bridges,
zero-lag input, independent seed restoration, fixed and learned ridge precision,
single-model/single-path dimensions, malformed controls and unsupported modes.

One-step features agree with an extended shared-builder replay. Later forecast
means agree when the shared builder receives each path's own simulated history.
Forecasts exactly reuse the Normal DESN path method with external joint draws;
one-step predictive mixture means and variances are also checked independently.

All ten AutoDESN Rd pages parse and pass `tools::checkRd()`. Static usage analysis
reports no findings for the new functions. The final installed-package focused
run passes **384 expectations with zero failures, errors or warnings**, including
**130 AutoDESN expectations**, the existing Gaussian readout and recursive
forecasts, topology, and warm-start tests. The coefficient-covariance test uses
the exact Wishart sampling variance and a six-MCSE entrywise bound, including
for zero population covariances.

Repository-wide validation is reported separately. It must not be interpreted
as an all-green release check: the shared integration branch includes archived
study tests pinned to other package versions and host-specific evidence paths.
The first complete invocation records 5,540 passing expectations, 41 failed
expectations, 62 test cases with errors, and 31 warnings. One failure was the
old covariance tolerance subsequently corrected and rerun successfully.
The untouched base run records 5,415 passing expectations, 40 failed
expectations, 62 test cases with errors, and the same 31 warnings. Across all
**560 existing test cases, expectation counts, passes, failures, errors,
warnings and skips match exactly**. There are **zero new failures in existing
test cases**. `baseline_comparison.csv` preserves the case-by-case evidence.

The additional run with `NOT_CRAN=true` passes **894 expectations across 99
test cases in 16 files**, with zero failures, errors, warnings or skips. This
includes existing MCMC routing, strict/fast backend, shrinkage, convergence and
repeatability tests. `final_coverage.csv` combines the initial full run with
the final focused and extended checks, retaining the latest result per case;
all raw run tables remain available.

Initial `R CMD check` also identifies pre-existing distribution issues: archived
configuration paths exceed portable-tar limits, a transfer-function example
references missing `nino34` data, and existing manuals have argument/default
mismatches. The branch corrects the simulation helper's malformed math markup,
generates missing online/rolling manuals from their existing roxygen, and
declares already-used optional `Matrix`/`RSpectra` dependencies. Its Windows CI
checkout now succeeds after enabling Git long paths. Detailed final check and
base-comparison artifacts accompany this report; the PR remains a draft.
The final metadata check (installation, examples and tests checked separately)
reports one inherited portable-path error, three inherited documentation/code
warnings, and two notes. No finding names an AutoDESN function or manual page.
The earlier complete package check also confirms the missing-data example
error; skipping examples in the metadata refresh does not resolve that issue.
At the recorded CI snapshot, four completed OS/R jobs fail repository-wide
checks, including the missing-data example and checkout-only historical study
assets. No AutoDESN test failure is reported in those job logs. The devel job
is still running. CI status is therefore explicitly not reported as green.

## Repeated forecasting study

The bank contains 48 specifications: depth 1/2, layer width 8/12, input lags
1/4/12, radius 0.4/0.85, seed 11/29, leak 0.5. Conditioning uses 30 observations,
followed by 20 common warmup observations. Two independently initialized Gibbs
chains each use 1,000 burn-in and 2,500 retained sweeps. Each forecast uses 1,000
paths for horizons 1 through 12.

For each of three stable processes, six independent series are evaluated at
origins 180 and 240. Innovations are Gaussian with standard deviation 0.35;
300 initial observations are discarded:

- Linear: `y[t] = 0.7*y[t-1] + innovation`.
- Nonlinear: `y[t] = 0.35*y[t-1] + 0.65*sin(1.8*y[t-2]) + innovation`.
- Seasonal: `y[t] = 0.25*y[t-1] + 0.6*y[t-12] + innovation`.

The fixed DESN is prespecified and uses the same Gaussian independent-ridge
likelihood/prior conventions and common response rows. Gaussian AR(1) and AR(12)
use the existing exact scaled-ridge backend; they are forecasting comparators,
not an ablation with identical coefficient priors. Fixed DESN uses one chain;
AutoDESN pools two chains after diagnostic screening.

| Process | Method | RMSE | CRPS | 90% coverage |
|---|---|---:|---:|---:|
| Linear | AutoDESN | 0.486 | 0.277 | 89.6% |
| Linear | Fixed DESN | 0.493 | 0.283 | 87.5% |
| Linear | Gaussian AR(1) | 0.466 | 0.264 | 93.1% |
| Linear | Gaussian AR(12) | 0.487 | 0.277 | 94.4% |
| Nonlinear | AutoDESN | 0.493 | 0.274 | 91.7% |
| Nonlinear | Fixed DESN | 0.649 | 0.373 | 84.7% |
| Nonlinear | Gaussian AR(1) | 0.703 | 0.407 | 86.8% |
| Nonlinear | Gaussian AR(12) | 0.550 | 0.310 | 91.7% |
| Seasonal | AutoDESN | 0.370 | 0.209 | 92.4% |
| Seasonal | Fixed DESN | 0.401 | 0.225 | 92.4% |
| Seasonal | Gaussian AR(1) | 0.502 | 0.285 | 86.8% |
| Seasonal | Gaussian AR(12) | 0.351 | 0.197 | 91.7% |

All 36 cases and 1,728 scored method/horizon rows are present, finite, and
unique. Recomputing summaries from raw scores reproduces the exported table.
The largest parameter split R-hat is 1.006; the smallest summed per-chain coda
spectral ESS is 407. The largest between-chain difference for an individual
model's probability is 0.0299. These are diagnostic screens, not convergence
proofs or architecture-identification claims.

The bank favors short memory for linear data, lag count 4 for nonlinear data,
and lag count 12 for seasonal data. Mean depth-2 mass is approximately 2.2%,
25.2%, and 1.8%, respectively. These describe representations within this bank;
the generating processes do not possess a uniquely defined DESN depth.
The nonlinear process uses two lags; the bank offers 1, 4 and 12, so 4 is its
shortest available input window containing both relevant lags.

The examples support implementation feasibility and show that automatic
selection need not prefer depth. They do not establish general superiority:
the correctly specified AR(1) comparator is best on linear data, and AR(12) is
best on seasonal data. Six independent replications are modest. Bootstrap
intervals resample whole series and retain the dependence between overlapping
origins and horizons; they are descriptive rather than hypothesis tests.

## Reproducibility and reporting audit

`validation/autodesn/artifacts/` contains the configurations, simulated series,
raw scores, model probabilities, diagnostics, oracle output and three figures
as both PNG and PDF. `validate_replay.R` reruns the first prespecified case
against the final code. All four methods reproduce the archived forecasts and
scores within `4.9e-15` after CSV round-trip.

The study launched before final namespace qualification, default-seed and
metadata cleanup. Every study fit explicitly supplies its seed. The launch
and delivery source manifests preserve this distinction; the numerical path
for these data is unchanged, as checked by replay. Editing the reporting
script during its original execution produced a trailing parse error after
all outputs, summaries and session details were saved. The final script parses
correctly, and a separate audit verifies complete case counts and aggregates.

The executed environment is native R 4.3.3 on Ubuntu 24.04.3. Production R code
adds no dependencies. Plot reproduction additionally uses Python, numpy,
pandas and matplotlib. No SMC, RHS, AL/exAL architecture averaging, exogenous
forecast input or online updating is claimed by this implementation.

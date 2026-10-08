# Independent Q-DESN sentinel mechanism campaign v1

This file freezes the implementation contract for the leakage-safe sentinel
campaign. The campaign targets the Normal, p=0.05, exAL-RHS cell and treats the
Normal AL-RHS and Laplace exAL-RHS p=0.05 cells as paired and positive controls.

The implementation is intentionally isolated from shared validation, article
main, and Overleaf. Article promotion is out of scope.

## Evidence motivating the design

The completed N=1000 campaign succeeded operationally but Q-DESN won only
three of eighteen MCMC forecast-MAE comparisons and no fit-RMSE comparison.
M0 removed gamma mixing as the leading exAL explanation. Replaying realized
future response lags improved every cell but reduced median MAE by only about
10 percent and left all Normal and Gaussian-mixture cells behind their DQLM
comparators. Zero-innovation plugin recursion did not rescue the models. The
next experiment must therefore distinguish readout representation and causal
origin adaptation before spending another full-study MCMC budget.

## Frozen scientific scope

The primary sentinel is `normal__exal__p005`. It is the largest observed
forecast-ratio failure and did not receive the previous campaign's broadest
post-M0 search. `normal__al__p005` separates likelihood-specific behavior and
`laplace__exal__p005` is a positive control.

All selection occurs in four expanding-window folds ending at source indices
8000, 8250, 8500, and 8750. Their validation targets end no later than 9000.
The repeatedly inspected 9001--10000 block is never opened by this campaign.
Every forecast is teacher-forced between origins and recursive for 30 leads
within an origin.

## Candidate surface

The deterministic maximin bank contains 240 candidates: 80 structures crossed
with reservoir-only, lag-only, and hybrid reservoir-plus-direct-lag readouts.
It covers depth 1--6, 40--1500 reservoir states, 1--500 response lags, leakage
0.01--0.995, spectral radius 0.40--0.999, input gain 0.02--3, broad exact
fan-in levels, both frozen preprocessing choices, and expected active sizes
3, 8, 15, 30, 60, and 120. Every layer retains identity Q. The reservoir seed
is fixed during discovery.

Global RHS scale is derived from expected active size and actual readout
dimension. Hybrid and lag-only models additionally screen a declared direct-lag
precision multiplier. The intercept remains outside RHS shrinkage.

## Gated computation

1. Six smoke jobs exercise every readout under Normal and exAL VB.
2. Normal RHS VB evaluates 240 candidates on folds S1 and S3.
3. Fifty forecast-leading and structurally diverse candidates receive matched
   exAL VB on all four folds.
4. Six dimension-feasible finalists receive causal online-VB forecast
   diagnostics. This is a separate estimator and cannot silently replace the
   static Q-DESN contract.
5. Twelve static finalists receive short MCMC on S2 and S4.
6. Three finalists and matched exDQLM controls receive three-chain full MCMC on
   all four folds.
7. The winning readout philosophy is applied to the paired and positive-control
   cells, first under VB and then under repeated-chain MCMC.

Normal VB is a triage tool, not an exclusion gate: the shortlist preserves
forecast leaders, readout/size strata, and boundary candidates. Quantile stages
rank lexicographically by median forecast MAE, forecast check loss, worst-fold
MAE, dimension, and immutable ID. Diagnostic flags are disclosed but are not a
metric-exclusion rule.

Candidates above 500 readout columns remain eligible for VB discovery. Exact
MCMC finalists are capped at 500 columns because the current full-covariance
beta sampler has cubic factorization cost. A decisive larger winner is retained
as a computational-method finding rather than silently discarded.

## Reproducibility and operations

The run freezes source snapshots, package and source hashes, candidate and fold
manifests, configurations, seeds, environments, and every stage plan before
execution. It uses CRAN exdqlm 1.1.2, the M0 exAL transition, one R process and
one numerical thread per model, no more than 15 idle physical cores, immutable
success artifacts, and fail-closed stage advancement. Fitted model binaries are
not retained.

The final decision is a scientific review packet, never automatic article
promotion. Fresh DGP replicates remain mandatory before any future article
replacement based on this development workflow.

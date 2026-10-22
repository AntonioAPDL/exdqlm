# Executed 500/500/100 AutoDESN results

Observations 1:500 determine frozen scaling and reservoir warmup; 501:1000
provide exactly 500 common likelihood contributions; 1001:1100 are held out
for one 100-step forecast. Generator initialization, observation washout and
MCMC burn-in remain distinct. No future response enters fitting or recursion.

The main example reuses the repository's period-90 Gaussian trend/two-harmonic
DGP with observation SD 10. The frozen 72-candidate bank has depths 1/2/3,
widths 20/50, input lag counts 5/30/90, two dynamical profiles and two seeds.
Bridges are identities; the readout contains one intercept and all layers.
The independent Gaussian ridge prior and blocked Gibbs target are unchanged.

Three fresh series per process give 9 cases and 6,300 unique method/lead score
rows. Every AutoDESN forecast has 192 outer posterior draws and 64 innovation
paths each: 12,288 trajectories over 100 leads. One joint model, coefficient
vector and variance stays fixed throughout each trajectory. Conditional means
are averaged over stochastic histories; predictive quantiles pool outcomes
using type 8.

## Frozen forecast results

| Process | Method | RMSE | CRPS | 90% coverage |
|---|---|---:|---:|---:|
| Trend + season | AutoDESN | 10.452 | 5.891 | 90.7% |
| Trend + season | Fixed DESN | 10.605 | 5.991 | 91.0% |
| Trend + season | Gaussian AR(1) | 25.394 | 14.707 | 95.7% |
| Trend + season | Gaussian AR(90) | 11.044 | 6.270 | 91.0% |
| Trend + season | Known DGP | 10.009 | 5.625 | 89.0% |
| Linear | AutoDESN | 0.497 | 0.282 | 90.3% |
| Linear | Fixed DESN | 0.508 | 0.291 | 86.7% |
| Linear | Gaussian AR(1) | 0.495 | 0.281 | 90.3% |
| Linear | Gaussian AR(90) | 0.505 | 0.290 | 91.3% |
| Linear | Known DGP | 0.493 | 0.279 | 89.3% |
| Nonlinear | AutoDESN | 0.667 | 0.364 | 93.3% |
| Nonlinear | Fixed DESN | 0.533 | 0.303 | 95.7% |
| Nonlinear | Gaussian AR(1) | 0.780 | 0.452 | 95.3% |
| Nonlinear | Gaussian AR(90) | 0.545 | 0.329 | 99.0% |
| Nonlinear | Known DGP | 0.680 | 0.368 | 93.0% |

These are the original frozen results; the separate sampler confirmation below
does not replace them. Gaussian AR uses the existing scaled-ridge prior, while
fixed DESN uses AutoDESN's independent ridge prior. The known-DGP reference
knows the true parameters and uses only information available at the origin.

AutoDESN performs well on the seasonal example. Its average 90% interval width
is 34.38, versus 32.90 for the known-DGP reference. Mean posterior mass on lag
count 90 is 99.97%. Depths 1/2/3 receive 26.8%/51.1%/22.0%; width 20 receives
97.9%. These describe this finite dictionary, not a uniquely true neural depth.

Linear results are close to AR(1). Fixed DESN and AR(90) score better on these
three nonlinear realizations. The known-DGP forecast is optimal in expected
proper score under its target, not on every finite collection of realized
paths. Three replications cannot establish comparative superiority. Automatic
selection using one-step training likelihood need not optimize a particular
long-horizon score; no test-based tuning is performed here.

## Sampler diagnostics and confirmation

The frozen study uses three chains with 1,500 discarded and 4,000 retained
sweeps each. A predeclared diagnostic-only retry uses 3,000 discarded and
8,000 retained sweeps. Three AutoDESN cases trigger that retry. Eight of nine
final AutoDESN screens and all nine fixed-DESN screens pass. The remaining
nonlinear replication has ridge-precision R-hat 1.01379; its failed screen is
preserved in the original evidence. The smallest final spectral ESS is 491.5.

A separate follow-up selects all and only that failed case from the diagnostic
ledger, using the same bank, priors, data and target. Three chains use 5,000
burn-in and 32,000 retained sweeps each. It passes: maximum R-hat 1.00108,
minimum spectral ESS 1,777.9, and maximum individual-model between-chain
probability range 0.00559. Total variation between original and confirmed
model-probability estimates is 0.00500.

For that case, RMSE changes from 0.50219 to 0.50610 and CRPS from 0.27044 to
0.27238. The forecast-mean RMS change is 0.00804. This supports numerical
stability while keeping the original failed screen visible.

## Implementation and forecast audit

- The installed-package focused suite passes 463 expectations with zero
  failures, errors, warnings or skips, including 72 new long-horizon checks.
- Checks cover serial/batched parity with matched innovations, shallow and
  reduced maps, identity bridges, ReLU, nested subsets, joint draw identity,
  frozen scaling, exact training rows and rejected future teacher forcing.
- A Gaussian AR(1) test checks analytic means, variances and 5/50/95% marginal
  quantiles over all 100 leads using 10,000 paths and Monte Carlo error bounds.
- Default serial outputs match the previous revision exactly in three
  100-step checks. The earlier 12-step study replay still agrees with archived
  scores within 4.9e-15 after CSV round-trip.
- 243 evidence checks verify split indices, all scored rows, finite outputs,
  saved trajectories, probability normalization, retry rules, re-aggregated
  metrics and unchanged launch source hashes.
- Changed manuals parse and pass checkRd. Usage analysis is clean for the
  three changed AutoDESN functions. The shared Normal function retains its
  existing codetools notice for the global .Random.seed reference.

For the prespecified seasonal example, increasing inner paths from 64 to 128
changes the mean-location curve by RMS 0.00812 in response units. The largest
5/50/95% quantile change is 0.411, compared with observation SD 10. This checks
inner simulation error, not all posterior Monte Carlo uncertainty.
Zero-innovation plug-in recursion differs from stochastic mean-location
recursion by RMS 0.170 and maximum 0.541; the estimands remain explicit.

A matched-output timing check for depth 3, width 50, 100 leads and 512 paths
measures 4.756 seconds serial versus 1.095 seconds batched: 4.34 times faster
on this runtime, with maximum difference 7.11e-14. This is one host/R/BLAS
timing, not a general speed guarantee. Serial remains the default.

The frozen study completes in 702.5 seconds under native R 4.3.3. Repository-wide
release checks retain the inherited archived-study, packaging and missing-data
example failures documented in docs/autodesn/VALIDATION.md. This focused run
does not assert a globally green release.

## Reproduction and evidence

Run from the repository root; choose a fresh AUTODESN_LONG_OUT for a new study:

```sh
Rscript validation/autodesn/long_horizon/run_study.R
Rscript validation/autodesn/long_horizon/confirm_sampler.R
python validation/autodesn/long_horizon/plot_results.py
python validation/autodesn/long_horizon/audit_results.py
Rscript validation/autodesn/long_horizon/audit_defaults.R
Rscript validation/autodesn/long_horizon/benchmark_forecast.R
```

Configuration, launch/delivery source manifests, scores, probabilities,
diagnostic attempts, confirmation results and session details are retained.
Every lead is saved for 64 illustrative trajectories per case; mean locations
and plug-in paths for all outer draws are retained. Full Monte Carlo arrays
and fitted-model binaries are reproducible but not stored. Five figures are
available in PNG and vector PDF. SHA256 manifests cover the artifacts.

# Independent exDQLM MCMC rolling-state repair v1

## Scope

This task is restricted to the independent single-quantile validation study and
the exDQLM MCMC rows. It does not alter Q-DESN, DQLM, joint validation,
applications, Article-v2, or Overleaf.

## Confirmed diagnosis

The CRAN 1.1.1 rerun did use `collapsed_slice` in all 27 exDQLM MCMC jobs. Its
three chains agree closely on the poor lower-tail forecast scores, so the
failure is not chain-local Monte Carlo noise. The first rolling origin is
competitive; the large positive quantile bias begins after held-out
observations are passed through the validation harness's deterministic state
extension.

The historical extension requests VB fields (`gammasig.out`, `sts.out`, and
`vts.out`). `exdqlmMCMC()` returns posterior draws instead. Missing fields were
silently replaced by defaults, giving `ex_f = 0` and a crude constant `ex_q`
for every unrestricted MCMC exAL update. This discards the fitted gamma.

For an exAL error with transformed AL probability `p`, scale `sigma`, and
`alpha = C(p0, gamma) |gamma|`, the exact conditional moments are

```text
mean(error | sigma, gamma) = sigma { A(p0, gamma) + alpha sqrt(2/pi) }

var(error | sigma, gamma) = sigma^2 {
  B(p0, gamma) + A(p0, gamma)^2 + alpha^2 (1 - 2/pi)
}
```

The repaired bridge averages the conditional first and second moments over
paired posterior `samp.sigma` and `samp.gamma` draws. It then uses the resulting
posterior-predictive mean and variance as the Gaussian pseudo-observation
moments for the held-out Kalman updates.

The analytical moments were also checked against the public CRAN 1.1.1
`rexal()` generator under a frozen seed. The run preflight repeats this check
and records the expected and empirical mean, variance, and target quantile.

Across the six lower-tail cells, the old forecast MAE has correlation 0.995
with the exAL error mean omitted by the historical updater. This magnitude and
direction match the observed upward drift. Median cells have gamma near zero
and therefore do not show the same failure.

### Cell-level evidence from the frozen 1.1.1 rerun

The following values are three-chain means. `First-origin MAE` is evaluated
before any held-out observation has been passed through the rolling state
extension. `Omitted mean` plugs the stored chain-level posterior gamma and sigma
means into the exact exAL error mean and then averages over chains.

| Family | tau | Fit RMSE | Forecast MAE | First-origin MAE | Omitted mean | Mean gamma ESS | Mean gamma ACF1 |
|---|---:|---:|---:|---:|---:|---:|---:|
| Gaussian mixture | 0.05 | 2.595 | 23.913 | 3.475 | 20.238 | 167.6 | 0.931 |
| Gaussian mixture | 0.25 | 1.337 | 8.940 | 1.785 | 8.212 | 38.3 | 0.994 |
| Gaussian mixture | 0.50 | 2.228 | 2.221 | 1.000 | 0.000 | 20037.0 | -0.006 |
| Laplace | 0.05 | 5.680 | 22.441 | 5.330 | 18.628 | 261.0 | 0.888 |
| Laplace | 0.25 | 1.714 | 6.810 | 1.556 | 6.860 | 169.6 | 0.964 |
| Laplace | 0.50 | 1.773 | 2.014 | 1.128 | 0.000 | 20000.0 | -0.001 |
| Gaussian | 0.05 | 1.940 | 16.227 | 1.194 | 15.340 | 218.8 | 0.915 |
| Gaussian | 0.25 | 2.363 | 6.636 | 0.740 | 5.955 | 120.1 | 0.981 |
| Gaussian | 0.50 | 2.589 | 1.659 | 1.230 | 0.000 | 20135.7 | -0.002 |

The lower-tail correlation between forecast MAE and omitted mean is
`0.99495631`. The across-chain standard deviation of forecast MAE is at most
`0.00526` in all nine cells and only `0.00254` in the worst-scoring Gaussian
mixture 0.05 cell. Thus the chains agree closely on the bad forecast path.

All 27 MCMC jobs used CRAN 1.1.1 `collapsed_slice` (the production M0 gamma and
sigma update), with 5,000 burn-in draws and 20,000 retained draws. Twenty-five
of 27 metric-level diagnostic summaries passed; only Gaussian mixture 0.25
forecast MAE and check loss were warnings. That cell does have high gamma and
sigma autocorrelation, but it is not the general explanation: the same
post-origin bias appears in lower-tail cells with much larger gamma ESS, and
the chains still agree on each reported metric.

### Alternatives ruled out before compute

- **Wrong package or old gamma sampler:** every unrestricted MCMC job records
  CRAN exdqlm 1.1.1 and `collapsed_slice`.
- **Insufficient MCMC length:** independent chains reproduce the same forecast
  failure to several decimal places; more iterations cannot remove a
  deterministic downstream centering error.
- **Globally poor exDQLM fit:** fit RMSE is competitive in several cells, and
  first-origin forecasts are dramatically better than the aggregate result.
- **Long-lead deterioration:** the protocol uses 34 origins, maximum lead 30,
  and stride 30. The jump begins after the first held-out state update rather
  than increasing primarily with lead.
- **Changed DGP, priors, or model design:** the materializer verifies the frozen
  source config hash and rejects any top-level scientific change outside the
  output/provenance/state-update allowlist.

The remaining causal uncertainty is whether exact posterior-predictive moment
matching is sufficiently accurate for the deterministic no-refit filter. The
full-budget sentinels answer that question directly. If they fail, the next
candidate is an observation-conditional latent-moment update, not a blind
sampler-length or hyperparameter screen.

## Identification strategy

1. Preserve every fit input, model specification, prior, MCMC seed, chain
   length, origin, lead, and score definition.
2. Change only the held-out state-update method.
   A fail-closed config audit compares every top-level field and permits changes
   only to generated output locations, provenance, and this state-update
   contract.
3. Run three full-budget one-chain sentinels under the public CRAN 1.1.1
   tarball: Normal p=0.05, Gaussian mixture p=0.25, and Normal p=0.50.
4. Require fit RMSE and first-origin forecasts to remain invariant, material
   lower-tail forecast improvement, and no material median regression.
5. Only after all sentinel gates pass, run the complete 27-job exDQLM MCMC
   confirmation (nine cells by three chains).
6. Compare the complete corrected exDQLM block with the current authority.
   Never mix partial old and new rows in an article-facing table.

## Promotion rules

- No article or shared-authority update from sentinel evidence.
- Full replacement requires 27/27 completed jobs, finite point and posterior
  metric summaries, exact CRAN 1.1.1 evidence, manifest verification, and the
  complete family-by-quantile surface.
- Metric changes and mixing changes remain separate findings.
- Fitted-model binaries are transient and must be pruned after successful row
  scoring; summaries, diagnostics, configs, seeds, and hashes are retained.
- The integration coordinator alone merges a frozen scientific handoff and
  decides whether Article-v2 should change.

## Expected decision

If the sentinel succeeds, the scientific repair is a validation forecast-state
transport correction, not an exDQLM sampler retuning campaign. Additional MCMC
iterations or broader gamma tuning would be wasteful before this correction is
evaluated on all nine cells.

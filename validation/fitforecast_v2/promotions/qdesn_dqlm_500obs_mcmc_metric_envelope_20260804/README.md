# Independent Q-DESN MCMC Alpha/Rho Confirmation Authority, 2026-08-04

- Promotion id: `qdesn_dqlm_500obs_mcmc_metric_envelope_20260804`
- Parent promotion: `qdesn_dqlm_500obs_mcmc_metric_envelope_20260727`
- Runtime run tag: `qdesn-arfc1-full-20260803_152952__git-3ed1d0c`
- Runtime implementation commit: `3ed1d0cdba4dd5e858d8abe667b49aef731fc9aa`
- Materialization branch: `validation/shared-fitforecast-v2-1.0.0`
- Materialization commit: `e5d2f335c49dbf264abc714d616fe8eda1e20f5e`
- Source registry SHA-256: `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`
- Completed full-budget roots: `8/8`
- Execution/source/seed contract passes: `8/8`
- Unexpected binary payloads: `0`
- Metric-envelope promotions: `3`

## Decision

The broad alpha/rho candidate does not transfer robustly across the paired
reservoir seeds. The exact-parent Gaussian-mixture, p=0.25, replicate-1
control nevertheless improves fit RMSE, forecast MAE, and forecast check
loss simultaneously against the frozen article envelope. Under the declared
status-agnostic metric-envelope policy, those three values are promoted from
one coherent completed root.

The promoted root retains FAIL signoff for high autocorrelation and half-chain
drift. This permits a numerical envelope update but not a convergence claim,
a global alpha/rho recommendation, or a prose claim of seed-robust superiority.
No Laplace metric is promoted because its small check-loss gains accompany
materially worse fit and forecast MAE.

## Remaining Work

Further Gaussian-mixture work should target sampler and reservoir-seed
stability. Further Laplace work requires a readout, shrinkage, or architecture
change rather than another local alpha/rho grid. Neither follow-up is launched
by this promotion.

# Q-DESN/DQLM 500-Observation MCMC Metric Envelope, 2026-07-27

- Promotion id: `qdesn_dqlm_500obs_mcmc_metric_envelope_20260727`
- Parent promotion: `qdesn_dqlm_500obs_mcmc_metric_envelope_20260726`
- Validation branch: `validation/shared-fitforecast-v2-1.0.0`
- Materialization commit: `827b16553ec39511c557e5c502ac222a9555cbe4`
- Source registry SHA-256: `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`
- Candidate rows audited: `129`
- Complete article cells: `36/36`
- Displayed metric-envelope changes: `0`
- Coherent full-budget confirmations added: `1`

## Decision

The Laplace, p=0.25, exAL-RHS full-budget confirmation passes every
prespecified external-benchmark, stability, source, and storage gate.
Its three metrics are slightly above the existing case-specific metric
minima, so it is retained as coherent confirmation evidence without
overwriting lower displayed envelope values.

## Article Contract

The article may point to this refreshed promotion and report the coherent
confirmation separately. Numeric table entries remain unchanged because
the declared article selection rule is metric-wise minimum evidence.
Diagnostic grade WARN (chain_marginal_but_usable) remains explicit.

- Article envelope: `qdesn_dqlm_500obs_mcmc_metric_envelope_20260727_article_envelope.csv`
- Coherent confirmation: `qdesn_dqlm_500obs_mcmc_metric_envelope_20260727_coherent_confirmation.csv`
- Manifest: `qdesn_dqlm_500obs_mcmc_metric_envelope_20260727_manifest.json`

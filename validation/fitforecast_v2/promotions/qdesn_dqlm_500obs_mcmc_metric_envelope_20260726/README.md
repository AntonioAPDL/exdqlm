# Q-DESN/DQLM 500-Observation MCMC Metric Envelope

- Promotion id: `qdesn_dqlm_500obs_mcmc_metric_envelope_20260726`
- Validation branch: `validation/shared-fitforecast-v2-1.0.0`
- Materialization commit: `8eec5d39159907c7606224fc848c7dc305308515`
- Source registry SHA-256: `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`
- Candidate rows audited: `128`
- Complete article cells: `36/36`
- Metrics improved relative to the prior article baseline: `36`

## Policy

This artifact implements the explicitly requested status-agnostic promotion policy.
Diagnostic status is never discarded: each displayed metric retains its own candidate,
run tag, source path, source hash, status, and signoff grade.

The envelope is metric-wise. A row may combine the best fit RMSE, forecast MAE, and
forecast check loss from different calibrated candidates. It must therefore be described
as a calibrated metric envelope, not as the output of one common fitted specification.

## Outputs

- Article envelope: `qdesn_dqlm_500obs_mcmc_metric_envelope_20260726_article_envelope.csv`
- Metric promotions: `qdesn_dqlm_500obs_mcmc_metric_envelope_20260726_promotions.csv`
- Metric winners with provenance: `qdesn_dqlm_500obs_mcmc_metric_envelope_20260726_metric_winners.csv`
- Next-screen handoff: `qdesn_dqlm_500obs_mcmc_metric_envelope_20260726_targeted_screening_handoff.csv`
- Manifest: `qdesn_dqlm_500obs_mcmc_metric_envelope_20260726_manifest.json`

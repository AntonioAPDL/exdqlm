# Five-Chain Q-DESN Robustness Sensitivity

This immutable bundle closes the Normal, p=0.25 five-chain confirmation
for independent single-quantile Q-DESN AL-RHS and exAL-RHS models.

The estimator is the coordinatewise median of five chain-specific posterior
point paths. Metrics are recomputed from that path. It is not pooled
posterior draws and must never be described as such.

The campaign completed 12/12 fresh fits and 11/11 five-chain designs with
zero unexpected model binaries. Five robust metric values are below the
frozen article-v3 single-chain metric envelope. The article table remains
unchanged because direct replacement would silently mix estimators.

Run tag: `qdesn-cagc1-full-20260808_161301__git-8cfd304`
Source branch: `validation/qdesn-mcmc-chain-aggregate-confirm-v1-1.0.0`
Source commit: `8cfd304c5d2eb9af76195998a3ef097ec79b801f`
Registry hash: `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`
Decision: `ROBUST_SENSITIVITY_CONFIRMED_ARTICLE_TABLE_UNCHANGED`
Manifest: `qdesn_500obs_mcmc_chain_aggregate_sensitivity_v1_20260808_manifest.json`

A future article update must either present this as a disclosed robustness
sensitivity or recompute every displayed MCMC model under one matched
multi-chain estimator policy.

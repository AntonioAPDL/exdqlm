# Corrected 500-Observation Article Handoff

This promotion is the immutable article-facing interface for the independent
single-quantile 500-observation comparison. It contains 72 rows: four models,
three innovation families, three quantile levels, and two inference methods.

Q-DESN and exQ-DESN rows use the exact train-only preprocessing replay. DQLM
and exDQLM rows retain their validated structured-model baselines. Historical
ridge rows are excluded because they have not been replayed under the corrected
preprocessing contract.

- Interface: `qdesn_dqlm_500obs_trainonly_article_v1_20260805_interface.csv`
- Interface SHA-256: `dff814fab1e920c10760645ac9e8d37dfa7f33ae2afba34ee8ed2a5509f4952a`
- Source registry SHA-256: `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`
- Forecast protocol: rolling origin, no refit, state update, leads 1-30, stride 30
- Training source indices: 8501-9000
- Forecast source indices: 9001-10000

The two aborted VB orchestration IDs listed in the manifest are non-consumable.

# Q-DESN TT500 MCMC Authoritative Handoff

This directory materializes the June 30, 2026 Q-DESN TT500 MCMC confirmation and rescue outputs as a compact, article-facing promotion artifact.

Promotion status: `authoritative_article_facing_diagnostic_qualified`.

The handoff is artifact-complete and storage-light, but not diagnostic-clean. Two selected cells remain `FAIL` because of high autocorrelation and seven cells remain `WARN`; those grades are intentionally retained in the summary and manifest.

Selected rows use rescue outputs where available and base confirmation outputs otherwise.

- Summary CSV: `qdesn_tt500_mcmc_authoritative_summary.csv`
- Summary SHA-256: `3272c426c4844afc188099f8e63c3d4f442729ee851a0c2347afe7fdff70025d`
- Source CSV: `qdesn_tt500_mcmc_authoritative_sources.csv`
- Source CSV SHA-256: `7622a04e02ea3192079bf6d4c1528d26083a22d76a6ca91830c0b2f64a6cae5a`
- Manifest: `qdesn_tt500_mcmc_authoritative_manifest.json`
- Manifest SHA-256: `479e4f59b5d6c8eafcadc06a01eaa6951ab44852e40ab6b17f97be8a172cf8a4`

The forecast protocol is rolling-origin, no-refit, observed-lag state update with `Hmax = 30` and origin stride `30` over source indices `9001:10000`.

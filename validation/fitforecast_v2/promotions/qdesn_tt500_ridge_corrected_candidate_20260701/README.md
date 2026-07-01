# Q-DESN TT500 Ridge Corrected Candidate

This directory materializes the July 1, 2026 Q-DESN TT500 ridge corrected-DESN relaunch as a compact, article-facing candidate artifact.

Promotion status: `candidate_partial_diagnostic_clean`.

Execution is complete and storage-light. VB ridge and MCMC AL ridge are candidate-promotable. MCMC exAL ridge is retained with explicit diagnostic debt because four rows remain `FAIL` for high autocorrelation and four rows remain `WARN`.

- Summary CSV: `qdesn_tt500_ridge_corrected_candidate_summary.csv`
- Summary SHA-256: `d5597eadf3f73d0ca4b1875dc6771ceb9e9f5f467dd1b36cdac4cc5dc1045a17`
- Source CSV: `qdesn_tt500_ridge_corrected_candidate_sources.csv`
- Source CSV SHA-256: `b63022a560ac97b61b2e39f8cdab9c8b572ea414752fb9a21e80320ec3efe227`
- Manifest: `qdesn_tt500_ridge_corrected_candidate_manifest.json`
- Manifest SHA-256: `90c29593925f101754fdd9fcae0f8875cc3d230eefae742eaee7fbf759808fbc`

The forecast protocol is rolling-origin, no-refit, observed-lag state update with `Hmax = 30` and origin stride `30` over source indices `9001:10000`.

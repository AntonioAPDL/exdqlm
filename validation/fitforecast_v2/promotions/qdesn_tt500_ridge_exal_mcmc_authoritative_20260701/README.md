# Q-DESN TT500 Ridge exAL MCMC Authoritative Handoff

This directory materializes the July 1, 2026 ridge exAL MCMC diagnostic-rescue run as the article-facing TT500 ridge exAL MCMC handoff.

Promotion status: `authoritative_article_facing_tt500`.
Diagnostic qualification: `diagnostic_qualified_authoritative_mcmc_with_explicit_flags`.

All nine completed rows are promoted by decision, with `signoff_grade` and `signoff_reason` preserved rather than hidden. Rows that were not source comparison-eligible because of diagnostics are intentionally marked article-facing `comparison_eligible = TRUE` in the promotion summary.

- Summary CSV: `qdesn_tt500_ridge_exal_mcmc_authoritative_summary.csv`
- Summary SHA-256: `8423e373e082515dcb5a5980176d75a1b1a69146da9e66bbfff0cf2d69c52ded`
- Source CSV: `qdesn_tt500_ridge_exal_mcmc_authoritative_sources.csv`
- Source CSV SHA-256: `07389d247f4f3ba4c631cc6c7f626c10b7ee862256bfa8b942588b061a3f6da2`
- Manifest: `qdesn_tt500_ridge_exal_mcmc_authoritative_manifest.json`
- Manifest SHA-256: `5e3ad97fa997fb0699410548eab37a0e216f648bb631bba162764e8145e08a15`

The forecast protocol is rolling-origin, no-refit, observed-lag state update with `Hmax = 30` and origin stride `30` over source indices `9001:10000`.

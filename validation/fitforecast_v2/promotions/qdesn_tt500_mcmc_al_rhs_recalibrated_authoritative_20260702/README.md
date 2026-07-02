# Q-DESN TT500 MCMC AL RHS Recalibrated Authoritative Handoff

This directory materializes the July 2, 2026 Q-DESN AL RHS MCMC recalibration run as the article-facing TT500 AL RHS MCMC handoff.

Promotion status: `authoritative_article_facing_diagnostic_qualified`.
Diagnostic qualification: `diagnostic_qualified_authoritative_mcmc_al_rhs_recalibrated`.

The source run completed all nine family/quantile cells. One row is `PASS`; eight rows are `WARN` with `chain_marginal_but_usable`. The warnings are preserved in the summary rather than hidden.

- Summary CSV: `qdesn_tt500_mcmc_al_rhs_recalibrated_authoritative_20260702_summary.csv`
- Summary SHA-256: `a24de53f8d24111e21785c0eec5b6c40973a0bbb7494060c16135a9062ba5063`
- Source CSV: `qdesn_tt500_mcmc_al_rhs_recalibrated_authoritative_20260702_sources.csv`
- Source CSV SHA-256: `754e80d4e808098ab76756e7979fbc6bf64844e65241714071d452e5fe139361`
- Manifest: `qdesn_tt500_mcmc_al_rhs_recalibrated_authoritative_20260702_manifest.json`
- Manifest SHA-256: `301ab838dfed94ef1994cb5e0d90506abb0c2ceec35c71dea1437cea06a21fb9`

The forecast protocol is rolling-origin, no-refit, observed-lag state update with `Hmax = 30` and origin stride `30` over source indices `9001:10000`.

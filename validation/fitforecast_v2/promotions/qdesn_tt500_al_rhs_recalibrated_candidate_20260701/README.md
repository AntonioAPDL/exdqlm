# Q-DESN TT500 AL RHS Recalibrated Candidate

This directory materializes the July 1, 2026 Q-DESN TT500 AL RHS VB recalibration screen as a compact, article-facing candidate artifact.

Promotion status: `candidate_partial_screen_clean`.

The full Wave A screen ran 216 roots. It produced 153 successful roots and 63 failed exploratory roots. Every failure used `rhs_tau0 = 3e-05`; all `1e-04` and `3e-04` candidates succeeded. The 9 promoted rows are success-only, cell-specific winners that improve both forecast MAE and pinball versus the old AL RHS rows.

- Summary CSV: `qdesn_tt500_al_rhs_recalibrated_candidate_20260701_summary.csv`
- Summary SHA-256: `1dc5de595092551d749f03df509f1a9697f54c98be2bba34f4c51750c1a59d30`
- Source CSV: `qdesn_tt500_al_rhs_recalibrated_candidate_20260701_sources.csv`
- Source CSV SHA-256: `9dddd2697b916527b289562fceb43ee4e5498894e6f730f726a42ff12bcc52ab`
- Excluded failures CSV: `qdesn_tt500_al_rhs_recalibrated_candidate_20260701_excluded_failures.csv`
- Excluded failures SHA-256: `8b932e3629b9e49dba55aa26ad9cc8ba9d43f7cd7cf71aa4b92967da679d7cc1`
- Manifest: `qdesn_tt500_al_rhs_recalibrated_candidate_20260701_manifest.json`
- Manifest SHA-256: `8e17f332e291754a6ca67bfa0740aa93ee6d2164d2db5986122f0f0934940728`

The forecast protocol is rolling-origin, no-refit, observed-lag state update with `Hmax = 30` and origin stride `30` over source indices `9001:10000`.

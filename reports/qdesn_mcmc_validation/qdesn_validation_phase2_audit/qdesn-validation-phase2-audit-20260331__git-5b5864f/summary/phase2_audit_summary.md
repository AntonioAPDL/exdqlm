# QDESN Validation Phase 2 Audit Summary

- generated_at: `2026-03-31 10:27:59.991386`
- git_sha: `5b5864f`
- output_root: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/reports/qdesn_mcmc_validation/qdesn_validation_phase2_audit/qdesn-validation-phase2-audit-20260331__git-5b5864f`

## Main Findings

- Wave 1 remained operationally clean: `4/4` profiles completed, `0` errors, `0` timeouts.
- The severe quartet stayed intact across all profiles; best candidates still had `severe_fail_n = 4`.
- The persistent hard root is `dlm_constV_bigW @ tau=0.05 exal ridge`.
- On the hard root, the anchor kept a mixed failure (`ESS=6.80`, `half_drift=0.795`), while `R1` traded that into stronger gamma half-drift (`1.061`) and `R3` drifted on gamma even harder (`1.021`).
- Conditioning is material but not sufficient by itself: `dlm_constV_smallW` has the worst raw design conditioning (`cond_num=884.33`), but the same design key appears in both a severe root and a sentinel root.

## Artifacts

- `tables/hard_root_profile_metrics.csv`
- `tables/hard_root_signoff_metrics.csv`
- `tables/hard_root_chain_parameter_metrics.csv`
- `tables/severe_quartet_profile_metrics.csv`
- `tables/tiny_d1_n8_conditioning_by_root.csv`
- `tables/tiny_d1_n8_conditioning_by_design.csv`
- `tables/tiny_d1_n8_root_design_map.csv`

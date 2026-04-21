## QDESN Tau050 Final Analysis Report Pack Outputs

Date: `2026-04-21`  
Status: canonical clean-SHA final post-recovery tau050 analysis/report pack completed from implementation commit `9674da6`

## Canonical Run

- implementation commit: `9674da6`
- source study-facing root:
  - [tau050 recovered study-facing root](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_recovered_study_facing_analysis/qdesn-dynamic-exdqlm-crossstudy-tau050-studyfacing-20260421-030134__git-2a9c078)
- source recovered comparison root:
  - [tau050 recovered main-comparison root](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_recovered_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-tau050-recovered-maincmp-20260421-024204__git-86be927)
- final-pack run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-tau050-finalpack-20260421-031506__git-9674da6`
- final-pack root:
  - [tau050 final analysis pack root](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_final_analysis_pack/qdesn-dynamic-exdqlm-crossstudy-tau050-finalpack-20260421-031506__git-9674da6)

Primary outputs:

- [headline final report](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_final_analysis_pack/qdesn-dynamic-exdqlm-crossstudy-tau050-finalpack-20260421-031506__git-9674da6/summary/qdesn_tau050_final_analysis_report.md)
- [main tables](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_final_analysis_pack/qdesn-dynamic-exdqlm-crossstudy-tau050-finalpack-20260421-031506__git-9674da6/summary/qdesn_tau050_final_main_tables.md)
- [diagnostic appendix](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_final_analysis_pack/qdesn-dynamic-exdqlm-crossstudy-tau050-finalpack-20260421-031506__git-9674da6/summary/qdesn_tau050_final_diagnostic_appendix.md)
- [strict reference-alignment decision](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_final_analysis_pack/qdesn-dynamic-exdqlm-crossstudy-tau050-finalpack-20260421-031506__git-9674da6/summary/qdesn_tau050_strict_reference_alignment_decision.md)

## Headline Outcome

| Surface | Rows | PASS | WARN | FAIL | Read |
|---|---:|---:|---:|---:|---|
| representative surface | 36 | 33 | 3 | 0 | canonical study-facing narrative layer |
| aligned reference surface | 24 | 24 | 0 | 0 | strict QDESN-vs-reference deltas available |
| full recovered fit inventory | 144 | 77 | 27 | 40 | diagnostic appendix only |

## Main Read

This final pack cleanly closes the post-recovery tau050 analysis loop:

- the representative layer is now the canonical study/report surface
- the full 144-fit recovered surface is retained only as appendix diagnostics
- strict mirrored-reference tau `0.50` alignment is documented as optional and not launched now

## Representative Surface

### Representative scorecard by prior/model

| Prior | Model | Rows | PASS | WARN | FAIL | Mean runtime (sec) | Mean holdout qtrue MAE |
|---|---|---:|---:|---:|---:|---:|---:|
| `rhs_ns` | `al` | 12 | 9 | 3 | 0 | 20.864 | 3.559 |
| `rhs_ns` | `exal` | 6 | 6 | 0 | 0 | 45.429 | 1146.167 |
| `ridge` | `al` | 12 | 12 | 0 | 0 | 10.372 | 73.895 |
| `ridge` | `exal` | 6 | 6 | 0 | 0 | 27.427 | 31.900 |

The key operational/presentation interpretation remains:

- `ridge` is the clean primary comparison prior
- `rhs_ns` remains the stress-test prior
- the representative layer is still entirely `vb`

### Figure set

Generated figures:

- [representative grade mix](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_final_analysis_pack/qdesn-dynamic-exdqlm-crossstudy-tau050-finalpack-20260421-031506__git-9674da6/plots/tau050_representative_grade_mix_by_prior_model.png)
- [representative performance](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_final_analysis_pack/qdesn-dynamic-exdqlm-crossstudy-tau050-finalpack-20260421-031506__git-9674da6/plots/tau050_representative_performance_by_prior_model.png)
- [reference alignment by tau](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_final_analysis_pack/qdesn-dynamic-exdqlm-crossstudy-tau050-finalpack-20260421-031506__git-9674da6/plots/tau050_reference_alignment_by_tau.png)
- [diagnostic fail rate by method/prior](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_final_analysis_pack/qdesn-dynamic-exdqlm-crossstudy-tau050-finalpack-20260421-031506__git-9674da6/plots/tau050_diagnostic_fail_rate_by_method_prior.png)

## Strict Reference Alignment Decision

Decision row from the canonical pack:

| Decision | Strict alignment required | Launch now | Gap tau values | Read |
|---|---|---|---|---|
| `do_not_launch_now` | `FALSE` | `FALSE` | `0.5` | representative layer is already clean; tau `0.50` rows can remain descriptive until/unless a manuscript needs like-for-like deltas |

This is the direct implementation of the “do 1 to 4” policy:

1. use the recovered study-facing pack as the canonical presentation source
2. build the final study/report tables and figures from the representative layer
3. keep the 144-fit recovered inventory as the diagnostic appendix
4. do **not** launch strict mirrored-reference tau `0.50` alignment unless it becomes a real downstream requirement

## Diagnostic Appendix

The appendix still captures the residual soft spots without elevating them into the headline story.

Most important diagnostic read:

- remaining softness is still concentrated in `mcmc rhs_ns`
- this is fit-quality/signoff softness, not runtime failure
- the appendix is now bounded and reproducible instead of mixed into the main narrative

## Recommended Forward Path

The best next move is no longer compute. It is interpretation and study/report integration:

1. use the final analysis pack as the canonical tau050 reporting surface
2. take the main narrative and figures from the representative layer
3. keep the appendix tables for diagnostics and reviewer-facing detail
4. only revisit strict tau `0.50` reference alignment if a downstream deliverable explicitly requires it

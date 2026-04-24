# QDESN Dynamic P90 Steeper-Trend Closeout And Main Comparison

- generated_at: `2026-04-24 04:54:22.97541`
- git_sha: `f3c46a3`
- closeout_output_root: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_closeout_analysis/qdesn-dynamic-p90-steepertrend-closeout-20260424-045352__git-f3c46a3`

## Final Launch State
- Ridge full: `18 / 18` roots and `72 / 72` fits completed.
- RHS-NS full: `18 / 18` roots and `72 / 72` fits completed, combining the preserved parent roots with the optimized continuation wave.
- Full main program: `36 / 36` roots and `144 / 144` fits completed.

## Numerical Failure Check
- root_level_failures: `0`
- completed_fits_status_not_success: `0`
- error_or_crash_files_found: `0`
- confirmed_numerical_runtime_crashes: `0`

## Main Outputs
- summary: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_closeout_analysis/qdesn-dynamic-p90-steepertrend-closeout-20260424-045352__git-f3c46a3/summary/qdesn_dynamic_p90_steepertrend_closeout.md`
- authoritative fit table: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_closeout_analysis/qdesn-dynamic-p90-steepertrend-closeout-20260424-045352__git-f3c46a3/tables/authoritative_fit_summary.csv`
- pairwise deltas: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_closeout_analysis/qdesn-dynamic-p90-steepertrend-closeout-20260424-045352__git-f3c46a3/tables/pairwise_delta_summary.csv`
- figure index: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_closeout_analysis/qdesn-dynamic-p90-steepertrend-closeout-20260424-045352__git-f3c46a3/tables/figure_index.csv`

## Headline Signoff
| prior | n | pass_n | warn_n | fail_n | pass_rate | warn_rate | fail_rate | comparison_eligible_rate |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| rhs_ns | 72 | 33 | 16 | 23 | 0.458 | 0.222 | 0.319 | 0.681 |
| ridge | 72 | 42 | 15 | 15 | 0.583 | 0.208 | 0.208 | 0.792 |

## Next Read
- The relaunch validates runtime/numerical stability on the new p90 steeper-trend dynamic surface.
- The scientific bottleneck remains diagnostic quality, especially MCMC autocorrelation, rather than numerical failure.
- The next analysis pass should focus on whether the current diagnostic thresholds should trigger targeted MCMC rescue overlays for the affected fit families.

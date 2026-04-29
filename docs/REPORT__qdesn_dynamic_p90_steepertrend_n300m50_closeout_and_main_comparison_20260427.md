# QDESN Dynamic P90 Steeper-Trend N300/M50 Closeout And Main Comparison

- generated_at: `2026-04-28 20:14:28.99431`
- git_sha: `f282f63`
- manifest: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_p90_steepertrend_n300m50_closeout_analysis_manifest.yaml`
- closeout_output_root: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_closeout_analysis/qdesn-dynamic-p90-steepertrend-n300m50-closeout-analysis-20260428-201418__git-f282f63`

## Final Launch State
- Observed roots: `36 / 36`.
- Observed fits: `144 / 144`.
- Priors: `ridge`, `rhs_ns`.
- Inference engines: `vb`, `mcmc`.
- Likelihood/readout families: `al`, `exal`.

## Numerical Failure Check
- observed_roots: `36 / 36`
- observed_fits: `144 / 144`
- completed_fits_status_not_success: `0`
- finite_check_failures: `22`
- domain_check_failures: `22`
- confirmed_nonfinite_or_domain_failures: `44`
- error_or_crash_files_found: `0`
- confirmed_numerical_runtime_crashes: `0`

## Main Outputs
- summary: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_closeout_analysis/qdesn-dynamic-p90-steepertrend-n300m50-closeout-analysis-20260428-201418__git-f282f63/summary/qdesn_dynamic_p90_steepertrend_closeout.md`
- authoritative fit table: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_closeout_analysis/qdesn-dynamic-p90-steepertrend-n300m50-closeout-analysis-20260428-201418__git-f282f63/tables/authoritative_fit_summary.csv`
- pairwise deltas: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_closeout_analysis/qdesn-dynamic-p90-steepertrend-n300m50-closeout-analysis-20260428-201418__git-f282f63/tables/pairwise_delta_summary.csv`
- figure index: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_closeout_analysis/qdesn-dynamic-p90-steepertrend-n300m50-closeout-analysis-20260428-201418__git-f282f63/tables/figure_index.csv`

## Headline Signoff
| prior | n | pass_n | warn_n | fail_n | pass_rate | warn_rate | fail_rate | comparison_eligible_rate |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| rhs_ns | 72 | 31 | 3 | 38 | 0.431 | 0.042 | 0.528 | 0.472 |
| ridge | 72 | 18 | 23 | 31 | 0.250 | 0.319 | 0.431 | 0.569 |

## Next Read
- The relaunch validates runtime/numerical stability on the new p90 steeper-trend dynamic surface.
- The scientific bottleneck remains diagnostic quality, especially MCMC autocorrelation, rather than numerical failure.
- The next analysis pass should focus on whether the current diagnostic thresholds should trigger targeted MCMC rescue overlays for the affected fit families.

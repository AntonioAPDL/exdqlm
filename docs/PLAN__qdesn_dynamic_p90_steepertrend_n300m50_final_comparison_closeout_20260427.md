# QDESN Dynamic P90 Steeper-Trend N300/M50 Final Comparison Closeout Plan

Date: 2026-04-27
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`

## Objective

Close the full n300/m50 QDESN dynamic validation campaign with a reproducible
comparison layer matching the prior analysis standard:

- compare `VB` vs `MCMC`
- compare `EXAL` vs `AL`
- compare `RHS-NS` vs `ridge`
- report signoff grades, metric distributions, pairwise deltas, runtime, and
  explicit numerical-failure checks
- produce quantile-fit uncertainty figures against the known simulated target
  quantile path

## Campaign Under Closeout

- run tag: `qdesn-dynamic-p90-steepertrend-n300m50-full-20260424-172949__git-366ca13`
- campaign results root: `results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation/qdesn-dynamic-p90-steepertrend-n300m50-full-20260424-172949__git-366ca13/20260424-172958__git-366ca13`
- campaign reports root: `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation/qdesn-dynamic-p90-steepertrend-n300m50-full-20260424-172949__git-366ca13`
- expected roots: `36`
- expected fits: `144`
- datasets: period-90 steeper-trend dynamic surface, `18` effective source windows
- reservoir profile: `deep_d3_n300x3_skip100_w300_m50`

## Tracker

- [x] Preserve the signoff repair code path for class-preserving MCMC VB-init pruning.
- [x] Preserve structural validation recognition for classless saved fit objects.
- [x] Add a single-campaign n300/m50 closeout manifest.
- [x] Generalize the closeout loader so it supports root-summary globs and legacy split-run manifests.
- [x] Add a dedicated runner for the n300/m50 closeout analysis.
- [x] Add a guarded finalizer that runs repair, campaign collection, and closeout after all roots are successful.
- [x] Wait for the final root to complete.
- [x] Run the final saved-output signoff repair across all `36` roots.
- [x] Recollect campaign tables after repair so the comparison uses authoritative CSVs.
- [x] Run the closeout analysis from the manifest.
- [x] Review generated tables and figures.
- [x] Update the final report with the produced output root and headline interpretation.
- [x] Register the run as the official baseline for future QDESN spec relaunches.

## Required Final Gates

- `36 / 36` roots have `manifest/root_status.txt = SUCCESS`
- `144 / 144` fit rows are present after repair
- `completed_fits_status_not_success = 0`
- `finite_check_failures = 0`
- `domain_check_failures = 0`
- hard runtime crash count remains `0`
- generated figure index includes signoff, metric, delta, and quantile-uncertainty figures

## Reproducible Commands

Preferred one-command finalizer after the launcher exits:

```bash
Rscript scripts/finalize_qdesn_dynamic_p90_steepertrend_n300m50_closeout.R
```

The finalizer refuses to continue unless all `36` roots have
`manifest/root_status.txt = SUCCESS`.

Manual final repair command if needed:

```bash
Rscript scripts/repair_qdesn_dynamic_crossstudy_signoff_from_saved_outputs.R \
  --results-root results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation/qdesn-dynamic-p90-steepertrend-n300m50-full-20260424-172949__git-366ca13 \
  --report-root reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation/qdesn-dynamic-p90-steepertrend-n300m50-full-20260424-172949__git-366ca13/signoff_repair_final_20260427
```

Run final closeout:

```bash
Rscript scripts/run_qdesn_dynamic_p90_steepertrend_n300m50_closeout_analysis.R
```

The closeout runner uses:

- `config/validation/qdesn_dynamic_p90_steepertrend_n300m50_closeout_analysis_manifest.yaml`
- `R/qdesn_dynamic_p90_steepertrend_closeout_analysis.R`

## Final State

The comparison analysis is now complete and should be treated as the official
baseline for future QDESN relaunches until a newer run is intentionally
promoted.

- closeout root: `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_closeout_analysis/qdesn-dynamic-p90-steepertrend-n300m50-closeout-analysis-20260428-201418__git-f282f63`
- official baseline config: `config/validation/qdesn_dynamic_p90_steepertrend_n300m50_official_baseline.yaml`
- official baseline report: `docs/BASELINE__qdesn_dynamic_p90_steepertrend_n300m50_20260428.md`

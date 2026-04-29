# QDESN Dynamic P90 Steeper-Trend N300/M50 Official Baseline

- established_at: 2026-04-28
- branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`
- baseline config: `config/validation/qdesn_dynamic_p90_steepertrend_n300m50_official_baseline.yaml`
- source defaults: `config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_defaults.yaml`

## Baseline Role

This run is the official QDESN dynamic validation baseline for future
144-fit relaunches using new QDESN specifications. It is complete, documented,
post-cleanup reproducible, and small enough to preserve while using compact
fit-path artifacts instead of full successful `forecast_objects.rds` payloads.

Future validation studies should compare against the closeout tables from this
baseline unless we intentionally promote a newer run.

## Authoritative Outputs

- results root: `results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation/qdesn-dynamic-p90-steepertrend-n300m50-full-20260424-172949__git-366ca13/20260424-172958__git-366ca13`
- campaign report root: `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation/qdesn-dynamic-p90-steepertrend-n300m50-full-20260424-172949__git-366ca13/20260424-172958__git-366ca13`
- closeout root: `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_closeout_analysis/qdesn-dynamic-p90-steepertrend-n300m50-closeout-analysis-20260428-201418__git-f282f63`
- authoritative fit summary: `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_closeout_analysis/qdesn-dynamic-p90-steepertrend-n300m50-closeout-analysis-20260428-201418__git-f282f63/tables/authoritative_fit_summary.csv`
- pairwise deltas: `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_closeout_analysis/qdesn-dynamic-p90-steepertrend-n300m50-closeout-analysis-20260428-201418__git-f282f63/tables/pairwise_delta_summary.csv`
- figure index: `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_closeout_analysis/qdesn-dynamic-p90-steepertrend-n300m50-closeout-analysis-20260428-201418__git-f282f63/tables/figure_index.csv`

## Study Surface

| Axis | Baseline value |
|---|---|
| Scenario | `dlm_constV_p90_m0amp_highnoise_steepertrend_v1` |
| Families | `gausmix`, `laplace`, `normal` |
| Taus | `0.05`, `0.25`, `0.50` |
| Effective fit sizes | `500`, `5000` |
| Source total sizes | `813`, `5313` |
| Priors | `ridge`, `rhs_ns` |
| Inference engines | `vb`, `mcmc` |
| Likelihood families | `al`, `exal` |
| Expected roots / fits | `36 / 144` |

The effective train sizes use a `300`-point QDESN washout. The TT500 window is
materialized from `813` source points and the TT5000 window from `5313` source
points, so the retained post-washout fit horizons remain `500` and `5000`.

## DESN And Inference Specs

The promoted DESN profile is `deep_d3_n300x3_skip100_w300_m50`:

| Field | Value |
|---|---|
| Layers | `3` |
| Neurons per layer | `300, 300, 300` |
| Bridge widths | `300, 300` |
| Random features | `50` |
| Alpha per layer | `0.25, 0.25, 0.25` |
| Rho per layer | `0.95, 0.95, 0.95` |
| State activation | `tanh, tanh, tanh` |
| Bridge activation | `identity, identity, identity` |
| Washout | `300` |
| DESN seed | `123` |

The baseline used `20,000` posterior metric draws, `20,000` VB synthesis draws,
`VB max_iter = 300`, `MCMC n_burn = 5000`, `MCMC n_mcmc = 20000`, slice MCMC,
and LDVB warm starts for MCMC. Successful MCMC outputs do not persist the
intermediate VB-init fit artifact.

## Retention And Cleanup

This baseline is preserved in `analysis` retention form:

| Check | Result |
|---|---:|
| Compact train path tables | `144 / 144` |
| Compact holdout path tables | `144 / 144` |
| Successful `forecast_objects.rds` files remaining | `0` |
| Results root size after cleanup | about `430 MiB` |
| Campaign report root size | about `134 MiB` |
| Closeout root size | about `4.3 MiB` |
| Scoped binary cleanup freed | `149.69 GiB` |
| Old progress trace cleanup freed | `0.39 GiB` |

Cleanup audit manifests:

- `reports/qdesn_mcmc_validation/storage_cleanup/qdesn_p90_n300m50_scoped_payload_cleanup_execute_20260428/cleanup_summary.md`
- `reports/qdesn_mcmc_validation/storage_cleanup/qdesn_p90_n300m50_postcleanup_zero_verification_20260428/cleanup_summary.md`
- `reports/qdesn_mcmc_validation/storage_cleanup/qdesn_validation_global_payload_cleanup_dryrun_20260428/cleanup_summary.md`
- `reports/qdesn_mcmc_validation/storage_cleanup/qdesn_validation_old_progress_trace_cleanup_20260428/cleanup_summary.md`

The only remaining local file above 10 MB in `results/qdesn_mcmc_validation`
or `reports/qdesn_mcmc_validation` is the official baseline campaign progress
trace. It is intentionally preserved.

## Closeout Status

| Check | Result |
|---|---:|
| Observed roots | `36 / 36` |
| Observed fits | `144 / 144` |
| Fit status not success | `0` |
| Runtime crash files found | `0` |
| Confirmed runtime crashes | `0` |
| Signoff PASS | `49` |
| Signoff WARN | `26` |
| Signoff FAIL | `69` |

The signoff failures are diagnostic-quality failures in completed fits, not
missing roots or runtime crashes. This is why the run is valid as a baseline
for comparing future QDESN specifications: future specs should aim to improve
the quality diagnostics while preserving the numerical stability and complete
coverage achieved here.

## Future Relaunch Rules

- Use this baseline's closeout tables as the default comparison target.
- Use `retention_profile: analysis` for full validation relaunches unless a run
  is explicitly a debugging run.
- Keep compact train/holdout path tables for all successful fits so uncertainty
  figures can be regenerated without full RDS payloads.
- Retain full RDS payloads for failures and selected debug runs only.
- Do not delete this baseline's results root, campaign report root, closeout
  root, cleanup manifests, source datasets, or compact fit-path tables.

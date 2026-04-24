# QDESN Dynamic P90 Steeper-Trend Post-Closeout Cleanup And Current Relaunch Spec

Date: 2026-04-24
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`
Closed campaign: `qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_validation`

## 1) Closed Campaign State

The p90 steeper-trend QDESN validation campaign is closed as a completed
validation artifact.

Final campaign read:

- ridge full: `18 / 18` roots and `72 / 72` fits complete
- RHS-NS full: `18 / 18` roots and `72 / 72` fits complete
- combined program: `36 / 36` roots and `144 / 144` fits complete
- hard numerical/runtime failures: `0`
- completed fits with `status != SUCCESS`: `0`

Primary closeout output:

- `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_closeout_analysis/qdesn-dynamic-p90-steepertrend-closeout-20260424-045352__git-f3c46a3`

Tracked closeout references:

- `docs/REPORT__qdesn_dynamic_p90_steepertrend_closeout_and_main_comparison_20260424.md`
- `docs/TRACK__qdesn_dynamic_p90_steepertrend_72case_relaunch_20260422.md`
- `config/validation/qdesn_dynamic_p90_steepertrend_closeout_analysis_manifest.yaml`

## 2) Storage Cleanup

The cleanup removed reproducible fit-object payloads while preserving the
essential audit surface.

Cleanup script:

- `scripts/cleanup_qdesn_validation_rds_payloads.sh`

Executed cleanup roots:

- `reports/qdesn_mcmc_validation/storage_cleanup/20260424_post_p90_payload_cleanup_execute`
- `reports/qdesn_mcmc_validation/storage_cleanup/20260424_post_p90_report_payload_cleanup_execute`

Removed payload classes:

- `models/forecast_objects.rds`
- `models/rhs_trace.rds`
- `models/timing_summary.rds`

Cleanup totals:

| Pass | Files deleted | Freed |
|---|---:|---:|
| QDESN validation `results/` payloads | `687` | `206.92 GiB` |
| QDESN validation `reports/` payloads | `20` | `1.51 GiB` |
| Combined | `707` | `208.43 GiB` |

Post-cleanup verification:

- remaining target payload files under QDESN validation `results/` and
  `reports/`: `0`
- remaining `.rds`/`.RData`-style files in repo: `222`
- remaining `.rds`/`.RData` footprint: `0.021 GiB`
- `.RData/.rdata` files requiring manual review: `0`
- `/home` free space after cleanup: about `351 GiB`

Preserved material:

- source dataset surfaces and `sim_output.rds` source artifacts
- tracked package data under `data/*.rda`
- configs, grids, launchers, runners, healthchecks, tests, docs
- CSV summaries, logs, figures, closeout reports, and cleanup manifests

## 3) Current Relaunch Spec To Modify

This is the current exact QDESN spec that produced the completed 144-fit
program. The next relaunch should fork from this contract and change only the
parts we explicitly decide to change.

Primary defaults:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_defaults.yaml`

Primary grid:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_full_grid.csv`

Launch wrappers:

- `scripts/run_qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_validation.R`
- `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_validation.R`
- `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_validation.R`

Dataset contract:

| Field | Current value |
|---|---|
| Scenario | `dlm_constV_p90_m0amp_highnoise_steepertrend_v1` |
| Families | `gausmix`, `laplace`, `normal` |
| Taus | `0.05`, `0.25`, `0.50` |
| Full dynamic roots | `9` |
| Effective source windows | `18` |
| Priors | `ridge`, `rhs_ns` |
| Expanded fits | `144` |
| Effective sizes | `500`, `5000` |
| Source totals | `813`, `5313` |
| Holdout | `1` |
| Max lag | `12` |
| Washout | `300` |

The staged totals are intentionally larger than the effective sizes:

- `813 = 500 + 300 washout + 12 lag + 1 holdout`
- `5313 = 5000 + 300 washout + 12 lag + 1 holdout`

Reservoir/readout contract:

| Field | Current value |
|---|---|
| Reservoir profile | `deep_d3_n100x3_skip100_w300_m30` |
| Depth `D` | `3` |
| Reservoir widths | `100, 100, 100` |
| Bridge widths `n_tilde` | `100, 100` |
| Random features `m` | `30` |
| Leak/alpha | `0.2, 0.2, 0.2` |
| Spectral radius/rho | `0.95, 0.95, 0.95` |
| State activation | `tanh, tanh, tanh` |
| Bridge activation | `identity, identity, identity` |
| Sparse recurrent probability `pi_w` | `0.1, 0.1, 0.1` |
| Input probability `pi_in` | `1.0, 1.0, 1.0` |
| Reservoir washout | `300` |
| Add bias | `true` |
| Reservoir seed | `123` |
| Readout input inclusion | `include_input = true` |
| Input mode | `raw_y_lags` |
| Input position | `after_reservoir` |
| Reservoir lags | `1` |
| Response lags `m_y` | `12` |
| Exogenous lags `m_x` | `0` |
| Preprocessing | `scale_y = true`, `scale_x = true` |

Shared inference budget:

| Field | Current value |
|---|---:|
| VB method | `LDVB` |
| VB max iterations | `300` |
| VB minimum ELBO iterations | `80` |
| VB `n_samp_xi` | `1000` |
| VB posterior/synthesis draws | `20000` |
| MCMC kernel | `slice` |
| MCMC burn-in | `5000` |
| MCMC kept draws | `20000` |
| MCMC thinning | `1` |
| MCMC init | `init_from_vb = true` |
| MCMC VB warm-start method | `LDVB` |
| Posterior metric draws | `20000` |

Warmup policy:

| Area | Current value |
|---|---|
| VB EXAL `(sigma, gamma)` warmup | freeze `10` iterations |
| VB post-warmup `(sigma, gamma)` damping | `0.5` for `3` iterations |
| MCMC EXAL `(sigma, gamma)` warmup | freeze `50` burn-in iterations |
| MCMC EXAL adaptation delay | delay adaptation and Laplace refresh until after warmup |
| VB RHS/RHS-NS tau warmup | freeze `50` iterations |
| VB RHS/RHS-NS tau local tolerance | `5.0e-4` |
| VB RHS/RHS-NS minimum tau updates | `2` |
| MCMC RHS/RHS-NS tau warmup | freeze `500` burn-in iterations |
| MCMC RHS/RHS-NS width adaptation | disabled |

Prior contract:

| Prior block | Current value |
|---|---|
| `gamma` | `mu0 = 0`, `s20 = 10` |
| `sigma` | `a = 1`, `b = 1` |
| `ridge` | `tau2 = 20` |
| `rhs_ns` | `tau0 = 0.01`, `a_zeta = 2`, `b_zeta = 1`, `s2 = 0.5` |
| `rhs_ns` intercept | `shrink_intercept = false`, `intercept_prec = 1.0e-10` |
| `rhs_ns` numerical guards | `n_inner = 2`, `var_floor = 1.0e-8` |

Current slice tuning:

| Surface | Current value |
|---|---|
| Shared core order | `sigma_then_gamma` |
| Ridge widths | `width_gamma = 0.45`, `width_sigma = 0.25` |
| RHS-NS core widths | `width_gamma = 0.42`, `width_sigma = 0.30` |
| RHS-NS local/global widths | `lambda = 0.18`, `tau = 0.10`, `c2 = 0.07`, `tau_c2_block = 0.22` |
| RHS-NS global block | `transformed_tau_c2_block` |
| RHS-NS transformed block passes | `3` |
| Core extra passes | `2` |
| Steps/shrink guards | ridge `90/320`, RHS-NS `100/360`; sigma guards `150/400` and `160/420` |

Pipeline/output contract:

| Field | Current value |
|---|---|
| Forecast mode | `origin` |
| Train/forecast last windows | `18`, `18` |
| Sampling chunk | `160` |
| Synthesis grid | `M = 151` |
| Synthesis samples | `20000` |
| Synthesis seed | `321` |
| Isotonic/rearrange | both `false` |
| Diagnostics | scores enabled; calibration, PIT, lead eval, fan charts, plots disabled |
| C++ postpred | disabled |
| Output saving | `save = true`, `keep_draws = false` |

## 4) Next Relaunch Recommendation

For the next 144-run relaunch, use this p90 spec as the template and create a
new named spec rather than mutating the completed p90 files in place.

Recommended next sequence:

1. decide the exact QDESN changes relative to this baseline
2. create a new defaults YAML with a new campaign/scenario id
3. materialize a new full grid and any smoke/subset grids
4. run focused config tests and prepare-only gates
5. launch a small smoke gate
6. launch the full 144-run program if the smoke gate is clean
7. preserve this cleanup and closeout trail as the comparison baseline

# Refreshed288 Numerical Runtime-Failure Relaunch

- run tag: `refreshed288_paperaligned_20260419_numcrash_thetafreeze_v1`
- variant tag: `refreshed288_0p50_ldvb_slice_numcrash_thetafreeze_v1`
- source canonical run: `20260417_canonical_v1`
- rerun scope: `20` frozen numerical/runtime crash rows only
- excluded rows: `27` static MCMC gate/mixing failures
- exdqlm init change: explicit `s_t` warmup/freeze in LDVB init path
- binary retention policy: keep candidate fit, vb-init, and draws `.rds` for manual review

## Phase Plan

| phase | rows |
|---|---|
| numerical_vb_primary |  1 |
| numerical_exdqlm_mcmc | 10 |
| numerical_dqlm_mcmc |  9 |

## Method Highlights

| lever | setting |
|---|---|
| exdqlm VB / VB-init | s_t warmup 50, min_postwarmup_updates 5, sigmagam warmup 50 |
| exdqlm MCMC | VB init max_iter 800 / min_iter 80 / n.samp 5000; latent pair warmup 100; sigmagam warmup 500 |
| dqlm MCMC | VB init max_iter 800 / min_iter 80 / n.samp 5000; U_t warmup 100; sigma warmup 500 |
| retention | preserve all fit / vb_init / draws binaries until manual cleanup |

## Row Allocation

| row_id | phase | family | tau_label | fit_size | model | inference | source_runtime_mode |
|---|---|---|---|---|---|---|---|
| 11 | numerical_vb_primary | gausmix | 0p25 |  500 | exdqlm | vb | ldvb_q_t1_na |
|  8 | numerical_exdqlm_mcmc | gausmix | 0p05 | 5000 | exdqlm | mcmc | nonfinite_chi |
| 12 | numerical_exdqlm_mcmc | gausmix | 0p25 |  500 | exdqlm | mcmc | ldvb_q_t1_na |
| 16 | numerical_exdqlm_mcmc | gausmix | 0p25 | 5000 | exdqlm | mcmc | nonfinite_chi |
| 24 | numerical_exdqlm_mcmc | gausmix | 0p50 | 5000 | exdqlm | mcmc | nonfinite_chi |
| 32 | numerical_exdqlm_mcmc | laplace | 0p05 | 5000 | exdqlm | mcmc | nonfinite_chi |
| 40 | numerical_exdqlm_mcmc | laplace | 0p25 | 5000 | exdqlm | mcmc | nonfinite_chi |
| 48 | numerical_exdqlm_mcmc | laplace | 0p50 | 5000 | exdqlm | mcmc | nonfinite_chi |
| 56 | numerical_exdqlm_mcmc | normal | 0p05 | 5000 | exdqlm | mcmc | nonfinite_chi |
| 64 | numerical_exdqlm_mcmc | normal | 0p25 | 5000 | exdqlm | mcmc | nonfinite_chi |
| 72 | numerical_exdqlm_mcmc | normal | 0p50 | 5000 | exdqlm | mcmc | nonfinite_chi |
|  6 | numerical_dqlm_mcmc | gausmix | 0p05 | 5000 | dqlm | mcmc | invalid_pre_chi |
| 14 | numerical_dqlm_mcmc | gausmix | 0p25 | 5000 | dqlm | mcmc | invalid_pre_chi |
| 22 | numerical_dqlm_mcmc | gausmix | 0p50 | 5000 | dqlm | mcmc | invalid_pre_chi |
| 30 | numerical_dqlm_mcmc | laplace | 0p05 | 5000 | dqlm | mcmc | invalid_pre_chi |
| 38 | numerical_dqlm_mcmc | laplace | 0p25 | 5000 | dqlm | mcmc | invalid_pre_chi |
| 46 | numerical_dqlm_mcmc | laplace | 0p50 | 5000 | dqlm | mcmc | invalid_pre_chi |
| 54 | numerical_dqlm_mcmc | normal | 0p05 | 5000 | dqlm | mcmc | invalid_pre_chi |
| 62 | numerical_dqlm_mcmc | normal | 0p25 | 5000 | dqlm | mcmc | invalid_pre_chi |
| 70 | numerical_dqlm_mcmc | normal | 0p50 | 5000 | dqlm | mcmc | invalid_pre_chi |


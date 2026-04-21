# QDESN Tau050 Remaining Precision Closeout Plan

Date: `2026-04-20`  
Status: prepared, tested, `prepare-only` validated, ready for canonical closeout launch

## Scope

This closeout package stops the precision-policy search and promotes a single winning rescue strategy for the final unresolved tau050 ridge pair:

| Lane | Root | Current closeout target |
|---|---|---|
| `AL` | `laplace / tau=0.50 / fit_size=5000 / ridge` | canonical rerun with `precision_beta = ladder_v2` |
| `EXAL` | `laplace / tau=0.50 / fit_size=5000 / ridge` | canonical rerun with `precision_beta = ladder_v2` |

The exact root is frozen in the closeout grids:

- [AL closeout grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_closeout_al_grid.csv)
- [EXAL closeout grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_closeout_exal_grid.csv)

## Why `ladder_v2` Is Being Promoted

The latest source-of-truth experiment is the code-level precision matrix on the exact unresolved pair:

| Strategy family | Arms | Success | Fail | Success rate |
|---|---:|---:|---:|---:|
| `ladder_v1` | 2 | 0 | 2 | 0.0% |
| `ladder_v2` | 2 | 2 | 0 | 100.0% |
| `eigen_v1` | 2 | 2 | 0 | 100.0% |

That result tells us:

1. `ladder_v1` is too weak and should be retired.
2. `ladder_v2` and `eigen_v1` are both viable.
3. `ladder_v2` is the cleaner promoted default because it succeeds without escalating to the more invasive eigenvalue-floor fallback.

So the closeout wave intentionally uses:

- `ladder_v2` as the only live promoted rerun policy
- `eigen_v1` as a prepared fallback only

## Design

### Live closeout phases

| Phase | Lane | Policy | Launch mode |
|---|---|---|---|
| `remaining_precision_closeout_al_ladder_v2` | `AL` | `precision_beta = ladder_v2` | launch |
| `remaining_precision_closeout_exal_ladder_v2` | `EXAL` | `precision_beta = ladder_v2` | launch |

### Prepared fallback phases

| Phase | Lane | Policy | Launch mode |
|---|---|---|---|
| `remaining_precision_closeout_al_eigen_v1` | `AL` | `precision_beta = eigen_v1` | `prepare-only` |
| `remaining_precision_closeout_exal_eigen_v1` | `EXAL` | `precision_beta = eigen_v1` | `prepare-only` |

The full phase inventory is frozen in:

- [remaining precision closeout map](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_closeout_map.csv)

## Reproducible Assets

Materializer:

- [remaining precision closeout materializer](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_closeout.R)

Generated defaults:

- [AL ladder_v2 closeout defaults](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_closeout_al_ladder_v2_defaults.yaml)
- [EXAL ladder_v2 closeout defaults](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_closeout_exal_ladder_v2_defaults.yaml)
- [AL eigen_v1 closeout defaults](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_closeout_al_eigen_v1_defaults.yaml)
- [EXAL eigen_v1 closeout defaults](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_closeout_exal_eigen_v1_defaults.yaml)

The closeout wave uses the already-productized public precision-beta API rather than one-off raw ladders.

## Validation Gate

Focused tests:

```bash
Rscript -e 'testthat::test_local(filter = "qdesn-dynamic-tau050-remaining-precision-closeout-config|qdesn-fit-mcmc-precision-beta-api|exal-precision-beta-rescue|qdesn-precision-beta-validation-export|exal-inference-config|exal-mcmc", reporter = "summary")'
```

Prepare-only phases:

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase remaining_precision_closeout_al_ladder_v2 --prepare-only
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase remaining_precision_closeout_exal_ladder_v2 --prepare-only
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase remaining_precision_closeout_al_eigen_v1 --prepare-only
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase remaining_precision_closeout_exal_eigen_v1 --prepare-only
```

## Launch Recommendation

Launch only the promoted pair in parallel with one worker each:

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase remaining_precision_closeout_al_ladder_v2
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase remaining_precision_closeout_exal_ladder_v2
```

Reasoning:

- the remaining scientific surface is only two roots
- the closeout wave is meant to freeze a canonical promoted policy, not reopen the search
- the fallback is still prepared and reproducible if either live lane fails

## Decision Rule

| Outcome | Next move |
|---|---|
| both `ladder_v2` closeout lanes succeed | freeze `ladder_v2` as the default precision rescue for this failure family and close the recovery program |
| one lane fails | rerun only that lane with prepared `eigen_v1` |
| both lanes fail | escalate to `eigen_v1` on both lanes and reassess whether deeper precision-kernel work is still required |

## Forward Path

After the closeout wave:

1. write the final closeout report against the promoted policy
2. record `ladder_v2` as the default precision rescue in the recovery playbook
3. retain `eigen_v1` as the explicit fallback for future hard precision failures

That keeps the future workflow simple:

- start with the standard run-specific recovery baseline for latent-state failures
- start with `precision_beta = "ladder_v2"` for precision-Cholesky failures
- escalate to `precision_beta = "eigen_v1"` only when the promoted ladder is still not enough

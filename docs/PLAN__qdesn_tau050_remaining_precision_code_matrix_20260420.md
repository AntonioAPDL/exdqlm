# QDESN Tau050 Remaining Precision Code Matrix Plan

Date: `2026-04-20`  
Status: prepared, tested, `prepare-only` validated, ready to launch

## Scope

This program replaces further config-only relaunches with a code-level stabilization screen on the exact final unresolved pair:

| Lane | Root | Current unresolved failure |
|---|---|---|
| `AL` | `laplace / tau=0.50 / fit_size=5000 / ridge` | `chol.default(... Prec ...)` not positive definite |
| `EXAL` | `laplace / tau=0.50 / fit_size=5000 / ridge` | `chol.default(... Prec ...)` not positive definite |

The pair is frozen in:

- [remaining precision-pair AL grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_al_grid.csv)
- [remaining precision-pair EXAL grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_exal_grid.csv)

## Why This Program Exists

The latest source-of-truth result is the broad precision config matrix:

- `7 / 7` failed
- all failures remained in the same precision Cholesky path
- none reverted to the old latent-`v` invalid-draw family

That result closes out the config-only search space for the final pair. The next move needs to improve the precision draw itself.

## Code-Level Direction

The beta precision draw in [R/exal_mcmc_fit.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/exal_mcmc_fit.R) now supports a dedicated `mcmc.precision_beta` control block:

- optional precision symmetrization before factorization
- adaptive diagonal-jitter ladder
- optional eigenvalue-floored SPD fallback
- structured failure payload emission
- successful rescue diagnostics export

The goal is to test whether the final pair can be recovered by improving the Cholesky rescue logic itself rather than by continuing to search warmup knobs.

## Matrix Design

All six arms keep the strongest validated pair-specific baselines:

- `AL` arms inherit from [remaining precision-pair AL defaults](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_al_v1_defaults.yaml)
- `EXAL` arms inherit from [remaining precision-pair EXAL defaults](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_exal_v2_defaults.yaml)

The only intended experimental difference is the new `precision_beta` rescue policy.

### AL arms

| Phase | Strategy |
|---|---|
| `remaining_precision_code_al_ladder_v1` | symmetrize + jitter ladder through `1e-4` |
| `remaining_precision_code_al_ladder_v2` | symmetrize + stronger jitter ladder through `1e-2` |
| `remaining_precision_code_al_eigen_v1` | symmetrize + ladder through `1e-6` + eigenvalue-floored SPD fallback |

### EXAL arms

| Phase | Strategy |
|---|---|
| `remaining_precision_code_exal_ladder_v1` | symmetrize + jitter ladder through `1e-4` |
| `remaining_precision_code_exal_ladder_v2` | symmetrize + stronger jitter ladder through `1e-2` |
| `remaining_precision_code_exal_eigen_v1` | symmetrize + ladder through `1e-6` + eigenvalue-floored SPD fallback |

## Reproducible Assets

Materializer:

- [remaining precision code matrix materializer](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_code_matrix.R)

Generated matrix map:

- [remaining precision code matrix map](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_code_matrix_map.csv)

Generated defaults:

- [AL ladder v1](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_code_al_ladder_v1_defaults.yaml)
- [AL ladder v2](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_code_al_ladder_v2_defaults.yaml)
- [AL eigen v1](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_code_al_eigen_v1_defaults.yaml)
- [EXAL ladder v1](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_code_exal_ladder_v1_defaults.yaml)
- [EXAL ladder v2](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_code_exal_ladder_v2_defaults.yaml)
- [EXAL eigen v1](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_code_exal_eigen_v1_defaults.yaml)

## Validation Gate

Focused tests:

```bash
Rscript -e 'testthat::test_local(filter = "exal-precision-beta-rescue|qdesn-precision-beta-validation-export|qdesn-dynamic-tau050-remaining-precision-code-matrix-config|exal-inference-config|exal-mcmc|qdesn-dynamic-failure-repair|qdesn-sigmagam-warmup-validation-export", reporter = "summary")'
```

Prepare-only phases:

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase remaining_precision_code_al_ladder_v1 --prepare-only
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase remaining_precision_code_al_ladder_v2 --prepare-only
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase remaining_precision_code_al_eigen_v1 --prepare-only
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase remaining_precision_code_exal_ladder_v1 --prepare-only
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase remaining_precision_code_exal_ladder_v2 --prepare-only
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase remaining_precision_code_exal_eigen_v1 --prepare-only
```

## Launch Recommendation

Launch all six phases in parallel with `1` worker each:

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase remaining_precision_code_al_ladder_v1
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase remaining_precision_code_al_ladder_v2
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase remaining_precision_code_al_eigen_v1
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase remaining_precision_code_exal_ladder_v1
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase remaining_precision_code_exal_ladder_v2
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase remaining_precision_code_exal_eigen_v1
```

Reasoning:

- exact root scope remains only the final unresolved pair
- each lane uses `1` worker
- all arms test code-level rescue policies, not redundant warmup variants
- launching them together is the fastest clean way to learn whether any structural precision rescue is enough

## Decision Rule

| Outcome | Next move |
|---|---|
| any arm succeeds cleanly | freeze the winning code-level rescue strategy and use it as the final repair spec |
| only jitter arms improve burn depth | keep the ladder and inspect whether stronger adaptive jitter should become the default fallback |
| only eigen arms improve burn depth | keep the eigen route and inspect whether a guarded near-PD repair should become the final fix |
| all arms fail in the same way | stop relaunching and shift to direct precision-kernel investigation on the matrix construction path itself |

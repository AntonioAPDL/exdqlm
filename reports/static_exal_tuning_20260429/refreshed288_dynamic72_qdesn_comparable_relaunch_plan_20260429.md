# Dynamic 72 Q-DESN-Comparable Relaunch Plan

## Purpose

This relaunch refreshes only the dynamic DQLM/exDQLM benchmark rows so they are directly comparable to the current Q-DESN simulation-study dataset and article tables.

The Q-DESN article now folds DQLM/exDQLM benchmarks into the dynamic simulation tables, so the historical retained DQLM/exDQLM dynamic rows should be replaced with a clean 0.4.0 package relaunch against the same effective simulated data.

## Run Identity

- Worktree: `/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration`
- Branch: `validation/rerun-after-0.4.0-sync-0p4p0-integration`
- Run tag: `20260429_p90_dynamic72_qdesn_comparable_v1`
- Variant tag: `p90_dynamic72_qdesn_comparable_v1`
- Dynamic dataset: `dlm_constV_p90_m0amp_highnoise_steepertrend_v1`
- Canonical registry: `tools/merge_reports/LOCAL_refreshed288_dataset_registry_20260422_dynamic_p90_steepertrend_v1.csv`
- Retained historical baseline to preserve: `20260422_p90_full288_baseline_v1`

## Scope

The relaunch surface is dynamic-only:

| Dimension | Values | Count |
| --- | --- | ---: |
| families | `normal`, `laplace`, `gausmix` | 3 |
| taus | `0.05`, `0.25`, `0.50` | 3 |
| effective fit sizes | `500`, `5000` | 2 |
| models | `dqlm`, `exdqlm` | 2 |
| inference engines | `vb`, `mcmc` | 2 |
| total dynamic rows | 3 x 3 x 2 x 2 x 2 | 72 |

Static rows are intentionally excluded from launch phases for this tag.

## Dataset Fairness Contract

Q-DESN uses staged source windows of total length `813` and `5313` to support reservoir washout and lag construction, but its reported effective windows are the final `500` and `5000` observations.

DQLM/exDQLM do not need that reservoir prefix. They must use:

- `fit_input_lastTT500`
- `fit_input_lastTT5000`

The verification script `tools/merge_reports/LOCAL_refreshed288_verify_qdesn_dynamic_windows_20260429.R` checks all 18 family/tau/fit-size cells and confirms that each canonical validation window equals the final effective tail of the matching Q-DESN staged window.

## Inference Contract

VB uses:

- engine: `exdqlmLDVB`
- method: `LDVB`
- `max_iter = 300`
- `min_iter_elbo = 80`
- `tol = 0.03`
- `dynamic_n_samp = 20000`
- `posterior_metric_draws = 20000`

MCMC uses:

- engine: `exdqlmMCMC`
- proposal: `slice`
- `slice_width = 0.1`
- `slice_max_steps = Inf`
- `init_from_vb = TRUE`
- `vb_init_method = LDVB`
- `vb_init_max_iter = 300`
- `vb_init_min_iter_elbo = 80`
- `vb_init_tol = 0.03`
- `vb_init_dynamic_n_samp = 1000`
- `n_burn = 5000`
- `n_mcmc = 20000`
- `thin = 1`

The posterior comparison scale is normalized to `20000` draws for both engines.

## Warmup Policy

Use the current 0.4.0 package defaults.

- exDQLM uses package-default light sigma/gamma warmup.
- DQLM does not receive exAL gamma behavior.
- No theta, latent, or precision rescue overlays are preloaded in the baseline.
- Any failure repair must be a separate documented pass with explicit row overlays.

## Retention Policy

Use compact/resource-efficient retention:

- keep comparison metrics needed for article tables
- keep fitted-quantile summaries needed for plots and uncertainty bands
- keep runtime and status metadata
- do not archive full fit binaries by default
- do not retain VB-init artifacts for MCMC unless required for failure debugging

## Launch Sequence

1. Fetch all branches and confirm the worktree is clean.
2. Check for active validation jobs and avoid process/file collisions.
3. Confirm package load and focused contract tests pass.
4. Verify the dynamic registry has 18 dynamic rows and no missing inputs.
5. Run the Q-DESN effective-window verification and store the report.
6. Prepare manifests for the run tag.
7. Launch dynamic smoke phases only.
8. If smoke passes, launch dynamic full phases only.
9. Build comparison outputs and document pass/warn/fail and any repair rows.
10. Commit and push scripts, manifests, and reports.

## Commands

The tag-specific wrapper is:

```bash
tools/merge_reports/LOCAL_refreshed288_launch_20260429_dynamic72_qdesn_comparable_v1.sh
```

It pins BLAS thread counts to 1, fixes the run and variant tags, runs only dynamic phases, and delegates to the existing 20260422 relaunch scripts.

Prepare:

```bash
tools/merge_reports/LOCAL_refreshed288_launch_20260429_dynamic72_qdesn_comparable_v1.sh prepare
```

Smoke dynamic only:

```bash
tools/merge_reports/LOCAL_refreshed288_launch_20260429_dynamic72_qdesn_comparable_v1.sh smoke
```

Full dynamic only:

```bash
tools/merge_reports/LOCAL_refreshed288_launch_20260429_dynamic72_qdesn_comparable_v1.sh full
```

Worker counts can be reduced if memory pressure or disk write contention appears.

Health checks:

```bash
tools/merge_reports/LOCAL_refreshed288_launch_20260429_dynamic72_qdesn_comparable_v1.sh health-smoke
tools/merge_reports/LOCAL_refreshed288_launch_20260429_dynamic72_qdesn_comparable_v1.sh health-full
```

## Acceptance Criteria

- 18 dataset-window checks pass before launch.
- Smoke dynamic phases pass before full launch.
- Full dynamic launch attempts 72 rows.
- Static rows are not relaunched.
- No full-root `sim_output.rds` is used for dynamic fits.
- No Q-DESN washout prefix is given to DQLM/exDQLM.
- No silent numerical repair is applied during baseline launch.
- Outputs include RMSE against `q_true`, quantile check loss, runtime, fitted quantile path summaries, and status metadata.
- Scripts, manifests, reports, run tag, branch, and Git SHA are sufficient to reproduce the run.

## Execution Note

The setup was executed on 2026-04-29. Window verification passed and dynamic VB smoke passed, but dynamic MCMC smoke did not pass. Therefore the full 72-case launch was not started. See:

- `reports/static_exal_tuning_20260429/refreshed288_dynamic72_qdesn_comparable_smoke_closeout_20260429.md`

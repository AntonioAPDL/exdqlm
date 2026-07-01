# Q-DESN TT500 Ridge Relaunch Audit Plan

Date: 2026-07-01

Worktree: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`

Branch: `validation/shared-fitforecast-v2-1.0.0`

Current HEAD at audit: `d45abc6e2408a287bd10aff7861f41872e894f8f` (`Promote TT500 Q-DESN MCMC handoff`)

Package version: `1.0.0`

## Executive Decision

Relaunch the TT500 Q-DESN ridge lanes only, using the corrected per-cell DESN specifications that repaired and promoted the Q-DESN exAL RHS-NS results. Do not relaunch the already promoted RHS-NS lanes unless a later audit finds a concrete defect.

The replacement target is 36 article-facing fits:

- 9 family x tau cells.
- 2 likelihoods: `al`, `exal`.
- 2 inference methods: `vb`, `mcmc`.
- 1 prior: `ridge`.

The launch should use one computational core per atomic fit or worker, with BLAS/OpenMP thread variables forced to 1. The full MCMC stage should be launched only after materialization, prepare-only, smoke, and micro-pilot gates pass.

## Root Cause Audit

The current Article-Q-DESN TT500 summary has 72 Q-DESN rows:

- `qdesn_al_rhs_ns`: 9 VB + 9 MCMC.
- `qdesn_exal_rhs_ns`: 9 VB + 9 MCMC.
- `qdesn_al_ridge`: 9 VB + 9 MCMC.
- `qdesn_exal_ridge`: 9 VB + 9 MCMC.

Only the ridge lanes are pathological. The current article-facing ridge rows all come from validation commit `ec465f93b7b799e675c40f3a6382c7c6e9ae5727` through legacy interface IDs `qdesn_vb` and `qdesn_mcmc`.

The legacy ridge grid is:

- Path: `config/validation/qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_mcmc_ridge_tt500_grid.csv`
- Rows: 9.
- Scenario: `dlm_constV_p90_m0amp_highnoise_steepertrend_v1`.
- Source total size: `813`.
- Active paths: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/...`.
- Reservoir profile: `deep_d3_n100x3_skip100_w300_m30`.
- Prior: `ridge`.

This is not the corrected shared v2 validation design. It is an old source/spec combination with stale `/home/jaguir26/local/src` paths and a large legacy reservoir. The observed pathology is therefore not evidence that corrected DESN ridge is bad; it is evidence that the article table is still carrying old ridge artifacts.

Current ridge metric scale in `tables/qdesn_validation_tt500_final_summary.csv`:

- Fit RMSE is roughly 23 to 70 across ridge rows.
- Forecast MAE is roughly `2.4e5` to `7.7e5`.
- Forecast pinball is roughly `1.2e5` to `7.1e5`.
- MCMC runtimes are roughly 149 to 191 hours per row under the old `deep_d3_n100x3` profile.

## Corrected DESN Specification to Reuse

The corrected DESN per-cell specification is frozen by:

- Winner materializer: `scripts/materialize_qdesn_tt500_mcmc_vb_winner_confirmation.R`
- Winner profiles: `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_winner_confirmation_profiles.csv`
- Winner cells: `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_winner_confirmation_winners.csv`
- Winner grid: `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_winner_confirmation_grid.csv`
- Promotion: `validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_authoritative_20260701/`

Corrected grid evidence:

- Rows: 9.
- Scenario: `dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast`.
- Fit size: `500`.
- Effective fit size: `500`.
- Source total size: `1890`.
- Raw source window: `8111:10000`.
- Train target window: `8501:9000`.
- Forecast block: `9001:10000`.
- Forecast origin stride: `30`.
- Maximum lead: `30`.
- Source paths: canonical `/data/jaguir26/local/src/...`.
- Source registry hash value in the promoted MCMC handoff: `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`.

Corrected per-cell DESN map:

| Family | Tau | Profile ID | D | n each | m | alpha | rho | pi_w | pi_in | readout lags | p estimate |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| gausmix | 0.05 | `tt500vb_f3_d2_n20_a0p05_r0p6_m15_lag15_rl0_pw0p03_pin0p3` | 2 | 20 | 15 | 0.05 | 0.60 | 0.03 | 0.30 | 15 | 81 |
| gausmix | 0.25 | `tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3` | 1 | 30 | 15 | 0.02 | 0.45 | 0.03 | 0.30 | 15 | 51 |
| gausmix | 0.50 | `tt500vb_f3_d1_n30_a0p03_r0p5_m15_lag15_rl0_pw0p03_pin0p3` | 1 | 30 | 15 | 0.03 | 0.50 | 0.03 | 0.30 | 15 | 51 |
| laplace | 0.05 | `tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3` | 1 | 30 | 15 | 0.02 | 0.45 | 0.03 | 0.30 | 15 | 51 |
| laplace | 0.25 | `tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3` | 1 | 30 | 15 | 0.02 | 0.45 | 0.03 | 0.30 | 15 | 51 |
| laplace | 0.50 | `tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3` | 1 | 30 | 15 | 0.02 | 0.45 | 0.03 | 0.30 | 15 | 51 |
| normal | 0.05 | `tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3` | 1 | 30 | 15 | 0.02 | 0.45 | 0.03 | 0.30 | 15 | 51 |
| normal | 0.25 | `tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3` | 1 | 30 | 15 | 0.02 | 0.45 | 0.03 | 0.30 | 15 | 51 |
| normal | 0.50 | `tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3` | 1 | 30 | 15 | 0.02 | 0.45 | 0.03 | 0.30 | 15 | 51 |

All profiles use washout `300` and reservoir lags `0`. The `rhs_tau0` field in these profiles is not relevant to ridge inference but should remain in profile provenance for exact replay.

## Feasibility Audit

The relaunch can use the current validation harness without changing the exdqlm 1.0.0 package branch.

Confirmed runner capabilities:

- `scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R` accepts `--methods`, `--likelihoods`, `--priors`, `--fit-sizes`, `--families`, `--taus`, `--root-ids`, `--spec-ids`, `--allow-grid-subset`, `--workers`, and `--scheduler`.
- The dynamic materializer can build profile-specific grids from frozen source materialization and screening profiles.
- `validation/fitforecast_v2/R/row_runner.R` reuses an existing VB initialization handoff for MCMC when `handoff$reuse_vb_init` is true and a matching VB manifest row exists. Otherwise, it computes an inline VB initialization.
- The row runner sets `OMP_NUM_THREADS`, `OPENBLAS_NUM_THREADS`, and `MKL_NUM_THREADS` from the per-row runtime thread setting.
- MCMC progress and telemetry are already wired through `progress_every = 50` and the progress callback.

Important limitation:

- The helper `qdesn_dynamic_fitforecast_materialize_forecast_targeted_stage()` currently hard-codes `defaults$screening_profiles$priors <- "rhs_ns"` and smoke priors to `"rhs_ns"`. For a clean ridge relaunch, do not mutate the existing helper globally without tests. Instead, either:
  - Add a narrow ridge-specific materializer that reuses the winner-map logic and writes ridge-specific defaults/grids, or
  - Add an optional `priors` argument to the helper with default `"rhs_ns"` and tests proving old RHS-NS materializations remain byte-compatible where expected.

Recommended implementation is the optional `priors` argument plus a new ridge relaunch script, because this preserves existing behavior while avoiding duplicated materialization logic.

## Proposed Relaunch Artifacts

New tracked files:

- `scripts/materialize_qdesn_tt500_ridge_corrected_desn.R`
- `scripts/orchestrate_qdesn_tt500_ridge_corrected_desn.R`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_ridge_corrected_desn_winners.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_ridge_corrected_desn_profiles.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_ridge_corrected_desn_cell_assignments.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_ridge_corrected_desn_defaults.yaml`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_ridge_corrected_desn_grid.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_ridge_corrected_desn_materialization_manifest.json`

New result/report roots:

- `results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_ridge_corrected_desn/`
- `reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_ridge_corrected_desn/`

Planned run tags:

- Prepare-only: `qdesn-tt500-ridge-corrected-desn-prepare-YYYYMMDD__git-SHA`
- Smoke: `qdesn-tt500-ridge-corrected-desn-smoke-YYYYMMDD__git-SHA`
- Micro-pilot: `qdesn-tt500-ridge-corrected-desn-pilot-YYYYMMDD__git-SHA`
- Full VB: `qdesn-tt500-ridge-corrected-desn-vb-full-YYYYMMDD__git-SHA`
- Full MCMC: `qdesn-tt500-ridge-corrected-desn-mcmc-full-YYYYMMDD__git-SHA`

## Staged Execution Plan

1. Materialize ridge corrected DESN grid.
   - Expected selected roots: 9.
   - Expected prior: `ridge`.
   - Expected paths: only `/data/jaguir26/local/src/...`.
   - Expected source window: train `8501:9000`, forecast `9001:10000`.

2. Prepare-only gate.
   - Run both likelihoods and both methods in preflight scope, but no fitting.
   - Require selected atomic specs = 36.
   - Require no active `/home/jaguir26/local/src` paths.
   - Require source-window verification PASS.
   - Require storage policy PASS.

3. Smoke gate.
   - Use the hardest known cell, `gausmix`, `tau = 0.05`.
   - Run all four ridge lanes for that cell with reduced budgets.
   - Workers: 4.
   - Threads per worker: 1.
   - Require fit, forecast, status, progress, heartbeat, artifact manifest, and lead metrics to exist.

4. Micro-pilot gate.
   - Suggested cells: `gausmix` 0.05, `laplace` 0.25, `normal` 0.50.
   - Run all four ridge lanes for those cells with reduced MCMC budget.
   - Workers: 12.
   - Threads per worker: 1.
   - Use this to confirm no ridge-specific numerical blow-up before full MCMC.

5. Full VB stage.
   - Run 18 VB fits: 9 cells x `al,exal`.
   - Workers: up to 18.
   - Threads per worker: 1.
   - Audit metrics against current article ridge rows and against RHS-NS corrected rows.
   - Do not promote unless all rows are source-clean, storage-light, and finite.

6. Full MCMC stage.
   - Run 18 MCMC fits: 9 cells x `al,exal`.
   - Workers: choose based on current machine load; maximum useful value is 18 if each atomic fit has one worker/core.
   - Threads per worker: 1.
   - Budget: `n_burn = 5000`, `n_mcmc = 20000`, `thin = 1`, `progress_every = 50`.
   - Reuse VB handoffs where available; if reuse is absent, record inline VB initialization in progress/status.

7. Audit and promotion.
   - Promote only if all 36 replacement rows are finite and traceable.
   - Write a ridge-specific promotion directory, then merge into the article-facing TT500 summary.
   - Keep old ridge rows quarantined and explicitly marked non-authoritative.

## Parallelization Policy

Use one core per worker. Before every launch, force:

```sh
export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1
export NUMEXPR_NUM_THREADS=1
```

For the full relaunch:

- VB stage: `--workers 18` is appropriate if the machine is otherwise free.
- MCMC stage: `--workers 18` is appropriate if the machine is otherwise free; reduce to 12 or 16 if competing jobs are active.
- Do not run old automatic follow-up launchers for the legacy ridge grid.

## Validation Gates

Required checks before full launch:

- Git worktree clean or dirty only with the planned ridge relaunch files.
- `DESCRIPTION` package version is `1.0.0`.
- Generated grid has exactly 9 rows and prior `ridge`.
- Generated atomic specs have exactly 36 rows when run with `--methods vb,mcmc --likelihoods al,exal --priors ridge`.
- All selected paths are canonical `/data/jaguir26/local/src/...`.
- No selected path contains `/home/jaguir26/local/src`.
- Source registry hash remains `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275` or the relaunch manifest documents any intentional change.
- Source windows are exactly train `8501:9000`, forecast `9001:10000`.
- Forecast protocol is `rolling_origin_no_refit_state_update`.
- Forecast stride is `30`, max lead is `30`.
- Storage-light policy produces scalar metrics, compact path summaries, logs/configs/manifests/status, and no routine successful `.rds`, `.rda`, or `.RData` payload retention.
- Prepare-only and dry-run paths produce no forbidden binary payloads.

Required checks after full launch:

- All 36 fits reach explicit terminal status.
- All fit and forecast metrics are finite.
- No row reports stale source paths.
- MCMC progress reaches expected total iterations (`25000` total including burn-in when `5000 + 20000`).
- Handoff manifests are present or documented as pruned according to policy.
- Forecast lead metrics files have stable SHA-256 hashes.
- Article-facing promotion includes branch, commit, run tag, package version, source hash, and artifact hashes.

## Article Update Policy

The Article-Q-DESN table should not consume ridge relaunch outputs until the promotion directory is complete and documented. Once promoted, replace only these rows in `tables/qdesn_validation_tt500_final_summary.csv`:

- `qdesn_al_ridge`, `vb`
- `qdesn_al_ridge`, `mcmc`
- `qdesn_exal_ridge`, `vb`
- `qdesn_exal_ridge`, `mcmc`

Do not replace or relaunch:

- `qdesn_al_rhs_ns`
- `qdesn_exal_rhs_ns`
- exDQLM/DQLM rows

Article guardrails should reject or mark non-authoritative any ridge rows whose provenance still contains:

- validation commit `ec465f93b7b799e675c40f3a6382c7c6e9ae5727`
- interface IDs `qdesn_vb` or `qdesn_mcmc` as the only ridge provenance
- scenario `dlm_constV_p90_m0amp_highnoise_steepertrend_v1`
- source total size `813`
- reservoir profile `deep_d3_n100x3_skip100_w300_m30`
- active `/home/jaguir26/local/src` paths

## Open Questions Before Launch

1. Should full MCMC run all 18 ridge MCMC fits at once, or cap at 12 to reserve cores for unrelated application jobs?
2. Should the smoke gate run both `al` and `exal` MCMC with tiny budgets, or run VB for both likelihoods and MCMC only for `exal` in the first smoke?
3. Should ridge relaunch use the same VB winner profiles without additional ridge-specific VB screening? The recommended answer is yes for this rescue, because the previous failure is clearly stale source/spec provenance, but a post-relaunch audit may still decide ridge is scientifically inferior.

## Next Safe Commands

Do not launch full compute until the new materializer and orchestrator are implemented and tested.

Recommended next implementation sequence:

```sh
cd /data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0
Rscript scripts/materialize_qdesn_tt500_ridge_corrected_desn.R --workers 18
Rscript scripts/orchestrate_qdesn_tt500_ridge_corrected_desn.R --dry-run --prepare --smoke --pilot
Rscript scripts/orchestrate_qdesn_tt500_ridge_corrected_desn.R --prepare
Rscript scripts/orchestrate_qdesn_tt500_ridge_corrected_desn.R --smoke
Rscript scripts/orchestrate_qdesn_tt500_ridge_corrected_desn.R --pilot
```

Only after those pass:

```sh
Rscript scripts/orchestrate_qdesn_tt500_ridge_corrected_desn.R --vb-full-background --workers 18
```

Then audit VB. Only after VB is clean:

```sh
Rscript scripts/orchestrate_qdesn_tt500_ridge_corrected_desn.R --mcmc-full-background --workers 18
```

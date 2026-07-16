# Q-DESN 500-Observation VB QVBM3 Low-Tau Relaunch Plan

Date: 2026-07-15

## Purpose

This package prepares a relaunch of the completed qvbm3 capacity-expansion VB screen with smaller RHS prior scale `rhs_tau0`.

The scientific question is narrow: did qvbm3 fail because the larger `D`, `m`, and `n_each` surface was under-regularized?  This relaunch keeps the qvbm3 cell/capacity surface fixed and changes only the RHS shrinkage axis.

## Source Evidence

- Source worktree: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`
- Source branch: `validation/shared-fitforecast-v2-1.0.0`
- qvbm3 source bundle index: `config/validation/qvbm3_capacity_bundle_index.csv`
- qvbm3 used `rhs_tau0 = 3e-04` and `rhs_tau0 = 1e-04`.
- Earlier qvbm2 `rhs_tau0 = 3e-05` rows failed/refused, so values at or below `3e-05` remain forbidden.

## Low-Tau Mapping

| qvbm3 `rhs_tau0` | relaunch `rhs_tau0` | Policy |
|---:|---:|---|
| `3e-04` | `1e-04` | move to prior safe floor |
| `1e-04` | `7.5e-05` | below-safe-floor canary, still above failed `3e-05` |

This is not an article-facing result and does not open MCMC promotion.  It only prepares a VB diagnostic relaunch.

## Generated Artifacts

Scripts:

- `scripts/materialize_qdesn_tt500_vb_qvbm3_lowtau_relaunch.R`
- `scripts/audit_qdesn_tt500_vb_qvbm3_lowtau_materialization.R`
- `scripts/orchestrate_qdesn_tt500_vb_qvbm3_lowtau_relaunch.R`

Expected generated config bundle:

- `config/validation/qvbm3_lowtau_bundle_index.csv`
- `config/validation/qvbm3_lowtau_bundle_index_manifest.json`
- `config/validation/qvbm3_lowtau_c12_defaults.yaml`
- `config/validation/qvbm3_lowtau_c12_grid.csv`
- `config/validation/qvbm3_lowtau_c12_profiles.csv`
- `config/validation/qvbm3_lowtau_c12_target_spec_ids.csv`
- `config/validation/qvbm3_lowtau_c123_defaults.yaml`
- `config/validation/qvbm3_lowtau_c123_grid.csv`
- `config/validation/qvbm3_lowtau_c123_profiles.csv`
- `config/validation/qvbm3_lowtau_c123_target_spec_ids.csv`

## Gates

The relaunch is VB-only, exact-spec filtered, storage-light, and non-article-facing.

Promotion remains closed unless a strict closeout shows that the low-tau relaunch improves the current Q-DESN frontier and clears the DQLM/exDQLM comparison gate for fit RMSE, fit check loss, forecast MAE, and forecast check loss.

## Commands

Materialize and audit only:

```bash
Rscript scripts/orchestrate_qdesn_tt500_vb_qvbm3_lowtau_relaunch.R --materialize-only
```

Prepare-only dry run:

```bash
Rscript scripts/orchestrate_qdesn_tt500_vb_qvbm3_lowtau_relaunch.R --prepare-only --workers 12
```

Full VB relaunch, only after explicit approval:

```bash
Rscript scripts/orchestrate_qdesn_tt500_vb_qvbm3_lowtau_relaunch.R --full --launch-approved --workers 12
```

No MCMC command is provided by this plan.

## Forced Ultra-Low Tau0 Launch

At user request on 2026-07-15, a separate forced ultra-low relaunch surface was materialized with every qvbm3 source profile set to `rhs_tau0 = 1e-06`.

This is intentionally separate from the safer `qvbm3_lowtau` surface because `1e-06` is below the previously failed/refused `3e-05` value.  The run is therefore diagnostic-only unless a later closeout proves it is stable and scientifically superior.

Generated surface:

- stage prefix: `qvbm3_tau1e6`
- bundle index: `config/validation/qvbm3_tau1e6_bundle_index.csv`
- c12 profiles: `config/validation/qvbm3_tau1e6_c12_profiles.csv`
- c123 profiles: `config/validation/qvbm3_tau1e6_c123_profiles.csv`
- materialization audit: `reports/qvbm3_tau1e6/audit/qvbm3_tau1e6_materialization_20260715/summary/qvbm3_tau1e6_materialization_audit.md`

Prepare-only run:

- orchestrator manifest: `reports/qvbm3_tau1e6/orch/qvbm3_tau1e6_vb_07151923__git-f91bcc7/manifest/qvbm3_lowtau_orchestrator_manifest.json`
- c12 prepare tag: `m3ltc12p_07151923_f91bcc7`
- c123 prepare tag: `m3ltc123p_07151923_f91bcc7`

Detached full run:

- tmux session: `qvbm3_tau1e6_vb_full_20260715_1924`
- tmux stdout: `reports/qvbm3_tau1e6/tmux/qvbm3_tau1e6_vb_full_20260715_1924.stdout.log`
- full c12 run tag: `m3ltc12f_07151924_f91bcc7`
- full c123 run tag: `m3ltc123f_07151924_f91bcc7`

Launch command used:

```bash
tmux new-session -d -s qvbm3_tau1e6_vb_full_20260715_1924 \
  "cd /data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0 && \
   Rscript scripts/orchestrate_qdesn_tt500_vb_qvbm3_lowtau_relaunch.R \
     --stage-prefix qvbm3_tau1e6 \
     --tau0-override 1e-06 \
     --allow-ultra-low-tau0 \
     --skip-materialize --skip-audit --skip-prepare \
     --full --launch-approved --workers 12 \
     > reports/qvbm3_tau1e6/tmux/qvbm3_tau1e6_vb_full_20260715_1924.stdout.log 2>&1"
```

## Forced Ultra-Low Tau0 Closeout

The `qvbm3_tau1e6` full VB relaunch completed cleanly and was closed out on 2026-07-16.

Tracked closeout evidence:

- summary: `validation/fitforecast_v2/docs/qvbm3_tau1e6_closeout_20260716.md`
- manifest: `validation/fitforecast_v2/docs/qvbm3_tau1e6_closeout_20260716_manifest.json`
- health table: `validation/fitforecast_v2/docs/qvbm3_tau1e6_closeout_20260716_health.csv`
- ratio table versus prior qvbm3: `validation/fitforecast_v2/docs/qvbm3_tau1e6_closeout_20260716_ratio_reference_summary.csv`
- ratio table versus qvbm1 and exDQLM/DQLM VB baselines: `validation/fitforecast_v2/docs/qvbm3_tau1e6_closeout_20260716_qvbm1_ratio_summary.csv`
- tau0 wiring audit: `validation/fitforecast_v2/docs/qvbm3_tau1e6_closeout_20260716_tau0_code_wiring.csv`

Closeout decision:

- status: `COMPLETE`
- roots: `66 / 66` successful, `0` remaining
- rolling forecast lead rows: `1980 / 1980`
- retained forbidden heavy payloads: `0`
- scientific disposition: `DIAGNOSTIC_NEGATIVE_DO_NOT_PROMOTE`
- article-facing: `FALSE`
- MCMC handoff: `FALSE`

Interpretation: the forced `rhs_tau0 = 1e-06` screen is empirically indistinguishable from the prior qvbm3 capacity screen and does not clear the qvbm1 or exDQLM/DQLM all-four gates. Future Q-DESN VB screening should pivot away from this same high-capacity surface with only tau0 shrinkage changes.

# Dynamic P90 Steepertrend Main Dataset Selection

Date: 2026-04-22

## Decision

The period-90 steeper-trend candidate dataset surface is now the promoted main
dynamic dataset for the next Q-DESN dynamic relaunch.

Selected scenario:

- `dlm_constV_p90_m0amp_highnoise_steepertrend_v1`

This selection is documented without rewriting the historical
`tau050_refreshed_main` study artifacts in place. The old dataset-backed runs
remain preserved for auditability; this new scenario becomes the active
source-of-truth for the next launch preparation phase.

## Why this surface was selected

Compared with the earlier short-period and period-365 candidates, this surface
gave the best visual balance for the intended study role:

- more readable seasonal structure than the original `dlm_constV_smallW`
- more compact and visually checkable oscillation than the period-365 draft
- clearer local trend signal after increasing the slope
- still compatible with the same `9`-root, `18`-window study contract
- still compatible with the Q-DESN washout-preserving materialization logic

## Exact promoted roots and windows

The promoted source contract remains:

- `9` full roots
- `18` canonical validation windows via `lastTT500` and `lastTT5000`
- `18` Q-DESN windows via `effTT500_totalTT813` and `effTT5000_totalTT5313`

Families:

- `gausmix`
- `laplace`
- `normal`

Tau levels:

- `0.05`
- `0.25`
- `0.50`

## Exact output roots

Canonical source bundle:

- [candidate source bundle](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_candidate_sources/dlm_constV_p90_m0amp_highnoise_steepertrend_v1)

Q-DESN materialized windows:

- [qdesn materialized windows](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_candidate_qdesn_sources/dlm_constV_p90_m0amp_highnoise_steepertrend_v1)

Visual review packs:

- [flat audit pack](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_candidate_dataset_audit_local/qdesn-dynamic-exdqlm-crossstudy-candidate-datasetaudit-20260422-035737__git-a4ecc81)
- [last5000 vs last500 pack](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_candidate_last5000_last500_audit_local/qdesn-dynamic-candidate-last5000-last500-audit-20260422-035753__git-a4ecc81)

## Generator and reproducibility contract

The canonical generation path is:

- [portable helper](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/tools/merge_reports/20260305_dynamic_dgp_model_helpers.R)
- [generator manifest](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_candidate_dataset_manifest.yaml)
- [refresh runner](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/run_qdesn_dynamic_exdqlm_crossstudy_candidate_dataset_refresh.R)

Important design guarantees:

- within family, the latent path is shared across tau
- tau-specific series are created by deterministic quantile-centering shifts
- `m0` is deterministic so the intended slope and seasonal amplitude are not
  lost to `C0 = 0.01 I` randomness
- Q-DESN washout is downstream materialization, not part of the canonical full
  root simulation

## Relaunch sizing implication

If the next relaunch uses:

- `18` effective source windows
- `{vb, mcmc}`
- `{al, exal}`
- one prior surface

then the relaunch is `72` fits.

If both `ridge` and `rhs_ns` are included, the same source surface expands to
`144` fits.

## Branching implication

The intended branch layering remains:

1. `0.4.0` package branch:
   shared package base
2. `0.4.0` validation branch:
   shared package base plus validation-study files
3. qdesn validation branch:
   same shared package base plus validation-study files plus qdesn-specific
   files and readout logic

That means the `0.4.0` validation worktree should reproduce the canonical full
roots and the canonical `lastTT500` / `lastTT5000` windows, while Q-DESN keeps
the extra `813 / 5313` washout materialization locally.

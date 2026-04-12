# REPORT: QDESN Dynamic Effective-W300 Postdraw Deep-DESN Row-Faithful Multiseed Implementation And Preflight

Date: 2026-04-12
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Status

This report records the corrected implementation after the user clarified that the replay must be
**row-faithful**, not a generic normalized replacement policy.

Important correction:

- the prior normalized multiseed canary path is withdrawn
- its live run outputs were deleted
- the branch now treats that path as historical-but-invalid for replay purposes

## 2) Corrected Contract

Active replay rule:

- preserve every current row's accepted exact local spec
- standardize only:
  - `n.burn = 5000`
  - `n.mcmc = 20000`
  - stored posterior draws `= 20000`
  - VB posterior draw export `= 20000`
  - `4` deterministic MCMC seeds
- choose the winning MCMC seed by:
  - `PASS > WARN > FAIL`
  - then lower `forecast_CRPS_mean`
  - then deterministic tie-breakers

## 3) Implemented Assets

Resolver and config wiring:

- `R/qdesn_dynamic_exdqlm_crossstudy_rowfaithful_replay.R`
- `R/qdesn_static_exdqlm_crossstudy.R`
- `scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R`

Committed replay inputs / outputs:

- manifest:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_replay_manifest.yaml`
- resolved defaults:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_defaults.yaml`
- resolved inventory:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_inventory.csv`
- materialization summary:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_materialization_summary.md`
- canary grid:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_canary_grid.csv`

Wrappers:

- full:
  - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_validation.R`
  - `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_validation.R`
  - `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_validation.R`
- canary:
  - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_canary_validation.R`
  - `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_canary_validation.R`
  - `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_canary_validation.R`

## 4) Materialized Source State

Resolved replay inventory:

- total roots: `36`
- overridden roots: `31`
- source-baseline roots kept unchanged: `5`

Representative resolved endpoints:

- `gausmix tau=0.05 fit_size=500 rhs_ns -> D310`
- `laplace tau=0.05 fit_size=5000 rhs_ns -> E530`
- `normal tau=0.05 fit_size=5000 rhs_ns -> F630`
- `normal tau=0.95 fit_size=5000 rhs_ns -> E520`
- `gausmix tau=0.25 fit_size=500 ridge -> SOURCE_BASELINE`

## 5) Validation Completed

Code and replay assertions:

- `pkgload::load_all(...)` passed
- accepted-chain reconstruction assertions passed
- replay contract assertions passed
- untouched baseline-root assertions passed

Committed-state preflights:

- canary preflight:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-rowfaithseed-canary-preflight-20260412`
- full preflight:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-rowfaithseed-full-preflight-20260412`

Smoothness proof:

- the materializer also passed when invoked from outside the repo root

## 6) Ready State

The corrected row-faithful replay path is now:

- implemented
- documented
- resolved into committed defaults/inventory
- preflight-validated

The next step after this report is the detached full relaunch from committed state.

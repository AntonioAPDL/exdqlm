# PLAN: QDESN Dynamic Effective-W300 Postdraw Deep-DESN Row-Faithful Multiseed Replay

Date: 2026-04-12
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Corrected Replay Contract

This plan replaces the withdrawn normalized-canary path.

The active requirement is:

1. start from the **current accepted/best exact row-level spec**
2. preserve **all** row-local tuning and inference semantics
3. change **only** these replay controls:
   - `n.burn = 5000`
   - `n.mcmc = 20000`
   - stored posterior draws `= 20000`
   - VB posterior draw export `= 20000`
   - `4` deterministic MCMC seeds
4. select the winning MCMC seed by:
   - `PASS > WARN > FAIL`
   - then lower `forecast_CRPS_mean`
   - then deterministic tie-breakers

What this means operationally:

- row-local proposal families stay the same
- joint vs non-joint stays the same
- adapt vs no-adapt stays the same
- slice widths, max-steps, refresh cadence, RW scales, init strategy, and other repaired tuning stay
  exactly the same
- only burn-in, kept chain length, posterior export size, and the 4-seed replay policy change

## 2) Accepted Source To Replay

The current accepted deep-DESN source is the promoted D/E/F chain:

- D-stage winners:
  - `D1 -> D120_ridge_lower_vb384`
  - `D2 -> D250_ridge_upper_combo512_diag3400`
  - `D3 -> D330_rhs_short_balanced3000`
  - `D4 -> SOURCE_BASELINE`
- D exact-root carry-forwards:
  - `D310` on `gausmix tau=0.05 fit_size=500 rhs_ns`
  - `D140` on the two long-horizon `ridge tau=0.05` roots
- E-stage winners:
  - `E1 -> E410_rhs_long_gausmix_guard320_balanced3200`
  - `E2 -> E520_rhs_long_general_diag3400`
  - `E3 -> E620_ridge_mid_diag3000`
- E exact-root carry-forward:
  - `E530` on `laplace tau=0.05 fit_size=5000 rhs_ns`
- F-stage decisions:
  - `F1 -> KEEP_SOURCE_BASELINE`
  - `F2 -> KEEP_SOURCE_BASELINE`
  - `F3 -> F630_rhs_long_normal_lower_guard320_recenter4000`
  - `F4 -> KEEP_SOURCE_BASELINE`

Current accepted signoff state:

- `71 PASS`
- `60 WARN`
- `13 FAIL`
- `36 / 36` root `SUCCESS`
- `0 / 36` root `FAIL`

## 3) Implementation Shape

The corrected relaunch uses a **resolved row-faithful defaults file**, not a generic normalized
policy.

Implementation pieces:

- replay manifest:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_replay_manifest.yaml`
- materializer:
  - `scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_replay.R`
- resolved defaults:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_defaults.yaml`
- resolved inventory:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_inventory.csv`
- canary grid:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_canary_grid.csv`

Config behavior:

- per-root accepted patches are resolved from the D/E/F chain and written into
  `replay.row_overrides`
- `qdesn_static_crossstudy_build_pipeline_cfg()` applies each root's accepted patch first
- the replay contract is then enforced afterward so:
  - row-local tuning survives
  - only burn / kept chain / posterior export sizes are standardized

## 4) Validation Stages

### 4.1 Code And Resolution Checks

- package load passes
- accepted-chain reconstruction passes
- representative roots resolve to the expected final promoted profiles
- replay contract enforcement passes
- untouched source-baseline roots keep their original local tuning apart from the contract changes

### 4.2 Committed-State Preflights

- canary `prepare-only`
- full `prepare-only`
- wrapper/materializer invocation from outside the repo root

### 4.3 Launch Rule

Launch the full replay only after:

- code assertions pass
- row-faithful defaults materialize cleanly
- both committed-state preflights pass
- docs/trackers are updated to withdraw the invalid normalized canary and point to this corrected
  replay path

## 5) Deliverables

- corrected row-faithful replay implementation
- corrected docs and trackers
- committed resolved defaults and inventory
- committed-state preflight evidence
- full detached relaunch from committed state

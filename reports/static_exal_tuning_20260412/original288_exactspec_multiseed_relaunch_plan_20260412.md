# Original288 Exact-Spec Multi-Seed Relaunch Plan (0.4.0)

Date: `2026-04-12`

## Purpose

This plan replaces the invalidated normalized relaunch with the correct target:

- replay each current corrected original-`288` row under its own exact accepted
  or selected historical spec
- preserve row-local kernels, proposals, adaptation settings, slice controls,
  refresh cadence, initialization strategy, prior semantics, and model family
- change only:
  - `n.burn = 5000`
  - `n.mcmc = 20000`
  - stored posterior draws `= 20000`
  - deterministic `4`-seed expansion and reduction

## Exact Replay Rule

For every current study row:

1. resolve the exact historical row-level run config from the current corrected
   `rhs_ns` comparison-selection state
2. preserve the row-local fit specification exactly
3. expand that base row to `4` deterministic seeds
4. rerun using:
   - `mcmc`: `n.burn = 5000`, `n.mcmc = 20000`
   - stored posterior draws `= 20000`
   - `vb` draw export standardized to `20000`
5. select the winning seed by:
   - `PASS > WARN > FAIL`
   - lower `crps`
   - lower primary-accuracy metric
   - lower runtime
   - smaller seed

## Current Input Universe

The relaunch source of truth is:

- `tools/merge_reports/LOCAL_original288_comparison_selection_rhsns_v1_20260411.csv`

Expected scope:

- `288` corrected study rows
- `1152` full seed-level replay rows
- `48` smoke rows

## Source Recovery Strategy

The historical selected rows come from multiple source waves, so the relaunch
must recover source configs from a table-backed index rather than assuming a
single manifest.

The resolver therefore:

1. indexes historical manifest/status CSVs across both validation worktrees
2. extracts recoverable `run_config_path` rows
3. matches the corrected selected row using:
   - exact selected fit-path match
   - exact selected health-path match
   - selected variant-tag match
   - original-case-key match
   - source CSV path match
4. rejects unresolved rows if the best resolution score is too weak

## Config Translation Rule

Two source-config styles are supported:

- nested historical configs
- flat wave-local configs

Translation policy:

- preserve all row-local controls from the source config
- rewrite only:
  - seed
  - run/output paths
  - `n.burn`
  - `n.mcmc`
  - stored posterior draw count

Important special handling:

- static nested configs recover their source data from the parent input
  directory even when the original `sim_output.rds` no longer exists
- dynamic nested configs recover their source state from the materialized
  dynamic source windows used by the restored-closure machinery

## Runner Contract

### Static

- `vb` rows run through `exal_static_LDVB(...)`
- `mcmc` rows run through `exal_static_mcmc(...)`
- row-local `beta_prior`, `beta_prior_controls`, proposal type, adaptation,
  slice controls, gamma substeps, global-eta jump settings, refresh cadence,
  and VB-init controls are preserved from the source config

### Dynamic

- `vb` rows run through `exdqlmLDVB(...)`
- `mcmc` rows run through `exdqlmMCMC(...)`
- row-local joint/non-joint mode, proposal family, adaptation settings, slice
  controls, refresh cadence, VB tolerances, and LDVB controls are preserved
  from the source config

## Output Contract

Every replay row writes:

- compact fit RDS
- health CSV
- metrics CSV
- row-status CSV
- posterior-draw export RDS

Every manifest family writes:

- manifest CSV
- manifest-status CSV
- phase summary CSV
- seed ranking CSV
- selected winner CSV

Post-run refresh writes:

- exact-spec selected comparison-selection CSV
- exact-spec selected comparison summary CSV
- refreshed cluster comparison report

## Validation Stages

1. syntax validation for helper/prepare/run/evaluate/reduce/refresh/launch
2. prepare validation:
   - `288` rows resolved
   - `1152` full rows built
   - `48` smoke rows built
   - `0` missing inputs
3. cross-path smoke execution:
   - static `mcmc`
   - static `vb`
   - dynamic `vb`
   - dynamic `mcmc`
4. launcher validation:
   - `--prepare-only=1`
   - `--dry-run=1 --skip-prepare=1`
5. staged tmux launch:
   - smoke first
   - seed reduction
   - full replay
   - seed reduction
   - comparison refresh

## Phase Order And Worker Caps

Replay phases:

1. `full_static_mcmc`
2. `full_static_vb`
3. `full_dynamic_vb`
4. `full_dynamic_mcmc`

Worker caps:

| phase | cap |
|---|---:|
| `full_static_mcmc` | `4` |
| `full_static_vb` | `8` |
| `full_dynamic_vb` | `6` |
| `full_dynamic_mcmc` | `3` |

Smoke uses the same phase names and caps on the reduced manifest.

# Q-DESN 500-Observation VB Break-Surface Redesign Plan

- date: 2026-07-13
- worktree: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`
- branch: `validation/shared-fitforecast-v2-1.0.0`
- current head at audit time: `862dcb5cd80b8d90dca1e4407ad3823e393bbd64`
- scope: Q-DESN versus DQLM/exDQLM fit+forecast validation only
- status: planning/audit only; no new VB, MCMC, smoke, pilot, or full screen launched

## Purpose

The recent Q-DESN RHS VB calibration loop has stopped producing meaningful
improvement. The objective of this note is to freeze the diagnosis, document why
the current local RHS search is exhausted, and define a different next strategy
that can break the observed fit/forecast tradeoff surface before any further
compute is spent.

This is not an article update and not a promotion note. It is a calibration
redesign plan.

## Reproducible Evidence

The following audit script recomputes historical Q-DESN VB screen performance
against the current DQLM/exDQLM VB baseline rather than trusting stale stored
dominance flags from older screens:

```bash
cd /data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0
Rscript scripts/audit_qdesn_tt500_vb_break_surface_redesign.R
```

Generated evidence:

- audit summary:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/posthoc/qdesn_tt500_vb_break_surface_redesign_20260713/summary/qdesn_tt500_vb_break_surface_redesign_audit.md`
- run trend:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/posthoc/qdesn_tt500_vb_break_surface_redesign_20260713/tables/qdesn_tt500_vb_current_baseline_run_trend.csv`
- current-baseline frontier:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/posthoc/qdesn_tt500_vb_break_surface_redesign_20260713/tables/qdesn_tt500_vb_current_baseline_frontier.csv`
- v5.1 blockers:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/posthoc/qdesn_tt500_vb_break_surface_redesign_20260713/tables/qdesn_tt500_vb_v51_by_likelihood_blockers.csv`
- v5.1 parameter correlations:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/posthoc/qdesn_tt500_vb_break_surface_redesign_20260713/tables/qdesn_tt500_vb_v51_parameter_correlations.csv`

Audit scale:

| Quantity | Value |
|---|---:|
| compatible completed VB screen files rescored | 30 |
| successful candidate rows rescored | 16,557 |
| family/quantile/likelihood cells | 18 |
| current-baseline all-primary frontier winners | 0 |
| cells requiring a new design axis | 8 |
| cells suitable only for small bridge screens | 10 |

## Diagnosis

The negative result is now strong enough to change strategy.

1. The recent v4 through v5.1 sequence is a plateau, not an under-sampled local
   region. Median best joint-worst ratio improved sharply at v4/v4.5 and then
   stayed near 1.05, while the maximum best joint-worst ratio stayed around
   1.8 for hard cells.
2. Older June screens that appeared to have all-metric wins do not survive
   rescoring against the current July 8 DQLM/exDQLM VB baseline. They were also
   largely exAL-only, while the current target is cell-specific AL and exAL.
3. v5.1 rows mostly converged, so simply raising VB iterations is not a global
   remedy. The notable exception is laplace tau 0.05 exAL, which hit the VB cap
   on the best local row and deserves a solver-confirmation check only after a
   better design is identified.
4. The v5.1 parameter pattern shows a structural tradeoff. Smaller/sparser
   specifications improve fit RMSE, while larger/more persistent specifications
   improve fit check loss. This is exactly the surface the last several screens
   have been walking along.
5. More local RHS-only perturbations are therefore low-value. They mostly trade
   one blocker for another without creating new information.

## Current Frontier

Ratios are against the current best DQLM/exDQLM VB baseline. Values below one
beat the baseline. `joint worst` is the worst of fit RMSE, fit check loss,
forecast MAE, and forecast check loss for the best known row in that cell.

| Family | Tau | Likelihood | Joint worst | Blockers | Recommended lane |
|---|---:|---|---:|---|---|
| gausmix | 0.05 | AL | 1.174 | fit RMSE | new design axis |
| gausmix | 0.05 | exAL | 1.617 | fit RMSE | new design axis |
| gausmix | 0.25 | AL | 1.050 | none metricwise | small bridge |
| gausmix | 0.25 | exAL | 1.052 | none metricwise | small bridge |
| gausmix | 0.50 | AL | 1.036 | none metricwise | small bridge |
| gausmix | 0.50 | exAL | 1.036 | none metricwise | small bridge |
| laplace | 0.05 | AL | 1.388 | fit RMSE, forecast MAE/check | new design axis |
| laplace | 0.05 | exAL | 1.760 | fit RMSE, fit check | new design axis |
| laplace | 0.25 | AL | 1.043 | fit RMSE | small bridge |
| laplace | 0.25 | exAL | 1.040 | fit check | small bridge |
| laplace | 0.50 | AL | 1.034 | fit check | small bridge |
| laplace | 0.50 | exAL | 1.034 | none metricwise | small bridge |
| normal | 0.05 | AL | 1.559 | fit RMSE, forecast MAE | new design axis |
| normal | 0.05 | exAL | 1.724 | fit RMSE, forecast MAE | new design axis |
| normal | 0.25 | AL | 1.026 | none metricwise | small bridge |
| normal | 0.25 | exAL | 1.036 | none metricwise | small bridge |
| normal | 0.50 | AL | 1.551 | forecast MAE/check | new design axis |
| normal | 0.50 | exAL | 1.439 | forecast MAE/check | new design axis |

## Strategy Change

The next phase should not be another broad local RHS tuning pass. It should be a
two-lane redesign:

1. Bridge lane for near cells.
2. New-design-axis lane for hard cells.

The lanes must be family, tau, and likelihood specific. A single global Q-DESN
specification is no longer the target.

## Lane A: Near-Cell Bridge Screens

Cells:

- gausmix tau 0.25 AL/exAL
- gausmix tau 0.50 AL/exAL
- laplace tau 0.25 AL/exAL
- laplace tau 0.50 AL/exAL
- normal tau 0.25 AL/exAL

These cells have evidence that the desired metrics are individually reachable,
but not always jointly in one row. The correct next action is small and
deliberate:

1. Select the best metric-specific rows from the current-baseline frontier.
2. Materialize a bridge grid that combines only the neighborhoods implied by
   those rows.
3. Keep VB-only, storage-light, and capped.
4. Require exact current-baseline dominance before any MCMC handoff.

This lane should be small: approximately 8 to 16 candidates per cell-likelihood,
not hundreds.

## Lane B: New-Design-Axis Screens

Cells:

- gausmix tau 0.05 AL/exAL
- laplace tau 0.05 AL/exAL
- normal tau 0.05 AL/exAL
- normal tau 0.50 AL/exAL

These cells should not receive another RHS-only local retuning pass. They need
new explanatory structure or a different regularization geometry.

Recommended axes:

1. Seasonal/harmonic readout structure.
   The source process is period-90. Add explicit low-dimensional seasonal
   structure instead of asking the reservoir weights to rediscover it through
   dense random features. Candidate forms should include sine/cosine period-90
   terms, compact lag-90 summaries, and short plus seasonal lag blocks.
2. Hybrid sparse-plus-seasonal reservoir input.
   Keep the sparse fit-RMSE-friendly core, but add a small deterministic
   seasonal component. This targets the normal tau 0.50 forecast failure and
   tau 0.05 tail behavior.
3. Likelihood-specific design, not shared AL/exAL design.
   AL and exAL fail differently. AL often stalls near fit check loss, while exAL
   can fail harder on fit RMSE in tail cells. Materialization should permit
   likelihood-specific candidates.
4. Solver confirmation only for credible rows.
   Raise VB iterations or tighten tolerance only after a candidate is already
   scientifically close. Do not use solver changes as a broad screen axis.
5. Consider non-RHS comparator designs for hard cells.
   If a hard cell stays blocked after seasonal/hybrid features, compare against
   ridge or structured shrinkage variants again under the current protocol.

## Proposed Build Plan

### build-01-current-frontier-freeze

Use `scripts/audit_qdesn_tt500_vb_break_surface_redesign.R` as the canonical
current-baseline rescoring step. No new model runs.

Required outputs:

- current-baseline frontier CSV
- run trend CSV
- v5.1 blocker CSV
- v5.1 parameter-correlation CSV

### build-02-bridge-grid-materializer

Create a materializer for Lane A only. Inputs are the current-baseline frontier
and the source screen summaries. Output is a small cell-likelihood-specific
bridge grid.

Guardrails:

- no hard cells in bridge grid
- no MCMC methods
- no routine `.rds`, `.rda`, or `.RData` payload retention
- every candidate must record source profile, current-baseline blockers, and
  intended metric target

### build-03-new-axis-grid-materializer

Create a separate materializer for Lane B. It should introduce explicit
seasonal/harmonic and hybrid sparse-plus-seasonal design fields rather than
only perturbing `D`, `n_each`, `alpha`, `rho`, `m`, `pi_w`, `pi_in`, and
`rhs_tau0`.

Required design columns:

- design_axis
- seasonal_feature_mode
- seasonal_period
- seasonal_lag_block
- raw_lag_block
- reservoir_width_mode
- likelihood_target
- blocker_target
- source_frontier_row

### build-04-dry-materialization-audit

Before launch, run only materialization and schema checks:

- all paths canonical under `/data/jaguir26/local/src`
- no `/home/jaguir26/local/src` active paths
- exact source registry hash retained
- all roots have `family`, `tau`, `likelihood_family`, `design_axis`, and
  `blocker_target`
- no forbidden binary files produced
- no accidental Article/PriceFM/GloFAS/joint-QVP paths

### build-05-small-VB-screen-only-after-approval

Launch only after explicit approval. Suggested sequence:

1. Lane A bridge screen first because it is smaller and likely to resolve some
   near cells.
2. Audit Lane A dominance.
3. Lane B new-axis screen for hard cells.
4. Audit Lane B dominance.
5. Promote only strict current-baseline VB winners to MCMC.

## MCMC Promotion Policy

No Q-DESN candidate from these redesign screens is MCMC-promotable unless it:

1. completes successfully,
2. is storage-light,
3. beats the current DQLM/exDQLM VB baseline on fit RMSE,
4. beats the current DQLM/exDQLM VB baseline on fit check loss,
5. beats the current DQLM/exDQLM VB baseline on rolling-origin forecast MAE,
6. beats the current DQLM/exDQLM VB baseline on rolling-origin forecast check
   loss,
7. carries exact source registry provenance, branch, commit, run tag, and
   configuration hash,
8. has a strict audit table proving the above.

## Why This Is Better Than Another Broad RHS Screen

Another v5-style broad RHS screen would continue to search the same axes that
already show a stable tradeoff. The new plan separates near cells from hard
cells, changes the design space for hard cells, keeps bridge screens small, and
prevents MCMC compute until a current-baseline VB result actually clears the
scientific gate.

## Implementation Status

Implemented on 2026-07-13 as no-launch infrastructure only.

Materializer:

```bash
cd /data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0
Rscript scripts/materialize_qdesn_tt500_vb_break_surface_redesign.R --lane both --workers 20
```

Dry materialization audit:

```bash
Rscript scripts/audit_qdesn_tt500_vb_break_surface_materialization.R --lane both
```

Generated configuration bundles:

- Lane A bridge profiles:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_break_surface_bridge_profiles.csv`
- Lane A bridge assignments:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_break_surface_bridge_cell_assignments.csv`
- Lane A bridge defaults:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_break_surface_bridge_defaults.yaml`
- Lane A bridge grid:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_break_surface_bridge_grid.csv`
- Lane B new-axis profiles:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_break_surface_newaxis_profiles.csv`
- Lane B new-axis assignments:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_break_surface_newaxis_cell_assignments.csv`
- Lane B new-axis defaults:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_break_surface_newaxis_defaults.yaml`
- Lane B new-axis grid:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_break_surface_newaxis_grid.csv`

Generated evidence:

- materialization index:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/posthoc/qdesn_tt500_vb_break_surface_redesign_20260713/materialization/qdesn_tt500_vb_break_surface_materialization_index.csv`
- dry audit summary:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/posthoc/qdesn_tt500_vb_break_surface_redesign_20260713/materialization_audit/summary/qdesn_tt500_vb_break_surface_materialization_audit.md`
- dry audit table:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/posthoc/qdesn_tt500_vb_break_surface_redesign_20260713/materialization_audit/tables/qdesn_tt500_vb_break_surface_materialization_audit.csv`

Dry audit result:

| Lane | Status | Profiles | Roots | Meaning |
|---|---|---:|---:|---|
| bridge | DRY_PASS | 90 | 90 | schema/path/storage checks pass; explicit human launch approval still required |
| newaxis | DRY_PASS_LAUNCH_BLOCKED | 48 | 48 | schema/path/storage checks pass, but seasonal/harmonic design metadata requires runner support or explicit ignore-policy before launch |

The generated defaults use `execution.methods: vb`. Some inactive MCMC tuning
blocks remain inherited from the v5.1 base defaults for compatibility with the
existing package configuration shape, but the executable stage method list is
VB-only and the dry audit rejects any defaults whose active methods include
MCMC.

Added local tests:

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-qdesn-tt500-vb-break-surface-redesign.R")'
```

## Do Not Launch Yet

The next allowed action is implementation of the materializers and dry
materialization checks only. No VB screen, MCMC screen, smoke, pilot, or full
launch should run until the grid design is inspected and explicitly approved.

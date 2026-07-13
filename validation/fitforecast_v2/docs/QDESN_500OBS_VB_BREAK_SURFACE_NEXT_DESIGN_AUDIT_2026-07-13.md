# Q-DESN 500-Observation VB Break-Surface Next-Design Audit

- date: 2026-07-13
- worktree: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`
- branch: `validation/shared-fitforecast-v2-1.0.0`
- scope: independent Q-DESN versus DQLM/exDQLM fit+forecast validation
- launch status: no launch requested, no launch performed
- purpose: revise the next calibration plan after verifying that the current
  local RHS search is stuck on a structural tradeoff surface

Follow-up refinement: after a deeper runner and decomposition-support audit,
the active next implementation plan is the mechanism-first decomposition-aware
redesign in
`validation/fitforecast_v2/docs/QDESN_500OBS_VB_MECHANISM_FIRST_REDESIGN_PLAN_2026-07-13.md`.

## Bottom Line

Do not launch another broad RHS/local-neighborhood screen as the next move. The
evidence says the current search family is mostly trading fit RMSE against check
loss and forecast metrics. The new-axis materialization created on 2026-07-13
is useful as a design sketch, but it is not yet a launchable scientific screen
because several intended design fields are metadata only under the current
runner.

The optimal next step is a no-compute implementation/audit pass that makes the
new design axes real, preferably through stage-level deterministic feature
bundles already supported by the current runner. Only after that should we run
tiny hard-cell VB probes. MCMC remains blocked until strict current-baseline VB
dominance is demonstrated cell by cell.

## Evidence Checked

Commands:

```bash
cd /data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0
git status -sb
git log --oneline --decorate -5
Rscript scripts/audit_qdesn_tt500_vb_break_surface_redesign.R
Rscript scripts/audit_qdesn_tt500_vb_break_surface_materialization.R --lane both
rg -n "deterministic_features|screening_profile|seasonal_feature_mode|likelihood_target|readout_y_lags|reservoir_lags|rhs_tau0" \
  R/qdesn_fitforecast_launch_plan.R \
  R/qdesn_dynamic_exdqlm_crossstudy.R \
  scripts/orchestrate_qdesn_tt500_vb_dominance_screening.R \
  scripts/materialize_qdesn_tt500_vb_break_surface_redesign.R
tmux list-sessions
ps -u "$USER" -o pid,ppid,stat,etime,pcpu,pmem,cmd | rg -i "qdesn|dqlm|fitforecast|validation_rhs|break_surface|Rscript"
```

Primary evidence paths:

- current-baseline frontier:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/posthoc/qdesn_tt500_vb_break_surface_redesign_20260713/tables/qdesn_tt500_vb_current_baseline_frontier.csv`
- v4 through v5.1 run trend:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/posthoc/qdesn_tt500_vb_break_surface_redesign_20260713/tables/qdesn_tt500_vb_current_baseline_run_trend.csv`
- v5.1 blockers:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/posthoc/qdesn_tt500_vb_break_surface_redesign_20260713/tables/qdesn_tt500_vb_v51_by_likelihood_blockers.csv`
- v5.1 parameter correlations:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/posthoc/qdesn_tt500_vb_break_surface_redesign_20260713/tables/qdesn_tt500_vb_v51_parameter_correlations.csv`
- materialization audit:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/posthoc/qdesn_tt500_vb_break_surface_redesign_20260713/materialization_audit/tables/qdesn_tt500_vb_break_surface_materialization_audit.csv`

## Diagnosis

The last several Q-DESN RHS VB screens are no longer giving useful scientific
information.

| Finding | Evidence | Interpretation |
|---|---|---|
| No current-baseline all-primary wins | v4 through v5.1 all have zero all-primary cell wins | The broad local search has not found a cell-specific dominant VB candidate. |
| Median frontier plateau | v4 through v5.1 median joint-worst ratio stays near 1.05 | Extra local variants are producing marginal movement, not breakthroughs. |
| Hard-cell maximum remains large | max joint-worst ratio stays near 1.8 | Some cells need a different design mechanism, not more local tuning. |
| Tradeoff is structural | `p_over_n_tt500`, `m`, `rho`, and `alpha` correlate positively with fit RMSE but can help check loss | Bigger or more persistent reservoirs help one criterion while hurting another. |
| Solver is not the global blocker | Most v5.1 frontier rows converged; one important laplace 0.05 exAL row hit the cap | Raising VB iterations is a confirmation tool, not the next broad axis. |
| Current new-axis materialization is launch-blocked | materialization audit: `newaxis = DRY_PASS_LAUNCH_BLOCKED` | The design idea is promising, but the runner must make the intended axes active first. |

Hard cells requiring a true new design axis:

| Family | Tau | Likelihood | Main blockers | Best current joint-worst ratio |
|---|---:|---|---|---:|
| gausmix | 0.05 | AL | fit RMSE | 1.174 |
| gausmix | 0.05 | exAL | fit RMSE | 1.617 |
| laplace | 0.05 | AL | fit RMSE, forecast MAE/check | 1.388 |
| laplace | 0.05 | exAL | fit RMSE, fit check | 1.760 |
| normal | 0.05 | AL | fit RMSE, forecast MAE | 1.559 |
| normal | 0.05 | exAL | fit RMSE, forecast MAE | 1.724 |
| normal | 0.50 | AL | forecast MAE/check | 1.551 |
| normal | 0.50 | exAL | forecast MAE/check | 1.439 |

Near cells suitable for small bridge screens only:

- gausmix tau 0.25 AL/exAL
- gausmix tau 0.50 AL/exAL
- laplace tau 0.25 AL/exAL
- laplace tau 0.50 AL/exAL
- normal tau 0.25 AL/exAL

## Runner-Support Audit

The current screening-profile loader validates and uses these active profile
columns:

- `D`, `n_each`, `n_tilde_each`, `m`, `alpha`, `rho`, `pi_w`, `pi_in`
- `washout`, `add_bias`, `seed`
- `readout_y_lags`, `reservoir_lags`, `rhs_tau0`
- dimension/provenance columns used for validation and audit

The current runner applies only these profile-level overrides to model
configuration:

- `readout_y_lags` -> response lag count
- `reservoir_lags` -> readout reservoir lag count
- `rhs_tau0` -> RHS prior scale
- reservoir shape and sparsity fields

The following new-axis fields are currently metadata unless additional runner
support or stage-level defaults make them active:

- `design_axis`
- `seasonal_feature_mode`
- `seasonal_period`
- `seasonal_lag_block`
- `raw_lag_block`
- `reservoir_width_mode`
- `likelihood_target`
- `blocker_target`

The current code already supports deterministic Fourier-style features through
stage-level defaults:

- `defaults$deterministic_features`
- `.qdesn_dynamic_crossstudy_make_deterministic_features(source_index, defaults)`

That support is stage-global, not profile-specific. Therefore a mixed-profile
new-axis grid with different `seasonal_feature_mode` values would not actually
test different seasonal feature modes unless we either split the runs into
stage-level bundles or extend the runner.

## Revised Strategy

### Principle 1: Stop Searching the Same Surface

Do not spend more compute on broad RHS-only variants that adjust only reservoir
size, sparsity, persistence, lag count, and RHS scale. Those axes have been
searched enough to reveal a stable tradeoff, especially between fit RMSE and
check-loss/forecast behavior.

### Principle 2: Make New Axes Real Before Running Them

The next screen must alter the information available to the model, not only the
regularization. The most practical first mechanism is deterministic seasonal
structure, because the simulation source has a known recurring component and
the current runner already has stage-level deterministic feature support.

### Principle 3: Keep Design Case-Specific

We should not require one Q-DESN specification to win everywhere. The plan must
remain family, tau, and likelihood specific. The target is a per-cell best
candidate that dominates or nearly matches the DQLM/exDQLM VB baseline on the
four article-facing metrics.

### Principle 4: Do Not Promote to MCMC Until VB Earns It

MCMC is expensive and should only be used for cells where VB shows a credible
current-protocol candidate. Any MCMC handoff must carry the exact per-cell
profile, feature-mode bundle, source registry identity, and strict dominance
audit.

## Better Build Plan

### build-A: Freeze the Current Evidence

Status: already available, but keep as the canonical starting point.

Deliverables:

- current-baseline frontier table
- run-trend table
- v5.1 blocker table
- v5.1 correlation table
- materialization audit table

Gate:

- no active current break-surface launch
- git worktree clean before implementation

### build-B: Split the Next Work Into Three Lanes

Lane 1: bridge only.

- Purpose: harvest near-cell wins where individual metrics are already close.
- Scope: the 10 near cells.
- Design: small interpolations among existing best rows.
- Risk: low.
- Expected value: may close small gaps, but unlikely to fix hard cells.

Lane 2: stage-level deterministic feature probes.

- Purpose: break the hard-cell surface by adding low-dimensional source-aligned
  information.
- Scope: the 8 hard cells.
- Design: separate stage bundles, not mixed profile metadata.
- Candidate stage bundles:
  - no deterministic features control
  - period-90 sine/cosine harmonics 1 and 2
  - period-90 sine/cosine harmonics 1 and 2 plus trend
  - period-90 sine/cosine harmonics 1 through 3 if the first probe moves the
    frontier
- Risk: moderate, because feature columns change the staged observed data.
- Gate: source registry and source window hashes must remain stable; staged
  feature manifests must prove the added columns.

Lane 3: runner extension only if stage-level probes are insufficient.

- Purpose: allow per-profile feature modes and likelihood-specific filters
  inside one screen.
- Scope: implementation only after lane 2 shows signal or reveals the need for
  profile-level feature variation.
- Risk: higher, because it touches launcher semantics.
- Gate: tests for per-profile feature activation, forecast-origin feature
  consistency, and likelihood-target filtering.

Recommended order:

1. Lane 2 tiny hard-cell deterministic feature probe.
2. Lane 1 bridge screen if we want quick near-cell cleanup.
3. Lane 3 runner extension only if required by lane 2 results.

This ordering is better than launching the current bridge first if the main
scientific issue is hard-cell failure. Bridge is safe but incremental. The
seasonal feature probe is the first credible break from the exhausted surface.

### build-C: Implement a Stage-Level Feature Bundle Materializer

No model fitting in this build.

Required outputs:

- defaults YAML for each feature bundle
- grid CSV for each bundle
- profile CSV for each bundle
- cell assignment CSV for each bundle
- manifest JSON recording:
  - source registry identity and hash
  - feature bundle label
  - deterministic feature config
  - intended hard cells
  - expected staged feature columns
  - active methods set to VB only
  - storage-light policy

Required design controls:

- one bundle per deterministic feature mode
- hard-cell only by default
- likelihood-target labels retained
- no MCMC method in active execution
- no routine successful `.rds`, `.rda`, or `.RData` retention

### build-D: Add a Dry Feature Activation Audit

No model fitting in this build.

Audit requirements:

- staged `observed.csv` and `q_true.csv` contain the expected deterministic
  feature columns for feature bundles
- control bundle contains no extra deterministic feature columns
- feature values at fit windows and rolling-origin forecast windows are
  reproducible from source indices
- source registry identity and source hashes are unchanged
- forecast-origin and horizon metadata are unchanged
- no `/home/jaguir26/local/src` active paths
- no forbidden binary artifacts from prepare-only paths
- no Article, PriceFM, GloFAS, or joint-QVP paths

### build-E: Add Likelihood-Target Enforcement Before Compute

Before any full screen, avoid wasting work on likelihoods that a profile was
not designed for.

Preferred low-risk implementation:

- materialize separate AL and exAL stage grids, or
- add a launcher-side preflight that errors if a profile-likelihood target is
  present but the execution likelihood grid would run extra likelihoods.

Do not rely on `likelihood_target` as passive metadata for launched runs.

### build-F: Tiny VB Probe After Explicit Approval

Only after builds C through E pass.

Probe cells:

- gausmix tau 0.05 exAL
- laplace tau 0.05 exAL
- normal tau 0.50 AL
- normal tau 0.05 exAL

Probe size:

- 2 to 4 feature bundles
- 4 to 8 candidates per cell-likelihood-bundle
- VB only
- storage-light only

Success signal:

- at least one hard cell reduces the joint-worst ratio materially
- no new catastrophic fit RMSE/check-loss tradeoff
- forecast metrics improve in normal tau 0.50 cells
- strict audit table can identify a per-cell winner or near winner

### build-G: Expand Only the Winning Mechanism

If the tiny probe moves the frontier, expand only the mechanism that moved it.
Do not expand all axes. Examples:

- if period-90 harmonics improve normal tau 0.50 forecast, refine harmonics and
  lag balance there
- if period-90 plus trend improves tau 0.05 tails, refine only tail cells
- if no feature bundle helps, stop and reassess model class, not RHS tuning

### build-H: MCMC Handoff

MCMC remains blocked until the VB audit identifies strict or compelling
per-cell winners. Handoff inputs must include:

- exact profile row
- exact deterministic feature bundle
- exact likelihood
- exact family and tau
- VB evidence table
- source registry hash
- source window and rolling-origin horizon metadata
- package branch and commit
- storage-light artifact manifest

## What Not To Do

- Do not launch the current `newaxis` bundle as-is.
- Do not assume `seasonal_feature_mode` changes the fitted model.
- Do not launch another v5-style broad RHS-only local search.
- Do not promote bridge candidates to MCMC unless they beat the current
  DQLM/exDQLM VB baseline under strict current-protocol audit.
- Do not update article tables from this planning work.
- Do not touch Article, PriceFM, GloFAS, or joint-QVP files.

## Next Safe Commands

No launch commands are approved by this document. The next safe commands are
implementation and audit commands only, for example:

```bash
cd /data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0

# implement only: create stage-level feature-bundle materializer and dry audit
# then run dry/preflight checks, not VB fitting
Rscript scripts/materialize_qdesn_tt500_vb_feature_bundle_probe.R --dry-run
Rscript scripts/audit_qdesn_tt500_vb_feature_bundle_probe.R
```

Those script names are proposed next-build names. They should not be treated as
existing launch commands until implemented and tested.

## Decision

The next scientific move is not more breadth on the same axes. It is a
mechanism change with hard launch gates:

1. implement stage-level deterministic-feature bundle materialization,
2. audit that the feature columns are truly active and forecast-consistent,
3. enforce likelihood-target execution,
4. run a tiny hard-cell VB probe only after explicit approval,
5. expand or stop based on whether that probe breaks the current tradeoff.

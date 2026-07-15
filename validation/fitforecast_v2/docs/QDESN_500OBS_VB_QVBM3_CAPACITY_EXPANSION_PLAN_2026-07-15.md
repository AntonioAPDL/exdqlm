# Q-DESN 500-Observation VB QVBM3 Capacity Expansion Plan

- date: 2026-07-15
- worktree: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`
- branch: `validation/shared-fitforecast-v2-1.0.0`
- scope: Q-DESN versus DQLM/exDQLM shared fit+forecast validation only
- status: plan only; no materialization, dry run, smoke, VB launch, or MCMC launch

## Purpose

The current Q-DESN VB calibration baseline is intentionally compact. It is now
useful as a reproducible reference, but it is not a final scientific answer. The
next experiment should deliberately test whether substantially more flexible
Q-DESN specifications can break the observed fit/forecast tradeoff surface.

This plan defines a new broad experiment family, `qvbm3`, with larger depth,
larger reservoir width, and longer lag memory:

- `D` up to `4`
- `n_each` up to `300`
- `m` and `readout_y_lags` up to `150`

The plan is VB-first. MCMC is explicitly out of scope until a candidate clears
the strict current-baseline dominance gates.

## Current Evidence

The frozen baseline/disposition artifact is:

```text
validation/fitforecast_v2/docs/QDESN_500OBS_VB_BASELINE_FREEZE_AND_DIAGNOSTIC_DISPOSITION_2026-07-15.md
```

Current frozen interpretation:

- `qvbm1` is the active Q-DESN VB calibration baseline, not article-facing and
  not MCMC-promoted.
- `qvbm2` and `qvbm2p3` are complete diagnostic screens, not promotion sources.
- No current Q-DESN VB screen clears the external all-four DQLM/exDQLM gate.

Historical Q-DESN profile maxima already present in the worktree:

| Quantity | Historical maximum observed |
|---|---:|
| `D` | 3 |
| `n_each` | 70 |
| `D * n_each` | 140 |
| `m` | 90 |
| `readout_y_lags` | 90 |
| `dimension_p_estimate` | 246 |

The requested `qvbm3` expansion is therefore a real extrapolation, not just a
small refinement of previous grids.

## Key Design Principle

Do not run a naive full factorial grid. The full cross-product of
`D`, `n_each`, `m`, `alpha`, `rho`, `pi_w`, `pi_in`, `rhs_tau0`, family, tau,
and likelihood would be too expensive, hard to interpret, and likely dominated
by redundant bad rows.

Instead, use a staged design-of-experiments screen:

1. canary capacity screen;
2. adaptive expansion around promising capacity tiers;
3. solver confirmation for only credible rows;
4. MCMC handoff only for strict VB winners.

## Interpretation Of The Incomplete Constraint

The request included the phrase "do not use" without an object. Until clarified,
this plan assumes the conservative interpretation:

- do not use qvbm2/qvbm2p3 as promotion sources;
- do not use metadata-only seasonal or harmonic design fields as launchable
  rows unless runner support is verified;
- do not use MCMC during the broad capacity screen;
- do not use successful but non-dominating rows as article-facing evidence.

## Capacity Risk Tiers

Approximate design dimension should be tracked for every row:

```text
dimension_p_estimate ~= 1 + D * n_each + readout_y_lags + optional_features + constants
```

For 500 training observations:

| Tier | Approximate `p / 500` | Policy |
|---|---:|---|
| green | `<= 0.75` | eligible for broad screen |
| amber | `(0.75, 1.50]` | eligible for targeted hard-cell screen |
| red | `> 1.50` | canary only; never full broad launch without evidence |

Examples:

| `D` | `n_each` | `m` | Approx. `p` | Approx. `p/500` | Tier |
|---:|---:|---:|---:|---:|---|
| 3 | 100 | 60 | 366 | 0.73 | green |
| 3 | 100 | 150 | 456 | 0.91 | amber |
| 4 | 100 | 150 | 556 | 1.11 | amber |
| 3 | 200 | 150 | 756 | 1.51 | red edge |
| 4 | 200 | 150 | 956 | 1.91 | red |
| 4 | 300 | 150 | 1356 | 2.71 | red stress canary |

The plan considers `n_each = 200` and `300`, but only through canaries or
adaptive rows after smaller expensive rows show real evidence.

## Experiment Family

Proposed family name:

```text
qvbm3_capacity_expansion
```

Suggested generated run tags:

```text
qdesn-vb-qvbm3-capacity-canary
qdesn-vb-qvbm3-capacity-adaptive
qdesn-vb-qvbm3-capacity-confirm
```

Suggested config prefix:

```text
config/validation/qvbm3_capacity_*
```

Suggested report/result roots:

```text
reports/qvbm3_capacity/
results/qvbm3_capacity/
```

## Candidate Axes

### Structural Capacity

Primary values:

| Axis | Values |
|---|---|
| `D` | `2`, `3`, `4` |
| `n_each` | `50`, `70`, `100`, `150`, `200`, `300` |
| `m` / `readout_y_lags` | `30`, `60`, `90`, `150` |
| `reservoir_lags` | `0`, `1` |

Rules:

- `D = 4, n_each >= 200` is canary-only until there is evidence that cheaper
  rows improve the hard cells.
- `m = 150` should be paired with no more than one or two width/depth settings
  per cell in the initial canary.
- `reservoir_lags = 1` is a targeted axis, not a broad default.

### Dynamics

Primary values:

| Axis | Values |
|---|---|
| `alpha` | `0.0005`, `0.001`, `0.0025`, `0.005`, `0.01`, `0.03`, `0.05` |
| `rho` | `0.35`, `0.50`, `0.65`, `0.80`, `0.90`, `0.97` |

Recommended pairings:

| Role | `alpha` | `rho` | Intended target |
|---|---:|---:|---|
| very slow memory | `0.0005`, `0.001` | `0.80`, `0.90`, `0.97` | tail/forecast persistence |
| balanced memory | `0.0025`, `0.005`, `0.01` | `0.50`, `0.65`, `0.80` | fit/forecast balance |
| faster adaptation | `0.03`, `0.05` | `0.35`, `0.50`, `0.65` | fit RMSE rescue |

### Shrinkage / Sparsity

Primary values:

| Axis | Values |
|---|---|
| `pi_w` | `0.0005`, `0.001`, `0.0025`, `0.005`, `0.01`, `0.03` |
| `pi_in` | `0.03`, `0.05`, `0.10`, `0.30` |
| `rhs_tau0` | `1e-4`, `3e-4`, `1e-3`, `3e-3` |

Rules:

- Do not reuse the invalid tiny `rhs_tau0 = 3e-05` p03 surface.
- Larger `D * n_each` must use stronger sparsity in canaries.
- Weaker shrinkage is allowed only after a row passes finite/stability gates.

## Cell-Specific Design

The target unit is family x tau x likelihood. Do not seek one global
specification for all cells.

Cells:

| Family | Tau values | Likelihoods |
|---|---|---|
| gausmix | `0.05`, `0.25`, `0.50` | `AL`, `exAL` |
| laplace | `0.05`, `0.25`, `0.50` | `AL`, `exAL` |
| normal | `0.05`, `0.25`, `0.50` | `AL`, `exAL` |

Each cell should receive:

- a compact baseline-adjacent row;
- a green capacity row;
- an amber capacity row;
- one hard-cell stress canary only if the current frontier says the cell is
  still blocked.

## Proposed Stages

### build-01-qvbm3-audit-freeze

Read-only.

Inputs:

- qvbm1 baseline freeze CSV;
- qvbm2/qvbm2p3 disposition CSVs;
- current DQLM/exDQLM VB baseline table;
- latest Q-DESN VB frontier tables.

Outputs:

- cell-level blocker table;
- prior candidate maxima table;
- hard/near/easy cell classification;
- cost-risk table for candidate architecture tiers.

No model runs.

### build-02-qvbm3-design-matrix

Generate a reproducible design matrix, but do not launch.

Expected scale:

| Stage | Target rows per cell-likelihood | Total roots |
|---|---:|---:|
| canary | `6` to `10` | `108` to `180` |
| adaptive | `8` to `16` only for unresolved cells | depends on blockers |
| confirm | `1` to `3` only for candidate winners | depends on winners |

The initial canary should include at least:

| Profile role | `D` | `n_each` | `m` | Notes |
|---|---:|---:|---:|---|
| green_deep_balanced | 3 | 100 | 60 | first serious capacity jump |
| green_deep_long | 3 | 100 | 90 | longer memory, still feasible |
| amber_deep_long | 3 | 100 | 150 | tests long lag memory |
| amber_wide_balanced | 3 | 150 | 60 | width versus lag comparison |
| amber_four_layer | 4 | 100 | 90 | tests depth at moderate width |
| red_edge_sparse | 3 | 200 | 150 | stress row with strong sparsity |
| red_four_layer_sparse | 4 | 200 | 90 | stress row with strong sparsity |
| red_extreme_single | 4 | 300 | 150 | one stress canary only, not broad |

### build-03-qvbm3-materializer

Implement a materializer only after design review.

Required outputs:

- `config/validation/qvbm3_capacity_profiles.csv`
- `config/validation/qvbm3_capacity_cell_assignments.csv`
- `config/validation/qvbm3_capacity_grid.csv`
- `config/validation/qvbm3_capacity_defaults.yaml`
- `config/validation/qvbm3_capacity_target_spec_ids.csv`
- `config/validation/qvbm3_capacity_materialization_manifest.json`

Required profile columns:

- `screening_profile_id`
- `screening_stage`
- `screening_wave`
- `profile_role`
- `D`
- `n_each`
- `n_tilde_each`
- `m`
- `readout_y_lags`
- `reservoir_lags`
- `alpha`
- `rho`
- `pi_w`
- `pi_in`
- `rhs_tau0`
- `dimension_p_estimate`
- `p_over_n_tt500`
- `capacity_tier`
- `cell_target_role`
- `target_family`
- `target_tau`
- `likelihood_target`
- `blocker_target`
- `source_baseline_screen`
- `source_frontier_row`
- `launch_gate`

### build-04-qvbm3-dry-audit

Run dry checks before launch.

Required checks:

- paths canonical under `/data/jaguir26/local/src`;
- no active `/home/jaguir26/local/src` paths;
- source registry hash retained;
- no Article-Q-DESN, PriceFM, GloFAS, or joint-QVP paths;
- active method list is VB only;
- no forbidden `.rds`, `.rda`, `.RData` payloads in dry paths;
- every row has family, tau, likelihood, capacity tier, and blocker target;
- no invalid `rhs_tau0`;
- red-tier rows capped to the predeclared canary count;
- expected roots match manifest counts.

### build-05-qvbm3-canary-launch

Launch only after explicit approval.

Policy:

- VB only;
- storage-light only;
- one process per root;
- conservative worker count until memory use is measured;
- stop-after-failure threshold for catastrophic numerical issues;
- no automatic MCMC handoff.

Recommended worker policy:

| Machine cores | Suggested workers | Reason |
|---:|---:|---|
| 64 | `16` to `24` initial | large rows may be memory-heavy |
| 64 after memory audit | up to `32` | only if canaries are stable |

### build-06-qvbm3-closeout

Closeout must compare each row against both:

1. frozen qvbm1 Q-DESN VB baseline;
2. current DQLM/exDQLM VB baseline.

Primary gates:

- fit RMSE ratio `< 1`;
- fit check-loss ratio `< 1`;
- rolling-origin forecast MAE ratio `< 1`;
- rolling-origin forecast check-loss ratio `< 1`.

Secondary diagnostics:

- runtime;
- convergence flag;
- finite/domain checks;
- warning/failure stage;
- signoff grade;
- storage-light compliance.

### build-07-adaptive-expansion

Only cells with credible improvement should be expanded.

Expansion rules:

- if fit improves but forecast worsens, vary `rho`, `m`, and `reservoir_lags`;
- if forecast improves but fit worsens, vary `alpha`, `pi_w`, and `rhs_tau0`;
- if both improve but not enough, interpolate around the winning profile;
- if neither improves in a cell, stop that cell and mark the architecture axis
  as non-promising.

### build-08-solver-confirm

Only for candidates already close to dominance.

Recommended confirmation:

- increase VB max iterations from screening cap to a confirm cap;
- keep the same source registry, same row spec, and same root ID family;
- compare confirm rows to their screening rows to separate solver effects from
  model effects.

### build-09-mcmc-handoff

No MCMC until VB has strict evidence.

MCMC candidates must be per-cell winners, not global defaults. A handoff row
must include:

- exact VB source profile;
- exact config hash;
- exact source registry hash;
- cell-specific dominance evidence;
- storage-light artifact manifest;
- explicit MCMC launch approval.

## Expected Failure Modes

| Risk | Mitigation |
|---|---|
| `p / n` too high | tiered canaries and red-tier caps |
| VB collapse under large weakly sparse designs | strong sparsity defaults for large rows |
| very slow runs | launch canary before broad adaptive expansion |
| false wins from solver noise | confirmation stage before MCMC |
| incomparable results | same frozen registry and same rolling-origin protocol |
| unimplemented design metadata | dry audit blocks metadata-only rows |

## Stop Rules

Stop or pause the screen if:

- more than 20% of canary rows fail with the same numerical error;
- any red-tier row produces unexpected heavy artifacts;
- active memory use causes swapping or threatens other work;
- the closeout cannot reconstruct all source/config hashes;
- a row touches any non-validation path.

## Implementation Status

Implemented as no-compute infrastructure on 2026-07-15.

The deeper audit refined the draft plan in one important way: the first qvbm3
screen should not cover every family/tau/likelihood cell. It should target the
eight unresolved hard cells for which qvbm1/qvbm2/qvbm2p3 provide direct
diagnostic evidence. This keeps the test broad over model capacity while
avoiding a wasteful full-cell sweep.

Implemented scripts:

```text
scripts/audit_qdesn_tt500_vb_qvbm3_capacity_expansion.R
scripts/materialize_qdesn_tt500_vb_qvbm3_capacity_expansion.R
scripts/audit_qdesn_tt500_vb_qvbm3_capacity_materialization.R
```

Commands run:

```bash
cd /data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0
Rscript scripts/audit_qdesn_tt500_vb_qvbm3_capacity_expansion.R
Rscript scripts/materialize_qdesn_tt500_vb_qvbm3_capacity_expansion.R --workers 20
Rscript scripts/audit_qdesn_tt500_vb_qvbm3_capacity_materialization.R
```

Generated configuration:

```text
config/validation/qvbm3_capacity_bundle_index.csv
config/validation/qvbm3_capacity_bundle_index_manifest.json
config/validation/qvbm3_capacity_c12_profiles.csv
config/validation/qvbm3_capacity_c12_cell_assignments.csv
config/validation/qvbm3_capacity_c12_grid.csv
config/validation/qvbm3_capacity_c12_defaults.yaml
config/validation/qvbm3_capacity_c12_target_spec_ids.csv
config/validation/qvbm3_capacity_c12_materialization_manifest.json
config/validation/qvbm3_capacity_c123_profiles.csv
config/validation/qvbm3_capacity_c123_cell_assignments.csv
config/validation/qvbm3_capacity_c123_grid.csv
config/validation/qvbm3_capacity_c123_defaults.yaml
config/validation/qvbm3_capacity_c123_target_spec_ids.csv
config/validation/qvbm3_capacity_c123_materialization_manifest.json
```

Generated evidence:

```text
reports/qvbm3_capacity/audit/qvbm3_capacity_prelaunch_20260715/summary/qvbm3_capacity_prelaunch_audit.md
reports/qvbm3_capacity/audit/qvbm3_capacity_prelaunch_20260715/tables/qvbm3_current_cell_blockers.csv
reports/qvbm3_capacity/audit/qvbm3_capacity_prelaunch_20260715/tables/qvbm3_capacity_tiers.csv
reports/qvbm3_capacity/audit/qvbm3_capacity_prelaunch_20260715/manifest/qvbm3_capacity_prelaunch_audit_manifest.json
reports/qvbm3_capacity/audit/qvbm3_capacity_materialization_20260715/summary/qvbm3_capacity_materialization_audit.md
reports/qvbm3_capacity/audit/qvbm3_capacity_materialization_20260715/tables/qvbm3_capacity_materialization_audit.csv
reports/qvbm3_capacity/audit/qvbm3_capacity_materialization_20260715/manifest/qvbm3_capacity_materialization_audit_manifest.json
```

Dry audit result:

| Bundle | Status | Profiles | Target specs | Red-tier profiles | Extreme profiles | Max `D` | Max `n_each` | Max `m` | Max `p/500` |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| c12 | DRY_PASS | 33 | 33 | 9 | 1 | 4 | 300 | 150 | 2.712 |
| c123 | DRY_PASS | 33 | 33 | 9 | 1 | 4 | 300 | 150 | 2.712 |

Total planned VB target specs: `66`.

No compute has been launched. The defaults are VB-only, MCMC handoff remains
closed, and the dry audit passed the stale-path, wrong-lane, storage-light,
capacity-cap, target-spec, and red-tier stress-canary gates.

## Recommendation

The next action is to review the generated qvbm3 design matrix and then decide
whether to launch the 66-root VB canary. Do not launch MCMC from qvbm3.

The most valuable initial scientific test is not the single largest model. It is
whether the green and amber capacity tiers (`D=3/4`, `n_each=100/150`,
`m=60/90/150`) improve hard cells without destroying forecast performance. The
`D=4, n_each=300, m=150` row should be present only as a capped stress canary.

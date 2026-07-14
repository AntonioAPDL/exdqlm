# Q-DESN 500-Observation VB Blocker-Aware qvbm2 Plan

- date: `2026-07-14`
- worktree: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`
- branch: `validation/shared-fitforecast-v2-1.0.0`
- predecessor screen: `qvbm1_decomp_guardfix_20260713_main__git-8c6eda9`
- predecessor closeout table: `reports/qvbm1/audit/closeout/qvbm1_decomp_guardfix_20260713_main__git-8c6eda9/tables/qvbm1_mechanism_first_ratio_blockers.csv`
- article policy: no Article-Q-DESN update from this screen until a completed strict audit promotes a candidate

## Decision

The qvbm1 mechanism-first screen is closed as diagnostic evidence. It completed
successfully and stayed storage-light, but it produced zero MCMC-promotable
per-cell winners under the conservative handoff gate. The next step is therefore
not MCMC and not another broad undirected screen. The next step is a smaller
blocker-aware VB follow-up that uses the qvbm1 signal while directly targeting
the failed ratios.

## qvbm1 Evidence Used

| Evidence | Finding | Consequence |
|---|---|---|
| Fit completion | `192 / 192` roots complete | qvbm1 is operationally closed |
| Rolling-origin rows | `5760 / 5760` lead rows complete | forecast evidence is complete |
| Storage-light audit | no forbidden `.rds`, `.rda`, `.RData`, or `__design.rds` payloads | qvbm1 can be retained as metadata/scalar evidence |
| Bundle winners | `c12` wins 4 cells, `c123` wins 4 cells | keep only component-lag DLM decomposition bundles |
| Non-winners | `raw`, `sr`, `srp`, `srx` win 0 cells | do not spend qvbm2 compute on them |
| MCMC handoff | `0 / 8` winners pass all primary gates | MCMC remains blocked |

## Diagnosis

The failed qvbm1 handoff is not a compute failure. It is a scientific dominance
failure. The winning qvbm1 cells often improve one target, especially fit RMSE,
but still degrade check loss or forecast metrics relative to the current
Q-DESN RHS same-likelihood baseline and/or the best DQLM/exDQLM VB baseline.

The qvbm2 design therefore enforces two principles:

1. Keep the useful mechanism signal: `c12` and `c123` component-lag DLM inputs.
2. Add explicit check-loss and forecast guards so fit-RMSE relief is not bought
   by worse check loss or forecast degradation.

## Target Cells

qvbm2 targets the same eight hard family/quantile/likelihood cells from qvbm1:

| family | tau | likelihood | qvbm1 winner bundle | dominant blocker |
|---|---:|---|---|---|
| gausmix | 0.05 | AL | `c123` | fit RMSE and check-loss guard |
| gausmix | 0.05 | exAL | `c123` | fit RMSE and check-loss guard |
| laplace | 0.05 | AL | `c12` | fit RMSE and forecast guard |
| laplace | 0.05 | exAL | `c123` | fit RMSE and forecast guard |
| normal | 0.05 | AL | `c123` | forecast MAE and check-loss guard |
| normal | 0.05 | exAL | `c12` | forecast MAE and check-loss guard |
| normal | 0.50 | AL | `c12` | forecast MAE and check-loss guard |
| normal | 0.50 | exAL | `c12` | forecast MAE and check-loss guard |

## qvbm2 Design

The screen uses two bundles:

| bundle code | bundle id | DLM input builder | period-90 harmonics |
|---|---|---|---|
| `c12` | `decomp_component_p90_h12` | component lags | 1, 2 |
| `c123` | `decomp_component_p90_h123` | component lags | 1, 2, 3 |

Each bundle has 8 profiles for each of the 8 target cells, giving
`2 * 8 * 8 = 128` exact VB roots. Each root is scoped to one likelihood by
`allowed_fit_spec_ids`; no MCMC is active.

| profile role | design purpose |
|---|---|
| `anchor_tail_guard` | retain the qvbm1 winning neighborhood |
| `check_guard_sparse` | lower capacity to protect check loss |
| `check_guard_strong_shrink` | stronger RHS shrinkage for check-loss stability |
| `rmse_balanced_low_memory` | fit-RMSE relief without long-memory drift |
| `rmse_balanced_deeper` | small two-layer state for fit structure |
| `forecast_guard_lowrho` | reduce forecast drift |
| `forecast_guard_midmemory` | moderate memory for rolling-origin forecasts |
| `period_aligned_two_layer` | small period-aligned state interaction |

## Generated Configs

| file | role |
|---|---|
| `config/validation/qvbm2_bundle_index.csv` | qvbm2 bundle index |
| `config/validation/qvbm2_bundle_index_manifest.json` | qvbm2 materialization manifest |
| `config/validation/qvbm2_c12_defaults.yaml` | c12 defaults |
| `config/validation/qvbm2_c12_grid.csv` | c12 grid |
| `config/validation/qvbm2_c12_profiles.csv` | c12 profiles |
| `config/validation/qvbm2_c12_cell_assignments.csv` | c12 cell assignments |
| `config/validation/qvbm2_c12_target_spec_ids.csv` | c12 exact VB spec ids |
| `config/validation/qvbm2_c123_defaults.yaml` | c123 defaults |
| `config/validation/qvbm2_c123_grid.csv` | c123 grid |
| `config/validation/qvbm2_c123_profiles.csv` | c123 profiles |
| `config/validation/qvbm2_c123_cell_assignments.csv` | c123 cell assignments |
| `config/validation/qvbm2_c123_target_spec_ids.csv` | c123 exact VB spec ids |

## Dry Audit Evidence

Command:

```bash
Rscript scripts/materialize_qdesn_tt500_vb_blocker_aware_followup.R \
  --stage-prefix qvbm2 --short-path-mode --workers 20

Rscript scripts/audit_qdesn_tt500_vb_mechanism_first_materialization.R \
  --stage-prefix qvbm2 --short-path-mode
```

Observed dry-audit result:

| bundle | status | input mode | input builder | target specs | max root-id chars |
|---|---|---|---|---:|---:|
| `c12` | `DRY_PASS` | `dlm_decomp_lags` | `component_lags` | 64 | 153 |
| `c123` | `DRY_PASS` | `dlm_decomp_lags` | `component_lags` | 64 | 154 |

Audit output:
`reports/qvbm2/audit/materialization/summary/qdesn_tt500_vb_mechanism_first_materialization_audit.md`

## Smoke Gate

Before the overnight full VB launch, run one representative exact-spec smoke
per bundle. The smoke must show:

- `root_status.txt = SUCCESS`;
- fit signoff present and passing;
- rolling-origin lead metrics present;
- no routine retained `.rds`, `.rda`, `.RData`, or `__design.rds` payloads;
- no active `/home/jaguir26/local/src` paths.

Observed smoke result:

| bundle | run tag | root status | fit rows | lead metric rows | forbidden payloads |
|---|---|---|---:|---:|---:|
| `c12` | `qvbm2_smoke_c12_20260714` | `SUCCESS` | 1 | 30 | 0 |
| `c123` | `qvbm2_smoke_c123_20260714` | `SUCCESS` | 1 | 30 | 0 |

Smoke logs:

- `reports/qvbm2/smoke/20260714/qvbm2_smoke_c12.log`
- `reports/qvbm2/smoke/20260714/qvbm2_smoke_c123.log`

Smoke results are intentionally tiny validation artifacts and are not
article-facing. The smoke showed that the slow section is the rolling-origin
lead-1 forecast lattice, not the VB fit itself.

## Full Overnight Launch Gate

Only launch full qvbm2 if the dry audit and smoke pass. The full launch remains:

- VB only;
- 20 workers;
- exact-spec filtered;
- storage-light;
- not article-facing;
- not an MCMC promotion.

Planned command:

```bash
tmux new-session -d -s ffv2_qvbm2_blocker_aware_20260714 \
  'cd /data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0 && \
   Rscript scripts/orchestrate_qdesn_tt500_vb_mechanism_first_redesign.R \
     --stage-prefix qvbm2 --short-path-mode --full --launch-approved \
     --workers 20 --orchestrator-tag qvbm2_blocker_aware_20260714 \
     > reports/qvbm2/orch/qvbm2_blocker_aware_20260714/qvbm2_full.stdout.log 2>&1'
```

## Promotion Rule

qvbm2 candidates are still diagnostic until closeout. MCMC promotion requires a
completed strict audit showing a per-cell winner that clears the conservative
handoff gate on fit RMSE, fit check loss, forecast MAE, and forecast check loss
against the current Q-DESN RHS same-likelihood baseline and the best DQLM/exDQLM
VB baseline.

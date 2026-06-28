# Q-DESN TT500 VB Stage 3 Forecast-Bias Rescue

Date: 2026-06-28

## Source Run

The completed forecast-targeted TT500 VB screen is mechanically complete and storage-light:

- run tag: `qdesn-tt500-vb-forecast-targeted-full-20260628`
- report root: `reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_forecast_targeted/qdesn-tt500-vb-forecast-targeted-full-20260628/20260628-100556__git-2aaf1bd`
- expected roots: 208
- successful roots: 208
- failed roots: 0
- forbidden binary payloads: 0
- strict audit: pass

The run is not a final article-facing replacement because three family x tau cells still lack a Q-DESN VB profile that beats the best DQLM/exDQLM VB baseline on all four primary metrics.

## Cells Requiring Stage 3

| family | tau | best worst ratio | main bottleneck |
|---|---:|---:|---|
| gausmix | 0.25 | 1.115 | rolling forecast MAE / pinball |
| normal | 0.25 | 1.483 | rolling forecast MAE / forecast bias |
| normal | 0.50 | 1.470 | rolling forecast MAE / forecast bias |

The fit metrics are already strongly better than the VB baseline in these cells, so MCMC is not the correct next step. The follow-up should remain VB-only and focus on forecast behavior.

## Stage 3 Design

Stage 3 is a narrow, cell-specific VB screen:

- target only the three failing family x tau cells
- keep TT500, `rhs_ns`, `exal`, and VB only
- reuse the frozen period-90, `m <= 90`, `washout = 300` TT500 source materialization
- keep `p / n <= 0.50`
- use storage-light outputs only
- no article-facing promotion until the strict audit and dominance ranking pass

The candidate grid emphasizes short-memory, low-inertia, input-responsive reservoirs:

- `alpha/rho` includes lower-inertia pairs such as `0.01/0.35`, `0.02/0.45`, `0.03/0.50`
- readout lengths include `15`, `30`, `45`, `60`, and `90` where compatible
- sparsity/input probes include low recurrent sparsity with stronger input connectivity
- reservoir-lag probes are retained as a diagnostic option

## Commands

Freeze and diagnose the completed source run:

```bash
Rscript scripts/freeze_diagnose_qdesn_tt500_vb_forecast_targeted_run.R
```

Materialize the Stage 3 config bundle:

```bash
Rscript scripts/materialize_qdesn_tt500_vb_stage3_forecast_bias_rescue.R --workers 12
```

Run the full staged lane:

```bash
Rscript scripts/orchestrate_qdesn_tt500_vb_stage3_forecast_bias_rescue.R --workers 12 --smoke --full
```

For background execution, run the orchestrator inside a named `tmux` session and monitor its launcher log.

## Acceptance Criteria

Stage 3 is acceptable only if:

- prepare-only passes
- smoke passes
- full Stage 3 roots all finish with explicit terminal status
- strict audit passes with rankings required
- no forbidden `.rds`, `.rda`, or `.RData` payloads remain for successful roots
- at least one Q-DESN VB profile beats the best VB baseline on all four primary metrics for each of the three target cells

If any target cell still fails, the next iteration should remain cell-specific rather than relaunching the full TT500 table.

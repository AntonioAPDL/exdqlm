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

## Closeout Evidence

Closeout was completed after the full Stage 3 run:

- full run tag: `qdesn-tt500-vb-stage3-forecast-bias-rescue-full-20260628`
- report root: `reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_stage3_forecast_bias_rescue/qdesn-tt500-vb-stage3-forecast-bias-rescue-full-20260628/20260628-114648__git-203f47a`
- results root: `results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_stage3_forecast_bias_rescue/qdesn-tt500-vb-stage3-forecast-bias-rescue-full-20260628/20260628-114648__git-203f47a`
- validation commit: `203f47adcbd417827e26e8efaf36f120e075fbf3`
- expected roots: 144
- successful roots: 144
- failed roots: 0
- forbidden binary payloads: 0
- strict audit after ranking: pass

The tmux shell wrapper returned exit code `1` because its post-run shell
snippet selected the sibling `launch/` directory as the report root for ranking.
The model run itself had already completed successfully. The ranking and strict
audit were rerun manually on the timestamped report root above:

```bash
Rscript scripts/rank_qdesn_tt500_vb_screen.R \
  --report-root reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_stage3_forecast_bias_rescue/qdesn-tt500-vb-stage3-forecast-bias-rescue-full-20260628/20260628-114648__git-203f47a \
  --top-n 20

Rscript scripts/rank_qdesn_tt500_vb_dominance_screen.R \
  --report-root reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_stage3_forecast_bias_rescue/qdesn-tt500-vb-stage3-forecast-bias-rescue-full-20260628/20260628-114648__git-203f47a \
  --baseline /data/jaguir26/local/src/Article-Q-DESN/tables/qdesn_validation_tt500_final_summary.csv \
  --top-n 20

Rscript scripts/audit_qdesn_tt500_vb_dominance_screening.R \
  --report-root reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_stage3_forecast_bias_rescue/qdesn-tt500-vb-stage3-forecast-bias-rescue-full-20260628/20260628-114648__git-203f47a \
  --results-root results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_stage3_forecast_bias_rescue/qdesn-tt500-vb-stage3-forecast-bias-rescue-full-20260628/20260628-114648__git-203f47a \
  --expected-roots 144 \
  --strict \
  --require-rankings
```

Authoritative closeout tables:

| artifact | SHA-256 |
|---|---|
| `tables/qdesn_tt500_vb_screen_fit_forecast_summary.csv` | `7eb702bb7ab468a083acacd1a185b485af21642d2bffafc9355a9b4f9526d3ca` |
| `tables/qdesn_tt500_vb_dominance_cell_summary.csv` | `59a2c78376f49e31f13d121730579e596d145c8cab7b7146eb19dbc5829e4192` |
| `tables/qdesn_tt500_vb_dominance_profile_ranking.csv` | `aa1c25cb3a22988d91b053917b460408fe79460eaf5f98f6f32ce7ea9f57444f` |
| `audit/tables/qdesn_tt500_vb_screen_audit_summary.csv` | `3a4711868bea45098e3e7c36495ce0e712bbb5cd57bb4c2ba1f63d7c59ee1828` |

## Promotion Candidate

The primary promotion candidate is:

`tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3`

This corresponds to `D = 1`, `n_each = 30`, `alpha = 0.02`, `rho = 0.45`,
`m = 15`, `readout_y_lags = 15`, `reservoir_lags = 0`, `pi_w = 0.03`, and
`pi_in = 0.3`.

The primary profile beats the best available DQLM/exDQLM VB baseline on all
four primary metrics in each of the three targeted cells:

| family | tau | forecast MAE ratio | forecast pinball ratio | fit RMSE ratio | fit pinball ratio |
|---|---:|---:|---:|---:|---:|
| gausmix | 0.25 | 0.635 | 0.950 | 0.100 | 0.479 |
| normal | 0.25 | 0.708 | 0.973 | 0.116 | 0.497 |
| normal | 0.50 | 0.824 | 0.984 | 0.108 | 0.407 |

The backup profile is:

`tt500vb_f3_d1_n30_a0p03_r0p5_m15_lag15_rl0_pw0p03_pin0p3`

It also passes all three targeted cells, but has a weaker worst-case forecast
MAE margin than the primary profile.

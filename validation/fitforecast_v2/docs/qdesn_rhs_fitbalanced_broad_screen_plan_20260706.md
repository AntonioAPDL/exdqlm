# Q-DESN RHS VB Fit-Balanced Broad Screen Plan

Date: 2026-07-06

## Purpose

The current article-facing validation table is presentable after the corrected Q-DESN refreshes, but the Q-DESN RHS variants still show uneven behavior. The latest Q-DESN RHS fit-aware VB refinement completed cleanly, yet no RHS profile dominates all primary VB baselines across fit and forecast. The active bottleneck is usually fit RMSE, not only rolling-origin forecast check loss.

This screen is a diagnostic VB-only broad search. It is not article-authoritative until a separate freeze/signoff promotes rows.

## Evidence Used

- Latest Q-DESN RHS fit-aware report root:
  `reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitaware_refinement/qdesn-tt500-vb-rhs-fitaware-refinement-20260706__git-42c2727/20260706-024112__git-0d22ebc`
- Latest targeted evidence freeze:
  `validation/fitforecast_v2/promotions/vb_targeted_refinement_evidence_20260706`
- Source scenario uses period-90 simulated dynamics:
  `dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast`

## Design

The new stage is:

`qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitbalanced_broad`

The screen keeps the latest best/near-best fit-aware profiles as anchors, then broadens the VB search around the observed bottlenecks:

- period-aware readout/reservoir-memory probes at 45, 60, and 90 lags
- compact low-capacity profiles to reduce unstable overfitting
- compact deeper profiles with small per-layer width
- RHS shrinkage probes across `tau0` values from `3e-5` to `3e-3`
- high-inertia guardrails to check whether stronger persistence helps or hurts
- a small seed-stability subset

The default materialization cap is 144 profiles. Across nine family/quantile cells, this yields 1296 selected root specifications. The launcher evaluates both AL and exAL for each root, so the full stage contains up to 2592 VB fits.

## Direct Launch Policy

The user explicitly requested no smoke/dry stage for this screen. The new orchestrator therefore makes smoke explicit rather than automatic:

```sh
Rscript scripts/orchestrate_qdesn_tt500_vb_rhs_fitbalanced_broad_screen.R \
  --full --skip-smoke --skip-materialize --workers 40 --max-profiles 144
```

The launcher still runs a prepare preflight before the full stage because the downstream validation runner expects staged source/config preparation. This is not a smoke run and does not produce article-authoritative metrics.

## Storage And Promotion Policy

- Keep scalar fit metrics, scalar rolling-origin forecast metrics, compact path summaries, manifests, status rows, and logs.
- Do not treat routine `.rds`, `.rda`, or `.RData` payloads as promoted evidence.
- Do not overwrite the existing article-facing table.
- Promote only after the broad screen completes, rankings/audit pass, and a separate freeze records the exact candidate rows and hashes.

## Expected Outputs

- Profiles:
  `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitbalanced_broad_profiles.csv`
- Assignments:
  `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitbalanced_broad_cell_assignments.csv`
- Defaults:
  `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitbalanced_broad_defaults.yaml`
- Grid:
  `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitbalanced_broad_grid.csv`
- Materialization manifest:
  `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitbalanced_broad_materialization_manifest.json`
- Diagnostics:
  `reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitbalanced_broad/materialization_diagnostics`

## Decision Gate After Completion

After completion, rank candidates by:

1. all-primary dominance against best VB baseline in each family/quantile cell
2. forecast check loss
3. forecast MAE
4. fit RMSE
5. fit check loss
6. runtime only as a secondary tie-breaker

Only then decide whether a MCMC follow-up is scientifically worth the compute.

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

## 2026-07-07 Closeout: Screen-Aware Ranking And Audit

### Run Identity

- Run tag:
  `qdesn-vb-rhs-fitbalanced-broad-20260706-140332__git-4a4975c`
- Report root:
  `reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitbalanced_broad/qdesn-vb-rhs-fitbalanced-broad-20260706-140332__git-4a4975c/20260706-140543__git-4a4975c`
- Results root:
  `results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitbalanced_broad/qdesn-vb-rhs-fitbalanced-broad-20260706-140332__git-4a4975c/20260706-140543__git-4a4975c`

### Root-Cause Diagnosis

The full VB screen completed model computation, but the first post-processing pass was too strict for an exploratory screen:

- the generic ranker required forecast lead metrics for failed exploratory candidates;
- failed candidates naturally had no forecast lead metrics;
- the strict audit required zero failed roots, even though this screen intentionally included aggressive specifications that could be rejected.

This was a post-processing contract issue, not evidence that the successful fits were incomplete.

### Implemented Contract

The broad-screen ranking contract is now:

`status == SUCCESS && comparison_eligible == TRUE`

Only these rows are rank-eligible. Failed or noneligible candidates are retained in:

`tables/qdesn_tt500_vb_screen_rejected_fits.csv`

Strict audit now has two separate terminal concepts:

- `terminal_complete`: all expected roots reached terminal state; failed candidates may be allowed for exploratory screens with `--allow-failed-candidates`;
- `terminal_zero_fail`: all expected roots reached terminal state with zero failures.

Successful roots still must pass the lead-metric, rolling-origin path, and storage-light contracts. Rankings are still required when `--require-rankings` is set.

### Post-Processing Commands

```sh
Rscript scripts/rank_qdesn_tt500_vb_screen.R \
  --report-root reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitbalanced_broad/qdesn-vb-rhs-fitbalanced-broad-20260706-140332__git-4a4975c/20260706-140543__git-4a4975c \
  --top-n 40

Rscript scripts/rank_qdesn_tt500_vb_dominance_screen.R \
  --report-root reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitbalanced_broad/qdesn-vb-rhs-fitbalanced-broad-20260706-140332__git-4a4975c/20260706-140543__git-4a4975c \
  --baseline /data/jaguir26/local/src/Article-Q-DESN__wt__main_validation_tables/tables/qdesn_validation_tt500_final_summary.csv \
  --top-n 40

Rscript scripts/audit_qdesn_tt500_vb_dominance_screening.R \
  --report-root reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitbalanced_broad/qdesn-vb-rhs-fitbalanced-broad-20260706-140332__git-4a4975c/20260706-140543__git-4a4975c \
  --results-root results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitbalanced_broad/qdesn-vb-rhs-fitbalanced-broad-20260706-140332__git-4a4975c/20260706-140543__git-4a4975c \
  --expected-roots 1296 \
  --strict \
  --require-rankings \
  --allow-failed-candidates
```

### Evidence Summary

- Atomic VB fits: 2592
- Successful VB fits: 2376
- Failed exploratory VB fits: 216
- Rank-eligible successful fits with complete lead metrics: 2375
- Rejected fit rows retained in ledger: 217
- Expected roots: 1296
- Observed roots: 1296
- Successful roots: 1188
- Failed roots: 108
- Running roots: 0
- Successful roots lead/rolling/storage contract: pass
- Strict screen audit with allowed failed candidates: pass
- Strict zero-fail terminal audit: fail, by design for this exploratory screen
- Forbidden binary payloads in successful storage contract: 0

Primary evidence files:

- `tables/qdesn_tt500_vb_screen_fit_forecast_summary.csv`
- `tables/qdesn_tt500_vb_screen_profile_cell_summary.csv`
- `tables/qdesn_tt500_vb_screen_profile_ranking.csv`
- `tables/qdesn_tt500_vb_screen_rejected_fits.csv`
- `tables/qdesn_tt500_vb_dominance_profile_ranking.csv`
- `audit/tables/qdesn_tt500_vb_screen_audit_summary.csv`
- `audit/tables/qdesn_tt500_vb_screen_root_audit.csv`
- `manifest/qdesn_tt500_vb_screen_profile_ranking_manifest.json`
- `manifest/qdesn_tt500_vb_dominance_manifest.json`
- `audit/manifest/qdesn_tt500_vb_screen_audit_manifest.json`

### Scientific Decision

The screen is technically complete and reproducible under the exploratory-screen contract, but it does not justify promoting one global RHS VB specification as dominant over the current best DQLM/exDQLM VB baselines.

Observed ranking results:

- best generic internal profile:
  `tt500vb_ftgt_d1_n20_a0p005_r0p25_m15_lag15_rl0_pw0p03_pin0p3`
- best dominance-profile candidate:
  `tt500vb_ftgt_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3`
- profiles passing all-primary dominance against the current best VB baseline in all nine cells: 0

Recommended next move:

1. Use this screen as a candidate-selection and diagnostic dataset, not as an article-authoritative replacement.
2. Inspect hard family/quantile cells where the dominance ratios remain above 1.
3. Launch only targeted follow-up VB screens around the best cell-specific regions before any expensive MCMC promotion.
4. Promote MCMC only for specifications that are robust under the VB dominance and stability checks.

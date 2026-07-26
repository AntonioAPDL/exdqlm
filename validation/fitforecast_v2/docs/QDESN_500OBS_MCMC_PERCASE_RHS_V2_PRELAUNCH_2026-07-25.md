# Q-DESN 500-Observation MCMC Per-Case RHS v2 Prelaunch

## Scope

This is the next independent Q-DESN / exQ-DESN RHS calibration step for the
500-observation simulation validation study. It is intentionally per-case:
each `family x tau x likelihood_target` cell receives its own candidate slate.
It is not a search for one global DESN specification.

The stage is:

```text
qdesn_dynamic_fitforecast_v2_tt500_mcmc_percase_rhs_v2
```

The model targets are:

```text
qdesn_al_rhs_ns
qdesn_exal_rhs_ns
```

The cells are:

```text
families: gausmix, laplace, normal
taus:     0.05, 0.25, 0.50
targets:  al, exal
```

## Why This Stage Exists

The v1c status-agnostic MCMC closeout improved several per-case same-variant
winners, but did not produce new global winners against the DQLM/exDQLM C13
MCMC baselines. The user clarified that global winners are not the objective.
The objective is case-specific calibration by family, quantile level, and
likelihood target, with MCMC allowed to rescue candidates whose VB performance
understates posterior performance.

Therefore this stage mines older broad and case-targeted VB screens, keeps up
to five historically promising candidates per cell-likelihood, and asks full
MCMC to confirm the per-case winners.

## Evidence Inputs

Primary current MCMC closeout:

```text
validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_rhsrepair_v1c_status_agnostic_closeout_20260725
```

Historical VB candidate sources used by the materializer:

```text
validation/fitforecast_v2/docs/qdesn_tt500_vb_historical_winner_handoff_selected_designs_20260709.csv
reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_case_targeted_rhs_v51/qdesn-vb-case-targeted-rhs-v51-full-20260713__git-a2f11f8/20260713-002045__git-a2f11f8/tables/qdesn_tt500_vb_dominance_cell_summary.csv
validation/fitforecast_v2/docs/qdesn_tt500_vb_active_baseline_freeze_20260715.csv
validation/fitforecast_v2/docs/qvbm3_tau1e6_closeout_20260716_cell_winners.csv
```

## Materialization Command

```bash
Rscript scripts/materialize_qdesn_tt500_mcmc_vb_candidate_full_confirmation.R \
  --stage-file qdesn_dynamic_fitforecast_v2_tt500_mcmc_percase_rhs_v2 \
  --focus-taus 0.05,0.25,0.50 \
  --max-candidates-per-cell-likelihood 5 \
  --workers 12
```

Expected materialized outputs:

```text
config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_percase_rhs_v2_profiles.csv
config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_percase_rhs_v2_cell_assignments.csv
config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_percase_rhs_v2_defaults.yaml
config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_percase_rhs_v2_grid.csv
config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_percase_rhs_v2_target_spec_ids.csv
config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_percase_rhs_v2_materialization_manifest.json
```

Expected counts:

```text
target MCMC atomic specs: 90
cell-likelihoods:         18
candidates per cell:       5
unique profile-likelihood specs: 72
```

## Per-Case Ledger Command

```bash
Rscript scripts/materialize_qdesn_tt500_mcmc_percase_rhs_v2_prelaunch.R \
  --stage-file qdesn_dynamic_fitforecast_v2_tt500_mcmc_percase_rhs_v2 \
  --stamp 20260725
```

Expected prelaunch outputs:

```text
validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_percase_rhs_v2_prelaunch_20260725/README.md
validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_percase_rhs_v2_prelaunch_20260725/qdesn_tt500_mcmc_percase_rhs_v2_candidate_inventory_20260725.csv
validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_percase_rhs_v2_prelaunch_20260725/qdesn_tt500_mcmc_percase_rhs_v2_current_percase_ledger_20260725.csv
validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_percase_rhs_v2_prelaunch_20260725/qdesn_tt500_mcmc_percase_rhs_v2_prelaunch_plan_20260725.csv
validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_percase_rhs_v2_prelaunch_20260725/qdesn_tt500_mcmc_percase_rhs_v2_prelaunch_summary_20260725.csv
validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_percase_rhs_v2_prelaunch_20260725/qdesn_tt500_mcmc_percase_rhs_v2_prelaunch_manifest_20260725.json
validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_percase_rhs_v2_prelaunch_20260725/file_manifest.csv
```

## Launch Contract

Full MCMC settings:

```text
n_burn = 5000
n_mcmc = 20000
thin = 1
progress_every = 50
init_from_vb = TRUE
workers = 12
```

Storage-light settings:

```text
keep_draws = FALSE
save_forecast_objects = FALSE
retain_full_rds_on_failure = FALSE
```

The target spec list must be supplied through `--spec-ids`. Without that gate,
the runner may execute both likelihoods for selected roots and waste compute.

## Prepare-Only Gate

```bash
SPEC_IDS=$(Rscript -e 'x <- read.csv("config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_percase_rhs_v2_target_spec_ids.csv", check.names = FALSE); cat(paste(x$spec_id, collapse = ","))')
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R \
  --defaults config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_percase_rhs_v2_defaults.yaml \
  --grid config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_percase_rhs_v2_grid.csv \
  --methods mcmc \
  --likelihoods al,exal \
  --fit-sizes 500 \
  --priors rhs_ns \
  --scheduler load_balanced \
  --allow-grid-subset \
  --workers 12 \
  --no-plots \
  --batch full \
  --run-tag qdesn-tt500-mcmc-percase-rhs-v2-prepare-20260725__git-<sha> \
  --spec-ids "$SPEC_IDS" \
  --prepare-only
```

## Smoke Gate

```bash
SMOKE_SPEC=$(Rscript -e 'x <- read.csv("config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_percase_rhs_v2_target_spec_ids.csv", check.names = FALSE); cat(x$spec_id[[1]])')
Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R \
  --defaults config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_percase_rhs_v2_defaults.yaml \
  --grid config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_percase_rhs_v2_grid.csv \
  --methods mcmc \
  --likelihoods al,exal \
  --fit-sizes 500 \
  --priors rhs_ns \
  --scheduler load_balanced \
  --allow-grid-subset \
  --workers 1 \
  --no-plots \
  --batch smoke \
  --run-tag qdesn-tt500-mcmc-percase-rhs-v2-smoke-20260725__git-<sha> \
  --spec-ids "$SMOKE_SPEC" \
  --stream-child-stdout
```

## Detached Full Launch

```bash
SPEC_IDS=$(Rscript -e 'x <- read.csv("config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_percase_rhs_v2_target_spec_ids.csv", check.names = FALSE); cat(paste(x$spec_id, collapse = ","))')
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_validation.R \
  --defaults config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_percase_rhs_v2_defaults.yaml \
  --grid config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_percase_rhs_v2_grid.csv \
  --methods mcmc \
  --likelihoods al,exal \
  --fit-sizes 500 \
  --priors rhs_ns \
  --scheduler load_balanced \
  --allow-grid-subset \
  --workers 12 \
  --no-plots \
  --batch full \
  --run-tag qdesn-tt500-mcmc-percase-rhs-v2-full-20260725__git-<sha> \
  --tmux-session qdesn_tt500_mcmc_percase_rhs_v2_20260725 \
  --spec-ids "$SPEC_IDS" \
  --stream-child-stdout
```

## Promotion Rule

This stage is not article-facing at launch. After completion, promote per-case
winners only if the closeout can document:

1. the source registry hash matches the existing validation registry;
2. every root has an explicit success/failure state;
3. no routine heavy `.rds`, `.rda`, or `.RData` payloads remain;
4. the selected candidate improves the same model variant or is a defensible
   diagnostic confirmation;
5. the final article table records the promoted per-case winners, not a global
   specification.

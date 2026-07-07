# Q-DESN 500-Observation VB RHS Fit-First Follow-Up Plan

Date: 2026-07-07

## Purpose

The completed Q-DESN RHS VB fit+forecast rescue run is complete, reproducible, and storage-light, but it should remain diagnostic. Its useful signal is that some family/quantile cells improved rolling-origin forecast MAE; its blocking signal is that fit RMSE remains worse than the current best DQLM/exDQLM VB baseline in every family/quantile cell.

This plan freezes that interpretation and materializes the next candidate-selection lane: a compact fit-first VB screen. It is not article-authoritative and it does not launch compute unless explicitly approved through the guarded orchestrator.

## Evidence Basis

- Completed source run tag:
  `qdesn-vb-rhs-fitforecast-rescue-20260707-144646__git-438a156`
- Completed report root:
  `reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitforecast_rescue/qdesn-vb-rhs-fitforecast-rescue-20260707-144646__git-438a156/20260707-144724__git-438a156`
- Source table:
  `tables/qdesn_tt500_vb_screen_fit_forecast_summary.csv`
- Article-facing baseline table used only for comparison:
  `/data/jaguir26/local/src/Article-Q-DESN__wt__main_validation_tables/tables/qdesn_validation_tt500_final_summary.csv`
- Validation branch:
  `validation/shared-fitforecast-v2-1.0.0`

## Diagnosis

The source rescue audit is strict-ready:

- expected roots: 276;
- observed roots: 276;
- successful roots: 276;
- running/failed roots: 0;
- storage-light checks passed;
- no routine `.rds`, `.rda`, or `.RData` retention in the active result root.

The scientific promotion audit rejects direct promotion:

- cells beating all primary VB baselines: 0 of 9;
- cells beating best VB fit RMSE baseline: 0 of 9;
- cells improving forecast MAE: 7 of 9;
- dominant bottleneck: fit RMSE, not forecast export or storage policy.

Therefore the optimal next step is not MCMC and not article promotion. The optimal next step is a smaller VB-only screen centered on fit recovery, using the completed rescue as candidate-selection evidence.

## Search Policy

The follow-up stage prioritizes fit recovery first:

- primary selection objective: lower fit RMSE and fit check loss against the best DQLM/exDQLM VB baseline;
- secondary guard: preserve rolling-origin forecast MAE and check-loss behavior;
- profile size guard: `p / n <= 0.30` for the 500-observation fit window;
- model class: Q-DESN with RHS prior, AL and exAL likelihoods;
- inference: VB only;
- MCMC policy: no MCMC launch from this source screen unless the fit-first follow-up produces promotion-quality candidates.

The materialized screen explores:

- compact reservoirs, mostly `D = 1` with `n_each = 10, 15, 20`;
- limited depth probes for Gaussian mixtures and hard cells;
- short memories/readout lags: 5, 10, 15, 20, and 30 for normal cells;
- low-to-moderate dynamics: `alpha` 0.00075 to 0.05, paired with `rho` 0.10 to 0.60;
- sparse input/readout probabilities to reduce parameter burden;
- RHS scales `tau0 = 1e-4, 3e-4, 1e-3, 3e-3`;
- explicit exclusion of the failed `tau0 = 3e-5` surface.

## Implemented Stage

Stage stub:

`qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitfirst_followup`

Tracked config outputs:

- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitfirst_followup_profiles.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitfirst_followup_cell_assignments.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitfirst_followup_defaults.yaml`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitfirst_followup_grid.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitfirst_followup_materialization_manifest.json`

Diagnostic outputs:

`reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitfirst_followup/materialization_diagnostics`

These diagnostics are reproducibility evidence, not article-facing result tables.

Materialized size after the 2026-07-07 build:

- unique profiles: 93;
- selected family/quantile/profile roots: 172;
- expected VB fits if AL and exAL are launched: 344;
- full-compute launch approval: false by default.
- smoke profile filter:
  `tt500vb_rhsfit1_d2_n15_a0p05_r0p6_m10_lag10_rl0_pw0p005_pin0p1_tau0_1em03`;
- smoke profile role: `fitfirst_depth_probe`.

## Commands

Post-hoc diagnosis only:

```sh
Rscript scripts/diagnose_qdesn_tt500_vb_rhs_fitforecast_rescue.R
```

Materialize the next fit-first screen:

```sh
Rscript scripts/materialize_qdesn_tt500_vb_rhs_fitfirst_followup.R \
  --workers 24 \
  --max-profiles-per-cell 24 \
  --max-p-over-n 0.30
```

Dry-run the launch wrapper:

```sh
Rscript scripts/orchestrate_qdesn_tt500_vb_rhs_fitfirst_followup.R \
  --dry-run \
  --materialize-only \
  --workers 24 \
  --max-profiles-per-cell 24 \
  --max-p-over-n 0.30
```

Future prepare-only gate:

```sh
Rscript scripts/orchestrate_qdesn_tt500_vb_rhs_fitfirst_followup.R \
  --prepare-only \
  --skip-materialize \
  --workers 24
```

Future smoke gate:

```sh
Rscript scripts/orchestrate_qdesn_tt500_vb_rhs_fitfirst_followup.R \
  --smoke \
  --skip-materialize \
  --workers 24
```

Future full launch, only after explicit approval:

```sh
Rscript scripts/orchestrate_qdesn_tt500_vb_rhs_fitfirst_followup.R \
  --full \
  --launch-approved \
  --skip-materialize \
  --workers 24
```

The orchestrator refuses full compute unless both `--full` and `--launch-approved` are supplied.

## Verification

Commands run on 2026-07-07:

```sh
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript -e \
  'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-qdesn-tt500-vb-rhs-fitfirst-followup.R")'
```

Result: passed, 23 expectations.

```sh
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript -e \
  'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-qdesn-tt500-vb-rhs-fitforecast-rescue.R")'
```

Result: passed, 17 expectations.

```sh
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript scripts/orchestrate_qdesn_tt500_vb_rhs_fitfirst_followup.R \
  --dry-run \
  --materialize-only \
  --skip-materialize \
  --workers 24 \
  --max-profiles-per-cell 24 \
  --max-p-over-n 0.30
```

Result: dry-run reported 172 expected roots, 344 expected VB fits, and `launch_approved: FALSE`.

Corrected prepare-only gate:

```sh
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript scripts/orchestrate_qdesn_tt500_vb_rhs_fitfirst_followup.R \
  --prepare-only \
  --skip-materialize \
  --workers 24
```

Result:

- run tag: `qdesn-vb-rhs-fitfirst-followup-20260707-184056__git-aaeb7ef`;
- prepare preflight status: 0;
- expected selected roots: 172;
- expected AL+exAL VB fits if launched: 344;
- full launch approval: false.

Corrected generated-profile smoke gate:

```sh
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript scripts/orchestrate_qdesn_tt500_vb_rhs_fitfirst_followup.R \
  --smoke \
  --skip-materialize \
  --workers 24
```

Result:

- run tag: `qdesn-vb-rhs-fitfirst-followup-20260707-184128__git-aaeb7ef`;
- prepare preflight status: 0;
- smoke status: 0;
- selected roots: 1;
- selected profile:
  `tt500vb_rhsfit1_d2_n15_a0p05_r0p6_m10_lag10_rl0_pw0p005_pin0p1_tau0_1em03`;
- selected profile role: `fitfirst_depth_probe`;
- selected profile `p/n`: 0.122;
- root status: SUCCESS;
- fit summary rows: 2;
- index alignment manifests: 2;
- forecast horizon summary files: 2;
- retained heavy artifact files: 0.

The smoke run is a technical plumbing/storage/indexing gate, not a model-quality result. The two VB method signoffs are `FAIL` under the intentionally tiny smoke budget (`max_iter = 5`), with comparison eligibility false. This is acceptable for smoke because the stage is a screening lane and candidate quality is determined only after a full approved VB screen and strict ranking/audit.

```sh
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript scripts/orchestrate_qdesn_tt500_vb_rhs_fitfirst_followup.R \
  --full \
  --skip-materialize
```

Result: refused before launch because `--launch-approved` was absent.

Storage-light check:

```sh
find config/validation \
  reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitfirst_followup \
  reports/qdesn_mcmc_validation/qdesn_tt500_vb_rhs_fitfirst_followup \
  -type f \( -name '*.rds' -o -name '*.rda' -o -name '*.RData' -o -name '__design.rds' \) -print
```

Result: no forbidden heavy payloads.

## Promotion Rule

Do not promote this stage, or send candidates to MCMC, merely because a forecast metric improves. A candidate should be considered for MCMC only if the follow-up stage:

- clears fit RMSE against the current best DQLM/exDQLM VB baseline in the relevant family/quantile cell;
- preserves or improves fit check loss;
- preserves forecast MAE and forecast check loss within the rolling-origin evaluation;
- passes the strict storage-light and launch-audit checks.

Article-facing promotion requires a separate freeze with exact source hashes, branch/commit provenance, interface hashes, and storage-light audit.

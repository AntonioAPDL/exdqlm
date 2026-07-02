# Q-DESN TT500 MCMC AL RHS Recalibration Lane

Date: 2026-07-02

## Purpose

This lane repairs the remaining article-facing TT500 pathology for the Q-DESN AL RHS MCMC model without disturbing the already-promoted VB results or unrelated validation/application work.

The Article-Q-DESN TT500 table audit identified the following state:

- Q-DESN AL RHS VB is clean after the 2026-07-01 recalibration handoff.
- Q-DESN exAL RHS VB and MCMC are clean.
- Q-DESN AL RHS MCMC still points to the older TT500 MCMC interface and is flagged for all nine family/quantile cells.
- Ridge variants remain diagnostic/supplementary until a separate ridge-specific screening is justified.

## Scope

This lane is intentionally narrow:

- fit size: TT500 only
- model: Q-DESN AL RHS only
- inference: MCMC only
- cells: all 3 families x 3 quantiles = 9 roots
- source profiles: the promoted recalibrated Q-DESN AL RHS VB winners only

It does not relaunch exDQLM/DQLM, exAL RHS, or any ridge variant.

## Frozen Inputs

- Promotion summary:
  `validation/fitforecast_v2/promotions/qdesn_tt500_al_rhs_recalibrated_candidate_20260701/qdesn_tt500_al_rhs_recalibrated_candidate_20260701_summary.csv`
- Source profiles:
  `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_al_rhs_recalibration_profiles.csv`
- Base MCMC defaults:
  `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_winner_confirmation_defaults.yaml`
- Source registry hash required by the promoted rows:
  `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`

## Generated Config Bundle

The materializer writes:

- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_al_rhs_recalibration_winners.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_al_rhs_recalibration_profiles.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_al_rhs_recalibration_cell_assignments.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_al_rhs_recalibration_defaults.yaml`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_al_rhs_recalibration_grid.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_al_rhs_recalibration_materialization_manifest.json`

Hard gates enforced at materialization:

- exactly 9 promoted VB winner rows
- `model_key == qdesn_al_rhs_ns`
- `qdesn_likelihood == al`
- `prior == rhs_ns`
- `inference == method == vb`
- `status == SUCCESS`
- `signoff_grade == PASS`
- `diagnostic_qualification == diagnostic_pass`
- `fit_size == 500`
- no selected profile may use the previously unstable `rhs_tau0 = 3e-05`

## Runtime Contract

- MCMC burn-in: 5000
- MCMC retained iterations: 20000
- thin: 1
- progress cadence: every 50 iterations
- warm start: enabled from the VB machinery already used by the Q-DESN launcher
- workers: 9, one per root, with BLAS/OpenMP thread caps set to 1
- output policy: storage-light, no routine successful heavy draw/forecast-object retention

## Commands

Materialize:

```bash
Rscript scripts/materialize_qdesn_tt500_mcmc_al_rhs_recalibration.R --workers 9
```

Test:

```bash
Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-qdesn-tt500-mcmc-al-rhs-recalibration.R")'
```

Dry-run orchestrator:

```bash
Rscript scripts/orchestrate_qdesn_tt500_mcmc_al_rhs_recalibration.R --dry-run --all --workers 9
```

Committed launch:

```bash
SHA=$(git rev-parse --short HEAD)
Rscript scripts/orchestrate_qdesn_tt500_mcmc_al_rhs_recalibration.R \
  --all \
  --workers 9 \
  --run-tag "qdesn-tt500-mcmc-al-rhs-recalibration-full-20260702__git-${SHA}"
```

Post-completion audit:

```bash
Rscript scripts/audit_qdesn_tt500_mcmc_al_rhs_recalibration.R \
  --report-root reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_al_rhs_recalibration/qdesn-tt500-mcmc-al-rhs-recalibration-full-20260702__git-${SHA} \
  --results-root results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_al_rhs_recalibration/qdesn-tt500-mcmc-al-rhs-recalibration-full-20260702__git-${SHA} \
  --out-dir reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_al_rhs_recalibration/qdesn-tt500-mcmc-al-rhs-recalibration-full-20260702__git-${SHA}/audit \
  --expected-roots 9 \
  --strict
```

## Promotion Rule

These outputs are not article-authoritative until the post-completion audit passes and a new promotion handoff is materialized. The Article table should continue to treat the current AL RHS MCMC rows as provisional/pathological until that handoff replaces the older interface IDs.

## Ridge Policy

The current ridge rows are not repaired by this lane. They should either remain diagnostic/supplementary or be addressed through a separate VB-first ridge screening. The AL RHS MCMC repair should not be delayed by ridge-specific work.

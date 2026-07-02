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
- canonical launcher expansion is 54 roots: 9 family/quantile cells times 6 unique selected VB winner profiles
- selected/run grid is exactly 9 roots: one promoted profile per family/quantile cell
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

## Launch Record

Launch started on 2026-07-02 after the materialization, targeted test, prepare-only, smoke, and 2-root pilot gates passed.

- validation launch commit: `ffe3388`
- run tag: `qdesn-tt500-mcmc-al-rhs-recalibration-full-20260702__git-ffe3388`
- tmux session: `qdesn_tt500_mcmc_alrhs_qdesn_tt500_mcmc_al_rhs_recalibration_full_20260`
- orchestrator manifest:
  `reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_al_rhs_recalibration/orchestrators/qdesn-tt500-mcmc-al-rhs-recalibration-orchestrator-20260702-032059__git-ffe3388/manifest/orchestrator_manifest.json`
- full report root:
  `reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_al_rhs_recalibration/qdesn-tt500-mcmc-al-rhs-recalibration-full-20260702__git-ffe3388`
- full results root:
  `results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_al_rhs_recalibration/qdesn-tt500-mcmc-al-rhs-recalibration-full-20260702__git-ffe3388`
- launch state at handoff: detached full run live with 9 selected MCMC AL RHS roots running in parallel.

## Ridge Policy

The current ridge rows are not repaired by this lane. They should either remain diagnostic/supplementary or be addressed through a separate VB-first ridge screening. The AL RHS MCMC repair should not be delayed by ridge-specific work.

## Completion And Promotion Record

The full nine-cell run completed and passed the strict post-completion audit.

- completed campaign stamp: `20260702-032753__git-ffe3388`
- strict audit status: `observed_roots = 9`, `n_success = 9`, `n_running = 0`, `n_fail = 0`, `strict_ready = TRUE`
- storage-light audit: `forbidden_binary_count_total = 0`; no `.rds`, `.rda`, or `.RData` files were retained under the successful results root
- source run signoff mix: 1 `PASS`, 8 `WARN`; `WARN` rows are retained as diagnostic-qualified article-facing rows with their signoff flags preserved

Article-facing promotion handoff:

- promotion id: `qdesn_tt500_mcmc_al_rhs_recalibrated_authoritative_20260702`
- promotion status: `authoritative_article_facing_diagnostic_qualified`
- diagnostic qualification: `diagnostic_qualified_authoritative_mcmc_al_rhs_recalibrated`
- summary:
  `validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_al_rhs_recalibrated_authoritative_20260702/qdesn_tt500_mcmc_al_rhs_recalibrated_authoritative_20260702_summary.csv`
- summary SHA-256:
  `a24de53f8d24111e21785c0eec5b6c40973a0bbb7494060c16135a9062ba5063`
- manifest:
  `validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_al_rhs_recalibrated_authoritative_20260702/qdesn_tt500_mcmc_al_rhs_recalibrated_authoritative_20260702_manifest.json`
- manifest SHA-256:
  `301ab838dfed94ef1994cb5e0d90506abb0c2ceec35c71dea1437cea06a21fb9`
- sources:
  `validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_al_rhs_recalibrated_authoritative_20260702/qdesn_tt500_mcmc_al_rhs_recalibrated_authoritative_20260702_sources.csv`

Pinned source evidence:

- campaign fit summary SHA-256:
  `6c6ed171a392151cac33e90574fcd326f9ef23b91e2e0b81cfc74d23a9267585`
- strict audit summary SHA-256:
  `cb9a66fabbe01d348e83e0ca4695a5044dd56a5132aeaacf33da3ace8e9382e3`
- root audit SHA-256:
  `9d238e39412fc73e0ac30af94f77fda51d3fc73c5697f216d83ef6cc57170ad5`
- source registry hash:
  `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`

Article integration rule: replace exactly the nine `qdesn_al_rhs_ns` / `mcmc` TT500 rows with this handoff. Do not alter the already-promoted AL RHS VB rows, exAL RHS rows, or ridge rows through this lane.

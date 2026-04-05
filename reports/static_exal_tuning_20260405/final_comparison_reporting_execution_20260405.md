# Validation Campaign: Broad Comparison And Final Reporting Execution

Date: 2026-04-05

Primary references:

- `reports/static_exal_tuning_20260405/final_comparison_reporting_plan_20260405.md`
- `tools/merge_reports/LOCAL_validation_campaign_selection_table_v1_20260405.csv`
- `tools/merge_reports/LOCAL_validation_campaign_comparison_long_v1_20260405.csv`
- `tools/merge_reports/LOCAL_validation_campaign_comparison_audit_v1_20260405.csv`

## Status

The broad comparison/reporting bundle is now implemented and executed.

No tuning or repair work was reopened in this phase.

The comparison pipeline was built directly on top of the fixed `291`-row merged
campaign selection table.

## What Was Implemented

New helper and scripts:

- `tools/merge_reports/LOCAL_validation_campaign_comparison_helpers_20260405.R`
- `tools/merge_reports/LOCAL_validation_campaign_build_comparison_dataset_20260405.R`
- `tools/merge_reports/LOCAL_validation_campaign_build_comparison_tables_20260405.R`
- `tools/merge_reports/LOCAL_validation_campaign_comparison_audit_20260405.R`

Key generated outputs:

- canonical long comparison dataset:
  - `tools/merge_reports/LOCAL_validation_campaign_comparison_long_v1_20260405.csv`
- broad reporting table:
  - `tools/merge_reports/LOCAL_validation_campaign_broad_comparison_table_v1_20260405.csv`
- static scenario wide comparison table:
  - `tools/merge_reports/LOCAL_validation_campaign_static_broad_comparison_v1_20260405.csv`
- dynamic comparison supplement:
  - `tools/merge_reports/LOCAL_validation_campaign_dynamic_broad_comparison_v1_20260405.csv`
- pairwise summaries:
  - `tools/merge_reports/LOCAL_validation_campaign_model_pair_summary_v1_20260405.csv`
  - `tools/merge_reports/LOCAL_validation_campaign_inference_pair_summary_v1_20260405.csv`
- diagnostic summaries:
  - `tools/merge_reports/LOCAL_validation_campaign_mcmc_diagnostics_by_method_v1_20260405.csv`
  - `tools/merge_reports/LOCAL_validation_campaign_vb_diagnostics_by_method_v1_20260405.csv`
- explainability supplement:
  - `tools/merge_reports/LOCAL_validation_campaign_warn_inventory_v1_20260405.csv`

## Audit Result

The reporting bundle passed the final audit.

| check | result |
|---|---|
| comparison-long rows = `291` | `PASS` |
| selected `FAIL` rows = `0` | `PASS` |
| source-gate mismatches = `0` where row-unique source evidence exists | `PASS` |
| static broad comparison rows = `72` | `PASS` |
| dynamic comparison rows = `3` | `PASS` |
| static model-pair rows = `144` | `PASS` |
| static inference-pair rows = `144` | `PASS` |

## Source Routing Result

The final comparison-long dataset uses three source types:

| source type | rows |
|---|---:|
| `method_signoff_long` | `216` |
| `summary_row_csv` | `73` |
| `candidate_health_csv` | `2` |

This is the correct outcome.

Important implementation detail:

- the repaired/default MCMC rows are sourced primarily from summary rows, not
  from the generic case-health filenames, because those generic health filenames
  were reused across multiple cases and are not safe as unique diagnostic
  sources

## Campaign Comparison Summary

### Overall health remains unchanged

| metric | value |
|---|---:|
| total selected cases | `291` |
| PASS | `208` |
| WARN | `83` |
| FAIL | `0` |

### By method

| root_kind | inference | model | total | PASS | WARN | FAIL | PASS % | WARN % |
|---|---|---|---:|---:|---:|---:|---:|---:|
| `dynamic` | `mcmc` | `dqlm` | 2 | 2 | 0 | 0 | 100.0 | 0.0 |
| `dynamic` | `mcmc` | `exdqlm` | 1 | 0 | 1 | 0 | 0.0 | 100.0 |
| `static_paper` | `mcmc` | `al` | 18 | 18 | 0 | 0 | 100.0 | 0.0 |
| `static_paper` | `mcmc` | `exal` | 18 | 8 | 10 | 0 | 44.4 | 55.6 |
| `static_paper` | `vb` | `al` | 18 | 18 | 0 | 0 | 100.0 | 0.0 |
| `static_paper` | `vb` | `exal` | 18 | 12 | 6 | 0 | 66.7 | 33.3 |
| `static_shrink` | `mcmc` | `al` | 54 | 54 | 0 | 0 | 100.0 | 0.0 |
| `static_shrink` | `mcmc` | `exal` | 54 | 18 | 36 | 0 | 33.3 | 66.7 |
| `static_shrink` | `vb` | `al` | 54 | 42 | 12 | 0 | 77.8 | 22.2 |
| `static_shrink` | `vb` | `exal` | 54 | 36 | 18 | 0 | 66.7 | 33.3 |

### By root kind

| root_kind | total | PASS | WARN | FAIL | PASS % |
|---|---:|---:|---:|---:|---:|
| `dynamic` | 3 | 2 | 1 | 0 | 66.7 |
| `static_paper` | 72 | 56 | 16 | 0 | 77.8 |
| `static_shrink` | 216 | 150 | 66 | 0 | 69.4 |

### By family

| family | total | PASS | WARN | FAIL | PASS % |
|---|---:|---:|---:|---:|---:|
| `gausmix` | 98 | 67 | 31 | 0 | 68.4 |
| `laplace` | 96 | 73 | 23 | 0 | 76.0 |
| `normal` | 97 | 68 | 29 | 0 | 70.1 |

### By tau

| tau | total | PASS | WARN | FAIL | PASS % | WARN % |
|---|---:|---:|---:|---:|---:|---:|
| `0p05` | 97 | 78 | 19 | 0 | 80.4 | 19.6 |
| `0p25` | 98 | 51 | 47 | 0 | 52.0 | 48.0 |
| `0p95` | 96 | 79 | 17 | 0 | 82.3 | 17.7 |

Interpretation:

- `tau = 0p25` remains the hardest broad setting in the final selected study
- `static_paper` is cleaner than `static_shrink` at the selected-fit level
- `laplace` is the strongest family by final PASS rate in this selected bundle

## Pairwise Comparison Result

### Model pairs: `exal` vs `al`

Static-only, matched within the same scenario and inference.

| slice | total pairs | exal better | al better | tie | median runtime ratio exal/al |
|---|---:|---:|---:|---:|---:|
| overall | 144 | 8 | 66 | 70 | 7.353899 |
| static_paper mcmc | 18 | 0 | 10 | 8 | 6.355072 |
| static_paper vb | 18 | 0 | 6 | 12 | 14.468442 |
| static_shrink mcmc | 54 | 0 | 36 | 18 | 2.660339 |
| static_shrink vb | 54 | 8 | 14 | 32 | 9.570197 |

Interpretation:

- in the final selected campaign, `al` remains the cleaner broad baseline in
  most matched static comparisons
- `exal` still matters scientifically because the selected campaign includes
  promoted `exal` local repairs and promoted `WARN` rescues that are necessary
  to keep the full campaign non-`FAIL`
- runtime cost remains materially higher for selected `exal` than for selected
  `al`

### Inference pairs: `mcmc` vs `vb`

Static-only, matched within the same scenario and model.

| slice | total pairs | mcmc better | vb better | tie | median runtime ratio mcmc/vb |
|---|---:|---:|---:|---:|---:|
| overall | 144 | 18 | 28 | 98 | 6.530636 |
| static_paper al | 18 | 0 | 0 | 18 | 8.982838 |
| static_paper exal | 18 | 2 | 6 | 10 | 4.348592 |
| static_shrink al | 54 | 12 | 0 | 42 | 7.718686 |
| static_shrink exal | 54 | 4 | 22 | 28 | 4.706869 |

Interpretation:

- most matched `vb` vs `mcmc` comparisons end in ties on final gate
- `vb` is overwhelmingly faster
- `mcmc` is still scientifically necessary in parts of the final bundle,
  especially for dynamic rows and selected `exal` repairs, but it is not the
  dominant broad winner in static matched-gate comparisons

## Diagnostic Comparison Result

### MCMC diagnostics

The final MCMC diagnostic summaries show the expected pattern:

- baseline `al` MCMC methods have much larger sigma ESS per 1k than selected
  `exal` MCMC methods
- selected `exal` MCMC methods still remain within acceptable non-`FAIL`
  bounds after the repair program
- selected `exal` MCMC runtime is materially larger than selected `al` MCMC
  runtime across both static root kinds

### VB diagnostics

The final VB diagnostic summaries show:

- `al` VB methods converge at very high rates with very short runtimes
- selected `exal` VB methods remain more fragile, but still fully non-`FAIL`
  in the final selected bundle
- local-dominance stability metrics remain weaker for `exal` VB than for `al`

## What This Means For Final Reporting

The branch now has the full reporting stack needed for the next scientific
deliverables:

1. the canonical long-format comparison dataset
2. one canonical broad comparison table across all selected cases
3. one static scenario-wide table for four-method side-by-side reporting
4. one dynamic supplement table
5. pairwise model and inference summaries
6. a WARN inventory for interpretation and manuscript caveats

## Bottom Line

The comparison/reporting phase is now implemented.

The campaign is not just healthy-fit complete; it is now comparison-table
ready at the branch level.

The next step should be publication-facing synthesis:

- choose the reporting subset/figures to surface in the manuscript or note
- write the narrative interpretation around the broad comparison tables
- keep tuning closed unless a later scientific review finds a real reporting
  inconsistency

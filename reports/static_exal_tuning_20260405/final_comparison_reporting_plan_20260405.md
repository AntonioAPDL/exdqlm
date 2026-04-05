# Validation Campaign: Broad Comparison And Final Reporting Plan

Date: 2026-04-05

Primary references:

- `reports/static_exal_tuning_20260405/comparison_ready_assembly_execution_20260405.md`
- `reports/static_exal_tuning_20260405/failband_wave11_closeout_and_comparison_ready_handoff_20260405.md`
- `tools/merge_reports/LOCAL_validation_campaign_selection_table_v1_20260405.csv`
- `tools/merge_reports/LOCAL_validation_campaign_row_health_v1_20260405.csv`
- `tools/merge_reports/LOCAL_validation_campaign_health_summary_v1_20260405.csv`

## Purpose

Move the branch from a comparison-ready healthy-fit assembly into a
publication-ready comparison/reporting bundle.

This is no longer a tuning task. The selected campaign is already fixed:

- `291` selected method-level cases
- `0` selected `FAIL`
- `0` unhealthy selected cases

The job here is to compare the selected methods rigorously, document the
comparison units correctly, and generate the branch-tracked outputs that the
final scientific write-up can trust.

## What Exactly Is Being Compared

The final campaign is method-level, not root-level.

Each selected row is one chosen fit for one method under one validation
scenario. The selected rows span:

- static paper:
  - `vb::al`
  - `vb::exal`
  - `mcmc::al`
  - `mcmc::exal`
- static shrink:
  - `vb::al`
  - `vb::exal`
  - `mcmc::al`
  - `mcmc::exal`
- dynamic:
  - `mcmc::dqlm`
  - `mcmc::exdqlm`

Therefore the comparison phase needs three comparison scales:

1. method-level summaries:
   - compare all selected rows by `model`, `inference`, `root_kind`, `family`,
     and `tau`
2. static scenario-level side-by-side tables:
   - one row per static run root, showing all four selected methods
3. pairwise comparisons on valid matched scenarios:
   - `exal` vs `al` within the same static scenario and inference
   - `mcmc` vs `vb` within the same static scenario and model

Dynamic should be treated as a descriptive supplement, not a fully paired
model-vs-model table, because the final dynamic selection only contains `3`
chosen cases rather than a complete method grid.

## Canonical Comparison Units

### 1. Selected case

The fundamental selected-case table is:

- `tools/merge_reports/LOCAL_validation_campaign_selection_table_v1_20260405.csv`

This stays the authoritative source for:

- `case_key`
- selected candidate
- selected pool
- selected gate
- selected runtime
- provenance

### 2. Scenario

The correct scenario unit for broad comparison is the underlying validation
run root, not just `family / tau / tt`.

Reason:

- static shrink contains repeated `family / tau / tt` combinations across
  `rhs_ns` and `rhs`
- the final promoted overrides can come from different waves than the
  historical baselines
- using only `family / tau / tt` would collapse distinct current-vs-legacy
  scenarios and break pairwise alignment

Therefore the comparison pipeline should define:

- `scenario_key = root_kind::run_root_rel`

This yields:

- `72` static scenarios
- `3` dynamic scenarios

### 3. Matched pair

Valid matched pairs are:

- static model pair:
  - same `scenario_key`
  - same `inference`
  - compare `al` vs `exal`
- static inference pair:
  - same `scenario_key`
  - same `model`
  - compare `vb` vs `mcmc`

This yields:

- `144` static model-pair comparisons
- `144` static inference-pair comparisons

## Which Metrics We Need To Compare

### Universal campaign metrics

These apply to every selected case and should appear in the final broad
comparison bundle:

- `gate_overall`
- `healthy`
- `state`
- `runtime_sec`
- `selected_pool`
- `selected_candidate`
- `selection_reason`

These are the metrics used for the final campaign health and provenance truth.

### MCMC diagnostics

Where available, broad comparison should also carry the chosen MCMC diagnostics:

- `ess_sigma_per1k`
- `ess_gamma_per1k`
- `acf1_sigma`
- `acf1_gamma`
- `geweke_sigma`
- `geweke_gamma`
- `half_drift_sigma`
- `half_drift_gamma`
- `accept_keep`
- `kernel_exact`
- `rhs_collapse_flag`

These matter because they explain why a selected method ended up as `PASS`
versus `WARN`, and they let us compare the quality/runtime tradeoff across
`al` vs `exal` and `vb` vs `mcmc`.

### VB diagnostics

Where available, broad comparison should also carry the chosen VB diagnostics:

- `vb_converged`
- `vb_trace_length`
- `vb_elbo_tail_rel_range`
- `vb_elbo_tail_rel_drift`
- `vb_sigma_tail_rel_range`
- `vb_gamma_tail_rel_range`
- `vb_ld_candidate_local_pass_rate_tail`
- `vb_ld_stabilized_rate_tail`

These matter because the static campaign contains both baseline `al` VB fits
and extended `exal` VB fits, and the final reporting phase should document
their stability/runtime tradeoffs rather than only their gate labels.

## The Most Important Source-Routing Rule

The reporting pipeline must not assume that every selected row can be read back
from the same artifact type.

There are three distinct source types:

1. `method_signoff_long.csv`
   - use for the `216` historical reusable static rows
2. row-level summary csvs
   - use for repaired/default MCMC rows such as:
     - refreshed static rows
     - residual-band broad-default rows
     - promoted local overrides
     - dynamic row `15`
3. case-health csvs
   - use only where no reliable summary row exists

Critical repo-specific nuance:

- some repaired/default MCMC case-health filenames are generic and were reused
  across multiple cases
- those filenames remain useful as provenance pointers
- they are **not** safe as the row-unique diagnostic source for final broad
  reporting
- the summary-row file is the authoritative row-level source whenever it exists

## New Files And Functions Needed

The final reporting phase needs a dedicated helper plus three reporting
scripts.

### New helper

- `tools/merge_reports/LOCAL_validation_campaign_comparison_helpers_20260405.R`

Responsibilities:

- normalize repo/absolute paths
- derive `run_root_rel`
- route each selected case to the correct diagnostic source
- extract selected-row diagnostics from:
  - `method_signoff_long.csv`
  - row-level summary csvs
  - candidate-health csvs
- define shared gate and grouping helpers

### New reporting scripts

- `tools/merge_reports/LOCAL_validation_campaign_build_comparison_dataset_20260405.R`
- `tools/merge_reports/LOCAL_validation_campaign_build_comparison_tables_20260405.R`
- `tools/merge_reports/LOCAL_validation_campaign_comparison_audit_20260405.R`

## Required Output Bundle

### Canonical comparison dataset

- `tools/merge_reports/LOCAL_validation_campaign_comparison_long_v1_20260405.csv`

This should be the canonical long-format comparison dataset:

- one row per selected case
- selected campaign metadata
- selected source diagnostics
- scenario key
- method id

### High-level summary tables

- `tools/merge_reports/LOCAL_validation_campaign_summary_by_model_v1_20260405.csv`
- `tools/merge_reports/LOCAL_validation_campaign_summary_by_inference_v1_20260405.csv`
- `tools/merge_reports/LOCAL_validation_campaign_summary_by_root_kind_v1_20260405.csv`
- `tools/merge_reports/LOCAL_validation_campaign_summary_by_family_v1_20260405.csv`
- `tools/merge_reports/LOCAL_validation_campaign_summary_by_tau_v1_20260405.csv`
- `tools/merge_reports/LOCAL_validation_campaign_summary_by_method_v1_20260405.csv`
- `tools/merge_reports/LOCAL_validation_campaign_summary_by_prior_semantics_v1_20260405.csv`

### Diagnostic summaries

- `tools/merge_reports/LOCAL_validation_campaign_mcmc_diagnostics_by_method_v1_20260405.csv`
- `tools/merge_reports/LOCAL_validation_campaign_vb_diagnostics_by_method_v1_20260405.csv`

### Broad comparison tables used for reporting

- `tools/merge_reports/LOCAL_validation_campaign_broad_comparison_table_v1_20260405.csv`
- `tools/merge_reports/LOCAL_validation_campaign_static_broad_comparison_v1_20260405.csv`
- `tools/merge_reports/LOCAL_validation_campaign_dynamic_broad_comparison_v1_20260405.csv`

### Pairwise comparison tables

- `tools/merge_reports/LOCAL_validation_campaign_model_pair_comparison_v1_20260405.csv`
- `tools/merge_reports/LOCAL_validation_campaign_model_pair_summary_v1_20260405.csv`
- `tools/merge_reports/LOCAL_validation_campaign_inference_pair_comparison_v1_20260405.csv`
- `tools/merge_reports/LOCAL_validation_campaign_inference_pair_summary_v1_20260405.csv`

### Explainability supplement

- `tools/merge_reports/LOCAL_validation_campaign_warn_inventory_v1_20260405.csv`

### Final audit

- `tools/merge_reports/LOCAL_validation_campaign_comparison_audit_v1_20260405.csv`

## Execution Phases

### Phase A: Materialize the canonical comparison-long dataset

1. read the final merged selection table
2. resolve the correct diagnostic source for each selected row
3. extract diagnostics into one normalized row format
4. verify the selected campaign gate agrees with the selected source gate
   whenever the source is row-unique

### Phase B: Build broad summary tables

1. summarize by:
   - model
   - inference
   - root kind
   - family
   - tau
2. summarize by full method identity:
   - `root_kind + inference + model`
3. build MCMC and VB diagnostic summaries by method

### Phase C: Build matched comparison tables

1. static scenario wide table:
   - `vb::al`
   - `vb::exal`
   - `mcmc::al`
   - `mcmc::exal`
2. dynamic descriptive table
3. model-pair comparison:
   - `exal` vs `al` within static inference
4. inference-pair comparison:
   - `mcmc` vs `vb` within static model

### Phase D: Audit and signoff

Required checks:

- comparison-long rows = `291`
- comparison-long selected `FAIL` rows = `0`
- static broad table rows = `72`
- dynamic broad table rows = `3`
- static model-pair rows = `144`
- static inference-pair rows = `144`
- no source-gate mismatches in the row-unique sources

## Final Reporting Objective

When this plan is executed, the branch should have:

1. one canonical comparison-long dataset
2. one canonical broad comparison table for reporting
3. side-by-side static scenario comparisons
4. pairwise exal-vs-al and mcmc-vs-vb summaries
5. a clear WARN inventory for interpretation
6. a final reporting audit proving the bundle is internally consistent

## Bottom Line

The validation campaign is already comparison-ready at the health/provenance
level.

The remaining work in this phase is to turn that fixed, healthy-fit selection
into a rigorous, branch-tracked comparison/reporting bundle that makes the
scientific comparisons explicit and reproducible.

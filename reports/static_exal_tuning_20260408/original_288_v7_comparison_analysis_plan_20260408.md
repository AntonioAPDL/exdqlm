# Original-288 V7 Comparison Analysis Plan

Date: 2026-04-08

## Purpose

Move the synced integration branch from residual repair and tail-closure work
into a comprehensive comparison-analysis phase built on the accepted
publication-target baseline under `v7`.

This phase is not another tuning program.

Its job is to:

1. freeze the current accepted original-`288` state as the comparison input
2. build a full comparison dataset from that accepted state
3. generate the broad comparison tables and pairwise summaries
4. audit the outputs against the accepted tracker totals
5. review how the comparison bundle actually looks with the current accepted
   unresolved tail still present

## Starting Point

Current accepted publication-target state under `v7`:

- `282 / 288` healthy
- `230 PASS`
- `52 WARN`
- `6 FAIL`

Current unresolved tail:

- all `6` are `dynamic`
- all `6` are `exdqlm :: mcmc`

Recent closeout result that does **not** change the accepted baseline:

- synced-base `dynamic tail6 localmix`
  - `6 / 6` complete
  - `0 PASS`
  - `0 WARN`
  - `6 FAIL`
  - `0` promotable improvements

Therefore:

- accepted `v7` remains the authoritative comparison baseline
- no fail-over-fail localmix output should be promoted into comparison inputs

## Why A New Comparison Plan Is Needed

The existing comparison pipeline on this branch is real and useful, but it was
built for a different frozen campaign:

- `291` selected method-level rows
- `0 FAIL`
- dynamic treated as a small descriptive supplement

Primary old pipeline references:

- `reports/static_exal_tuning_20260405/final_comparison_reporting_plan_20260405.md`
- `reports/static_exal_tuning_20260405/final_comparison_reporting_execution_20260405.md`
- `tools/merge_reports/LOCAL_validation_campaign_build_comparison_dataset_20260405.R`
- `tools/merge_reports/LOCAL_validation_campaign_build_comparison_tables_20260405.R`
- `tools/merge_reports/LOCAL_validation_campaign_comparison_audit_20260405.R`

That older pipeline cannot be reused unchanged because it assumes:

1. `291` rows instead of `288`
2. `0 FAIL` instead of `6 FAIL`
3. only `3` dynamic selected rows instead of the full `72` dynamic rows
4. scenario and pair-count audits tailored to the older comparison-ready
   campaign rather than the corrected original-`288` study universe

What **should** be reused:

- the source-routing approach
- the comparison-long dataset design
- the pairwise-table pattern
- the audit style

What **must** be replaced:

- hard-coded `291`-row assumptions
- zero-FAIL assumptions
- dynamic-supplement-only assumptions

## Canonical Inputs

The new comparison bundle should use the accepted original-`288` `v7` artifacts
as its canonical input set.

Primary inputs:

- `tools/merge_reports/LOCAL_original288_carryforward_selection_v7_20260407.csv`
- `tools/merge_reports/LOCAL_original288_row_health_v7_20260407.csv`
- `tools/merge_reports/LOCAL_original288_health_summary_v7_20260407.csv`
- `tools/merge_reports/LOCAL_original288_recovery_block_status_v7_20260407.csv`
- `tools/merge_reports/LOCAL_original288_health_breakdown_by_method_v7_20260407.csv`
- `tools/merge_reports/LOCAL_original288_unresolved_inventory_v7_20260407.csv`
- `tools/merge_reports/LOCAL_original288_unresolved_dynamic_inventory_v7_20260407.csv`

Source-routing inputs carried through the `v7` carryforward table:

- `baseline_signoff_path`
- `baseline_fit_path`
- `selected_fit_path`
- `selected_health_path`
- `selected_summary_path`
- `source_path`

Important routing rule:

- this comparison analysis is about the **accepted publication-target state**
- it is not a direct comparison of “latest rerun candidate” outputs
- selected evidence may still live in the predecessor worktree for many rows,
  and that is acceptable because `v7` is a carry-forward baseline

## Canonical Comparison Units

### 1. Method-level selected case

The fundamental unit is one accepted row per `original_case_key`.

Expected total:

- `288` accepted rows

### 2. Scenario-level unit

The clean scenario key should now be the accepted registry scenario itself:

- `scenario_key = original_scenario_key`

This is better than reconstructing a new root-relative key because
`original_scenario_key` already captures the corrected original-`288` study
registry.

Expected scenario counts:

- static paper:
  - `18`
- static shrink:
  - `36`
- dynamic:
  - `18`
- total:
  - `72`

### 3. Matched comparison pairs

Unlike the older `291`-row campaign, the accepted original-`288` baseline
contains a complete method grid for the study registry, including the dynamic
block. So the new comparison bundle should support full matched pair tables for
both static and dynamic rows.

Expected pair counts:

- static model pairs:
  - `54` scenarios x `2` inference = `108`
- static inference pairs:
  - `54` scenarios x `2` models = `108`
- dynamic model pairs:
  - `18` scenarios x `2` inference = `36`
- dynamic inference pairs:
  - `18` scenarios x `2` models = `36`

## Comparison Questions To Answer

The new bundle should answer these questions directly.

### Campaign health

- what is healthy, warn, and fail in the accepted original-`288` baseline
- where do the `6` unresolved failures cluster

### Model comparisons

- static:
  - `exal` vs `al`
- dynamic:
  - `exdqlm` vs `dqlm`

### Inference comparisons

- `mcmc` vs `vb` for both static and dynamic

### Runtime / diagnostic tradeoffs

- how the accepted methods compare on runtime
- where `WARN` and `FAIL` concentrate in MCMC diagnostics
- where VB methods remain clean versus fragile

### Failure interpretation

- how the accepted `6` unresolved rows affect the dynamic comparison picture
- whether the accepted baseline is still comparison-usable even with those
  remaining fails

## Required Output Bundle

### Canonical long dataset

- `tools/merge_reports/LOCAL_original288_comparison_long_v1_20260408.csv`

One row per accepted `original_case_key`, carrying:

- accepted state metadata
- selected provenance
- selected diagnostics
- scenario key
- comparison group fields

### Broad comparison tables

- `tools/merge_reports/LOCAL_original288_broad_comparison_table_v1_20260408.csv`
- `tools/merge_reports/LOCAL_original288_static_scenario_comparison_v1_20260408.csv`
- `tools/merge_reports/LOCAL_original288_dynamic_scenario_comparison_v1_20260408.csv`

### Health summaries

- `tools/merge_reports/LOCAL_original288_comparison_summary_by_block_v1_20260408.csv`
- `tools/merge_reports/LOCAL_original288_comparison_summary_by_model_v1_20260408.csv`
- `tools/merge_reports/LOCAL_original288_comparison_summary_by_inference_v1_20260408.csv`
- `tools/merge_reports/LOCAL_original288_comparison_summary_by_method_v1_20260408.csv`
- `tools/merge_reports/LOCAL_original288_comparison_summary_by_family_v1_20260408.csv`
- `tools/merge_reports/LOCAL_original288_comparison_summary_by_tau_v1_20260408.csv`
- `tools/merge_reports/LOCAL_original288_comparison_summary_by_prior_semantics_v1_20260408.csv`

### Pairwise comparison tables

- `tools/merge_reports/LOCAL_original288_static_model_pair_comparison_v1_20260408.csv`
- `tools/merge_reports/LOCAL_original288_static_model_pair_summary_v1_20260408.csv`
- `tools/merge_reports/LOCAL_original288_static_inference_pair_comparison_v1_20260408.csv`
- `tools/merge_reports/LOCAL_original288_static_inference_pair_summary_v1_20260408.csv`
- `tools/merge_reports/LOCAL_original288_dynamic_model_pair_comparison_v1_20260408.csv`
- `tools/merge_reports/LOCAL_original288_dynamic_model_pair_summary_v1_20260408.csv`
- `tools/merge_reports/LOCAL_original288_dynamic_inference_pair_comparison_v1_20260408.csv`
- `tools/merge_reports/LOCAL_original288_dynamic_inference_pair_summary_v1_20260408.csv`

### Diagnostic supplements

- `tools/merge_reports/LOCAL_original288_mcmc_diagnostics_by_method_v1_20260408.csv`
- `tools/merge_reports/LOCAL_original288_vb_diagnostics_by_method_v1_20260408.csv`
- `tools/merge_reports/LOCAL_original288_warn_inventory_v1_20260408.csv`
- `tools/merge_reports/LOCAL_original288_fail_inventory_v1_20260408.csv`

### Audit

- `tools/merge_reports/LOCAL_original288_comparison_audit_v1_20260408.csv`

### Execution note

- `reports/static_exal_tuning_20260408/original_288_v7_comparison_analysis_execution_20260408.md`

## Implementation Plan

### Phase 1. Freeze comparison inputs

Goal:

- treat accepted `v7` as immutable input to the comparison build

Checks:

- `carryforward_selection_v7` exists and is readable
- `row_health_v7` exists and is readable
- `health_summary_v7` matches the current tracker:
  - `282 / 288` healthy
  - `6 / 288` fail
- unresolved inventories agree with the `6` accepted fail rows

### Phase 2. Build comparison helper layer

New helper:

- `tools/merge_reports/LOCAL_original288_comparison_helpers_20260408.R`

Responsibilities:

- normalize paths
- define scenario and method keys from the accepted `v7` schema
- route accepted rows to their selected diagnostic evidence
- extract diagnostics from:
  - `method_signoff_long.csv`
  - row-level summary csvs
  - case-health csvs where necessary
- define grouped summary helpers
- define gate-ranking helpers that remain valid even with `FAIL` rows present

### Phase 3. Build the canonical long dataset

New script:

- `tools/merge_reports/LOCAL_original288_build_comparison_dataset_20260408.R`

Input:

- `LOCAL_original288_carryforward_selection_v7_20260407.csv`

Output:

- `LOCAL_original288_comparison_long_v1_20260408.csv`

Hard requirements:

- exactly `288` rows
- one row per `original_case_key`
- no duplicate case keys
- selected gate must match routed source evidence wherever a row-unique source
  exists
- keep `FAIL` rows in the dataset rather than filtering them out

### Phase 4. Build the comparison tables

New script:

- `tools/merge_reports/LOCAL_original288_build_comparison_tables_20260408.R`

Input:

- `LOCAL_original288_comparison_long_v1_20260408.csv`

Outputs:

- broad table
- scenario-wide tables
- method summaries
- pairwise summaries
- warn/fail inventories
- diagnostic summaries

Important design rule:

- the dynamic block should now be treated as a full comparison block, not just
  a supplement, because the accepted original-`288` baseline contains the full
  dynamic method grid

### Phase 5. Audit the bundle

New script:

- `tools/merge_reports/LOCAL_original288_comparison_audit_20260408.R`

Required audit checks:

1. comparison-long rows = `288`
2. row-health totals match accepted `v7`
3. fail rows = `6`
4. unresolved dynamic inventory rows = `6`
5. static scenario rows = `54`
6. dynamic scenario rows = `18`
7. static model-pair rows = `108`
8. static inference-pair rows = `108`
9. dynamic model-pair rows = `36`
10. dynamic inference-pair rows = `36`
11. source-gate mismatches = `0` where row-unique evidence exists

The audit should fail loudly if any of these are violated.

### Phase 6. Review how the comparison looks

After the bundle is built and audited, review three things before calling it
ready:

1. do the broad health summaries match the accepted tracker counts exactly
2. do the pairwise tables tell a coherent scientific story
3. are the `6` remaining dynamic fails represented clearly enough that the
   comparison bundle remains usable without hiding unresolved debt

## What We Expect To Learn

The comparison-analysis phase should answer:

- how strong the accepted `v7` study already is at `282 / 288`
- where the remaining unresolved debt concentrates
- how static vs dynamic behavior differs in the accepted bundle
- how `al` vs `exal` and `dqlm` vs `exdqlm` look in the accepted comparison
  tables
- whether the current accepted bundle is already good enough for comparison
  write-up while the final `6` rows remain unresolved

## Immediate Next Step

The next concrete action should be:

1. implement the new original-`288` comparison helper and scripts
2. build the `v7` comparison dataset and tables
3. run the new audit
4. inspect the outputs and document the first comparison readout

That should be the next major branch task before any new residual tuning lane
is considered.

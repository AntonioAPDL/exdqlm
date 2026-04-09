# Original-288 V7 Comparison Analysis Execution

Date: 2026-04-08

## Scope

This execution closes the planned comparison-analysis phase for the accepted
original-`288` synced-base publication-target baseline under `v7`.

Canonical accepted state used as input:

- `288` accepted rows
- `230 PASS`
- `52 WARN`
- `6 FAIL`
- `282 / 288` healthy

The accepted unresolved tail remains:

- all `6` rows are `dynamic`
- all `6` rows are `exdqlm :: mcmc`

## Implemented Comparison Stack

New comparison-analysis files:

- `tools/merge_reports/LOCAL_original288_comparison_helpers_20260408.R`
- `tools/merge_reports/LOCAL_original288_build_comparison_dataset_20260408.R`
- `tools/merge_reports/LOCAL_original288_build_comparison_tables_20260408.R`
- `tools/merge_reports/LOCAL_original288_comparison_audit_20260408.R`

New execution note:

- `reports/static_exal_tuning_20260408/original_288_v7_comparison_analysis_execution_20260408.md`

## Important Implementation Details

The older `2026-04-05` comparison pipeline was reused in structure, but the
new original-`288` bundle required several corrections.

### 1. Accepted row bridge

The accepted `v7` carryforward schema does not match the older `291`-row
selection-table schema, so the new helper bridges:

- `original_case_key -> case_key`
- `original_scenario_key -> scenario_key`
- accepted selection metadata
- accepted selected paths
- accepted baseline gate metadata

### 2. Checkpoint-aware summary routing

Some accepted promoted rows point to checkpoint-style CSVs rather than classic
`summary` CSVs.

The new helper now treats both as summary-like evidence sources when present:

- `summary`
- `checkpoint`

This was required to recover exact accepted gate evidence for part of the
`hybrid_291_selection` carryforward set.

### 3. Candidate-health tie-breaking

The old helper could not uniquely resolve several accepted rows because the
source files sometimes contain:

- repeated start/complete events
- generic rows and model-specific rows
- compact health tables without fit-path-level uniqueness

The new helper now resolves accepted rows using a stronger priority:

1. exact `candidate_path` match when available
2. accepted `queue_id` / canonical row id when available
3. scenario metadata (`root_kind`, `family`, `tau`, `fit_size`)
4. exact `model`
5. exact `variant_tag`
6. `stage == complete`
7. latest timestamp

### 4. Exact-vs-lossy source matching in audit

The audit now enforces zero gate mismatches only when row-exact evidence is
available.

In practice this means:

- exact candidate-path sources are compared strictly
- lossy compact health sources are allowed to contribute diagnostics without
  being forced into an exact gate-match claim

This change was necessary to keep the audit faithful to the accepted evidence
quality rather than over-claiming row exactness.

## Generated Output Bundle

### Canonical long dataset

- `tools/merge_reports/LOCAL_original288_comparison_long_v1_20260408.csv`

### Broad tables

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

### Pairwise tables

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

## Execution Commands

Executed from the synced integration worktree:

```bash
Rscript tools/merge_reports/LOCAL_original288_build_comparison_dataset_20260408.R
Rscript tools/merge_reports/LOCAL_original288_build_comparison_tables_20260408.R
Rscript tools/merge_reports/LOCAL_original288_comparison_audit_20260408.R
```

Final audit result:

- all checks passed: `yes`

## Key Readouts

### Block health

| block | total | pass | warn | fail | healthy |
|---|---:|---:|---:|---:|---:|
| `dynamic` | `72` | `56` | `10` | `6` | `66` |
| `static_paper` | `72` | `57` | `15` | `0` | `72` |
| `static_shrink` | `144` | `117` | `27` | `0` | `144` |

### Static model comparison

From `LOCAL_original288_static_model_pair_summary_v1_20260408.csv`:

- `108` matched static model pairs
- `exal_better = 0`
- `al_better = 42`
- `tie = 66`
- `median runtime ratio exal / al = 8.291317`

Interpretation:

- the accepted `v7` comparison does **not** show any static scenario where
  `exal` has a better accepted gate than `al`
- the accepted static picture is mostly ties plus a substantial set where `al`
  is cleaner
- `exal` is also materially slower in the accepted baseline

### Static inference comparison

From `LOCAL_original288_static_inference_pair_summary_v1_20260408.csv`:

- `108` matched static inference pairs
- `mcmc_better = 8`
- `vb_better = 14`
- `tie = 86`
- `median runtime ratio mcmc / vb = 4.845254`

Interpretation:

- static `vb` is at least as good as `mcmc` in most accepted rows
- when the accepted gates differ, `vb` wins more often than `mcmc`
- `mcmc` is much slower

### Dynamic model comparison

From `LOCAL_original288_dynamic_model_pair_summary_v1_20260408.csv`:

- `36` matched dynamic model pairs
- `exdqlm_better = 1`
- `dqlm_better = 15`
- `tie = 20`
- `median runtime ratio exdqlm / dqlm = 2.271454`

Interpretation:

- the accepted dynamic model picture is mixed but not favorable to `exdqlm`
- the unresolved tail is the dominant reason the dynamic comparison remains
  scientifically asymmetric

### Dynamic inference comparison

From `LOCAL_original288_dynamic_inference_pair_summary_v1_20260408.csv`:

- `36` matched dynamic inference pairs
- `mcmc_better = 0`
- `vb_better = 13`
- `tie = 23`
- `median runtime ratio mcmc / vb = 8.953858`

Interpretation:

- accepted dynamic `vb` dominates dynamic `mcmc` on gate quality and runtime
- the dynamic failure tail is fully concentrated in `mcmc`

### WARN / FAIL inventories

Inventory totals:

- `WARN = 52`
- `FAIL = 6`

`FAIL` inventory interpretation:

- all `6` fails are the known accepted unresolved dynamic tail
- all `6` are `dynamic :: exdqlm :: mcmc`
- all `6` come from `baseline_original`

This confirms the comparison bundle is still usable:

- the full method grid is intact
- the unresolved tail is explicit, localized, and auditable

## Bottom Line

The original-`288` comparison-analysis bundle is now complete and audited on
the synced integration branch.

What we now have:

- a frozen accepted `v7` comparison input
- a full `288`-row comparison dataset
- broad and pairwise comparison tables
- explicit `WARN` and `FAIL` inventories
- an audit that checks the bundle against the accepted tracker totals

The next task is no longer “build the comparison bundle.”

The next task is:

- review how the accepted `v7` comparison actually reads as a study-level
  result
- decide whether the remaining `6` dynamic failures are worth another narrow
  micro-tuning attempt or should stay as an explicit unresolved tail in the
  final reporting

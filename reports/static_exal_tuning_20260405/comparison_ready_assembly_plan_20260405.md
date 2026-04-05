# Validation Campaign: Comparison-Ready Assembly Plan

Date: 2026-04-05

Primary references:

- `reports/static_exal_tuning_20260405/failband_wave11_closeout_and_comparison_ready_handoff_20260405.md`
- `reports/static_exal_tuning_20260403/post_wave8_campaign_readiness_plan_20260403.md`
- `tools/merge_reports/LOCAL_validation_campaign_promoted_local_map_v9_20260405.csv`
- `tools/merge_reports/LOCAL_targeted_manifest_current_static_rhsns_20260329.csv`
- `tools/merge_reports/LOCAL_targeted_manifest_legacy_rhs_refresh_20260329.csv`
- `tools/merge_reports/full288_rhsns_impl_refresh_20260329/health_compact_20260329_114727.csv`
- `tools/merge_reports/full288_rhs_legacy_refresh_20260329/health_compact_20260329_123208.csv`

## Purpose

The repair phase is complete at the promoted row-best level. The next task is
not more tuning. The next task is to turn the promoted campaign map into a
fully traceable final campaign table and regenerate campaign-level health and
comparison outputs from that frozen selection.

This plan defines exactly how to:

1. freeze the promoted campaign map
2. build the merged final campaign table
3. regenerate campaign-level health

The emphasis is:

- deterministic assembly
- explicit provenance
- zero ambiguity about which artifact is selected for each case
- zero tolerance for silent stale-row leakage

## Execution Complete

The assembly plan defined in this document has now been implemented and run.

Primary execution outputs:

- `tools/merge_reports/LOCAL_validation_campaign_frozen_policy_v1_20260405.csv`
- `tools/merge_reports/LOCAL_validation_campaign_selection_table_v1_20260405.csv`
- `tools/merge_reports/LOCAL_validation_campaign_row_health_v1_20260405.csv`
- `tools/merge_reports/LOCAL_validation_campaign_health_summary_v1_20260405.csv`
- `tools/merge_reports/LOCAL_validation_campaign_audit_v1_20260405.csv`
- `reports/static_exal_tuning_20260405/comparison_ready_assembly_execution_20260405.md`

Validated execution result:

- exactly `291` selected cases
- `208 PASS`
- `83 WARN`
- `0 FAIL`
- `0` unhealthy selected cases

Important correction that mattered during implementation:

- the `21` residual-band broad-default rows were real, but they could only be
  recovered correctly from the paired `failband2` checkpoint events
- the old summary-only view flattened four duplicated RHS scope-cases because
  current and legacy entries shared the same `row_id`
- the final merged table therefore uses scope-aware `(scope_label, row_id)`
  keys and checkpoint-pair provenance for the broad-default pool

## Current Validated End-State

The promoted endgame tail is now fully non-`FAIL`:

| tail item | promoted result |
|---|---|
| static row `87` | `WARN` |
| static row `135` | `PASS` |
| static row `174` | `WARN` |
| static row `269` | `WARN` |
| dynamic row `15` | `WARN` |

Broad static default remains:

- `F085_sub2_s100`

Promoted row-local map is now stored in:

- `tools/merge_reports/LOCAL_validation_campaign_promoted_local_map_v9_20260405.csv`

## Exact Assembly Target

The final merged campaign must resolve to exactly `291` selected cases:

| source pool | count | role |
|---|---:|---|
| reusable historical artifacts | 218 | unchanged healthy campaign coverage outside the stale debt |
| refreshed static non-`FAIL` rows | 42 | refreshed stale static rows that became reusable directly |
| residual-band broad-default rows | 21 | rows covered by the promoted broad static default `F085_sub2_s100` |
| promoted local static overrides | 9 | row-specific promoted repairs inside the old residual static band |
| promoted dynamic local override | 1 | row `15` exact replay rescue |
| overall final campaign | 291 | must be unique, complete, and non-`FAIL` |

This `218 + 42 + 21 + 9 + 1 = 291` identity is the core accounting invariant.

## Investigation Findings That Matter For Assembly

### 1. The stale static debt is already machine-readable

The two targeted stale-debt manifests already exist and should be treated as
the canonical stale-static debt definition:

- `tools/merge_reports/LOCAL_targeted_manifest_current_static_rhsns_20260329.csv`
- `tools/merge_reports/LOCAL_targeted_manifest_legacy_rhs_refresh_20260329.csv`

These files already carry the fields needed to define the static stale universe:

- `row_id`
- `root_kind`
- `family`
- `tau_label`
- `fit_size`
- `prior`
- `prior_override`
- `inference`
- `model`
- `run_root`
- `scope`
- `prepared_tag`

Important implication:

- the static stale debt should be excluded from the reusable pool by exact
  manifest membership, not by hand-written row lists

### 2. The stale refresh health pools are already compact and joinable

The old stale refresh pools already expose compact row-level health tables:

- current RHS-NS:
  `tools/merge_reports/full288_rhsns_impl_refresh_20260329/health_compact_20260329_114727.csv`
- legacy RHS:
  `tools/merge_reports/full288_rhs_legacy_refresh_20260329/health_compact_20260329_123208.csv`

Those compact health tables already share the core row schema:

- `row_id`
- `inference`
- `model`
- `root_kind`
- `family`
- `tau_label`
- `state`
- `gate_overall`
- `healthy`
- `runtime_sec`

Important implication:

- the merge logic should normalize around row metadata plus scope, not around
  file names

### 3. The reusable `218` pool is the only source pool that may need explicit reconstruction

There is no single already-confirmed machine-readable file in the branch that
states "these are the final 218 reusable campaign artifacts" as one canonical
selection table.

However, the repo does contain the underlying raw ingredients:

- `results/**/tables/method_signoff_long.csv`
- historical campaign outputs under the original validation roots
- the stale-debt manifests that define what must be excluded

Important implication:

- one of the first assembly tasks must be to materialize a canonical reusable
  inventory table rather than assuming it already exists

### 4. Manifest registry is the safest way to recover exact selected artifact paths

For the refreshed and repaired rows, exact artifact paths should come from the
wave manifests and promoted-map files, not from string reconstruction.

That applies especially to:

- refreshed static rows
- residual-band default rows
- row-local promoted overrides
- dynamic row `15`

Important implication:

- the assembly should build a manifest registry first, then join the promoted
  selection logic onto that registry

## Canonical Key Design

The final merged table needs one deterministic case key that prevents current /
legacy collisions and keeps static and dynamic workstreams separate.

Recommended canonical key:

| workstream | canonical key |
|---|---|
| static | `static_validation::<scope_label>::<row_id>` |
| dynamic | `dynamic_tail_cppgig_refresh_20260331::<row_id>` |

Required normalized fields in the final merged table:

- `case_key`
- `workstream`
- `scope_label`
- `row_id`
- `root_kind`
- `family`
- `tau_label`
- `fit_size`
- `inference`
- `model`
- `selected_pool`
- `selected_candidate`
- `selected_variant_tag`
- `selected_fit_path`
- `selected_health_path`
- `gate_overall`
- `healthy`
- `state`
- `runtime_sec`
- `prior_semantics`
- `provenance_source`
- `selection_reason`

## Phase A: Freeze the Promoted Campaign Map

### Goal

Turn the current broad-default-plus-local-override policy into a frozen,
machine-readable selection policy that downstream merge scripts can trust.

### Required output

A frozen policy table, for example:

- `tools/merge_reports/LOCAL_validation_campaign_frozen_policy_v1_20260405.csv`

This should not just restate the local overrides. It should explicitly encode:

1. broad default baseline:
   - `F085_sub2_s100`
2. local static overrides:
   - `87` -> `F085_sub2_s1025_histshort`
   - `115` -> `F0825_sub2_s100`
   - `135` -> `F0825_sub2_s105_none`
   - `174` -> `F085_sub2_s105_histshort`
   - `190` -> `F0825_sub2_s100_rwlong`
   - `206` -> `F0825_sub2_s1025_rwlong`
   - `278` -> `F0845_sub2_s1025`
   - `181` -> `F0825_sub2_s100`
   - `269` -> `F0845_sub2_s100_histshort`
3. dynamic local override:
   - `15` -> `row15_slice_exact_20260405`
4. selection precedence:
   - dynamic local override
   - static local override
   - residual-band broad default
   - refreshed static non-`FAIL`
   - reusable historical artifact

### Critical checks

- exactly `9` static local overrides
- exactly `1` dynamic local override
- no duplicate `(workstream, scope_label, row_id)` entries
- no override assigned to a row outside the intended stale / residual band

## Phase B: Build the Manifest Registry

### Goal

Create one normalized registry that maps promoted candidates to exact artifact
paths and exact variant tags.

### Required sources

1. stale-debt manifests:
   - `LOCAL_targeted_manifest_current_static_rhsns_20260329.csv`
   - `LOCAL_targeted_manifest_legacy_rhs_refresh_20260329.csv`
2. refresh manifests:
   - `LOCAL_static_exal_f080s105_refresh_manifest_20260403_211026_937_3845552.csv`
3. residual-band / row-fix / fail-band manifests:
   - wave manifests that produced the promoted row-level artifacts for
     `87`, `135`, `174`, `190`, `206`, `269`
4. dynamic replay manifests:
   - `LOCAL_dynamic_matrix_manifest_row15wave8_20260405_*.csv`

### Required normalized registry fields

- `case_key`
- `workstream`
- `scope_label`
- `row_id`
- `candidate_id`
- `geometry_candidate`
- `variant_tag`
- `fit_path`
- `health_summary_path`
- `manifest_path`
- `source_wave`
- `selection_pool`

### Critical checks

- every promoted local override resolves to exactly one manifest-backed artifact
- no promoted artifact path is inferred by string concatenation when a manifest
  entry exists
- every manifest-backed selected fit path exists on disk

## Phase C: Materialize the Reusable `218`-Case Inventory

### Goal

Build one canonical reusable inventory table for the non-stale part of the
campaign.

### Preferred route

If a canonical full-campaign inventory already exists and can be validated,
reuse it.

### Fallback route

If not, reconstruct it from:

- `results/**/tables/method_signoff_long.csv`
- original campaign run roots
- exclusion of:
  - the `72` static stale-debt rows from the targeted manifests
  - dynamic row `15` pre-repair debt

### Required output

- `tools/merge_reports/LOCAL_validation_campaign_reusable_inventory_20260405.csv`

### Required fields

- `case_key`
- `baseline_fit_path`
- `baseline_health_path`
- `gate_overall`
- `healthy`
- `state`
- `provenance_source`

### Critical checks

- exactly `218` cases survive after exclusions
- no case from the stale `72` static debt remains in the reusable pool
- dynamic row `15` old unhealthy artifact is excluded
- row `5` and row `57` are handled by their already-resolved current selections
  and do not get accidentally reverted to older unhealthy artifacts

## Phase D: Build the Final Merged Campaign Selection Table

### Goal

Materialize one final `291`-row table that says, for every campaign case, which
artifact is selected and why.

### Required output

- `tools/merge_reports/LOCAL_validation_campaign_selection_table_20260405.csv`

### Selection logic

1. start from the canonical reusable inventory
2. replace the stale `72` static rows with:
   - `42` refreshed static non-`FAIL` rows
   - `21` residual-band broad-default rows under `F085_sub2_s100`
   - `9` promoted local overrides
3. replace dynamic row `15` with the promoted exact replay

### Required pool checks

| pool | expected count |
|---|---:|
| reusable historical | 218 |
| refreshed static non-`FAIL` | 42 |
| residual-band broad-default | 21 |
| promoted local static override | 9 |
| promoted dynamic override | 1 |
| overall | 291 |

### Critical checks

- exactly `291` rows
- exactly `291` unique `case_key`
- no `NA` selected paths
- no duplicate case selection
- all selected artifacts exist on disk
- all selected health records exist on disk
- current RHS-NS and legacy RHS rows preserve their distinct prior semantics

## Phase E: Regenerate Campaign-Level Health

### Goal

Compute fresh campaign-level health from the final merged selection table rather
than relying on wave-local summaries.

### Required outputs

- `tools/merge_reports/LOCAL_validation_campaign_health_merged_20260405.csv`
- `tools/merge_reports/LOCAL_validation_campaign_health_summary_20260405.csv`
- `tools/merge_reports/LOCAL_validation_campaign_warn_register_20260405.csv`

### Required derived tables

1. full row-level merged health
2. compact summary by:
   - model
   - inference
   - root kind
   - family
   - tau
3. source-pool summary:
   - reusable historical
   - refreshed static
   - broad-default residual
   - local static override
   - dynamic override
4. WARN register with provenance notes

### Acceptance checks

- `0` runtime failures
- `0` gate `FAIL`
- all `WARN` rows have explicit provenance notes
- no selected row is still `MISSING`
- merged totals reconcile exactly to `291`

## Phase F: Provenance Audit

### Goal

Make sure the final merged table is scientifically defensible.

### Audit questions

1. Does every promoted override point to the intended artifact?
2. Did any stale artifact leak back in through path collisions?
3. Are current RHS-NS and legacy RHS rows still separated correctly?
4. Does row `87` point to the promoted wave-11 rescue and not to an older
   failing artifact?
5. Does dynamic row `15` point to the exact replay rescue and not to the older
   unhealthy refresh artifact?

### Required audit output

- `reports/static_exal_tuning_20260405/comparison_ready_provenance_audit_20260405.md`

## Recommended Implementation Scripts

To keep the assembly deterministic and reproducible, the next implementation
should be split into four small scripts rather than one large ad hoc notebook:

1. `tools/merge_reports/LOCAL_validation_campaign_freeze_map_20260405.R`
   - freeze the broad default + local override policy
2. `tools/merge_reports/LOCAL_validation_campaign_build_selection_table_20260405.R`
   - build the `291`-row final merged selection table
3. `tools/merge_reports/LOCAL_validation_campaign_regenerate_health_20260405.R`
   - read selected artifacts and rebuild campaign-level health
4. `tools/merge_reports/LOCAL_validation_campaign_audit_20260405.R`
   - assert counts, uniqueness, provenance, and acceptance rule

## Shortest Safe Execution Order

1. freeze policy
2. build manifest registry
3. materialize reusable `218` inventory
4. build final merged `291`-row selection table
5. regenerate merged campaign health
6. run provenance audit
7. only then generate the broad comparison tables

## Bottom Line

The remaining work is now an assembly and audit problem, not a tuning problem.

The plan is robust if and only if it preserves these invariants:

- exact pool accounting: `218 + 42 + 21 + 9 + 1 = 291`
- exact path provenance for every promoted override
- zero selected runtime failures
- zero selected gate `FAIL`
- explicit documentation for every selected `WARN`

If those invariants hold, the branch is ready to move directly into the final
healthy-fit campaign assembly and broad comparison reporting phase.

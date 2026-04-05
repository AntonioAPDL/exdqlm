# Original 288 Realignment Investigation And Recovery Plan

Date: 2026-04-05

Status: investigation and planning only. No new validation runs were launched in
this checkpoint.

## Purpose

Re-anchor the repaired validation study to the original `288` method-level
study cells from the March 9 baseline universe, while preserving as many of the
successful repairs from the later `291`-row hybrid campaign as possible.

This document exists because the branch-level comparison-ready assembly and
reporting bundle was built on a healthy `291`-row repaired campaign, but that
campaign is not the same study universe as the original `288`-cell design.

The goal from this point onward is:

1. recover the original `288` study cells, not a hybrid replacement universe
2. reuse repaired artifacts from the `291` campaign wherever they truly map
   onto those original cells
3. identify exactly which original cells are still unhealthy after that remap
4. plan the remaining work against the true original target before launching
   any new repair runs

## Executive Conclusion

The current `291`-row selected campaign is healthy, but it is not yet the
correct final comparison universe if the publication target is "the original
`288` study cells with healthy selected fits."

The good news is that most of the repair work transfers cleanly once the
selection table is reinterpreted by the actual artifact root path instead of by
the later campaign semantics:

- all original `72` `static_paper` cells are already recoverable as healthy
- all original `144` `static_shrink` baseline cells are already recoverable as
  healthy
- `48` of the original `72` `dynamic` cells are already healthy
- only `24` original cells remain unresolved, and all `24` are dynamic

So the problem is no longer "untangle the whole study." The study can now be
split cleanly into:

- a fully recovered static baseline universe
- a dynamic-only residual repair program

## Original Study Definition

The original baseline study universe consists of exactly `288` method-level
cells.

### Static paper block

- families: `gausmix`, `laplace`, `normal`
- quantiles: `0.05`, `0.25`, `0.95`
- sample sizes: `tt100`, `tt1000`
- models: `al`, `exal`
- inference: `vb`, `mcmc`
- prior/root semantics: `paper`

Count:

- `3 * 3 * 2 * 2 * 2 = 72`

### Static shrink baseline block

- families: `gausmix`, `laplace`, `normal`
- quantiles: `0.05`, `0.25`, `0.95`
- sample sizes: `tt100`, `tt1000`
- priors: `rhs`, `ridge`
- models: `al`, `exal`
- inference: `vb`, `mcmc`

Count:

- `3 * 3 * 2 * 2 * 2 * 2 = 144`

### Dynamic baseline block

- families: `gausmix`, `laplace`, `normal`
- quantiles: `0.05`, `0.25`, `0.95`
- horizons: `TT500`, `TT5000`
- models: `dqlm`, `exdqlm`
- inference: `vb`, `mcmc`

Count:

- `3 * 3 * 2 * 2 * 2 = 72`

### Total

- `72 + 144 + 72 = 288`

## Timeline Reconstruction

### 1. Original baseline study

The original study was generated from the March 9 result roots:

- `results/function_testing_20260309_static_paper_family_qspec`
- `results/function_testing_20260309_static_shrinkage_family_qspec`
- `results/function_testing_20260309_dynamic_dlm_family_qspec`

These roots define the original publication target universe.

### 2. Static repair campaign

The later validation recovery work focused heavily on the static `exal`
failure bands, especially:

- current `rhs_ns` carry-forward refresh work
- legacy `rhs` refresh work
- fail-band bridge programs
- local row-specific static repairs

This was scientifically useful, but it introduced a new static-shrink semantic
layer (`rhs_ns`) that was not part of the original March 9 baseline universe.

### 3. Dynamic work narrowed to a tail-sidecar

The dynamic work during the repair phase concentrated on a small tail debt,
especially rows `5`, `15`, and `57`, rather than on a full dynamic baseline
reassembly.

This was a reasonable operational choice during repair, but it means the final
selected campaign did not carry forward the full original dynamic universe.

### 4. Comparison-ready hybrid campaign

The branch-level assembly then froze a healthy `291`-row repaired campaign with
these pool counts:

- `216` historical reusable static
- `42` refreshed static non-`FAIL`
- `21` residual-band broad-default static
- `9` local static overrides
- `2` historical dynamic reusable
- `1` dynamic local override

That campaign is healthy and operationally real, but it is not the same target
as the original `288` design.

## Why The Current 291 Campaign Drifted From The Original 288

Three things happened simultaneously.

### 1. Most of the original dynamic universe was dropped

The current selected campaign contains only `3` dynamic rows:

- `2` historical dynamic reusable rows
- `1` dynamic local override

The original baseline dynamic block contains `72` rows.

So the repaired comparison bundle currently omits `69` original dynamic study
cells.

### 2. Original static shrink `ridge` semantics were replaced by later repair semantics

The original static shrink baseline contains:

- `72` `rhs`
- `72` `ridge`

The repaired static campaign introduced `rhs_ns` semantics and later reporting
treated parts of that repair universe as if it were a broad final comparison
target.

### 3. Some repaired static shrink artifacts were counted twice under different labels

The current selected table contains:

- `291` selected rows
- but only `233` unique `selected_fit_path` values

All duplicate artifact reuse is concentrated in `static_shrink`:

- `58` duplicated rows labeled `rhs`
- `58` duplicated rows labeled `rhs_ns`

This means the same repaired fit artifact is sometimes counted twice under two
different semantic labels.

## Important Correction: Artifact-Path Remap Saves Most Of The Work

The semantic labels in the current selected table are not sufficient to recover
the original study cleanly.

However, if selected rows are remapped by the actual source root implied by
their `selected_fit_path`, then the later repaired campaign becomes much more
useful for the original baseline study.

The remap rule is:

- `validation_paper_tt*` -> original `static_paper`
- `validation_shrink_rhs_tt*` -> original `static_shrink` with prior `rhs`
- `validation_shrink_ridge_tt*` -> original `static_shrink` with prior `ridge`
- `validation_dynamic_tt*` -> original `dynamic`

Under that remap, the original baseline universe can be rebuilt as:

1. use the repaired selected artifact when it maps directly onto an original
   baseline cell
2. otherwise keep the untouched original baseline artifact if that original row
   was already `PASS` or `WARN`
3. classify the row as unresolved only if neither of the above yields a
   healthy original-baseline fit

### Salvage accounting

| block | original cells | healthy via repaired selection | healthy via untouched baseline | healthy now | unresolved |
|---|---:|---:|---:|---:|---:|
| `static_paper` | `72` | `72` | `0` | `72` | `0` |
| `static_shrink` | `144` | `144` | `0` | `144` | `0` |
| `dynamic` | `72` | `3` | `45` | `48` | `24` |
| total | `288` | `219` | `45` | `264` | `24` |

This is the key result of the investigation.

It means:

- the entire original static universe is already recoverable as healthy
- the remaining debt is entirely dynamic

## Current Original-288 Gap Inventory

The unresolved original-baseline cells are exactly `24`, and all of them are
dynamic.

Breakdown:

- `dqlm vb`: `0` unresolved
- `dqlm mcmc`: `7` unresolved
- `exdqlm vb`: `2` unresolved
- `exdqlm mcmc`: `15` unresolved

Machine-readable inventory:

- `tools/merge_reports/LOCAL_original288_realignment_unresolved_dynamic_inventory_20260405.csv`
- `tools/merge_reports/LOCAL_original288_realignment_block_status_20260405.csv`

## What We Should Treat As The New Ground Truth

From this point onward, the recovery target should be:

- not the healthy `291` hybrid campaign
- but the original `288` baseline study cells

The `291` campaign should instead be treated as:

- a repair knowledge base
- a source of reusable artifacts
- a source of transfer lessons for the remaining dynamic debt

This distinction matters because:

- the original study design is what broad comparison claims should be tied to
- the repaired `291` table mixes old baseline roots, refreshed static repair
  roots, and a dynamic tail supplement
- the publication-facing comparison should not silently change the study
  universe

## Recovery Principles For The Corrected 288 Campaign

1. Freeze a canonical registry of the original `288` baseline keys.
2. Route repaired artifacts into that registry by actual source path, not by
   later semantic label alone.
3. Treat the current static side as provisionally closed unless a strict
   registry audit finds a specific static hole.
4. Treat the remaining repair problem as dynamic-first, not static-first.
5. Do not rerun broad static programs unless the registry audit proves they are
   actually needed for the original `288` universe.
6. Keep the repaired `291` bundle as evidence, not as the final study
   definition.

## High-Quality Recovery Checklist

### Phase A: Freeze the true target universe

1. Build a canonical original-`288` registry with one row per baseline method
   cell.
2. Include these key dimensions in that registry:
   - block/root kind
   - family
   - tau
   - sample size or horizon
   - prior/root semantics
   - model
   - inference
3. Verify the registry count is exactly `288`.

### Phase B: Build a corrected carry-forward table

1. Reinterpret the repaired `291` selection table by actual `selected_fit_path`
   root.
2. Map those repaired artifacts onto the canonical original `288` registry.
3. For any uncovered original cell, fall back to the untouched baseline result
   if that baseline row is already `PASS` or `WARN`.
4. Produce a corrected carry-forward table with exactly `288` target keys.
5. Verify no target key is duplicated.
6. Verify no artifact is silently reused under conflicting original-baseline
   semantics.

### Phase C: Lock down the static side

1. Confirm that all `72` original `static_paper` cells are now healthy in the
   corrected carry-forward table.
2. Confirm that all `144` original `static_shrink` cells are now healthy in the
   corrected carry-forward table.
3. Record the exact repaired-or-baseline provenance used for every static row.
4. Do not reopen static repair unless the corrected registry audit finds a true
   original-baseline gap.

### Phase D: Audit the dynamic side comprehensively

1. Build the full original dynamic `72`-cell registry.
2. Mark which dynamic cells already have healthy baseline artifacts.
3. Mark which dynamic cells already have healthy transferred repairs from the
   later repair program.
4. Confirm that the unresolved dynamic debt is exactly the `24` rows in the
   machine-readable inventory.
5. Group the `24` rows by:
   - model
   - inference
   - family
   - tau
   - horizon
6. Rank these gaps by likely transfer value from the repaired `291` lessons.

### Phase E: Harvest dynamic repair candidates before launching anything new

1. Review all existing dynamic repair-sidecar artifacts, especially the row
   `5` / `15` / `57` work and any exact-historical rescue lanes.
2. Identify whether any of the unresolved `24` dynamic baseline cells already
   have a healthy analogue from later repair work that was not yet mapped back
   into the original registry.
3. Prefer carry-forward from already completed repaired artifacts over new
   reruns wherever scientifically defensible.
4. Only classify a dynamic cell as needing new computation after the carry-
   forward audit is complete.

### Phase F: Plan the remaining dynamic repair program

1. Build a dynamic-only repair manifest against the unresolved original `24`
   cells.
2. Prioritize the weakest baseline strata first:
   - `exdqlm mcmc`
   - `dqlm mcmc`
   - then the small `exdqlm vb` residue
3. Keep the static side frozen while the dynamic repair work proceeds.
4. Design the dynamic repair lane so that every new run maps directly back to
   one original `288` registry key.

### Phase G: Rebuild final reporting on the corrected target

1. After dynamic repair, regenerate the corrected `288` selection table.
2. Recompute row-level health on exactly that `288`-row table.
3. Rebuild broad comparison tables using the corrected original-baseline
   universe.
4. Recheck pairwise comparison counts against the original study design.
5. Only then treat the study as publication-ready.

## Acceptance Criteria For The Corrected 288 Campaign

The corrected final campaign should not be signed off until all of the
following are true:

1. exactly `288` original target keys are present
2. every selected target row is `PASS` or `WARN`
3. selected `FAIL` rows = `0`
4. every selected row maps to an original March 9 study cell
5. no duplicated selected artifact is counted under conflicting baseline
   semantics
6. the dynamic comparison is based on the full corrected original dynamic
   universe, not a 3-row supplement

## Immediate Next Decision

Do not launch new runs yet.

The next correct implementation step is:

1. build the canonical original-`288` registry
2. build the corrected carry-forward table
3. verify the `264 healthy / 24 unresolved` accounting mechanically
4. only after that, design the dynamic-only repair program for the residual
   `24`

That is the cleanest and least risky way to untangle the current hybrid state
and get back to the true publication target.

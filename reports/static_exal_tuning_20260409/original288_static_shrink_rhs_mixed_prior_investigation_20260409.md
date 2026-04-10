# Original288 Static Shrink RHS Mixed-Prior Investigation

Date: 2026-04-09

## Purpose

This note records a study-governance correction for the accepted
`original288 / v7` validation state.

The user requirement is now explicit:

- always use `rhs_ns`
- never use legacy `rhs`

Under that rule, the accepted `static_shrink / rhs` branch can no longer be
treated as a clean prior-family result.

## Decision Summary

The branch-level decision is:

1. freeze the current `static_shrink / rhs` accepted rows as **legacy
   mixed-prior historical results**
2. rebuild the entire branch as explicit `rhs_ns` only
3. rerun the broader metric comparison and cluster diagnosis after the corrected
   `rhs_ns` branch is available

This is a **full-branch correction**, not a small patch.

## Scope

| Quantity | Value |
|---|---:|
| accepted total | `288` |
| `static_shrink` rows | `144` |
| `static_shrink / rhs` rows to correct | `72` |
| share of accepted `288` | `25.0%` |
| share of `static_shrink` | `50.0%` |
| MCMC rows in rebuild | `36` |
| VB rows in rebuild | `36` |

The current accepted `rhs` branch is the full Cartesian branch:

- families: `normal`, `laplace`, `gausmix`
- taus: `0p05`, `0p25`, `0p95`
- fit sizes: `100`, `1000`
- models: `al`, `exal`
- inference: `mcmc`, `vb`

## Inputs

- [accepted selection `v7`](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/LOCAL_original288_carryforward_selection_v7_20260407.csv)
- [prior audit script](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/LOCAL_original288_static_shrink_rhs_prior_audit_20260409.R)

Generated audit outputs:

- [row audit](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/original288_static_shrink_rhs_prior_audit_20260409/original288_static_shrink_rhs_row_audit_20260409.csv)
- [bucket summary](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/original288_static_shrink_rhs_prior_audit_20260409/original288_static_shrink_rhs_bucket_summary_20260409.csv)
- [bucket by inference](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/original288_static_shrink_rhs_prior_audit_20260409/original288_static_shrink_rhs_bucket_by_inference_20260409.csv)
- [rhs_ns rebuild inventory](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/original288_static_shrink_rhs_prior_audit_20260409/original288_static_shrink_rhsns_rebuild_inventory_20260409.csv)

## Main Finding

The accepted `static_shrink / rhs` branch is mixed.

Evidence buckets:

| Evidence bucket | Count | Share | Interpretation |
|---|---:|---:|---|
| `rhsns_explicit` | `35` | `48.6%` | selected artifact explicitly names `rhsns` |
| `baseline_ambiguous` | `27` | `37.5%` | baseline carry-forward under `validation_shrink_rhs_*` with no explicit `rhs_ns` marker |
| `repaired_ambiguous_nonrhsns` | `7` | `9.7%` | repaired branch, but still not explicit `rhs_ns` |
| `rhs_legacy_explicit` | `3` | `4.2%` | explicit legacy `rhs` artifact |

This means the accepted `rhs` branch is **not** safely interpretable as
“really `rhs_ns` underneath”.

## By Inference And Model

| Evidence bucket | Inference | Model | Rows |
|---|---|---|---:|
| `rhsns_explicit` | `mcmc` | `al` | `7` |
| `rhsns_explicit` | `mcmc` | `exal` | `6` |
| `rhsns_explicit` | `vb` | `al` | `4` |
| `rhsns_explicit` | `vb` | `exal` | `18` |
| `baseline_ambiguous` | `mcmc` | `al` | `11` |
| `baseline_ambiguous` | `mcmc` | `exal` | `2` |
| `baseline_ambiguous` | `vb` | `al` | `14` |
| `repaired_ambiguous_nonrhsns` | `mcmc` | `exal` | `7` |
| `rhs_legacy_explicit` | `mcmc` | `exal` | `3` |

The main issue is therefore not only the presence of explicit legacy `rhs`.
The larger issue is that a big part of the accepted branch is **ambiguous**
under a strict `rhs_ns`-only governance rule.

## Interpretation

The current `static_shrink / rhs` metric results remain useful as a
**historical record** of what the accepted `v7` carry-forward looked like.

They should no longer be used as:

- a clean prior-family comparison
- a propagation target
- a forward scientific conclusion about `rhs_ns`

That includes both:

- the broader metric comparison note
- the cluster-by-cluster diagnosis

Those notes can remain in place, but the `static_shrink / rhs` entries in them
should now be read as **legacy mixed-prior signals only**.

## Corrective Action

The clean correction is to rebuild the entire branch as:

- `block = static_shrink`
- prior family = `rhs_ns`
- same `72` scenario rows
- same family / tau / fit-size / model / inference grid

Why full rebuild instead of patching only the clearly wrong subset:

- it removes label ambiguity completely
- it gives one clean study definition
- it keeps future comparisons reproducible
- it avoids spending time proving which ambiguous baseline rows were “probably”
  `rhs_ns`

## Post-Rebuild Verification

After the corrected `rhs_ns` branch is rerun, the next verification step is:

1. rebuild the static broader metric comparison
2. rebuild the static cluster diagnosis
3. compare `al` vs `exal` within `mcmc`
4. compare `al` vs `exal` within `vb`
5. verify whether `exal` remains better overall in static MCMC once the
   shrinkage branch is fully clean

That is the right point to answer the scientific question again. The current
mixed-prior `rhs` branch should not be used as the final answer to that
question.

## Final Read

Yes, the correction scope is the full `72`-row `static_shrink / rhs` branch.

The correct governance stance is:

- freeze current `rhs` results as legacy mixed-prior
- rebuild all `72` rows as explicit `rhs_ns`
- then rerun the cluster-by-cluster comparison before making final claims about
  static shrinkage performance under `rhs_ns`

# Original288 Propagation Framework

Date: 2026-04-09

This document converts the metric-comparison and cluster-diagnosis work into an
explicit pre-launch propagation framework.

The purpose is **not** to relaunch immediately. The purpose is to make the next
relaunch:

- documented
- reproducible
- easy to modify
- cluster-specific rather than overgeneralized

## Inputs

This framework is built from:

- [original288 metric comparison](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/reports/static_exal_tuning_20260409/original288_metric_comparison_20260409.md)
- [original288 metric cluster diagnosis](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/reports/static_exal_tuning_20260409/original288_metric_cluster_diagnosis_20260409.md)
- [static shrink rhs mixed-prior investigation](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/reports/static_exal_tuning_20260409/original288_static_shrink_rhs_mixed_prior_investigation_20260409.md)
- [propagation rules CSV](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/reports/static_exal_tuning_20260409/original288_propagation_rules_20260409.csv)
- [prepare script](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/LOCAL_original288_propagation_prepare_20260409.R)

Generated artifacts:

- [workstreams](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/reports/static_exal_tuning_20260409/original288_propagation_workstreams_20260409.csv)
- [schedule](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/reports/static_exal_tuning_20260409/original288_propagation_schedule_20260409.csv)
- [legacy freeze](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/reports/static_exal_tuning_20260409/original288_propagation_legacy_freeze_20260409.csv)
- [rebuild required](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/reports/static_exal_tuning_20260409/original288_propagation_rebuild_required_20260409.csv)
- [hold fixed](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/reports/static_exal_tuning_20260409/original288_propagation_hold_fixed_20260409.csv)
- [audit blockers](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/reports/static_exal_tuning_20260409/original288_propagation_audit_blockers_20260409.csv)

## What “Propagate” Means Here

Propagation does **not** mean:

- rewrite all baselines at once
- assume the paper-aligned static `slice` setup is globally optimal
- copy static `exal` settings directly into every dynamic cluster
- promote clusters without within-inference matched comparisons

Propagation **does** mean:

- define a stronger reference profile for clusters where the metric evidence is
  already favorable
- keep comparisons within inference class:
  - `al` vs `exal` within `mcmc`
  - `al` vs `exal` within `vb`
  - `dqlm` vs `exdqlm` within `mcmc`
  - `dqlm` vs `exdqlm` within `vb`
- separate:
  - propagation clusters
  - reinforcement clusters
  - repair clusters
  - hold-fixed clusters
  - audit-blocked clusters

## Reference Profiles

The framework uses named target profiles rather than hard-coding one universal
relaunch setup.

| Profile | Intended use | Meaning |
|---|---|---|
| `legacy_mixed_prior_freeze` | legacy governance | freeze a historical branch that should no longer drive propagation or scientific interpretation |
| `static_rhsns_full_rebuild` | corrected shrinkage rhs branch | rebuild the entire old `rhs` branch as explicit `rhs_ns` only |
| `static_exal_ref_slice_long` | `static_paper / mcmc` | propagate the paper-aligned exAL MCMC reference |
| `static_exal_ref_slice_long_shrink` | `static_shrink / mcmc` | adapt the same static MCMC idea to shrinkage clusters |
| `static_exal_vb_tau025_repair` | static VB weak pocket | investigate and repair the tau 0.25 VB failure mode |
| `static_exal_vb_hold` | static VB non-0.25 | hold the current clusters stable while tau 0.25 is diagnosed |
| `dynamic_exdqlm_tau095_ref` | dynamic MCMC `tau=0.95` | reinforce the strongest dynamic tail cluster |
| `dynamic_exdqlm_tau095_ref_vb` | dynamic VB `tau=0.95` | reinforce the strongest dynamic VB tail cluster |
| `dynamic_exdqlm_lowmid_repair` | dynamic MCMC `tau=0.05/0.25` | repair low/mid tau calibration and `q_rmse` |
| `dynamic_exdqlm_lowmid_repair_vb` | dynamic VB `tau=0.05/0.25` | repair low/mid tau calibration collapse |

## What Gets Frozen And Rebuilt

### 1. Static shrink mixed-prior correction

The `static_shrink / rhs` branch is no longer treated as an audit blocker. It
is now treated as a **study-definition correction**.

Governance decision:

- freeze the current `static_shrink / rhs` accepted rows as **legacy
  mixed-prior historical results**
- do not use that branch for forward propagation
- do not interpret it as a clean `rhs_ns` prior family
- rebuild the entire branch as explicit `rhs_ns` only

Scope:

- `72` rows total
- `36` MCMC
- `36` VB
- `25.0%` of the accepted `288`
- `50.0%` of the `static_shrink` block

This rebuild is full-branch by design because the accepted `rhs` bucket mixes:

- explicit `rhs_ns` rows
- explicit legacy `rhs` rows
- ambiguous baseline carry-forward rows
- repaired rows that are still not explicit `rhs_ns`

That mixed state makes the historical branch useful only as a legacy record,
not as a clean prior-family result.

## What Gets Propagated

### 1. Static MCMC propagation

These are the highest-confidence propagation targets:

- `static_paper / paper / mcmc`
- `static_shrink / ridge / mcmc`

These are promoted because the metric diagnosis is already favorable to `exal`
in a strong and broad way.

### 2. Dynamic reinforcement

These are the strongest dynamic clusters and should be reinforced rather than
treated as generic dynamic defaults:

- `dynamic / mcmc / tau = 0.95`
- `dynamic / vb / tau = 0.95`

The metric diagnosis shows that `tau = 0.95` is the clear dynamic strength
region for `exdqlm`.

## What Gets Repaired Instead Of Propagated

### Static VB repair

The framework explicitly isolates:

- `static_paper / vb / tau = 0.25`
- `static_shrink / ridge / vb / tau = 0.25`

This is a repair lane, not a propagation lane, because it is the cleanest and
most consistent static weak pocket for `exal`.

### Dynamic low/mid tau repair

These are repair lanes:

- `dynamic / mcmc / tau = 0.05`
- `dynamic / mcmc / tau = 0.25`
- `dynamic / vb / tau = 0.05`
- `dynamic / vb / tau = 0.25`

These clusters are weak because:

- `q_rmse` is usually worse
- calibration can be poor
- for VB especially, `pplc` can improve while coverage degrades badly

## What Gets Held Fixed

The framework currently holds fixed:

- `static_paper / vb / tau = 0.05`
- `static_paper / vb / tau = 0.95`
- `static_shrink / ridge / vb / tau = 0.05`
- `static_shrink / ridge / vb / tau = 0.95`

Reason:
- these clusters are mixed-to-positive for `exal`
- we do not want to destabilize them until the `tau = 0.25` VB pocket is
  better understood

## Workstream Summary

The generated workstream table converts the rules into four practical groups:

1. `phase0_static_prior_correction`
   - freeze the legacy mixed-prior `static_shrink / rhs` branch
   - rebuild all `72` rows as explicit `rhs_ns`
2. `phase1_static`
   - propagate strong static MCMC clusters
3. `phase2_static_vb`
   - repair `tau = 0.25` only in clean paper/ridge VB clusters
   - hold/monitor the rest of clean static VB
4. `phase3_dynamic`
   - reinforce `tau = 0.95`
5. `phase4_dynamic_repair`
   - repair low/mid tau dynamic clusters

## Practical Launch Principle

The framework is designed so that the next relaunch should be assembled from
**separate manifests by workstream**, not one monolithic experiment family.

That means the eventual launch should be split into:

- static propagation manifests
- static VB repair manifests
- dynamic reinforcement manifests
- dynamic repair manifests

This keeps the system flexible for future tuning changes and prevents strong
clusters from being mixed together with clearly weak ones.

## Final Read

This framework makes the next step clear:

- propagate where the evidence is already strong
- repair where the cluster diagnosis says performance is weak
- freeze the current `static_shrink / rhs` branch as legacy mixed-prior output
- rebuild that full branch as explicit `rhs_ns` before using it again in
  propagation or forward scientific interpretation
- keep comparisons within inference class

That is the version most likely to move dynamic performance toward the stronger
static `exal` pattern without overgeneralizing from the wrong clusters.

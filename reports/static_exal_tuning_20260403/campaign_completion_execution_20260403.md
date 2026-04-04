# Validation Campaign: Focused Completion Execution Program

Date: 2026-04-03

Current context:

- `reports/static_exal_tuning_20260403/post_wave8_campaign_readiness_plan_20260403.md`
- `reports/static_exal_tuning_20260403/wave8_closeout_and_fail_only_repair_program.md`
- `reports/static_exal_tuning_20260403/fail_only_bridge_results_20260403.md`
- `tools/merge_reports/LOCAL_VALIDATION_RECOVERY_TRACKER_STATIC_EXAL_20260331.md`

## Status Note

This document is the current execution record for the campaign-completion phase.

The study has moved out of broad tuning search and into focused completion.
The active question is no longer which static `exal` family to trust. The
active question is how to roll the promoted exact-runner baseline through the
minimum remaining stale debt while preserving artifact reuse and final-table
comparability.

## Validated State at Start of This Phase

### What improved

- wave-8 completed cleanly under the repaired resume / monitor / supervisor
  stack
- `F080_sub2_s105` is the promoted zero-FAIL exact-runner baseline
- the fail-only bridge run resolved the final ambiguity:
  - `F075_sub2_s095` is dominated and dropped
  - `F080_sub2_s095` failed because it was slightly too tight, not because the
    `F080` family is broken
- dynamic row `5` is now resolved under current `HEAD`

### What still fails or remains stale

- `72` static `exal` MCMC rows remain stale relative to the promoted baseline:
  - `54` current RHS-NS refresh rows
  - `18` legacy RHS comparison rows
- dynamic row `15` remains `done / FAIL / FALSE`
- the merged comparison-ready campaign tables have not yet been regenerated

### What worked best

1. `F080_sub2_s105` as the active exact-runner geometry
2. `F080_sub2_s100_ref` as the primary fallback
3. reuse of valid artifacts instead of relaunching broad slices
4. deterministic manifests, auditable logs, and keep-going supervision

### What clearly did not work

- reopening the broad tuning grid
- treating `F075_sub2_s095` as salvageable
- treating the `C060` family as the active production baseline
- assuming the stale static refresh manifests were disjoint

## Critical Execution Correction

The stale `72`-row static debt cannot be relaunched with a naive single
variant-tag wrapper.

Why:

- the `18` legacy RHS comparison rows overlap the current static RHS-NS refresh
  slice on both `row_id` and `run_root`
- the overlapping rows differ in intended prior semantics, not in path layout:
  - current slice expects `rhs_ns`
  - legacy slice expects `rhs`
- the older static tuning runner inherited `beta_prior` from the original
  baseline fit / run config, which is insufficient for the current refresh
  slice because:
  - static-paper baseline fits are still `ridge`
  - overlapping static-shrink baseline fits are still `rhs`

Practical consequence:

- the focused campaign refresh must carry scope-specific variant tags and
  scope-specific prior templates
- current RHS-NS reruns must source `beta_prior = rhs_ns` from the stale
  `rhsns_impl_refresh_20260329` artifacts
- legacy comparison reruns must source `beta_prior = rhs` from the stale
  `rhs_legacy_refresh_20260329` artifacts

This preserves the current-vs-legacy comparison semantics without rerunning the
entire `291`-row campaign.

## Implemented Execution Program

### Static refresh lane

Active baseline:

- `F080_sub2_s105`

Static refresh tooling:

- `tools/merge_reports/LOCAL_static_exal_f080s105_refresh_prepare_20260403.R`
- `tools/merge_reports/LOCAL_static_exal_f080s105_refresh_evaluate_20260403.R`
- `tools/merge_reports/LOCAL_static_exal_f080s105_refresh_launch_20260403.sh`
- `tools/merge_reports/LOCAL_static_exal_f080s105_refresh_supervisor_20260403.sh`
- `tools/merge_reports/LOCAL_static_exal_f080s105_refresh_monitor_20260403.sh`

Scope split:

| scope | rows | prior source | variant tag |
|---|---:|---|---|
| current RHS-NS refresh | 54 | stale `rhsns_impl_refresh_20260329` candidate fits | `static_exal_f080_sub2_s105_rhsns_current_20260403` |
| legacy RHS comparison refresh | 18 | stale `rhs_legacy_refresh_20260329` candidate fits | `static_exal_f080_sub2_s105_rhs_legacy_20260403` |

Geometry applied to both scopes:

- `gamma_substeps = 2`
- `p_global_eta_jump = 0.08`
- `global_eta_jump_scale = 1.05`
- `mh_proposal = laplace_rw`

Campaign-equivalent MCMC budget:

- `n_burn = 2000`
- `n_mcmc = 1000`
- `thin = 1`

This uses the promoted exact-runner geometry while keeping the final refresh
comparable to the original campaign budget.

### Dynamic row `15` sidecar

Implemented sidecar preparation:

- `tools/merge_reports/LOCAL_dynamic_row15_sidecar_prepare_20260403.R`

Current readiness decision:

- `blocked_pending_repair_hypothesis`

Why not launched yet:

- row `15` already finishes under current `HEAD`
- the remaining failure is gate-level chain quality, dominated by
  `ess_gamma_per1k = FAIL`
- no new code change or new tuning hypothesis has yet been introduced that
  would make an immediate identical relaunch scientifically valuable

Current lane decision:

- keep row `15` separate
- do not let it block the larger static rerun
- prepare the sidecar bookkeeping now, but defer launch until there is an
  actual repair or replacement hypothesis

## Verification Standard

Comparison-ready acceptance rule remains:

| criterion | requirement |
|---|---|
| stale static debt | `0` |
| dynamic tail debt | `0` unresolved rows |
| runtime failures | `0` |
| gate FAIL count | `0` |
| gate WARN count | acceptable if documented and scientifically interpretable |
| provenance | refreshed outputs tied back to scope-aware manifests and variant tags |

## Launch Decision

### Static lane

Launch-ready once both are verified:

1. prepare-only schedule and scope counts are correct
2. runner uses scope-correct prior templates and scope-correct variant tags

Verification completed before launch:

- prepare-only schedule confirms:
  - `54` current RHS-NS rows
  - `18` legacy RHS rows
  - scope-specific variant tags prevent current-vs-legacy key collisions
- current RHS-NS stale artifacts are only partially available (`36/54`), so the
  prepared schedule now uses:
  - row-specific prior templates where available
  - family-level current RHS-NS fallback templates where the stale row never
    completed
- a two-row smoke validated the corrected runner semantics:
  - current static-paper row `83` ran with `beta_prior = rhs_ns`
  - legacy shrink row `149` ran with `beta_prior = rhs`
  - the smoke was only a tooling verification pass (`50 + 50` iterations), not
    a campaign-quality scientific run

### Dynamic row `15`

Not launch-ready in this phase.

The next useful action for row `15` is not "rerun immediately." The next useful
action is "define a concrete repair hypothesis first."

## Comparison-Ready Closeout Path

After the static lane completes and row `15` is repaired:

1. merge the refreshed `72` static rows with the `218` reusable artifacts
2. merge the final row `15` sidecar artifact
3. regenerate campaign-level health tables
4. produce the final comparison-ready table grouped by:
   - model
   - inference
   - root kind
   - family
   - tau
5. apply the narrow fail-only discipline again only if a small residual band
   remains

## Operational Bottom Line

The current highest-value action is now clear:

1. launch the focused `72`-row static refresh under `F080_sub2_s105`
2. keep row `15` isolated as a documented sidecar debt
3. regenerate the final merged campaign tables once the static lane completes

That is the shortest rigorous path from the current validated branch state to a
comparison-ready and publication-ready validation campaign.

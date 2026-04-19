# Refreshed288 Canonical Relaunch Plan

Date: `2026-04-17`

## Purpose

This note defines the clean, high-quality path from the interrupted
`refreshed288_paperaligned_20260416` pilot to the next canonical full
`288`-case relaunch.

The goal is to keep the work:

- well documented,
- reproducible,
- easy to track,
- and scientifically clean.

## Artifact Split

We now treat the recent work as two separate study artifacts.

| artifact | role | status | canonical? |
|---|---|---|---|
| `refreshed288_paperaligned_20260416` | first fresh paper-aligned pilot run | interrupted during `full_static_vb` | `No` |
| next refreshed288 run with a new run tag | full clean relaunch from scratch | not launched yet | `Yes` |

Operational rule:

- do not retrofit new method behavior into the interrupted pilot run;
- do not mix pilot outputs with the next canonical relaunch outputs.

## Current Pilot State

Current interrupted run root:

- `tools/merge_reports/full288_refreshed288_paperaligned_20260416`

Current state at freeze:

| scope | total | completed | stale `running` | pending |
|---|---:|---:|---:|---:|
| full `288` run | `288` | `76` | `8` | `204` |

Interpretation:

- the smoke gate passed;
- the real full launch started;
- the run stopped operationally during `full_static_vb`;
- this pilot remains useful evidence, but it is not the canonical baseline.

Reference notes:

- [refreshed288_recovery_plan_20260417.md](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/reports/static_exal_tuning_20260417/refreshed288_recovery_plan_20260417.md)
- [refreshed288_rhsns_tau_policy_20260417.md](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/reports/static_exal_tuning_20260417/refreshed288_rhsns_tau_policy_20260417.md)
- [refreshed288_gamma_sigma_warmup_design_20260417.md](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/reports/static_exal_tuning_20260417/refreshed288_gamma_sigma_warmup_design_20260417.md)

## Canonical Relaunch Contract

The next canonical rerun must preserve these study axes:

| axis | canonical value |
|---|---|
| tau grid | `0.05`, `0.25`, `0.50` |
| families | `normal`, `laplace`, `gausmix` |
| static priors | `paper`, `ridge`, `rhs_ns` |
| forbidden shrink prior | plain `rhs` |
| VB engine | `LDVB` |
| MCMC engine | `slice` |
| MCMC init | explicit VB warm start |
| dynamic sizes | `TT500`, `TT5000` |
| static sizes | `TT100`, `TT1000` |
| seed policy | one deterministic seed per row |

Explicit refreshed shrinkage policy:

| context | explicit policy |
|---|---|
| `rhs_ns` VB tau warmup | `50` |
| `rhs_ns` VB `min_iter` | `80` |
| `rhs_ns` MCMC tau warmup | `500` |
| `rhs_ns` MCMC VB-init tau warmup | `50` |
| `rhs_ns` MCMC VB-init `min_iter` | `80` |

Gamma/sigma policy:

| context | current canonical interpretation |
|---|---|
| interrupted pilot | no explicit `sigmagam` warmup |
| next canonical rerun | only after a sigmagam-enabled package build is fully tested |

## Tracking And Naming Rules

The refreshed tooling now supports an explicit run tag so the next relaunch can
live in a fresh run root instead of reusing the interrupted pilot namespace.

Examples:

```bash
export REFRESHED288_RUN_TAG=20260417_canonical_v1
export REFRESHED288_VARIANT_TAG=0p50_ldvb_slice_sigmagam_v1
```

With that, the next rerun will materialize under new paths such as:

- `tools/merge_reports/LOCAL_refreshed288_full_manifest_20260417_canonical_v1.csv`
- `tools/merge_reports/LOCAL_refreshed288_run_contract_20260417_canonical_v1.csv`
- `tools/merge_reports/full288_refreshed288_paperaligned_20260417_canonical_v1`
- `reports/static_exal_tuning_20260417/refreshed288_full_status_20260417_canonical_v1.md`

This prevents the canonical rerun from looking like a silent mutation of the
interrupted pilot.

## Required Pre-Launch Checkpoints

Before launching the next canonical rerun, all of these must be true.

| checkpoint | requirement |
|---|---|
| interrupted pilot | preserved, not resumed, not mutated |
| method policy | explicit `rhs_ns` tau controls visible in generated configs |
| `sigmagam` feature | implemented and tested in the active package surface |
| manifests | generated from a fresh run tag |
| run contract | written for the new run tag |
| launch mode | detached runner with durable logs |
| git state | checkpoint committed before launch |

## Recommended Execution Order

The next canonical rerun should proceed in this order.

1. Preserve the interrupted pilot as non-canonical historical evidence.
2. Finish package-side warmup implementation and focused verification.
3. Generate a fresh canonical run tag and run contract.
4. Rebuild the refreshed288 manifests from scratch under the new run tag.
5. Launch smoke first under the new tag.
6. If smoke passes, launch the full study under the new tag.
7. Freeze the completed new run and treat that, not the pilot, as the baseline.

## Exact Intended Next-Launch Pattern

The new canonical relaunch should use a new run tag and a detached launcher.

Example:

```bash
export REFRESHED288_RUN_TAG=20260417_canonical_v1
export REFRESHED288_VARIANT_TAG=0p50_ldvb_slice_sigmagam_v1

tmux new-session -d -s refreshed288_canonical_v1 \
  "cd /home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration && \
   tools/merge_reports/LOCAL_refreshed288_launch_20260416.sh launch --manifest-kind=smoke \
   > reports/static_exal_tuning_20260417/refreshed288_canonical_v1_launch.log 2>&1"
```

Important:

- use a fresh run tag;
- do not use the recovery script for the canonical rerun;
- do not call the default launcher without the new tag if we intend a new study artifact.

## Summary

The clean path forward is:

- keep the interrupted `20260416` run as a preserved pilot,
- use the new explicit tagging and run-contract machinery,
- only launch a fresh canonical rerun after the warmup-enabled package surface
  is fully tested,
- and track that next run as a new named artifact from day one.

# Follow-up Handoff for `0.4.0` Validation Worktree After Warmup Normalization

Date: 2026-04-22

## Purpose

This note updates the `0.4.0` validation-study worktree after the original
freeze / sync / backport sequence completed on 2026-04-21.

It should be treated as the current handoff context for a Codex session working
inside this validation-study worktree. The main goal is to explain:

1. what had already been done before the new follow-up work,
2. what additional package-layer normalization and default warmup work was done
   afterward,
3. which commits and docs are now the sources of truth, and
4. how the three branches are supposed to relate to each other.

## Current remote-synced branch state

These branch tips were refreshed with `git fetch origin --prune` on
2026-04-22 before writing this note.

| Branch | Current SHA | Role |
|---|---|---|
| `origin/cransub/0.4.0` | `a812f445001a35fd17941fb33b36b34db08c98b5` | shared package base |
| `origin/validation/rerun-after-0.4.0-sync-0p4p0-integration` | `9df7db193b5027ce0ffdc5cc1b878369e89eb286` | `0.4.0` validation-study branch |
| `origin/feature/qdesn-mcmc-alternative-0p4p0-integration` | `4da5642a2538d4e5c5a893d042c5d2f3a580dbb4` | qdesn validation-study branch |

Local validation-worktree status at handoff time:

- branch: `validation/rerun-after-0.4.0-sync-0p4p0-integration`
- local HEAD: `9df7db193b5027ce0ffdc5cc1b878369e89eb286`
- `git status`: clean
- local HEAD matches `origin/validation/rerun-after-0.4.0-sync-0p4p0-integration`

## What had already been done before this follow-up

The earlier freeze / sync / backport work established:

| Branch / SHA | Meaning |
|---|---|
| `validation/rerun-after-0.4.0-sync-0p4p0-integration` at `5bdc943` | frozen validation branch after stopping the long recovery lane, syncing to upstream `0.4.0`, and fixing immediate sync issues |
| `integration/0.4.0-validation-warmup-backport` at `54fb296` | fresh `0.4.0`-based backport branch carrying selected validation-derived warmup / stability improvements |

That earlier phase already resolved these main issues:

- stopping the long-running recovery lane cleanly and documenting the freeze
- syncing validation code to upstream `0.4.0`
- keeping upstream `0.4.0` naming and package shape
- preserving selected validation-derived warmup / stability improvements
- fixing VB trace compatibility after the upstream `0.4.0` trace update

The main earlier validation docs in this repo are:

- [refreshed288_exdqlm_tt5000_recovery_stop_freeze_and_0p4p0_sync_handoff_20260421.md](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/reports/static_exal_tuning_20260421/refreshed288_exdqlm_tt5000_recovery_stop_freeze_and_0p4p0_sync_handoff_20260421.md)
- [refreshed288_0p4p0_sync_and_backport_execution_20260421.md](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/reports/static_exal_tuning_20260421/refreshed288_0p4p0_sync_and_backport_execution_20260421.md)

## What changed after that earlier sync

After the earlier `5bdc943` / `54fb296` phase, the qdesn integration repo
continued evolving and then went through a second, more structured
normalization pass.

The important later milestones were:

| Commit | Repo / branch | Meaning |
|---|---|---|
| `07bd93c` | qdesn integration branch | proper normalization of the package surface onto native `0.4.0` naming, removing temporary wrapper scaffolding and out-of-scope dataset additions |
| `12cf0d6` | qdesn integration branch | richer builder normalization and adoption work across qdesn / `0.4.0` package surfaces |
| `a812f44` | `cransub/0.4.0` | shared base after Stage 1 default warmup profile plus the late `control=` merge-quality fix |
| `9df7db1` | this validation branch | `0.4.0` validation branch after inheriting the finalized shared base behavior |
| `4da5642` | qdesn integration branch | qdesn branch after Stage 2 normalization onto the shared base while preserving qdesn-only supersets |

## Main new idea introduced by the follow-up work

The big design change after the earlier sync is:

**ordinary users should get safe warmup behavior automatically without needing
to hand-assemble advanced nested control lists.**

That means the shared package base now has a package-native default warmup
profile that is applied automatically at the entrypoint layer.

## Shared baseline now implemented in the package base

The current shared default warmup policy is:

| Area | Baseline behavior |
|---|---|
| `rhs` / `rhs_ns` prior | automatic tau warmup, target `50L` |
| exAL VB | light `(sigma, gamma)` warmup profile |
| exAL MCMC | light `(sigma, gamma)` warmup profile |
| explicit controls | still supported and override the defaults |
| strong theta / latent / precision rescue | still available, but not part of the universal baseline |

Concretely, the shared base now behaves like this:

### Prior-level shrinkage defaults

- `freeze_tau_warmup_iters = 50L`
- `force_tau_after_warmup = TRUE`

### exAL VB default sigmagam warmup

- `freeze_warmup_iters = 10L`
- `force_after_warmup = TRUE`
- `postwarmup_damping = 0.6`
- `postwarmup_damping_iters = 5L`
- `min_postwarmup_updates = 1L`

### exAL MCMC default sigmagam warmup

- `freeze_burnin_iters = 25L`
- `freeze_only_during_burn = TRUE`
- `force_after_warmup = TRUE`
- `delay_adapt_until_after_warmup = TRUE`
- `delay_laplace_refresh_until_after_warmup = TRUE`

## Important implementation rule from the follow-up

The default warmup behavior is now applied at the **entrypoint layer**, not by
making every user call the low-level builder helpers.

That is intentional. The builder helpers still exist, but they are now the
advanced / override path instead of the normal path.

## Important API-quality fix from the follow-up

A subtle issue was discovered during propagation:

- `exal_make_vb_control(control = ...)`
- `exal_make_mcmc_control(control = ...)`

could still overwrite incoming `control` values too aggressively because scalar
defaults were being reapplied even when the caller intended to preserve an
existing control list.

This was fixed in the shared base so that:

- an existing `control=` list is preserved,
- only missing defaults are filled,
- explicitly passed arguments still win,
- nested warmup blocks are normalized before being returned.

This is part of why the current `a812f44` / `9df7db1` / `4da5642` state should
be preferred over the earlier `54fb296` / `5bdc943` state.

## Intended three-branch architecture

The current work is built around this branch layering:

| Branch | Should contain |
|---|---|
| `0.4.0` package branch | only CRAN-bound package code, docs, tests, and intended package data |
| `0.4.0` validation-study branch | the shared `0.4.0` package layer plus validation-study files, scripts, reports, and datasets |
| qdesn validation-study branch | the same shared package layer plus validation-study machinery plus qdesn-specific files and rescue paths |

This means:

- the shared package-layer defaults should be owned by `cransub/0.4.0`
- this validation branch should inherit that package layer, not invent a new one
- the qdesn branch should inherit the same shared package layer and keep only
  the extra qdesn-specific supersets

## What is shared now

After the latest normalization, these package-facing files were checked and
matched across the branches wherever they are supposed to be identical:

- `R/exalStaticLDVB.R`
- `R/exalStaticMCMC.R`
- `R/exdqlmLDVB.R`
- `R/exdqlmMCMC.R`
- `R/exdqlm-package.R`
- `README.Rmd`
- `README.md`
- `NEWS.md`

That shared layer now comes from the current `0.4.0` base at `a812f44`.

## What remains intentionally different in qdesn

The qdesn branch still keeps the richer qdesn-only inference-control superset,
including readout-specific or rescue-oriented controls that do not belong in the
shared package base.

Examples include:

- qdesn-specific inference-control surfaces in `R/exal_inference_config.R`
- qdesn readout rescue paths
- qdesn-specific precision / latent rescue machinery
- qdesn validation scripts and reports

The point of the latest normalization was **not** to remove qdesn’s extra power.
It was to make the shared package layer consistent first, then let qdesn remain
the superset branch above that.

## Main qdesn docs to read

The qdesn integration repo is the main source of truth for the later
normalization work. These are the key docs to read there:

- [PLAN__qdesn_0p4p0_proper_normalization_20260421.md](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/PLAN__qdesn_0p4p0_proper_normalization_20260421.md)
- [REPORT__qdesn_0p4p0_proper_normalization_implementation_20260421.md](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_0p4p0_proper_normalization_implementation_20260421.md)
- [REPORT__qdesn_0p4p0_sync_carry_forward_implementation_20260421.md](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_0p4p0_sync_carry_forward_implementation_20260421.md)
- [REPORT__qdesn_warmup_builder_normalization_and_0p4p0_adoption_20260421.md](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_warmup_builder_normalization_and_0p4p0_adoption_20260421.md)
- [TRACK__qdesn_default_warmup_profile_and_branch_normalization_20260421.md](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/TRACK__qdesn_default_warmup_profile_and_branch_normalization_20260421.md)
- [REPORT__qdesn_default_warmup_profile_and_branch_normalization_implementation_20260421.md](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_default_warmup_profile_and_branch_normalization_implementation_20260421.md)

## What Codex in this worktree should do first

If you are the next Codex session in this validation worktree:

1. confirm branch state and SHAs locally
2. read the two local validation docs from 2026-04-21
3. read the qdesn normalization tracker and implementation reports listed above
4. understand that `9df7db1` is already the updated validation-branch state
   after the later shared warmup normalization work
5. do **not** assume the earlier `5bdc943` / `54fb296` state is still the final
   source of truth

## Paste-ready prompt for the next Codex session

```text
You are working inside the `0.4.0` validation-study worktree.

Before doing anything else, use the local repo state plus the qdesn integration
repo on this machine as your source of truth and orient yourself to the current
post-normalization branch state.

Current remote-synced branch tips:
- `origin/validation/rerun-after-0.4.0-sync-0p4p0-integration` = `9df7db193b5027ce0ffdc5cc1b878369e89eb286`
- `origin/cransub/0.4.0` = `a812f445001a35fd17941fb33b36b34db08c98b5`
- `origin/feature/qdesn-mcmc-alternative-0p4p0-integration` = `4da5642a2538d4e5c5a893d042c5d2f3a580dbb4`

Important historical references:
- earlier validation freeze/sync state: `5bdc943`
- earlier fresh backport branch: `54fb296`

Important correction:
- those earlier SHAs are no longer the final source of truth by themselves
- the shared package layer has since been normalized further
- the current shared package base is now `a812f44`
- this validation branch now reflects that normalized base at `9df7db1`
- the qdesn branch reflects the same shared base plus qdesn-specific supersets at `4da5642`

Your first job is to read and internalize the following local validation docs:
- `reports/static_exal_tuning_20260421/refreshed288_exdqlm_tt5000_recovery_stop_freeze_and_0p4p0_sync_handoff_20260421.md`
- `reports/static_exal_tuning_20260421/refreshed288_0p4p0_sync_and_backport_execution_20260421.md`
- `reports/static_exal_tuning_20260421/refreshed288_qdesn_default_warmup_normalization_followup_handoff_20260422.md`

Then read these docs from the qdesn integration repo:
- `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/PLAN__qdesn_0p4p0_proper_normalization_20260421.md`
- `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_0p4p0_proper_normalization_implementation_20260421.md`
- `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_0p4p0_sync_carry_forward_implementation_20260421.md`
- `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_warmup_builder_normalization_and_0p4p0_adoption_20260421.md`
- `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/TRACK__qdesn_default_warmup_profile_and_branch_normalization_20260421.md`
- `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_default_warmup_profile_and_branch_normalization_implementation_20260421.md`

Understand the current branch architecture:
- `0.4.0` package branch = shared package base
- `0.4.0` validation branch = shared package base + validation-study files
- qdesn validation branch = same shared package base + validation-study files + qdesn-specific files

Understand the current shared default warmup policy:
- `rhs` / `rhs_ns` tau warmup defaults to `50L`
- exAL VB gets light automatic `(sigma, gamma)` warmup
- exAL MCMC gets light automatic `(sigma, gamma)` warmup
- explicit manual `vb_control` / `mcmc_control` overrides still work
- stronger theta / latent / precision rescue remains available but is not the universal default

Also understand the late API-quality fix:
- `exal_make_vb_control(control = ...)`
- `exal_make_mcmc_control(control = ...)`
now preserve existing control lists and fill only missing defaults instead of clobbering inherited values

Your first concrete task in this worktree is:
1. confirm the local branch is at `9df7db1` and clean
2. summarize the current state back to the user in terms of:
   - what had already been done at `5bdc943` / `54fb296`
   - what changed later in `a812f44` / `9df7db1` / `4da5642`
   - what the current shared warmup defaults are
   - what is shared vs what remains intentionally qdesn-specific
3. only after that, proceed with the next user task

Do not assume the earlier backport state is sufficient without checking the
later normalization docs and branch tips listed above.
```

## Short summary

If you need the shortest possible mental model:

- the earlier sync/backport work was real and important
- but the package layer was normalized further afterward
- the current authoritative shared base is `a812f44`
- this validation branch is already updated to that base at `9df7db1`
- the qdesn branch is the matching superset at `4da5642`

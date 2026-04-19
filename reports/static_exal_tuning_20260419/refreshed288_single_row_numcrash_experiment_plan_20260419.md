# Refreshed288 Single-Row Numerical-Crash Experiment Plan

Date: `2026-04-19`

## Purpose

This note defines the next **isolated learning lane** for the dynamic numerical-crash problem.

The goal is **not** to rescue the full crash cohort immediately.

The goal is to:

1. choose **one representative failing row**,
2. hold fixed the parts of the method we already believe are directionally correct,
3. vary only a **small number of targeted MCMC levers**,
4. identify which lever actually changes failure timing or avoids the crash,
5. use that result to decide whether a broader relaunch is justified.

This is the highest-signal and least wasteful next step after the broader crash reruns.

## Chosen Representative Row

The recommended microscope row is:

| row_id | family | tau | fit size | model | inference | canonical crash |
|---|---|---:|---:|---|---|---|
| `8` | `gausmix` | `0.05` | `5000` | `exdqlm` | `mcmc` | `nonfinite_chi` |

### Why row `8`

It is the best single-row target because it is:

- a **true failing row**, not a control,
- part of the main expensive `TT5000` exDQLM crash family,
- one of the rows that clearly showed **backend sensitivity** in the diagnosis,
- one of the rows where the old crash was later reclassified as **upstream init / early-state instability**,
- representative of the exDQLM dynamic crash class that currently carries the most method complexity.

### Why not row `12`

Row `12` is cheaper, but it is not the right microscope row now because it is less stable as a diagnostic target across configurations. It is useful as a secondary bridge row, but it is not the best single-row study surface.

### Why not row `6`

Row `6` is the right DQLM representative, but DQLM is now a separate failure class. The current plan is to learn first on the richer exDQLM failure surface, then port the relevant lessons to DQLM.

## Core Diagnostic Principle

For this isolated lane, we should **hold the VB-init layer fixed** and only vary a narrow set of MCMC levers.

That avoids confounding:

- LDVB init stability,
- theta-state stability,
- latent-state stability,
- sigma/gamma stability,
- backend choice.

## Fixed Baseline Layer For All Arms

These settings should be held fixed across all experiment arms unless explicitly stated otherwise.

### Fixed VB / VB-init layer

| Control | Value |
|---|---:|
| VB / VB-init method | `ldvb` |
| `max_iter` | `800` |
| `min_iter` | `80` |
| `tol` | `0.01` |
| VB-init `n.samp` | `5000` |
| exDQLM VB `s_t` warmup | `50` |
| exDQLM VB `s_t` min postwarmup updates | `5` |
| VB `sigmagam` warmup | `50` |
| VB `sigmagam` min postwarmup updates | `5` |
| VB `sigmagam` postwarmup damping | `0.5` for `5` iterations |
| VB-init validation | require finite `theta`, `post_pred`, `sfe`, `sigma`, `gamma` |
| GIG `b_vec / chi` floor | `1e-10` |

### Why hold these fixed

We already have strong evidence that:

- weaker VB-init specs are not enough,
- exDQLM `s_t` is a real instability surface,
- the GIG floor is reasonable hardening but not the main root-cause lever,
- the current question is now mainly about the **dynamic MCMC path**, especially theta/backend behavior.

## Fixed Diagnostic Horizon For All Arms

We should **not** run full production-length chains for this microscope lane.

The current crashes happen very early, so the learning run should be short and diagnostic-heavy.

Recommended diagnostic horizon:

| Control | Value |
|---|---:|
| `n.burn` | `600` |
| `n.mcmc` | `200` |
| `thin` | `1` |
| `trace_diagnostics` | `TRUE` |
| `trace.every` | `1` |
| preserve binaries | `TRUE` |
| worker count | `1` |

### Why this horizon

This is long enough to answer:

- do we survive iteration `1`,
- do we survive the theta warmup exit,
- do we survive the latent warmup exit,
- do we survive the sigmagam warmup exit,
- do we produce a sane kept-draw tail,

without spending full `5000 / 20000` budgets on every experiment arm.

## Main Experimental Question

The question for this isolated lane is:

> For exDQLM row `8`, which of the following is the dominant rescue lever
> within the C++ backend family: backend mode, theta warmup, latent warmup,
> or sigmagam warmup?

## Experiment Ladder

This should be run as a **small sequential ladder**, not as a full Cartesian grid.

### Arm A: Reproduction anchor

| Lever | Setting |
|---|---|
| backend | `C++ fast` |
| theta warmup | `0` |
| latent warmup | `0` |
| sigmagam warmup | `0` |

Purpose:

- confirm that row `8` still reproduces the short-horizon early failure on current `HEAD`
- preserve a fresh same-day reference for comparison

Expected outcome:

- likely early crash near iter `1`

Decision use:

- if this does **not** fail, the row is no longer a stable microscope row and we should switch to row `16`

### Arm B: Backend-only arm

| Lever | Setting |
|---|---|
| backend | `C++ strict` |
| theta warmup | `0` |
| latent warmup | `0` |
| sigmagam warmup | `0` |

Purpose:

- isolate what moving from `fast` to `strict` buys us while staying on C++

What we learn:

- if this alone survives iter `1`, stricter C++ regularization is the dominant first rescue lever

### Arm C: Theta-only arm

| Lever | Setting |
|---|---|
| backend | `C++ strict` |
| theta warmup | `100` |
| latent warmup | `0` |
| sigmagam warmup | `0` |

Purpose:

- test the user’s current hypothesis directly: maybe the critical thing is mostly theta

What we learn:

- whether theta warmup alone is enough once the C++ backend is already stabilized

### Arm D: Theta + latent arm

| Lever | Setting |
|---|---|
| backend | `C++ strict` |
| theta warmup | `100` |
| latent warmup | `100` (`u_st_pair`) |
| sigmagam warmup | `0` |

Purpose:

- test whether early latent coupling is still part of the failure after theta is protected

### Arm E: Current production-intent arm

| Lever | Setting |
|---|---|
| backend | `C++ strict` |
| theta warmup | `100` |
| latent warmup | `100` (`u_st_pair`) |
| sigmagam warmup | `500` |

Purpose:

- evaluate the current full exDQLM crash-recovery spec under a short but meaningful horizon

This is the current best integrated spec, but it should be reached only after the simpler arms are understood.

### Arm F: Escalation arm

Run only if Arm E still fails after the same failure stage.

| Lever | Setting |
|---|---|
| backend | `C++ strict` |
| theta warmup | `200` |
| latent warmup | `200` (`u_st_pair`) |
| sigmagam warmup | `750` |

Purpose:

- test whether the issue is simply that the current warmups are too short

### Arm G: Fast-backend recovery challenge

Run only if Arms B-E show clear improvement.

| Lever | Setting |
|---|---|
| backend | `C++ fast` |
| theta warmup | best value from earlier arms |
| latent warmup | best value from earlier arms |
| sigmagam warmup | best value from earlier arms |

Purpose:

- determine whether the learned warmup recipe can rescue the fast backend too,
- or whether `strict` mode must remain part of the permanent fix

## Recommended Run Order

Run these one by one:

1. Arm A
2. Arm B
3. Arm C
4. Arm D
5. Arm E
6. Arm F only if needed
7. Arm G only if scientifically useful

This gives the cleanest causal read with minimal wasted compute.

## What To Record For Every Arm

For every arm, freeze and record:

| Artifact | Requirement |
|---|---|
| manifest | one-row manifest only |
| run contract | fully resolved controls |
| diagnostics trace | full per-iteration trace |
| fit object | retained |
| vb-init fit | retained |
| draws | retained |
| summary note | one short markdown interpretation |

Required summary fields:

- run tag
- row id
- backend
- theta warmup
- latent warmup
- sigmagam warmup
- first failure stage
- first failure iteration
- first non-finite component
- whether kept draws were produced
- whether outcome is `PASS`, `WARN`, or `FAIL`

## Success Criteria

We should distinguish three levels of success.

### Level 1

- gets past iteration `1`

### Level 2

- gets past all warmup boundaries and reaches kept draws with finite diagnostics

### Level 3

- ends `PASS` or `WARN`

For this microscope lane, even a move from immediate iter-1 crash to late-burn finite behavior is useful learning.

## Decision Gates

| If this happens | Then do this |
|---|---|
| Arm A does not fail | switch microscope row to `16` |
| Arm B rescues the row | backend is dominant; keep warmup additions secondary |
| Arm B still fails, Arm C rescues | theta freeze is the main extra lever |
| Arm C still fails, Arm D rescues | latent coupling matters after theta |
| Arm D still fails, Arm E rescues | delayed sigmagam movement is necessary |
| Arm E still fails and Arm F rescues | current warmups are too short |
| None of A-F rescue | stop broad reruns; patch code again before any cohort relaunch |

## Resource Discipline

This lane should be intentionally small.

| Item | Policy |
|---|---|
| concurrent workers | `1` |
| row scope | exactly one row |
| chain length | short diagnostic horizon only |
| preserve binaries | yes |
| rerun all `20` rows | no |
| include static gate failures | no |

## Follow-On Rule

Only after the microscope row yields a clear winning arm should we move to:

1. a confirmatory exDQLM row, preferably `16`, and then
2. a DQLM representative row, preferably `6`

This preserves isolation and avoids burning full reruns on unresolved specs.

## Final Recommendation

The next experiment lane should be:

- **one row only**: row `8`
- **fixed stronger VB-init spec**
- **short diagnostic horizon**
- **sequential arm ladder**
- **backend and theta first**
- **latent and sigmagam second**

That is the fastest and most reproducible path to learning what actually matters.

## Execution Checklist

- [ ] freeze row `8` as the microscope target
- [ ] create one-row manifest generator
- [ ] create one-row run contract writer
- [ ] define Arm A through Arm E as separate explicit variants
- [ ] preserve all binaries for every arm
- [ ] run one arm at a time
- [ ] write a one-paragraph interpretation after each arm
- [ ] stop immediately if the row stops being reproducible
- [ ] do not expand to the full crash cohort until one arm clearly wins

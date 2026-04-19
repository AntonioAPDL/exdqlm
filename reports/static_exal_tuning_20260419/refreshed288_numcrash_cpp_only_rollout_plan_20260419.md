# Refreshed288 Numerical-Crash C++-Only Rollout Plan

Date: `2026-04-19`

## Why This Improves The Current Plan

The current single-row microscope plan is directionally good, but it is still too close to thinking of the `20` failed rows as one problem.

They are not one problem.

The frozen numerical-crash cohort actually splits into **three distinct sub-cohorts**:

1. `exdqlm` dynamic MCMC rows with the old `nonfinite_chi` / current early-state crash surface
2. `dqlm` dynamic MCMC rows with the `pre_uts / invalid state before chi update` surface
3. `exdqlm` LDVB-init failures with `ldvb_q_t1 is NA`

That means the best next plan is **not**:

- rerun all `20`,
- or even use one winning row and immediately spread it to all `20`.

The best next plan is:

- microscope one **representative row**,
- keep the experiment fully inside the **C++ backend family**,
- identify the **minimal winning arm**,
- confirm it inside the same sub-cohort,
- only then spread it to the rest of that sub-cohort,
- and keep the other sub-cohorts isolated until we have evidence they should inherit the same spec.

That is the highest-signal, least wasteful, and most reproducible path from the current state.

## What We Have

The current branch already contains the main hardening layers we wanted:

- exDQLM LDVB `s_t` warmup/freeze
- dynamic MCMC `theta` warmup/freeze
- dynamic latent warmup
  - `u_only` for `dqlm`
  - `u_st_pair` for `exdqlm`
- exDQLM MCMC `sigmagam` warmup
- DQLM sigma-only warmup
- GIG `b_vec / chi` floor at `1e-10`
- full diagnostics and run-contract serialization

And we have now frozen the policy:

- **never use the R backend for this lane**
- use **C++ only**
- default experiment backend: `C++ strict`

## What We Want

We want a plan that:

1. learns quickly,
2. does not waste full-chain compute on unresolved specs,
3. is documented well enough that any future rerun is interpretable,
4. can be propagated to related failures only when the evidence says it should,
5. preserves enough artifacts to debug failures rather than just count them.

## Cohort Partition

The frozen `20`-row numerical-crash manifest should be treated as:

| Track | Rows | Meaning | Current recommended action |
|---|---|---|---|
| `track_exdqlm_mcmc_tt5000` | `8,16,24,32,40,48,56,64,72` | main exDQLM `TT5000` dynamic MCMC crash family | microscope first, then confirm, then spread |
| `track_dqlm_mcmc_tt5000` | `6,14,22,30,38,46,54,62,70` | main DQLM `TT5000` dynamic MCMC crash family | hold until exDQLM learning stabilizes |
| `track_exdqlm_init_blocked` | `11,12` | LDVB-init failures (`ldvb_q_t1 is NA`) | separate init track, not part of MCMC rollout |

This partition is the most important improvement over the earlier plan.

## Main Scientific Read

The strongest current read is:

- the dominant live failure appears at the **first theta draw / immediate post-theta validation**
- this happens before the latent GIG step matters
- we still want the GIG floor because it is good protection, but it is not the primary lever
- inside the C++ family, the meaningful questions are now:
  - `fast` vs `strict`
  - no-theta-freeze vs theta-freeze
  - no-latent-freeze vs latent-freeze
  - no-sigmagam-freeze vs sigmagam-freeze

So the best experiment design is a **minimal-arm C++ ladder**, not a broad rerun.

## Fixed Baseline For The Microscope Lane

These settings should remain fixed across microscope arms:

| Control | Value |
|---|---:|
| backend family | `C++ only` |
| VB / VB-init method | `ldvb` |
| VB / VB-init `max_iter` | `800` |
| VB / VB-init `min_iter` | `80` |
| VB / VB-init `tol` | `0.01` |
| VB-init `n.samp` | `5000` |
| exDQLM VB `s_t` warmup | `50` |
| exDQLM VB `s_t` min postwarmup updates | `5` |
| VB `sigmagam` warmup | `50` |
| VB `sigmagam` min postwarmup updates | `5` |
| VB `sigmagam` postwarmup damping | `0.5` for `5` iterations |
| GIG `b_vec / chi` floor | `1e-10` |
| diagnostics trace | `TRUE` |
| retain binaries | `TRUE` |

## Microscope Row

Use **row `8`** as the primary microscope row.

Why:

- exDQLM
- `TT5000`
- true failing row
- representative of the biggest exDQLM MCMC crash family
- already central to the earlier diagnosis

Use **row `16`** as the first confirmatory row if row `8` yields a promising arm.

## Recommended Microscope Horizon

Do not use full production budgets for the microscope lane.

Use:

| Control | Value |
|---|---:|
| `n.burn` | `600` |
| `n.mcmc` | `200` |
| `thin` | `1` |
| `trace.every` | `1` |
| workers | `1` |

This is long enough to learn where the chain dies, and short enough to keep the experiment ladder cheap.

## C++-Only Arm Ladder

### Arm A: Reproduction anchor

| Lever | Setting |
|---|---|
| backend | `C++ fast` |
| theta warmup | `0` |
| latent warmup | `0` |
| sigmagam warmup | `0` |

Purpose:

- confirm same-day reproducibility of the current failure under the least-protected C++ setting

### Arm B: Mode-only arm

| Lever | Setting |
|---|---|
| backend | `C++ strict` |
| theta warmup | `0` |
| latent warmup | `0` |
| sigmagam warmup | `0` |

Purpose:

- isolate what `strict` mode alone buys us

### Arm C: Theta-first arm

| Lever | Setting |
|---|---|
| backend | `C++ strict` |
| theta warmup | `100` |
| latent warmup | `0` |
| sigmagam warmup | `0` |

Purpose:

- test the user’s theta hypothesis directly

### Arm D: Theta + latent arm

| Lever | Setting |
|---|---|
| backend | `C++ strict` |
| theta warmup | `100` |
| latent warmup | `100` |
| sigmagam warmup | `0` |

Purpose:

- test whether early latent coupling still matters once theta is protected

### Arm E: Current best integrated arm

| Lever | Setting |
|---|---|
| backend | `C++ strict` |
| theta warmup | `100` |
| latent warmup | `100` |
| sigmagam warmup | `500` |

Purpose:

- evaluate the full current production-intent exDQLM spec

### Arm F: Escalation arm

Use only if Arm E still fails at the same stage.

| Lever | Setting |
|---|---|
| backend | `C++ strict` |
| theta warmup | `200` |
| latent warmup | `200` |
| sigmagam warmup | `750` |

Purpose:

- test whether the existing warmup lengths are simply too short

### Arm G: Fast recovery challenge

Use only if one of Arms B-F clearly improves the row.

| Lever | Setting |
|---|---|
| backend | `C++ fast` |
| theta warmup | winning value |
| latent warmup | winning value |
| sigmagam warmup | winning value |

Purpose:

- determine whether the learned recipe rescues `fast`, or whether `strict` must remain part of the permanent fix

## Minimal-Winning-Arm Principle

This is the main rollout rule:

> We do **not** propagate the most complicated arm.  
> We propagate the **least complicated arm that wins**.

That keeps the eventual relaunch:

- easier to interpret,
- cheaper,
- and less overfit to one row.

## Success Levels

| Level | Meaning |
|---|---|
| `L1` | gets past iter `1` |
| `L2` | gets past all active warmup boundaries |
| `L3` | reaches kept draws with finite diagnostics |
| `L4` | ends `PASS` or `WARN` |

For the microscope lane, even an `L2` result is useful learning.

## Propagation Logic

### Stage 1: microscope

Run row `8` through Arms A-F sequentially.

Stop rules:

- if no arm improves over Arm A, do not spread anything
- patch code again before any broader relaunch

### Stage 2: confirmatory exDQLM row

If one arm wins on row `8`, run the **same arm unchanged** on row `16`.

Why row `16`:

- same sub-cohort
- same model
- same `TT5000`
- different `tau`

If row `16` does not confirm, stop broad rollout.

### Stage 3: exDQLM spread

If rows `8` and `16` both confirm the same arm, spread that arm to:

- `24,32,40,48,56,64,72`

These are the remaining exDQLM `TT5000` MCMC crash rows.

### Stage 4: DQLM transfer

Only after exDQLM spread shows stable value should we test transfer to DQLM:

- representative row: `6`
- confirmatory row: `14`
- then remaining DQLM rows if those confirm

Important:

- DQLM does **not** inherit exDQLM `sigmagam` logic automatically
- DQLM’s analogue is:
  - theta warmup
  - `u_only` latent warmup
  - sigma-only warmup

### Stage 5: init-blocked rows

Rows `11` and `12` are **not** part of the MCMC rollout.

They must remain a separate init-blocked track.

They should only be revisited after:

- the exDQLM microscope lane identifies a clearly improved exDQLM init/MCMC combination,
- or we make a direct LDVB init patch.

## Artifact Requirements

For every arm and every spread stage, keep:

| Artifact | Requirement |
|---|---|
| one-row or subgroup manifest | frozen |
| run contract | fully resolved |
| method summary | saved |
| phase summary | saved |
| fit `.rds` | retained |
| vb-init `.rds` | retained |
| draws `.rds` | retained |
| short markdown interpretation | written immediately after run |

Required interpretation fields:

- row set
- backend mode
- theta warmup
- latent mode and warmup
- sigmagam or sigma warmup
- first failure stage
- first failure iteration
- whether kept draws were reached
- terminal outcome
- whether this arm should be promoted, held, or abandoned

## Decision Matrix

| Result | Action |
|---|---|
| Arm B wins | backend mode is the main lever; keep later arms optional |
| Arm C wins over B | theta warmup is necessary |
| Arm D wins over C | latent warmup adds value |
| Arm E wins over D | delayed sigmagam movement adds value |
| Arm F only wins | current warmups are too short; use longer schedule in later rollout |
| Arm G also wins | `fast` can be retained |
| Arm G fails but strict wins | keep `strict` as the permanent crash-recovery backend |

## Final Recommended Implementation Sequence

1. freeze the three-track cohort partition
2. build one-row microscope manifests for row `8`
3. run Arms A-F sequentially
4. choose the **minimal winning arm**
5. confirm on row `16`
6. spread only to the remaining exDQLM `TT5000` rows
7. test transfer to DQLM on row `6`
8. confirm on row `14`
9. only then spread to the remaining DQLM rows
10. keep `11` and `12` out until the init-blocked lane is explicitly revisited

## Implementation Checklist

- [ ] freeze the cohort partition
- [ ] create one-row manifests for microscope row `8`
- [ ] create one contract per arm
- [ ] run Arms A-F with one worker
- [ ] write one interpretation note per arm
- [ ] choose minimal winning arm
- [ ] confirm on row `16`
- [ ] if confirmed, spread to the remaining exDQLM `TT5000` rows
- [ ] only after that, test DQLM transfer on row `6`
- [ ] confirm on row `14`
- [ ] keep rows `11` and `12` isolated until explicitly reopened

## Bottom Line

The best next move is not “rerun all `20` with more warmup.”

The best next move is:

- **C++ only**
- **one microscope row**
- **minimal arm ladder**
- **promote only the least complicated winning arm**
- **spread only within the matching sub-cohort**

That is the most rigorous, efficient, and reproducible plan we have so far.

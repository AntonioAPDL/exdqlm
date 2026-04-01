# PLAN: QDESN Validation Phase 9 Family Replication Audit (2026-04-01)

Date: 2026-04-01  
Branch: `feature/qdesn-mcmc-alternative`  
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1) Purpose

Run the next overnight program as a replication-first audit on the full fixed 6-root harness.

This wave is designed around the main Phase-8 lesson:

- a focused local winner can still fail the full-6 confirmation step;
- the exact `R61` reference baseline itself did not reproduce its earlier `2 FAIL` result;
- the next decision must be made at the family level, not from a single profile instance.

So the goal of Phase 9 is:

1. quantify rerun variability on the still-plausible recipes;
2. identify which recipe family is actually stable on the branch-facing full-6 harness;
3. choose the next local repair direction from replicated evidence, not one-off rankings.

## 2) Current Reference State

Phase-7 stability outcome established the reference baseline conceptually:

- reference recipe: exact `R61/R44` settings
- best prior stable read: `2 FAIL`, `0` sentinel FAIL

Phase-8 outcome changed the next-step discipline:

- `R84` won the focused 5-root screen with `2 FAIL`, `0` sentinel FAIL;
- `R84` then failed the full-6 confirmation with `6 FAIL`, `2` sentinel FAIL;
- the `R61` anchor family reran at `5 FAIL`, `1` sentinel FAIL in the same wave.

Interpretation:

- Phase 8 did not produce a promotable new baseline;
- Phase 8 showed the current full-6 surface has meaningful rerun variability;
- baseline promotion should now require family-level replicated evidence.

## 3) What This Wave Will Not Redo

Explicitly out of scope:

- reopening broad local search families before replication is understood;
- rerunning weak Phase-8 descendants such as `R83`, `R85`, `R86`, `R87`, `R88`, `R89`, `R90`, `R91`, `R92`, or `R93` as lead ideas;
- replaying QR-only, bridge-only, conditioning-only, or older transformed-sigma families;
- treating a single screen winner as enough evidence for a new baseline.

## 4) Candidate Families

### Family A: exact `R61` reference baseline

Purpose:

- measure how stable the current reference recipe really is on repeated full-6 reruns.

Included profiles:

- `R100_r61_rep1`
- `R101_r61_rep2`
- `R102_r61_rep3`

### Family B: exact `R84` rhs-local winner

Purpose:

- test whether the best Phase-8 local rhs signal can reproduce on full-6 when repeated.

Included profiles:

- `R110_r84_rep1`
- `R111_r84_rep2`
- `R112_r84_rep3`

### Family C: exact `R68` clean ridge signal

Purpose:

- preserve the best zero-sentinel ridge-local signal from Phase 7.

Included profiles:

- `R120_r68_rep1`
- `R121_r68_rep2`
- `R122_r68_rep3`

### Family D: exact `R65` stronger ridge-chain signal

Purpose:

- test the stronger ridge-chain / step-out pattern that looked competitive before stability filtering.

Included profiles:

- `R130_r65_rep1`
- `R131_r65_rep2`
- `R132_r65_rep3`

## 5) Why These Families

| family | why it is included | why it is still plausible |
|---|---|---|
| `R61` | current branch reference | best prior stable result |
| `R84` | strongest Phase-8 local winner | showed the cleanest rhs-local improvement on the focused screen |
| `R68` | clean ridge signal | best zero-sentinel ridge-local signal from Phase 7 |
| `R65` | stronger ridge-chain signal | meaningful ridge improvement that deserves replicated full-6 evidence |

What is intentionally excluded:

- weak rhs-only descendants from Phase 7 and Phase 8;
- overly expensive combined descendants;
- any family already shown to be locally or operationally unhelpful.

## 6) Schedule

This is a single-stage replication audit on the fixed 6-root harness.

Execution order:

1. `R61` family (`3` exact reruns)
2. `R84` family (`3` exact reruns)
3. `R68` family (`3` exact reruns)
4. `R65` family (`3` exact reruns)

Total campaigns:

- `12` full-6 campaigns

## 7) Resource Plan

Execution plan:

- one-stage sequential screen
- per-profile campaigns use parallel root execution
- `campaign_workers = 4`
- `threads_per_worker = 1`
- `profile_timeout_minutes = 180`
- plots off

Why this is efficient:

- every run is on the branch-facing fixed 6-root harness, so we do not waste time on another narrow local screen first;
- only `4` still-plausible recipe families are included;
- each family is rerun `3` times, which is enough to estimate directionality without exploding compute.

## 8) Decision Rules

Primary review file:

- `family_rank_summary.csv`

Secondary review files:

- `profile_rank_summary.csv`
- `phase35_micro_pilot_summary.csv`
- `phase35_micro_pilot_diag_shift.csv`

Promotion criteria for a family:

1. strong median fail count relative to the other families;
2. stable sentinel behavior across reruns;
3. acceptable runtime inflation;
4. no operational regressions.

Practical interpretation:

- promotable family:
  - median `total_fail_n <= 3`
  - median `sentinel_fail_n = 0`
  - at least `2/3` reruns with `total_fail_n <= 3`
- provisional local lead:
  - best median fail count, but unstable sentinel behavior
- no stable winner:
  - overlapping family-level results or persistent sentinel instability

## 9) Morning Review

Open these first:

1. `reports/.../summary/screen_results.md`
2. `reports/.../tables/family_rank_summary.csv`
3. `reports/.../tables/profile_rank_summary.csv`
4. `reports/.../tables/profile_execution_status.csv`

Questions to answer:

1. does `R61` actually reproduce as the best family;
2. does `R84` hold any of its local Phase-8 advantage on repeated full-6 reruns;
3. which ridge family is more stable: `R68` or `R65`;
4. is the next move rhs-local, ridge-local, or simply more replication before tuning again.

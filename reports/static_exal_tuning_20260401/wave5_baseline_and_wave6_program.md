# Static exAL Tuning: Wave-5 Baseline and Wave-6 Program

Date: 2026-04-01

Follow-on state and the focused rerun decision are now recorded in:

- `reports/static_exal_tuning_20260401/c060_focus_rerun_and_wave6_closeout.md`
- `reports/static_exal_tuning_20260401/transfer_reassessment_and_wave7_program.md`

## Status Note

This document is now a historical planning record for the wave-5 to wave-6 handoff.

The current baseline reassessment is no longer the original wave-6 program. After the stopped focused rerun exposed an exact-runner transfer mismatch, the active forward plan moved to the wave-7 transfer-validation program:

- `reports/static_exal_tuning_20260401/transfer_reassessment_and_wave7_program.md`

## Current Baseline

The current production anchor is still:

- `JF2_sub2_p007_s100`

with:

- `gamma_substeps = 2`
- `p_global_eta_jump = 0.07`
- `global_eta_jump_scale = 1.0`
- `rhsns_lambda_power = 1.0`

This remains the latest completed full `mix12` winner:

| candidate_id | pass_n | warn_n | fail_n | healthy_n | gate_points | composite |
|---|---:|---:|---:|---:|---:|---:|
| `JF2_sub2_p007_s100` | 7 | 5 | 0 | 12 | 19 | 9.447503 |
| `GJ1_sub2_jump005` | 3 | 9 | 0 | 12 | 15 | 8.848194 |

## What Improved

### Crash behavior

- the original static `exal` `tau=0.25` crash band is no longer the main blocker
- the search is now focused on chain quality, not runtime survival

### Quality behavior

- `JF2` clearly improved over the old `GJ1` anchor
- wave-5 `crash6` confirmed that two nearby families are still promising:
  - `F090_sub2_s100`
  - `SUB3_070_100`

Wave-5 completed `crash6` leaders:

| candidate_id | pass_n | warn_n | fail_n | healthy_n | gate_points | composite | read |
|---|---:|---:|---:|---:|---:|---:|---|
| `F090_sub2_s100` | 4 | 1 | 1 | 5 | 9 | 6.254966 | best `substeps=2` frontier result |
| `SUB3_070_100` | 4 | 1 | 1 | 5 | 9 | 6.436273 | best `substeps=3` refinement |
| `F060_sub2_s100` | 2 | 2 | 2 | 4 | 6 | 6.457052 | viable but weaker |
| `C060_110_sub2` | 2 | 2 | 2 | 4 | 6 | 5.165886 | viable but weaker |
| `S110_sub2_p070` | 2 | 2 | 2 | 4 | 6 | 5.014951 | viable but weaker |

## What Still Fails

- the remaining problem is still static `exal` MCMC quality on the hard quality rows
- we still need a candidate that converts more hard rows from `WARN` to `PASS` without reintroducing `FAIL`
- dynamic row `15` remains a separate current-HEAD dynamic quality issue and should not drive the static search

## What Worked Best

The strongest ideas so far are:

1. keep the shared-core crash fix in place
2. keep `rhsns_lambda_power = 1.0`
3. work in the local jump-geometry neighborhood around `JF2`
4. allow slightly higher jump frequency when paired with controlled scale
5. keep `substeps = 3` only in the narrow `SUB3_070_100` neighborhood

## What Clearly Did Not Work

Do not reopen:

- lambda tempering families
- pure no-jump or effectively no-jump families
- very large jump scales
- high-frequency plus small-scale `substeps = 3` variants
- `S090_sub2_p070`
- `C080_090_sub2`
- `SUB3_080_090`
- already dominated wave-5 families that are further from the winners than the planned wave-6 candidates

## Highest-Value Remaining Directions

### Direction A: high-frequency `substeps = 2` refinement

Why:

- `F090_sub2_s100` is the strongest completed wave-5 `crash6` result
- we still do not know whether the quality frontier peaks just below, at, or slightly above `0.09`
- we also have not yet tested gentle scale adjustments around that point

### Direction B: narrow `substeps = 3` refinement

Why:

- `SUB3_070_100` is the only `substeps = 3` variant that remained genuinely competitive
- the failed `SUB3_080_090` path tells us not to broaden this family indiscriminately
- the right follow-up is a very small local refinement around the working point

### Direction C: mild scale widening around the current anchor

Why:

- `S110_sub2_p070` was not a winner, but it showed enough viability to justify one gentler scale step
- this gives us one low-risk control path in case the high-frequency frontier does not convert enough `WARN` rows

## Wave-6 Program

Wave-6 is designed as a broad but disciplined local search. It intentionally excludes families we already understand to be weak.

### Candidate schedule

| candidate_id | substeps | p_jump | jump_scale | role | why included |
|---|---:|---:|---:|---|---|
| `F085_sub2_s100` | 2 | 0.085 | 1.00 | bridge | tests whether most gains arrive before `0.09` |
| `F090_sub2_s095` | 2 | 0.090 | 0.95 | refine | tests whether `F090` benefits from slightly tighter global jumps |
| `F090_sub2_s105` | 2 | 0.090 | 1.05 | refine | tests whether `F090` benefits from slightly wider global jumps |
| `F095_sub2_s095` | 2 | 0.095 | 0.95 | frontier | probes the upper edge with tempered scale |
| `F095_sub2_s100` | 2 | 0.095 | 1.00 | frontier | probes whether the quality frontier extends beyond `0.09` |
| `S105_sub2_p070` | 2 | 0.070 | 1.05 | anchor-local | gentler version of the mid-tier `S110` line |
| `B085_105_sub2` | 2 | 0.085 | 1.05 | hybrid | tests whether moderate frequency and moderate widening work together |
| `SUB3_070_105` | 3 | 0.070 | 1.05 | sub3 refine | simplest local refinement of `SUB3_070_100` |
| `SUB3_075_100` | 3 | 0.075 | 1.00 | sub3 frontier | tests a small frequency increase at the safe scale |
| `SUB3_075_105` | 3 | 0.075 | 1.05 | sub3 frontier | tests the same increase with a gentle scale expansion |

### Stage plan

| Stage | Rows | Purpose | top_k |
|---|---|---|---:|
| `crash6` | `83,107,131,165,213,261` | verify no crash regression | 6 |
| `guard6` | `91,99,115,197,245,277` | screen the hardest quality rows early | 4 |
| `quality8` | `91,99,115,197,245,277,181,229` | broader quality ranking | 3 |
| `mix12` | `75,99,123,91,115,139,149,197,245,181,229,277` | final same-seed decision | all survivors |

### Promotion rules

#### `crash6 -> guard6`

- must be `crash_safe = TRUE`
- rank by:
  1. fewer `FAIL`
  2. more gate points
  3. more healthy rows
  4. better composite

#### `guard6 -> quality8`

- prefer no `FAIL` on rows `99`, `115`, `197`, `245`, `277`
- rank by:
  1. fewer `FAIL`
  2. more gate points
  3. more healthy rows
  4. better composite

#### `quality8 -> mix12`

- same guard rule as `guard6`
- keep only the strongest three candidates

#### Final selection rule

Use the relaxed production rule:

1. `FAIL` is the primary blocker
2. `WARN` is acceptable
3. a candidate may replace `JF2` only if it is `crash_safe`, finishes `mix12` with `0 FAIL`, and beats `JF2` on gate points, healthy rows, or composite
4. if no challenger beats `JF2`, keep `JF2` and stop tuning

## Compute Plan

- server reports `64` logical cores via `nproc`
- wave-6 uses single-threaded workers and a default parallel stage width of `10`
- this is intentionally below the hardware ceiling to reduce contention risk and keep the matrix stable
- wave-6 is queued behind the currently running wave-5 controller rather than launched concurrently

## Operational State

At the time this report was written:

- wave-5 `smoke` was complete
- wave-5 `crash6` was complete after dropping `SUB3_080_090`
- wave-5 `quality8` was running
- wave-6 tooling was prepared and queued to launch automatically after wave-5 finishes

## Decision Framework From Here

1. let wave-5 finish
2. compare any wave-5 challenger against `JF2`
3. let queued wave-6 run automatically afterward
4. if wave-6 still does not beat `JF2` under the relaxed `0 FAIL` rule, stop tuning and use `JF2_sub2_p007_s100` for the focused `72`-row static rerun

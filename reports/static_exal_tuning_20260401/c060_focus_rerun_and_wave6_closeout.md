# Static exAL Tuning: C060 Baseline, Wave-6 Closeout, and Focused Rerun Plan

Date: 2026-04-01

Follow-on state from the earlier tuning reports:

- `reports/static_exal_tuning_20260331/wave4_finish_and_wave5_overnight_plan.md`
- `reports/static_exal_tuning_20260401/wave5_baseline_and_wave6_program.md`
- `reports/static_exal_tuning_20260401/transfer_reassessment_and_wave7_program.md`

## Status Note

This document is no longer the current execution guide.

It remains the historical record of the first `C060_110_sub2` promotion and the initial focused-rerun decision, but the focused rerun was then stopped after it exposed an exact-runner transfer mismatch. The current baseline reassessment and next-stage plan now live in:

- `reports/static_exal_tuning_20260401/transfer_reassessment_and_wave7_program.md`

## Current Baseline

The best completed static `exal` tuning baseline is now:

- `C060_110_sub2`

with:

- `gamma_substeps = 2`
- `p_global_eta_jump = 0.06`
- `global_eta_jump_scale = 1.10`
- `rhsns_lambda_power = 1.0`

Wave-5 final decision:

| candidate_id | pass_n | warn_n | fail_n | healthy_n | gate_points | composite |
|---|---:|---:|---:|---:|---:|---:|
| `C060_110_sub2` | 10 | 2 | 0 | 12 | 22 | 9.885716 |
| `JF2_sub2_p007_s100` | 7 | 5 | 0 | 12 | 19 | 9.447503 |

Decision artifact:

- `/home/jaguir26/local/src/exdqlm__wt__debug-static-exal-shared-core-20260331/tools/merge_reports/LOCAL_static_exal_wave5_final_decision_20260331.md`

## Main Takeaways

### What improved

- the effective production baseline improved from `JF2_sub2_p007_s100` to `C060_110_sub2`
- the best completed `mix12` result improved from `7 PASS / 5 WARN / 0 FAIL` to `10 PASS / 2 WARN / 0 FAIL`
- the static `exal` search is now firmly in quality optimization territory rather than crash containment
- the focused rerun gate is now satisfied under the relaxed production rule because the best completed baseline has `0 FAIL`

### What still fails

- dynamic row `15` remains a separate current-`HEAD` dynamic quality failure and is not resolved by the static tuning work
- wave-6 did not produce a completed new winner before it hit a pathological `substeps = 3` lane
- the remaining uncertainty is now optional upside, not baseline authorization risk

### What worked best

The strongest surviving ideas were:

1. keep the shared-core crash fix in place
2. keep `rhsns_lambda_power = 1.0`
3. keep `gamma_substeps = 2`
4. tune in the moderate jump-geometry neighborhood rather than pushing the aggressive frontier
5. use small, disciplined coupled frequency-scale changes instead of broad family jumps

### What clearly did not work

Do not reopen:

- lambda tempering families
- no-jump or effectively no-jump families
- aggressive high-frequency frontier variants that overshoot hard rows
- oversized jump scales
- the pathological `substeps = 3` families:
  - `SUB3_080_090`
  - `SUB3_075_100`

### Highest-value directions now

1. move the validation study forward on the focused static rerun under `C060_110_sub2`
2. keep dynamic row `15` explicitly separate from the static rerun decision
3. only reopen tuning after the focused rerun if there is still a concentrated residual fail band
4. if a post-rerun tuning cycle is needed, keep it narrow around the `C060 / F075 / F080` neighborhood and do not reopen dominated families

## Wave-6 Closeout

Wave-6 was exploratory follow-up research, not gating work, and it was stopped after a nonproductive `crash6` bottleneck.

Operational outcome:

| item | state |
|---|---|
| wave-6 controller | stopped manually |
| last completed critical wave | wave-5 |
| wave-6 stage at stop | `crash6` |
| completed wave-6 crash6 candidates | `9 / 10` |
| dropped candidate | `SUB3_075_100` |

Why the candidate was dropped:

| signal | observation |
|---|---|
| row | `165` |
| last telemetry milestone | burn-in `550` |
| last log milestone | burn-in `550` |
| sigma signal | extremely large and effectively flat |
| acceptance signal | decayed to `0.0210` |
| interpretation | pathological slow path; not worth holding the project open |

This means wave-6 did not displace the completed `C060_110_sub2` winner and should be treated as optional, unfinished research rather than a blocker.

## Focused Static Rerun Scope

The focused rerun scope is:

- `72` total rows
- all static `exal` MCMC rows that are still scientifically tied to the old static baseline

Breakdown:

| slice | rows |
|---|---:|
| current static RHS-NS `exal` MCMC | 54 |
| legacy static RHS `exal` MCMC | 18 |
| total | 72 |

Distribution:

| axis | counts |
|---|---|
| root kind | `static_paper = 18`, `static_shrink = 54` |
| family | `gausmix = 24`, `laplace = 24`, `normal = 24` |
| tau | `0p05 = 24`, `0p25 = 24`, `0p95 = 24` |

Dynamic row `15` is not included in this rerun package because it is a separate dynamic-quality issue, not static rerun debt.

## Execution Path

The focused rerun is intentionally executed from the debug worktree, not directly from the validation worktree package.

Reason:

- the tuned static `exal` baseline is currently applied through debug execution hooks in the debug worktree package
- the validation worktree remains the tracked reporting branch and stays package-clean
- the rerun manifest still points at the validation-study data and result roots so the scientific scope stays anchored to the validation campaign

In practice:

1. prepare the `72`-row manifest from the validation-study current + legacy manifests
2. clone each source `run_config.rds` to a tuned provenance copy
3. launch the rerun from the debug worktree with the `C060_110_sub2` execution overrides
4. write candidate fit outputs to fresh tagged paths
5. use the resulting health summary to decide whether any post-rerun tuning is still worth compute

## Current Decision

The project should now proceed on this basis:

1. treat `C060_110_sub2` as the active static `exal` production baseline
2. stop treating wave-6 as critical path
3. run the focused `72`-row static `exal` MCMC rerun next
4. keep dynamic row `15` as a separate follow-up issue

That is the shortest technically credible path from the current tuning state into the actual validation closeout lane.

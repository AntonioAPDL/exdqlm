# Static exAL Tuning: Wave-7 Closeout and Wave-8 Exact-Runner Program

Date: 2026-04-03

Current tracked context:

- `reports/static_exal_tuning_20260331/wave4_finish_and_wave5_overnight_plan.md`
- `reports/static_exal_tuning_20260401/wave5_baseline_and_wave6_program.md`
- `reports/static_exal_tuning_20260401/c060_focus_rerun_and_wave6_closeout.md`
- `reports/static_exal_tuning_20260401/transfer_reassessment_and_wave7_program.md`

## Wave-7 Final Decision

Wave-7 (exact-runner transfer program) completed and produced a new best transfer candidate:

- `F080_sub2_s100`

Final decision artifact:

- `/home/jaguir26/local/src/exdqlm__wt__debug-static-exal-shared-core-20260331/tools/merge_reports/LOCAL_static_exal_wave7_transfer_final_decision_20260401.md`

Key result:

| candidate_id | pass_n | warn_n | fail_n | healthy_n | exact_ready |
|---|---:|---:|---:|---:|---|
| `F080_sub2_s100` | 7 | 4 | 1 | 11 | `FALSE` |

Interpretation:

- `F080_sub2_s100` is now the best completed exact-runner transfer baseline.
- It does **not** satisfy the strict `0 FAIL` exact-ready gate.
- The exact-runner parity question remains unresolved.

## Main Takeaways

### What improved

- wave-7 finished cleanly and produced a stronger exact-runner transfer leader
- `F080_sub2_s100` outperformed the raw `C060_110_sub2` reference under the real validation runner
- the remaining uncertainty is now narrow and well scoped to the `F080` neighborhood

### What still fails

- no candidate achieved `0 FAIL` in `mix12_transfer`
- the exact-runner baseline is improved but not yet production-ready

### What worked best

1. transfer candidates in the `F080` neighborhood
2. `substeps = 2` geometry without lambda tempering
3. moderate jump frequencies, not the aggressive frontier

### What clearly did not work

- the raw `C060` reference as a transfer baseline
- aggressive `F090 / F095` frontier families
- any lambda tempering or no-jump families

### Highest-value directions now

1. tighten and widen the `F080` scale slightly to find a `0 FAIL` transfer baseline
2. probe a small frequency band around `F080` (between `F075` and `F085`)
3. avoid reopening any dominated families

## Wave-8 Program (Exact-Runner Transfer)

Wave-8 is a disciplined, exact-runner transfer program focused only on the `F080` neighborhood.

### Candidate schedule

| candidate_id | gamma_substeps | p_global_eta_jump | global_eta_jump_scale | family | why included |
|---|---:|---:|---:|---|---|
| `F080_sub2_s100_ref` | 2 | 0.080 | 1.00 | `f080_reference` | best transfer baseline from wave-7 |
| `F080_sub2_s095` | 2 | 0.080 | 0.95 | `f080_scale` | tighten scale to reduce drift |
| `F080_sub2_s105` | 2 | 0.080 | 1.05 | `f080_scale` | widen scale to reduce stickiness |
| `F075_sub2_s095` | 2 | 0.075 | 0.95 | `f075_scale` | lower frequency + tighter scale |
| `F075_sub2_s105` | 2 | 0.075 | 1.05 | `f075_scale` | lower frequency + wider scale |
| `F085_sub2_s095` | 2 | 0.085 | 0.95 | `f085_scale` | upper edge with tempered scale |
| `F085_sub2_s105` | 2 | 0.085 | 1.05 | `f085_scale` | upper edge with wider scale |
| `F0825_sub2_s100` | 2 | 0.0825 | 1.00 | `f0825_center` | midpoint between `F080` and `F085` |

### Stage plan

| stage | rows | purpose | top_k |
|---|---|---|---:|
| `transfer6` | `83,107,115,119,197,245` | exact-runner bridge check | 4 |
| `guard8` | `83,99,107,115,119,197,245,277` | hard guard check | 3 |
| `mix12_transfer` | `75,83,91,99,107,115,119,139,149,197,245,277` | final exact-runner decision | all survivors |

### Promotion rules

#### `transfer6 -> guard8`

- must be crash-safe
- rank by:
  1. fewer `FAIL`
  2. `row115` not `FAIL`
  3. `row245` not `FAIL`
  4. more gate points
  5. more healthy rows
  6. better composite

#### `guard8 -> mix12_transfer`

- prefer candidates with no `FAIL` on `99`, `115`, `197`, `245`, `277`
- rank by:
  1. fewer `FAIL`
  2. better guard quality
  3. more gate points
  4. more healthy rows
  5. better composite

#### Final selection rule

- `F080_sub2_s100_ref` is the exact-runner reference
- `0 FAIL` is the primary requirement
- a candidate may replace the reference if it is exact-ready and beats the reference on gate points, healthy rows, or composite

## Compute Plan

- server capacity: `64` logical cores
- wave-8 uses `6` parallel lanes
- exact-runner semantics only (no stage-budget runner)
- the plan is optimized for learning per unit of compute, not breadth

## Current Decision Framework

1. keep `F080_sub2_s100` as the best exact-runner baseline so far
2. do not relaunch the full `72`-row static rerun until wave-8 produces a `0 FAIL` transfer winner
3. if wave-8 still fails to yield `0 FAIL`, we will pause and re-evaluate the acceptance rule with the stakeholder group

## Status Update (2026-04-03)

- wave-8 launcher and scoring scripts are now implemented on the validation
  branch:
  - `tools/merge_reports/LOCAL_static_exal_wave8_transfer_prepare_20260403.R`
  - `tools/merge_reports/LOCAL_static_exal_wave8_transfer_score_20260403.R`
  - `tools/merge_reports/LOCAL_static_exal_wave8_transfer_launch_20260403.sh`
- wave-8 prepare-only validation should be run before launch to confirm the
  schedule CSVs are generated as expected

## Closeout Note

Wave-8 has now completed on the validation branch. The closeout, residual
FAIL analysis, and fail-only next-step program live in:

- `reports/static_exal_tuning_20260403/wave8_closeout_and_fail_only_repair_program.md`
- `reports/static_exal_tuning_20260403/PROMPT__wave8_fail_only_repair_20260403.md`
- `reports/static_exal_tuning_20260403/fail_only_bridge_results_20260403.md`

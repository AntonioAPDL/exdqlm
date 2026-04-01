# Static exAL Tuning: Transfer Reassessment and Wave-7 Exact-Runner Program

Date: 2026-04-01

Current tracked context:

- `reports/static_exal_tuning_20260331/wave4_finish_and_wave5_overnight_plan.md`
- `reports/static_exal_tuning_20260401/wave5_baseline_and_wave6_program.md`
- `reports/static_exal_tuning_20260401/c060_focus_rerun_and_wave6_closeout.md`

## Current Validation State

The best fully completed tuning result is still:

- `C060_110_sub2`

with:

- `gamma_substeps = 2`
- `p_global_eta_jump = 0.06`
- `global_eta_jump_scale = 1.10`
- `rhsns_lambda_power = 1.0`

Wave-5 completed `mix12` evidence:

| candidate_id | pass_n | warn_n | fail_n | healthy_n | gate_points | composite |
|---|---:|---:|---:|---:|---:|---:|
| `C060_110_sub2` | 10 | 2 | 0 | 12 | 22 | 9.885716 |
| `F080_sub2_s100` | 8 | 4 | 0 | 12 | 20 | 9.411556 |
| `F060_sub2_s100` | 8 | 4 | 0 | 12 | 20 | 9.369537 |
| `F075_sub2_s100` | 7 | 5 | 0 | 12 | 19 | 9.767500 |
| `JF2_sub2_p007_s100` | 7 | 5 | 0 | 12 | 19 | 9.447503 |

Wave-6 did not produce a completed winner that displaced `C060_110_sub2`. The strongest completed partial `crash6` readouts were:

| candidate_id | completed_rows | pass_n | warn_n | fail_n | healthy_n | read |
|---|---:|---:|---:|---:|---:|---|
| `SUB3_075_105` | 6 | 4 | 1 | 1 | 5 | strongest completed `substeps = 3` hedge |
| `SUB3_070_105` | 6 | 3 | 2 | 1 | 5 | second-best completed `substeps = 3` hedge |
| `F090_sub2_s105` | 6 | 2 | 3 | 1 | 5 | only credible `F090` survivor |
| `SUB3_075_100` | 3 | 1 | 1 | 1 | 2 | unfinished and operationally pathological |

## Main Reassessment

### What improved

- the static `exal` crash band remains fixed
- the best completed tuning baseline improved from `JF2_sub2_p007_s100` to `C060_110_sub2`
- the best completed `mix12` result improved from `7 PASS / 5 WARN / 0 FAIL` to `10 PASS / 2 WARN / 0 FAIL`
- the search space is now narrow and well understood; weak families have been ruled out

### What still fails

- exact transfer from the tuning matrix into the real validation rerun path is not yet proven
- the focused `72`-row static rerun was launched and then stopped after `4` completed rows because the rerun path exposed a parity problem
- dynamic row `15` remains a separate current-`HEAD` dynamic quality issue and is still not part of the static solution

### Transfer-risk evidence

The focused rerun stop was the correct decision because it exposed a reproducibility gap:

| row_id | source | gate_overall | healthy | n_burn | n_mcmc | read |
|---|---|---|---|---:|---:|---|
| `115` | wave-5 `C060` mix12 | `PASS` | `TRUE` | `3000` | `8000` | completed tuning evidence |
| `115` | focused rerun under `C060` | `FAIL` | `FALSE` | `2000` | `1000` | exact validation rerun path mismatch |
| `83` | focused rerun under `C060` | `WARN` | `TRUE` | `3000` | `8000` | partial bridge evidence |
| `107` | focused rerun under `C060` | `PASS` | `TRUE` | `3000` | `8000` | partial bridge evidence |
| `119` | focused rerun under `C060` | `WARN` | `TRUE` | `2000` | `1000` | partial bridge evidence |

Interpretation:

- `C060_110_sub2` remains the best completed tuning winner
- it is not yet a production rerun baseline
- the highest-value next step is to resolve exact-runner transfer parity before any broad relaunch

## What Worked Best

The strongest ideas so far are:

1. keep the shared-core crash fix in place
2. keep `rhsns_lambda_power = 1.0`
3. stay in the moderate coupled jump-geometry neighborhood
4. prefer `substeps = 2` as the main line
5. keep `substeps = 3` only as a narrow hedge in the `070/105` to `075/105` neighborhood

## What Clearly Did Not Work

Do not reopen:

- lambda tempering families
- no-jump or effectively no-jump families
- oversized jump scales
- aggressive `F090 / F095` frontier families as the main line
- pathological `substeps = 3` variants:
  - `SUB3_080_090`
  - `SUB3_075_100`
- broad reruns before exact-runner parity is established

## Highest-Value Directions

1. exact-runner transfer validation around `C060_110_sub2`
2. nearby coupled-geometry neighbors that might transfer more robustly:
   - `C055_110_sub2`
   - `C065_110_sub2`
   - `C060_105_sub2`
   - `C060_115_sub2`
3. strong completed simpler controls:
   - `F075_sub2_s100`
   - `F080_sub2_s100`
4. only one narrow `substeps = 3` hedge family:
   - `SUB3_070_105`
   - `SUB3_075_105`

## Wave-7 Program

Wave-7 is an exact-runner transfer-validation program. It reuses the real validation runner semantics and evaluates only the remaining high-value candidates.

### Candidate schedule

| candidate_id | gamma_substeps | p_global_eta_jump | global_eta_jump_scale | family | why included |
|---|---:|---:|---:|---|---|
| `C060_110_sub2_ref` | 2 | 0.060 | 1.10 | `bridge_reference` | current best completed winner; required reference control |
| `C055_110_sub2` | 2 | 0.055 | 1.10 | `coupled_geometry` | tests whether slightly less frequent global jumps improve transfer stability |
| `C065_110_sub2` | 2 | 0.065 | 1.10 | `coupled_geometry` | tests whether `C060` under-jumps on the bridge rows |
| `C060_105_sub2` | 2 | 0.060 | 1.05 | `coupled_geometry` | tightens scale slightly around `C060` to reduce drift |
| `C060_115_sub2` | 2 | 0.060 | 1.15 | `coupled_geometry` | widens scale slightly around `C060` to test exact-runner robustness |
| `F075_sub2_s100` | 2 | 0.075 | 1.00 | `geometry_control` | strong completed alternative with simpler geometry |
| `F080_sub2_s100` | 2 | 0.080 | 1.00 | `geometry_control` | strong completed alternative with better PASS coverage than `JF2` |
| `SUB3_070_105` | 3 | 0.070 | 1.05 | `sub3_hedge` | best completed sub3 hedge from wave-6 |
| `SUB3_075_105` | 3 | 0.075 | 1.05 | `sub3_hedge` | strongest partial sub3 frontier that remained credible |

### Stage plan

| stage | rows | purpose | top_k |
|---|---|---|---:|
| `transfer6` | `83,107,115,119,197,245` | direct bridge from tuning winner to exact validation path | 5 |
| `guard8` | `83,99,107,115,119,197,245,277` | hard quality guard with exact-runner semantics | 3 |
| `mix12_transfer` | `75,83,91,99,107,115,119,139,149,197,245,277` | final exact-runner selection | all survivors |

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

Use `C060_110_sub2_ref` as the exact-runner reference candidate for the same stage:

1. crash safety is mandatory
2. `0 FAIL` remains the primary production target
3. a challenger may replace the reference if it is exact-runner stable and beats the reference on fail count, gate points, healthy rows, or composite
4. if no challenger beats the reference, keep `C060_110_sub2` as the best completed tuning winner but do not authorize a broad rerun until the transfer question is explicitly resolved

## Compute Plan

- server capacity: `64` logical cores
- wave-7 default parallel width: `6` candidate lanes
- rationale:
  - exact-runner rows are heavier than the stage-budget search
  - `6` parallel lanes keeps the overnight run efficient without creating unnecessary contention
  - stage pruning is aggressive so later stages consume less compute

## Current Decision Framework

1. treat `C060_110_sub2` as the best completed tuning baseline
2. treat the stopped focused rerun as exploratory transfer evidence only
3. run wave-7 before any new broad relaunch
4. only reopen the `72`-row static rerun after wave-7 names an exact-runner-stable baseline

That is now the shortest technically rigorous path forward.

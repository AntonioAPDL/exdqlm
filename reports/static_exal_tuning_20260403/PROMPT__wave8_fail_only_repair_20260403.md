Work strictly in this worktree:

- /home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs

Branch context:

- expected branch: validation/rerun-after-0.4.0-sync

Current validated situation:

- wave-8 completed successfully
- the repaired resume pipeline is verified and no longer the main problem
- all wave-8 rows are done; remaining scope is fail-only scientific repair
- raw FAIL count is `4`, but that reduces to `2` underlying weak patterns
- zero-FAIL candidates already exist and should be preserved as the current
  best shortlist

Read first:

- `reports/static_exal_tuning_20260403/wave8_closeout_and_fail_only_repair_program.md`
- `reports/static_exal_tuning_20260403/wave7_closeout_and_wave8_program.md`

Residual FAIL targets:

1. `F075_sub2_s095 / row119 / static_paper / laplace / tau_0p95`
   - fails in `transfer6`, `guard8`, and `mix12_transfer`
2. `F080_sub2_s095 / row75 / static_paper / gausmix / tau_0p05`
   - fails only in `mix12_transfer`

Protected zero-FAIL shortlist:

- `F080_sub2_s105`
- `F080_sub2_s100_ref`
- `F0825_sub2_s100`
- `F075_sub2_s105`
- `F085_sub2_s095`
- `F085_sub2_s105`

Mission:

Implement the next fail-only repair program end to end in the same disciplined,
high-quality style as the repaired wave-8 execution.

Your work has 5 phases, in this order.

## Phase 1: Reconstruct the fail-only state

1. Verify repository state:
   - `git status --short --branch`
   - `git branch --show-current`
   - `git log --oneline -n 10`

2. Reconstruct the exact fail-only picture from the current wave-8 outputs.
   Verify:
   - all wave-8 rows are complete
   - the exact 4 FAIL entries
   - the reduction from 4 raw FAIL entries to 2 underlying failure patterns
   - the zero-FAIL candidate shortlist

3. Inspect the most relevant runtime evidence for the residual FAILs and their
   nearby successful neighbors.
   At minimum inspect:
   - the relevant summary csvs:
     - `tools/merge_reports/LOCAL_static_case_health_summary_wave8_transfer_*.csv`
   - the relevant health csvs:
     - `tools/merge_reports/LOCAL_static_case_health_wave8_transfer_*`
   - the relevant row logs under:
     - `tools/merge_reports/LOCAL_static_exal_wave8_*_resume.log`
   - the wave-8 manifests:
     - `tools/merge_reports/LOCAL_static_exal_wave8_guard8_resume_manifest_*.csv`
     - `tools/merge_reports/LOCAL_static_exal_wave8_mix12_transfer_resume_manifest_*.csv`

## Phase 2: Diagnose the two failure patterns

For each residual FAIL pattern:

1. compare it against the closest successful neighboring candidate(s)
2. compare it against the same row under the best zero-FAIL candidate(s)
3. determine the most likely mechanism:
   - proposal / jump geometry mismatch
   - row-specific instability
   - warm-start issue
   - gate-threshold issue
   - something else

Be explicit about what is proven vs inferred.

## Phase 3: Design the fail-only repair program

Design a narrow, efficient, high-learning-value repair program that:

1. touches only the residual FAIL patterns and the minimum comparison rows
2. avoids reopening the full wave-8 grid
3. preserves the repaired orchestration quality:
   - deterministic manifests
   - auditable per-row logging
   - supervisor / monitor safety
4. uses the same exact-runner discipline we have been using

Required output:

- a concrete fail-only candidate schedule
- clear rationale for each candidate / row included
- a decision rule for promotion, drop, or stop

## Phase 4: Implement the program

Implement the fail-only repair program end to end.

This includes:

1. update the reporting / tracker docs
2. create the focused manifests / launcher / supervisor / monitor if needed
3. validate the setup in prepare-only mode before launch
4. keep the implementation narrow, robust, and auditable

Important:

- do not modify package model code unless you identify a real model-code bug
  and explain it clearly first
- prefer orchestration / targeted schedule changes over broad disruption
- do not relaunch broad waves

## Phase 5: Execute only if verified

If and only if the fail-only repair setup is validated:

1. launch the fail-only repair program
2. monitor it using the same robust standards as wave-8
3. run a fresh health check
4. summarize whether the remaining FAILs were resolved or not

Deliverables in chat:

1. a concise diagnosis of the two residual failure patterns
2. the exact fail-only repair plan
3. what you implemented
4. verification evidence
5. the post-launch health table if launched
6. a clear answer to:
   - which candidate should be carried forward now
   - whether `F075_sub2_s095` should be dropped
   - whether `F080_sub2_s095` became viable or should remain secondary

Final constraints:

- keep the same high-quality, rigorous, efficient strategy we have used so far
- optimize for learning value per unit of compute
- do not stop at vague planning; implement the fail-only program if the setup
  is sound

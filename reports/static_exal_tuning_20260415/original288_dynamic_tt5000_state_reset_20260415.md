# Original288 Dynamic TT5000 State Reset (0.4.0)

Date: `2026-04-15`

## Why This Note Exists

The branch had accumulated several overlapping narratives:

- the accepted `v9` current-state comparison
- the completed branch-wide exact-spec replay
- the targeted dynamic `TT5000` repair relaunch
- disk-pressure cleanup questions around large replay artifacts

This note resets the state in one place so the branch itself explains:

1. where we are now
2. why the dynamic `TT5000` block did not get fixed
3. what was safely deleted
4. what the next rational step should be

## Main Goal

The ultimate validation goal is still the same:

1. keep a reproducible `0.4.0` validation branch with frozen, documented
   current-state selections
2. run the exact per-row replay we actually intended:
   - preserve each row's local winning spec
   - standardize only `n.burn = 5000`, `n.mcmc = 20000`, stored posterior
     draws `= 20000`, and deterministic `4` seeds
3. refresh the cluster-by-cluster comparison across:
   - static vs dynamic
   - `al` vs `exal`
   - `dqlm` vs `exdqlm`
   - `vb` vs `mcmc`
4. make that comparison scientifically complete rather than partially blocked
   by unresolved replay-selected failures

## Where We Are Now

Current branch state:

- accepted baseline comparison layer:
  - `tools/merge_reports/LOCAL_original288_comparison_selection_rhsns_v1_20260411.csv`
- branch-wide exact-spec replay comparison layer:
  - `tools/merge_reports/LOCAL_original288_comparison_selection_exactspec_multiseed_v1_20260412.csv`
- post-repair comparison layer:
  - `tools/merge_reports/LOCAL_original288_comparison_selection_exactspec_multiseed_dynamic_tt5000_repair_v1_20260414.csv`

Current scientific status:

- the exact-spec replay completed successfully as an execution workflow
- the static side is fully comparable
- the dynamic `TT5000` side is still unresolved
- the targeted dynamic `TT5000` repair wave completed and did **not** rescue
  any of the unresolved rows

That means the branch is operationally under control, but the replay-based
comparison is still only partial on dynamic.

## What The Targeted Repair Actually Did

Repair campaign:

- plan:
  - `reports/static_exal_tuning_20260414/original288_dynamic_tt5000_exactspec_repair_plan_20260414.md`
- program:
  - `reports/static_exal_tuning_20260414/original288_dynamic_tt5000_exactspec_repair_program_20260414.md`
- execution:
  - `reports/static_exal_tuning_20260414/original288_dynamic_tt5000_exactspec_repair_execution_20260414.md`

Final repair counts:

| scope | total | pass | warn | fail | healthy |
|---|---:|---:|---:|---:|---:|
| full repair wave | `196` | `0` | `0` | `196` | `0` |
| phase 1 exact replay | `144` | `0` | `0` | `144` | `0` |
| phase 2 historical repair | `52` | `0` | `0` | `52` | `0` |

Selected repaired outcome:

| measure | count |
|---|---:|
| unresolved target rows | `36` |
| selected repaired `PASS` | `0` |
| selected repaired `WARN` | `0` |
| selected repaired `FAIL` | `36` |
| better than pre-repair replay | `0` |
| matches pre-repair replay | `36` |
| worse than pre-repair replay | `0` |

Interpretation:

- the relaunch was the right narrow repair experiment
- it replayed the intended exact and historical specs
- it falsified the hope that exact replay plus known historical rescue profiles
  would be enough to close the dynamic `TT5000` hole

## Why The Dynamic TT5000 Block Was Not Fixed

This is now clear from the row-level artifacts:

- failure rows:
  - `tools/merge_reports/full288_original288_dynamic_tt5000_exactspec_repair_20260414/rows/*.csv`
- failure signature summary:
  - `tools/merge_reports/LOCAL_original288_dynamic_tt5000_failure_signature_summary_20260415.csv`
- phase-2 case coverage:
  - `tools/merge_reports/LOCAL_original288_dynamic_tt5000_phase2_case_coverage_20260415.csv`

### 1. The failures are real runtime failures, not comparison bugs

The `36 / 288` dynamic comparison holes come from replay-selected winners that
still fail at runtime. They are not healthy rows with broken metric extraction.

Two signatures dominate the entire repair wave:

| failure signature | count |
|---|---:|
| `system is computationally singular: reciprocal condition number = 1.73213e-50` | `116` |
| `chi has non-finite values (iter=1)` | `80` |

### 2. The failures happen immediately

The `chi` failures occur at `iter = 1` in:

- `R/exdqlmMCMC.R`
  - `sample_gig_cpp_required()`
  - `exdqlm_mcmc_uts`
  - `dqlm_mcmc_uts`

This tells us the hard pocket is not “mixing eventually goes bad.” It is
starting from a numerically invalid latent-state configuration on some TT5000
cases.

### 3. The VB side was not actually repaired by historical overlays

Phase 2 historical repair coverage only existed for `9 / 36` unresolved cases,
and every one of those was an `mcmc` case.

Coverage summary:

- phase-2 cases touched: `9`
- phase-2 historical candidates total: `13`
- phase-2 VB cases touched: `0`

So the repair wave did **not** have a real historical rescue inventory for:

- any `vb` TT5000 case
- many `mcmc` TT5000 cases

### 4. The unresolved hole is branch-wide on dynamic TT5000

The post-repair selected dynamic `TT5000` block remains:

- `3` families
- `3` taus
- `2` models
- `2` inference methods
- all `36` rows still `FAIL`

This is no longer consistent with “we just missed one good tuning profile.”
It looks like a broader method-level numerical instability in the TT5000
dynamic path under the standardized replay controls.

## What Was Safely Deleted

Safe deletion manifest:

- `tools/merge_reports/LOCAL_dynamic_safe_delete_manifest_20260415.txt`

Safe deletion completed:

- deleted files: `9`
- reclaimed space: `5.58G`
- deleted category:
  - old unselected `2026-04-10` restored-closure dynamic fit files

Current dynamic storage audit:

- `tools/merge_reports/LOCAL_dynamic_storage_audit_20260415.csv`

Current large storage buckets:

| category | size |
|---|---:|
| selected exact-spec dynamic replay files | `18.62G` |
| unselected exact-spec dynamic replay files | `55.85G` |
| selected restored-closure dynamic files | `1.73G` |

Interpretation:

- the safest meaningful reclaim has already been taken
- the next large reclaim would be the unselected exact-spec dynamic seed
  replicas
- those are still recent reproducibility evidence, so they should be treated as
  a separate deliberate cleanup decision rather than a casual delete

## What We Are Doing Next

The right next move is **not** another broad relaunch.

The right next move is a root-cause debugging lane for dynamic `TT5000`.

Recommended order:

1. stop broad repair sweeps on the same `36` rows
2. choose a minimal representative debugging quartet:
   - `dqlm / mcmc`
   - `exdqlm / mcmc`
   - `dqlm / vb`
   - `exdqlm / vb`
   on hard `TT5000` cases
3. trace the actual numerical breakpoints in the main codebase:
   - `chi` becoming non-finite in `sample_gig_cpp_required()`
   - singular linear-algebra paths on the VB / dynamic side
4. make method-level numerical fixes or diagnostics in the package code
5. only then relaunch the narrow dynamic `TT5000` block again
6. refresh the exact-spec comparison after those fixes land

## Bottom Line

This is the clean read:

- the branch is not “lost”; it is now better characterized
- the targeted dynamic repair run was worth doing because it ruled out the easy
  explanation that exact replay plus old row-local rescue configs would close
  the gap
- the remaining problem is a concentrated dynamic `TT5000` numerical-stability
  problem, not a general validation-management problem
- the next correct step is focused debugging in the main dynamic code path, not
  another large validation sweep

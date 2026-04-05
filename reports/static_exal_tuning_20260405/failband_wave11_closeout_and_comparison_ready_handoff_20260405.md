# Validation Campaign: Wave-11 Closeout and Comparison-Ready Handoff

Date: 2026-04-05

Primary references:

- `reports/static_exal_tuning_20260405/failband_wave10_closeout_and_wave11_row87_lowermid_program_20260405.md`
- `reports/static_exal_tuning_20260403/post_wave8_campaign_readiness_plan_20260403.md`
- `tools/merge_reports/LOCAL_validation_campaign_promoted_local_map_v9_20260405.csv`
- `tools/merge_reports/LOCAL_dynamic_row15_wave8_matrix_20260405.csv`

## Status Note

Wave-11 completed cleanly. No validation jobs are currently running in this
worktree.

The repair phase is now complete at the promoted row-best decision level:

- there are no remaining active runtime failures in the promoted campaign map
- there are no remaining active gate `FAIL` rows in the promoted campaign map
- the remaining work is now campaign assembly, provenance freeze, and broad
  comparison reporting

Important nuance:

- wave-11 as an experiment set still contains many `FAIL` candidate-runs
- that does **not** make the campaign unresolved
- the scientific decision rule for this phase is row-level closure under the
  promoted final map, not "every probed candidate must be non-`FAIL`"

## Wave-11 Closeout Summary

| stage | total | PASS | WARN | FAIL | missing | resolved |
|---|---:|---:|---:|---:|---:|---:|
| `anchor4_short_hist` | 4 | 0 | 1 | 3 | 0 | 1 |
| `confirm4_medium` | 4 | 0 | 1 | 3 | 0 | 1 |
| `none3_lowermid` | 3 | 0 | 1 | 2 | 0 | 1 |
| `overall` | 11 | 0 | 3 | 8 | 0 | 3 |

Wave-11 was therefore mixed as a candidate screen but successful as a closure
lane, because it closed the last remaining blocker:

| row | best_candidate_id | best_geometry_candidate | best_gate |
|---:|---|---|---|
| `87` | `R87_F085_sub2_s1025_histshort_seed2026079087` | `F085_sub2_s1025` | `WARN` |

Additional row-`87` non-`FAIL` confirmations from wave-11:

| stage | candidate_id | gate |
|---|---|---|
| `confirm4_medium` | `R87_F0825_sub2_s100_medium_seed2026111087` | `WARN` |
| `none3_lowermid` | `R87_F0825_sub2_s1025_none_seed2026116087` | `WARN` |

## Promoted Campaign Map v9

Broad static default:

- `F085_sub2_s100`

Promoted row-local static overrides:

| scope | row_id | preferred candidate | role | best read |
|---|---:|---|---|---|
| `current_rhsns_refresh` | `87` | `F085_sub2_s1025_histshort` | promoted `WARN` rescue | `WARN` |
| `current_rhsns_refresh` | `115` | `F0825_sub2_s100` | stable `PASS` | `PASS` |
| `current_rhsns_refresh` | `135` | `F0825_sub2_s105_none` | promoted `PASS` | `PASS` |
| `current_rhsns_refresh` | `174` | `F085_sub2_s105_histshort` | promoted `WARN` | `WARN` |
| `current_rhsns_refresh` | `190` | `F0825_sub2_s100_rwlong` | stable `WARN` | `WARN` |
| `current_rhsns_refresh` | `206` | `F0825_sub2_s1025_rwlong` | promoted `PASS` | `PASS` |
| `current_rhsns_refresh` | `278` | `F0845_sub2_s1025` | stable `PASS` | `PASS` |
| `legacy_rhs_refresh` | `181` | `F0825_sub2_s100` | stable `PASS` | `PASS` |
| `legacy_rhs_refresh` | `269` | `F0845_sub2_s100_histshort` | promoted `WARN` | `WARN` |

Promoted dynamic local override:

| workstream | row | preferred candidate | best read |
|---|---:|---|---|
| `dynamic_tail_cppgig_refresh_20260331` | `15` | `row15_slice_exact_20260405` | `WARN` |

## Endgame Closure Status

| tail item | best current result | status |
|---|---|---|
| static row `87` | `WARN` | closed to non-`FAIL` |
| static row `135` | `PASS` | closed |
| static row `174` | `WARN` | closed to non-`FAIL` |
| static row `269` | `WARN` | closed to non-`FAIL` |
| dynamic row `15` | `WARN` | closed to non-`FAIL` |

Progress against the active tail:

| goal slice | total | non-FAIL | FAIL | percent closed |
|---|---:|---:|---:|---:|
| final hard-tail items (`87`, `135`, `174`, `269`, `15`) | 5 | 5 | 0 | `100.0%` |
| static residual 9-row band | 9 | 9 | 0 | `100.0%` |
| remaining active blockers | 0 | 0 | 0 | `100.0%` |

## What Improved

1. row `87` is no longer a blocker; it now has a promoted `WARN` rescue
2. the full active tail is now non-`FAIL`
3. the branch is operationally clean: no running jobs, no active orchestration
   issues, and a fully traceable repair history
4. the campaign can now move out of repair mode and into merge/reporting mode

## Which Ideas Worked Best

1. keep `F085_sub2_s100` as the broad static default rather than constantly
   replacing the global baseline
2. use row-specific local overrides only where the broad default remained weak
3. trust exact historical non-`FAIL` anchors when the remaining tail became
   very small
4. separate dynamic row `15` from the static search and solve it by direct
   exact replay
5. use narrow corrective waves with explicit manifests, evaluator checkpoints,
   and provenance instead of broad reruns

## Which Ideas Did Not Help

1. trying to force one final generic tuning profile to solve every residual row
2. reopening already-screened weak families or wider residual bands
3. treating wave-10's late `F085` / `F0855` micro-band as the whole row-`87`
   search space
4. evaluating success by raw candidate-run totals rather than the promoted
   row-best closure objective

## Next Phase: Comparison-Ready Assembly

The next rigorous phase should be:

1. freeze the promoted campaign map v9 and preserve its provenance
2. build the merged campaign selection table:
   - reusable historical artifacts
   - refreshed static campaign slices
   - promoted row-local repairs
   - promoted dynamic row-`15` replay
3. regenerate campaign-level health tables and verify:
   - `0` runtime failures
   - `0` gate `FAIL`
   - `WARN` rows are documented and interpretable
4. produce the broad comparison-ready summary tables by:
   - model
   - inference
   - root kind
   - family
   - tau
5. only reopen tuning if the merge/provenance audit reveals a real regression
   or artifact-selection mistake

## Bottom Line

The validation study is no longer blocked by unresolved repair debt.

The branch is now ready for the next major objective:

- freeze the promoted local map
- assemble the merged healthy-fit campaign
- generate the broad comparison tables
- move toward final scientific signoff

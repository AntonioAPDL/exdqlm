# Validation Campaign: Post-Wave-8 Baseline and Comparison-Readiness Plan

Date: 2026-04-03

Current tracked context:

- `reports/static_exal_tuning_20260403/wave8_closeout_and_fail_only_repair_program.md`
- `reports/static_exal_tuning_20260403/fail_only_bridge_results_20260403.md`
- `tools/merge_reports/LOCAL_VALIDATION_RECOVERY_TRACKER_STATIC_EXAL_20260331.md`
- `tools/merge_reports/full288_dynamic_tail_cppgig_refresh_20260331/rows/row_0005.csv`
- `tools/merge_reports/full288_dynamic_tail_cppgig_refresh_20260331/rows/row_0015.csv`

## Status Note

This is the active planning document after wave-8 closeout and the fail-only
bridge repair.

It replaces the earlier question of "which tuning family should we trust next?"
with the current operational question: "what is the minimum remaining work to
reach a comparison-ready full validation campaign?"

## Promoted Baseline

The latest completed results do improve the previous exact-runner baseline and
should now be treated as the active carry-forward baseline.

| role | candidate_id | evidence | current decision |
|---|---|---|---|
| historical stage-budget winner | `C060_110_sub2` | wave-5 `mix12`: `10 PASS / 2 WARN / 0 FAIL` | historical tuning winner only; not the active validation rerun baseline |
| prior exact-runner baseline | `F080_sub2_s100` | wave-7: `7 PASS / 4 WARN / 1 FAIL` | superseded |
| active exact-runner baseline | `F080_sub2_s105` | wave-8: `22 PASS / 4 WARN / 0 FAIL` | promote and carry forward |
| primary backup | `F080_sub2_s100_ref` | wave-8: `19 PASS / 7 WARN / 0 FAIL` | keep as fallback control |
| secondary bridge option | `F080_sub2_s0975` | fail-only bridge: `1 PASS / 1 WARN / 0 FAIL` | optional narrow hedge only |

## Main Takeaways

### What improved

- wave-8 completed end to end under the repaired resume stack; orchestration is
  no longer the main blocker
- `F080_sub2_s105` became the first clear zero-FAIL exact-runner carry-forward
  candidate in the final `F080` neighborhood
- the fail-only bridge run resolved the remaining ambiguity:
  - `F075_sub2_s095` is dominated and should be dropped
  - `F080_sub2_s095` failed because it was slightly too tight, not because the
    `F080` family is broken
- dynamic tail row `5` improved from `failed_runtime` to `done / PASS / TRUE`
  under `full288_dynamic_tail_cppgig_refresh_20260331`
- dynamic tail row `15` still fails, but its refreshed current-HEAD run now
  finishes much faster than the older refresh and narrows the remaining dynamic
  problem to chain quality rather than pure runtime stall

### What still fails or remains unresolved

- the full `72`-row static `exal` rerun under the promoted baseline has not yet
  been executed, so those outputs are still stale relative to the new baseline
- dynamic row `15` remains `done / FAIL / FALSE` under
  `full288_dynamic_tail_cppgig_refresh_20260331`
- the campaign-level merged health tables and publishable comparison summary
  table have not yet been regenerated from the latest promoted baseline
- the remaining scientific uncertainty is no longer "which family to try?" but
  "how well does `F080_sub2_s105` generalize across the full stale static
  rerun slice and the final dynamic tail debt?"

### What worked best

1. `F080`-family exact-runner candidates with `gamma_substeps = 2`
2. slightly widened scale around the `F080` center, especially
   `F080_sub2_s105`
3. narrow, fail-only bridge experiments rather than reopening the whole grid
4. the repaired orchestration stack:
   deterministic manifests, auditable logs, locked summaries, supervisor, and
   live monitor

### What clearly did not work

- the `C060` family as the active exact-runner carry-forward baseline
- `F075_sub2_s095`, which repeatedly failed on the same row and is now
  dominated
- `F080_sub2_s095` as a full carry-forward candidate; it is too tight
- aggressive `F090 / F095` frontier families
- lambda-tempering, no-jump, and pathological `substeps = 3` lanes
- any broad rerun before exact-runner carry-forward evidence was clean

### Highest-value directions now

1. rerun the stale static `exal` slice under `F080_sub2_s105`
2. repair or replace dynamic row `15` under current `HEAD`
3. merge the refreshed outputs with the already valid artifacts and generate
   the final comparison-ready campaign tables

## Remaining Comparison Debt

The current goal is not to relaunch the full `291`-row campaign. The current
goal is to reuse all trustworthy artifacts and rerun only the stale or still
failing debt.

| workstream | cases | current state | why still needed |
|---|---:|---|---|
| static `exal` current RHS-NS rerun | 54 | stale relative to promoted baseline | these rows still reflect the old static baseline and dominate the residual campaign fail debt |
| static `exal` legacy RHS rerun | 18 | stale relative to promoted baseline | needed for apples-to-apples current-vs-legacy comparison under the promoted static baseline |
| dynamic tail row `15` | 1 | current-HEAD refresh still `FAIL` | only remaining dynamic unresolved row; row `5` and row `57` are already resolved |
| reusable validated artifacts | 218 | reusable now | these do not require rerun if provenance is preserved |

Minimal remaining rerun scope to reach a refreshed full-campaign closeout:

- `73` cases total (`72` static + `1` dynamic)
- not `291`

## Comparison-Ready Acceptance Rule

For the final publishable campaign summary, the acceptance target should be:

| criterion | requirement |
|---|---|
| full campaign coverage | all targeted cases represented in the merged final table |
| stale baseline debt | `0` stale rows remaining |
| runtime failures | `0` |
| gate FAIL count | `0` |
| gate WARN count | acceptable if documented and scientifically interpretable |
| provenance | each refreshed slice tagged and traceable to its manifest and baseline |

This keeps the standard aligned with the working rule already used in the
study: `WARN` can be tolerated, `FAIL` cannot.

## Recommended Next-Phase Plan

### Phase A: Freeze the promoted baseline

- [ ] Freeze `F080_sub2_s105` as the active static `exal` validation baseline
- [ ] Keep `F080_sub2_s100_ref` as the fallback control in case the full rerun
      exposes a concentrated regression
- [ ] Record `F080_sub2_s0975` as a secondary bridge candidate, not the primary
      production baseline

### Phase B: Prepare the 72-row static rerun

- [ ] rebuild the `72`-row static rerun manifest from the stale current and
      legacy static `exal` rows
- [ ] apply `F080_sub2_s105` exact-runner overrides with the same robust
      orchestration standards used in wave-8
- [ ] validate the prepare-only outputs before launch
- [ ] preserve deterministic manifests, failure logs, supervisor logs, and
      monitor heartbeats

### Phase C: Keep the dynamic tail debt separate but active

- [ ] open a narrow row-`15` current-HEAD refresh/repair lane
- [ ] do not let row `15` block preparation of the larger static rerun
- [ ] treat row `15` as the only remaining dynamic debt; do not relaunch rows
      `5` or `57`

### Phase D: Merge and summarize the refreshed campaign

- [ ] merge the refreshed `72` static rows and refreshed row `15` with the
      existing reusable artifacts
- [ ] regenerate campaign-level health tables
- [ ] produce summary distributions by model, inference, root kind, family, and
      tau
- [ ] produce the final comparison-ready summary table used for reporting

### Phase E: Stop rule if a narrow residual fail band remains

- [ ] if the refreshed `72`-row rerun leaves only a narrow residual fail band,
      do not reopen a broad tuning search
- [ ] isolate only the remaining failing rows and repair them with the same
      narrow fail-only discipline used successfully after wave-8

## Operational Bottom Line

The study is in a materially better place now.

The open problem is no longer "find a plausible static tuning family" and it is
no longer "fix the resume chain." The open problem is now much cleaner:

1. roll the promoted exact-runner baseline through the stale `72`-row static
   slice
2. clean up dynamic row `15`
3. regenerate the full campaign tables

That is the shortest rigorous path from the current branch state to a
comparison-ready and publication-ready validation summary.
